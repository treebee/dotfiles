#!/usr/bin/python3
"""Bubblewrap sandbox wrapper for AI agents.

Run an agent in a bubblewrap sandbox with a minimal view of the host. All
namespaces are unshared, the environment is cleared, and only explicitly
selected files and sockets are exposed.

Usage::

    bwrap_agent AGENT [ARGS...]
    bwrap_agent --shell [ARGS...]

Examples::

    bwrap_agent cursor-agent --resume
    bwrap_agent opencode run "explain this repository"
    bwrap_agent --shell -c 'git status'

The current directory must be covered by a writable bind. If it is not, the
script offers to whitelist it for one run or permanently. Non-interactive
runs fail with guidance instead of silently granting access.

Configuration
=============

Additional configuration is read from ``~/.config/bwrap-agent.toml`` (or
``$XDG_CONFIG_HOME/bwrap-agent.toml``). Supported sections:

``[[binds]]``
    Extra bind mounts. ``source`` is mandatory. ``target`` is optional and
    defaults to the host path. ``read_only`` defaults to true::

        [[binds]]
        source = "/srv/data"
        target = "/data"
        read_only = true

``[[envvars]]``
    Extra environment variables. ``name`` is mandatory. ``value`` is optional
    and falls back to the current environment::

        [[envvars]]
        name = "MY_TOKEN"

``[[whiteouts]]``
    Paths to hide with an empty tmpfs mount. The path must already be visible
    inside the sandbox::

        [[whiteouts]]
        target = "~/.config/agent/secret"

``[agents.<name>]``
    Per-agent overrides for the built-in profiles. Paths are relative to the
    home directory unless absolute::

        [agents.opencode]
        gui = true
        rw_paths = [".config/opencode"]
        ro_paths = [".local/share/skills"]
        env = ["COLORTERM"]
        network = true
        command = ["opencode"]

Security model
==============

The sandbox uses ``--unshare-all``, ``--clearenv``, ``--cap-drop ALL``,
``--disable-userns`` and ``--new-session`` by default. Home directories are
not mounted wholesale: only the agent's own state directories and a small set
of read-only tool configuration files are visible. SSH keys are never bound;
instead, a private ssh-agent socket is exposed. Likewise, the session D-Bus is
replaced by an ``xdg-dbus-proxy`` that only allows desktop portal and
notification traffic.

Use ``--allow-userns`` and ``--no-new-session`` if an agent needs nested user
namespaces or its own controlling terminal. Use ``--no-network`` to run
without network access, and ``--docker`` to expose the Docker socket.

Debugging
=========

``--debug`` logs the complete bwrap command line. ``--dry-run`` prints it
without executing it. When in doubt, start the sandbox with ``--shell`` to
inspect what the agent can see.
"""

import argparse
import json
import logging
import os
import pwd
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from collections.abc import Iterator, Sequence
from contextlib import ExitStack, suppress
from dataclasses import dataclass, replace
from pathlib import Path

env = os.getenv


class SandboxError(Exception):
    """Raised when the sandbox cannot be set up."""


def expand_path(value: str | Path, home: Path) -> Path:
    """Expand ``~``/environment variables and make relative paths relative to home."""
    path = Path(os.path.expandvars(os.path.expanduser(os.fspath(value))))
    return path if path.is_absolute() else home / path


@dataclass
class BasicBindConfig:
    """A bubblewrap bind mount."""

    source: str | Path
    target: str | Path | None = None
    flag: str | None = None

    def __post_init__(self) -> None:
        self.source = os.fspath(self.source)
        self.target = self.source if self.target is None else os.fspath(self.target)

    @property
    def writable(self) -> bool:
        return False

    def __iter__(self) -> Iterator[str]:
        if self.flag is None or not Path(self.source).exists():
            return
        yield self.flag
        yield os.fspath(self.source)
        yield os.fspath(self.target)

    def covers_path(self, path: Path) -> bool:
        """Return whether ``path`` is inside this bind's source."""
        source = Path(self.source)
        if not source.exists():
            return False
        path = path.resolve()
        source = source.resolve()
        return path == source or source in path.parents


@dataclass
class ROBindConfig(BasicBindConfig):
    """A read-only bind mount."""

    flag: str = "--ro-bind"


@dataclass
class RWBindConfig(BasicBindConfig):
    """A read-write bind mount."""

    flag: str = "--bind"
    create: bool = True

    def __post_init__(self) -> None:
        super().__post_init__()
        path = Path(self.source)
        if self.create and not path.exists():
            # A missing optional directory is harmless; __iter__ skips it.
            with suppress(OSError):
                path.mkdir(parents=True)

    @property
    def writable(self) -> bool:
        return True


@dataclass
class DevBindConfig(BasicBindConfig):
    """A device bind mount."""

    flag: str = "--dev-bind"

    @property
    def writable(self) -> bool:
        return True


@dataclass
class Tmpfs:
    """A tmpfs mount."""

    target: str | Path

    def __iter__(self) -> Iterator[str]:
        yield "--tmpfs"
        yield os.fspath(self.target)


@dataclass
class Dir:
    """Create a directory inside the sandbox."""

    target: str | Path

    def __iter__(self) -> Iterator[str]:
        yield "--dir"
        yield os.fspath(self.target)


Mount = BasicBindConfig | Tmpfs | Dir | tuple[str, ...]


@dataclass(frozen=True)
class AgentProfile:
    """Filesystem and environment requirements for an agent."""

    name: str
    command: tuple[str, ...]
    rw_paths: tuple[str, ...] = ()
    ro_paths: tuple[str, ...] = ()
    env: tuple[str, ...] = ()
    gui: bool = False
    network: bool = True


@dataclass(frozen=True)
class BwrapFeatures:
    """Bubblewrap options supported by the installed version."""

    disable_userns: bool
    new_session: bool
    cap_drop: bool
    hostname: bool


# Environment variables that are safe and useful to pass into the sandbox. Anything that
# is not listed here remains hidden because bwrap is invoked with --clearenv.
ENV_VARS_TO_SHARE = (
    "ASDF_DIR",
    "BUN_INSTALL",
    "COLORTERM",
    "DISPLAY",
    "EDITOR",
    "HOME",
    "LANG",
    "LC_ALL",
    "LC_CTYPE",
    "LC_NUMERIC",
    "LC_TIME",
    "LOGNAME",
    "MOZ_ENABLE_WAYLAND",
    "PATH",
    "PIP_REQUIRE_VIRTUALENV",
    "SHELL",
    "TERM",
    "TERMINFO",
    "TERM_PROGRAM",
    "TZ",
    "USER",
    "VIRTUAL_ENV",
    "VISUAL",
    "WAYLAND_DISPLAY",
    "WORKON_HOME",
    "XAUTHORITY",
    "XCURSOR_SIZE",
    "XDG_CACHE_HOME",
    "XDG_CONFIG_HOME",
    "XDG_CURRENT_DESKTOP",
    "XDG_DATA_HOME",
    "XDG_RUNTIME_DIR",
    "XDG_SESSION_TYPE",
    "XDG_STATE_HOME",
)

# These are only meaningful for agents that talk to a display server.
GUI_ENV_VARS = {
    "DISPLAY",
    "MOZ_ENABLE_WAYLAND",
    "WAYLAND_DISPLAY",
    "XAUTHORITY",
    "XCURSOR_SIZE",
    "XDG_SESSION_TYPE",
}

CONFIG_FILE_NAME = "bwrap-agent.toml"


# Read-only home paths that are commonly needed by development tools.
HOME_RO_PATHS = (
    ".agents",
    ".asdf",
    ".bun",
    ".config/agents",
    ".config/git",
    ".config/nvim",
    ".gitconfig",
    ".local/bin",
    ".npmrc",
    ".nvm",
    ".pip",
    ".tool-versions",
    ".vim",
    ".vimrc",
    "nvim",
)

# System paths that are safe to expose read-only.
SYSTEM_RO_PATHS = (
    "/usr",
    "/lib",
    "/lib64",
    "/bin",
    "/etc/alternatives",
    "/etc/ca-certificates",
    "/etc/fonts",
    "/etc/gai.conf",
    "/etc/group",
    "/etc/host.conf",
    "/etc/hosts",
    "/etc/java-17-openjdk",
    "/etc/java-21-openjdk",
    "/etc/ld.so.cache",
    "/etc/ld.so.conf",
    "/etc/ld.so.conf.d",
    "/etc/localtime",
    "/etc/nsswitch.conf",
    "/etc/os-release",
    "/etc/passwd",
    "/etc/pki",
    "/etc/protocols",
    "/etc/resolv.conf",
    "/etc/services",
    "/etc/ssh/ssh_config",
    "/etc/ssh/ssh_config.d",
    "/etc/ssl",
    "/etc/xdg",
)

BROAD_PATHS = (
    Path("/"),
    Path("/dev"),
    Path("/etc"),
    Path("/home"),
    Path("/opt"),
    Path("/proc"),
    Path("/run"),
    Path("/sys"),
    Path("/tmp"),
    Path("/usr"),
    Path("/var"),
)


def detect_bwrap_features() -> BwrapFeatures:
    """Inspect ``bwrap --help`` and report which hardening options are available."""
    try:
        result = subprocess.run(
            ["bwrap", "--help"],
            capture_output=True,
            check=False,
            text=True,
        )
    except OSError as exc:  # pragma: no cover - validate_environment catches this first
        raise SandboxError(f"failed to run bwrap: {exc}") from exc

    help_text = result.stdout + result.stderr
    return BwrapFeatures(
        disable_userns="--disable-userns" in help_text,
        new_session="--new-session" in help_text,
        cap_drop="--cap-drop" in help_text,
        hostname="--hostname" in help_text,
    )


def builtin_profile(name: str) -> AgentProfile | None:
    """Return the built-in profile for a known agent, if any."""
    match name:
        case "cursor":
            cursor_ide = Path("/usr/share/cursor/cursor")
            command = (str(cursor_ide), "--no-sandbox") if cursor_ide.exists() else (
                "cursor",
                "--no-sandbox",
            )
            return AgentProfile(
                name="cursor",
                command=command,
                rw_paths=(
                    ".cache/cursor",
                    ".config/Cursor",
                    ".config/cursor",
                    ".cursor",
                    ".local/share/cursor",
                    ".local/state/cursor",
                ),
                ro_paths=("/opt/cursor-agent", "/usr/share/cursor", ".cursorignore"),
                gui=True,
            )

        case "cursor-agent" | "agent":
            current = (
                Path.home() / ".local/share/cursor-agent/versions/current/cursor-agent"
            )
            command = (str(current),) if current.exists() else ("cursor-agent",)
            return AgentProfile(
                name="cursor-agent",
                command=command,
                rw_paths=(
                    ".cache/cursor-agent",
                    ".config/cursor-agent",
                    ".local/share/cursor-agent",
                    ".local/state/cursor-agent",
                ),
                ro_paths=("/opt/cursor-agent",),
                gui=True,
            )

        case "opencode":
            return AgentProfile(
                name="opencode",
                command=("opencode",),
                rw_paths=(
                    ".cache/opencode",
                    ".config/opencode",
                    ".local/share/opencode",
                    ".local/state/opencode",
                    ".opencode",
                ),
                ro_paths=(".local/share/skills",),
                gui=False,
            )

        case "claude":
            return AgentProfile(
                name="claude",
                command=("claude",),
                rw_paths=(
                    ".cache/claude",
                    ".claude",
                    ".config/claude",
                    ".local/share/claude",
                    ".local/state/claude",
                ),
                gui=False,
            )

        case "codex":
            return AgentProfile(
                name="codex",
                command=("codex",),
                rw_paths=(
                    ".cache/codex",
                    ".codex",
                    ".config/codex",
                    ".local/share/codex",
                    ".local/state/codex",
                ),
                gui=False,
            )

        case "gemini" | "agy":
            return AgentProfile(
                name=name,
                command=(name,),
                rw_paths=(
                    ".cache/gemini",
                    ".config/gemini",
                    ".gemini",
                    ".local/share/gemini",
                    ".local/state/gemini",
                ),
                gui=False,
            )

    return None


def generic_profile(name: str) -> AgentProfile:
    """Return a conservative profile for an unknown agent."""
    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        rw_paths = (
            f".cache/{name}",
            f".config/{name}",
            f".{name}",
            f".local/share/{name}",
            f".local/state/{name}",
        )
    else:
        rw_paths = ()

    return AgentProfile(name=name, command=(name,), rw_paths=rw_paths)


def default_config_path() -> Path:
    """Return the default configuration file location."""
    base = env("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return expand_path(base, Path.home()) / CONFIG_FILE_NAME


def load_config(path: Path) -> dict:
    """Load the TOML configuration, returning an empty table when it does not exist."""
    if not path.exists():
        return {}

    try:
        with path.open("rb") as fobj:
            config = tomllib.load(fobj)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SandboxError(f"failed to read {path}: {exc}") from exc

    if not isinstance(config, dict):
        raise SandboxError(f"expected a TOML table in {path}")

    return config


def get_config_agent(config: dict, *names: str) -> dict:
    """Return the ``[agents.<name>]`` table for the first matching name."""
    agents = config.get("agents", {})
    if not isinstance(agents, dict):
        raise SandboxError("'agents' must be a table")

    for name in names:
        candidate = agents.get(name)
        if candidate is None:
            continue
        if not isinstance(candidate, dict):
            raise SandboxError(f"'agents.{name}' must be a table")
        return candidate

    return {}


def string_tuple(value: object, *, key: str) -> tuple[str, ...]:
    """Validate and convert a TOML value to a tuple of strings."""
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise SandboxError(f"'{key}' must be a list of strings")
    return tuple(value)


def merge_agent_config(profile: AgentProfile, agent_config: dict) -> AgentProfile:
    """Apply a user-provided ``[agents.<name>]`` table to a built-in profile."""
    if not agent_config:
        return profile

    command = profile.command
    if "command" in agent_config:
        value = agent_config["command"]
        command = (
            (value,)
            if isinstance(value, str)
            else string_tuple(value, key="command")
        )
        if not command:
            raise SandboxError("'command' must not be empty")

    rw_paths = profile.rw_paths
    if "rw_paths" in agent_config:
        rw_paths = (*rw_paths, *string_tuple(agent_config["rw_paths"], key="rw_paths"))

    ro_paths = profile.ro_paths
    if "ro_paths" in agent_config:
        ro_paths = (*ro_paths, *string_tuple(agent_config["ro_paths"], key="ro_paths"))

    extra_env = profile.env
    if "env" in agent_config:
        extra_env = (*extra_env, *string_tuple(agent_config["env"], key="env"))

    gui = agent_config.get("gui", profile.gui)
    if not isinstance(gui, bool):
        raise SandboxError("'gui' must be a boolean")

    network = agent_config.get("network", profile.network)
    if not isinstance(network, bool):
        raise SandboxError("'network' must be a boolean")

    return replace(
        profile,
        command=command,
        rw_paths=rw_paths,
        ro_paths=ro_paths,
        env=extra_env,
        gui=gui,
        network=network,
    )


def get_agent_profile(
    agent: str,
    config: dict | None = None,
    *,
    shell: bool = False,
) -> AgentProfile:
    """Resolve an agent name to a profile, applying user configuration."""
    config = config or {}

    if shell:
        shell_path = env("SHELL") or pwd.getpwuid(os.getuid()).pw_shell
        profile = AgentProfile(name="shell", command=(shell_path,), gui=False)
        return merge_agent_config(profile, get_config_agent(config, "shell"))

    name = Path(agent).name
    profile = builtin_profile(name) or generic_profile(name)

    if profile.command == (name,) and agent != name:
        profile = replace(profile, command=(agent,))

    agent_config = get_config_agent(config, name, profile.name)
    return merge_agent_config(profile, agent_config)


def get_config_binds(config: dict, home: Path) -> list[Mount]:
    """Build bind mounts from the ``[[binds]]`` configuration section."""
    raw_binds = config.get("binds", [])
    if not isinstance(raw_binds, list):
        raise SandboxError("'binds' must be a list of tables")

    binds: list[Mount] = []
    for index, item in enumerate(raw_binds):
        if not isinstance(item, dict):
            raise SandboxError(f"'binds[{index}]' must be a table")

        source = item.get("source")
        if not isinstance(source, str) or not source:
            raise SandboxError(f"'binds[{index}].source' must be a non-empty string")

        read_only = item.get("read_only", True)
        if not isinstance(read_only, bool):
            raise SandboxError(f"'binds[{index}].read_only' must be a boolean")

        source_path = expand_path(source, home)
        if not source_path.exists():
            raise SandboxError(f"bind source does not exist: {source_path}")

        target = item.get("target")
        if target is not None and not isinstance(target, str):
            raise SandboxError(f"'binds[{index}].target' must be a string")
        target_path = expand_path(target, home) if target else None

        if read_only:
            binds.append(ROBindConfig(source_path, target_path))
        else:
            binds.append(RWBindConfig(source_path, target_path, create=False))

    return binds


def get_config_whiteouts(config: dict, home: Path) -> list[Mount]:
    """Build tmpfs whiteouts from the ``[[whiteouts]]`` configuration section."""
    raw_whiteouts = config.get("whiteouts", [])
    if not isinstance(raw_whiteouts, list):
        raise SandboxError("'whiteouts' must be a list of tables")

    whiteouts: list[Mount] = []
    for index, item in enumerate(raw_whiteouts):
        if not isinstance(item, dict):
            raise SandboxError(f"'whiteouts[{index}]' must be a table")

        target = item.get("target")
        if not isinstance(target, str) or not target:
            raise SandboxError(
                f"'whiteouts[{index}].target' must be a non-empty string"
            )

        whiteouts.append(Tmpfs(expand_path(target, home)))

    return whiteouts



def resolve_command(profile: AgentProfile, args: Sequence[str]) -> list[str]:
    """Resolve the agent executable and append its arguments."""
    command = list(profile.command)
    executable = command[0]

    if os.sep in executable or executable.startswith("."):
        path = Path(executable).expanduser()
        if not path.exists() or not os.access(path, os.X_OK):
            raise SandboxError(f"agent command is not executable: {executable}")
        command[0] = str(path)
    else:
        resolved = shutil.which(executable)
        if resolved is None:
            raise SandboxError(f"agent command not found: {executable}")
        command[0] = resolved

    return [*command, *args]


def is_broad_path(path: Path, home: Path) -> bool:
    """Return whether binding ``path`` read-write would expose too much of the host."""
    resolved = path.resolve()
    return resolved == home.resolve() or resolved in BROAD_PATHS


def get_default_binds(
    profile: AgentProfile,
    home: Path,
    runtime_dir: Path,
    *,
    docker: bool,
) -> list[Mount]:
    """Build the baseline filesystem view for the sandbox."""
    binds: list[Mount] = [
        ("--dev", "/dev"),
        ("--proc", "/proc"),
        Tmpfs("/dev/shm"),
        Tmpfs("/run"),
        Tmpfs("/tmp"),
        ROBindConfig("/sys/dev/char"),
        ROBindConfig("/sys/devices"),
        ROBindConfig("/sys/class"),
        DevBindConfig("/dev/dri"),
        DevBindConfig("/dev/snd"),
        Dir(runtime_dir),
    ]

    for path in SYSTEM_RO_PATHS:
        binds.append(ROBindConfig(path))

    binds.append(
        ROBindConfig("/usr/libexec/flatpak-xdg-utils/xdg-open", "/usr/bin/xdg-open"),
    )
    binds.append(ROBindConfig("/run/systemd/resolve"))

    if profile.gui:
        if env("DISPLAY"):
            binds.append(ROBindConfig("/tmp/.X11-unix"))
            binds.append(ROBindConfig(home / ".Xauthority"))

        if wayland_display := env("WAYLAND_DISPLAY"):
            wayland_path = Path(wayland_display)
            if not wayland_path.is_absolute():
                wayland_path = runtime_dir / wayland_path
            binds.append(ROBindConfig(wayland_path))

        if xauthority := env("XAUTHORITY"):
            binds.append(ROBindConfig(xauthority))

    if docker:
        docker_host = env("DOCKER_HOST")
        if docker_host:
            docker_path = Path(docker_host.removeprefix("unix://"))
            if docker_path.is_absolute():
                binds.append(ROBindConfig(docker_path))
        else:
            binds.append(ROBindConfig("/var/run/docker.sock"))

    for relative in HOME_RO_PATHS:
        binds.append(ROBindConfig(home / relative))

    # Keep the SSH directory synthetic and expose only non-secret configuration.
    binds.append(Dir(home / ".ssh"))
    binds.append(ROBindConfig(home / ".ssh/config"))
    binds.append(ROBindConfig(home / ".ssh/known_hosts"))
    binds.append(ROBindConfig("/etc/ssh/ssh_config"))

    if virtual_env := env("VIRTUAL_ENV"):
        binds.append(ROBindConfig(virtual_env))

    binds.append(RWBindConfig(home / ".cache" / profile.name, create=True))
    binds.append(RWBindConfig(home / ".npm", create=True))

    if workon_home := env("WORKON_HOME"):
        binds.append(RWBindConfig(expand_path(workon_home, home), create=True))
    elif (home / ".virtualenvs").exists():
        binds.append(ROBindConfig(home / ".virtualenvs"))

    for value in profile.ro_paths:
        binds.append(ROBindConfig(expand_path(value, home)))

    for value in profile.rw_paths:
        binds.append(RWBindConfig(expand_path(value, home), create=True))

    return binds


def get_extra_binds(
    options: argparse.Namespace,
    home: Path,
) -> list[Mount]:
    """Build bind mounts requested on the command line."""
    binds: list[Mount] = []

    for value in options.extra_rw_binds:
        path = expand_path(value, home)
        if not path.exists():
            raise SandboxError(f"bind source does not exist: {path}")
        binds.append(RWBindConfig(path, create=False))

    for value in options.extra_ro_binds:
        path = expand_path(value, home)
        if not path.exists():
            raise SandboxError(f"bind source does not exist: {path}")
        binds.append(ROBindConfig(path))

    return binds


def add_bind_to_config(path: Path, source: Path, *, read_only: bool) -> None:
    """Append a ``[[binds]]`` entry to the configuration file."""
    path.parent.mkdir(parents=True, exist_ok=True)

    prefix = ""
    if path.exists():
        content = path.read_bytes()
        if content:
            prefix = "\n" if content.endswith(b"\n") else "\n\n"

    entry = (
        "[[binds]]",
        f"source = {json.dumps(str(source))}",
        f"read_only = {json.dumps(read_only)}",
    )

    try:
        with path.open("a") as fobj:
            fobj.write(prefix + "\n".join(entry) + "\n")
    except OSError as exc:
        raise SandboxError(f"failed to update {path}: {exc}") from exc


def is_interactive() -> bool:
    return sys.stdin.isatty() and sys.stderr.isatty()


def prompt_choice(prompt: str, choices: Sequence[str], default: str) -> str:
    choices_text = "/".join(choices)
    while True:
        try:
            answer = input(f"{prompt} [{choices_text}] ({default}): ").strip().lower()
        except EOFError:
            return default
        if not answer:
            return default
        if answer in choices:
            return answer
        print(f"Please answer one of: {', '.join(choices)}", file=sys.stderr)


def prompt_yes_no(prompt: str, *, default: bool = True) -> bool:
    suffix = "Y/n" if default else "y/N"
    try:
        answer = input(f"{prompt} [{suffix}]: ").strip().lower()
    except EOFError:
        return default
    if not answer:
        return default
    return answer in {"y", "yes"}


def cwd_is_visible(binds: Sequence[Mount], cwd: Path) -> bool:
    return any(
        isinstance(bind, BasicBindConfig) and bind.covers_path(cwd) for bind in binds
    )


def cwd_is_writable(binds: Sequence[Mount], cwd: Path) -> bool:
    return any(
        isinstance(bind, BasicBindConfig) and bind.writable and bind.covers_path(cwd)
        for bind in binds
    )


def ensure_cwd_in_sandbox(
    binds: list[Mount],
    *,
    config_path: Path,
    options: argparse.Namespace,
    home: Path,
) -> None:
    """Make sure the current directory is available and writable inside the sandbox."""
    cwd = Path.cwd()

    if cwd_is_writable(binds, cwd):
        return
    if options.cwd_read_only and cwd_is_visible(binds, cwd):
        return

    if is_broad_path(cwd, home):
        raise SandboxError(f"refusing to whitelist {cwd}; run from a project directory")

    visible = cwd_is_visible(binds, cwd)
    always = False

    if options.dry_run:
        print(
            f"warning: {cwd} is not writable inside the sandbox",
            file=sys.stderr,
        )
        read_only = options.cwd_read_only
    elif not is_interactive():
        state = "read-only" if visible else "not available"
        raise SandboxError(
            f"{cwd} is {state} inside the sandbox; "
            f"add it to {config_path} under [[binds]]"
        )
    else:
        state = "read-only" if visible else "not available"
        print(
            f"The current directory {cwd} is {state} inside the sandbox.",
            file=sys.stderr,
        )
        choice = prompt_choice(
            "Whitelist it for this run only, permanently, or abort?",
            ("once", "always", "no"),
            "no",
        )
        if choice == "no":
            raise SandboxError("aborted")
        always = choice == "always"
        read_only = options.cwd_read_only or not prompt_yes_no(
            "Allow write access?",
            default=True,
        )

    if read_only:
        binds.append(ROBindConfig(cwd))
    else:
        binds.append(RWBindConfig(cwd, create=False))

    if always:
        add_bind_to_config(config_path, cwd, read_only=read_only)
        print(f"Added {cwd} to {config_path}.", file=sys.stderr)



def dedupe_binds(binds: Sequence[Mount]) -> list[Mount]:
    """Remove duplicate mount arguments while preserving order."""
    result: list[Mount] = []
    seen: set[tuple[str, ...]] = set()

    for bind in binds:
        key = tuple(bind)
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(bind)

    return result


def get_bind_args(binds: Sequence[Mount]) -> list[str]:
    """Flatten bind configurations into bwrap arguments."""
    result: list[str] = []
    for bind in binds:
        result.extend(bind)
    return result


class SshAgent:
    """A private ssh-agent whose socket is the only SSH access for the sandbox."""

    def __init__(self, session_dir: Path) -> None:
        self.socket: Path | None = None
        self._proc: subprocess.Popen | None = None
        self._session_dir = session_dir

    def __enter__(self) -> "SshAgent":
        if shutil.which("ssh-agent") is None:
            logging.info("ssh-agent not found; SSH authentication is unavailable")
            return self

        socket = self._session_dir / "ssh-agent"
        try:
            proc = subprocess.Popen(
                ["ssh-agent", "-D", "-a", str(socket)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as exc:
            raise SandboxError(f"failed to start ssh-agent: {exc}") from exc

        try:
            for _ in range(50):
                if socket.is_socket():
                    break
                if proc.poll() is not None:
                    raise SandboxError("ssh-agent exited during startup")
                time.sleep(0.1)
            else:
                raise SandboxError(
                    f"timed out waiting for ssh-agent socket at {socket}"
                )
        except BaseException:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:  # pragma: no cover
                proc.kill()
            raise

        self._proc = proc
        self.socket = socket
        return self

    def add_key(self, path: Path) -> None:
        if self.socket is None:
            return
        if shutil.which("ssh-add") is None:
            logging.info("ssh-add not found; sandbox SSH key was not loaded")
            return

        try:
            subprocess.run(
                ["ssh-add", "-q", str(path)],
                env={**os.environ, "SSH_AUTH_SOCK": str(self.socket)},
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as exc:
            raise SandboxError(f"failed to add SSH key {path}: {exc}") from exc

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        proc = self._proc
        self._proc = None
        if proc is None:
            return

        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:  # pragma: no cover
            proc.kill()


class DBusProxy:
    """A filtered D-Bus connection that only exposes a couple of desktop services."""

    policy = (
        "--talk=org.freedesktop.portal.Desktop",
        "--talk=org.freedesktop.Notifications",
    )

    def __init__(self, session_dir: Path) -> None:
        self.socket: Path | None = None
        self._proc: subprocess.Popen | None = None
        self._read_fd: int | None = None
        self._session_dir = session_dir

    def __enter__(self) -> "DBusProxy":
        bus_address = env("DBUS_SESSION_BUS_ADDRESS")
        if not bus_address:
            logging.info("DBUS_SESSION_BUS_ADDRESS is not set; D-Bus is unavailable")
            return self
        if shutil.which("xdg-dbus-proxy") is None:
            logging.info("xdg-dbus-proxy not found; D-Bus is unavailable")
            return self

        socket = self._session_dir / "bus"
        read_fd, write_fd = os.pipe()
        try:
            proc = subprocess.Popen(
                [
                    "xdg-dbus-proxy",
                    f"--fd={write_fd}",
                    bus_address,
                    str(socket),
                    "--filter",
                    *self.policy,
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                pass_fds=(write_fd,),
            )
        except OSError as exc:
            os.close(read_fd)
            raise SandboxError(f"failed to start xdg-dbus-proxy: {exc}") from exc
        finally:
            os.close(write_fd)

        try:
            # The proxy writes a byte once it is ready. A closed pipe means it exited.
            if not os.read(read_fd, 1):
                proc.wait(timeout=5)
                raise SandboxError("D-Bus proxy failed to start")
        except BaseException:
            os.close(read_fd)
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:  # pragma: no cover
                proc.kill()
            raise

        self._proc = proc
        self._read_fd = read_fd
        self.socket = socket
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        proc = self._proc
        read_fd = self._read_fd
        self._proc = None
        self._read_fd = None

        if read_fd is not None:
            os.close(read_fd)
        if proc is None:
            return

        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:  # pragma: no cover
            proc.kill()


def find_sandbox_ssh_key() -> Path | None:
    """Return the first ``~/.ssh/sandbox_*`` private key, if any."""
    ssh_dir = Path.home() / ".ssh"
    if not ssh_dir.is_dir():
        return None

    for path in sorted(ssh_dir.glob("sandbox_*")):
        if path.is_file() and not path.name.endswith(".pub"):
            return path

    return None


def get_env_args(
    profile: AgentProfile,
    options: argparse.Namespace,
    config: dict,
    home: Path,
    runtime_dir: Path,
    cwd: Path,
) -> list[str]:
    """Build the explicit environment for the sandbox."""
    values: dict[str, str] = {}
    for name in ENV_VARS_TO_SHARE:
        if not profile.gui and name in GUI_ENV_VARS:
            continue
        if (value := env(name)) is not None:
            values[name] = value

    for name in profile.env:
        if (value := env(name)) is not None:
            values[name] = value

    raw_envvars = config.get("envvars", [])
    if not isinstance(raw_envvars, list):
        raise SandboxError("'envvars' must be a list of tables")
    for index, item in enumerate(raw_envvars):
        if not isinstance(item, dict):
            raise SandboxError(f"'envvars[{index}]' must be a table")

        name = item.get("name")
        if not isinstance(name, str) or not name:
            raise SandboxError(f"'envvars[{index}].name' must be a non-empty string")

        value = item.get("value")
        if value is None:
            value = env(name)
        if value is None:
            raise SandboxError(f"environment variable is not set: {name}")
        if not isinstance(value, str):
            raise SandboxError(f"'envvars[{index}].value' must be a string")

        values[name] = value

    if options.docker and (docker_host := env("DOCKER_HOST")):
        values["DOCKER_HOST"] = docker_host

    values["BWRAP_AGENT_SANDBOX"] = "1"
    values["HOME"] = values.get("HOME", str(home))
    values["PATH"] = values.get("PATH", "/usr/local/bin:/usr/bin:/bin")
    values["PWD"] = str(cwd)
    values["SHELL"] = values.get("SHELL", pwd.getpwuid(os.getuid()).pw_shell)
    values["USER"] = values.get("USER", pwd.getpwuid(os.getuid()).pw_name)
    values["LOGNAME"] = values.get("LOGNAME", values["USER"])
    values["XDG_RUNTIME_DIR"] = values.get("XDG_RUNTIME_DIR", str(runtime_dir))
    if profile.gui:
        values.setdefault("MOZ_ENABLE_WAYLAND", "1")

    if virtual_env := values.get("VIRTUAL_ENV"):
        venv_bin = str(Path(virtual_env) / "bin")
        path_parts = values["PATH"].split(":")
        if venv_bin not in path_parts:
            values["PATH"] = ":".join([venv_bin, *path_parts])

    result: list[str] = []
    for name, value in values.items():
        result.extend(("--setenv", name, value))

    for item in options.extra_env_vars:
        if "=" in item:
            name, value = item.split("=", 1)
        else:
            name = item
            value = env(name)
            if value is None:
                raise SandboxError(f"environment variable is not set: {name}")
        result.extend(("--setenv", name, value))

    return result



def build_bwrap_args(
    binds: Sequence[Mount],
    command: Sequence[str],
    options: argparse.Namespace,
    profile: AgentProfile,
    features: BwrapFeatures,
    env_args: Sequence[str],
    cwd: Path,
) -> list[str]:
    """Assemble the complete bwrap command line."""
    args = ["bwrap", "--unshare-all"]

    if profile.network and not options.no_network:
        args.append("--share-net")

    if not options.allow_userns and features.disable_userns:
        args.extend(("--unshare-user", "--disable-userns"))

    if features.cap_drop:
        args.extend(("--cap-drop", "ALL"))

    if features.new_session and not options.no_new_session:
        args.append("--new-session")

    if features.hostname:
        args.extend(("--hostname", "bwrap-agent"))

    args.extend(("--clearenv", "--die-with-parent", "--chdir", str(cwd)))
    args.extend(get_bind_args(binds))
    args.extend(env_args)
    args.extend(("--", *command))
    return args


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Sandbox AI agents using bubblewrap",
        epilog=(
            "Configuration is read from ~/.config/bwrap-agent.toml "
            "(or $XDG_CONFIG_HOME/bwrap-agent.toml)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    parser.add_argument("--debug", action="store_true", help="enable debug logging")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the bwrap command instead of executing it",
    )
    parser.add_argument(
        "--config",
        type=Path,
        metavar="PATH",
        help="configuration file to use instead of the default",
    )
    parser.add_argument(
        "--gui",
        action="store_true",
        help="expose display server sockets to the agent",
    )
    parser.add_argument(
        "--cwd-read-only",
        action="store_true",
        help="bind the current directory read-only",
    )
    parser.add_argument(
        "-b",
        "--bind",
        dest="extra_rw_binds",
        action="append",
        default=[],
        metavar="PATH",
        help="bind PATH read-write (may be repeated)",
    )
    parser.add_argument(
        "-rb",
        "--ro-bind",
        dest="extra_ro_binds",
        action="append",
        default=[],
        metavar="PATH",
        help="bind PATH read-only (may be repeated)",
    )
    parser.add_argument(
        "-e",
        "--env",
        dest="extra_env_vars",
        action="append",
        default=[],
        metavar="NAME[=VALUE]",
        help="pass an environment variable into the sandbox (may be repeated)",
    )
    parser.add_argument(
        "--no-network",
        action="store_true",
        help="run without network access",
    )
    parser.add_argument(
        "--allow-userns",
        action="store_true",
        help="allow the sandboxed process to create nested user namespaces",
    )
    parser.add_argument(
        "--no-new-session",
        action="store_true",
        help="do not detach the sandbox from the controlling terminal",
    )
    parser.add_argument(
        "--docker",
        action="store_true",
        help="expose the Docker socket to the sandbox",
    )
    parser.add_argument(
        "--no-ssh-agent",
        action="store_true",
        help="do not provide a filtered ssh-agent to the sandbox",
    )
    parser.add_argument(
        "--no-dbus",
        action="store_true",
        help="do not provide a filtered D-Bus connection to the sandbox",
    )
    parser.add_argument(
        "--shell",
        action="store_true",
        help="run a shell inside the sandbox instead of an agent",
    )
    parser.add_argument(
        "agent",
        nargs="?",
        help="agent command to run (for example: cursor-agent, opencode, claude)",
    )
    parser.add_argument(
        "agent_args",
        nargs=argparse.REMAINDER,
        help="arguments forwarded to the agent",
    )
    return parser


def validate_environment() -> None:
    if shutil.which("bwrap") is None:
        raise SandboxError("bubblewrap (bwrap) was not found in PATH")


def run(options: argparse.Namespace) -> int:
    validate_environment()
    features = detect_bwrap_features()

    home = Path.home()
    cwd = Path.cwd()
    runtime_dir = Path(env("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    config_path = (
        expand_path(options.config, home) if options.config else default_config_path()
    )
    config = load_config(config_path)

    agent = options.agent
    if options.shell:
        agent_args = ([agent] if agent else []) + list(options.agent_args)
        profile = get_agent_profile("", config, shell=True)
        command = resolve_command(profile, agent_args)
    else:
        if not agent:
            raise SandboxError("an agent command is required (or use --shell)")
        profile = get_agent_profile(agent, config)
        command = resolve_command(profile, options.agent_args)

    if options.gui:
        profile = replace(profile, gui=True)

    binds = get_default_binds(
        profile,
        home,
        runtime_dir,
        docker=options.docker,
    )
    binds.extend(get_config_binds(config, home))
    binds.extend(get_extra_binds(options, home))
    ensure_cwd_in_sandbox(
        binds,
        config_path=config_path,
        options=options,
        home=home,
    )
    binds.extend(get_config_whiteouts(config, home))

    with tempfile.TemporaryDirectory(prefix="bwrap-agent-") as tmp_path:
        session_dir = Path(tmp_path)

        with ExitStack() as stack:
            ssh_agent: SshAgent | None = None
            if not options.no_ssh_agent:
                ssh_agent = stack.enter_context(SshAgent(session_dir))
                if (
                    ssh_agent.socket is not None
                    and not options.dry_run
                    and (key := find_sandbox_ssh_key())
                ):
                    ssh_agent.add_key(key)

            dbus_proxy: DBusProxy | None = None
            if not options.no_dbus:
                dbus_proxy = stack.enter_context(DBusProxy(session_dir))

            if ssh_agent is not None and ssh_agent.socket is not None:
                binds.append(ROBindConfig(ssh_agent.socket))

            if dbus_proxy is not None and dbus_proxy.socket is not None:
                binds.append(ROBindConfig(dbus_proxy.socket))

            binds = dedupe_binds(binds)

            env_args = get_env_args(profile, options, config, home, runtime_dir, cwd)
            if ssh_agent is not None and ssh_agent.socket is not None:
                env_args.extend(("--setenv", "SSH_AUTH_SOCK", str(ssh_agent.socket)))
            if dbus_proxy is not None and dbus_proxy.socket is not None:
                env_args.extend(
                    (
                        "--setenv",
                        "DBUS_SESSION_BUS_ADDRESS",
                        f"unix:path={dbus_proxy.socket}",
                    )
                )

            bwrap_args = build_bwrap_args(
                binds,
                command,
                options,
                profile,
                features,
                env_args,
                cwd,
            )

            if options.debug:
                logging.debug("Running:\n  %s", shlex.join(bwrap_args))

            if options.dry_run:
                print(shlex.join(bwrap_args))
                return 0

            try:
                return subprocess.run(bwrap_args, check=False).returncode
            except OSError as exc:
                raise SandboxError(f"failed to execute bwrap: {exc}") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    options = parser.parse_args(argv)

    logging.basicConfig(
        level="DEBUG" if options.debug else "WARNING",
        format="%(levelname)s: %(message)s",
    )

    try:
        return run(options)
    except SandboxError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())

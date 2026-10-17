#!/usr/bin/python3
"""Bubblewrap sandbox wrapper for AI agents.

This script runs an AI agent in a bubblewrap sandbox. It exposes only the parts of the host
filesystem that are needed for the agent, its configuration, and the current project. All
namespaces are unshared and the environment is cleared before the agent is started.

Use `bwrap_agent.py --help` for usage information.
"""

import argparse
import logging
import os
import pwd
import re
import shlex
import shutil
import subprocess
import sys
from collections.abc import Iterator, Sequence
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
            try:
                path.mkdir(parents=True)
            except OSError:
                # A missing optional directory is harmless; __iter__ skips it.
                pass

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
            current = Path.home() / ".local/share/cursor-agent/versions/current/cursor-agent"
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


def get_agent_profile(agent: str, shell: bool = False) -> AgentProfile:
    """Resolve an agent name to a profile."""
    if shell:
        shell_path = env("SHELL") or pwd.getpwuid(os.getuid()).pw_shell
        return AgentProfile(name="shell", command=(shell_path,))

    name = Path(agent).name
    profile = builtin_profile(name) or generic_profile(name)

    if profile.command == (name,) and agent != name:
        profile = replace(profile, command=(agent,))

    return profile


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
    binds.append(ROBindConfig("/tmp/.X11-unix") if env("DISPLAY") else ())

    if wayland_display := env("WAYLAND_DISPLAY"):
        wayland_path = Path(wayland_display)
        if not wayland_path.is_absolute():
            wayland_path = runtime_dir / wayland_path
        binds.append(ROBindConfig(wayland_path))

    if xauthority := env("XAUTHORITY"):
        binds.append(ROBindConfig(xauthority))
    if env("DISPLAY"):
        binds.append(ROBindConfig(home / ".Xauthority"))

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
        binds.append(RWBindConfig(home / ".virtualenvs", create=False))

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


def add_cwd_bind(binds: list[Mount], home: Path) -> None:
    """Make the current directory writable inside the sandbox."""
    cwd = Path.cwd()

    if is_broad_path(cwd, home):
        raise SandboxError(f"refusing to bind {cwd} read-write; run from a project directory")

    for bind in binds:
        if (
            isinstance(bind, BasicBindConfig)
            and bind.writable
            and bind.covers_path(cwd)
        ):
            return

    binds.append(RWBindConfig(cwd, create=False))


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


def get_env_args(
    profile: AgentProfile,
    options: argparse.Namespace,
    home: Path,
    runtime_dir: Path,
    cwd: Path,
) -> list[str]:
    """Build the explicit environment for the sandbox."""
    values = {
        name: value
        for name in ENV_VARS_TO_SHARE
        if (value := env(name)) is not None
    }

    for name in profile.env:
        if (value := env(name)) is not None:
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

    agent = options.agent
    if options.shell:
        agent_args = ([agent] if agent else []) + list(options.agent_args)
        profile = get_agent_profile("", shell=True)
        command = resolve_command(profile, agent_args)
    else:
        if not agent:
            raise SandboxError("an agent command is required (or use --shell)")
        profile = get_agent_profile(agent)
        command = resolve_command(profile, options.agent_args)

    binds = get_default_binds(
        profile,
        home,
        runtime_dir,
        docker=options.docker,
    )
    binds.extend(get_extra_binds(options, home))
    add_cwd_bind(binds, home)
    binds = dedupe_binds(binds)

    env_args = get_env_args(profile, options, home, runtime_dir, cwd)
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

    logging.basicConfig(level="DEBUG" if options.debug else "WARNING")

    try:
        return run(options)
    except SandboxError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

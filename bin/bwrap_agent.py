#!/usr/bin/env python3
"""Bubblewrap sandbox wrapper for AI agents.

See also https://patrickmccanna.net/a-detailed-writeup-of-claude-code-constrained-by-bubblewrap/

This script creates a sandboxed environment for running AI agent commands using bubblewrap,
restricting filesystem access while preserving necessary environment variables and paths.
"""

import argparse
import os
import shlex
import shutil
from dataclasses import dataclass, field
from pathlib import Path


# Environment variables grouped by purpose
DISPLAY_VARS = [
    "DISPLAY",
    "WAYLAND_DISPLAY",
    "MOZ_ENABLE_WAYLAND",
    "XCURSOR_SIZE",
    "XDG_SESSION_TYPE",
]

SHELL_VARS = [
    "HOME",
    "PATH",
    "SHELL",
    "TERM",
    "TERMINFO",
    "TERM_PROGRAM",
    "EDITOR",
]

LOCALE_VARS = [
    "LANG",
    "LC_NUMERIC",
    "LC_TIME",
]

XDG_VARS = [
    "XDG_RUNTIME_DIR",
    "XDG_CONFIG_HOME",
]

DEV_VARS = [
    "ASDF_DIR",
    "BUN_INSTALL",
    "PIP_REQUIRE_VIRTUALENV",
    "VIRTUALENVWRAPPER_PYTHON",
    "VIRTUALENVWRAPPER_SCRIPT",
    "_VIRTUALENVWRAPPER_API",
    "VIRTUAL_ENV",
]

ENV_VARS_TO_SHARE = (
    DISPLAY_VARS + SHELL_VARS + LOCALE_VARS + XDG_VARS + DEV_VARS + ["COLORTERM"]
)

# System paths that are always mounted read-only
SYSTEM_RO_BINDS = [
    Path("/usr"),
    Path("/lib"),
    Path("/lib64"),
    Path("/bin"),
    Path("/etc/resolv.conf"),
    Path("/etc/hosts"),
    Path("/etc/ssl"),
    Path("/etc/passwd"),
    Path("/etc/group"),
    Path("/etc/alternatives"),
]

# Dotfile paths relative to home - read-only (for tools/configs)
DOTFILE_RO_BINDS = [
    ".nvm",
    ".npm",
    ".npmrc",
    ".asdf",
    ".tool-versions",
    ".bun",
    ".config/git",
    ".config/agents",
    ".agents",
]

# Dotfile paths relative to home - read-write (for state/cache)
DOTFILE_RW_BINDS = [
    ".cache",
]

# Agent-specific configurations
AGENT_CONFIGS = {
    "cursor": {
        "rw_paths": [
            ".local/share/cursor-agent",
            ".config/Cursor",
            "/opt/cursor-agent",
            "/usr/share/cursor",
        ],
    },
}

env = os.getenv


@dataclass
class BindConfig:
    """Configuration for a bind mount.

    Attributes:
        source: Path to bind mount
        read_only: Whether the mount should be read-only
        required: If True, fail if path doesn't exist (reserved for future use)
    """

    source: Path
    read_only: bool = True
    required: bool = False


@dataclass
class SandboxConfig:
    """Parsed CLI configuration.

    Attributes:
        agent: Name of the agent command to run
        agent_args: Additional arguments to pass to the agent
        extra_rw_binds: Extra paths to bind read-write
        extra_ro_binds: Extra paths to bind read-only
        extra_env_vars: Extra environment variables to share
    """

    agent: str
    agent_args: list[str] = field(default_factory=list)
    extra_rw_binds: list[Path] = field(default_factory=list)
    extra_ro_binds: list[Path] = field(default_factory=list)
    extra_env_vars: list[str] = field(default_factory=list)


def expand_path(value: str) -> str:
    """Expand user home directory in path."""
    return os.path.expanduser(value)


def bind(config: BindConfig) -> list[str]:
    if config.source.exists():
        flag = "--ro-bind" if config.read_only else "--bind"
        return [flag, str(config.source), str(config.source)]
    return []


def parse_arguments() -> SandboxConfig:
    """Parse and validate CLI arguments.

    Returns:
        SandboxConfig with parsed arguments

    Raises:
        SystemExit: If required arguments are missing
    """
    parser = argparse.ArgumentParser(
        description="Sandbox AI agents using bubblewrap",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-b",
        "--bind",
        dest="extra_rw_binds",
        action="append",
        default=[],
        help="Extra paths to bind read-write (can be specified multiple times)",
    )
    parser.add_argument(
        "-rb",
        "--ro-bind",
        dest="extra_ro_binds",
        action="append",
        default=[],
        help="Extra paths to bind read-only (can be specified multiple times)",
    )
    parser.add_argument(
        "-e",
        "--env",
        dest="extra_env_vars",
        action="append",
        default=[],
        help="Extra environment variables to share (can be specified multiple times)",
    )
    parser.add_argument(
        "agent",
        help="Agent command to run (e.g., cursor, claude, custom-agent)",
    )
    parser.add_argument(
        "agent_args",
        nargs="*",
        help="Additional arguments to pass to the agent",
    )

    parsed = parser.parse_args()

    # Expand paths in extra binds
    extra_rw = [Path(expand_path(p)) for p in parsed.extra_rw_binds if p]
    extra_ro = [Path(expand_path(p)) for p in parsed.extra_ro_binds if p]

    return SandboxConfig(
        agent=parsed.agent,
        agent_args=parsed.agent_args or [],
        extra_rw_binds=extra_rw,
        extra_ro_binds=extra_ro,
        extra_env_vars=parsed.extra_env_vars or [],
    )


def validate_environment() -> None:
    if not shutil.which("bwrap"):
        raise SystemExit(
            "Error: bubblewrap (bwrap) not found in PATH. Please install bubblewrap."
        )


def get_system_binds() -> list[list[str]]:
    """Generate bind arguments for system paths.

    Returns:
        list of bind argument lists for system paths
    """
    binds = []
    for path in SYSTEM_RO_BINDS:
        binds.append(bind(BindConfig(path, read_only=True)))
    return binds


def get_dotfile_binds(home: Path) -> list[list[str]]:
    """Generate bind arguments for dotfile paths.

    Args:
        home: Path to home directory

    Returns:
        list of bind argument lists for dotfile paths
    """
    binds = []

    for dotfile in DOTFILE_RO_BINDS:
        binds.append(bind(BindConfig(home / dotfile, read_only=True)))

    for dotfile in DOTFILE_RW_BINDS:
        binds.append(bind(BindConfig(home / dotfile, read_only=False)))

    binds.append(bind(BindConfig(home / ".gitconfig", read_only=True)))
    binds.append(bind(BindConfig(home / ".local", read_only=True)))
    binds.append(bind(BindConfig(home / ".virtualenvs", read_only=True)))
    binds.append(bind(BindConfig(home / "nvim", read_only=True)))

    return binds


def get_agent_binds(
    agent_name: str, home: Path, xdg_runtime_dir: str | None
) -> list[list[str]]:
    """Generate bind arguments for agent-specific paths.

    Args:
        agent_name: Name of the agent
        home: Path to home directory
        xdg_runtime_dir: XDG runtime directory path (if set)

    Returns:
        list of bind argument lists for agent paths
    """
    binds = []

    # cursor cli is 'agent' or 'cursor-agent'
    if agent_name in {"cursor", "cursor-agent", "agent"}:
        config_key = "cursor"
    else:
        config_key = agent_name

    agent_config = AGENT_CONFIGS.get(config_key, {})
    for path_str in agent_config.get("rw_paths", []):
        path = Path(path_str) if path_str.startswith("/") else home / path_str
        binds.append(bind(BindConfig(path, read_only=False)))

    # Add XDG runtime dir if available (needed for some GUI agents)
    if xdg_runtime_dir:
        binds.append(bind(BindConfig(Path(xdg_runtime_dir), read_only=False)))

    # Add standard agent paths (home-relative)
    for subpath in [
        f".config/{config_key}",
        f".local/share/{config_key}",
        f".{config_key}",
    ]:
        binds.append(bind(BindConfig(home / subpath, read_only=False)))

    return binds


def get_extra_binds(paths: list[Path], read_only: bool) -> list[list[str]]:
    """Generate bind arguments for extra user-specified paths.

    Args:
        paths: list of paths to bind
        read_only: Whether to bind read-only

    Returns:
        list of bind argument lists
    """
    binds = []
    for path in paths:
        binds.append(bind(BindConfig(path, read_only=read_only)))
    return binds


def environment_args(env_vars: dict[str, str]) -> list[str]:
    """Generate --setenv arguments for bwrap.

    Args:
        env_vars: Environment dictionary

    Returns:
        Flattened list of --setenv arguments
    """
    args = []

    for var_name, value in env_vars.items():
        if value:
            args.extend(["--setenv", var_name, value])

    # Always set MOZ_ENABLE_WAYLAND if not already set
    if not env("MOZ_ENABLE_WAYLAND"):
        args.extend(["--setenv", "MOZ_ENABLE_WAYLAND", "1"])

    return args


def build_shell_command(agent_cmd: str, agent_args: list[str]) -> str:
    """Build the shell command to execute inside the sandbox.

    Conditionally adds virtual environment activation if relevant env vars exist.

    Args:
        agent_cmd: Path to agent command
        agent_args: Additional arguments for the agent

    Returns:
        Shell command string
    """
    setup_parts = []

    venv_wrapper = env("VIRTUALENVWRAPPER_SCRIPT")
    if venv_wrapper:
        setup_parts.append(f"source {shlex.quote(venv_wrapper)}")

    virtual_env = env("VIRTUAL_ENV")
    if virtual_env:
        setup_parts.append(f"source {shlex.quote(virtual_env)}/bin/activate")

    exec_parts = [shlex.quote(agent_cmd)]
    exec_parts.extend(shlex.quote(arg) for arg in agent_args)
    exec_cmd = "exec " + " ".join(exec_parts)

    if setup_parts:
        return " && ".join(setup_parts) + " && " + exec_cmd
    else:
        return exec_cmd


def build_environment_dict(extra_vars: list[str]) -> dict:
    """Build environment dictionary for execvpe.

    Args:
        extra_vars: Additional environment variables to include

    Returns:
        Dictionary of environment variables
    """
    all_vars = ENV_VARS_TO_SHARE + extra_vars
    env_dict = {}

    for var_name in all_vars:
        value = env(var_name)
        if value is not None:
            env_dict[var_name] = value

    # Always include MOZ_ENABLE_WAYLAND
    env_dict["MOZ_ENABLE_WAYLAND"] = "1"

    return env_dict


def execute_bwrap(bwrap_args: list[str], env: dict) -> None:
    """Execute bwrap with the given arguments.

    Args:
        bwrap_args: Complete list of arguments for bwrap
        env: Environment dictionary

    Raises:
        SystemExit: If exec fails
    """
    try:
        os.execvpe("bwrap", bwrap_args, env)
    except OSError as e:
        raise SystemExit(f"Failed to execute bwrap: {e}")


def main() -> None:
    config = parse_arguments()

    validate_environment()

    home = Path.home()
    cwd = Path.cwd()
    xdg_runtime_dir = env("XDG_RUNTIME_DIR") or None

    bind_args = []

    for bind_list in get_system_binds():
        bind_args.extend(bind_list)

    for bind_list in get_dotfile_binds(home):
        bind_args.extend(bind_list)

    for bind_list in get_agent_binds(config.agent, home, xdg_runtime_dir):
        bind_args.extend(bind_list)

    for bind_list in get_extra_binds(config.extra_rw_binds, read_only=False):
        bind_args.extend(bind_list)
    for bind_list in get_extra_binds(config.extra_ro_binds, read_only=True):
        bind_args.extend(bind_list)

    bind_args.extend(bind(BindConfig(cwd, read_only=False)))

    env_dict = build_environment_dict(config.extra_env_vars)
    env_args = environment_args(env_dict)

    command = shutil.which(config.agent) or config.agent
    exec_cmd = build_shell_command(command, config.agent_args)

    shell = env("SHELL", "/bin/bash")

    bwrap_args = [
        "bwrap",
        *bind_args,
        "--tmpfs",
        "/tmp",
        "--proc",
        "/proc",
        "--dev",
        "/dev",
        "--share-net",
        "--unshare-pid",
        "--die-with-parent",
        "--chdir",
        str(cwd),
        *env_args,
        "--",
        shell,
        "-c",
        exec_cmd,
    ]

    execute_bwrap(bwrap_args, env_dict)


if __name__ == "__main__":
    main()

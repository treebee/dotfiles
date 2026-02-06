#!/usr/bin/env python3

# Taken from https://patrickmccanna.net/a-detailed-writeup-of-claude-code-constrained-by-bubblewrap/
# and adapted as needed

import argparse
import os
import shutil
from pathlib import Path


env = os.getenv

def expand_path(value: str) -> str:
    return os.path.expanduser(value)


ENV_VARS_TO_SHARE = [
"EDITOR",
"XDG_RUNTIME_DIR",
"WAYLAND_DISPLAY",
]

def _add_bind(flag: str, path: Path) -> None:
    if path.exists():
        return [flag, str(path), str(path)]
    return []


def bind(path: Path) -> None:
    return _add_bind("--bind", path)


def ro_bind(path: Path) -> None:
    return _add_bind("--ro-bind", path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-b", "--bind", dest="extra_rw_binds", action="append", default=[])
    parser.add_argument("-rb", "--ro-bind", dest="extra_ro_binds", action="append", default=[])
    parser.add_argument("agent_cmd_arg", nargs="?")
    parser.add_argument("agent_args", nargs=argparse.REMAINDER)
    parsed, extra_args = parser.parse_known_args()

    if parsed.agent_cmd_arg:
        agent_cmd_arg = parsed.agent_cmd_arg
        remaining_args = parsed.agent_args
    elif extra_args:
        agent_cmd_arg = extra_args[0]
        remaining_args = extra_args[1:]
    else:
        raise SystemExit("Missing agent command argument.")

    extra_rw_binds = [expand_path(value) for value in parsed.extra_rw_binds if value]
    extra_ro_binds = [expand_path(value) for value in parsed.extra_ro_binds if value]

    optional_binds: list[str] = []
    home = Path.home()
    xdg_runtime_dir = env("XDG_RUNTIME_DIR", "")

    env_vars = [("--setenv", ev, env(ev, "")) for ev in ENV_VARS_TO_SHARE]


    env_agent_cmd = env("AGENT_CMD", "")
    if env_agent_cmd in {"cursor", "cursor-agent", "agent"}:
        agent = "cursor"
        optional_binds.extend(bind(Path(home / ".local/share/cursor-agent")))
        optional_binds.extend(bind(Path(home / ".config/Cursor")))
        optional_binds.extend(bind(Path("/opt/cursor-agent")))
        optional_binds.extend(bind(Path("/usr/share/cursor")))
        # TODO check this again
        # bind(Path("/sys"))
        # bind(Path("/run/dbus"))
        if xdg_runtime_dir:
            optional_binds.extend(bind(Path(xdg_runtime_dir)))
    else:
        agent = agent_cmd_arg

    optional_binds.extend(ro_bind(home / ".nvm"))
    optional_binds.extend(ro_bind(home / ".config/agents"))
    optional_binds.extend(ro_bind(home / ".agents"))
    optional_binds.extend(bind(home / f".config/{agent}"))
    optional_binds.extend(bind(home / f".local/share/{agent}"))
    optional_binds.extend(bind(home / f".{agent}"))
    optional_binds.extend(ro_bind(home / ".npm"))
    optional_binds.extend(ro_bind(home / ".config/git"))
    optional_binds.extend(ro_bind(home / ".asdf"))
    optional_binds.extend(ro_bind(Path("/etc/alternatives")))
    optional_binds.extend(bind(home / ".virtualenvs"))

    optional_binds.extend(ro_bind(home / ".tool-versions"))
    optional_binds.extend(ro_bind(home / ".npmrc"))
    optional_binds.extend(ro_bind(home / ".bun"))

    for bind_path in extra_rw_binds:
        path = Path(bind_path)
        if path.exists():
            optional_binds.extend(bind(path))

    for bind_path in extra_ro_binds:
        path = Path(bind_path)
        if path.exists():
            optional_binds.extend(ro_bind(path))

    command = shutil.which(agent_cmd_arg) or agent_cmd_arg
    cwd = os.getcwd()

    bwrap_args = [
        "bwrap",
        *ro_bind(Path("/usr")),
        *ro_bind(Path("/lib")),
        *ro_bind(Path("/lib64")),
        *ro_bind(Path("/bin")),
        *ro_bind(Path("/etc/resolv.conf")),
        *ro_bind(Path("/etc/hosts")),
        *ro_bind(Path("/etc/ssl")),
        *ro_bind(Path("/etc/passwd")),
        *ro_bind(Path("/etc/group")),
        *ro_bind(home / ".gitconfig"),
        *ro_bind(home / ".local"),
        *ro_bind(home / "nvim"),
        *optional_binds,
        *bind(home / ".cache"),
        *bind(Path(cwd)),
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
        cwd,
        "--setenv",
        "MOZ_ENABLE_WAYLAND",
        "1",
    ]

    for ev in env_vars:
        bwrap_args += ev

    bwrap_args += [
        command,
        *remaining_args,
    ]
    print(bwrap_args)
    environment = {k: v for k, v in os.environ.items() if k in ENV_VARS_TO_SHARE}
    environment.update({"MOZ_ENABLE_WAYLAND": "1"})

    os.execvpe("bwrap", bwrap_args, environment)


if __name__ == "__main__":
    main()

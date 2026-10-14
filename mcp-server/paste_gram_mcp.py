# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.2"]
# ///
"""MCP server that lets AI agents send text and files to Telegram via paste-gram.

The server wraps the paste-gram Fish function instead of reimplementing it, so
chunking, compression, captions, and MTProto guardrails behave exactly like the
CLI. It adds agent-specific guardrails on top: uploaded paths must sit under an
allowed root and must not look like credentials, and destinations are limited
to the default chat and aliases from the paste-gram alias map unless the user
opts in to arbitrary targets.
"""

from __future__ import annotations

import fnmatch
import html as html_lib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Literal

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

SERVER_DIR = Path(__file__).resolve().parent
BUNDLED_FUNCTION = SERVER_DIR.parent / "functions" / "paste-gram.fish"

# Names that commonly hold secrets; refuse them even under an allowed root.
DENIED_NAME_PATTERNS = (
    ".ssh", ".gnupg", ".aws", ".azure", ".kube", ".docker", ".netrc", ".pgpass",
    ".npmrc", ".pypirc", ".git-credentials", ".env", ".env.*", "*.pem", "*.key",
    "*.p12", "*.pfx", "id_rsa*", "id_ed25519*", "id_ecdsa*", "id_dsa*",
    "*.session", "*.session-journal", "fish_variables", "credentials*",
)
ANSI_PATTERN = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
TRUE_VALUES = {"1", "true", "yes"}

Transport = Literal["default", "bot", "mtproto"]

mcp = FastMCP(
    "paste-gram",
    instructions=(
        "Sends text, command output, files, and directories to the user's Telegram "
        "through the paste-gram CLI. Sending is outward-facing: only send content the "
        "user asked to send, to the destination they asked for. Omit `targets` to use "
        "the user's default chat. Call list_targets to resolve a named destination, and "
        "check_setup when a send fails because of configuration."
    ),
)

SEND_ANNOTATIONS = ToolAnnotations(
    readOnlyHint=False, destructiveHint=False, idempotentHint=False, openWorldHint=True
)
READ_ANNOTATIONS = ToolAnnotations(readOnlyHint=True, openWorldHint=False)


def _env_flag(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in TRUE_VALUES


def _function_file() -> str:
    configured = os.environ.get("PASTEGRAM_MCP_FUNCTION_FILE")
    if configured is not None:
        return configured
    return str(BUNDLED_FUNCTION) if BUNDLED_FUNCTION.is_file() else ""


def _timeout() -> float:
    try:
        return float(os.environ.get("PASTEGRAM_MCP_TIMEOUT", "900"))
    except ValueError:
        return 900.0


def _run_fish(script: str, args: list[str], stdin_text: str | None = None) -> subprocess.CompletedProcess[str]:
    fish = shutil.which("fish")
    if fish is None:
        raise RuntimeError("fish is not installed or not on PATH")
    env = os.environ.copy()
    env["PASTEGRAM_MCP_FUNCTION_FILE"] = _function_file()
    # Prefer the bundled function so the server and CLI flags stay in sync;
    # fall back to the user's installed paste-gram when it is not available.
    prelude = (
        'if test -n "$PASTEGRAM_MCP_FUNCTION_FILE"; and test -f "$PASTEGRAM_MCP_FUNCTION_FILE"\n'
        '  source "$PASTEGRAM_MCP_FUNCTION_FILE"\n'
        "end\n"
    )
    return subprocess.run(
        [fish, "-c", prelude + script, "--", *args],
        input=stdin_text if stdin_text is not None else "",
        capture_output=True,
        text=True,
        timeout=_timeout(),
        env=env,
    )


def _alias_map_path() -> Path:
    configured = os.environ.get("PASTEGRAM_ID_MAP")
    if configured:
        return Path(configured).expanduser()
    return Path.home() / ".config" / "paste-gram" / "chat_ids.json"


def _load_aliases() -> dict[str, object]:
    path = _alias_map_path()
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def _check_targets(targets: list[str] | None) -> list[str]:
    if not targets:
        return []
    cleaned = [t.strip() for raw in targets for t in raw.split(",") if t.strip()]
    if _env_flag("PASTEGRAM_MCP_ALLOW_ANY_TARGET"):
        return cleaned
    aliases = _load_aliases()
    rejected = [t for t in cleaned if t != "me" and t not in aliases]
    if rejected:
        raise ValueError(
            "Unknown target(s): " + ", ".join(rejected) + ". Use an alias from list_targets, "
            "'me', or omit targets for the default chat. Raw chat IDs and usernames require "
            "the user to set PASTEGRAM_MCP_ALLOW_ANY_TARGET=true."
        )
    return cleaned


def _allowed_roots() -> list[Path]:
    configured = os.environ.get("PASTEGRAM_MCP_ALLOWED_ROOTS", "")
    roots = [Path(p).expanduser() for p in configured.split(os.pathsep) if p.strip()]
    if not roots:
        roots = [Path.cwd()]
    return [r.resolve() for r in roots]


def _is_denied(path: Path) -> bool:
    return any(
        fnmatch.fnmatch(part.lower(), pattern) for part in path.parts for pattern in DENIED_NAME_PATTERNS
    )


def _check_paths(paths: list[str]) -> list[str]:
    if not paths:
        raise ValueError("paths must contain at least one file or directory")
    roots = _allowed_roots()
    resolved: list[str] = []
    for raw in paths:
        # Resolve symlinks so a link inside a root cannot point outside it.
        path = Path(raw).expanduser()
        if not path.is_absolute():
            path = Path.cwd() / path
        path = path.resolve()
        if not path.exists():
            raise ValueError(f"Path not found: {raw}")
        if not any(path == root or path.is_relative_to(root) for root in roots):
            raise ValueError(
                f"Path is outside the allowed roots ({', '.join(map(str, roots))}): {raw}. "
                "The user can widen PASTEGRAM_MCP_ALLOWED_ROOTS."
            )
        if _is_denied(path):
            raise ValueError(f"Refusing to send a path that looks like credentials or secrets: {raw}")
        if path.is_dir():
            for child in path.rglob("*"):
                if _is_denied(child.relative_to(path)):
                    raise ValueError(
                        f"Refusing to send {raw}: it contains a credential-like entry "
                        f"({child.relative_to(path)})"
                    )
        resolved.append(str(path))
    return resolved


def _common_flags(targets: list[str], transport: Transport) -> list[str]:
    flags: list[str] = []
    if transport == "bot":
        flags.append("--bot")
    elif transport == "mtproto":
        flags.append("--mtproto")
    flags.extend(f"--id={target}" for target in targets)
    return flags


def _result(proc: subprocess.CompletedProcess[str]) -> dict[str, object]:
    stdout = ANSI_PATTERN.sub("", proc.stdout)
    stderr = ANSI_PATTERN.sub("", proc.stderr)
    lines = [line.strip() for line in (stdout + "\n" + stderr).splitlines() if line.strip()]
    sent = [line.removeprefix("✓").strip() for line in lines if line.startswith("✓")]
    errors = [line.removeprefix("❌").strip() for line in lines if line.startswith("❌")]
    result: dict[str, object] = {"ok": proc.returncode == 0, "exit_code": proc.returncode, "sent": sent}
    if errors or proc.returncode != 0:
        result["errors"] = errors or stderr.strip().splitlines()[-10:]
    return result


def _send(args: list[str], stdin_text: str | None = None) -> dict[str, object]:
    try:
        proc = _run_fish("paste-gram $argv", args, stdin_text)
    except subprocess.TimeoutExpired:
        return {"ok": False, "exit_code": None, "sent": [], "errors": [f"Timed out after {_timeout():.0f}s"]}
    except RuntimeError as exc:
        return {"ok": False, "exit_code": None, "sent": [], "errors": [str(exc)]}
    return _result(proc)


@mcp.tool(annotations=SEND_ANNOTATIONS)
def send_message(
    text: str,
    html: bool = False,
    targets: list[str] | None = None,
    transport: Transport = "default",
) -> dict[str, object]:
    """Send a text message to Telegram.

    Plain text is sent in a code block and long text is split automatically.
    Set html=true to render Telegram HTML (<b>, <i>, <code>, <a href>, ...);
    tags must be balanced and literal &, <, > escaped as &amp;, &lt;, &gt;.
    Omit targets to use the user's default chat; otherwise pass aliases from
    list_targets or 'me'. transport overrides the user's default (bot/mtproto).
    """
    if not text.strip():
        raise ValueError("text must not be empty")
    flags = _common_flags(_check_targets(targets), transport)
    if not html:
        # Escape plain text into a code block ourselves; the CLI's stdin path
        # rewrites < and > while --html keeps it verbatim and chunk-safe.
        text = f"<pre>{html_lib.escape(text, quote=False)}</pre>"
    # The --message= form is never mistaken for a file path or another flag.
    return _send([*flags, "--html", f"--message={text}"])


@mcp.tool(annotations=SEND_ANNOTATIONS)
def send_files(
    paths: list[str],
    caption: str | None = None,
    caption_html: bool = False,
    archive_name: str | None = None,
    targets: list[str] | None = None,
    transport: Transport = "default",
) -> dict[str, object]:
    """Send one or more files or directories to Telegram as documents.

    A single file is sent as-is; a directory, or several paths, are packed
    into one .tgz archive (named archive_name, or a timestamped default).
    Files over 50MB are compressed and split automatically in Bot API mode.
    Paths must be under the allowed roots (the server's working directory by
    default), and credential-like files are refused.
    """
    resolved = _check_paths(paths)
    flags = _common_flags(_check_targets(targets), transport)
    if caption:
        if caption_html:
            flags.append("--html")
        flags.append(f"--message={caption}")
    elif caption_html:
        raise ValueError("caption_html requires a caption")
    if archive_name:
        if len(resolved) < 2:
            raise ValueError("archive_name only applies when sending multiple paths")
        flags.append(f"--file-name={archive_name}")
    return _send([*flags, "--", *resolved])


@mcp.tool(annotations=READ_ANNOTATIONS)
def list_targets() -> dict[str, object]:
    """List destination aliases from the paste-gram alias map.

    Use these names in the targets argument of send tools. Omitting targets
    sends to the user's default chat.
    """
    aliases = []
    for name, value in _load_aliases().items():
        username = value.get("username") if isinstance(value, dict) else None
        aliases.append({"alias": name, "username": username})
    return {
        "map_path": str(_alias_map_path()),
        "aliases": aliases,
        "any_target_allowed": _env_flag("PASTEGRAM_MCP_ALLOW_ANY_TARGET"),
    }


@mcp.tool(annotations=READ_ANNOTATIONS)
def check_setup() -> dict[str, object]:
    """Report whether paste-gram is installed and configured, without revealing secrets."""
    variables = [
        "TELEGRAM_TOKEN", "TELEGRAM_CHAT_ID", "TELEGRAM_API_URL", "PASTEGRAM_DEFAULT_MODE",
        "TELEGRAM_MT_API_ID", "TELEGRAM_MT_API_HASH",
    ]
    script = (
        "if not functions -q paste-gram\n  echo 'version='\nelse\n"
        "  echo 'version='(paste-gram --version 2>/dev/null)\nend\n"
        "for v in $argv\n  set -q $v; and test -n \"$$v\"; and echo \"set=$v\"\nend\n"
        "echo \"mode=$PASTEGRAM_DEFAULT_MODE\"\n"
    )
    try:
        proc = _run_fish(script, variables)
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        return {"installed": False, "error": str(exc)}
    out = proc.stdout.splitlines()
    version = next((line.split("=", 1)[1] for line in out if line.startswith("version=")), "")
    configured = {line.split("=", 1)[1] for line in out if line.startswith("set=")}
    mode = next((line.split("=", 1)[1] for line in out if line.startswith("mode=")), "") or "bot"
    return {
        "installed": bool(version),
        "version": version or None,
        "function_source": _function_file() or "installed paste-gram function",
        "default_transport": mode,
        "bot_api_configured": {"TELEGRAM_TOKEN", "TELEGRAM_CHAT_ID"} <= configured,
        "mtproto_configured": {"TELEGRAM_MT_API_ID", "TELEGRAM_MT_API_HASH"} <= configured,
        "custom_api_url": "TELEGRAM_API_URL" in configured,
        "allowed_roots": [str(root) for root in _allowed_roots()],
        "any_target_allowed": _env_flag("PASTEGRAM_MCP_ALLOW_ANY_TARGET"),
    }


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()

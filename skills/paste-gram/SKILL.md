---
name: paste-gram
description: Send text, command output, files, or directories to the user's own Telegram chat with the paste-gram Fish CLI (alias `ptg`). Use when the user asks to send, share, forward, paste, or "telegram" something to themselves or to a configured chat, or to notify them on Telegram when a long task finishes.
---

# paste-gram

`paste-gram` is a Fish shell function that delivers text, piped output, files, and
directories to Telegram through the Bot API (default) or the user's personal account
(MTProto). Large files and directories are compressed and split automatically.

Sending to Telegram is outward-facing: it delivers content to a real chat. Only send
what the user asked you to send, to the destination they asked for.

## 0. Prefer the MCP tools when they exist

If the `paste-gram` MCP server is connected, use its tools instead of the shell:
`send_message`, `send_files`, `list_targets`, and `check_setup`. They take structured
arguments, return `{ok, exit_code, sent, errors}`, and enforce path and destination
guardrails. Use the shell instructions below only when those tools are unavailable.

## 1. Check that it is available

Agent shells are usually bash or zsh, and `paste-gram` is a Fish function, so always
call it through Fish:

```bash
fish -c 'functions -q paste-gram; and paste-gram --version'
```

If this fails, tell the user to install it with `fisher install behnambagheri/fish-paste-gram`
and configure `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`. Never ask the user to paste a
token into the chat, and never print, echo, or log token values.

## 2. Pass arguments safely

Pass user content as arguments after `--` instead of interpolating it into the Fish
command string. This avoids quoting bugs and shell injection:

```bash
fish -c 'paste-gram $argv' -- "Build finished: 42 tests passed"
fish -c 'paste-gram $argv' -- ./report.pdf
fish -c 'paste-gram $argv' -- -m "Nightly logs" ./logs
some_command 2>&1 | fish -c 'paste-gram $argv' -- -m "Output of some_command"
```

## 3. Choose the input form

| Goal | Arguments |
|------|-----------|
| Short text message | `"text"` or `-m "text"` |
| Command output | pipe it to stdin, with no positional arguments |
| One file | `/path/to/file` |
| One directory (sent as `.tgz`) | `/path/to/dir` |
| Several files/directories as one archive | `--file-name bundle-name a.json b.json dir/` |
| Caption on a file | `-m "caption" /path/to/file` |
| Formatted message | `--html -m '<b>Done</b> in <code>3m</code>'` |

Rules that matter for non-interactive callers:

- Positional arguments win over stdin. Stdin is only read when there are no positional
  arguments, and an empty stdin is treated as no input.
- Always give `-m`/`--message` an inline text value. Without one, paste-gram tries to
  open an editor and fails with an error when no terminal is available.
- Pass `--file-name` when sending several inputs. Without it, a timestamped name such
  as `paste-gram-2026-10-14-143052.tgz` is used.
- `--html` only applies to `-m` text. Use balanced Telegram HTML tags and escape
  literal `&`, `<`, and `>` as `&amp;`, `&lt;`, and `&gt;`.

## 4. Destination and transport

- The default transport comes from `PASTEGRAM_DEFAULT_MODE` (`bot` or `mtproto`) and may
  be MTProto. Pass `--bot` or `--mtproto` when the transport matters; `--api-url` alone
  does not change the transport.
- With no `--id`, Bot API mode sends to `TELEGRAM_CHAT_ID`, which is normally the user.
  Prefer this default.
- Use `--id <alias|@username|numeric-id>` only when the user names a destination.
  Aliases live in `~/.config/paste-gram/chat_ids.json` (or `PASTEGRAM_ID_MAP`); read
  that file to resolve a name the user mentions rather than guessing an ID.
- `--mtproto` sends as the user's personal account and defaults to Saved Messages
  (`me`). External or multi-target MTProto sends are blocked unless
  `PASTEGRAM_MT_ALLOW_EXTERNAL` / `PASTEGRAM_MT_ALLOW_BROADCAST` are set. Never set
  these yourself; tell the user and let them decide. Never use MTProto for bulk,
  unsolicited, or automated outreach.
- MTProto needs a one-time interactive login. If it asks for a phone number or code,
  stop and ask the user to run `ptg --mtproto "test"` once in their own terminal.

## 5. Read the result

- Exit status `0` means every chunk or file was accepted by Telegram; any non-zero
  status means at least part of the send failed. Report failures with the `❌` line
  from stderr.
- Success lines look like `✓ sent file report.pdf to <target>` or
  `✓ sent chunk chunk_aa to <target>`.
- Add `-v`/`--verbose` to diagnose problems. It prints the mode, input type, resolved
  target, API URL, and Telegram response with secrets redacted.

## Useful flags

```
-m, --message <text>     Caption for a file, or a standalone message
--html                   Render -m text as Telegram HTML
-i, --id <target>        Destination (repeatable or comma-separated)
--file-name <name>       Archive name for multiple inputs (.tgz is added)
--bot / --mtproto        Force Bot API or personal-account transport
--api-url <url>          Override the Bot API URL for one call
--proxy <url>            curl proxy for Bot API requests
--hostname <bool>        Include the hostname in the caption
--last-command <bool>    Include the invoking command line
--include-path <bool>    Include the file or directory path
-v, --verbose            Diagnostics with secrets redacted
-V, --version            Print the version
-h, --help               Full help
```

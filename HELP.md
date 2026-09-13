# paste-gram Help

## What it does
`paste-gram` sends text or files from your Fish shell to a Telegram chat via the Bot API, with an optional MTProto mode for personal-account sends. It supports stdin, direct arguments, and large files (auto-compresses and chunks >50MB for bot mode).

## Install
- `fisher install behnambagheri/paste-gram`
- Aliases: `ptg` (if you add one) and `ptg2` (from `conf.d/paste-gram-alias.fish`).

## Configure
Set these environment variables (universal with `-Ux` recommended):
- `TELEGRAM_TOKEN` (required)
- `TELEGRAM_CHAT_ID` (required)
- `TELEGRAM_API_URL` (optional, defaults to `https://api.telegram.org`)
- `PASTEGRAM_HOSTNAME` (optional: `true|1` to prepend hostname)
- `PASTEGRAM_LAST_COMMAND` (optional: `true|1` to prepend last command)
- `PASTEGRAM_DEFAULT_MODE` (optional: `bot|mtproto`, default `bot`)
- `PASTEGRAM_USE_MT` (optional: `true|1` to default to MTProto mode)
- `TELEGRAM_MT_PYTHON` (optional: Python interpreter path; auto-detects `$HOME/.venvs/venv3.14/bin/python`)
- `TELEGRAM_MT_API_ID` (required for MTProto)
- `TELEGRAM_MT_API_HASH` (required for MTProto)
- `TELEGRAM_MT_SESSION` (optional session path for MTProto)

Dependencies: Fish 3+, `curl`, `jq`, `tar`, `split`, `stat`.
MTProto dependencies: Python with `telethon`; proxy support additionally requires `python-socks[asyncio]`.

## Usage
- Send a message: `ptg "Hello from Fish"` or `paste-gram "Hello from Fish"`
- Pipe output: `echo "from pipe" | ptg`
- Send a file: `ptg /path/to/file.log`
- Send a big file locally: `PTG_TMP=(mktemp); seq 1 5000 >$PTG_TMP; ptg $PTG_TMP`
- Override destination chat for one call: `ptg --id @my_other_chat "Hello"`
- Send via MTProto: `ptg --mtproto "Hello from my account"`
- In MTProto mode, omitting `--id` sends to `me` (Saved Messages).
- Force Bot API for one call with `ptg --bot "Hello from the bot"`.
- `--id`/`-i` accepts numeric IDs, `@channel` usernames, or aliases from a JSON map; repeat the flag or comma-separate to send to multiple chats.
- Include metadata: `PASTEGRAM_HOSTNAME=true PASTEGRAM_LAST_COMMAND=true ptg "payload"`

## Chat alias map
- Default path: `~/.config/paste-gram/chat_ids.json` (override with `PASTEGRAM_ID_MAP`). A placeholder file is created automatically on install if missing—replace sample values with your own. Legacy string values are still supported.
- Example:
  ```json
  {
    "friend1": {
      "chat_id": "123456789",
      "username": "@friend1"
    },
    "friend2": {
      "chat_id": "987654321"
    }
  }
  ```
- Usage: `ptg --id friend1 "Hi"` or `ptg --id friend2 /path/to/file`.
  If both `username` and `chat_id` exist, the username is preferred.

Completions: Fish completions are provided for both `paste-gram` and `ptg`, including alias suggestions when your map file exists.

## How it behaves
- Text is wrapped in `<pre>` and split into ~3.8KB chunks to satisfy Telegram limits.
- Files over 50MB are compressed (`tar.gz`) and split into 49MB chunks; each chunk is sent sequentially.
- Captions include absolute paths; API calls are HTML-formatted with timeouts for safety.
- MTProto mode sends files directly (no bot size limits) and uses the Telethon client.
- MTProto automatically prefers `$HOME/.venvs/venv3.14/bin/python` without requiring virtualenv activation.

## Troubleshooting
- “TELEGRAM_TOKEN and TELEGRAM_CHAT_ID must be set”: export both vars.
- “Failed to connect to Telegram API”: check network, proxy settings, or override `TELEGRAM_API_URL`.
- Missing `jq`/`tar`/`split`: install via your package manager.
- HTML rejected: ensure text does not contain raw `<`/`>` (the script sanitizes but confirm when pasting custom content).
- MTProto “unable to open database file”: set `TELEGRAM_MT_SESSION` to a writable path.
- MTProto “Cannot find any entity”: use `--id me`, `@username`, or ensure the chat is in your dialog list.
- MTProto “requires the telethon package”: install Telethon in the selected Python environment.
- MTProto proxy warning about `python-socks`: install `python-socks[asyncio]` in the selected Python environment.

## Contributing quick tips
- Keep Fish style: two-space indents, `set -l` for locals, kebab-case functions.
- Test both macOS (`stat -f`) and Linux (`stat -c`) paths for size detection and chunking.

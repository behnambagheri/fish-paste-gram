# paste-gram Help

## What it does
`paste-gram` sends text or files from your Fish shell to a Telegram chat via the Bot API. It supports stdin, direct arguments, and large files (auto-compresses and chunks >50MB).

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

Dependencies: Fish 3+, `curl`, `jq`, `tar`, `split`, `stat`.

## Usage
- Send a message: `ptg "Hello from Fish"` or `paste-gram "Hello from Fish"`
- Pipe output: `echo "from pipe" | ptg`
- Send a file: `ptg /path/to/file.log`
- Send a big file locally: `PTG_TMP=(mktemp); seq 1 5000 >$PTG_TMP; ptg $PTG_TMP`
- Override destination chat for one call: `ptg --id @my_other_chat "Hello"`
- `--id`/`-i` accepts numeric IDs, `@channel` usernames, or aliases from a JSON map; repeat the flag or comma-separate to send to multiple chats.
- Include metadata: `PASTEGRAM_HOSTNAME=true PASTEGRAM_LAST_COMMAND=true ptg "payload"`

## Chat alias map
- Default path: `~/.config/paste-gram/chat_ids.json` (override with `PASTEGRAM_ID_MAP`). A placeholder file is created automatically on install if missing—replace sample values with your own.
- Example:
  ```json
  {
    "bea": "323101679",
    "reza": "5415541173"
  }
  ```
- Usage: `ptg --id bea "Hi"` or `ptg --id reza /path/to/file`.

## How it behaves
- Text is wrapped in `<pre>` and split into ~3.8KB chunks to satisfy Telegram limits.
- Files over 50MB are compressed (`tar.gz`) and split into 49MB chunks; each chunk is sent sequentially.
- Captions include absolute paths; API calls are HTML-formatted with timeouts for safety.

## Troubleshooting
- “TELEGRAM_TOKEN and TELEGRAM_CHAT_ID must be set”: export both vars.
- “Failed to connect to Telegram API”: check network, proxy settings, or override `TELEGRAM_API_URL`.
- Missing `jq`/`tar`/`split`: install via your package manager.
- HTML rejected: ensure text does not contain raw `<`/`>` (the script sanitizes but confirm when pasting custom content).

## Contributing quick tips
- Keep Fish style: two-space indents, `set -l` for locals, kebab-case functions.
- Test both macOS (`stat -f`) and Linux (`stat -c`) paths for size detection and chunking.

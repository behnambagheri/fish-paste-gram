# 📬 paste-gram

Send text, files, or directories to your Telegram chat directly from the Fish shell!

`paste-gram` is a lightweight Fish plugin that sends any input (text, files, or directories) to your Telegram bot using the Bot API, with an optional MTProto mode for personal-account sends. You can pipe output from other commands or pass messages/files/directories directly. Perfect for quick remote sharing, logging, or personal note-taking!

### 🚀 Recent updates
- Chat alias map now supports `chat_id` + `username` objects (username preferred).
- Optional MTProto mode to send as your personal account (`--mtproto`/`--personal`).
- Optional user captions with `-m`/`--message`, including long captions written in your default editor.
- Send to multiple chats at once with repeatable `--id`/`-i` or comma-separated aliases.
- Default install creates `~/.config/paste-gram/chat_ids.json` with placeholder aliases only (friend1/friend2/demo_channel).
- Fish completions for `paste-gram` and `ptg`.
- Directories are automatically archived as `.tgz` files; archives over 50MB are split into 49MB chunks.
- Files over 50MB are auto-compressed (`tar.gz`) and split into 49MB chunks.
- Compatible with both Linux and macOS with compact HTML captions for host/command/path.

---

## ✨ Features

- 🐟 Native Fish shell function
- 📦 Works with `fisher` plugin manager
- 🧾 Sends:
  - Messages (via direct argument or stdin)
  - Files and directories (as documents with optional caption; directories are archived automatically)
- 🖥️ Can prepend hostname and/or command line (configurable)
- 🔐 Gets config from environment variables
- 🧭 Built-in Fish completions for commands and `--id` aliases
- 🆔 Target either numeric chat IDs or usernames (channels) with `--id` / `TELEGRAM_CHAT_ID`
- 👤 Optional MTProto mode to send as your personal account
- 🔎 Verbose diagnostics with `-v`, including the effective mode, endpoint/proxy, and Telegram response

---

## 🧰 Requirements

- Fish shell 3.0 or higher
- `curl`
- `jq`
- `curl`
- `tar`
- `split`
- Telegram bot with a valid token
- Your own chat ID (or a group chat ID where your bot is added)
- Python 3 + `telethon` (only for MTProto personal-account mode). `pipx install telethon` recommended.
- `python-socks[asyncio]` for MTProto proxy support.

---

## ⚙️ Installation

1. **Install with [Fisher](https://github.com/jorgebucaran/fisher):**

```fish
fisher install behnambagheri/fish-paste-gram
```

2. **Set environment variables (numeric ID or channel username with `@`):**

```fish
set -Ux TELEGRAM_TOKEN 'your_bot_token_here'
set -Ux TELEGRAM_CHAT_ID '123456789'
# Optional:
set -Ux TELEGRAM_API_URL 'https://api.telegram.org'
set -Ux PASTEGRAM_HOSTNAME 'true'
set -Ux PASTEGRAM_LAST_COMMAND 'true'
set -Ux PASTEGRAM_INCLUDE_PATH 'true'
# Optional default transport: bot or mtproto
set -Ux PASTEGRAM_DEFAULT_MODE 'bot'
# Optional explicit Python interpreter for MTProto
set -Ux TELEGRAM_MT_PYTHON "$HOME/.venvs/venv3.14/bin/python"
```

If you changed `TELEGRAM_API_URL` but requests still go to `api.telegram.org`, check which function file Fish is actually running:

```fish
functions paste-gram | head -n 1
```

If it points to `~/.config/fish/functions/paste-gram.fish`, reinstall to refresh your installed copy:

```fish
fisher remove behnambagheri/fish-paste-gram
fisher install behnambagheri/fish-paste-gram
```

---

## 🤖 How to Get Your Telegram Bot Token

1. Open Telegram and search for [`@BotFather`](https://t.me/BotFather)
2. Start a chat and send `/newbot`
3. Follow the prompts to name and create your bot
4. After success, BotFather will give you a **bot token** like:
   ```
   123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
   ```
5. Copy it and set it as `TELEGRAM_TOKEN`

---

## 👤 Personal account (MTProto)

Use MTProto to send messages as your own Telegram account (not a bot).

1. Get your API credentials from https://my.telegram.org (API Development Tools):
   - `TELEGRAM_MT_API_ID`
   - `TELEGRAM_MT_API_HASH`
2. Install Telethon:
   ```fish
   pipx install telethon
   ```
   For MTProto proxy support, also install `python-socks` in the same environment:
   ```fish
   python3 -m pip install 'python-socks[asyncio]'
   ```
3. Set env vars and send:
   ```fish
   set -Ux TELEGRAM_MT_API_ID '123456'
   set -Ux TELEGRAM_MT_API_HASH 'your_api_hash_here'
   ptg --mtproto "Hello from my account"
   ```

The plugin automatically prefers `$HOME/.venvs/venv3.14/bin/python` when it exists, so
activating the virtual environment is not required. Override it with `TELEGRAM_MT_PYTHON`.

4. Optional: route MTProto via proxy:
   ```fish
   # URL form (recommended)
   set -Ux TELEGRAM_MT_PROXY 'socks5://user:pass@proxy.example.com:1080'

   # Split variables form
   set -Ux TELEGRAM_MT_PROXY_TYPE 'socks5' # socks5|socks4|http|mtproxy
   set -Ux TELEGRAM_MT_PROXY_HOST 'proxy.example.com'
   set -Ux TELEGRAM_MT_PROXY_PORT '1080'
   set -Ux TELEGRAM_MT_PROXY_USERNAME 'user'
   set -Ux TELEGRAM_MT_PROXY_PASSWORD 'pass'
   ```

   MTProxy example:
   ```fish
   set -Ux TELEGRAM_MT_PROXY_TYPE 'mtproxy'
   set -Ux TELEGRAM_MT_PROXY_HOST 'proxy.example.com'
   set -Ux TELEGRAM_MT_PROXY_PORT '443'
   set -Ux TELEGRAM_MT_PROXY_SECRET 'your_hex_secret'
   ```

   If your proxy endpoint is `tg.behnam.pro`, set one of:
   ```fish
   set -Ux TELEGRAM_MT_PROXY 'socks5://tg.behnam.pro:1080'
   # or
   set -Ux TELEGRAM_MT_PROXY 'http://tg.behnam.pro:443'
   ```

The first run will prompt for login and a code. A session file is saved at `~/.config/paste-gram/mtproto.session` (override with `TELEGRAM_MT_SESSION`).
If you see “unable to open database file”, set `TELEGRAM_MT_SESSION` to a writable path.
MTProto resolves chats by username/alias or existing dialogs. When no `--id` is provided in MTProto mode,
the destination defaults to your Saved Messages (`me`). Numeric IDs may fail unless the chat is in your dialog list.

### Telegram policy guardrails

Telegram's [Terms of Service](https://telegram.org/tos), [API Terms of Service](https://core.telegram.org/api/terms),
and [Spam FAQ](https://telegram.org/faq_spam) prohibit spam, scams, unsolicited messages, abusive automation,
and actions that violate other users' privacy or consent. The plugin is intentionally interactive and now applies
these conservative local guardrails to MTProto mode:

- `me` is the default destination.
- External MTProto destinations are blocked unless explicitly enabled.
- Multi-target MTProto sends are blocked unless explicitly enabled.
- A one-second delay is inserted between MTProto sends by default.

These checks reduce accidental misuse but cannot guarantee that Telegram will never restrict an account. Only send
content to recipients who expect it, do not use this tool for scraping or bulk outreach, and use your own `api_id`.

If an external recipient has explicitly consented to receive the message, enable it for that invocation or session:

```fish
PASTEGRAM_MT_ALLOW_EXTERNAL=true ptg --mtproto --id @expected_recipient "Expected message"
```

For intentional, consented multi-target delivery, enable both safeguards explicitly:

```fish
PASTEGRAM_MT_ALLOW_EXTERNAL=true \
PASTEGRAM_MT_ALLOW_BROADCAST=true \
ptg --mtproto --id @recipient_one --id @recipient_two "Expected message"
```

The default delay can be increased, but should not be disabled for routine personal-account use:

```fish
set -Ux PASTEGRAM_MT_DELAY_SECONDS 2
```

### Default mode and destination

Set the default transport once:

```fish
set -Ux PASTEGRAM_DEFAULT_MODE 'mtproto'  # bot or mtproto
```

With that setting, this sends through your personal account to Saved Messages:

```fish
ptg "Personal default message"
```

Use `--bot` or `--bot-api` to force Bot API for one command. Use `--mtproto` or `--personal` to
force MTProto for one command. Add a URL after `--bot-api`/`--bot`, or use `--api-url`, to override
`TELEGRAM_API_URL` for one command. Use `--proxy` to pass a curl proxy URL for Bot API requests:

```fish
ptg --bot-api https://api.telegram.org "Bot API message"
ptg --api-url https://api.telegram.org --proxy socks5h://127.0.0.1:1080 "Through a proxy"
```

The older `PASTEGRAM_USE_MT=true|false` variable remains supported.

---

## 🆔 How to Find Your Chat ID

### 📥 Option 1: Using [@getidsbot](https://t.me/getidsbot)

1. Start a chat with [@getidsbot](https://t.me/getidsbot)
2. Send `/start`
3. It will respond with your numeric chat ID

### 📤 Option 2: Using Bot API (if you’re in a group):

1. Add your bot to the group
2. Send a message to the group
3. Use this API endpoint:

```
https://api.telegram.org/bot<your_token>/getUpdates
```

Check the response JSON for `"chat":{"id":...}`

---

## 🧪 Usage

```fish
# Pipe output from any command
echo "Hello from pipe" | ptg

# Send direct message
ptg "Direct hello from fish"

# Send as your personal account via MTProto
ptg --mtproto "Personal hello from fish"
ptg --mtproto "Saved Messages"              # MTProto defaults to me when --id is omitted

# Send to a different chat/channel without changing TELEGRAM_CHAT_ID (numeric, @username, or alias)
ptg --id @my_other_chat "Hello from another place"

# Send to multiple chats in one go
ptg --id friend1 --id friend2 "Hello to two chats"
# or
ptg --id friend1,friend2 "Hello again"

# Send a file with optional caption
ptg ~/Documents/log.txt

# Archive and send a directory (large archives are chunked automatically)
ptg ~/Documents/project

# Compress and send multiple files/directories as one archive
ptg ~/Documents/a.json ~/Documents/b.json ~/Documents/project ~/yamls/*.yaml

# Add a short caption to a file or directory
ptg -m "Updated configuration" ~/Documents/project

# Open $GIT_EDITOR, $VISUAL, $EDITOR, or vi to write a long caption
ptg -m ~/Documents/project

# Send a standalone message through the -m/--message interface
ptg -m "Hello"
ptg --message "Hello again"

# Override metadata defaults for one command
ptg --last-command false --hostname true --include-path false ~/Documents/project

# Show effective configuration and Telegram responses (works with stdin, text, and files)
echo "debug me" | ptg -v
ptg -v ~/Documents/log.txt
ptg -v --id @my_other_chat "debug me"
```

If `PASTEGRAM_HOSTNAME` or `PASTEGRAM_LAST_COMMAND` is set to `"true"`, those will be prepended to your message or file caption. `PASTEGRAM_INCLUDE_PATH` defaults to `true`; set it to `false` to omit the file or directory path. File captions omit redundant labels, shorten paths inside `$HOME` to `~/…`, and show directories using the source path while Telegram displays the archive filename. When multiple files or directories are provided, paste-gram creates one `.tgz` archive and lists every original input under `PATH:` on its own line. Fish expands globs such as `~/yamls/*.yaml` before paste-gram receives them.
Use `-m`/`--message` with inline text for a short caption. If the option has no text value, paste-gram opens `$GIT_EDITOR`, then `$VISUAL`, then `$EDITOR`, then `vi`; the saved text is added above the generated metadata under a bold `Caption:` title. When there is no file, positional text, or stdin input, the `-m`/`--message` text is sent as a standalone message instead. Caption text is escaped as plain text for Telegram HTML mode. If the complete document caption is too long for Telegram, the full user caption is sent as text before the file and only the compact metadata remains attached to the document.
Use `--hostname`, `--last-command`, and `--include-path` with `true` or `false` to override `PASTEGRAM_HOSTNAME`, `PASTEGRAM_LAST_COMMAND`, and `PASTEGRAM_INCLUDE_PATH` for one command. The `--include-hostname` and `--include-command` spellings are accepted as aliases. The inline values take precedence over the environment variables.
Use `--api-url <url>` or `--bot-api <url>` to override `TELEGRAM_API_URL` for one Bot API command. Use `--proxy <url>` to configure curl's proxy for that command; this is separate from the MTProto proxy settings.
Use `-v`/`--verbose` with any send form to print the selected mode, input type, resolved target, API URL, proxy status, runtime settings, and the Telegram response. Secrets such as bot tokens, API hashes, proxy passwords, and MTProxy secrets are redacted. `-V`/`--version` prints only the version.

---

## 🔧 Environment Variables

| Variable                  | Required | Default | Description                                                  |
|---------------------------|----------|---------|--------------------------------------------------------------|
| `TELEGRAM_TOKEN`          | ✅ yes   | —       | Telegram bot token from BotFather                           |
| `TELEGRAM_CHAT_ID`        | ✅ yes   | —       | Chat ID (from @getidsbot or Bot API)                        |
| `TELEGRAM_API_URL`        | ❌ no    | `https://api.telegram.org` | Override default Telegram API URL (e.g. for proxy) |
| `PASTEGRAM_HOSTNAME`      | ❌ no    | `false` | If `"true"`, includes hostname in message                    |
| `PASTEGRAM_LAST_COMMAND`  | ❌ no    | `false` | If `"true"`, includes executed command line in message       |
| `PASTEGRAM_INCLUDE_PATH`  | ❌ no    | `true`  | If `"false"`, omits file or directory path from captions     |
| `PASTEGRAM_ID_MAP`        | ❌ no    | `$HOME/.config/paste-gram/chat_ids.json` | Path to alias map for `--id` lookups |
| `PASTEGRAM_DEFAULT_MODE`  | ❌ no    | `bot` | Default transport: `bot` or `mtproto` |
| `PASTEGRAM_USE_MT`        | ❌ no    | `false` | Legacy compatibility toggle for default MTProto mode |
| `TELEGRAM_MT_PYTHON`      | ❌ no    | auto-detected | Python interpreter used for MTProto |
| `PASTEGRAM_MT_ALLOW_EXTERNAL` | ❌ no | `false` | Allow explicit non-`me` MTProto destinations |
| `PASTEGRAM_MT_ALLOW_BROADCAST` | ❌ no | `false` | Allow multiple MTProto destinations in one invocation |
| `PASTEGRAM_MT_DELAY_SECONDS` | ❌ no | `1.0` | Delay between MTProto sends/chunks |
| `TELEGRAM_MT_API_ID`      | ✅ yes (MTProto) | — | Telegram API ID for personal account                        |
| `TELEGRAM_MT_API_HASH`    | ✅ yes (MTProto) | — | Telegram API hash for personal account                      |
| `TELEGRAM_MT_SESSION`     | ❌ no    | `$HOME/.config/paste-gram/mtproto` | Session path for MTProto auth                       |
| `TELEGRAM_MT_PROXY`       | ❌ no    | —       | Proxy URL for MTProto (`socks5://`, `socks4://`, `http://`, `mtproxy://`) |
| `TELEGRAM_MT_PROXY_TYPE`  | ❌ no    | `socks5` (if host set) | Split proxy config type (`socks5`, `socks4`, `http`, `mtproxy`) |
| `TELEGRAM_MT_PROXY_HOST`  | ❌ no    | —       | Split proxy config host for MTProto                          |
| `TELEGRAM_MT_PROXY_PORT`  | ❌ no    | —       | Split proxy config port for MTProto                          |
| `TELEGRAM_MT_PROXY_USERNAME` | ❌ no | —       | Optional username for SOCKS/HTTP proxy                       |
| `TELEGRAM_MT_PROXY_PASSWORD` | ❌ no | —       | Optional password for SOCKS/HTTP proxy                       |
| `TELEGRAM_MT_PROXY_SECRET` | ❌ no   | —       | Required secret when proxy type is `mtproxy`                 |

### 🧭 Chat alias map

Create a JSON file for friendly names (default path: `~/.config/paste-gram/chat_ids.json`, or set `PASTEGRAM_ID_MAP` to another path). A placeholder file is created automatically—replace the sample values with your own IDs or usernames. Legacy string values are still supported.

```json
{
  "friend1": {
    "chat_id": "123456789",
    "username": "@friend1"
  },
  "friend2": {
    "chat_id": "987654321"
  },
  "demo_channel": {
    "chat_id": "-1001234567890",
    "username": "@demo_channel"
  }
}
```

Then use the alias with `--id`:

```fish
ptg --id friend1 "Hello friend1"
ptg --id demo_channel /path/to/file.log
ptg --id friend1,friend2 "Hello both"
```

During install, a sample map is created at the default path if one does not already exist.

Use the `--id`/`-i` flag to override `TELEGRAM_CHAT_ID` for a single call (prefix with `@` for channels). If both `username` and `chat_id` exist, the username is preferred.

---

## 🧾 License

MIT License © 2025 [Behnam Bagheri]

# 📬 paste-gram

Send text or files to your Telegram chat directly from the Fish shell!

`paste-gram` is a lightweight Fish plugin that sends any input (either text or a file) to your Telegram bot using the Bot API, with an optional MTProto mode for personal-account sends. You can pipe output from other commands or pass messages/files directly. Perfect for quick remote sharing, logging, or personal note-taking!

### 🚀 New in v1.5.1
- Chat alias map now supports `chat_id` + `username` objects (username preferred).
- Optional MTProto mode to send as your personal account (`--mtproto`/`--personal`).
- Send to multiple chats at once with repeatable `--id`/`-i` or comma-separated aliases.
- Default install creates `~/.config/paste-gram/chat_ids.json` with placeholder aliases only (friend1/friend2/demo_channel).
- Fish completions for `paste-gram` and `ptg`.
- Files over 50MB are auto-compressed (`tar.gz`) and split into 49MB chunks.
- Compatible with both Linux and macOS with HTML-based captions for host/command/path.

---

## ✨ Features

- 🐟 Native Fish shell function
- 📦 Works with `fisher` plugin manager
- 🧾 Sends:
  - Messages (via direct argument or stdin)
  - Files (as documents with optional caption)
- 🖥️ Can prepend hostname and/or command line (configurable)
- 🔐 Gets config from environment variables
- 🧭 Built-in Fish completions for commands and `--id` aliases
- 🆔 Target either numeric chat IDs or usernames (channels) with `--id` / `TELEGRAM_CHAT_ID`
- 👤 Optional MTProto mode to send as your personal account

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
3. Set env vars and send:
   ```fish
   set -Ux TELEGRAM_MT_API_ID '123456'
   set -Ux TELEGRAM_MT_API_HASH 'your_api_hash_here'
   ptg --mtproto "Hello from my account"
   ```

The first run will prompt for login and a code. A session file is saved at `~/.config/paste-gram/mtproto.session` (override with `TELEGRAM_MT_SESSION`).
If you see “unable to open database file”, set `TELEGRAM_MT_SESSION` to a writable path.
MTProto resolves chats by username/alias or existing dialogs; for Saved Messages use `--id me`. Numeric IDs may fail unless the chat is in your dialog list.

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
ptg --mtproto --id me "Saved Messages"

# Send to a different chat/channel without changing TELEGRAM_CHAT_ID (numeric, @username, or alias)
ptg --id @my_other_chat "Hello from another place"

# Send to multiple chats in one go
ptg --id friend1 --id friend2 "Hello to two chats"
# or
ptg --id friend1,friend2 "Hello again"

# Send a file with optional caption
ptg ~/Documents/log.txt
```

If `PASTEGRAM_HOSTNAME` or `PASTEGRAM_LAST_COMMAND` is set to `"true"`, those will be prepended to your message or file caption.

---

## 🔧 Environment Variables

| Variable                  | Required | Default | Description                                                  |
|---------------------------|----------|---------|--------------------------------------------------------------|
| `TELEGRAM_TOKEN`          | ✅ yes   | —       | Telegram bot token from BotFather                           |
| `TELEGRAM_CHAT_ID`        | ✅ yes   | —       | Chat ID (from @getidsbot or Bot API)                        |
| `TELEGRAM_API_URL`        | ❌ no    | `https://api.telegram.org` | Override default Telegram API URL (e.g. for proxy) |
| `PASTEGRAM_HOSTNAME`      | ❌ no    | `false` | If `"true"`, includes hostname in message                    |
| `PASTEGRAM_LAST_COMMAND`  | ❌ no    | `false` | If `"true"`, includes executed command line in message       |
| `PASTEGRAM_ID_MAP`        | ❌ no    | `$HOME/.config/paste-gram/chat_ids.json` | Path to alias map for `--id` lookups |
| `PASTEGRAM_USE_MT`        | ❌ no    | `false` | If `"true"`, default to MTProto mode                         |
| `TELEGRAM_MT_API_ID`      | ✅ yes (MTProto) | — | Telegram API ID for personal account                        |
| `TELEGRAM_MT_API_HASH`    | ✅ yes (MTProto) | — | Telegram API hash for personal account                      |
| `TELEGRAM_MT_SESSION`     | ❌ no    | `$HOME/.config/paste-gram/mtproto` | Session path for MTProto auth                       |

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

# 📬 paste-gram

Send text or files to your Telegram chat directly from the Fish shell!

`paste-gram` is a lightweight Fish plugin that sends any input (either text or a file) to your Telegram bot using the Bot API. You can pipe output from other commands or pass messages/files directly. Perfect for quick remote sharing, logging, or personal note-taking!

### 🚀 New in v1.4.0
- Send to multiple chats at once with repeatable `--id`/`-i` or comma-separated aliases.
- Default install creates `~/.config/paste-gram/chat_ids.json` with placeholder aliases only.
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
- 🆔 Target either numeric chat IDs or usernames (channels) with `--id` / `TELEGRAM_CHAT_ID`

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

---

## ⚙️ Installation

1. **Install with [Fisher](https://github.com/jorgebucaran/fisher):**

```fish
fisher install behnambagheri/paste-gram
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

# Send to a different chat/channel without changing TELEGRAM_CHAT_ID (numeric, @username, or alias)
ptg --id @my_other_chat "Hello from another place"

# Send to multiple chats in one go
ptg --id bea --id reza "Hello to two chats"
# or
ptg --id bea,reza "Hello again"

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

### 🧭 Chat alias map

Create a JSON file for friendly names (default path: `~/.config/paste-gram/chat_ids.json`, or set `PASTEGRAM_ID_MAP` to another path). A placeholder file is created automatically—replace the sample values with your own IDs:

```json
{
  "example_friend": "123456789",
  "example_channel": "-1001234567890"
}
```

Then use the alias with `--id`:

```fish
ptg --id bea "Hello Behnam"
ptg --id pastebin /path/to/file.log
ptg --id bea,reza "Hello both"
```

During install, a sample map is created at the default path if one does not already exist.

Use the `--id`/`-i` flag to override `TELEGRAM_CHAT_ID` for a single call (prefix with `@` for channels).

---

## 🧾 License

MIT License © 2025 [Behnam Bagheri]

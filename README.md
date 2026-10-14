# paste-gram: send files, command output, and text to Telegram from your terminal

[![Fish shell](https://img.shields.io/badge/shell-fish-4AAE47?logo=gnubash&logoColor=white)](https://fishshell.com/)
[![Fisher plugin](https://img.shields.io/badge/install-fisher-blue)](https://github.com/jorgebucaran/fisher)
[![Telegram Bot API](https://img.shields.io/badge/Telegram-Bot%20API%20%7C%20MTProto-26A5E4?logo=telegram&logoColor=white)](https://core.telegram.org/bots/api)
[![Latest release](https://img.shields.io/github/v/release/behnambagheri/fish-paste-gram)](https://github.com/behnambagheri/fish-paste-gram/releases)
[![License](https://img.shields.io/github/license/behnambagheri/fish-paste-gram)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/behnambagheri/fish-paste-gram?style=social)](https://github.com/behnambagheri/fish-paste-gram/stargazers)

**paste-gram** (alias `ptg`) is a command-line tool and [Fish shell](https://fishshell.com/) plugin that sends text, piped command output, files, and whole directories to a Telegram chat. It uses the Telegram Bot API by default, can optionally send as your personal account through MTProto, and automatically compresses and splits uploads larger than Telegram's 50 MB bot limit. It works on Linux and macOS, over SSH, in cron jobs and CI, and from AI coding agents such as Claude Code and Codex.

Think of it as a **terminal-to-Telegram pastebin**: get logs off a remote server, save snippets, or get notified when a long command finishes.

```fish
fisher install behnambagheri/fish-paste-gram   # install
make build 2>&1 | ptg                           # pipe any command output to Telegram
ptg ~/logs/app.log                              # send a file
ptg ~/Documents/project                         # send a directory (auto .tgz, auto-split over 50 MB)
long_task; ptg -m "long_task finished"          # get a notification when a job is done
```

**Contents:** [Use cases](#-use-cases) · [Features](#-features) · [Installation](#%EF%B8%8F-installation) · [Usage](#-usage) · [MTProto](#-personal-account-mtproto) · [AI agents](#-use-with-ai-agents) · [Environment variables](#-environment-variables) · [FAQ](#-faq)

---

## 💡 Use cases

- **Send server logs to Telegram**: pull a log file or `journalctl` output off a remote machine over SSH without `scp`.
- **Pipe command output to Telegram**: `kubectl get pods | ptg`, `docker logs app | ptg`, `df -h | ptg`.
- **Telegram notifications from the shell**: alert yourself when a build, backup, deploy, or cron job finishes.
- **Share large files and folders**: directories are archived as `.tgz`, and anything over 50 MB is split into 49 MB parts that you can rejoin with `cat` (Bot API mode).
- **Personal notes and snippets**: drop code, configs, or links into your Saved Messages from any terminal.
- **AI agent delivery**: let Claude Code, Codex, or another agent send you reports and artifacts on Telegram.

---

## ✨ Features

- 🐟 Native Fish shell function, installable with `fisher`
- 🧾 Sends messages (argument or stdin), files, directories, and multiple inputs bundled into one archive
- 📦 Automatic `tar.gz` compression and 49 MB chunking for files over Telegram's 50 MB bot upload limit
- 🖥️ Optional hostname, command line, and path in captions
- 📝 Captions with `-m`/`--message`, editor support for long captions, and Telegram HTML formatting with `--html`
- 👥 Send to several chats at once with repeatable `--id` or chat aliases from a JSON map
- 👤 Optional MTProto mode to send as your personal account (defaults to Saved Messages)
- 🌐 Custom Bot API URL and HTTP/SOCKS proxy support, including MTProxy for MTProto
- 🧭 Built-in Fish completions for flags and `--id` aliases
- 🤖 Agent-friendly: an Agent Skill, an MCP server, and predictable non-interactive behavior for Claude Code, Codex, Cursor, and other AI agents
- 🔎 Verbose diagnostics with `-v`, with secrets redacted

### 🚀 Recent updates

See [CHANGELOG.md](CHANGELOG.md) for the full history. Highlights:

- Telegram HTML formatting for messages and captions with `--html`.
- Multiple files, directories, and globs bundled into one named `.tgz` upload.
- Agent Skill, MCP server, and Claude Code plugin for AI agents.
- MTProto personal-account mode with safety guardrails and proxy support.
- Per-command overrides for the Bot API URL, curl proxy, and caption metadata.

---

## 🧰 Requirements

- Fish shell 3.0 or higher
- `curl`
- `jq`
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

# Choose the compressed archive name (.tgz is added automatically)
ptg --file-name release-bundle ~/Documents/a.json ~/Documents/project

# Add a short caption to a file or directory
ptg -m "Updated configuration" ~/Documents/project

# Open $GIT_EDITOR, $VISUAL, $EDITOR, or vi to write a long caption
ptg -m ~/Documents/project

# Send a standalone message through the -m/--message interface
ptg -m "Hello"
ptg --message "Hello again"

# Render HTML formatting in a message or file caption
ptg --html -m '<b>Hi</b>'
ptg --html --message '<b>Updated</b> <i>configuration</i>' ./config.yaml

# Override metadata defaults for one command
ptg --last-command false --hostname true --include-path false ~/Documents/project

# Show effective configuration and Telegram responses (works with stdin, text, and files)
echo "debug me" | ptg -v
ptg -v ~/Documents/log.txt
ptg -v --id @my_other_chat "debug me"
```

If `PASTEGRAM_HOSTNAME` or `PASTEGRAM_LAST_COMMAND` is set to `"true"`, those will be prepended to your message or file caption. `PASTEGRAM_INCLUDE_PATH` defaults to `true`; set it to `false` to omit the file or directory path. File captions omit redundant labels, shorten paths inside `$HOME` to `~/…`, and show directories using the source path while Telegram displays the archive filename. When multiple files or directories are provided, paste-gram creates one `.tgz` archive and lists every original input as a separate bullet under the bold `PATH:` heading. Fish expands globs such as `~/yamls/*.yaml` before paste-gram receives them. Pass `--file-name <name>` to name the archive; otherwise, paste-gram prompts with a timestamped suggestion such as `paste-gram-2026-09-20-143052`, which Enter accepts. The `.tgz` suffix is added automatically. In non-interactive usage, set `--file-name` explicitly.
Use `-m`/`--message` with inline text for a short caption. If the option has no text value, paste-gram opens `$GIT_EDITOR`, then `$VISUAL`, then `$EDITOR`, then `vi`; the saved text is added above the generated metadata under a bold `Caption:` title. When there is no file, positional text, or stdin input, the `-m`/`--message` text is sent as a standalone message instead. By default, caption text is escaped as plain text for Telegram HTML mode. Add `--html` to interpret the text from `-m`/`--message` as [Telegram HTML](https://core.telegram.org/bots/api#html-style): `<b>Hi</b>` renders **Hi** in bold, outside the default code block. This works with inline text, editor input, and file/directory captions in both Bot API and MTProto mode. Use balanced tags supported by your transport and encode literal `&`, `<`, and `>` as `&amp;`, `&lt;`, and `&gt;`. Long formatted messages preserve tags, entities, and Unicode across chunks. `--html` requires `-m`/`--message`; positional and piped content retain their existing code-block behavior. If the complete document caption is too long for Telegram, the full user caption is sent as text before the file and only the compact metadata remains attached to the document.
Use `--hostname`, `--last-command`, and `--include-path` with `true` or `false` to override `PASTEGRAM_HOSTNAME`, `PASTEGRAM_LAST_COMMAND`, and `PASTEGRAM_INCLUDE_PATH` for one command. The `--include-hostname` and `--include-command` spellings are accepted as aliases. The inline values take precedence over the environment variables.
Use `--api-url <url>` or `--bot-api <url>` to override `TELEGRAM_API_URL` for one Bot API command. Use `--proxy <url>` to configure curl's proxy for that command; this is separate from the MTProto proxy settings.
Use `-v`/`--verbose` with any send form to print the selected mode, input type, resolved target, API URL, proxy status, runtime settings, and the Telegram response. Secrets such as bot tokens, API hashes, proxy passwords, and MTProxy secrets are redacted. `-V`/`--version` prints only the version.

---

## 🤖 Use with AI agents

paste-gram is built to be used by AI coding agents such as Claude Code, Codex, Cursor, and Claude Desktop. Ask your agent to "send me the report on Telegram" and the file arrives in your chat. It is agent-friendly in three ways:

- **Agent Skill** ([`skills/paste-gram/SKILL.md`](skills/paste-gram/SKILL.md)): teaches skill-aware agents when and how to call paste-gram safely.
- **MCP server** ([`mcp-server/`](mcp-server/paste_gram_mcp.py)): exposes `send_message`, `send_files`, `list_targets`, and `check_setup` as tools for any MCP client.
- **Predictable CLI**: no prompts or editors in non-interactive shells, clear errors, and non-zero exit codes on failure. A [`llms.txt`](llms.txt) summary is included for agents that read project docs.

### Quick start for agents

First install paste-gram and set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID` as shown in [Installation](#%EF%B8%8F-installation). Then pick your agent:

**Claude Code** (installs the skill and the MCP server together):

```
/plugin marketplace add behnambagheri/fish-paste-gram
/plugin install paste-gram@paste-gram
```

The MCP server needs the `mcp` Python package: `python3 -m pip install mcp`, or set `PASTEGRAM_MCP_PYTHON` to an interpreter that has it.

**Codex, Cursor, Claude Desktop, and other MCP clients:** register the MCP server as shown in [MCP server](#mcp-server). For Codex:

```bash
codex mcp add paste-gram -- python3 /path/to/fish-paste-gram/mcp-server/paste_gram_mcp.py
```

**Any agent with shell access:** no setup is needed beyond the CLI. Optionally copy or symlink `skills/paste-gram` into the agent's skills directory, for example `~/.codex/skills/paste-gram` for Codex or `~/.claude/skills/paste-gram` for Claude Code without the plugin.

### Example prompts

- "Run the tests and send me the failure report on Telegram."
- "When the build finishes, message me on Telegram with the result."
- "Compress the `logs/` folder and send it to me on Telegram."
- "Send `dist/report.pdf` to the `team` alias on Telegram with the caption 'Weekly report'."

### How agents call the CLI

Agents typically run bash or zsh and have no terminal attached, so paste-gram behaves predictably in non-interactive shells:

- Call it through Fish and pass content after `--`: `fish -c 'paste-gram $argv' -- ./report.pdf`.
- Positional arguments take precedence over stdin; stdin is read only when no positional arguments are given, and empty stdin is treated as no input.
- `-m`/`--message` without inline text fails with an error instead of waiting on an editor when no terminal is available.
- Multiple inputs without `--file-name` use the timestamped default archive name instead of prompting.
- A missing input or any failed Telegram request exits with a non-zero status.

### MCP server

[`mcp-server/paste_gram_mcp.py`](mcp-server/paste_gram_mcp.py) exposes paste-gram as [Model Context Protocol](https://modelcontextprotocol.io) tools, so any MCP client (Claude Code, Claude Desktop, Codex, Cursor, …) can call it directly:

| Tool | Purpose |
|------|---------|
| `send_message` | Send text (plain text in a code block, or Telegram HTML with `html: true`) |
| `send_files` | Send files or directories, with an optional caption and archive name |
| `list_targets` | List aliases from the chat alias map |
| `check_setup` | Report installation and configuration status without revealing secrets |

Each send returns `ok`, `exit_code`, the `sent` confirmations, and any `errors`. The server wraps the Fish function, so chunking, compression, captions, and MTProto guardrails behave exactly like the CLI. It requires Python 3.10+ with the `mcp` package (`pip install -r mcp-server/requirements.txt`) and `fish` on `PATH`.

The Claude Code plugin above registers the server automatically. Set `PASTEGRAM_MCP_PYTHON` if `python3` on your `PATH` does not have `mcp` installed. To register it manually in Claude Code:

```bash
claude mcp add paste-gram -s user -- /path/to/python /path/to/paste-gram/mcp-server/paste_gram_mcp.py
```

Other clients use the same command in their MCP configuration, for example:

```json
{
  "mcpServers": {
    "paste-gram": {
      "command": "/path/to/python",
      "args": ["/path/to/paste-gram/mcp-server/paste_gram_mcp.py"]
    }
  }
}
```

The server adds guardrails for agent use:

- Files and directories must sit under an allowed root (the server's working directory by default), and paths that look like credentials (`.ssh`, `.env`, `*.pem`, `*.key`, MTProto session files, …) are always refused, including inside directories.
- Destinations are limited to the default chat, `me`, and aliases from the alias map. Raw chat IDs and usernames require opt-in.

| Variable | Default | Description |
|----------|---------|-------------|
| `PASTEGRAM_MCP_ALLOWED_ROOTS` | server working directory | `:`-separated directories that `send_files` may read from |
| `PASTEGRAM_MCP_ALLOW_ANY_TARGET` | `false` | Allow raw chat IDs and `@usernames` in addition to aliases |
| `PASTEGRAM_MCP_TIMEOUT` | `900` | Seconds before a send is aborted |
| `PASTEGRAM_MCP_FUNCTION_FILE` | bundled `functions/paste-gram.fish` | Fish file to source; set it to an empty string to use the installed function |
| `PASTEGRAM_MCP_PYTHON` | `python3` | Interpreter used by the Claude Code plugin to start the server |

The MTProto guardrails still apply: agents should not set `PASTEGRAM_MT_ALLOW_EXTERNAL` or `PASTEGRAM_MT_ALLOW_BROADCAST` on their own, and the first MTProto login must be completed interactively by you.

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

## ❓ FAQ

**How do I send a file to Telegram from the command line?**
Install paste-gram, set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`, then run `ptg /path/to/file`. Directories work the same way and are archived automatically.

**How do I pipe command output to Telegram?**
Pipe it into `ptg`: `some_command 2>&1 | ptg`. The output is sent as a formatted code block and split into several messages if it is longer than Telegram's 4096-character limit.

**Can I send files larger than 50 MB with a Telegram bot?**
The Bot API limits bot uploads to 50 MB, so in Bot API mode paste-gram compresses large inputs and splits them into 49 MB parts named `archive.tgz_00`, `archive.tgz_01`, and so on. Download them into one folder and rejoin them with `cat archive.tgz_* > archive.tgz`. MTProto mode sends the file whole.

**Does it work in bash or zsh?**
paste-gram is a Fish function, but you can call it from any shell: `fish -c 'paste-gram $argv' -- ./report.pdf`. Fish only needs to be installed.

**Can I send as my own Telegram account instead of a bot?**
Yes. Use `--mtproto` (or `--personal`) with your own API ID and hash from [my.telegram.org](https://my.telegram.org). See [Personal account (MTProto)](#-personal-account-mtproto).

**Does it work on macOS and Linux?**
Yes. It supports both GNU and BSD/macOS userland tools.

---

## 🧾 License

[MIT License](LICENSE) © 2025 Behnam Bagheri

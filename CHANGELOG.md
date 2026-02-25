# Changelog

## [v1.6.0] - 2026-02-25

### Added
- MTProto proxy support via `TELEGRAM_MT_PROXY` URL (`socks5://`, `socks4://`, `http://`, `mtproxy://`) or split env vars (`TELEGRAM_MT_PROXY_TYPE/HOST/PORT` with optional auth/secret).

### Changed
- `--help` now lists MTProto proxy environment variables.
- MTProto now prefers a Python runtime with an installed Telethon environment (including pipx `telethon` venv) so injected dependencies like `pysocks` are honored.

## [v1.5.2] - 2026-02-25

### Fixed
- `TELEGRAM_API_URL` handling now trims whitespace, ignores empty values, and strips trailing slashes before requests.

### Docs
- Added troubleshooting steps to verify which installed Fish function file is active and how to reinstall via Fisher.

## [v1.5.1] - 2025-12-20

### Changed
- Chat alias map now supports objects with `chat_id` and `username` (username preferred when present).

## [v1.5.0] - 2025-12-20

### Added
- MTProto mode for sending as a personal account (`--mtproto`/`--personal`) with new env vars.

## [v1.0.0] - 2025-06-11

### Added
- Telegram token, chat ID, and API endpoint pulled from env vars
- Supports three input modes: piped, direct string, and file input
- Optional headers: hostname (`PASTEGRAM_HOSTNAME=true`) and command (`PASTEGRAM_LAST_COMMAND=true`)
- HTML formatting for message headers and content blocks
- Automatic escaping of `<` and `>` characters
- File upload support with full file path and filename in caption
- Chunked message sending (Telegram 4096-char limit safe)

### Fixed
- Error handling for Telegram API and curl failures
- Corrected logic to prevent malformed HTML in message chunks


## [v1.1.0] - 2025-06-13

### Added
- File compression using `tar czvf` for files larger than 50MB
- Automatic chunking of compressed files into 49MB parts
- Telegram API retry-safe upload per chunk
- Enhanced caption with file name and full path

### Fixed
- Cross-platform `stat` compatibility (macOS/Linux)
- Better error detection for failed Telegram uploads

## [v1.2.0] - 2025-12-20

### Added
- `--id`/`-i` flag to override `TELEGRAM_CHAT_ID` per call (works for files, direct args, and stdin).

### Fixed
- Sending to channel/usernames like `@example` now works for files and messages (chat_id sent as literal text for both APIs).

## [v1.3.0] - 2025-12-20

### Added
- Alias lookup for `--id` via JSON map (default `~/.config/paste-gram/chat_ids.json`, override with `PASTEGRAM_ID_MAP`).
- `--id` now accepts numeric IDs, `@user`/`@channel`, or aliases.

## [v1.3.1] - 2025-12-20

### Added
- Auto-create `~/.config/paste-gram/chat_ids.json` with sample aliases on install (or first load) if missing.

## [v1.3.2] - 2025-12-20

### Changed
- The auto-created alias map now contains placeholder entries only; users must fill in their own IDs.

## [v1.4.0] - 2025-12-20

### Added
- Support multiple `--id`/`-i` values (repeat flags or comma-separate) to send to several chats in one command.

## [v1.4.1] - 2025-12-20

### Added
- Colored logs indicating each target chat during sends (messages and files).

### Changed
- Placeholder alias map and docs use generic sample names only (friend1/friend2/demo_channel).

## [v1.4.2] - 2025-12-20

### Added
- Fish completions for `paste-gram` and `ptg`, including alias suggestions from the ID map.

## [v1.4.3] - 2025-12-20

### Changed
- Logs prefer showing alias names alongside chat IDs when available.

# Changelog

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

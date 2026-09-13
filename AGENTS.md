# Repository Guidelines

## Project Structure & Module Organization
- Core function lives in `functions/paste-gram.fish`; keep new helpers in this file unless they warrant their own function file.
- Aliases load from `conf.d/paste-gram-alias.fish` (Fish autoloads everything in `conf.d/`). Mirror this pattern for any new shorthand commands.
- Tests and fixtures sit in `test/` (sample large file, helper scripts, log fixtures). Treat these as scratch space for local verification rather than a formal suite.
- User-facing docs are in `README.md`; version notes belong in `CHANGELOG.md`.

## Build, Test, and Development Commands
- `fish -c 'source functions/paste-gram.fish; paste-gram "hello world"'` — quick smoke test for message sending (requires `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`).
- `fish -c 'fisher install ./'` — install the plugin locally from the repo to test autoload behavior.
- `fish -c 'PTG_TMP=(mktemp); seq 1 5000 >$PTG_TMP; paste-gram $PTG_TMP'` — sample file upload; replace with a real path you can share.
- There is no build step; keep changes shell-native and cross-platform. File-size detection must support both GNU `stat` and macOS/BSD `stat` because Homebrew may change PATH precedence on macOS.

## Coding Style & Naming Conventions
- Fish scripts with two-space indentation; prefer `set -l` for locals and uppercase for env/config (e.g., `TELEGRAM_TOKEN`).
- Keep function names kebab-cased (`paste-gram`) to match Fish conventions; short aliases belong in `conf.d/`.
- Validate booleans case-insensitively when adding flags; guard all network calls with clear error messages.
- Use `mktemp` for temporary files and clean up when possible; avoid subshell-heavy code that harms portability.

## Testing Guidelines
- No automated CI exists; rely on manual checks. Verify both stdin and argument modes, plus file uploads over 50MB to confirm chunking/compression paths (`test/100mb_test_file` exists for this).
- When changing output formatting, confirm Telegram accepts the HTML payload (`parse_mode="HTML"`) and that chunk splitting still wraps `<pre>` correctly.
- Document any new env vars in `README.md` and ensure sensible defaults to avoid runtime failures.
- For MTProto, verify the automatic `$HOME/.venvs/venv3.14/bin/python` selection without virtualenv activation, and keep `TELEGRAM_MT_PYTHON` as the explicit override.
- MTProto defaults to `me` when no `--id` is supplied. External and multi-target sends must remain opt-in through `PASTEGRAM_MT_ALLOW_EXTERNAL` and `PASTEGRAM_MT_ALLOW_BROADCAST`.

## Commit & Pull Request Guidelines
- Write imperative, concise commit subjects; include a brief body if behavior or UX changes.
- Update `CHANGELOG.md` when user-visible behavior changes (new flags, new default caption fields, altered size thresholds).
- Pull requests should note tested platforms (macOS/Linux), test commands run, and any Telegram-side validation performed; include screenshots/log snippets only when they clarify behavior.
- Avoid committing tokens or chat IDs; use placeholder values in examples and sanitize captured logs before sharing.

## Security & Configuration Tips
- Never hardcode secrets; rely on exported env vars (`TELEGRAM_TOKEN`, `TELEGRAM_CHAT_ID`, optional `TELEGRAM_API_URL`, `PASTEGRAM_HOSTNAME`, `PASTEGRAM_LAST_COMMAND`, `TELEGRAM_MT_API_ID`, `TELEGRAM_MT_API_HASH`, and `TELEGRAM_MT_SESSION`).
- Treat MTProto as a user-account capability: do not add unattended bulk outreach, scraping, unsolicited messaging, or automatic replies. Keep the default destination as `me` and preserve the one-second delay unless the user has a documented reason to change it.
- Keep HTTP requests time-bounded (`--connect-timeout`, `--max-time`) and handle non-200 responses defensively with informative errors.
- When adding new temp files or directories, ensure they are unique per call and removed after use to prevent leaking message content.

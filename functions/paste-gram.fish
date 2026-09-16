function __paste_gram_file_size --argument-names file_path
    if not test -f "$file_path"
        echo "❌ File not found: $file_path" >&2
        return 1
    end

    # Homebrew may put GNU stat ahead of macOS BSD stat in PATH, even on Darwin.
    if stat --version >/dev/null 2>&1
        stat -c %s "$file_path"
    else
        stat -f %z "$file_path"
    end
end

function __paste_gram_display_path --argument-names path
    if test -z "$path"; or test -z "$HOME"
        printf '%s\n' "$path"
        return
    end

    if test "$path" = "$HOME"
        printf '~\n'
        return
    end

    set -l home_prefix "$HOME/"
    set -l prefix_length (string length -- "$home_prefix")
    if test (string sub -s 1 -l "$prefix_length" -- "$path") = "$home_prefix"
        printf '~/%s\n' (string sub -s (math "$prefix_length + 1") -- "$path")
    else
        printf '%s\n' "$path"
    end
end

function __paste_gram_normalize_bool --argument-names value setting_name
    switch (string lower -- "$value")
        case "true" "1" "yes"
            printf 'true\n'
        case "false" "0" "no"
            printf 'false\n'
        case "*"
            echo "❌ $setting_name must be true or false" >&2
            return 1
    end
end

function __paste_gram_open_editor --argument-names file_path
    set -l editor_command ""
    if set -q GIT_EDITOR; and test -n "$GIT_EDITOR"
        set editor_command "$GIT_EDITOR"
    else if set -q VISUAL; and test -n "$VISUAL"
        set editor_command "$VISUAL"
    else if set -q EDITOR; and test -n "$EDITOR"
        set editor_command "$EDITOR"
    else
        set editor_command "vi"
    end

    set -l editor_parts (string split ' ' -- "$editor_command")
    if test (count $editor_parts) -eq 0; or not command -sq "$editor_parts[1]"
        echo "❌ Caption editor not found: $editor_command" >&2
        return 1
    end

    command $editor_parts "$file_path"
end

function __paste_gram_append_user_caption --argument-names output_file caption_file
    if not test -s "$caption_file"
        return 0
    end

    printf '<b>Caption:</b>\n' >> "$output_file"
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$caption_file" >> "$output_file"
    printf '\n' >> "$output_file"
end

function __paste_gram_bot_request --argument-names api_url token method target_label verbose proxy_url
    set -l curl_args $argv[7..-1]
    if test -n "$proxy_url"
        set curl_args --proxy "$proxy_url" $curl_args
    end
    if test "$verbose" = "true"
        set -l api_url_display (string replace -r '\?.*$' '' -- "$api_url")
        set api_url_display (string replace -r '://[^/@]+@' '://<redacted>@' -- "$api_url_display")
        printf '[paste-gram verbose] request: POST %s/%s\n' "$api_url_display" "$method" >&2
        printf '[paste-gram verbose] request target: %s\n' "$target_label" >&2
        printf '[paste-gram verbose] request auth: Telegram bot token configured (redacted)\n' >&2
    end

    set -l response (curl -sS -X POST "$api_url/bot$token/$method" $curl_args)
    set -l curl_status $status

    if test "$verbose" = "true"
        printf '[paste-gram verbose] Telegram response:\n' >&2
        if test (count $response) -gt 0
            printf '%s\n' "$response" | jq . >&2 2>/dev/null
            if test $status -ne 0
                printf '%s\n' "$response" >&2
            end
        else
            printf '(empty response)\n' >&2
        end
    end

    if test $curl_status -ne 0
        echo "Error: Failed to connect to Telegram API!" >&2
        return $curl_status
    end

    printf '%s\n' "$response"
end

function __paste_gram_bot_send_long_caption --argument-names api_url token caption_path verbose proxy_url
    set -l target_chat_ids $argv[6..-1]
    set -l splitdir (mktemp -d)
    split -b 3800 "$caption_path" "$splitdir/chunk_"
    set -l request_status 0

    for target_chat_id in $target_chat_ids
        set -l response (__paste_gram_bot_request "$api_url" "$token" "sendMessage" "$target_chat_id" "$verbose" "$proxy_url" \
            --data-urlencode chat_id="$target_chat_id" \
            --data-urlencode text="<b>Caption:</b>" \
            -d parse_mode="HTML" \
            --connect-timeout 10 \
            --max-time 30)
        set request_status $status
        if test $request_status -ne 0; or not echo $response | jq -e '.ok' >/dev/null
            echo "Error: Failed to send long caption title to $target_chat_id" >&2
            rm -rf "$splitdir"
            return 1
        end

        for chunk in $splitdir/chunk_*
            set response (__paste_gram_bot_request "$api_url" "$token" "sendMessage" "$target_chat_id" "$verbose" "$proxy_url" \
                --data-urlencode chat_id="$target_chat_id" \
                --data-urlencode text="$(cat "$chunk")" \
                --connect-timeout 10 \
                --max-time 30)
            set request_status $status
            if test $request_status -ne 0; or not echo $response | jq -e '.ok' >/dev/null
                echo "Error: Failed to send long caption body to $target_chat_id" >&2
                rm -rf "$splitdir"
                return 1
            end
        end
    end

    rm -rf "$splitdir"
end

function __paste_gram_mtproto_send_long_caption --argument-names caption_path verbose
    set -l mtproto_chat_ids $argv[3..-1]
    set -l title_file (mktemp)
    set -l title_manifest (mktemp)
    set -l splitdir (mktemp -d)
    set -l body_manifest (mktemp)
    printf '<b>Caption:</b>\n' > "$title_file"
    printf '%s\n' "$title_file" > "$title_manifest"
    split -b 3800 "$caption_path" "$splitdir/chunk_"
    printf '%s\n' $splitdir/chunk_* > "$body_manifest"

    __paste_gram_mtproto_send "message" "$title_manifest" "" "" "$verbose" $mtproto_chat_ids
    if test $status -ne 0
        rm -f "$title_file" "$title_manifest" "$body_manifest"
        rm -rf "$splitdir"
        return 1
    end

    __paste_gram_mtproto_send "message_plain" "$body_manifest" "" "" "$verbose" $mtproto_chat_ids
    set -l request_status $status
    rm -f "$title_file" "$title_manifest" "$body_manifest"
    rm -rf "$splitdir"
    return $request_status
end

function __paste_gram_mtproto_send --argument-names mode manifest file_path caption_path verbose
    set -l mtproto_chat_ids $argv[6..-1]
    if test (count $mtproto_chat_ids) -eq 0
        echo "❌ MTProto requires a chat id (set TELEGRAM_CHAT_ID or pass --id)" >&2
        return 1
    end
    set -l api_id $TELEGRAM_MT_API_ID
    set -l api_hash $TELEGRAM_MT_API_HASH
    if test -z "$api_id"; or test -z "$api_hash"
        echo "❌ TELEGRAM_MT_API_ID and TELEGRAM_MT_API_HASH must be set for MTProto mode" >&2
        return 1
    end
    set -l session_path (set -q TELEGRAM_MT_SESSION; and echo $TELEGRAM_MT_SESSION; or echo "$HOME/.config/paste-gram/mtproto")
    set -l mt_proxy_url (set -q TELEGRAM_MT_PROXY; and echo $TELEGRAM_MT_PROXY; or echo "")
    set -l mt_proxy_type (set -q TELEGRAM_MT_PROXY_TYPE; and echo $TELEGRAM_MT_PROXY_TYPE; or echo "")
    set -l mt_proxy_host (set -q TELEGRAM_MT_PROXY_HOST; and echo $TELEGRAM_MT_PROXY_HOST; or echo "")
    set -l mt_proxy_port (set -q TELEGRAM_MT_PROXY_PORT; and echo $TELEGRAM_MT_PROXY_PORT; or echo "")
    set -l mt_proxy_username (set -q TELEGRAM_MT_PROXY_USERNAME; and echo $TELEGRAM_MT_PROXY_USERNAME; or echo "")
    set -l mt_proxy_password (set -q TELEGRAM_MT_PROXY_PASSWORD; and echo $TELEGRAM_MT_PROXY_PASSWORD; or echo "")
    set -l mt_proxy_secret (set -q TELEGRAM_MT_PROXY_SECRET; and echo $TELEGRAM_MT_PROXY_SECRET; or echo "")
    set -l mt_delay_seconds "1.0"
    if set -q PASTEGRAM_MT_DELAY_SECONDS
        set mt_delay_seconds "$PASTEGRAM_MT_DELAY_SECONDS"
    end
    mkdir -p (dirname "$session_path")

    set -l py_code 'import asyncio
import json
import os
import sys
from urllib.parse import parse_qs, unquote, urlparse

try:
    from telethon import TelegramClient
except Exception:
    sys.stderr.write("❌ MTProto requires the telethon package. Install with: pipx install telethon or pip install telethon\n")
    sys.exit(1)

def env(name, default=None):
    value = os.environ.get(name, default)
    if value is None:
        raise RuntimeError(f"Missing required env var: {name}")
    return value

mode = env("PASTEGRAM_MT_MODE")
manifest = os.environ.get("PASTEGRAM_MT_MANIFEST")
file_path = os.environ.get("PASTEGRAM_MT_FILE")
caption_path = os.environ.get("PASTEGRAM_MT_CAPTION")
chat_ids = [c for c in env("PASTEGRAM_MT_CHAT_IDS", "").split(",") if c]
api_id = int(env("PASTEGRAM_MT_API_ID"))
api_hash = env("PASTEGRAM_MT_API_HASH")
session = env("PASTEGRAM_MT_SESSION")
try:
    send_delay = max(0.0, float(os.environ.get("PASTEGRAM_MT_DELAY_SECONDS", "1.0")))
except ValueError:
    raise RuntimeError("PASTEGRAM_MT_DELAY_SECONDS must be a non-negative number")

async def pause_between_sends():
    if send_delay > 0:
        await asyncio.sleep(send_delay)

async def resolve_entity(client, chat):
    try:
        return await client.get_entity(chat)
    except Exception as exc:
        raise RuntimeError(
            f"Cannot resolve chat '{chat}'. Use @username, 'me', or start a dialog so it appears in your chats. ({exc})"
        )

def _normalize_proxy_type(raw):
    normalized = (raw or "").strip().lower()
    aliases = {
        "socks": "socks5",
        "socks5h": "socks5",
        "https": "http",
        "mt": "mtproxy",
    }
    return aliases.get(normalized, normalized)

def _proxy_from_url(raw_url):
    proxy_url = (raw_url or "").strip()
    if not proxy_url:
        return None
    parsed = urlparse(proxy_url)
    proxy_type = _normalize_proxy_type(parsed.scheme)
    host = parsed.hostname
    port = parsed.port
    username = unquote(parsed.username) if parsed.username else None
    password = unquote(parsed.password) if parsed.password else None
    secret = None

    if proxy_type == "mtproxy":
        query_secret = parse_qs(parsed.query).get("secret", [None])[0]
        path_secret = parsed.path.lstrip("/") if parsed.path else None
        secret = query_secret or path_secret or password

    return proxy_type, host, port, username, password, secret

def _proxy_from_parts():
    host = os.environ.get("TELEGRAM_MT_PROXY_HOST", "").strip()
    if not host:
        return None
    raw_port = os.environ.get("TELEGRAM_MT_PROXY_PORT", "").strip()
    try:
        port = int(raw_port) if raw_port else None
    except ValueError:
        raise RuntimeError("TELEGRAM_MT_PROXY_PORT must be a number")
    proxy_type = _normalize_proxy_type(os.environ.get("TELEGRAM_MT_PROXY_TYPE", "socks5"))
    username = os.environ.get("TELEGRAM_MT_PROXY_USERNAME", "").strip() or None
    password = os.environ.get("TELEGRAM_MT_PROXY_PASSWORD", "").strip() or None
    secret = os.environ.get("TELEGRAM_MT_PROXY_SECRET", "").strip() or None
    return proxy_type, host, port, username, password, secret

def build_client_kwargs():
    proxy_cfg = _proxy_from_url(os.environ.get("TELEGRAM_MT_PROXY")) or _proxy_from_parts()
    if not proxy_cfg:
        return {}

    proxy_type, host, port, username, password, secret = proxy_cfg
    if not proxy_type:
        raise RuntimeError("Unsupported MTProto proxy type ''. Use socks5, socks4, http, or mtproxy.")
    if not host:
        raise RuntimeError("MTProto proxy host is missing")
    if port is None:
        raise RuntimeError("MTProto proxy port is missing")

    if proxy_type == "mtproxy":
        if not secret:
            raise RuntimeError("MTProxy requires TELEGRAM_MT_PROXY_SECRET or mtproxy://.../?secret=<hex>")
        from telethon.network.connection import ConnectionTcpMTProxyRandomizedIntermediate
        return {
            "connection": ConnectionTcpMTProxyRandomizedIntermediate,
            "proxy": (host, port, secret),
        }

    if proxy_type not in {"socks5", "socks4", "http"}:
        raise RuntimeError(f"Unsupported MTProto proxy type '{proxy_type}'. Use socks5, socks4, http, or mtproxy.")

    if username:
        return {"proxy": (proxy_type, host, port, True, username, password or "")}
    return {"proxy": (proxy_type, host, port)}

def verbose_response(label, response):
    if os.environ.get("PASTEGRAM_MT_VERBOSE") != "true":
        return
    print(f"[paste-gram verbose] Telegram response ({label}):", file=sys.stderr)
    try:
        payload = response.to_dict() if hasattr(response, "to_dict") else response
        print(json.dumps(payload, default=str, indent=2, ensure_ascii=False), file=sys.stderr)
    except Exception:
        print(str(response), file=sys.stderr)

def verbose_proxy_description():
    raw_url = os.environ.get("TELEGRAM_MT_PROXY", "").strip()
    if raw_url:
        parsed = urlparse(raw_url)
        host = parsed.hostname or "?"
        port = parsed.port or "?"
        return f"{parsed.scheme or 'configured'}://{host}:{port} (credentials/secret redacted)"
    host = os.environ.get("TELEGRAM_MT_PROXY_HOST", "").strip()
    if host:
        proxy_type = _normalize_proxy_type(os.environ.get("TELEGRAM_MT_PROXY_TYPE", "socks5"))
        port = os.environ.get("TELEGRAM_MT_PROXY_PORT", "").strip() or "?"
        return f"{proxy_type}://{host}:{port} (credentials/secret redacted)"
    return "not configured"

async def main():
    client_kwargs = build_client_kwargs()
    if os.environ.get("PASTEGRAM_MT_VERBOSE") == "true":
        print(f"[paste-gram verbose] MTProto proxy: {verbose_proxy_description()}", file=sys.stderr)
        print(f"[paste-gram verbose] MTProto session: {session}", file=sys.stderr)
        chat_target_summary = ", ".join(chat_ids)
        print(f"[paste-gram verbose] MTProto target(s): {chat_target_summary}", file=sys.stderr)
    async with TelegramClient(session, api_id, api_hash, **client_kwargs) as client:
        await client.start()
        if mode in ("message", "message_plain"):
            if not manifest or not os.path.exists(manifest):
                raise RuntimeError("Missing message manifest for MTProto send")
            with open(manifest, "r", encoding="utf-8") as handle:
                message_files = [line.strip() for line in handle if line.strip()]
            if not message_files:
                raise RuntimeError("No message chunks found for MTProto send")
            message_parse_mode = "html" if mode == "message" else None
            for chat in chat_ids:
                entity = await resolve_entity(client, chat)
                for msg_file in message_files:
                    with open(msg_file, "r", encoding="utf-8") as mf:
                        text = mf.read()
                    sent_message = await client.send_message(entity, text, parse_mode=message_parse_mode)
                    verbose_response("send_message", sent_message)
                    await pause_between_sends()
        elif mode == "file":
            if not file_path:
                raise RuntimeError("Missing file path for MTProto send")
            caption = None
            if caption_path and os.path.exists(caption_path):
                with open(caption_path, "r", encoding="utf-8") as cf:
                    caption = cf.read()
            for chat in chat_ids:
                entity = await resolve_entity(client, chat)
                sent_message = await client.send_file(entity, file_path, caption=caption, parse_mode="html")
                verbose_response("send_file", sent_message)
                await pause_between_sends()
        else:
            raise RuntimeError(f"Unknown MTProto mode: {mode}")

try:
    asyncio.run(main())
except Exception as exc:
    sys.stderr.write(f"❌ MTProto send failed: {exc}\n")
    sys.exit(1)
'

    set -l python_cmd ""
    set -l python_args
    set -l python_candidates
    if set -q TELEGRAM_MT_PYTHON
        if test -n "$TELEGRAM_MT_PYTHON"
            set python_candidates "$TELEGRAM_MT_PYTHON"
        end
    end
    # Prefer the standard Codex/Python project environment without requiring activation.
    set python_candidates $python_candidates "$HOME/.venvs/venv3.14/bin/python" python3

    for candidate in $python_candidates
        if not test -x "$candidate"; and not command -sq "$candidate"
            continue
        end
        "$candidate" -c "import telethon" >/dev/null 2>&1
        if test $status -eq 0
            set python_cmd "$candidate"
            break
        end
    end

    set -l pipx_python ""
    if command -sq pipx
        set -l pipx_venvs (pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)
        if test -n "$pipx_venvs"
            set -l telethon_python "$pipx_venvs/telethon/bin/python"
            if test -x "$telethon_python"
                set pipx_python "$telethon_python"
            end
        end
    end

    if test -z "$python_cmd"; and test -n "$pipx_python"
        set python_cmd "$pipx_python"
        set python_args
    else if test -z "$python_cmd"; and command -sq pipx
        set python_cmd pipx
        set python_args run --spec telethon python
    else if test -z "$python_cmd"
        echo "❌ No Python interpreter with Telethon was found. Set TELEGRAM_MT_PYTHON or install Telethon." >&2
        return 1
    end

    if test "$verbose" = "true"
        printf '[paste-gram verbose] MTProto Python runtime: %s' "$python_cmd" >&2
        if test (count $python_args) -gt 0
            printf ' %s' (string join ' ' -- $python_args) >&2
        end
        printf '\n' >&2
    end

    if test -n "$mt_proxy_url"; or test -n "$mt_proxy_host"
        $python_cmd $python_args -c "import python_socks" >/dev/null 2>&1
        if test $status -ne 0
            echo "❌ MTProto proxy requires python-socks. Install with: python3 -m pip install 'python-socks[asyncio]'" >&2
            return 1
        end
    end

    env PASTEGRAM_MT_MODE="$mode" \
        PASTEGRAM_MT_MANIFEST="$manifest" \
        PASTEGRAM_MT_FILE="$file_path" \
        PASTEGRAM_MT_CAPTION="$caption_path" \
        PASTEGRAM_MT_CHAT_IDS=(string join "," -- $mtproto_chat_ids) \
        PASTEGRAM_MT_API_ID="$api_id" \
        PASTEGRAM_MT_API_HASH="$api_hash" \
        PASTEGRAM_MT_SESSION="$session_path" \
        TELEGRAM_MT_PROXY="$mt_proxy_url" \
        TELEGRAM_MT_PROXY_TYPE="$mt_proxy_type" \
        TELEGRAM_MT_PROXY_HOST="$mt_proxy_host" \
        TELEGRAM_MT_PROXY_PORT="$mt_proxy_port" \
        TELEGRAM_MT_PROXY_USERNAME="$mt_proxy_username" \
        TELEGRAM_MT_PROXY_PASSWORD="$mt_proxy_password" \
        TELEGRAM_MT_PROXY_SECRET="$mt_proxy_secret" \
        PASTEGRAM_MT_DELAY_SECONDS="$mt_delay_seconds" \
        PASTEGRAM_MT_VERBOSE="$verbose" \
        $python_cmd $python_args -c "$py_code"
    if test $status -ne 0
        return 1
    end
end

function paste-gram --description "Send text, files, or directories to Telegram" --argument cmdArg
    set -l pastegram_version "v1.7.0"
    set -l token $TELEGRAM_TOKEN
    set -l chat_id $TELEGRAM_CHAT_ID
    set -l api_url "https://api.telegram.org"
    if set -q TELEGRAM_API_URL
        set -l configured_api_url (string trim -- "$TELEGRAM_API_URL")
        if test -n "$configured_api_url"
            set api_url (string trim -r -c "/" -- "$configured_api_url")
        end
    end
    set -l api_url_override ""
    set -l curl_proxy_override ""
    set -l override_chat_ids
    set -l positional_args
    set -l id_map_path (set -q PASTEGRAM_ID_MAP; and echo $PASTEGRAM_ID_MAP; or echo "$HOME/.config/paste-gram/chat_ids.json")
    set -l mode_override ""
    set -l hostname_override ""
    set -l command_override ""
    set -l path_override ""
    set -l use_mtproto "false"
    set -l verbose "false"
    set -l allow_mt_external "false"
    set -l allow_mt_broadcast "false"
    set -l user_caption_requested "false"
    set -l user_caption_editor "false"
    set -l user_caption_text ""

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        set -l arg $argv[$i]
        switch $arg
            case "-h" "--help"
                printf "paste-gram — send text, files, or directories to Telegram\n\n"
                printf "Usage:\n"
                printf "  paste-gram \"message\"                 # send plain text\n"
                printf "  echo \"from pipe\" | paste-gram        # send stdin\n"
                printf "  paste-gram /path/to/file              # send file or directory (auto-archive/chunk >50MB)\n"
                printf "  paste-gram /path/one /path/two        # compress and send multiple files/directories as one archive\n"
                printf "  paste-gram -m \"caption\" /path/to/file # add a caption to a file or directory\n"
                printf "  paste-gram -m /path/to/file            # edit a long caption in the default editor\n"
                printf "  paste-gram --id @other_chat \"msg\"    # override TELEGRAM_CHAT_ID (numeric, alias, repeatable)\n"
                printf "  paste-gram --mtproto \"msg\"           # send via personal account (MTProto)\n"
                printf "  paste-gram --bot [api-url] \"msg\"    # force Bot API; optionally override its URL\n"
                printf "  paste-gram -v \"msg\"                 # show effective config and Telegram responses\n"
                printf "  PASTEGRAM_HOSTNAME=true PASTEGRAM_LAST_COMMAND=true paste-gram \"msg\"\n\n"
                printf "Env vars (required): TELEGRAM_TOKEN, TELEGRAM_CHAT_ID\n"
                printf "Env vars (optional): TELEGRAM_API_URL, PASTEGRAM_HOSTNAME=true|1, PASTEGRAM_LAST_COMMAND=true|1, PASTEGRAM_INCLUDE_PATH=true|false, PASTEGRAM_ID_MAP=<path to alias json>\n"
                printf "MTProto env vars (required for --mtproto): TELEGRAM_MT_API_ID, TELEGRAM_MT_API_HASH\n"
                printf "MTProto env vars (optional): TELEGRAM_MT_PYTHON=<path> TELEGRAM_MT_SESSION=<path> TELEGRAM_MT_PROXY=<url> TELEGRAM_MT_DELAY_SECONDS=<seconds>\n"
                printf "MTProto safety overrides: PASTEGRAM_MT_ALLOW_EXTERNAL=true PASTEGRAM_MT_ALLOW_BROADCAST=true\n"
                printf "Mode env vars: PASTEGRAM_DEFAULT_MODE=bot|mtproto; PASTEGRAM_USE_MT=true|false is supported for compatibility\n"
                printf "Flags (optional): -m|--message [caption], --api-url <url>, --proxy <url>, --hostname <true|false>, --last-command <true|false>, --include-path <true|false>, -v|--verbose, --id|-i <chat-id|alias> (repeatable), --mtproto/--personal, --bot/--bot-api [api-url]\n"
                printf "Version: -V|--version\n"
                printf "Dependencies: fish 3+, curl, jq, tar, split, stat, Python with telethon (MTProto), python-socks[asyncio] (MTProto proxy)\n"
                return 0
            case "-v" "--verbose"
                set verbose "true"
            case "--api-url"
                if test (math "$i + 1") -gt $argc
                    echo "❌ $arg requires an API URL" >&2
                    return 1
                end
                set api_url_override $argv[(math "$i + 1")]
                set i (math "$i + 1")
            case "--api-url=*"
                set api_url_override (string replace -- "--api-url=" "" -- "$arg")
            case "--proxy"
                if test (math "$i + 1") -gt $argc
                    echo "❌ $arg requires a proxy URL" >&2
                    return 1
                end
                set curl_proxy_override $argv[(math "$i + 1")]
                set i (math "$i + 1")
            case "--proxy=*"
                set curl_proxy_override (string replace -- "--proxy=" "" -- "$arg")
            case "--hostname" "--include-hostname"
                if test (math "$i + 1") -gt $argc
                    echo "❌ $arg requires true or false" >&2
                    return 1
                end
                set hostname_override $argv[(math "$i + 1")]
                set i (math "$i + 1")
            case "--hostname=*" "--include-hostname=*"
                set hostname_override (string replace -r '^--(include-)?hostname=' '' -- "$arg")
            case "--last-command" "--include-command"
                if test (math "$i + 1") -gt $argc
                    echo "❌ $arg requires true or false" >&2
                    return 1
                end
                set command_override $argv[(math "$i + 1")]
                set i (math "$i + 1")
            case "--last-command=*" "--include-command=*"
                set command_override (string replace -r '^--(include-)?(last-command|command)=' '' -- "$arg")
            case "--include-path"
                if test (math "$i + 1") -gt $argc
                    echo "❌ $arg requires true or false" >&2
                    return 1
                end
                set path_override $argv[(math "$i + 1")]
                set i (math "$i + 1")
            case "--include-path=*"
                set path_override (string replace -- "--include-path=" "" -- "$arg")
            case "-m" "--message"
                set user_caption_requested "true"
                if test (math "$i + 1") -le $argc
                    set -l message_arg $argv[(math "$i + 1")]
                    if test "$message_arg" != "--"; and not string match -qr '^-' -- "$message_arg"; and not test -f "$message_arg"; and not test -d "$message_arg"
                        set user_caption_text "$message_arg"
                        set i (math "$i + 1")
                    else
                        set user_caption_editor "true"
                    end
                else
                    set user_caption_editor "true"
                end
            case "-V" "--version"
                printf "paste-gram %s\n" $pastegram_version
                return 0
            case "-i" "--id" "-id"
                if test (math "$i + 1") -le $argc
                    set -l raw_value $argv[(math "$i + 1")]
                    set override_chat_ids $override_chat_ids (string split "," -- $raw_value)
                    set i (math "$i + 1")
                else
                    echo "❌ --id requires a chat identifier" >&2
                    return 1
                end
            case "--mtproto" "--personal"
                set mode_override "mtproto"
            case "--bot" "--bot-api"
                set mode_override "bot"
                if test (math "$i + 1") -le $argc
                    set -l bot_api_candidate $argv[(math "$i + 1")]
                    if string match -qr '^https?://' -- "$bot_api_candidate"
                        set api_url_override $bot_api_candidate
                        set i (math "$i + 1")
                    end
                end
            case "--bot=*" "--bot-api=*"
                set mode_override "bot"
                set api_url_override (string replace -r '^--(bot-api|bot)=' '' -- "$arg")
            case "--id=*"
                set -l raw_value (string replace -- "--id=" "" $arg)
                set override_chat_ids $override_chat_ids (string split "," -- $raw_value)
            case "-i=*"
                set -l raw_value (string replace -- "-i=" "" $arg)
                set override_chat_ids $override_chat_ids (string split "," -- $raw_value)
            case "--message=*"
                set user_caption_requested "true"
                set user_caption_text (string replace -- "--message=" "" $arg)
                if test -z "$user_caption_text"
                    set user_caption_editor "true"
                end
            case "-m=*"
                set user_caption_requested "true"
                set user_caption_text (string replace -- "-m=" "" $arg)
                if test -z "$user_caption_text"
                    set user_caption_editor "true"
                end
            case "--"
                if test $i -lt $argc
                    set positional_args $positional_args $argv[(math "$i + 1")..-1]
                end
                break
            case "*"
                set positional_args $positional_args $arg
        end
        set i (math "$i + 1")
    end

    if test -n "$api_url_override"
        set api_url (string trim -r -c "/" -- (string trim -- "$api_url_override"))
    end

    set -l default_mode "bot"
    if set -q PASTEGRAM_DEFAULT_MODE
        switch (string lower -- $PASTEGRAM_DEFAULT_MODE)
            case "bot" "bot-api" "api"
                set default_mode "bot"
            case "mtproto" "personal"
                set default_mode "mtproto"
            case "*"
                echo "❌ PASTEGRAM_DEFAULT_MODE must be bot or mtproto" >&2
                return 1
        end
    end

    if test $default_mode = "mtproto"
        set use_mtproto "true"
    end

    if set -q PASTEGRAM_USE_MT
        switch (string lower -- $PASTEGRAM_USE_MT)
            case "true" "1" "yes"
                set use_mtproto "true"
            case "false" "0" "no"
                set use_mtproto "false"
            case "*"
                echo "❌ PASTEGRAM_USE_MT must be true or false" >&2
                return 1
        end
    end

    if test $mode_override = "mtproto"
        set use_mtproto "true"
    else if test $mode_override = "bot"
        set use_mtproto "false"
    end

    if set -q PASTEGRAM_MT_ALLOW_EXTERNAL
        switch (string lower -- $PASTEGRAM_MT_ALLOW_EXTERNAL)
            case "true" "1" "yes"
                set allow_mt_external "true"
            case "false" "0" "no"
                set allow_mt_external "false"
            case "*"
                echo "❌ PASTEGRAM_MT_ALLOW_EXTERNAL must be true or false" >&2
                return 1
        end
    end

    if set -q PASTEGRAM_MT_ALLOW_BROADCAST
        switch (string lower -- $PASTEGRAM_MT_ALLOW_BROADCAST)
            case "true" "1" "yes"
                set allow_mt_broadcast "true"
            case "false" "0" "no"
                set allow_mt_broadcast "false"
            case "*"
                echo "❌ PASTEGRAM_MT_ALLOW_BROADCAST must be true or false" >&2
                return 1
        end
    end

    set -l mode_label "Bot API"
    if test $use_mtproto = "true"
        set mode_label "MTProto (personal account)"
    end

    set -l input_kind "none"
    set -l input_detail "no input"
    if isatty stdin
        if test -n "$positional_args"
            if test (count $positional_args) -gt 1
                if test -f "$positional_args[1]"; or test -d "$positional_args[1]"
                    set input_kind "multiple files/directories"
                    set input_detail (count $positional_args)" positional inputs"
                else
                    set input_kind "argument"
                    set input_detail "argument text (content hidden)"
                end
            else if test -f "$positional_args[1]"
                set input_kind "file"
                set input_detail "$positional_args[1]"
            else if test -d "$positional_args[1]"
                set input_kind "directory"
                set input_detail "$positional_args[1]"
            else
                set input_kind "argument"
                set input_detail "argument text (content hidden)"
            end
        end
    else
        set input_kind "stdin"
        set input_detail "pipe/stdin"
    end

    set -l requested_target_display "$chat_id"
    set -l target_source "TELEGRAM_CHAT_ID"
    if test (count $override_chat_ids) -gt 0
        set requested_target_display (string join ', ' -- $override_chat_ids)
        set target_source "command-line --id"
    else if test $use_mtproto = "true"
        set requested_target_display "me (default Saved Messages)"
        set target_source "MTProto default"
    end

    set -l include_hostname (set -q PASTEGRAM_HOSTNAME; and echo $PASTEGRAM_HOSTNAME; or echo "false")
    set include_hostname (__paste_gram_normalize_bool "$include_hostname" "PASTEGRAM_HOSTNAME")
    if test $status -ne 0
        return 1
    end
    if test -n "$hostname_override"
        set include_hostname (__paste_gram_normalize_bool "$hostname_override" "--hostname")
        if test $status -ne 0
            return 1
        end
    end

    set -l include_command (set -q PASTEGRAM_LAST_COMMAND; and echo $PASTEGRAM_LAST_COMMAND; or echo "false")
    set include_command (__paste_gram_normalize_bool "$include_command" "PASTEGRAM_LAST_COMMAND")
    if test $status -ne 0
        return 1
    end
    if test -n "$command_override"
        set include_command (__paste_gram_normalize_bool "$command_override" "--last-command")
        if test $status -ne 0
            return 1
        end
    end

    set -l include_path "true"
    if set -q PASTEGRAM_INCLUDE_PATH
        set include_path $PASTEGRAM_INCLUDE_PATH
    end
    set include_path (__paste_gram_normalize_bool "$include_path" "PASTEGRAM_INCLUDE_PATH")
    if test $status -ne 0
        return 1
    end
    if test -n "$path_override"
        set include_path (__paste_gram_normalize_bool "$path_override" "--include-path")
        if test $status -ne 0
            return 1
        end
    end

    if test "$verbose" = "true"
        printf '[paste-gram verbose] version: %s\n' "$pastegram_version" >&2
        printf '[paste-gram verbose] mode: %s\n' "$mode_label" >&2
        printf '[paste-gram verbose] mode selection: default=%s override=%s\n' "$default_mode" (test -n "$mode_override"; and echo "$mode_override"; or echo "none") >&2
        printf '[paste-gram verbose] input: %s (%s)\n' "$input_kind" "$input_detail" >&2
        printf '[paste-gram verbose] requested target(s): %s\n' "$requested_target_display" >&2
        printf '[paste-gram verbose] target source: %s\n' "$target_source" >&2
        set -l api_url_display (string replace -r '\?.*$' '' -- "$api_url")
        set api_url_display (string replace -r '://[^/@]+@' '://<redacted>@' -- "$api_url_display")
        if test "$use_mtproto" = "true"
            printf '[paste-gram verbose] Bot API URL (not used in MTProto): %s\n' "$api_url_display" >&2
        else
            printf '[paste-gram verbose] API URL: %s\n' "$api_url_display" >&2
        end
        if test "$use_mtproto" = "true"
            if set -q TELEGRAM_MT_PROXY; and test -n "$TELEGRAM_MT_PROXY"
                set -l mt_proxy_type (string split -m 1 ':' -- "$TELEGRAM_MT_PROXY")[1]
                printf '[paste-gram verbose] proxy: %s URL configured (credentials/secret redacted)\n' "$mt_proxy_type" >&2
            else if set -q TELEGRAM_MT_PROXY_HOST; and test -n "$TELEGRAM_MT_PROXY_HOST"
                set -l mt_proxy_type "socks5"
                if set -q TELEGRAM_MT_PROXY_TYPE; and test -n "$TELEGRAM_MT_PROXY_TYPE"
                    set mt_proxy_type (string lower -- "$TELEGRAM_MT_PROXY_TYPE")
                end
                set -l mt_proxy_port "?"
                if set -q TELEGRAM_MT_PROXY_PORT; and test -n "$TELEGRAM_MT_PROXY_PORT"
                    set mt_proxy_port "$TELEGRAM_MT_PROXY_PORT"
                end
                printf '[paste-gram verbose] proxy: %s://%s:%s (credentials/secret redacted)\n' "$mt_proxy_type" "$TELEGRAM_MT_PROXY_HOST" "$mt_proxy_port" >&2
            else
                printf '[paste-gram verbose] proxy: not configured\n' >&2
            end
            set -l mt_session_path (set -q TELEGRAM_MT_SESSION; and echo $TELEGRAM_MT_SESSION; or echo "$HOME/.config/paste-gram/mtproto")
            set -l mt_delay "1.0"
            if set -q PASTEGRAM_MT_DELAY_SECONDS
                set mt_delay "$PASTEGRAM_MT_DELAY_SECONDS"
            end
            printf '[paste-gram verbose] MTProto session: %s\n' "$mt_session_path" >&2
            printf '[paste-gram verbose] MTProto delay: %ss\n' "$mt_delay" >&2
            if set -q TELEGRAM_MT_API_ID; and set -q TELEGRAM_MT_API_HASH
                printf '[paste-gram verbose] MTProto API credentials: configured (redacted)\n' >&2
            else
                printf '[paste-gram verbose] MTProto API credentials: missing\n' >&2
            end
        else
            if set -q TELEGRAM_TOKEN; and test -n "$TELEGRAM_TOKEN"
                printf '[paste-gram verbose] bot token: configured (redacted)\n' >&2
            else
                printf '[paste-gram verbose] bot token: missing\n' >&2
            end
            set -l proxy_env_names
            for proxy_var in HTTPS_PROXY HTTP_PROXY ALL_PROXY https_proxy http_proxy all_proxy
                if set -q $proxy_var
                    set proxy_env_names $proxy_env_names $proxy_var
                end
            end
            if test (count $proxy_env_names) -gt 0
                printf '[paste-gram verbose] curl proxy environment: %s (values hidden)\n' (string join ', ' -- $proxy_env_names) >&2
            else
                printf '[paste-gram verbose] curl proxy environment: not configured\n' >&2
            end
            if test -n "$curl_proxy_override"
                printf '[paste-gram verbose] inline curl proxy: configured (value hidden)\n' >&2
            end
        end
        printf '[paste-gram verbose] hostname metadata: %s\n' "$include_hostname" >&2
        printf '[paste-gram verbose] last-command metadata: %s\n' "$include_command" >&2
    end

    if test $use_mtproto = "true"
        if test (count $override_chat_ids) -gt 1; and test $allow_mt_broadcast != "true"
            echo "❌ MTProto broadcast is blocked by default. Set PASTEGRAM_MT_ALLOW_BROADCAST=true only for intentional, consented multi-target sends." >&2
            return 1
        end
        for requested_chat in $override_chat_ids
            set -l requested_chat_lower (string lower -- $requested_chat)
            if test $requested_chat_lower != "me"; and test $requested_chat_lower != "self"; and test $allow_mt_external != "true"
                echo "❌ External MTProto targets are blocked by default. Use --id me, or set PASTEGRAM_MT_ALLOW_EXTERNAL=true only for an expected recipient." >&2
                return 1
            end
        end
    end

    if test $use_mtproto != "true"
        if test -z "$token"
            echo "❌ TELEGRAM_TOKEN must be set" >&2
            return 1
        end
    end
    if test (count $override_chat_ids) -eq 0; and test -z "$chat_id"; and test $use_mtproto != "true"
        echo "❌ TELEGRAM_CHAT_ID must be set or pass --id" >&2
        return 1
    end

    set -l chat_ids
    set -l chat_labels
    set -l to_resolve
    if test (count $override_chat_ids) -gt 0
        set to_resolve $override_chat_ids
    else if test $use_mtproto = "true"
        set to_resolve "me"
    else
        set to_resolve $chat_id
    end

    for candidate in $to_resolve
        set -l resolved_id $candidate
        set -l display_label $candidate
        if test $use_mtproto = "true"
            set -l candidate_lower (string lower -- $resolved_id)
            if test $candidate_lower = "me"; or test $candidate_lower = "self"
                set resolved_id "me"
                set display_label "me"
                set chat_ids $chat_ids $resolved_id
                set chat_labels $chat_labels $display_label
                continue
            end
        end
        if not string match -qr '^@' -- $resolved_id
            if not string match -qr '^[-]?[0-9]+$' -- $resolved_id
                if test -f "$id_map_path"
                    set -l map_value (jq -r --arg key "$resolved_id" --arg prefer_username "$use_mtproto" '
                        if has($key) then
                            if (.[$key] | type) == "object" then
                                if $prefer_username == "true" then
                                    .[$key].username // .[$key].chat_id // empty
                                else
                                    .[$key].chat_id // .[$key].username // empty
                                end
                            else
                                .[$key]
                            end
                        else
                            empty
                        end' "$id_map_path" 2>/dev/null)
                    if test -n "$map_value"
                        set resolved_id $map_value
                        set -l map_username (jq -r --arg key "$candidate" '
                            if has($key) and (.[$key] | type) == "object" then
                                .[$key].username // empty
                            else
                                empty
                            end' "$id_map_path" 2>/dev/null)
                        if test -n "$map_username"
                            set display_label "$candidate ($map_username)"
                        else
                            set display_label "$candidate ($resolved_id)"
                        end
                    else
                        echo "❌ chat id alias '$resolved_id' not found in $id_map_path" >&2
                        return 1
                    end
                else
                    echo "❌ chat id alias '$resolved_id' not found and map file missing at $id_map_path" >&2
                    return 1
                end
            else if test -f "$id_map_path"
                set -l alias_value (jq -r --arg value "$resolved_id" '
                    to_entries[]
                    | select(
                        ((.value | type) == "object") and (.value.chat_id == $value or .value.username == $value)
                        or ((.value | type) != "object") and (.value == $value)
                    )
                    | .key' "$id_map_path" 2>/dev/null | head -n 1)
                if test -n "$alias_value"
                    set display_label "$alias_value ($resolved_id)"
                end
            end
        end
        set chat_ids $chat_ids $resolved_id
        set chat_labels $chat_labels $display_label
    end

    set -l color_ok (set_color green)
    set -l color_info (set_color cyan)
    set -l color_reset (set_color normal)
    echo "$color_info→ Target chat IDs:" $chat_labels $color_reset

    set -l m_hostname (hostname)

    #sync_history
    history --merge
    set -l full_cmd (history --max 2 | head -n 1)
    set -l display_full_cmd (string replace -a -- "$HOME" "~" "$full_cmd")

    if test "$verbose" = "true"
        printf '[paste-gram verbose] resolved target(s): %s\n' (string join ', ' -- $chat_labels) >&2
    end

    set -l head_message_text_file (mktemp)
    set -l body_meesage_text_file (mktemp)
    set -l message_text_file (mktemp)
    set -l splitdir (mktemp -d)
    set -l compressdir (mktemp -d)
    set -l user_caption_file ""
    set -l metadata_caption_file ""

    if test "$user_caption_requested" = "true"
        set user_caption_file (mktemp)
        if test "$user_caption_editor" = "true"
            if not __paste_gram_open_editor "$user_caption_file"
                rm -f "$user_caption_file"
                return 1
            end
        else
            printf '%s\n' "$user_caption_text" > "$user_caption_file"
        end
        if test "$verbose" = "true"
            if test "$user_caption_editor" = "true"
                set -l editor_display "vi"
                if set -q GIT_EDITOR; and test -n "$GIT_EDITOR"
                    set editor_display "$GIT_EDITOR"
                else if set -q VISUAL; and test -n "$VISUAL"
                    set editor_display "$VISUAL"
                else if set -q EDITOR; and test -n "$EDITOR"
                    set editor_display "$EDITOR"
                end
                printf '[paste-gram verbose] user caption: edited in %s\n' "$editor_display" >&2
            else
                printf '[paste-gram verbose] user caption: inline text configured (content hidden)\n' >&2
            end
        end
    end




    if test $include_hostname = "true"; or \
       test $include_hostname = "True"; or \
       test $include_hostname = "1"
        echo -e "<b>Host:</b> <u>$m_hostname</u>" >> "$head_message_text_file"
        printf '\n' >> "$head_message_text_file"
#         echo -e "Hostname: $m_hostname"
    end

    if test $include_command = "true"; or \
       test $include_command = "True"; or \
       test $include_command = "1"
        echo -e "<b>Command:</b>" >> "$head_message_text_file"
        echo -e "\$ <b>$display_full_cmd</b>" >> "$head_message_text_file"
        printf '\n' >> "$head_message_text_file"
#         echo -e "FullCommand: $full_cmd"
    end

    #cat $head_message_text_file

#++++++++++++++++++++++++++++++++++++++++++

    if isatty stdin
        if test -n "$positional_args"
        #echo "Reading from arguments..."
            if test -f "$positional_args[1]"; or test -d "$positional_args[1]"
                set -l invalid_input ""
                for candidate in $positional_args
                    if not test -f "$candidate"; and not test -d "$candidate"
                        set invalid_input "$candidate"
                        break
                    end
                end
                if test -n "$invalid_input"
                    echo "❌ Multiple file inputs must all be existing files or directories: $invalid_input" >&2
                    return 1
                end

                set -f file $positional_args[1]
                set -l abs_path (realpath "$file")
                set -l source_path "$abs_path"
                set -l source_name (basename "$abs_path")
                set -l is_directory "false"
                set -l is_bundle "false"
                if test (count $positional_args) -gt 1
                    set is_bundle "true"
                    set is_directory "true"
                    set source_name "paste-gram-files"
                    echo "Compressing multiple files and directories..."
                else if test -d "$file"
                    set is_directory "true"
                    echo "Compressing directory..."
                else
                    echo "Uploading file..."
                end

                set file_name "$source_name"
                set dir_name (dirname "$abs_path")
                set file_size 0

                if test "$is_bundle" = "true"
                    set -l tar_file "$compressdir/$source_name.tgz"
                    if not tar -czf "$tar_file" $positional_args
                        echo "❌ Failed to compress multiple inputs" >&2
                        return 1
                    end
                    set file "$tar_file"
                    set file_name (basename "$tar_file")
                    set file_size (__paste_gram_file_size "$file")
                    if test $status -ne 0
                        return 1
                    end
                else if test "$is_directory" = "true"
                    set -l tar_file "$compressdir/$source_name.tgz"
                    if not tar -czf "$tar_file" -C "$dir_name" "$source_name"
                        echo "❌ Failed to compress directory: $source_path" >&2
                        return 1
                    end
                    set file "$tar_file"
                    set file_name (basename "$tar_file")
                    set file_size (__paste_gram_file_size "$file")
                    if test $status -ne 0
                        return 1
                    end
                else
                    set file_size (__paste_gram_file_size "$file")
                    if test $status -ne 0
                        return 1
                    end
                    set file "$abs_path"
                end

                if test "$verbose" = "true"
                    if test "$is_bundle" = "true"
                        printf '[paste-gram verbose] bundled input paths:\n' >&2
                        for input_path in $positional_args
                            printf '  %s\n' (realpath "$input_path") >&2
                        end
                    else
                        printf '[paste-gram verbose] file path: %s\n' "$source_path" >&2
                    end
                    printf '[paste-gram verbose] file size: %s bytes\n' "$file_size" >&2
                    if test "$is_bundle" = "true"
                        printf '[paste-gram verbose] multiple-input delivery: archived as %s\n' "$file_name" >&2
                    else if test "$is_directory" = "true"
                        printf '[paste-gram verbose] directory delivery: archived as %s\n' "$file_name" >&2
                    end
                end

                set file_size_mb (math "$file_size / 1024 / 1024")

                echo -e "File Size: $file_size_mb MB"

                set -l display_path (__paste_gram_display_path "$source_path")
                __paste_gram_append_user_caption "$message_text_file" "$user_caption_file"
                cat "$head_message_text_file" >> "$message_text_file"
                if test "$include_path" = "true"
                    if test "$is_bundle" = "true"
                        printf '<b>PATH:</b>\n' >> "$message_text_file"
                        for input_path in $positional_args
                            printf '<u>%s</u>\n' (__paste_gram_display_path (realpath "$input_path")) >> "$message_text_file"
                        end
                    else if test "$is_directory" = "true"
                        printf '<b>PATH:</b>\n' >> "$message_text_file"
                        printf '<u>%s</u>\n' "$display_path" >> "$message_text_file"
                    else
                        printf '<b>FILE:</b>\n' >> "$message_text_file"
                        printf '<u>%s</u>\n' "$display_path" >> "$message_text_file"
                    end
                end

                #++++++++++++++++++++++++++++++++++++++
                if test "$file_size_mb" -gt 50
                    if test "$is_directory" = "true"
                        if test "$verbose" = "true"
                            printf '[paste-gram verbose] directory archive exceeds 50MB; sending archive chunks directly\n' >&2
                        end
                    else if test $use_mtproto = "true"
                        echo -e "MTProto mode: sending file without Bot API size limits."
                        if test "$verbose" = "true"
                            printf '[paste-gram verbose] file delivery: direct MTProto upload\n' >&2
                        end
                    else
                        # Compress the file first
                        echo -e "Compress the file first."

                        set -l tar_file "$compressdir/$file_name.tgz"
                        if not tar -czf "$tar_file" -C "$dir_name" "$file_name"
                            echo "❌ Failed to compress file: $source_path" >&2
                            return 1
                        end

                        set file_size (__paste_gram_file_size "$tar_file")
                        if test $status -ne 0
                            return 1
                        end

                        set  file_size_mb (math "$file_size / 1024 / 1024")
                        echo -e "File size after compress: $file_size_mb MB"
                        if test "$verbose" = "true"
                            printf '[paste-gram verbose] file delivery: compressed then split into Bot API chunks\n' >&2
                        end
                        set  file $tar_file
                        set  file_name (basename "$tar_file")
                        set  abs_path (realpath $tar_file)
                    end

                end

                set -l upload_caption_file "$message_text_file"
                if test "$user_caption_requested" = "true"
                    set -l caption_characters (wc -m < "$message_text_file" | string trim)
                    if test "$caption_characters" -gt 1024
                        echo "Long caption exceeds Telegram's document-caption limit; sending it as text before the file."
                        if test $use_mtproto = "true"
                            __paste_gram_mtproto_send_long_caption "$user_caption_file" "$verbose" $chat_ids
                        else
                            __paste_gram_bot_send_long_caption "$api_url" "$token" "$user_caption_file" "$verbose" "$curl_proxy_override" $chat_ids
                        end
                        if test $status -ne 0
                            return 1
                        end

                        set metadata_caption_file (mktemp)
                        cat "$head_message_text_file" > "$metadata_caption_file"
                        if test "$include_path" = "true"
                            if test "$is_bundle" = "true"
                                printf '<b>PATH:</b>\n' >> "$metadata_caption_file"
                                for input_path in $positional_args
                                    printf '<u>%s</u>\n' (__paste_gram_display_path (realpath "$input_path")) >> "$metadata_caption_file"
                                end
                            else if test "$is_directory" = "true"
                                printf '<b>PATH:</b>\n' >> "$metadata_caption_file"
                                printf '<u>%s</u>\n' "$display_path" >> "$metadata_caption_file"
                            else
                                printf '<b>FILE:</b>\n' >> "$metadata_caption_file"
                                printf '<u>%s</u>\n' "$display_path" >> "$metadata_caption_file"
                            end
                        end
                        set upload_caption_file "$metadata_caption_file"
                    end
                end

                if test "$file_size_mb" -gt 50
                    if test $use_mtproto = "true"
                        __paste_gram_mtproto_send "file" "" "$file" "$upload_caption_file" "$verbose" $chat_ids
                    else
                        echo -e "Sending the compressed file in chunks."
                        split -b 49MB -d "$file" $splitdir/"$file_name"_
                        for i in "$splitdir/$file_name"_*
                            for idx in (seq (count $chat_ids))
                                set -l target_chat_id $chat_ids[$idx]
                                set -l target_label $chat_labels[$idx]
                                echo "$color_info→ sending chunk "(basename $i)" to $target_label$color_reset"
                                set response (__paste_gram_bot_request "$api_url" "$token" "sendDocument" "$target_label" "$verbose" "$curl_proxy_override" \
                                    --form-string chat_id="$target_chat_id" \
                                    -F "document=@$i" \
                                    --form-string caption="$(cat "$upload_caption_file")" \
                                    --form-string parse_mode="HTML" \
                                    --connect-timeout 10 \
                                    --max-time 30)
                                set request_status $status

                                set -l status_ok (echo $response | jq .ok)
                                set -l status_description (echo $response | jq .description)

                                if test $request_status -ne 0
                                    echo "Error: Failed to connect to Telegram API!"
                                    return 1
                                end

                                if not echo $response | jq -e '.ok' >/dev/null
                                    echo "Error: Failed to send chunk: "(echo $response | jq -r '.description // "Unknown error"')
                                    return 1
                                end
                                echo "$color_ok✓ sent chunk "(basename $i)" to $target_label$color_reset"
                            end
                            rm -f "$i"
                        end
                    end
                else

                    if test "$verbose" = "true"
                        printf '[paste-gram verbose] file delivery: single upload\n' >&2
                    end

                    if test $use_mtproto = "true"
                        __paste_gram_mtproto_send "file" "" "$file" "$upload_caption_file" "$verbose" $chat_ids
                    else
                        for idx in (seq (count $chat_ids))
                            set -l target_chat_id $chat_ids[$idx]
                            set -l target_label $chat_labels[$idx]
                            echo "$color_info→ sending file $file_name to $target_label$color_reset"
                            set response (__paste_gram_bot_request "$api_url" "$token" "sendDocument" "$target_label" "$verbose" "$curl_proxy_override" \
                                --form-string chat_id="$target_chat_id" \
                                -F "document=@$file" \
                                --form-string caption="$(cat "$upload_caption_file")" \
                                --form-string parse_mode="HTML" \
                                --connect-timeout 10 \
                                --max-time 30)
                            set request_status $status

                            set -l status_ok (echo $response | jq .ok)
                            set -l status_description (echo $response | jq .description)

                            if test $request_status -ne 0
                                echo "Error: Failed to connect to Telegram API!"
                                return 1
                            end

                            if not echo $response | jq -e '.ok' >/dev/null
                                echo "Error: Failed to send chunk: "(echo $response | jq -r '.description // "Unknown error"')
                                return 1
                            end
                            echo "$color_ok✓ sent file $file_name to $target_label$color_reset"
                        end
                    end
                end
                #++++++++++++++++++++++++++++++++++++++

            else
#                 echo "string from argument: $argv"
                set -l message $positional_args[1]
                echo -e "$message" >> "$body_meesage_text_file"
                if test (uname) = "Darwin"
                    sed -i '' 's#<#-#g' $body_meesage_text_file
                    sed -i '' 's#>#-#g' $body_meesage_text_file
                else
                    sed -i 's#<#-#g' $body_meesage_text_file
                    sed -i 's#>#-#g' $body_meesage_text_file
                end
                __paste_gram_append_user_caption "$message_text_file" "$user_caption_file"
                cat "$head_message_text_file" >> "$message_text_file"
                echo -e "<pre>" >> "$message_text_file"
                cat "$body_meesage_text_file" >> "$message_text_file"
                echo -e "</pre>" >> "$message_text_file"

                # Split file into chunks
                split -b 3800 $message_text_file $splitdir/chunk_
                # find the very last chunk
                set -l last_chunk (ls $splitdir/chunk_* | sort | tail -n1)

                # Wrap chunks for Telegram HTML parsing
                for chunk in $splitdir/chunk_*
                    # 1) First chunk: append closing </pre> if it’s not already there
                    if test $chunk = "$splitdir/chunk_aa"; and not grep -q '</pre>' "$chunk"
                        echo '</pre>' >>"$chunk"
                    end
                    # 2) Middle chunks: wrap in both <pre>…</pre>
                    if test $chunk != "$splitdir/chunk_aa"; and test $chunk != "$last_chunk"
                        echo '<pre>' | cat - "$chunk" >"$chunk.tmp"
                        mv "$chunk.tmp" "$chunk"
                        echo '</pre>' >>"$chunk"
                    end
                    # 3) Last chunk: prepend opening <pre> if it’s not already there
                    if test $chunk = "$last_chunk"; and not grep -q '<pre>' "$chunk"
                        echo '<pre>' | cat - "$chunk" >"$chunk.tmp"
                        mv "$chunk.tmp" "$chunk"
                    end
                end

                if test $use_mtproto = "true"
                    set -l mtproto_manifest (mktemp)
                    printf "%s\n" $splitdir/chunk_* > "$mtproto_manifest"
                    __paste_gram_mtproto_send "message" "$mtproto_manifest" "" "" "$verbose" $chat_ids
                    rm -f "$mtproto_manifest"
                else
                    # Send each chunk
                    for chunk in $splitdir/chunk_*
                        for idx in (seq (count $chat_ids))
                            set -l target_chat_id $chat_ids[$idx]
                            set -l target_label $chat_labels[$idx]
                            echo "$color_info→ sending chunk "(basename $chunk)" to $target_label$color_reset"
                            set response (__paste_gram_bot_request "$api_url" "$token" "sendMessage" "$target_label" "$verbose" "$curl_proxy_override" \
                                --data-urlencode chat_id="$target_chat_id" \
                                --data-urlencode text="$(cat $message_text_file)" \
                                -d parse_mode="HTML" \
                                --connect-timeout 10 \
                                --max-time 30)
                            set request_status $status

                            if test $request_status -ne 0
                                echo "Error: Failed to connect to Telegram API!"
                                return 1
                            end

                            if not echo $response | jq -e '.ok' >/dev/null
                                echo "Error: Failed to send chunk: "(echo $response | jq -r '.description // "Unknown error"')
                                return 1
                            end
                            echo "$color_ok✓ sent chunk "(basename $chunk)" to $target_label$color_reset"
                        end
                    end
                end
            end
        else
            echo "⚠️ no input detected"
        end
    else
        cat >> $body_meesage_text_file
        #echo "string from pipe: $combined"
        # Regular message
        __paste_gram_append_user_caption "$message_text_file" "$user_caption_file"
        cat "$head_message_text_file" >> "$message_text_file"
        echo -e "<pre>" >> "$message_text_file"
        if test (uname) = "Darwin"
            sed -i '' 's#<#-#g' $body_meesage_text_file
            sed -i '' 's#>#-#g' $body_meesage_text_file
        else
            sed -i 's#<#-#g' $body_meesage_text_file
            sed -i 's#>#-#g' $body_meesage_text_file
        end
        cat "$body_meesage_text_file" >> "$message_text_file"
        echo -e "</pre>" >> "$message_text_file"

        # Split file into chunks
        split -b 3800 $message_text_file $splitdir/chunk_
        # find the very last chunk
        set -l last_chunk (ls $splitdir/chunk_* | sort | tail -n1)

        # Wrap chunks for Telegram HTML parsing
        for chunk in $splitdir/chunk_*
            # 1) First chunk: append closing </pre> if it’s not already there
            if test $chunk = "$splitdir/chunk_aa"; and not grep -q '</pre>' "$chunk"
                echo '</pre>' >>"$chunk"
            end
            # 2) Middle chunks: wrap in both <pre>…</pre>
            if test $chunk != "$splitdir/chunk_aa"; and test $chunk != "$last_chunk"
                echo '<pre>' | cat - "$chunk" >"$chunk.tmp"
                mv "$chunk.tmp" "$chunk"
                echo '</pre>' >>"$chunk"
            end
            # 3) Last chunk: prepend opening <pre> if it’s not already there
            if test $chunk = "$last_chunk"; and not grep -q '<pre>' "$chunk"
                echo '<pre>' | cat - "$chunk" >"$chunk.tmp"
                mv "$chunk.tmp" "$chunk"
            end
        end

        if test $use_mtproto = "true"
            set -l mtproto_manifest (mktemp)
            printf "%s\n" $splitdir/chunk_* > "$mtproto_manifest"
            __paste_gram_mtproto_send "message" "$mtproto_manifest" "" "" "$verbose" $chat_ids
            rm -f "$mtproto_manifest"
        else
            # Send each chunk
            for chunk in $splitdir/chunk_*
                for idx in (seq (count $chat_ids))
                    set -l target_chat_id $chat_ids[$idx]
                    set -l target_label $chat_labels[$idx]
                    echo "$color_info→ sending chunk "(basename $chunk)" to $target_label$color_reset"
                    set response (__paste_gram_bot_request "$api_url" "$token" "sendMessage" "$target_label" "$verbose" "$curl_proxy_override" \
                        --data-urlencode chat_id="$target_chat_id" \
                        --data-urlencode text="$(cat $chunk)" \
                        -d parse_mode="HTML" \
                        --connect-timeout 10 \
                        --max-time 30)
                    set request_status $status


                    if test $request_status -ne 0
                        echo "Error: Failed to connect to Telegram API!"
                        return 1
                    end

                    if not echo $response | jq -e '.ok' >/dev/null
                        echo "Error: Failed to send chunk: "(echo $response | jq -r '.description // "Unknown error"')
                        return 1
                    end
                    echo "$color_ok✓ sent chunk "(basename $chunk)" to $target_label$color_reset"
                end
            end
        end
    end
    if test -n "$user_caption_file"
        rm -f "$user_caption_file"
    end
    if test -n "$metadata_caption_file"
        rm -f "$metadata_caption_file"
    end
end

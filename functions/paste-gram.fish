function __paste_gram_mtproto_send --argument-names mode manifest file_path caption_path
    set -l mtproto_chat_ids $argv[5..-1]
    if test (count $mtproto_chat_ids) -eq 0
        echo "❌ MTProto requires a chat id (set TELEGRAM_CHAT_ID or pass --id)" >&2
        return 1
    end
    if not command -sq python3; and not command -sq pipx
        echo "❌ python3 or pipx is required for MTProto mode" >&2
        return 1
    end
    set -l api_id $TELEGRAM_MT_API_ID
    set -l api_hash $TELEGRAM_MT_API_HASH
    if test -z "$api_id"; or test -z "$api_hash"
        echo "❌ TELEGRAM_MT_API_ID and TELEGRAM_MT_API_HASH must be set for MTProto mode" >&2
        return 1
    end
    set -l session_path (set -q TELEGRAM_MT_SESSION; and echo $TELEGRAM_MT_SESSION; or echo "$HOME/.config/paste-gram/mtproto")
    mkdir -p (dirname "$session_path")

    set -l py_code 'import asyncio
import os
import sys

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

async def resolve_entity(client, chat):
    try:
        return await client.get_entity(chat)
    except Exception as exc:
        raise RuntimeError(
            f"Cannot resolve chat '{chat}'. Use @username, 'me', or start a dialog so it appears in your chats. ({exc})"
        )

async def main():
    async with TelegramClient(session, api_id, api_hash) as client:
        await client.start()
        if mode == "message":
            if not manifest or not os.path.exists(manifest):
                raise RuntimeError("Missing message manifest for MTProto send")
            with open(manifest, "r", encoding="utf-8") as handle:
                message_files = [line.strip() for line in handle if line.strip()]
            if not message_files:
                raise RuntimeError("No message chunks found for MTProto send")
            for chat in chat_ids:
                entity = await resolve_entity(client, chat)
                for msg_file in message_files:
                    with open(msg_file, "r", encoding="utf-8") as mf:
                        text = mf.read()
                    await client.send_message(entity, text, parse_mode="html")
        elif mode == "file":
            if not file_path:
                raise RuntimeError("Missing file path for MTProto send")
            caption = None
            if caption_path and os.path.exists(caption_path):
                with open(caption_path, "r", encoding="utf-8") as cf:
                    caption = cf.read()
            for chat in chat_ids:
                entity = await resolve_entity(client, chat)
                await client.send_file(entity, file_path, caption=caption, parse_mode="html")
        else:
            raise RuntimeError(f"Unknown MTProto mode: {mode}")

try:
    asyncio.run(main())
except Exception as exc:
    sys.stderr.write(f"❌ MTProto send failed: {exc}\n")
    sys.exit(1)
'

    set -l python_cmd python3
    set -l python_args
    if command -sq pipx
        set python_cmd pipx
        set python_args run --spec telethon python
    end

    env PASTEGRAM_MT_MODE="$mode" \
        PASTEGRAM_MT_MANIFEST="$manifest" \
        PASTEGRAM_MT_FILE="$file_path" \
        PASTEGRAM_MT_CAPTION="$caption_path" \
        PASTEGRAM_MT_CHAT_IDS=(string join "," -- $mtproto_chat_ids) \
        PASTEGRAM_MT_API_ID="$api_id" \
        PASTEGRAM_MT_API_HASH="$api_hash" \
        PASTEGRAM_MT_SESSION="$session_path" \
        $python_cmd $python_args -c "$py_code"
    if test $status -ne 0
        return 1
    end
end

function paste-gram --description "Send text or file to Telegram" --argument cmdArg
    set -l pastegram_version "v1.5.1"
    set -l token $TELEGRAM_TOKEN
    set -l chat_id $TELEGRAM_CHAT_ID
    set -l api_url (set -q TELEGRAM_API_URL; and echo $TELEGRAM_API_URL; or echo "https://api.telegram.org")
    set -l override_chat_ids
    set -l positional_args
    set -l id_map_path (set -q PASTEGRAM_ID_MAP; and echo $PASTEGRAM_ID_MAP; or echo "$HOME/.config/paste-gram/chat_ids.json")
    set -l use_mtproto "false"

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        set -l arg $argv[$i]
        switch $arg
            case "-h" "--help"
                printf "paste-gram — send text or files to Telegram\n\n"
                printf "Usage:\n"
                printf "  paste-gram \"message\"                 # send plain text\n"
                printf "  echo \"from pipe\" | paste-gram        # send stdin\n"
                printf "  paste-gram /path/to/file              # send file (auto-chunk >50MB)\n"
                printf "  paste-gram --id @other_chat \"msg\"    # override TELEGRAM_CHAT_ID (numeric, alias, repeatable)\n"
                printf "  paste-gram --mtproto \"msg\"           # send via personal account (MTProto)\n"
                printf "  PASTEGRAM_HOSTNAME=true PASTEGRAM_LAST_COMMAND=true paste-gram \"msg\"\n\n"
                printf "Env vars (required): TELEGRAM_TOKEN, TELEGRAM_CHAT_ID\n"
                printf "Env vars (optional): TELEGRAM_API_URL, PASTEGRAM_HOSTNAME=true|1, PASTEGRAM_LAST_COMMAND=true|1, PASTEGRAM_ID_MAP=<path to alias json>\n"
                printf "MTProto env vars (required for --mtproto): TELEGRAM_MT_API_ID, TELEGRAM_MT_API_HASH\n"
                printf "MTProto env vars (optional): TELEGRAM_MT_SESSION=<path> PASTEGRAM_USE_MT=true|false\n"
                printf "Flags (optional): --id|-i <chat-id|alias> (repeatable), --mtproto/--personal\n"
                printf "Dependencies: fish 3+, curl, jq, tar, split, stat, python3 (MTProto), telethon (MTProto)\n"
                return 0
            case "-v" "-V" "--version"
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
                set use_mtproto "true"
            case "--id=*"
                set -l raw_value (string replace -- "--id=" "" $arg)
                set override_chat_ids $override_chat_ids (string split "," -- $raw_value)
            case "-i=*"
                set -l raw_value (string replace -- "-i=" "" $arg)
                set override_chat_ids $override_chat_ids (string split "," -- $raw_value)
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

    if set -q PASTEGRAM_USE_MT
        switch (string lower -- $PASTEGRAM_USE_MT)
            case "true" "1" "yes"
                set use_mtproto "true"
            case "false" "0" "no"
                # keep default
            case "*"
                echo "❌ PASTEGRAM_USE_MT must be true or false" >&2
                return 1
        end
    end

    if test $use_mtproto != "true"
        if test -z "$token"
            echo "❌ TELEGRAM_TOKEN must be set" >&2
            return 1
        end
    end
    if test (count $override_chat_ids) -eq 0; and test -z "$chat_id"
        echo "❌ TELEGRAM_CHAT_ID must be set or pass --id" >&2
        return 1
    end

    set -l chat_ids
    set -l chat_labels
    set -l to_resolve
    if test (count $override_chat_ids) -gt 0
        set to_resolve $override_chat_ids
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

    set -l include_hostname (set -q PASTEGRAM_HOSTNAME; and echo $PASTEGRAM_HOSTNAME; or echo "false")
    set -l include_command (set -q PASTEGRAM_LAST_COMMAND; and echo $PASTEGRAM_LAST_COMMAND; or echo "false")

    set -l m_hostname (hostname)

    #sync_history
    history --merge
    set -l full_cmd (history --max 2 | head -n 1)

    set -l head_message_text_file (mktemp)
    set -l body_meesage_text_file (mktemp)
    set -l message_text_file (mktemp)
    set -l splitdir (mktemp -d)
    set -l compressdir (mktemp -d)




    if test $include_hostname = "true"; or \
       test $include_hostname = "True"; or \
       test $include_hostname = "1"
        echo -e "<b>Hostname:</b> <u>$m_hostname</u>" >> "$head_message_text_file"
#         echo -e "Hostname: $m_hostname"
    end

    if test $include_command = "true"; or \
       test $include_command = "True"; or \
       test $include_command = "1"
        echo -e "\$ <b><u>$full_cmd</u></b>" >> "$head_message_text_file"
#         echo -e "FullCommand: $full_cmd"
    end


    if test $include_command  = "true";  or \
       test $include_command  = "True";  or \
       test $include_command  = "1"   ;  or \
       test $include_hostname = "true";  or \
       test $include_hostname = "True";  or \
       test $include_hostname = "1"
        echo -e "\n=======================\n" >> "$head_message_text_file"
    end

    #cat $head_message_text_file

#++++++++++++++++++++++++++++++++++++++++++

    if isatty stdin
        if test -n "$positional_args"
        #echo "Reading from arguments..."
            if test -f "$positional_args[1]"
                echo "Uploading file..."
                set -f file $positional_args[1]
                set -l abs_path (realpath $file)

                if test (uname) = "Darwin"
                    set file_size (stat -f %z "$file")
                else
                    set file_size (stat -c %s "$file")
                end


                set  file_size_mb (math "$file_size / 1024 / 1024")
                set  file_name (basename "$file")
                set  dir_name (dirname "$file")

                echo -e "File Size: $file_size_mb MB"

                echo -e "Caption:\n" > "$message_text_file"
                cat "$head_message_text_file" >> "$message_text_file"
                echo -e "<b>File:</b> <u>$file</u>" >> "$message_text_file"
                echo -e "<b>PATH:</b> <u>$abs_path</u>" >> "$message_text_file"

                set -l caption (printf "📄 <b>File:</b> %s\n📍 <b>Path:</b> %s" (basename $file) $abs_path)

                #++++++++++++++++++++++++++++++++++++++
                if test "$file_size_mb" -gt 50
                    if test $use_mtproto = "true"
                        echo -e "MTProto mode: sending file without Bot API size limits."
                    else
                        # Compress the file first
                        echo -e "Compress the file first."

                        set -l tar_file "$compressdir/$file_name.tgz"
                        tar czvf "$tar_file" -C $dir_name "$file_name"

                        if test (uname) = "Darwin"
                            set file_size (stat -f %z "$tar_file")
                        else
                            set file_size (stat -c %s "$tar_file")
                        end

                        set  file_size_mb (math "$file_size / 1024 / 1024")
                        echo -e "File size after compress: $file_size_mb MB"
                        set  file $tar_file
                        set  file_name (basename "$tar_file")
                        set  abs_path (realpath $tar_file)
                    end

                end

                if test "$file_size_mb" -gt 50
                    if test $use_mtproto = "true"
                        __paste_gram_mtproto_send "file" "" "$file" "$message_text_file" $chat_ids
                    else
                        echo -e "Chuck the compress file."
                        split -b 49MB -d "$file" $splitdir/"$file_name"_
                        echo -e "Send Chuck: $i"
                        for i in "$splitdir/$file_name"_*
                            for idx in (seq (count $chat_ids))
                                set -l target_chat_id $chat_ids[$idx]
                                set -l target_label $chat_labels[$idx]
                                echo "$color_info→ sending chunk "(basename $i)" to $target_label$color_reset"
                                set response (curl -s -X POST "$api_url"/bot$token/"sendDocument" \
                                    --form-string chat_id="$target_chat_id" \
                                    -F document=@"$i" \
                                    -F caption="$(cat $message_text_file)" \
                                    -F parse_mode="HTML" \
                                    --connect-timeout 10 \
                                    --max-time 30)

                                set -l status_ok (echo $response | jq .ok)
                                set -l status_description (echo $response | jq .description)

                                if test $status -ne 0
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

                    if test $use_mtproto = "true"
                        __paste_gram_mtproto_send "file" "" "$file" "$message_text_file" $chat_ids
                    else
                        for idx in (seq (count $chat_ids))
                            set -l target_chat_id $chat_ids[$idx]
                            set -l target_label $chat_labels[$idx]
                            echo "$color_info→ sending file $file_name to $target_label$color_reset"
                            set response (curl -s -X POST "$api_url"/bot$token/"sendDocument" \
                                --form-string chat_id="$target_chat_id" \
                                -F document=@"$file" \
                                -F caption="$(cat $message_text_file)" \
                                -F parse_mode="HTML" \
                                --connect-timeout 10 \
                                --max-time 30)

                            set -l status_ok (echo $response | jq .ok)
                            set -l status_description (echo $response | jq .description)

                            if test $status -ne 0
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
                cat "$head_message_text_file" > "$message_text_file"
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
                    __paste_gram_mtproto_send "message" "$mtproto_manifest" "" "" $chat_ids
                    rm -f "$mtproto_manifest"
                else
                    # Send each chunk
                    for chunk in $splitdir/chunk_*
                        for idx in (seq (count $chat_ids))
                            set -l target_chat_id $chat_ids[$idx]
                            set -l target_label $chat_labels[$idx]
                            echo "$color_info→ sending chunk "(basename $chunk)" to $target_label$color_reset"
                            set response (curl -s -X POST "$api_url/bot$token/sendMessage" \
                                --data-urlencode chat_id="$target_chat_id" \
                                --data-urlencode text="$(cat $message_text_file)" \
                                -d parse_mode="HTML" \
                                --connect-timeout 10 \
                                --max-time 30)

                            if test $status -ne 0
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
        cat "$head_message_text_file" > "$message_text_file"
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
            __paste_gram_mtproto_send "message" "$mtproto_manifest" "" "" $chat_ids
            rm -f "$mtproto_manifest"
        else
            # Send each chunk
            for chunk in $splitdir/chunk_*
                for idx in (seq (count $chat_ids))
                    set -l target_chat_id $chat_ids[$idx]
                    set -l target_label $chat_labels[$idx]
                    echo "$color_info→ sending chunk "(basename $chunk)" to $target_label$color_reset"
                    set response (curl -s -X POST "$api_url/bot$token/sendMessage" \
                        --data-urlencode chat_id="$target_chat_id" \
                        --data-urlencode text="$(cat $chunk)" \
                        -d parse_mode="HTML" \
                        --connect-timeout 10 \
                        --max-time 30)


                    if test $status -ne 0
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
end

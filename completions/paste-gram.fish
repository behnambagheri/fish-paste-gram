function __paste_gram_id_candidates
    set -l map_path (set -q PASTEGRAM_ID_MAP; and echo $PASTEGRAM_ID_MAP; or echo "$HOME/.config/paste-gram/chat_ids.json")
    if not test -f "$map_path"
        return
    end
    if command -sq jq
        jq -r 'to_entries[] | "\(.key)\t\(
            if (.value | type) == "object" then
                (.value.username // .value.chat_id // "")
            else
                .value
            end
        )"' "$map_path" 2>/dev/null
    end
end

function __paste_gram_completion_is_piped
    set -l commandline_buffer (commandline -b)
    set -l cursor_position (commandline -C)
    set -l commandline_prefix (string sub -s 1 -l $cursor_position -- "$commandline_buffer")
    string match -q -r '\|[[:space:]]*(command[[:space:]]+)?(ptg|paste-gram)([[:space:]]|$)' -- "$commandline_prefix"
end

complete -c paste-gram -n "__paste_gram_completion_is_piped" -f
complete -c paste-gram -s h -l help -d "Show help"
complete -c paste-gram -s m -l message -d "Add a caption; opens the default editor when omitted"
complete -c paste-gram -l api-url -d "Override Bot API URL for this command" -r
complete -c paste-gram -l proxy -d "Use a curl proxy for Bot API requests" -r
complete -c paste-gram -l hostname -l include-hostname -d "Override hostname metadata" -x -a "true false"
complete -c paste-gram -l last-command -l include-command -d "Override command metadata" -x -a "true false"
complete -c paste-gram -l include-path -d "Override file or directory path metadata" -x -a "true false"
complete -c paste-gram -s v -l verbose -d "Show effective configuration and Telegram responses"
complete -c paste-gram -s V -l version -d "Show version"
complete -c paste-gram -s i -l id -o id -d "Override chat id (numeric, @user, or alias; repeatable)" -x -a "(__paste_gram_id_candidates)"
complete -c paste-gram -l mtproto -l personal -d "Send via personal account (MTProto)"
complete -c paste-gram -l bot -l bot-api -d "Send via Bot API for this call"

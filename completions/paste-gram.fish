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

complete -c paste-gram -s h -l help -d "Show help"
complete -c paste-gram -s m -l message -d "Add a caption; opens the default editor when omitted"
complete -c paste-gram -s v -l verbose -d "Show effective configuration and Telegram responses"
complete -c paste-gram -s V -l version -d "Show version"
complete -c paste-gram -s i -l id -o id -d "Override chat id (numeric, @user, or alias; repeatable)" -x -a "(__paste_gram_id_candidates)"
complete -c paste-gram -l mtproto -l personal -d "Send via personal account (MTProto)"
complete -c paste-gram -l bot -l bot-api -d "Send via Bot API for this call"
complete -c paste-gram -n "__fish_is_first_arg; and not string match -qr '^-.*' -- (commandline -ct)" -a "(__fish_complete_path)" -d "File or directory to send"
complete -c paste-gram -n "__fish_seen_argument -s m -l message; and not string match -qr '^-.*' -- (commandline -ct)" -a "(__fish_complete_path)" -d "File or directory to send"

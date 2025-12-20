set -l id_map_path (set -q PASTEGRAM_ID_MAP; and echo $PASTEGRAM_ID_MAP; or echo "$HOME/.config/paste-gram/chat_ids.json")

if not test -f "$id_map_path"
    mkdir -p (dirname "$id_map_path")
    printf '{\n  "bea": "323101679",\n  "reza": "5415541173",\n  "pastebin": "-1001804111897",\n  "nikneshan": "110876335",\n  "nik": "110876335",\n  "ali": "226172014",\n  "yara": "157350506"\n}\n' >"$id_map_path"
end

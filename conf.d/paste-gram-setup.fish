set -l id_map_path (set -q PASTEGRAM_ID_MAP; and echo $PASTEGRAM_ID_MAP; or echo "$HOME/.config/paste-gram/chat_ids.json")

if not test -f "$id_map_path"
    mkdir -p (dirname "$id_map_path")
    printf '{\n  "example_friend": "123456789",\n  "example_channel": "-1001234567890"\n}\n' >"$id_map_path"
end

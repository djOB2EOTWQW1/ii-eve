#!/usr/bin/env bash
# presets.sh - manage shell config presets for illogical-impulse
# Usage:
#   presets.sh --save <name> [description]
#   presets.sh --rename <old_name> <new_name>
#   presets.sh --remove <name>
#   presets.sh --apply <name>

CONFIG_DIR="${HOME}/.config/illogical-impulse"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PRESETS_DIR="${CONFIG_DIR}/presets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCHWALL="${SCRIPT_DIR}/../colors/switchwall.sh"

mkdir -p "$PRESETS_DIR"

action="$1"
name="$2"

if [ "$action" = "--list" ] || [ "$action" = "list" ]; then
    items=()
    for f in "$PRESETS_DIR"/*.json; do
        [ -e "$f" ] || continue
        bname=$(basename "$f" .json)
        mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        item=$(jq -n --arg name "$bname" --arg path "$f" --argjson mtime "${mtime:-0}" '{"name": $name, "path": $path, "mtime": $mtime}')
        items+=("$item")
    done
    if [ ${#items[@]} -eq 0 ]; then
        echo "[]"
    else
        printf '%s\n' "${items[@]}" | jq -s '.'
    fi
    exit 0
fi

if [ -z "$name" ]; then
    echo "Error: missing preset name" >&2
    exit 1
fi

case "$action" in
    --save|save)
        description="$3"
        jq 'del(._presetMeta)' "$CONFIG_FILE" > "$PRESETS_DIR/${name}.json"
        if [ -n "$description" ]; then
            jq --arg desc "$description" '._presetMeta = {"description": $desc}' \
                "$PRESETS_DIR/${name}.json" > "$PRESETS_DIR/${name}.json.tmp" \
                && mv "$PRESETS_DIR/${name}.json.tmp" "$PRESETS_DIR/${name}.json"
        fi
        ;;
    --rename|rename)
        new_name="${*:3}"
        new_name=$(echo "$new_name" | tr ' ' '_')
        if [ -n "$new_name" ] && [ -f "$PRESETS_DIR/${name}.json" ]; then
            mv "$PRESETS_DIR/${name}.json" "$PRESETS_DIR/${new_name}.json"
        fi
        ;;
    --remove|--delete|remove|delete)
        rm -f "$PRESETS_DIR/${name}.json"
        ;;
    --apply|apply)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        jq -s '.[0] * .[1] | del(._presetMeta)' "$CONFIG_FILE" "$preset_file" \
            > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        if [ -x "$SWITCHWALL" ]; then
            "$SWITCHWALL" --noswitch
        fi
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac

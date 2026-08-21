#!/bin/bash
RESTORE_FILE="$HOME/.config/hypr/custom/session_restore.sh"

clients_json=$(hyprctl clients -j 2>/dev/null)
if [ -n "$clients_json" ]; then
    cmds=$(echo "$clients_json" | jq -r '.[] | select(.initialClass != "" and .initialClass != "org.quickshell" and .initialClass != "quickshell") | "hyprctl dispatch '\''hl.dsp.exec_cmd(\"" + .initialClass + "\", {workspace = " + (.workspace.id | tostring) + "})'\''"')
    if [ -n "$cmds" ]; then
        cat << EOS > "$RESTORE_FILE"
#!/bin/bash
sleep 2
$cmds
EOS
        chmod +x "$RESTORE_FILE"
    fi
fi

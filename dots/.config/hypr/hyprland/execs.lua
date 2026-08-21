-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()
    local is_disabled = function(id)
        local f = io.open(os.getenv("HOME") .. "/.config/hypr/custom/disabled_services.list", "r")
        if not f then return false end
        local content = f:read("*a")
        f:close()
        return content:find(id) ~= nil
    end

    -- Bar, wallpaper
    if not is_disabled("geoclue") then hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh") end
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Custom user autostart & session restore
    hl.exec_cmd("[ -f $HOME/.config/hypr/custom/user_autostart.sh ] && $HOME/.config/hypr/custom/user_autostart.sh")
    hl.exec_cmd("[ -f $HOME/.config/hypr/custom/session_restore.sh ] && $HOME/.config/hypr/custom/session_restore.sh")

    -- Core components (authentication, lock screen, notification daemon)
    if not is_disabled("keyring") then hl.exec_cmd("gnome-keyring-daemon --start --components=secrets") end
    if not is_disabled("hypridle") then hl.exec_cmd("hypridle") end
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    if not is_disabled("easyeffects") then hl.exec_cmd("easyeffects --hide-window --service-mode") end

    -- Clipboard: history
    if not is_disabled("cliphist") then
        hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
        hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    end

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)

-- Custom Hyprland Execs
hl.device({ name = "pnp0c50:00-04f3:30aa-touchpad", enabled = false })
hl.device({ name = "etps/2-elantech-touchpad", enabled = false })

hl.on("hyprland.start", function ()
    hl.exec_cmd("bash $HOME/.config/hypr/custom/session_restore.sh")
    hl.exec_cmd("bash $HOME/.config/hypr/custom/user_autostart.sh")
end)

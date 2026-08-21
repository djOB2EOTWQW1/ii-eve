#!/bin/bash
sleep 2
hyprctl dispatch 'hl.dsp.exec_cmd("firefox", {workspace = 1})'
hyprctl dispatch 'hl.dsp.exec_cmd("Discord", {workspace = 2})'

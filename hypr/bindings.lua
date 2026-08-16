-- Personal keybindings (migrated from bindings.conf).
-- ALT is the primary modifier here; SUPER stays on the Omarchy defaults.
-- See current bindings and descriptions: omarchy menu keybindings --print

-- Free up keys taken by Omarchy defaults.
hl.unbind("SUPER + SPACE") -- was: Omarchy menu (launcher lives on ALT + D)
hl.unbind("SUPER + V") -- was: Universal paste (now push-to-talk)
hl.unbind("ALT + TAB") -- was: cycle windows (now workspace navigation)
hl.unbind("ALT + SHIFT + TAB") -- was: cycle windows backwards
hl.unbind("CTRL + ALT + TAB") -- was: focus next monitor (now former workspace)

-- Application launcher.
o.bind("ALT + D", "Launch apps", "omarchy-menu toggle apps")

-- Applications.
o.bind("ALT + RETURN", "Terminal", 'uwsm app -- $TERMINAL --dir="$(omarchy-cmd-terminal-cwd)"')
o.bind("ALT + F", "File manager", { launch = "nautilus --new-window" })
o.bind("ALT + B", "Browser", "omarchy-launch-browser")
o.bind("ALT + SHIFT + B", "Browser (private)", "omarchy-launch-browser --private")
o.bind("ALT + M", "Music", "omarchy-launch-or-focus spotify")
o.bind("ALT + N", "Editor", "omarchy-launch-editor")
o.bind("ALT + T", "Activity", { tui = "btop" })
o.bind("ALT + SHIFT + D", "Docker", { tui = "lazydocker" })
o.bind("ALT + G", "Signal", { focus = "signal", launch = "signal-desktop" })
o.bind("ALT + O", "Obsidian", { focus = "obsidian", launch = "obsidian" })
o.bind("ALT + R", "Set tablet region", "/home/patrick/dotfiles/bin/hypr-tablet-region")
o.bind("ALT + SHIFT + G", "Screenshot", 'grim -g "$(slurp)" - | wl-copy')

-- Web apps. If the url contains #, type it as ## to prevent it being treated
-- as a comment.
o.bind("ALT + Y", "YouTube", { focus = true, webapp = "https://youtube.com/" })
o.bind("ALT + X", "X", { webapp = "https://x.com/" })

-- Window management.
o.bind("ALT + W", "Close active window", hl.dsp.window.close())
o.bind("ALT + P", "Pin window", hl.dsp.window.pin())
o.bind("ALT + V", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))

-- Focus movement (vim-style, repeats when held).
o.bind("ALT + H", "Focus on left window", hl.dsp.focus({ direction = "l" }), { repeating = true })
o.bind("ALT + L", "Focus on right window", hl.dsp.focus({ direction = "r" }), { repeating = true })
o.bind("ALT + K", "Focus on above window", hl.dsp.focus({ direction = "u" }), { repeating = true })
o.bind("ALT + J", "Focus on below window", hl.dsp.focus({ direction = "d" }), { repeating = true })

-- Swap windows (vim-style).
o.bind("ALT + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("ALT + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.bind("ALT + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("ALT + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

-- Workspaces 1-10 on ALT + number row.
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  o.bind("ALT + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("ALT + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

-- Workspace navigation.
o.bind("ALT + TAB", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("ALT + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("ALT + CTRL + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))

-- Push-to-talk: hold Super+V to record, release to transcribe.
o.bind("SUPER + V", "Record voice note", "/home/patrick/.local/bin/fluester client start")
o.bind("SUPER + V", nil, "/home/patrick/.local/bin/fluester client stop", { release = true })

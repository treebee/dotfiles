-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Fallback for any monitor without a specific rule below.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Per-output overrides (migrated from hyprland.conf). These only apply when a
-- monitor with that exact name is connected; the fallback above covers the rest.
hl.monitor({ output = "eDP-1", mode = "1920x1080@60.03", position = "704x1216", scale = 1.50 })
hl.monitor({ output = "DP-1", mode = "3440x1440@49.99", position = "1984x128", scale = 1.00 })

-- Personal input overrides (migrated from input.conf and tablet.conf).
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
  input = {
    -- Custom programmer layout (see ~/.config/xkb/symbols/us-prog).
    kb_layout = "us-prog",
    kb_variant = "",

    -- Change speed of keyboard repeat.
    repeat_rate = 40,
    repeat_delay = 600,

    -- Start with numlock on by default.
    numlock_by_default = true,

    touchpad = {
      -- Control the speed of your scrolling.
      scroll_factor = 0.4,
    },
  },
})

-- Per-device overrides.
hl.device({
  name = "kinesis-advantage360",
  kb_layout = "us-prog",
  kb_options = "compose:caps",
})

hl.device({
  name = "at-translated-set-2-keyboard",
  kb_variant = "us-prog-laptop",
  kb_options = "caps:swapescape",
})

-- Wacom tablet: constrain the pen to a region of the internal display.
hl.device({
  name = "wacom-intuos-bt-s-pen",
  output = "eDP-1",
  region_size = { 1748, 1103 },
  region_position = { 709, 234 },
})

-- Note: the terminal touchpad scroll-speed window rules from the old
-- input.conf are already part of Omarchy's defaults, so they're not repeated
-- here. Enable workspace swipe gestures if wanted:
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

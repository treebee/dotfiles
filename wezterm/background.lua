-- The art is a bit too bright and colorful to be useful as a backdrop
-- for text, so we're going to dim it down to 10% of its normal brightness
local dimmer = { brightness = 0.1 }

local config = {}
local home = os.getenv("HOME") .. "/"

config.enable_scroll_bar = true
config.min_scroll_bar_height = '2cell'
config.colors = {
    scrollbar_thumb = 'white',
}

config.background = {
    -- This is the deepest/back-most layer. It will be rendered first
    {
        source = {
            File = home .. "Pictures/terminal.png",
        },
        hsb = dimmer,
    },
}

return config

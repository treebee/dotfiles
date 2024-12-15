-- Pull in the wezterm API
local wezterm = require 'wezterm'
local sessionizer = require 'sessionizer'
local background = require 'background'

local act = wezterm.action
-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
config.hide_tab_bar_if_only_one_tab = true

-- For example, changing the color scheme:
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font({ family = 'Monaspace Krypton', harfbuzz_features = { 'calt', 'liga', 'dlig', 'ss01', 'ss02', 'ss03', 'ss04', 'ss05', 'ss06', 'ss07', 'ss08' }, })


-- smart splits
local function is_vim(pane)
    -- this is set by the plugin, and unset on ExitPre in Neovim
    return pane:get_user_vars().IS_NVIM == 'true'
end

local direction_keys = {
    Left = 'h',
    Down = 'j',
    Up = 'k',
    Right = 'l',
    -- reverse lookup
    h = 'Left',
    j = 'Down',
    k = 'Up',
    l = 'Right',
}

local function split_nav(resize_or_move, key)
    return {
        key = key,
        mods = resize_or_move == 'resize' and 'META' or 'CTRL',
        action = wezterm.action_callback(function(win, pane)
            if is_vim(pane) then
                -- pass the keys through to vim/nvim
                win:perform_action({
                    SendKey = { key = key, mods = resize_or_move == 'resize' and 'META' or 'CTRL' },
                }, pane)
            else
                if resize_or_move == 'resize' then
                    win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
                else
                    win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
                end
            end
        end),
    }
end

wezterm.on('update-right-status', function(window, pane)
    window:set_right_status(window:active_workspace())
end)

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
    {
        mods   = "LEADER|SHIFT",
        key    = "|",
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
    },
    {
        mods   = "LEADER",
        key    = "-",
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
    },
    {
        mods   = "LEADER",
        key    = "z",
        action = wezterm.action.TogglePaneZoomState
    },
    {
        mods   = "LEADER",
        key    = "Space",
        action = wezterm.action.RotatePanes "Clockwise"
    },
    {
        mods   = "LEADER",
        key    = "0",
        action = wezterm.action.PaneSelect {
            mode = 'SwapWithActive',
        },
    },
    {
        mods   = "CTRL",
        key    = "LeftArrow",
        action = wezterm.action.ActivateTabRelative(-1)
    },
    {
        mods   = "CTRL",
        key    = "RightArrow",
        action = wezterm.action.ActivateTabRelative(1)
    },
    {
        mods   = 'LEADER',
        key    = 'Enter',
        action = wezterm.action.ActivateCopyMode,
    },
    -- move between split panes
    split_nav('move', 'h'),
    split_nav('move', 'j'),
    split_nav('move', 'k'),
    split_nav('move', 'l'),
    -- resize panes
    split_nav('resize', 'h'),
    split_nav('resize', 'j'),
    split_nav('resize', 'k'),
    split_nav('resize', 'l'),
    {
        mods = "LEADER",
        key = "f",
        action = wezterm.action_callback(sessionizer.open)
    },
    -- search for things that look like git hashes
    {
        key = 'g',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.Search {
            Regex = '[a-f0-9]{6,}',
        },
    },
    -- search for the lowercase string "hash" matching the case exactly
    {
        key = 'h',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.Search { CaseSensitiveString = 'hash' },
    },
    -- scroll
    {
        key = 'U',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.ScrollToTop
    },
    {
        key = 'D',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.ScrollToBottom
    },

    -- navigate workspaces
    --
    -- Switch to the default workspace
    {
        key = 'y',
        mods = 'CTRL|SHIFT',
        action = act.SwitchToWorkspace {
            name = 'default',
        },
    },
    -- Switch to a monitoring workspace, which will have `top` launched into it
    {
        key = 'm',
        mods = 'CTRL|SHIFT',
        action = act.SwitchToWorkspace {
            name = 'monitoring',
            spawn = {
                args = { 'htop' },
            },
        },
    },
    -- Create a new workspace with a random name and switch to it
    { key = 'i', mods = 'CTRL|SHIFT', action = act.SwitchToWorkspace },
    -- Show the launcher in fuzzy selection mode and have it list all workspaces
    -- and allow activating one.
    {
        key = 'f',
        mods = 'CTRL|SHIFT',
        action = act.ShowLauncherArgs {
            flags = 'FUZZY|WORKSPACES',
        },
    },
}

for k, v in pairs(background) do config[k] = v end

-- and finally, return the configuration to wezterm
return config

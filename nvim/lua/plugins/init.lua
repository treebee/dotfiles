return {
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd([[colorscheme tokyonight]])
        end,
    },
    { "folke/which-key.nvim", lazy = false },
    "folke/zen-mode.nvim",
    { "folke/trouble.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
    "norcalli/nvim-colorizer.lua",
    { "tpope/vim-fugitive", tag = "v3.7" },
    { "mbbill/undotree",    tag = "rel_6.1" },
    "github/copilot.vim",
}

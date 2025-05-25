return {
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd([[colorscheme tokyonight]])
        end,
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        init = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
        end,
    },
    "folke/zen-mode.nvim",
    "norcalli/nvim-colorizer.lua",
    { "tpope/vim-fugitive" },
    { "mbbill/undotree" },
}

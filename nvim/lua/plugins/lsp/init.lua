return {
    {
        "j-hui/fidget.nvim",
        config = function()
            require("fidget").setup({})
        end,
    },
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        lazy = true,
        config = false,
        init = function()
            -- Disable automatic setup, we are doing it manually
            vim.g.lsp_zero_extend_cmp = 0
            vim.g.lsp_zero_extend_lspconfig = 0
        end,
    },
    {
        'williamboman/mason.nvim',
        lazy = false,
        config = true,
    },

    -- LSP
    {
        'neovim/nvim-lspconfig',
        cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
        event = { 'BufReadPre', 'BufNewFile' },
        dependencies = {
            { 'williamboman/mason-lspconfig.nvim' },
            "folke/neodev.nvim",
            { 'saghen/blink.cmp' },
        },
        config = function()
            require("neodev").setup()
            local lspconfig = require('lspconfig')

            -- This is where all the LSP shenanigans will live
            local lsp_zero = require('lsp-zero')
            lsp_zero.extend_lspconfig()

            lsp_zero.on_attach(function(_, bufnr)
                -- see :help lsp-zero-keybindings
                -- to learn the available actions
                lsp_zero.default_keymaps({ buffer = bufnr })
            end)

            local capabilities = require('blink.cmp').get_lsp_capabilities()

            require('mason-lspconfig').setup({
                ensure_installed = {
                    'rust_analyzer', 'eslint', 'lua_ls', 'gopls', 'zls',
                    'elixirls', 'html', 'htmx', 'cssls', 'tailwindcss', 'pylsp',
                },
                handlers = {
                    lsp_zero.default_setup,
                    rust_analyzer = lsp_zero.noop,
                    lua_ls = function()
                        -- (Optional) Configure lua language server for neovim
                        local lua_opts = lsp_zero.nvim_lua_ls()
                        lua_opts.capabilities = capabilities
                        lspconfig.lua_ls.setup(lua_opts)
                    end,
                }
            })
        end
    },
    {
        'ray-x/lsp_signature.nvim',
        event = "VeryLazy",
        opts = {},
        config = function(_, opts) require 'lsp_signature'.setup(opts) end
    }
}

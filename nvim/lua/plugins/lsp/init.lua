return {
    {
        'neovim/nvim-lspconfig',
        cmd = { 'LspInfo', 'LspInstall', 'LspUninstall', 'Mason' },
        event = { 'BufReadPost', 'BufNewFile' },
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
            "saghen/blink.cmp",
            "j-hui/fidget.nvim",
        },
        config = function()
            require("elixir").setup({
            })
            local servers = {
                bashls = {},
                cssls = {},
                -- elixirls = {
                --     cmd = { vim.env.HOME .. "/.local/share/nvim/mason/bin/elixir-ls" },
                -- },
                -- html = {},
                jsonls = {},
                lua_ls = {
                    settings = {
                        Lua = {
                            runtime = { version = "LuaJIT" },
                            workspace = {
                                checkThirdParty = false,
                                library = {
                                    "${3rd}/luv/library",
                                    unpack(vim.api.nvim_get_runtime_file("", true)),
                                },
                            },
                            telemetry = { enabled = false },
                        },
                    },
                },
                -- nextls = {
                --     cmd = { vim.env.HOME .. "/.local/share/nvim/mason/bin/nextls", "--stdio" },
                -- },
                pylsp = {},
                sqlls = {},
                tailwindcss = {},
                yamlls = {},
                rust_analyzer = {
                    check = { command = "clippy", features = "all" },
                },
                zls = {},
            }
            local formatters = {}

            local ensure_installed = vim.tbl_keys(vim.tbl_deep_extend("force", {}, servers, formatters))

            require("mason-tool-installer").setup({
                auto_update = true,
                run_on_start = true,
                start_delay = 3000,
                debounce_hours = 12,
                ensure_installed = ensure_installed,
            })

            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = vim.tbl_deep_extend("force", capabilities, require('blink.cmp').get_lsp_capabilities())

            for name, config in pairs(servers) do
                require("lspconfig")[name].setup({
                    autostart = config.autostart,
                    cmd = config.cmd,
                    capabilities = capabilities,
                    filetypes = config.filetypes,
                    handlers = vim.tbl_deep_extend("force", {}, config.handlers or {}),
                    settings = config.settings,
                    root_dir = config.root_dir,
                })
            end

            require("mason").setup()
            require('mason-lspconfig').setup()
        end
    },
}

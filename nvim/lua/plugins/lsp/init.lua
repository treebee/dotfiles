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
            local is_work_laptop = vim.uv.os_gethostname() == "notebook-pam"
            local servers = {
                bashls = {},
                cssls = {},
                html = {},
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
                pylsp = {
                    autostart = not is_work_laptop,
                    settings = {
                        pylsp = {
                            plugins = {
                                pycodestyle = { enabled = false },
                                pylint = { enabled = is_work_laptop },
                                pyflakes = { enabled = false },
                                mccabe = { enabled = is_work_laptop },
                                autopep8 = { enabled = false },
                                yapf = { enabled = false },
                                flake8 = { enabled = false },
                                pydocstyle = { enabled = false },
                            }
                        }
                    }
                },
                ruff = {
                    settings = {
                        format = {
                            enable = not is_work_laptop,
                        },
                    }
                },
                sqlls = {},
                tailwindcss = {},
                yamlls = {},
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

            servers["rust_analyzer"] = {
                check = { command = "clippy", features = "all" },
            }
            for name, config in pairs(servers) do
                vim.lsp.config(name, {
                    autostart = config.autostart,
                    cmd = config.cmd,
                    capabilities = capabilities,
                    filetypes = config.filetypes,
                    handlers = vim.tbl_deep_extend("force", {}, config.handlers or {}),
                    settings = config.settings,
                    root_dir = config.root_dir,
                })
                vim.lsp.enable(name)
            end

            require("mason").setup()
            require('mason-lspconfig').setup()
        end
    },
}

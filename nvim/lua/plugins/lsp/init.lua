return {
	{
		"neovim/nvim-lspconfig",
		cmd = { "LspInfo", "LspInstall", "LspUninstall", "Mason" },
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			"saghen/blink.cmp",
			"j-hui/fidget.nvim",
		},
		config = function(ev)
			local is_work_laptop = require("pam.utils").is_work_laptop()

			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

			-- Apply default settings to ALL language servers
			vim.lsp.config("*", {
				on_attach = on_attach,
				capabilities = capabilities,
			})

			-- Define server-specific overrides
			local servers = {
				bashls = {},
				cssls = {},
				gleam = {},
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
					-- Custom key to control enabling the server
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
							},
						},
					},
				},
				ruff = {}, -- No special config needed here, it's handled by on_attach
				rust_analyzer = {
					settings = {
						["rust-analyzer"] = {
							checkOnSave = true,
						},
					},
				},
				sqlls = {},
				tailwindcss = {},
				yamlls = {},
				zls = {},
			}

			-- Setup mason and mason-lspconfig first
			require("mason").setup()
			require("mason-lspconfig").setup()

			-- Simplified and corrected loop to configure and enable servers
			for name, config in pairs(servers) do
				-- Set server-specific config
				vim.lsp.config(name, config)

				-- Conditionally enable the server
				if config.autostart ~= false then
					vim.lsp.enable(name)
				end
			end

			-- Setup mason-tool-installer
			local ensure_installed = vim.tbl_keys(servers)
			require("mason-tool-installer").setup({
				auto_update = true,
				run_on_start = true,
				start_delay = 3000,
				debounce_hours = 12,
				ensure_installed = ensure_installed,
			})

			require("fidget").setup()
		end,
	},
}

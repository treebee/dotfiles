return {
	"mason-org/mason-lspconfig.nvim",
	opts = {
		ensure_installed = {
			"lua_ls",
			"rust_analyzer",
			"ruff",
			"zls",
			"bashls",
			"cssls",
			"html",
			"jsonls",
			"pylsp",
			"sqlls",
			"tailwindcss",
			"yamlls",
			"elixir-ls",
		},
	},
	dependencies = {
		{ "mason-org/mason.nvim", opts = {} },
		"neovim/nvim-lspconfig",
		"saghen/blink.cmp",
		"j-hui/fidget.nvim",
	},
}

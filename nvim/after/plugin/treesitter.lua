require("nvim-treesitter")
	.install({
		"bash",
		"c",
		"cpp",
		"css",
		"erlang",
		"eex",
		"git_config",
		"git_rebase",
		"gitignore",
		"gitattributes",
		"lua",
		"vim",
		"vimdoc",
		"markdown",
		"markdown_inline",
		"python",
		"elixir",
		"gleam",
		"json",
		"yaml",
		"rust",
		"zig",
		"go",
		"heex",
		"html",
		"jinja",
		"json",
		"json5",
		"make",
		"puppet",
		"query",
		"sql",
		"sway",
		"terraform",
		"tmux",
		"typescript",
		"yaml",
	})
	:wait(30000)

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "elixir", "heex", "eex" },
	callback = function()
		vim.treesitter.start()
	end,
})

local langs = {
    "bash",
    "c",
    "cpp",
    "css",
    "eex",
    "elixir",
    "gleam",
    "go",
    "heex",
    "html",
    "javascript",
    "json",
    "jsx",
    "lua",
    "markdown",
    "php",
    "puppet",
    "python",
    "ruby",
    "rust",
    "scss",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vue",
    "yaml",
    "zig",
    "zsh",
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = langs,
    callback = function()
        vim.treesitter.start()
    end,
})

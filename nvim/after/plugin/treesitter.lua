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
    "ocaml",
    "php",
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

require("nvim-treesitter").install(langs)

vim.api.nvim_create_autocmd("FileType", {
    pattern = langs,
    callback = function()
        vim.treesitter.start()
    end,
})

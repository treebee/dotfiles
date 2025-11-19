vim.api.nvim_create_autocmd("FileType", {
    pattern = { "elixir", "heex", "eex" },
    callback = function()
        vim.treesitter.start()
    end,
})

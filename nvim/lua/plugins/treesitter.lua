return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local ts_install_dir = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"
        vim.opt.runtimepath:append(ts_install_dir .. "/runtime")
    end,
}

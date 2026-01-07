return {
    "mason-org/mason-lspconfig.nvim",
    opts = {
        ensure_installed = require("pam.lsp").servers,
        automatic_enable = false,
    },
    dependencies = {
        { "mason-org/mason.nvim", opts = {} },
        "neovim/nvim-lspconfig",
        "saghen/blink.cmp",
        "j-hui/fidget.nvim",
    },
}

return {
    "elixir-tools/elixir-tools.nvim",
    version = "*",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local elixir = require("elixir")
        local elixirls = require("elixir.elixirls")
        elixir.setup {
            nextls = { enable = false },
            elixirls = {
                enable = true,
                settings = elixirls.settings {
                    dialyzerEnabled = true,
                    enableTestLenses = true,
                },
                on_attach = require("pam.lsp").on_attach,
                tag = "v0.28.0",
            },
        }
    end,
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
}

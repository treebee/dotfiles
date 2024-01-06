local dapui = require('dapui')

require("dap-python").setup()
require("dap-python").test_runner = "pytest"

vim.api.nvim_set_keymap("n", "<leader>dt", ":DapUiToggle<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>db", ":DapToggleBreakpoint<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>dc", ":DapContinue<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>dr", ":lua require('dapui').open({ reset = true })<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>dR", ":lua require('dapui').close({ reset = true })<CR>", { noremap = true })

vim.keymap.set("n", "<leader>dn", ":lua require('dap-python').test_method()<CR>")
vim.keymap.set("n", "<leader>df", ":lua require('dap-python').test_class()<CR>")
vim.keymap.set("n", "<leader>ds", ":lua require('dap-python').debug_selection()<CR>")


dapui.setup({
    layouts = {
        {
            -- You can change the order of elements in the sidebar
            elements = {
                -- Provide IDs as strings or tables with "id" and "size" keys
                {
                    id = "scopes",
                    size = 0.25, -- Can be float or integer > 1
                },
                { id = "breakpoints", size = 0.25 },
                { id = "stacks",      size = 0.25 },
                { id = "watches",     size = 0.25 },
            },
            size = 40,
            position = "left", -- Can be "left" or "right"
        },
        {
            elements = {
                "console",
                "repl",
            },
            size = 20,
            position = "bottom", -- Can be "bottom" or "top"
        },
    },
})

local dap = require('dap')

require("dapui").setup()
require("dap-python").setup()
require("dap-python").test_runner = "pytest"

vim.api.nvim_set_keymap("n", "<leader>dt", ":DapUiToggle<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>db", ":DapToggleBreakpoint<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>dc", ":DapContinue<CR>", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>dr", ":lua require('dapui').open({ reset = true })<CR>", { noremap = true })

vim.keymap.set("n", "<leader>dn", ":lua require('dap-python').test_method()<CR>")
vim.keymap.set("n", "<leader>df", ":lua require('dap-python').test_class()<CR>")
vim.keymap.set("n", "<leader>ds", ":lua require('dap-python').debug_selection()<CR>")

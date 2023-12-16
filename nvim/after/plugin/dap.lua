require("dap-python").setup("~/.virtualenvs/debugpy/bin/python")
require("dap-python").test_runner = "pytest"

vim.keymap.set("n", "<leader>dn", ":lua require('dap-python').test_method()<CR>")
vim.keymap.set("n", "<leader>df", ":lua require('dap-python').test_class()<CR>")
vim.keymap.set("n", "<leader>ds", ":lua require('dap-python').debug_selection()<CR>")

require("dapui").setup()

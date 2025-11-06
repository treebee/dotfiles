local M = {}

M.on_attach = function(client, bufnr)
	-- Disable formatting for ruff
	if client.name == "ruff" and not require("pam.utils").is_work_laptop() then
		-- Note: We only disable it if we are NOT on the work laptop
		-- Or, if you want it always disabled, remove the condition.
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end

	-- Add any other on_attach logic here, like keymaps
	-- vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
	local opts = { buffer = ev.buf }
	vim.keymap.set("n", "<leader>vd", function()
		vim.diagnostic.open_float()
	end, opts)
	vim.keymap.set("n", "[d", function()
		vim.diagnostic.get_next()
	end, opts)
	vim.keymap.set("n", "]d", function()
		vim.diagnostic.get_prev()
	end, opts)
	vim.keymap.set("n", "gd", function()
		vim.lsp.buf.definition()
	end, opts)
	vim.keymap.set("n", "K", function()
		vim.lsp.buf.hover()
	end, opts)
	vim.keymap.set("n", "<leader>vws", function()
		vim.lsp.buf.workspace_symbol()
	end, opts)
	vim.keymap.set("n", "<leader>vca", function()
		vim.lsp.buf.code_action()
	end, opts)
	vim.keymap.set("n", "<leader>vrr", function()
		vim.lsp.buf.references()
	end, opts)
	vim.keymap.set("n", "<leader>vrn", function()
		vim.lsp.buf.rename()
	end, opts)
	vim.keymap.set("i", "<leader>vrh", function()
		vim.lsp.buf.signature_help()
	end, opts)
	vim.keymap.set("n", "<space>fp", ":ElixirFromPipe<cr>", { buffer = true, noremap = true })
	vim.keymap.set("n", "<space>tp", ":ElixirToPipe<cr>", { buffer = true, noremap = true })
	vim.keymap.set("v", "<space>em", ":ElixirExpandMacro<cr>", { buffer = true, noremap = true })
end

return M

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

vim.lsp.config("*", {
	on_attach = require("pam.lsp").on_attach,
	capabilities = capabilities,
})

vim.diagnostic.config({
	virtual_text = true,
})

if vim.uv.os_gethostname() == "notebook-pam" then
	-- Solute stuff
	-- Only show diagnostics for "our" code,
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "python" },
		callback = function()
			local prefixes = {
				vim.env.SOLUTE_DEV_ROOT,
				vim.env.HOME .. "/workspace/tues",
				vim.env.HOME .. "/GIT/pgpeek",
			}
			local path = vim.api.nvim_buf_get_name(0)
			-- bail out if something looks like an installed module, we sometimes
			-- visit and even edit these for debugging, but we never want to lint
			-- or auto format them, we explicitly check them first because they
			-- may still live below one of our prefixes somewhere in the filesystem
			if string.find(path, "(.*/site-packages/.*|.*/.tox/.*)") ~= nil then
				vim.diagnostic.enable(false)
				return
			end

			for _, prefix in ipairs(prefixes) do
				if string.find(path, "^" .. prefix) ~= nil then
					vim.diagnostic.enable(true)
					return
				end
			end
			-- finally, disable for everything else, assuming it is foreign code
			vim.diagnostic.enable(false)
		end,
	})

	vim.lsp.config("pylsp", {
		cmd = { vim.env["HOME"] .. "/.local/share/uv/tools/solute-pyformat/bin/pylsp" },
	})
end

vim.api.nvim_create_autocmd("BufWritePre", {
	callback = function()
		vim.lsp.buf.format()
	end,
})

require("fidget").setup()

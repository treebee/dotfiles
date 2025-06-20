local lspconfig = require('lspconfig')
local dbxls = require("pam.dbxls")

dbxls.setup()
lspconfig.gleam.setup({})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("PamLspConfig", {}),
    callback = function(ev)
        local opts = { buffer = ev.buf }
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.get_next() end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.get_prev() end, opts)
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<leader>vrh", function() vim.lsp.buf.signature_help() end, opts)
    end,
})

vim.diagnostic.config({
    virtual_text = true
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
    end
})

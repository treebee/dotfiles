local lspconfig = require('lspconfig')
local dbxls = require("pam.dbxls")

dbxls.setup()

lspconfig.gleam.setup({})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("pam_lsp", {}),
    callback = require("pam.lsp").on_attach,
})

vim.diagnostic.config({
    virtual_text = true
})

if vim.loop.os_gethostname() == "notebook-pam" then
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

    -- Format Python code on-save
    vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function()
            if vim.bo.filetype == "python" then
                vim.lsp.buf.format({ async = false })
            end
        end
    })

    require("lspconfig").pylsp.setup({
        cmd = { vim.env["HOME"] .. "/.local/share/uv/tools/solute-pyformat/bin/pylsp" },
        settings = {
            pylsp = {
                plugins = {
                    solute_pyformat = {
                        enabled = true,
                    },
                },
            },
        },
    })
end

vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        vim.lsp.buf.format()
    end
})


lspconfig.rust_analyzer.setup({
    on_attach = function(_, bufnr)
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end,
    settings = {
        ["rust-analyzer"] = {
            imports = {
                granularity = {
                    group = "module",
                },
                prefix = "self",
            },
            cargo = {
                buildScripts = {
                    enable = true,
                },
            },
            procMacro = {
                enable = true
            },
        }
    }
})

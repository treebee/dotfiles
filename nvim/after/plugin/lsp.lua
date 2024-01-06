local lsp = require('lsp-zero')

lsp.preset('recommended')

lsp.on_attach(function(client, bufnr)
    local opts = { buffer = bufnr, remap = false }

    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
    vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
end)

require('mason').setup({})
require('mason-lspconfig').setup({
    -- Replace the language servers listed here
    -- with the ones you want to install
    ensure_installed = { 'tsserver', 'rust_analyzer', 'eslint', 'lua_ls', 'jedi_language_server', 'elixirls', 'html' },
    handlers = {
        lsp.default_setup,
    },
})

require('lspconfig').lua_ls.setup({
    on_init = function(client)
        local path = client.workspace_folders[1].name
        if not vim.loop.fs_stat(path .. '/.luarc.json') and not vim.loop.fs_stat(path .. '/.luarc.jsonc') then
            client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
                Lua = {
                    runtime = {
                        -- Tell the language server which version of Lua you're using
                        -- (most likely LuaJIT in the case of Neovim)
                        version = 'LuaJIT'
                    },
                    -- Make the server aware of Neovim runtime files
                    workspace = {
                        checkThirdParty = false,
                        library = {
                            vim.env.VIMRUNTIME
                            -- "${3rd}/luv/library"
                            -- "${3rd}/busted/library",
                        }
                        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower
                        -- library = vim.api.nvim_get_runtime_file("", true)
                    }
                }
            })

            client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
        end
        return true
    end
})
local cmp = require('cmp')
local cmp_select = { behavior = cmp.SelectBehavior.Select }
local cmp_mappings = lsp.defaults.cmp_mappings({
    ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
    ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
    ['<C-y>'] = cmp.mapping.confirm({ select = true }),
    ['<C-Space>'] = cmp.mapping.complete(),
})

lsp.set_preferences({
    sign_icons = {}
})

cmp.setup({
    mapping = cmp_mappings
})

lsp.setup()

vim.diagnostic.config({
    virtual_text = true
})

require('lspconfig').ruff_lsp.setup {
    init_options = {
        settings = {
            args = {}
        }
    }
}
-- format on save
vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]


-- Solute stuff
-- Only show diagnostics for "our" code,
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python" },
    callback = function()
        prefixes = {
            vim.env.SOLUTE_DEV_ROOT,
            --            vim.env.HOME .. "/GIT/tues",
            --            vim.env.HOME .. "/GIT/pgpeek",
        }
        path = vim.api.nvim_buf_get_name(0)
        buf = vim.api.nvim_win_get_buf(0)
        -- bail out if something looks like an installed module, we sometimes
        -- visit and even edit these for debugging, but we never want to lint
        -- or auto format them, we explicitly check them first because they
        -- may still live below one of our prefixes somewhere in the filesystem
        if string.find(path, "(.*/site-packages/.*|.*/.tox/.*)") ~= nil then
            vim.diagnostic.disable(buf)
            return
        end

        for _, prefix in ipairs(prefixes) do
            if string.find(path, "^" .. prefix) ~= nil then
                vim.diagnostic.enable(buf)
                return
            end
        end
        -- finally, disable for everything else, assuming it is foreign code
        vim.diagnostic.disable(buf)
    end,
})

-- Format Python code on-save
vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function()
        if vim.bo.filetype == "python" then
            vim.lsp.buf.format()
        end
    end
})

if vim.loop.os_gethostname() == "pam-notebook" then
    require("lspconfig").pylsp.setup({
        --cmd = {vim.env["HOME"] .. "/.virtualenvs/solute-pyformat/bin/pylsp", "--log-file", "/tmp/lsplog", "-v"},
        cmd = { vim.env["HOME"] .. "/.virtualenvs/solute-pyformat/bin/pylsp" },
        --cmd = {vim.env["HOME"] .. "/.local/bin/pylsp"},
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
require('dap-python').setup()

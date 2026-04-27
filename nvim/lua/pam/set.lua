vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.api.nvim_create_autocmd("FileType", {
    pattern = "html",
    callback = function()
        vim.opt.tabstop = 2
        vim.opt.softtabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.expandtab = true
    end,
})

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

vim.api.nvim_set_option_value("clipboard", "unnamedplus", { scope = "global" })

vim.opt.laststatus = 3


local treesitter_group = vim.api.nvim_create_augroup("pam-treesitter-main", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = treesitter_group,
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)

        local filetype = vim.bo[args.buf].filetype

        if not vim.treesitter.get_parser(args.buf, nil, { error = false }) then
            return
        end

        local language = vim.treesitter.language.get_lang(filetype)
        if not language then
            return
        end

        local has_indents, query = pcall(vim.treesitter.query.get, language, "indents")
        if has_indents and query then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

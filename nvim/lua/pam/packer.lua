-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    use('nvim-lua/plenary.nvim', { tag = '0.1.4' })
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.4',
        requires = { { 'nvim-lua/plenary.nvim', tag = '0.1.4' } }
    }

    use({
        "rebelot/kanagawa.nvim",
        as = 'kanagawa',
        setup = function()
            commentStyle = { italic = true };
            theme = "dragon";
            background = {
                dark = "dragon",
                light = "lotus"
            }
        end,
        config = function()
            vim.cmd('colorscheme kanagawa')
        end
    })
    use('nvim-treesitter/nvim-treesitter', { run = ':TSUpdate', tag = 'v0.9.1' })
    use('theprimeagen/harpoon', { branch = 'harpoon2' })
    use('mbbill/undotree', { tag = 'rel_6.1' })
    use('tpope/vim-fugitive', { tag = 'v3.7' })
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            --- Uncomment these if you want to manage LSP servers from neovim
            { 'williamboman/mason.nvim' },
            { 'williamboman/mason-lspconfig.nvim' },

            -- LSP Support
            { 'neovim/nvim-lspconfig' },
            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },
            { 'hrsh7th/cmp-nvim-lsp' },
            { 'L3MON4D3/LuaSnip' },
        }
    }
    use('github/copilot.vim')
    use('theprimeagen/vim-be-good')

    use('neovim/nvim-lspconfig', { tag = 'v0.1.x' })
    use('simrat39/rust-tools.nvim')

    -- Debugging
    use('mfussenegger/nvim-dap')
end)

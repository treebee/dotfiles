if vim.uv.os_gethostname() == "notebook-pam" then
    return {
        dir = vim.env.HOME .. "/workspace/tickets.nvim",
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-telescope/telescope.nvim', -- optional
            'nvim-tree/nvim-web-devicons'    -- optional
        },
        config = function()
            require('tickets').setup({
                jira_url = "https://solute.atlassian.net",
                auth = {
                    email = "pam@solute.de",
                    api_token = os.getenv("JIRA_API_TOKEN"),
                },
                -- UI settings
                ui = {
                    icons = true,
                    width = 0.9,
                    height = 0.8
                },

                -- Optional telescope integration
                telescope = {
                    enabled = true,
                },
            })
        end
    }
else
    return {}
end

return {
<<<<<<< HEAD
    {
        "zbirenbaum/copilot.lua",
        event = { "BufEnter" },
        config = function()
            require("copilot").setup({
                suggestion = {
                    enabled = false,
                },
                panel = { enabled = false },
            })
        end,
    },
    {
        "zbirenbaum/copilot-cmp",
        event = { "BufEnter" },
        dependencies = { "zbirenbaum/copilot.lua" },
        config = function()
            require("copilot_cmp").setup()
        end,
    },
=======
	{
		"zbirenbaum/copilot.lua",
		event = { "BufEnter" },
		config = function()
			require("copilot").setup({
				suggestion = {
					enabled = false,
				},
				panel = { enabled = false },
			})
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		event = { "BufEnter" },
		dependencies = { "zbirenbaum/copilot.lua" },
		config = function()
			require("copilot_cmp").setup()
		end,
	},
>>>>>>> 4671164 (nvim: Activate fidget and add copilot cmp)
}

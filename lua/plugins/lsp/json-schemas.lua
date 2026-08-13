return {
	{
		"b0o/schemastore.nvim",
		lazy = true,
	},
	{
		"saghen/blink.cmp",
		opts = function(_, opts)
			opts.sources = opts.sources or {}
			opts.sources.providers = opts.sources.providers or {}
			opts.sources.providers.launch_json = {
				name = "LaunchJson",
				module = "plugins.krs.launch_cmp",
				score_offset = 100,
				enabled = function()
					local name = vim.fn.expand("%:t")
					return name == "launch.json"
				end,
			}

			opts.sources.providers.krsnvim = {
				name = "KrsNvimScript",
				module = "plugins.krs.krsnvim_cmp",
				score_offset = 100,
				enabled = function()
					local name = vim.fn.expand("%:t")
					local ft = vim.bo.filetype
					return name:match("%.krsnvim$") ~= nil or ft == "krsnvim"
				end,
			}

			if opts.sources.default then
				if not vim.tbl_contains(opts.sources.default, "launch_json") then
					table.insert(opts.sources.default, "launch_json")
				end
				if not vim.tbl_contains(opts.sources.default, "krsnvim") then
					table.insert(opts.sources.default, "krsnvim")
				end
			end
		end,
	},
}

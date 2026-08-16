-- ============================================================================
-- PLUGINS: GitSigns -- git signs in signcolumn, hunk previews & stage/reset.
-- ============================================================================

return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "" },
			topdelete = { text = "" },
			changedelete = { text = "▎" },
			untracked = { text = "▎" },
		},
		signcolumn = true,
		numhl = false,
		linehl = false,
		word_diff = false,
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		attach_to_untracked = true,
		current_line_blame = false,
		preview_config = {
			border = "rounded",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns
			if not gs then
				return
			end

			local function map(mode, l, r, opts)
				opts = opts or {}
				opts.buffer = bufnr
				vim.keymap.set(mode, l, r, opts)
			end

			-- Hunk Navigation
			map("n", "]c", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gs.next_hunk()
				end)
				return "<Ignore>"
			end, { expr = true, desc = "Next Git Hunk" })

			map("n", "[c", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, { expr = true, desc = "Previous Git Hunk" })

			-- Hunk Actions
			map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage Git Hunk" })
			map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset Git Hunk" })
			map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview Git Hunk" })
			map("n", "<leader>hb", function()
				gs.blame_line({ full = true })
			end, { desc = "Git Blame Line" })
			map("n", "<leader>hd", gs.diffthis, { desc = "Git Diff This" })
		end,
	},
}

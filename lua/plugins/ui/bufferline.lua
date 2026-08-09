return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("bufferline").setup({
			options = {
				mode = "buffers",
				separator_style = "slant",
				always_show_bufferline = true,
				show_buffer_close_icons = true,
				show_close_icon = false,
				offsets = {
					{ filetype = "neo-tree", text = "🦊 Explorer", highlight = "Directory", text_align = "left" },
				},
			},
		})

		vim.keymap.set(
			"n",
			"gt",
			"<Cmd>BufferLineCycleNext<CR>",
			{ noremap = true, silent = true, desc = "Next tab" }
		)
		vim.keymap.set(
			"n",
			"gT",
			"<Cmd>BufferLineCyclePrev<CR>",
			{ noremap = true, silent = true, desc = "Previous tab" }
		)

		-- Move active tab order left / right (reordering buffer tabs)
		local move_left_keys = {
			"<C-A-Left>",
			"<A-S-h>",
			"<A-H>",
			"<A-S-Left>",
			"<A-S-k>",
			"<A-K>",
		}
		local move_right_keys = {
			"<C-A-Right>",
			"<A-S-l>",
			"<A-L>",
			"<A-S-Right>",
			"<A-S-j>",
			"<A-J>",
		}

		for _, key in ipairs(move_left_keys) do
			pcall(vim.keymap.set, "n", key, "<Cmd>BufferLineMovePrev<CR>", { noremap = true, silent = true, desc = "Move buffer tab left" })
		end

		for _, key in ipairs(move_right_keys) do
			pcall(vim.keymap.set, "n", key, "<Cmd>BufferLineMoveNext<CR>", { noremap = true, silent = true, desc = "Move buffer tab right" })
		end

		-- Leader shortcuts for moving buffer tabs
		vim.keymap.set("n", "<leader>bh", "<Cmd>BufferLineMovePrev<CR>", { noremap = true, silent = true, desc = "Move buffer tab left" })
		vim.keymap.set("n", "<leader>bl", "<Cmd>BufferLineMoveNext<CR>", { noremap = true, silent = true, desc = "Move buffer tab right" })
	end,
}

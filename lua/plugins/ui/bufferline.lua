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

		-- Move active tab order left / right
		vim.keymap.set(
			"n",
			"<C-A-h>",
			"<Cmd>BufferLineMovePrev<CR>",
			{ noremap = true, silent = true, desc = "Move tab left" }
		)
		vim.keymap.set(
			"n",
			"<C-A-l>",
			"<Cmd>BufferLineMoveNext<CR>",
			{ noremap = true, silent = true, desc = "Move tab right" }
		)
	end,
}

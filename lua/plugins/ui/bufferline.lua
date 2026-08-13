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
				close_command = function(bufnr)
					if _G.Smart_Close_Buffer then
						_G.Smart_Close_Buffer(bufnr, true)
					else
						pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
					end
				end,
				right_mouse_command = function(bufnr)
					if _G.Smart_Close_Buffer then
						_G.Smart_Close_Buffer(bufnr, true)
					else
						pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
					end
				end,
				middle_mouse_command = function(bufnr)
					if _G.Smart_Close_Buffer then
						_G.Smart_Close_Buffer(bufnr, true)
					else
						pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
					end
				end,
				offsets = {
					{ filetype = "neo-tree", text = "🦊 Explorer", highlight = "Directory", text_align = "left" },
				},
				name_formatter = function(buf)
					local bufnr = buf.bufnr
					if _G.Is_File_Deleted and _G.Is_File_Deleted(bufnr) then
						return "[D] " .. buf.name
					end
					local path = buf.path
					if not path or path == "" then
						path = vim.api.nvim_buf_get_name(bufnr)
					end
					if path and path ~= "" and vim.bo[bufnr].buftype == "" then
						if not path:match("^%a[%a%d+.-]+://") and not path:match("^node:") then
							local uv = vim.uv or vim.loop
							if uv.fs_stat(path) == nil then
								return "[D] " .. buf.name
							end
						end
					end
					return buf.name
				end,

				-- nvim-dap force-lists every stack-frame buffer (dap/session.lua sets
				-- buflisted = true on jump), so a debug session fills the bufferline
				-- with node internals, dap-src:// frames and the term:// console.
				-- Only real files on disk are tabs.
				custom_filter = function(bufnr)
					if vim.bo[bufnr].buftype ~= "" then
						return false
					end
					local name = vim.api.nvim_buf_get_name(bufnr)
					if name == "" or name:match("^%a[%a%d+.-]+://") or name:match("^node:") then
						return false
					end
					return not name:match("[/\\]node_modules[/\\]")
				end,
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

-- ============================================================================
-- PLUGIN: bufferline -- the tab bar across the top.
-- ============================================================================
-- WHAT IS CUSTOMISED
--   * Closing a tab (icon, middle click, right click) routes through the smart
--     buffer closer, so the editor lands on the dashboard instead of quitting.
--   * A deleted file is prefixed with `[D]`, using the cached state from
--     plugins/krs/smart_check.lua -- no disk access while drawing the bar.
--   * Only real files on disk become tabs. nvim-dap force-lists every stack frame
--     buffer, which would otherwise fill the bar with node internals,
--     `dap-src://` frames and the terminal console.
--
-- KEYS
--   gt / gT           next / previous buffer
--   <leader>bh / bl   move the current tab left / right (many alt aliases too)
-- ============================================================================

--- Closes a tab the same way <C-q> does: the smart closer keeps the editor in a
--- usable state, and falls back to a plain delete before it has loaded.
--- @param bufnr integer Buffer behind the tab.
local function close_buffer(bufnr)
	if _G.Smart_Close_Buffer then
		_G.Smart_Close_Buffer(bufnr, false)
	else
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end
end

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
				close_command = close_buffer,
				right_mouse_command = close_buffer,
				middle_mouse_command = close_buffer,
				offsets = {
					{ filetype = "neo-tree", text = "🦊 Explorer", highlight = "Directory", text_align = "left" },
				},
				name_formatter = function(buf)
					if _G.Is_File_Deleted and _G.Is_File_Deleted(buf.bufnr) then
						return "[D] " .. buf.name
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

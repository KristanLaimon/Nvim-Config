-- ============================================================================
-- 🦊 KRS CONFIG: Live Colorscheme Previewer
-- ============================================================================
-- HOW THIS MODULE WORKS:
-- 1. Listens to Vim command line events (`CmdlineChanged` and `CmdlineLeave`).
-- 2. When you type `:colorscheme <theme>` and navigate with `<Tab>`, it captures the theme name.
-- 3. Temporarily applies the theme in real time for instant preview (`pcall(vim.cmd.colorscheme, name)`).
-- 4. If input is cancelled (pressing Esc without Enter), automatically restores the original theme (`vim.v.event.abort`).
-- ============================================================================

local M = {}

local colorscheme_preview_orig = nil

function M.setup()
	local group = vim.api.nvim_create_augroup("KRSColorschemeLivePreview", { clear = true })

	-- Event 1: Command line text modified
	vim.api.nvim_create_autocmd("CmdlineChanged", {
		group = group,
		callback = function()
			if vim.fn.getcmdtype() ~= ":" then
				return
			end

			local cmdline = vim.fn.getcmdline()
			local name = cmdline:match("^colo%S*%s+(%S+)%s*$")

			if not name then
				return
			end

			-- Save original theme before previewing
			if colorscheme_preview_orig == nil then
				colorscheme_preview_orig = vim.g.colors_name
			end

			pcall(vim.cmd.colorscheme, name)
		end,
	})

	-- Event 2: Command line confirmed or left
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		callback = function()
			if vim.fn.getcmdtype() ~= ":" then
				return
			end

			local cmdline = vim.fn.getcmdline()
			local applied = cmdline:match("^colo%S*%s+(%S+)%s*$")

			-- If cancelled with Esc (abort = true) and not applied -> revert to previous theme
			if colorscheme_preview_orig and vim.v.event.abort and not applied then
				pcall(vim.cmd.colorscheme, colorscheme_preview_orig)
			end

			colorscheme_preview_orig = nil
		end,
	})
end

return M


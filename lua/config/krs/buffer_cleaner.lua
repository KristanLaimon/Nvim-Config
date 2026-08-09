-- ============================================================================
-- 🦊 KRS CONFIG: Buffer Cleaner & Smart Quit Manager
-- ============================================================================
-- HOW THIS MODULE WORKS:
-- 1. `Neotree_Smart_Quit`: Smartly closes current buffer/tab:
--      - If multiple tabs/buffers are open, closes only current tab and moves to previous (without quitting Neovim).
--      - Si screen is split, closes only the current split window.
--      - If it is the last open file, deletes buffer and returns to Alpha Dashboard.
--      - If already on Alpha Dashboard, `:q` quits Neovim completely.
-- 2. `CleanNoNameBuffers`: Autocommand detecting and clearing empty unmodified [No Name] buffers when real files open.
-- 3. `AddOpenedFolder`: Keeps record of recently opened folders/projects for Telescope.
-- 4. Command aliases `:q` and `:q!`: Overrides `:q` to dynamically trigger smart quit.
-- ============================================================================

local M = {}

-- Global table for tracking opened folders
_G.OpenedFolders = _G.OpenedFolders or {}

function _G.AddOpenedFolder(dir_path)
	if not dir_path or dir_path == "" then
		return
	end
	local clean = vim.fn.fnamemodify(dir_path, ":p"):gsub("[/\\]$", "")
	if vim.fn.isdirectory(clean) == 1 then
		_G.OpenedFolders[clean:lower()] = clean
	end
end

-- Smart Buffer & Tab Manager Quit Function
function _G.Neotree_Smart_Quit(force)
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[cur_buf].filetype
	local bt = vim.bo[cur_buf].buftype

	-- 1. If in Alpha (Dashboard), :q quits Neovim completely
	if ft == "alpha" then
		vim.cmd(force and "qa!" or "qa")
		return
	end

	-- 2. If focused on Neo-tree, close Neo-tree sidebar
	if ft == "neo-tree" then
		pcall(vim.cmd, "Neotree close")
		return
	end

	-- 3. If in a terminal window, close that window
	if bt == "terminal" then
		pcall(vim.cmd, force and "close!" or "close")
		return
	end

	-- Count how many real code windows (excluding Neo-tree) are in the current tabpage
	local code_wins = 0
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local b = vim.api.nvim_win_get_buf(win)
			local bft = vim.bo[b].filetype
			if bft ~= "neo-tree" and bft ~= "alpha" then
				code_wins = code_wins + 1
			end
		end
	end

	-- If multiple window splits exist, close only the current split
	if code_wins > 1 then
		pcall(vim.cmd, force and "close!" or "close")
		return
	end

	-- Count how many real file buffers are open in total
	local bufs = vim.api.nvim_list_bufs()
	local real_bufs = {}
	for _, b in ipairs(bufs) do
		if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
			local bname = vim.api.nvim_buf_get_name(b)
			local bft = vim.bo[b].filetype
			if bft ~= "alpha" and bft ~= "neo-tree" then
				table.insert(real_bufs, b)
			end
		end
	end

	-- If more than 1 file buffer open in bufferline:
	if #real_bufs > 1 then
		-- Cycle to previous buffer before deleting current
		pcall(vim.cmd, "BufferLineCyclePrev")
		pcall(vim.api.nvim_buf_delete, cur_buf, { force = force })
	else
		-- Last file buffer -> Show Alpha Dashboard FIRST, then delete buffer
		local ok_alpha = pcall(vim.cmd, "Alpha")
		if not ok_alpha then
			pcall(vim.cmd, "enew")
		end
		pcall(vim.api.nvim_buf_delete, cur_buf, { force = force })
	end
end

function M.setup()
	-- Initialize working directory in OpenedFolders
	_G.AddOpenedFolder(vim.fn.getcwd())

	-- Autocmd: Track directory changes (:cd / Telescope projects)
	local group_track = vim.api.nvim_create_augroup("KRSTrackOpenedFolders", { clear = true })
	vim.api.nvim_create_autocmd("DirChanged", {
		group = group_track,
		callback = function(ctx)
			local dir = (ctx.file and ctx.file ~= "") and ctx.file or vim.fn.getcwd()
			_G.AddOpenedFolder(dir)
		end,
	})

	-- Autocmd: Automatic cleanup of empty [No Name] buffers when real files are open
	local group_clean = vim.api.nvim_create_augroup("KRSCleanNoNameBuffers", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group_clean,
		callback = function()
			vim.schedule(function()
				local bufs = vim.api.nvim_list_bufs()
				local real_files = 0
				for _, b in ipairs(bufs) do
					if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
						local bname = vim.api.nvim_buf_get_name(b)
						local btype = vim.bo[b].buftype
						local ftype = vim.bo[b].filetype
						if bname ~= "" and btype == "" and ftype ~= "alpha" and ftype ~= "neo-tree" then
							real_files = real_files + 1
						end
					end
				end

				-- Only clean [No Name] buffers if at least 1 real file is open
				if real_files > 0 then
					local visible_bufs = {}
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) then
							visible_bufs[vim.api.nvim_win_get_buf(win)] = true
						end
					end

					for _, b in ipairs(bufs) do
						if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
							local bname = vim.api.nvim_buf_get_name(b)
							local btype = vim.bo[b].buftype
							local modified = vim.bo[b].modified
							if bname == "" and btype == "" and not modified and not visible_bufs[b] then
								pcall(vim.api.nvim_buf_delete, b, { force = true })
							end
						end
					end
				end
			end)
		end,
	})

	-- Keybindings for smart buffer quit (Ctrl+Q & Leader+q)
	vim.keymap.set("n", "<C-q>", function()
		_G.Neotree_Smart_Quit(false)
	end, { noremap = true, silent = true, desc = "Close current buffer/tab" })
	vim.keymap.set("n", "<leader>q", function()
		_G.Neotree_Smart_Quit(false)
	end, { noremap = true, silent = true, desc = "Close current buffer/tab" })

	-- Override :q, :q!, :bd, :bd!, :bdelete to trigger smart quit
	vim.cmd([[
		cnoreabbrev <expr> q (getcmdtype() == ':' && getcmdline() ==# 'q') ? 'lua _G.Neotree_Smart_Quit(false)' : 'q'
		cnoreabbrev <expr> q! (getcmdtype() == ':' && getcmdline() ==# 'q!') ? 'lua _G.Neotree_Smart_Quit(true)' : 'q!'
		cnoreabbrev <expr> bd (getcmdtype() == ':' && getcmdline() ==# 'bd') ? 'lua _G.Neotree_Smart_Quit(false)' : 'bd'
		cnoreabbrev <expr> bd! (getcmdtype() == ':' && getcmdline() ==# 'bd!') ? 'lua _G.Neotree_Smart_Quit(true)' : 'bd!'
		cnoreabbrev <expr> bdelete (getcmdtype() == ':' && getcmdline() ==# 'bdelete') ? 'lua _G.Neotree_Smart_Quit(false)' : 'bdelete'
		cnoreabbrev <expr> bdelete! (getcmdtype() == ':' && getcmdline() ==# 'bdelete!') ? 'lua _G.Neotree_Smart_Quit(true)' : 'bdelete!'
	]])
end

return M


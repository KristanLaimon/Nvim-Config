-- ============================================================================
-- 🦊 KRS CONFIG: Media & Image Viewer (OS Default Program & Chafa Terminal)
-- ============================================================================
-- 1. Press <Ctrl + Shift + Enter> to open current image/video in OS default application.
-- 2. Press <leader>i to preview images directly inside terminal using Chafa.
-- 3. Supports all image formats (png, jpg, gif, webp, svg, etc.) and video formats (mp4, mkv, avi, mov, etc.).
-- ============================================================================

local M = {}

local media_exts = {
	-- Images
	png = true, jpg = true, jpeg = true, gif = true, webp = true,
	bmp = true, ico = true, svg = true, tiff = true, avif = true, heic = true,
	-- Videos
	mp4 = true, mkv = true, avi = true, mov = true, wmv = true,
	flv = true, webm = true, m4v = true, ["3gp"] = true, ogv = true,
}

local function is_media_file(path)
	if not path or path == "" then return false end
	local ext = vim.fn.fnamemodify(path, ":e"):lower()
	return media_exts[ext] == true
end

-- Open file with OS default application (Windows / macOS / Linux)
function M.open_with_system_app(filepath)
	-- Check if Neo-tree has a selected node
	local neotree_path = nil
	local ok_mgr, manager = pcall(require, "neo-tree.sources.manager")
	if ok_mgr and manager.get_state then
		local state = manager.get_state("filesystem")
		if state and state.tree then
			local node = state.tree:get_node()
			if node and node.path then
				neotree_path = node.path
			end
		end
	end

	-- If focused on Neo-tree or filepath is not provided, use Neo-tree selected node
	if vim.bo.filetype == "neo-tree" and neotree_path then
		filepath = neotree_path
	elseif not filepath or filepath == "" then
		filepath = neotree_path or vim.api.nvim_buf_get_name(0)
	end

	if not filepath or filepath == "" or vim.fn.filereadable(filepath) == 0 then
		-- Fallback to first real active buffer
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype ~= "neo-tree" and vim.bo[b].buftype == "" then
				local name = vim.api.nvim_buf_get_name(b)
				if name ~= "" and vim.fn.filereadable(name) == 1 then
					filepath = name
					break
				end
			end
		end
	end

	if not filepath or filepath == "" or vim.fn.filereadable(filepath) == 0 then
		vim.notify("No valid file found to open", vim.log.levels.WARN, { title = "Media Viewer" })
		return
	end

	local is_win = vim.fn.has("win32") == 1
	local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1

	if is_win then
		vim.system({ "cmd.exe", "/c", "start", '""', filepath }, { detach = true })
	elseif is_mac then
		vim.system({ "open", filepath }, { detach = true })
	else
		vim.system({ "xdg-open", filepath }, { detach = true })
	end

	local filename = vim.fn.fnamemodify(filepath, ":t")
	vim.notify("🎬 Opening with OS default program: " .. filename, vim.log.levels.INFO, { title = "Media Viewer" })
end

function M.view_current_image()
	local path = vim.api.nvim_buf_get_name(0)

	if path == "" or vim.fn.filereadable(path) == 0 or vim.bo.filetype == "neo-tree" then
		path = ""
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype ~= "neo-tree" and vim.bo[b].buftype == "" then
				local name = vim.api.nvim_buf_get_name(b)
				if name ~= "" and vim.fn.filereadable(name) == 1 then
					path = name
					break
				end
			end
		end
	end

	if path == "" then
		vim.notify("No valid file to display", vim.log.levels.WARN, { title = "KRS Image Viewer" })
		return
	end

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	})

	vim.fn.termopen(string.format("chafa --size=%dx%d %s", width, height, vim.fn.shellescape(path)))

	vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", { buffer = buf, silent = true })
end

function M.setup()
	-- Map <leader>i to open image viewer with Chafa
	vim.keymap.set(
		"n",
		"<leader>i",
		M.view_current_image,
		{ noremap = true, silent = true, desc = "View image with Chafa" }
	)

	-- Map Ctrl + Shift + Enter to open image or video with OS default program
	local cr_keys = { "<C-S-CR>", "<C-S-Enter>", "<C-S-Return>" }
	local modes = { "n", "i", "v", "t" }

	for _, mode in ipairs(modes) do
		for _, key in ipairs(cr_keys) do
			vim.keymap.set(mode, key, function()
				if vim.fn.mode() == "t" then
					vim.cmd("stopinsert")
				end
				M.open_with_system_app()
			end, { noremap = true, silent = true, desc = "Open Media with OS Default App" })
		end
	end

	-- Autocmd to notify user when opening media files
	vim.api.nvim_create_autocmd("BufReadPost", {
		pattern = "*",
		callback = function(ev)
			local name = vim.api.nvim_buf_get_name(ev.buf)
			if is_media_file(name) then
				local filename = vim.fn.fnamemodify(name, ":t")
				vim.notify(
					"🖼️ Media file opened: " .. filename .. "\nPress <Ctrl + Shift + Enter> to open with OS default program.",
					vim.log.levels.INFO,
					{ title = "Media Viewer" }
				)
			end
		end,
	})
end

return M



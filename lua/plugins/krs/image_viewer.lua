-- ============================================================================
-- 🦊 KRS PLUGIN: Media & Image Viewer (OS Default Program & Chafa Terminal)
-- ============================================================================
-- 1. Press <Ctrl + Shift + Enter> to open current image/video in OS default application.
-- 2. Press <leader>i to preview images directly inside terminal using Chafa.
-- 3. Supports all image formats (png, jpg, gif, webp, svg, etc.) and video formats.
-- 4. Portable lazy plugin spec exportable across Neovim configs.
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

local function path_exists(p)
	return p ~= nil and p ~= "" and (vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1)
end

local function windows_path_for_wsl(linux_path)
	local distro = os.getenv("WSL_DISTRO_NAME")
	if not distro then
		return nil
	end
	local rel = linux_path:gsub("^/", ""):gsub("/", "\\")
	return "\\\\wsl.localhost\\" .. distro .. "\\" .. rel
end

function M.open_with_system_app(filepath)
	local ok, err = pcall(function()
		if not filepath or filepath == "" then
			filepath = vim.api.nvim_buf_get_name(0)
		end

		if not path_exists(filepath) then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local b = vim.api.nvim_win_get_buf(win)
				if vim.bo[b].filetype ~= "neo-tree" and vim.bo[b].buftype == "" then
					local name = vim.api.nvim_buf_get_name(b)
					if path_exists(name) then
						filepath = name
						break
					end
				end
			end
		end

		if not path_exists(filepath) then
			vim.notify("No valid file or folder found to open", vim.log.levels.WARN, { title = "Media Viewer" })
			return
		end

		filepath = filepath:gsub("[/\\]+$", "")

		local is_win = vim.fn.has("win32") == 1
		local is_wsl = vim.fn.has("wsl") == 1
		local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1

		local cmd
		if is_win then
			cmd = { "cmd.exe", "/c", "start", '""', filepath }
		elseif is_wsl then
			cmd = { "explorer.exe", windows_path_for_wsl(filepath) or filepath }
		elseif is_mac then
			cmd = { "open", filepath }
		else
			cmd = { "xdg-open", filepath }
		end

		vim.system(cmd, { detach = true }, function(result)
			if result.code ~= 0 and cmd[1] ~= "cmd.exe" and cmd[1] ~= "explorer.exe" then
				vim.schedule(function()
					vim.notify(
						"Failed to open: " .. (result.stderr ~= "" and result.stderr or cmd[1] .. " exited " .. result.code),
						vim.log.levels.ERROR,
						{ title = "Media Viewer" }
					)
				end)
			end
		end)

		local filename = vim.fn.fnamemodify(filepath, ":t")
		vim.notify("🎬 Opening with OS default program: " .. filename, vim.log.levels.INFO, { title = "Media Viewer" })
	end)

	if not ok then
		vim.notify("Reveal in system explorer failed: " .. tostring(err), vim.log.levels.ERROR, { title = "Media Viewer" })
	end
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

function M.open_project_root_in_explorer()
	M.open_with_system_app(vim.fn.getcwd())
end

function M.setup()
	vim.api.nvim_create_user_command("OpenRootInExplorer", function()
		M.open_project_root_in_explorer()
	end, { desc = "Open current project root in the OS file explorer" })

	vim.keymap.set(
		"n",
		"<leader>i",
		M.view_current_image,
		{ noremap = true, silent = true, desc = "View image with Chafa" }
	)

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

_G.ImageViewer = M

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "image_viewer",
	dir = require("krs.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

local M = {}

local font_name = "JetBrainsMono Nerd Font"
local default_size = 14
local min_size = 6
local max_size = 40

local config_path = vim.fn.stdpath("config") .. "/font_config.json"

local function read_config()
	local f = io.open(config_path, "r")
	if not f then
		return { font_size = default_size, font_name = font_name }
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" and data.font_size then
		return data
	end
	return { font_size = default_size, font_name = font_name }
end

local function write_config(data)
	local ok, encoded = pcall(vim.json.encode, data)
	if ok then
		local f = io.open(config_path, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

local current_data = read_config()
M.current_size = current_data.font_size or default_size
M.font_name = current_data.font_name or font_name

function M.apply_font_size(size)
	size = math.max(min_size, math.min(max_size, size))
	M.current_size = size

	-- Update vim.o.guifont
	local font_str = M.font_name .. ":h" .. tostring(size)
	pcall(function()
		vim.o.guifont = font_str
	end)

	-- Update Neovide scale factor if running Neovide
	if vim.g.neovide then
		pcall(function()
			vim.g.neovide_scale_factor = size / 14.0
		end)
	end

	-- Persist configuration
	write_config({
		font_size = size,
		font_name = M.font_name,
	})
end

function M.increase()
	M.apply_font_size(M.current_size + 1)
	vim.notify("🔍 Font size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager" })
end

function M.decrease()
	M.apply_font_size(M.current_size - 1)
	vim.notify("🔍 Font size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager" })
end

function M.reset()
	M.apply_font_size(default_size)
	vim.notify("🔍 Font size reset: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager" })
end

function M.setup()
	-- Apply initial font size on setup
	M.apply_font_size(M.current_size)

	-- Register user commands
	vim.api.nvim_create_user_command("FontSizeIncrease", M.increase, { desc = "Increase font size" })
	vim.api.nvim_create_user_command("FontSizeDecrease", M.decrease, { desc = "Decrease font size" })
	vim.api.nvim_create_user_command("FontSizeReset", M.reset, { desc = "Reset font size" })

	-- Register global keybindings for Normal, Insert, Visual, and Terminal modes
	local modes = { "n", "i", "v", "t" }
	local opts = { noremap = true, silent = true }

	-- Increase font size: Ctrl + +, Ctrl + =, Ctrl + NumpadAdd
	vim.keymap.set(modes, "<C-=>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-+>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-kPlus>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))

	-- Decrease font size: Ctrl + -, Ctrl + NumpadMinus
	vim.keymap.set(modes, "<C-->", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-kMinus>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))

	-- Reset font size: Ctrl + 0
	vim.keymap.set(modes, "<C-0>", M.reset, vim.tbl_extend("force", opts, { desc = "Reset font size" }))
end

return M

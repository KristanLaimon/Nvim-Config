-- ============================================================================
-- 🦊 KRS CONFIG: Font Manager & GUI Scale
-- ============================================================================
-- HOW THIS MODULE WORKS:
-- 1. Reads/Saves font configuration in a JSON file in stdpath("config").
-- 2. Dynamically modifies 'vim.o.guifont' and Neovide scale factor (if using Neovide).
-- 3. Registers user commands (:FontSizeIncrease, :FontSizeDecrease, :FontSizeReset).
-- 4. Registers global keymaps (Ctrl + +, Ctrl + -, Ctrl + 0).
-- ============================================================================

local M = {}

-- Default configuration
local font_name = "JetBrainsMono Nerd Font"
local default_size = 14
local min_size = 6
local max_size = 40

-- Persistence JSON path: ~/.config/nvim/font_config.json (or AppData/Local/nvim on Windows)
local config_path = vim.fn.stdpath("config") .. "/font_config.json"

-- Private function: Read saved font configuration from disk
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

-- Private function: Save font configuration to disk in JSON format
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

-- Load initial data
local current_data = read_config()
M.current_size = current_data.font_size or default_size
M.font_name = current_data.font_name or font_name

-- Apply font size and update GUI variables (Neovim GUI / Neovide)
function M.apply_font_size(size)
	-- Clamp size between min_size and max_size
	size = math.max(min_size, math.min(max_size, size))
	M.current_size = size

	-- Update native option guifont
	local font_str = M.font_name .. ":h" .. tostring(size)
	pcall(function()
		vim.o.guifont = font_str
	end)

	-- If running in Neovide, adjust scale factor
	if vim.g.neovide then
		pcall(function()
			vim.g.neovide_scale_factor = size / 14.0
		end)
	end

	-- Persist changes to JSON
	write_config({
		font_size = size,
		font_name = M.font_name,
	})
end

-- Increase size
function M.increase()
	M.apply_font_size(M.current_size + 1)
	vim.notify("🔍 Font Size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Decrease size
function M.decrease()
	M.apply_font_size(M.current_size - 1)
	vim.notify("🔍 Font Size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Reset size to default
function M.reset()
	M.apply_font_size(default_size)
	vim.notify("🔍 Font Reset: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Public setup function
function M.setup()
	-- Apply initial size at startup
	M.apply_font_size(M.current_size)

	-- Register User Commands in Neovim (:FontSizeIncrease, etc.)
	vim.api.nvim_create_user_command("FontSizeIncrease", M.increase, { desc = "Increase font size" })
	vim.api.nvim_create_user_command("FontSizeDecrease", M.decrease, { desc = "Decrease font size" })
	vim.api.nvim_create_user_command("FontSizeReset", M.reset, { desc = "Reset font size" })

	-- Register Keymaps for Normal, Insert, Visual, and Terminal modes
	local modes = { "n", "i", "v", "t" }
	local opts = { noremap = true, silent = true }

	-- Ctrl + +, Ctrl + =, Ctrl + NumpadAdd
	vim.keymap.set(modes, "<C-=>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-+>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-kPlus>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))

	-- Ctrl + -, Ctrl + NumpadMinus
	vim.keymap.set(modes, "<C-->", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-kMinus>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))

	-- Ctrl + 0
	vim.keymap.set(modes, "<C-0>", M.reset, vim.tbl_extend("force", opts, { desc = "Reset font size" }))
end

return M

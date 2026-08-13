-- ============================================================================
-- 🦊 KRS PLUGIN: Font Manager & GUI Scale
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Reads/Saves font configuration in a JSON file in stdpath("config").
-- 2. Dynamically modifies 'vim.o.guifont' and Neovide scale factor (if using Neovide).
-- 3. Registers user commands (:FontSizeIncrease, :FontSizeDecrease, :FontSizeReset).
-- 4. Registers global keymaps (Ctrl + +, Ctrl + -, Ctrl + 0, Ctrl + Mouse Wheel).
-- 5. Portable lazy plugin spec exportable across Neovim configs.
-- ============================================================================

local M = {}

-- Default configuration
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

-- Apply font size and update GUI variables (Neovim GUI / Neovide)
function M.apply_font_size(size)
	size = math.max(min_size, math.min(max_size, size))
	M.current_size = size

	local font_str = M.font_name .. ":h" .. tostring(size)
	pcall(function()
		vim.o.guifont = font_str
	end)

	if vim.g.neovide then
		pcall(function()
			vim.g.neovide_scale_factor = size / 14.0
			vim.g.neovide_padding_top = 0
			vim.g.neovide_padding_bottom = 0
			vim.g.neovide_padding_right = 0
			vim.g.neovide_padding_left = 0
		end)
	end

	write_config({
		font_size = size,
		font_name = M.font_name,
	})
end

function M.increase()
	M.apply_font_size(M.current_size + 1)
	vim.notify("🔍 Font Size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

function M.decrease()
	M.apply_font_size(M.current_size - 1)
	vim.notify("🔍 Font Size: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

function M.reset()
	M.apply_font_size(default_size)
	vim.notify("🔍 Font Reset: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

function M.setup()
	M.apply_font_size(M.current_size)

	if vim.fn.exists(":FontSizeIncrease") == 0 then
		vim.api.nvim_create_user_command("FontSizeIncrease", M.increase, { desc = "Increase font size" })
	end
	if vim.fn.exists(":FontSizeDecrease") == 0 then
		vim.api.nvim_create_user_command("FontSizeDecrease", M.decrease, { desc = "Decrease font size" })
	end
	if vim.fn.exists(":FontSizeReset") == 0 then
		vim.api.nvim_create_user_command("FontSizeReset", M.reset, { desc = "Reset font size" })
	end

	local modes = { "n", "i", "v", "t" }
	local opts = { noremap = true, silent = true }

	-- Zoom In (Ctrl + =, Ctrl + +, Ctrl + Shift + =, Ctrl + Shift + +, Numpad +, ScrollWheelUp)
	vim.keymap.set(modes, "<C-=>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-+>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-S-=>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-S-+>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-kPlus>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-KPPlus>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))
	vim.keymap.set(modes, "<C-ScrollWheelUp>", M.increase, vim.tbl_extend("force", opts, { desc = "Increase font size" }))

	-- Zoom Out (Ctrl + -, Ctrl + _, Ctrl + Shift + -, Ctrl + Shift + _, Numpad -, ScrollWheelDown)
	vim.keymap.set(modes, "<C-->", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-_>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-S-->", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-S-_>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-kMinus>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-KPMinus>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))
	vim.keymap.set(modes, "<C-ScrollWheelDown>", M.decrease, vim.tbl_extend("force", opts, { desc = "Decrease font size" }))

	-- Zoom Reset (Ctrl + 0, Numpad 0)
	vim.keymap.set(modes, "<C-0>", M.reset, vim.tbl_extend("force", opts, { desc = "Reset font size" }))
	vim.keymap.set(modes, "<C-k0>", M.reset, vim.tbl_extend("force", opts, { desc = "Reset font size" }))
	vim.keymap.set(modes, "<C-KP0>", M.reset, vim.tbl_extend("force", opts, { desc = "Reset font size" }))
end

-- Ensure setup runs on module load
M.setup()

_G.FontManager = M

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_font",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

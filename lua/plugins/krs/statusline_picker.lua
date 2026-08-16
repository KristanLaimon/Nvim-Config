-- ============================================================================
-- KRS PLUGIN: Statusline Theme Picker & NvChad Statusline Engine.
-- ============================================================================
-- WHAT IT DOES
--   Provides NvChad-style statusline layouts (pills, blocks, classic, minimal,
--   vscode) and an interactive theme picker command `:KrsStatuslineTheme`.
-- ============================================================================

local store = require("krs.core.store")

local M = {}

M.settings = {
	store_file = vim.fn.stdpath("config") .. "/.krsnvim/statusline.json",
	default_theme = "nvchad_pills",
}

M.available_themes = {
	nvchad_pills = "NvChad Pills (Rounded Statusline)",
	nvchad_blocks = "NvChad Blocks (Blocky Statusline)",
	nagatoro_classic = "Nagatoro Classic (Minimal & Clean)",
	vscode = "VSCode Modern (Flat Bar)",
	minimal = "Minimalist (Compact)",
}

--- Formats editor mode into NvChad style pill string.
--- @param mode_str string
--- @return string formatted
function M.format_mode(mode_str)
	local modes = {
		["NORMAL"] = " NORMAL",
		["INSERT"] = "󰏫 INSERT",
		["VISUAL"] = "󰈈 VISUAL",
		["V-LINE"] = "󰈈 V-LINE",
		["V-BLOCK"] = "󰈈 V-BLOCK",
		["SELECT"] = "󰈈 SELECT",
		["S-LINE"] = "󰈈 S-LINE",
		["S-BLOCK"] = "󰈈 S-BLOCK",
		["REPLACE"] = "󰛔 REPLACE",
		["V-REPLACE"] = "󰛔 V-REPLACE",
		["COMMAND"] = "󰘳 COMMAND",
		["EX"] = "󰘳 EX",
		["MORE"] = "󰘳 MORE",
		["CONFIRM"] = "󰘳 CONFIRM",
		["SHELL"] = "󰞷 SHELL",
		["TERMINAL"] = "󰞷 TERMINAL",
	}
	return modes[mode_str] or (" " .. mode_str)
end

--- Retrieves current statusline theme selection.
--- @return string theme_name
function M.get_current_theme()
	local data = store.load(M.settings.store_file, {})
	return data.theme or M.settings.default_theme
end

--- Generates Lualine options table for a given statusline theme.
--- @param theme_name string
--- @return table lualine_options
function M.get_lualine_config(theme_name)
	theme_name = theme_name or M.get_current_theme()

	if theme_name == "nvchad_blocks" then
		return {
			options = {
				theme = "auto",
				globalstatus = true,
				component_separators = { left = "|", right = "|" },
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = { { "mode", fmt = M.format_mode } },
				lualine_b = { { "branch", icon = "" }, "diff", "diagnostics" },
				lualine_c = { { "filename", file_status = true, path = 1 } },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { { "location", icon = "" } },
			},
		}
	elseif theme_name == "vscode" then
		return {
			options = {
				theme = "auto",
				globalstatus = true,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { { "branch", icon = "" }, "diagnostics" },
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		}
	elseif theme_name == "minimal" then
		return {
			options = {
				theme = "auto",
				globalstatus = true,
				component_separators = "",
				section_separators = "",
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { { "filename", path = 1 } },
				lualine_c = {},
				lualine_x = { "branch" },
				lualine_y = { "filetype" },
				lualine_z = { "location" },
			},
		}
	elseif theme_name == "nagatoro_classic" then
		return {
			options = {
				theme = "auto",
				globalstatus = true,
			},
			sections = {
				lualine_a = { { "branch", icon = "🌿" }, "diff", "diagnostics" },
				lualine_b = { { "filename", file_status = true, path = 1 } },
				lualine_c = {},
				lualine_x = {
					{
						"mode",
						fmt = function(str)
							return "-- " .. str .. " --"
						end,
					},
					"encoding",
					"fileformat",
					"filetype",
				},
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		}
	end

	-- Default: nvchad_pills
	return {
		options = {
			theme = "auto",
			globalstatus = true,
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
		},
		sections = {
			lualine_a = { { "mode", fmt = M.format_mode } },
			lualine_b = { { "branch", icon = "" }, "diff", "diagnostics" },
			lualine_c = { { "filename", file_status = true, path = 1 } },
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { { "location", icon = "" } },
		},
	}
end

--- Sets active statusline theme and applies configuration.
--- @param theme_name string
function M.set_theme(theme_name)
	if not M.available_themes[theme_name] then
		vim.notify("Unknown statusline theme: " .. tostring(theme_name), vim.log.levels.WARN)
		return
	end

	store.save(M.settings.store_file, { theme = theme_name })
	local has_lualine, lualine = pcall(require, "lualine")
	if has_lualine then
		lualine.setup(M.get_lualine_config(theme_name))
	end
	vim.notify("Statusline theme set to: " .. M.available_themes[theme_name], vim.log.levels.INFO)
end

--- Opens interactive statusline theme picker.
function M.open_picker()
	local items = {}
	local keys = {}
	for k, label in pairs(M.available_themes) do
		table.insert(keys, k)
		table.insert(items, label .. " (" .. k .. ")")
	end

	vim.ui.select(items, { prompt = "Select Statusline Theme:" }, function(choice, index)
		if choice and index then
			M.set_theme(keys[index])
		end
	end)
end

function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	vim.api.nvim_create_user_command("KrsStatuslineTheme", function(opts)
		if opts.args and opts.args ~= "" then
			M.set_theme(opts.args)
		else
			M.open_picker()
		end
	end, {
		nargs = "?",
		complete = function()
			local names = {}
			for k in pairs(M.available_themes) do
				table.insert(names, k)
			end
			return names
		end,
		desc = "Pick or set statusline theme",
	})
end

-- LAZY.NVIM SPEC
local plugin_spec = {
	name = "krs_statusline_picker",
	dir = require("krs.core.lazyspec").for_module(),
	cmd = "KrsStatuslineTheme",
	config = M.setup,
}

return setmetatable(plugin_spec, { __index = M })

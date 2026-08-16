-- ============================================================================
-- KRS PLUGIN: Command Palette (Ctrl + Shift + P).
-- ============================================================================
-- WHAT IT DOES
--   A fuzzy picker over every command this config exposes, reachable from any
--   mode. The list below IS the configuration -- add entries to `M.commands`.
--
-- ENTRY SHAPE -- exactly one action per entry
--   { name = "Label shown in the list",
--     category = "Files",          -- grouping prefix, also fuzzy-searchable
--     cmd  = "Neotree toggle",     -- a) run an Ex command
--     keys = "<C-k>",              -- b) feed keys, as if typed
--     fn   = function() end }      -- c) call Lua directly
--
-- FROM ANOTHER MODULE
--   require("plugins.krs.command_palette").add_command({ name = ..., cmd = ... })
-- ============================================================================

local store = require("krs.core.store")

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.settings = {
	--- Picker geometry and titles.
	picker_width = 0.75,
	prompt_title = " 🚀🦊 Command Palette (Ctrl+Shift+P) ",
	results_title = "Available Commands",

	--- Path to global history store for MRU ordering.
	history_file = vim.fn.stdpath("data") .. "/command_palette_history.json",
	--- Maximum number of entries remembered in global history.
	max_history = 100,

	keys = {
		--- Open the palette. Bound in normal, insert, visual and terminal mode.
		open = { "<C-S-p>", "<C-S-P>" },
	},
}

--- Everything the palette offers, in display order. EDIT THIS LIST.
--- @type table[]
M.commands = {
	-- --------------------------------------------------------------------------
	-- 📁 Files & Search
	-- --------------------------------------------------------------------------
	{ name = "🔍 Find Files (ignoring .gitignore)", cmd = "TelescopeFindFilesNoIgnore", category = "Files" },
	{ name = "📂 Open Project Root in File Explorer", cmd = "OpenRootInExplorer", category = "Files" },
	{ name = "🐧 Browse WSL Files", cmd = "TelescopeFileBrowserWSL", category = "Files" },

	-- --------------------------------------------------------------------------
	-- 🦊 Workspaces & Sessions
	-- --------------------------------------------------------------------------
	{ name = "💼 Select Workspace (Workspaces UI)", cmd = "WorkspaceSelect", category = "Workspace" },
	{ name = "💾 Save Current Workspace", cmd = "WorkspaceSave", category = "Workspace" },
	{ name = "🚪 Close Workspace & Go to Main Menu", cmd = "WorkspaceClose", category = "Workspace" },

	-- --------------------------------------------------------------------------
	-- 🌲 File Explorer & Git
	-- --------------------------------------------------------------------------
	{ name = "🌳 Toggle File Explorer (Neo-tree)", cmd = "Neotree toggle", category = "Explorer" },
	{ name = "🐙 Toggle Git Center (Ctrl+Shift+G)", cmd = "GitCenterToggle", category = "Git" },
	{
		name = "🎨 Toggle Git Center Colored Tab Indicators (Default: Plain Text)",
		cmd = "GitCenterToggleTabColors",
		category = "Git",
	},
	{ name = "🐙 Toggle Git Panel (Neogit)", cmd = "Neogit", category = "Git" },

	-- --------------------------------------------------------------------------
	-- 🧠 LSP, Diagnostics & Type Injection
	-- --------------------------------------------------------------------------
	{
		name = "👁️ Toggle LSP Reference Counts / CodeLens (Default: ON)",
		cmd = "KrsToggleReferences",
		category = "LSP",
	},
	{ name = "💉 Modular Type Injector (Lua & TS/JS)", cmd = "TypeInjector", category = "LSP" },
	{ name = "🚫 Add .krsnvim Ignore to .gitignore", cmd = "KrsGitignoreGenerated", category = "LSP" },
	{ name = "ℹ️ LSP Server Information", cmd = "LspInfo", category = "LSP" },
	{ name = "📦 Server & Package Manager (Mason)", cmd = "Mason", category = "LSP" },
	{ name = "📦 Nuget Package Manager (C#)", cmd = "NugetManager", category = "LSP" },

	-- --------------------------------------------------------------------------
	-- 🎨 UI & Configuration
	-- --------------------------------------------------------------------------
	{ name = "📚 Open Documentation Center & Wiki (Ctrl+Shift+D)", cmd = "KrsWiki", category = "UI" },
	{ name = "🎨 Open Nagatoro & NvChad Theme Picker", cmd = "KrsThemePicker", category = "UI" },
	{
		name = "📊 Open Statusline Theme Picker (NvChad Pills, Blocks, etc.)",
		cmd = "KrsStatuslineTheme",
		category = "UI",
	},
	{ name = "🎨 Toggle UI Icons Mode (Nerd Font Symbols vs Emojis)", cmd = "ToggleIconsMode", category = "UI" },
	{ name = "🔍 Increase Font Size", cmd = "FontSizeIncrease", category = "UI" },
	{ name = "🔍 Decrease Font Size", cmd = "FontSizeDecrease", category = "UI" },
	{ name = "🔍 Reset Font Size", cmd = "FontSizeReset", category = "UI" },
	{ name = "🧩 Plugin Manager (Lazy)", cmd = "Lazy", category = "Config" },
	{ name = "🔄 Reload Neovim Configuration", cmd = "ReloadConfig", category = "Config" },
	{ name = "🚪 Quit Neovim (Quit All)", cmd = "qa", category = "System" },

	-- --------------------------------------------------------------------------
	-- 🎨 Discord Rich Presence (cord.nvim)
	-- --------------------------------------------------------------------------
	{ name = "🎮 Discord: Toggle", cmd = "Cord toggle", category = "Discord" },
	{ name = "🎮 Discord: Reconnect", cmd = "Cord reconnect", category = "Discord" },
	{ name = "🎮 Discord: Shutdown", cmd = "Cord shutdown", category = "Discord" },
	{ name = "🎮 Discord: Status", cmd = "Cord status", category = "Discord" },
	{ name = "🎮 Discord: Restart Plugin", cmd = "CordReload", category = "Discord" },

	-- --------------------------------------------------------------------------
	-- 🎨 Tailwind Classes Organizer
	-- --------------------------------------------------------------------------
	{
		name = "🎨 Toggle Tailwind Organizer (Auto-Format on Save)",
		cmd = "TailwindOrganizerToggle",
		category = "Tailwind",
	},
	{ name = "✨ Organize Tailwind Classes (Current File)", cmd = "TailwindOrganize", category = "Tailwind" },
	{ name = "ℹ️ Tailwind Organizer Status", cmd = "TailwindOrganizerStatus", category = "Tailwind" },

	-- --------------------------------------------------------------------------
	-- 🐞 Debugging & Breakpoints
	-- --------------------------------------------------------------------------
	{ name = "🐾 Enable/Disable Breakpoint (Cursor)", cmd = "DapBreakpointToggleEnabled", category = "Debug" },
	{ name = "✅ Enable All Breakpoints", cmd = "DapBreakpointsEnableAll", category = "Debug" },
	{ name = "🚫 Disable All Breakpoints (Keep Them)", cmd = "DapBreakpointsDisableAll", category = "Debug" },
	{ name = "🗑️ Remove All Breakpoints", cmd = "DapBreakpointsRemoveAll", category = "Debug" },

	-- --------------------------------------------------------------------------
	-- 🛠️ Tasks & Code Execution
	-- --------------------------------------------------------------------------
	{ name = "🔄 Restart Current Task (Kill & Rerun)", cmd = "TaskRestart", category = "Tasks" },
	{ name = "🛑 Stop / Kill Current Task", cmd = "TaskKill", category = "Tasks" },
	{ name = "⚡ Run Default Project Task", cmd = "TaskRunDefault", category = "Tasks" },
	{ name = "🛠️ Open Project Task Menu", cmd = "TaskMenu", category = "Tasks" },

	-- --------------------------------------------------------------------------
	-- 🦊 krsnvimtranspiler (Script Transpiler)
	-- --------------------------------------------------------------------------
	{
		name = "🦊 Transpile Selected .krsnvim Script (Both .sh & .ps1)",
		cmd = "KrsTranspileBoth",
		category = "Transpiler",
	},
	{ name = "🐧 Transpile Selected .krsnvim Script to Bash (.sh)", cmd = "KrsTranspileSh", category = "Transpiler" },
	{
		name = "🪟 Transpile Selected .krsnvim Script to PowerShell (.ps1)",
		cmd = "KrsTranspilePs1",
		category = "Transpiler",
	},
	{ name = "🔄 Transpile Active / Neo-tree .krsnvim File", cmd = "KrsTranspile", category = "Transpiler" },
	{ name = "🚀 Open Launch Profiles Manager (<C-S-q>)", cmd = "LaunchProfiles", category = "Transpiler" },
}

-- ============================================================================
-- API & HISTORY
-- ============================================================================

--- Appends an entry at runtime, so other modules can contribute commands.
--- @param item table Entry in the shape documented at the top of this file.
function M.add_command(item)
	if type(item) == "table" and item.name then
		table.insert(M.commands, item)
	end
end

--- Loads the recent command execution history.
--- @return string[] Array of command names in MRU order (most recent first).
function M.load_history()
	local path = M.settings.history_file
	if not path or path == "" then
		return {}
	end
	local data = store.load(path, { history = {} })
	if type(data) == "table" and type(data.history) == "table" then
		return data.history
	end
	return {}
end

--- Saves the command execution history to persistent storage.
--- @param history string[] Array of command names.
--- @return boolean ok
--- @return string|nil err
function M.save_history(history)
	local path = M.settings.history_file
	if not path or path == "" then
		return false, "No history_file configured"
	end
	return store.save(path, { history = history })
end

--- Records a command execution, moving it to the top of MRU history.
--- @param name string Command name identifier.
function M.record_command_use(name)
	if not name or name == "" then
		return
	end

	local history = M.load_history()
	local new_history = { name }
	local max_len = M.settings.max_history or 100

	for _, item_name in ipairs(history) do
		if item_name ~= name and #new_history < max_len then
			table.insert(new_history, item_name)
		end
	end

	M.save_history(new_history)
end

--- Clears the stored command execution history.
function M.clear_history()
	M.save_history({})
end

--- Returns `M.commands` sorted by MRU history recency (most recent first),
--- with unvisited commands retaining their original relative declaration order.
--- @return table[] Array of palette command entries.
function M.get_sorted_commands()
	local history = M.load_history()
	local rank_map = {}
	for idx, name in ipairs(history) do
		if not rank_map[name] then
			rank_map[name] = idx
		end
	end

	local items = {}
	for idx, cmd in ipairs(M.commands) do
		local rank = (cmd.name and rank_map[cmd.name]) or (100000 + idx)
		table.insert(items, {
			cmd = cmd,
			orig_idx = idx,
			rank = rank,
		})
	end

	table.sort(items, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.orig_idx < b.orig_idx
	end)

	local sorted = {}
	for _, item in ipairs(items) do
		table.insert(sorted, item.cmd)
	end
	return sorted
end

--- Runs the action of an entry: Ex command, simulated keys, or Lua function.
--- Also records its usage in history so recent commands move to top.
--- @param item table|nil Palette entry.
function M.execute_item(item)
	if not item then
		return
	end

	if item.name then
		M.record_command_use(item.name)
	end

	if item.cmd then
		-- Execute Neovim/Vimscript command
		vim.cmd(item.cmd)
	elseif item.keys then
		-- Simulate keypress using nvim_feedkeys
		local termcodes = vim.api.nvim_replace_termcodes(item.keys, true, false, true)
		vim.api.nvim_feedkeys(termcodes, "m", false)
	elseif item.fn and type(item.fn) == "function" then
		-- Execute Lua function directly
		item.fn()
	end
end

local execute_item = M.execute_item

--- Opens the palette picker.
function M.open_palette()
	if not pcall(require, "telescope") then
		vim.notify("Telescope is not available for Command Palette", vim.log.levels.ERROR, { title = "Command Palette" })
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local themes = require("telescope.themes")

	pickers
		.new(
			themes.get_dropdown({
				prompt_title = M.settings.prompt_title,
				width = M.settings.picker_width,
				results_title = M.settings.results_title,
			}),
			{
				finder = finders.new_table({
					results = M.get_sorted_commands(),
					entry_maker = function(entry)
						local category = entry.category or "General"
						local shortcut = entry.keys or entry.cmd or ""
						local display_str =
							string.format("[%s] %s %s", category, entry.name, shortcut ~= "" and ("(" .. shortcut .. ")") or "")

						return {
							value = entry,
							display = display_str,
							-- Ordinal for fuzzy search
							ordinal = category .. " " .. entry.name .. " " .. shortcut,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection and selection.value then
							vim.schedule(function()
								M.execute_item(selection.value)
							end)
						end
					end)
					return true
				end,
			}
		)
		:find()
end

-- ============================================================================
-- SETUP
-- ============================================================================

--- Registers `:CommandPalette` and the open keys.
function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	if vim.fn.exists(":CommandPalette") == 0 then
		vim.api.nvim_create_user_command("CommandPalette", function()
			M.open_palette()
		end, { desc = "Open Command Palette" })
	end

	for _, key in ipairs(M.settings.keys.open) do
		vim.keymap.set({ "n", "i", "v", "t" }, key, function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_palette()
		end, { noremap = true, silent = true, desc = "Open Command Palette" })
	end
end

-- Legacy global kept for user scripts and older keybinds that reference it.
_G.CommandPalette = M

-- ============================================================================
-- LAZY.NVIM SPEC
-- ============================================================================

return setmetatable({
	name = "krs_command_palette",
	dir = require("krs.core.lazyspec").for_module(),
	cmd = "CommandPalette",
	keys = { { "<C-S-p>", mode = { "n", "i", "v", "t" }, desc = "Open Command Palette" } },
	dependencies = { "nvim-telescope/telescope.nvim" },
	config = M.setup,
}, { __index = M })

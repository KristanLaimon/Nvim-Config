-- ============================================================================
-- 🦊 KRS PLUGIN: VSCode-Style Command Palette (Ctrl + Shift + P)
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Activated with <Ctrl+Shift+P> from any mode (Normal, Insert, Visual, Terminal).
-- 2. Presents a Telescope picker with fuzzy search.
-- 3. Uses a configurable array (`M.commands`) supporting 3 action types:
--      a) `cmd`: Executes a Neovim/Vimscript command (e.g. "Telescope find_files", "Lazy", "Mason")
--      b) `keys`: Simulates keypresses (e.g. "<C-k>", "<leader>e", "<F2>")
--      c) `fn`: Executes a custom Lua function directly.
-- 4. You can add your own commands at runtime using `M.add_command({ ... })`.
-- ============================================================================

local M = {}

-- Array of user-configurable commands
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
	{ name = "🐙 Toggle Git Panel (Neogit)", cmd = "Neogit", category = "Git" },

	-- --------------------------------------------------------------------------
	-- 🧠 LSP, Diagnostics & Type Injection
	-- --------------------------------------------------------------------------
	{ name = "💉 Modular Type Injector (Lua & TS/JS)", cmd = "TypeInjector", category = "LSP" },
	{ name = "🚫 Add KRS Generated Files to .gitignore", cmd = "KrsGitignoreGenerated", category = "LSP" },
	{ name = "ℹ️ LSP Server Information", cmd = "LspInfo", category = "LSP" },
	{ name = "📦 Server & Package Manager (Mason)", cmd = "Mason", category = "LSP" },
	{ name = "📦 Nuget Package Manager (C#)", cmd = "NugetManager", category = "LSP" },

	-- --------------------------------------------------------------------------
	-- 🎨 UI & Configuration
	-- --------------------------------------------------------------------------
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

	-- --------------------------------------------------------------------------
	-- 🎨 Tailwind Classes Organizer
	-- --------------------------------------------------------------------------
	{ name = "🎨 Toggle Tailwind Organizer (Auto-Format on Save)", cmd = "TailwindOrganizerToggle", category = "Tailwind" },
	{ name = "✨ Organize Tailwind Classes (Current File)", cmd = "TailwindOrganize", category = "Tailwind" },
	{ name = "ℹ️ Tailwind Organizer Status", cmd = "TailwindOrganizerStatus", category = "Tailwind" },
}

-- Public function to dynamically add commands from any plugin or config
function M.add_command(item)
	if type(item) == "table" and item.name then
		table.insert(M.commands, item)
	end
end

-- Execute action associated with selected entry
local function execute_item(item)
	if not item then
		return
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

-- Open Command Palette with Telescope
function M.open_palette()
	local ok_telescope, _ = pcall(require, "telescope")
	if not ok_telescope then
		vim.notify(
			"Telescope is not available for Command Palette",
			vim.log.levels.ERROR,
			{ title = "Command Palette" }
		)
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
				prompt_title = " 🚀🦊 Command Palette (Ctrl+Shift+P) ",
				width = 0.75,
				results_title = "Available Commands",
			}),
			{
				finder = finders.new_table({
					results = M.commands,
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
								execute_item(selection.value)
							end)
						end
					end)
					return true
				end,
			}
		)
		:find()
end

_G.CommandPalette = M

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "command_palette",
	dir = vim.fn.stdpath("config"),
	cmd = "CommandPalette",
	keys = {
		{
			"<C-S-p>",
			function()
				M.open_palette()
			end,
			mode = { "n", "i", "v", "t" },
			desc = "Command Palette",
		},
		{
			"<C-S-P>",
			function()
				M.open_palette()
			end,
			mode = { "n", "i", "v", "t" },
			desc = "Command Palette",
		},
	},
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		vim.api.nvim_create_user_command("CommandPalette", function()
			M.open_palette()
		end, { desc = "Open Command Palette" })

		-- Global keymaps
		local modes = { "n", "i", "v", "t" }
		vim.keymap.set(modes, "<C-S-p>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_palette()
		end, { noremap = true, silent = true, desc = "Open Command Palette" })

		vim.keymap.set(modes, "<C-S-P>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_palette()
		end, { noremap = true, silent = true, desc = "Open Command Palette" })
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})


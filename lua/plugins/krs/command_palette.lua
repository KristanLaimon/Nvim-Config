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
	{ name = "🔍 Find Files (respecting .gitignore)", keys = "<C-k>", category = "Files" },
	{ name = "🔍 Find Files (ignoring .gitignore)", cmd = "TelescopeFindFilesNoIgnore", category = "Files" },
	{ name = "🔍 Find & Open File Left (Split Left)", keys = "<C-S-h>", category = "Files" },
	{ name = "🔍 Find & Open File Down (Split Down)", keys = "<C-S-j>", category = "Files" },
	{ name = "🔍 Find & Open File Up (Split Up)", keys = "<C-S-k>", category = "Files" },
	{ name = "🔍 Find & Open File Right (Split Right)", keys = "<C-S-l>", category = "Files" },
	{ name = "📝 Search Text in Files (Live Grep)", keys = "<C-f>", category = "Files" },
	{ name = "📂 Open Folder", keys = "<C-S-o>", category = "Files" },
	{ name = "⭐ Recent Projects", keys = "<C-S-r>", category = "Files" },
	{ name = "📁 Floating Desktop File Explorer", keys = "<C-S-f>", category = "Files" },
	{ name = "🖥️ Toggle Selected Terminal", keys = "<C-;>", category = "Terminal" },

	-- --------------------------------------------------------------------------
	-- 🦊 Workspaces & Sessions
	-- --------------------------------------------------------------------------
	{ name = "💼 Select Workspace (Workspaces UI)", cmd = "WorkspaceSelect", category = "Workspace" },
	{ name = "💾 Save Current Workspace", cmd = "WorkspaceSave", category = "Workspace" },
	{ name = "🚪 Close Workspace & Go to Main Menu", cmd = "WorkspaceClose", category = "Workspace" },

	-- --------------------------------------------------------------------------
	-- 🛠️ Tasks & Code Execution (IntelliJ Style)
	-- --------------------------------------------------------------------------
	{ name = "🚀 [Play] IntelliJ Run Menu", keys = "<leader>rp", category = "Tasks" },
	{ name = "🐞 [Debug] IntelliJ Debug Menu", keys = "<leader>rd", category = "Tasks" },
	{ name = "⚙️ [Profiles] IntelliJ Profiles & Tasks Menu", keys = "<leader>rc", category = "Tasks" },
	{ name = "🚀 Toggle IntelliJ Top-Right Toolbar", cmd = "IntelliJToolbarToggle", category = "UI" },
	{ name = "🚀 Run Project Default Task", keys = "<C-S-a>", category = "Tasks" },
	{ name = "🛠️ Open Project Tasks Menu", keys = "<leader>ta", category = "Tasks" },

	-- --------------------------------------------------------------------------
	-- 🌲 File Explorer & Git
	-- --------------------------------------------------------------------------
	{ name = "🌳 Toggle File Explorer (Neo-tree)", cmd = "Neotree toggle", category = "Explorer" },
	{ name = "🏷️ Rename Current File (F2)", keys = "<F2>", category = "Explorer" },
	{ name = "🐙 Toggle Git Panel (Neogit)", cmd = "Neogit", category = "Git" },

	-- --------------------------------------------------------------------------
	-- 💻 Terminals
	-- --------------------------------------------------------------------------
	{ name = "💻 Toggle Terminal 1", keys = "<C-;>", category = "Terminal" },
	{ name = "💻 Toggle Terminal 2", keys = "<leader>t2", category = "Terminal" },
	{ name = "💻 Toggle Terminal 3", keys = "<leader>t3", category = "Terminal" },

	-- --------------------------------------------------------------------------
	-- 🧠 LSP, Diagnostics & Formatting
	-- --------------------------------------------------------------------------
	{ name = "💡 Quick-Fix / Code Actions (VSCode)", keys = "<C-.>", category = "LSP" },
	{ name = "🎯 Go to Symbol Definition", keys = "<A-j>", category = "LSP" },
	{ name = "⚠️ View Error / Diagnostic Detail at Caret", keys = "<A-k>", category = "LSP" },
	{ name = "🎨 Format File (Conform)", keys = "<leader>f", category = "LSP" },
	{ name = "ℹ️ LSP Server Information", cmd = "LspInfo", category = "LSP" },
	{ name = "📦 Server & Package Manager (Mason)", cmd = "Mason", category = "LSP" },

	-- --------------------------------------------------------------------------
	-- 🎨 UI & Configuration
	-- --------------------------------------------------------------------------
	{ name = "🔍 Increase Font Size", cmd = "FontSizeIncrease", category = "UI" },
	{ name = "🔍 Decrease Font Size", cmd = "FontSizeDecrease", category = "UI" },
	{ name = "🔍 Reset Font Size", cmd = "FontSizeReset", category = "UI" },
	{ name = "🖼️ View Image with Chafa", keys = "<leader>i", category = "UI" },
	{ name = "🎬 Open Image/Video with OS Default Program", keys = "<C-S-Enter>", category = "UI" },
	{ name = "🧩 Plugin Manager (Lazy)", cmd = "Lazy", category = "Config" },
	{ name = "🔄 Reload Neovim Configuration", cmd = "ReloadConfig", category = "Config" },
	{ name = "🚪 Quit Neovim (Quit All)", cmd = "qa", category = "System" },
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


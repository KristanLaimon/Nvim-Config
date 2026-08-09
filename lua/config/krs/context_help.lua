-- ============================================================================
-- 🦊 KRS CONFIG: Ultra-Clean Context-Aware Help System
-- ============================================================================
-- 1. Automatically detects context (Neo-Tree, Git, File Explorer, Editor).
-- 2. Pressing '?' or <F1> displays a minimal 4-5 line notification
--    with ONLY key essential shortcuts. Zero noise, zero fluff.
-- ============================================================================

local M = {}

-- Detect current context based on filetype and buffer name
function M.get_context()
	local ft = vim.bo.filetype
	local buf_name = vim.api.nvim_buf_get_name(0)

	if ft == "neo-tree" then
		return "neotree"
	elseif ft:find("Neogit") or ft:find("Diffview") or ft:find("git") or buf_name:find("Git") then
		return "git"
	elseif ft == "TelescopePrompt" or ft == "TaskRunner" or buf_name:find("Telescope") or buf_name:find("project_tasks") then
		return "telescope"
	else
		return "editor"
	end
end

-- Show minimal notification help
function M.show_help()
	local context = M.get_context()
	local title = ""
	local help_lines = {}

	if context == "neotree" then
		title = "🌳 Neo-Tree (Explorer)"
		help_lines = {
			"a : Create File     | A : Create Folder",
			"r : Rename          | d : Delete",
			"c : Copy            | x : Cut | p : Paste",
			"Ctrl + Shift + Enter/Space : Reveal selected file/folder in System Explorer",
			"q : Close explorer",
		}
	elseif context == "git" then
		title = "🦊 Git Center"
		help_lines = {
			"1..4: Jump to Section 1, 2, 3, or 4",
			"Ctrl+Shift+J/K: Scroll right preview panel",
			"s/S : Stage File / Stage All",
			"u/U : Unstage File / Unstage All",
			"c : Edit Commit Title | C : Commit & Tag",
			"Tab: Toggle focus between list and preview",
			"d : View Diffview | q : Close panel",
		}
	elseif context == "telescope" then
		title = "📁 File Explorer"
		help_lines = {
			"a : Create (file.txt or folder/)",
			"r : Rename          | d : Delete",
			"c : Copy            | m : Move / Cut",
			"o : Open Folder as Active Project (CWD)",
			"Tab: Multi-select items",
		}
	else
		title = "⚡ Key Editor Shortcuts"
		help_lines = {
			"Ctrl + K        : Find File by Name",
			"Ctrl + Shift + H/J/K/L : Find File & Open in Split (← ↓ ↑ →)",
			"Ctrl + F        : Live Grep Text in Project",
			"Ctrl + Shift + F: Floating Desktop Explorer",
			"Ctrl + Shift + T: Project Task Menu",
			"Ctrl + Shift + Enter: Open Media (Image/Video) with OS Default App",
			"Alt + 1..9      : Terminal 1 to 9  |  Ctrl + ; : Toggle Terminal",
		}
	end

	local msg = table.concat(help_lines, "\n")
	vim.notify(msg, vim.log.levels.INFO, { title = title })
end

function M.setup()
	vim.keymap.set("n", "?", function()
		M.show_help()
	end, { noremap = true, silent = true, desc = "Context Help" })

	vim.keymap.set("n", "<F1>", function()
		M.show_help()
	end, { noremap = true, silent = true, desc = "Context Help" })
end

return M


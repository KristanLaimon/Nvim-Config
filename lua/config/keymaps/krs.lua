-- ============================================================================
-- KEYMAPS: KRS features -- tasks, launch profiles, git, explorer, scripts.
-- ============================================================================
-- KEYS
--   <C-S-t>       Task menu               <C-S-a>  Run default task
--   <C-1>..<C-4>  Toggle task output 1-4  <C-`>    Toggle last task output
--   <C-S-s>       Smart launch            <C-S-q>  Launch profiles manager
--   <C-S-x>/<A-s> Stage everything (git)
--   <C-S-f>       Floating desktop explorer    <leader>fw  WSL explorer
--   <C-,>         Run the current .krsnvim script
--   <C-S-,>       Open the krsnvimscript wiki
--
-- COMMANDS
--   :KrsExport [sh|ps1] / :KrsExportSh / :KrsExportPs1
--     Transpile the current .krsnvim script to a shell script.
--
-- WHY THE KEYS ARE DUPLICATED HERE AND IN THE PLUGINS
--   Each plugin binds its own keys in `setup()` so it works standalone; these
--   bindings guarantee the key exists even before that plugin has loaded, and
--   they are identical, so whichever wins behaves the same.
-- ============================================================================

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.settings = {
	keys = {
		--- Stage every unstaged and untracked change. Many aliases because Alt and
		--- Meta combinations arrive differently per terminal and GUI.
		git_center = { "<C-S-g>", "<C-S-G>", "<C-g>", "<C-G>" },
		git_stage_all = {
			"<C-S-x>", "<C-S-X>",
			"<C-A-s>", "<C-A-S>", "<C-M-s>", "<C-M-S>",
			"<A-C-s>", "<A-C-S>", "<M-C-s>", "<M-C-S>",
			"<A-s>", "<A-S>", "<M-s>", "<M-S>",
		},
		smart_launch = { "<C-S-s>", "<C-S-S>" },
		launch_profiles = { "<C-S-q>", "<C-S-Q>" },
		task_menu = { "<C-S-t>", "<C-S-T>" },
		task_menu_leader = "<leader>ta",
		run_default_task = { "<C-S-a>", "<C-S-A>" },
		--- Toggle the most recent task output. `<C-i>` is omitted because it shares
		--- the same keycode as <Tab>, which breaks code indentation in buffers.
		toggle_last_output = { "<C-`>" },
		toggle_last_output_no_terminal = {},
		--- Prefix for per-slot task output toggles; the slot number is appended.
		task_slot_prefix = "<C-",
		explorer = "<C-S-f>",
		wsl_explorer = "<leader>fw",
		--- Run the current .krsnvim script.
		run_script = { "<C-,>", "<C-comma>" },
		--- Open the krsnvimscript wiki.
		wiki = { "<C-S-,>", "<C-S-comma>", "<C-?>" },
	},

	--- How many task output slots have a direct toggle.
	task_slots = 4,
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function opts(desc)
	return { noremap = true, silent = true, desc = desc }
end

--- Wraps a handler so it also works from terminal mode.
--- @param fn function
--- @return function
local function from_any_mode(fn)
	return function()
		if vim.fn.mode() == "t" then
			pcall(vim.cmd, "stopinsert")
		end
		fn()
	end
end

--- Binds one handler to several keys, in normal, insert, visual and terminal mode.
--- @param keys string[] Key list.
--- @param fn function Handler; wrapped with `from_any_mode`.
--- @param desc string Description.
local function map_all_modes(keys, fn, desc)
	for _, key in ipairs(keys) do
		vim.keymap.set({ "n", "i", "v", "t" }, key, from_any_mode(fn), opts(desc))
	end
end

-- ============================================================================
-- GIT, LAUNCH PROFILES, TASKS
-- ============================================================================

map_all_modes(M.settings.keys.git_center, function()
	require("plugins.krs.git_center").toggle_git_center()
end, "Toggle Git Control Center")

map_all_modes(M.settings.keys.git_stage_all, function()
	require("plugins.krs.git_center").stage_all_with_modal()
end, "Stage all unstaged changes in git (Modal Confirmation)")

map_all_modes(M.settings.keys.smart_launch, function()
	require("plugins.krs.launch_profiles").handle_smart_launch()
end, "Smart Launch / Profile Debug UI")

map_all_modes(M.settings.keys.launch_profiles, function()
	require("plugins.krs.launch_profiles").open_management_menu()
end, "Open Launch Profiles Management UI")

map_all_modes(M.settings.keys.task_menu, function()
	require("plugins.krs.tasks").open_task_menu()
end, "Open Project Task Menu")

map_all_modes(M.settings.keys.run_default_task, function()
	require("plugins.krs.tasks").run_default_or_menu()
end, "Run default task or kill & rerun running task")

vim.keymap.set("n", M.settings.keys.task_menu_leader, function()
	require("plugins.krs.tasks").open_task_menu()
end, opts("Open Project Task Menu"))

-- Long-running task outputs (`bun run dev` and friends). A slot key does nothing
-- when that slot is empty.
for slot = 1, M.settings.task_slots do
	vim.keymap.set({ "n", "i", "v", "t" }, M.settings.keys.task_slot_prefix .. slot .. ">", function()
		require("plugins.krs.tasks").toggle_slot_window(slot)
	end, opts("Toggle task output slot " .. slot))
end

map_all_modes(M.settings.keys.toggle_last_output, function()
	require("plugins.krs.tasks").toggle_last_slot_window()
end, "Toggle last task output window")

for _, key in ipairs(M.settings.keys.toggle_last_output_no_terminal) do
	vim.keymap.set({ "n", "i", "v" }, key, function()
		require("plugins.krs.tasks").toggle_last_slot_window()
	end, opts("Toggle last task output window"))
end

-- ============================================================================
-- EXPLORERS
-- ============================================================================

vim.keymap.set({ "n", "i", "v" }, M.settings.keys.explorer, function()
	require("plugins.krs.file_explorer").open_desktop_explorer()
end, opts("Open Floating Desktop File Explorer"))

vim.keymap.set({ "n", "i", "v" }, M.settings.keys.wsl_explorer, function()
	require("plugins.krs.file_explorer").open_wsl_explorer()
end, opts("Open Floating WSL File Explorer"))

-- ============================================================================
-- KRSNVIMSCRIPT
-- ============================================================================

map_all_modes(M.settings.keys.run_script, function()
	local buf_name = vim.api.nvim_buf_get_name(0)

	-- Outside a script, the same key opens the launch profiles instead, so it
	-- always means "run this project".
	if not (buf_name:match("%.krsnvim$") or vim.bo.filetype == "krsnvim") then
		require("plugins.krs.launch_profiles").open_management_menu()
		return
	end

	vim.cmd("silent! write")
	local relative = vim.fn.fnamemodify(buf_name, ":.")
	local cmd = 'nvim --headless -c "lua require[[krsnvim]].setup_globals()" -l ' .. vim.fn.shellescape(relative)
	require("plugins.krs.tasks").run_custom_command(cmd, nil, nil, vim.fn.fnamemodify(buf_name, ":t"))
end, "Run current .krsnvim file with krsnvimscript")

map_all_modes(M.settings.keys.wiki, function()
	require("krsnvim").wiki.open()
end, "Open krsnvimscript Floating Wiki Documentation")

-- ============================================================================
-- TRANSPILER COMMANDS
-- ============================================================================

--- The `.krsnvim` file to transpile: the current buffer when it is one, else the
--- first listed one. These commands often run from the command palette, after
--- focus has passed through neo-tree or telescope.
---
--- @return string|nil path
local function script_buffer_name()
	local buf_name = vim.api.nvim_buf_get_name(0)
	if buf_name:match("%.krsnvim$") and vim.fn.filereadable(buf_name) == 1 then
		return buf_name
	end

	for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if buf.name:match("%.krsnvim$") and vim.fn.filereadable(buf.name) == 1 then
			return buf.name
		end
	end
	return nil
end

--- Runs a transpiler export against the resolved script.
--- @param exporter fun(path: string, ...) Export function from krsnvimtranspiler.
--- @param ... any Extra arguments, e.g. an output path.
local function export(exporter, ...)
	local buf_name = script_buffer_name()
	if not buf_name then
		vim.notify("KrsExport: no .krsnvim file found to transpile", vim.log.levels.ERROR, {
			title = "krsnvimtranspiler",
		})
		return
	end
	exporter(buf_name, ...)
end

vim.api.nvim_create_user_command("KrsExport", function(command)
	local transpiler = require("krsnvim").krsnvimtranspiler
	local target = command.fargs[1] or "both"

	if target == "sh" then
		export(transpiler.export_sh, command.fargs[2])
	elseif target == "ps1" then
		export(transpiler.export_ps1, command.fargs[2])
	else
		export(transpiler.export_both)
	end
end, { nargs = "*", desc = "Export current .krsnvim script to .sh and .ps1 equivalents" })

vim.api.nvim_create_user_command("KrsExportSh", function(command)
	export(require("krsnvim").krsnvimtranspiler.export_sh, command.args ~= "" and command.args or nil)
end, { nargs = "?", desc = "Export current .krsnvim script to .sh (Bash)" })

vim.api.nvim_create_user_command("KrsExportPs1", function(command)
	export(require("krsnvim").krsnvimtranspiler.export_ps1, command.args ~= "" and command.args or nil)
end, { nargs = "?", desc = "Export current .krsnvim script to .ps1 (PowerShell)" })

return M

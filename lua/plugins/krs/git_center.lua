-- ============================================================================
-- 🦊 KRS PLUGIN: Centro de Control de Git Interactivo (Ctrl + Shift + G)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Alternable Garantizado (Toggle / Untoggle):
--      - Presiona <Ctrl+Shift+G> para abrir o cerrar el panel en cualquier momento.
-- 2. Edición Nativa en Vim para Commit & Tag:
--      - Presiona [c] (Title), [m] (Description) o [t] (Tag) para abrir un editor de buffer nativo de Vim.
-- 3. Refresco In-Place Sin Parpadeo (Zero Flicker):
--      - Las actualizaciones de estado (stage, unstage, commit, tag) actualizan el contenido del buffer in-place sin cerrar ni reabrir las ventanas flotantes.
-- 4. Acciones Globales del Panel:
--      - [S] (Shift + s) -> Stage All (Todos los archivos)
--      - [U] (Shift + u) -> Unstage All (Todos los archivos)
--      - [s] -> Stage Seleccionado / [v+s] -> Stage Multi-Selección
--      - [u] -> Unstage Seleccionado / [v+u] -> Unstage Multi-Selección
-- 5. Rendimiento Optimizado (Debounced Preview 40ms & Memoria Caché Lua).
-- 6. Títulos de Secciones en Inglés.
-- ============================================================================

local M = {}

-- Referencias a ventanas abiertas para Toggle/Untoggle
M.main_win = nil
M.preview_win = nil
M.diff_cache = {}

-- Estado interno del formulario de commit
M.commit_data = {
	title = "",
	description = "",
	tag = "",
}

-- Comprobar si el Centro de Git está abierto
function M.is_open()
	return M.main_win ~= nil and vim.api.nvim_win_is_valid(M.main_win)
end

-- Cerrar todas las ventanas del Centro de Git (Untoggle)
function M.close_git_center()
	if M.preview_win and vim.api.nvim_win_is_valid(M.preview_win) then
		pcall(vim.api.nvim_win_close, M.preview_win, true)
	end
	if M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
		pcall(vim.api.nvim_win_close, M.main_win, true)
	end
	M.main_win = nil
	M.preview_win = nil
end

-- Alternar abrir/cerrar (Toggle / Untoggle)
function M.toggle_git_center()
	if M.is_open() then
		M.close_git_center()
	else
		M.open_git_center()
	end
end

-- Ejecutar comando Git en consola y devolver la salida formateada
local function run_git_cmd(args, cwd)
	cwd = cwd or vim.fn.getcwd()
	local cmd = "git -C " .. vim.fn.shellescape(cwd) .. " " .. args
	return vim.fn.systemlist(cmd)
end

-- Obtener métricas y metadatos completos de Git
function M.get_git_info()
	local cwd = vim.fn.getcwd()
	if vim.fn.isdirectory(cwd .. "/.git") == 0 then
		local is_inside = run_git_cmd("rev-parse --is-inside-work-tree")[1]
		if is_inside ~= "true" then
			return nil
		end
	end

	-- 1. Branch
	local branch_output = run_git_cmd("branch --show-current")
	local branch = (branch_output and #branch_output > 0 and branch_output[1] ~= "") and branch_output[1] or "HEAD (Detached)"

	-- 2. Lines + and -
	local numstat = run_git_cmd("diff --numstat")
	local numstat_cached = run_git_cmd("diff --cached --numstat")
	local added_lines = 0
	local deleted_lines = 0

	for _, line in ipairs(numstat) do
		local add, del = line:match("^(%d+)%s+(%d+)")
		if add and del then
			added_lines = added_lines + tonumber(add)
			deleted_lines = deleted_lines + tonumber(del)
		end
	end
	for _, line in ipairs(numstat_cached) do
		local add, del = line:match("^(%d+)%s+(%d+)")
		if add and del then
			added_lines = added_lines + tonumber(add)
			deleted_lines = deleted_lines + tonumber(del)
		end
	end

	-- 3. Staged Files
	local staged_files = run_git_cmd("diff --name-only --cached")

	-- 4. Unstaged Files
	local unstaged_files = run_git_cmd("diff --name-only")

	-- 5. Untracked Files
	local untracked_files = run_git_cmd("ls-files --others --exclude-standard")

	-- 6. Linear Git Graph
	local graph = run_git_cmd("log --graph --oneline --all --decorate --color=never -n 12")

	return {
		branch = branch,
		added = added_lines,
		deleted = deleted_lines,
		staged = staged_files,
		unstaged = unstaged_files,
		untracked = untracked_files,
		graph = graph,
	}
end

-- Generar las líneas de texto del panel e índice de mapeo de líneas
local function build_panel_content(info, left_width)
	local lines = {}
	local line_map = {}

	-- HEADER (English)
	table.insert(lines, string.format(" 🌿 Branch: %s", info.branch))
	table.insert(lines, string.format(" 📊 Changes: +%d -%d lines", info.added, info.deleted))
	table.insert(lines, string.format(" 🟢 Staged: %d  |  🔴 Unstaged: %d  |  ❓ Untracked: %d", #info.staged, #info.unstaged, #info.untracked))
	table.insert(lines, string.rep("═", left_width - 2))

	-- SECTION 1: Commit Box & Tag (English)
	table.insert(lines, " 📝 [SECTION 1: COMMIT BOX & TAG]")
	table.insert(lines, "   [c] Title:       " .. (M.commit_data.title ~= "" and M.commit_data.title or "<Press c to edit in Vim>"))
	table.insert(lines, "   [m] Description: " .. (M.commit_data.description ~= "" and M.commit_data.description or "<Optional - Press m>"))
	table.insert(lines, "   [t] Tag:         " .. (M.commit_data.tag ~= "" and M.commit_data.tag or "<Optional - Press t>"))
	table.insert(lines, "   🚀 [C] Execute Commit & Tag")
	table.insert(lines, string.rep("─", left_width - 2))

	-- SECTION 2: Staged Files (English)
	table.insert(lines, string.format(" 🟢 [SECTION 2: STAGED FILES (%d)] ([u] Unstage / [U] Unstage All)", #info.staged))
	if #info.staged > 0 then
		for _, f in ipairs(info.staged) do
			table.insert(lines, "   ✓ " .. f)
			line_map[#lines] = { type = "staged", file = f }
		end
	else
		table.insert(lines, "   (no files staged)")
	end
	table.insert(lines, string.rep("─", left_width - 2))

	-- SECTION 3: Unstaged & Untracked Files (English)
	local total_unstaged = #info.unstaged + #info.untracked
	table.insert(lines, string.format(" 🔴 [SECTION 3: UNSTAGED & UNTRACKED FILES (%d)] ([s] Stage / [S] Stage All)", total_unstaged))
	if #info.unstaged > 0 then
		for _, f in ipairs(info.unstaged) do
			table.insert(lines, "   M " .. f)
			line_map[#lines] = { type = "unstaged", file = f }
		end
	end
	if #info.untracked > 0 then
		for _, f in ipairs(info.untracked) do
			table.insert(lines, "   ? " .. f)
			line_map[#lines] = { type = "untracked", file = f }
		end
	end
	if total_unstaged == 0 then
		table.insert(lines, "   (working tree clean)")
	end
	table.insert(lines, string.rep("─", left_width - 2))

	-- SECTION 4: Linear Git Graph (English)
	table.insert(lines, " 📜 [SECTION 4: LINEAR GIT GRAPH & TAGS]")
	if info.graph and #info.graph > 0 then
		for _, g_line in ipairs(info.graph) do
			table.insert(lines, "   " .. g_line)
		end
	else
		table.insert(lines, "   (no commit history)")
	end

	return lines, line_map
end

-- Open native Vim buffer editor modal for Title, Description, or Tag
local function open_vim_editor_modal(title_label, default_text, on_save)
	local width = math.floor(vim.o.columns * 0.65)
	local height = 6
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	if default_text and default_text ~= "" then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(default_text, "\n"))
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " 📝 " .. title_label .. " (Vim Editor: Esc to save and exit) ",
		title_pos = "center",
	})

	vim.api.nvim_set_option_value("number", true, { win = win })
	vim.api.nvim_set_option_value("wrap", true, { win = win })

	local function save_and_close()
		local text_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local full_text = table.concat(text_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
		on_save(full_text)
	end

	local kopts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set("n", "<Esc>", save_and_close, kopts)
	vim.keymap.set("n", "<CR>", save_and_close, kopts)
	vim.cmd("startinsert!")
end

-- Open or Refresh Git Control Center (<Ctrl+Shift+G>)
function M.open_git_center()
	if M.is_open() then
		M.close_git_center()
		return
	end

	local info = M.get_git_info()
	if not info then
		vim.notify("Current directory is not a valid Git repository", vim.log.levels.WARN, { title = "Git Center (KRS)" })
		return
	end

	M.diff_cache = {}

	local total_width = math.floor(vim.o.columns * 0.92)
	local total_height = math.floor(vim.o.lines * 0.85)
	local left_width = math.floor(total_width * 0.50)
	local right_width = total_width - left_width - 2
	local start_row = math.floor((vim.o.lines - total_height) / 2)
	local start_col = math.floor((vim.o.columns - total_width) / 2)

	-- Left Control Panel Window
	local main_buf = vim.api.nvim_create_buf(false, true)
	M.main_win = vim.api.nvim_open_win(main_buf, true, {
		relative = "editor",
		width = left_width,
		height = total_height,
		row = start_row,
		col = start_col,
		style = "minimal",
		border = "rounded",
		title = " 🐙 Git Center (Ctrl+Shift+G to untoggle) ",
		title_pos = "center",
	})

	-- Right Live Preview Window
	local preview_buf = vim.api.nvim_create_buf(false, true)
	M.preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = right_width,
		height = total_height,
		row = start_row,
		col = start_col + left_width + 2,
		style = "minimal",
		border = "rounded",
		title = " 👁️ Live Diff Preview (+ / -) ",
		title_pos = "center",
	})

	-- Autocomando de seguridad para limpiar variables cuando la ventana se cierra
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(M.main_win),
		once = true,
		callback = function()
			M.close_git_center()
		end,
	})

	local lines, line_map = build_panel_content(info, left_width)

	vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = main_buf })
	vim.api.nvim_set_option_value("cursorline", true, { win = M.main_win })

	-- Debounced Live Preview Update
	local preview_timer = nil
	local function update_preview_debounced()
		if preview_timer then
			preview_timer:stop()
			if not preview_timer:is_closing() then
				preview_timer:close()
			end
			preview_timer = nil
		end

		preview_timer = vim.uv.new_timer()
		preview_timer:start(40, 0, vim.schedule_wrap(function()
			if not M.main_win or not vim.api.nvim_win_is_valid(M.main_win) or not M.preview_win or not vim.api.nvim_win_is_valid(M.preview_win) then
				return
			end

			local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
			local item = line_map[row]

			if not item or not item.file then
				vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { " 💡 Select a staged or unstaged file to view diff." })
				return
			end

			local cache_key = item.type .. ":" .. item.file
			if not M.diff_cache[cache_key] then
				local preview_lines = {}
				if item.type == "staged" then
					preview_lines = run_git_cmd("diff --cached --color=never " .. vim.fn.shellescape(item.file))
					if #preview_lines == 0 then
						preview_lines = run_git_cmd("diff --cached --no-ext-diff " .. vim.fn.shellescape(item.file))
					end
				elseif item.type == "unstaged" then
					preview_lines = run_git_cmd("diff --color=never " .. vim.fn.shellescape(item.file))
				elseif item.type == "untracked" then
					if vim.fn.filereadable(item.file) == 1 then
						preview_lines = vim.fn.readfile(item.file)
					else
						preview_lines = { " [ New File ]" }
					end
				end

				if #preview_lines == 0 then
					if vim.fn.filereadable(item.file) == 0 then
						preview_lines = { " 🗑️ [ File Deleted ]" }
					else
						preview_lines = { " (no visible changes)" }
					end
				end
				M.diff_cache[cache_key] = preview_lines
			end

			vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, M.diff_cache[cache_key])
			vim.api.nvim_set_option_value("filetype", "diff", { buf = preview_buf })
		end))
	end

	local augroup = vim.api.nvim_create_augroup("KRSGitCenterPreview", { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		buffer = main_buf,
		callback = update_preview_debounced,
	})
	update_preview_debounced()

	-- Refresco In-Place SIN CERRAR ni REABRIR las ventanas flotantes (Zero Flicker)
	local function refresh()
		local cur_info = M.get_git_info()
		if not cur_info or not M.main_win or not vim.api.nvim_win_is_valid(M.main_win) then
			return
		end

		local new_lines, new_line_map = build_panel_content(cur_info, left_width)
		line_map = new_line_map

		local cur_pos = vim.api.nvim_win_get_cursor(M.main_win)
		vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, new_lines)
		pcall(vim.api.nvim_win_set_cursor, M.main_win, math.min(cur_pos[1], #new_lines), cur_pos[2])

		M.diff_cache = {}
		update_preview_debounced()
	end

	local function process_visual_selection(action_type)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		vim.schedule(function()
			local start_row = vim.api.nvim_buf_get_mark(main_buf, "<")[1]
			local end_row = vim.api.nvim_buf_get_mark(main_buf, ">")[1]
			if start_row > end_row then
				start_row, end_row = end_row, start_row
			end

			local files_to_process = {}
			for r = start_row, end_row do
				local it = line_map[r]
				if it and it.file then
					table.insert(files_to_process, vim.fn.shellescape(it.file))
				end
			end

			if #files_to_process > 0 then
				local files_str = table.concat(files_to_process, " ")
				if action_type == "stage" then
					run_git_cmd("add " .. files_str)
				elseif action_type == "unstage" then
					run_git_cmd("restore --staged " .. files_str)
				end
			end
			refresh()
		end)
	end

	local key_opts = { buffer = main_buf, noremap = true, silent = true }

	-- UNTOGGLE CON CUALQUIER COMBINACIÓN DE TECLAS DE CERRAR (<C-S-g>, <C-S-G>, <C-g>, q, Esc)
	local close_keys = { "<C-S-g>", "<C-S-G>", "<C-g>", "<C-G>", "q", "<Esc>" }
	for _, k in ipairs(close_keys) do
		vim.keymap.set("n", k, M.close_git_center, key_opts)
		vim.keymap.set("v", k, M.close_git_center, key_opts)
	end

	-- [c]: Edit Commit Title in Native Vim Editor
	vim.keymap.set("n", "c", function()
		open_vim_editor_modal("Commit Title", M.commit_data.title, function(input)
			M.commit_data.title = input
			refresh()
		end)
	end, key_opts)

	-- [m]: Edit Commit Description in Native Vim Editor
	vim.keymap.set("n", "m", function()
		open_vim_editor_modal("Commit Description", M.commit_data.description, function(input)
			M.commit_data.description = input
			refresh()
		end)
	end, key_opts)

	-- [t]: Edit Optional Tag in Native Vim Editor
	vim.keymap.set("n", "t", function()
		open_vim_editor_modal("Optional Tag (e.g. v1.0.0)", M.commit_data.tag, function(input)
			M.commit_data.tag = input
			refresh()
		end)
	end, key_opts)

	-- [s] in Normal: Stage single file
	vim.keymap.set("n", "s", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = line_map[row]
		if item and (item.type == "unstaged" or item.type == "untracked") then
			run_git_cmd("add " .. vim.fn.shellescape(item.file))
			refresh()
		end
	end, key_opts)

	-- [s] in Visual: Visual Multi-Stage
	vim.keymap.set("v", "s", function()
		process_visual_selection("stage")
	end, key_opts)

	-- [S] (Shift + s): Stage All Files
	vim.keymap.set({ "n", "v" }, "S", function()
		run_git_cmd("add .")
		refresh()
	end, key_opts)

	-- [u] in Normal: Unstage single file
	vim.keymap.set("n", "u", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = line_map[row]
		if item and item.type == "staged" then
			run_git_cmd("restore --staged " .. vim.fn.shellescape(item.file))
			refresh()
		end
	end, key_opts)

	-- [u] in Visual: Visual Multi-Unstage
	vim.keymap.set("v", "u", function()
		process_visual_selection("unstage")
	end, key_opts)

	-- [U] (Shift + u): Unstage All Files
	vim.keymap.set({ "n", "v" }, "U", function()
		run_git_cmd("restore --staged .")
		refresh()
	end, key_opts)

	-- [C]: Execute Commit & Tag
	vim.keymap.set("n", "C", function()
		if M.commit_data.title == "" then
			vim.notify("Please enter a commit title first with [c]", vim.log.levels.WARN, { title = "Git Center" })
			return
		end

		local commit_cmd = "commit -m " .. vim.fn.shellescape(M.commit_data.title)
		if M.commit_data.description ~= "" then
			commit_cmd = commit_cmd .. " -m " .. vim.fn.shellescape(M.commit_data.description)
		end

		local res = run_git_cmd(commit_cmd)
		vim.notify("🚀 Commit executed:\n" .. table.concat(res, "\n"), vim.log.levels.INFO, { title = "Git Center" })

		if M.commit_data.tag ~= "" then
			run_git_cmd("tag " .. vim.fn.shellescape(M.commit_data.tag))
			vim.notify("🏷️ Tag created: " .. M.commit_data.tag, vim.log.levels.INFO, { title = "Git Center" })
		end

		M.commit_data.title = ""
		M.commit_data.description = ""
		M.commit_data.tag = ""
		refresh()
	end, key_opts)

	-- [d]: View full Diff in Diffview
	vim.keymap.set("n", "d", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = line_map[row]
		if item and item.file then
			M.close_git_center()
			vim.cmd("DiffviewOpen --selected-file=" .. vim.fn.fnameescape(item.file))
		end
	end, key_opts)

	-- [r]: Refresh
	vim.keymap.set("n", "r", refresh, key_opts)
end

_G.GitCenter = M

-- Lazy.nvim plugin specification
local plugin_spec = {
	"NeogitOrg/neogit",
	cmd = { "GitCenter", "Neogit" },
	keys = {
		{ "<C-S-g>", function() M.toggle_git_center() end, mode = { "n", "i", "v", "t" }, desc = "Toggle Git Center" },
		{ "<C-S-G>", function() M.toggle_git_center() end, mode = { "n", "i", "v", "t" }, desc = "Toggle Git Center" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		vim.api.nvim_create_user_command("GitCenter", function()
			M.toggle_git_center()
		end, { desc = "Toggle Git Control Center" })

		local modes = { "n", "i", "v", "t" }
		for _, mode in ipairs(modes) do
			vim.keymap.set(mode, "<C-S-g>", function()
				if vim.fn.mode() == "t" then
					vim.cmd("stopinsert")
				end
				M.toggle_git_center()
			end, { noremap = true, silent = true, desc = "Toggle Git Control Center" })

			vim.keymap.set(mode, "<C-S-G>", function()
				if vim.fn.mode() == "t" then
					vim.cmd("stopinsert")
				end
				M.toggle_git_center()
			end, { noremap = true, silent = true, desc = "Toggle Git Control Center" })
		end
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

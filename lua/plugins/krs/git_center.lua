-- ============================================================================
-- 🦊 KRS PLUGIN: Interactive Git Control Center (Ctrl + Shift + G)
-- ============================================================================

local M = {}

-- References to open windows for Toggle/Untoggle
M.main_win = nil
M.preview_win = nil
M.main_buf = nil
M.preview_buf = nil
M.diff_cache = {}
M.line_map = {}

-- Internal state of commit form
M.commit_data = {
	title = "",
	description = "",
	tag = "",
}

-- Namespace for VSCode-style Diff highlights
local ns_diff = vim.api.nvim_create_namespace("git_center_diff_hl")

-- Configure VSCode-style colors for + and - changes
local function setup_diff_highlights()
	-- Added lines (+) -> Soft green background, light green text (VSCode style)
	vim.api.nvim_set_hl(0, "GitCenterDiffAdd", { bg = "#1c3427", fg = "#a6e3a1", default = true })
	-- Deleted lines (-) -> Soft red background, light red text (VSCode style)
	vim.api.nvim_set_hl(0, "GitCenterDiffDelete", { bg = "#3b1d22", fg = "#f38ba8", default = true })
	-- Hunk Header (@@) -> Soft blue background, bold cyan/blue text
	vim.api.nvim_set_hl(0, "GitCenterDiffHeader", { bg = "#1e293b", fg = "#89dceb", bold = true, default = true })
	-- Unchanged context text
	vim.api.nvim_set_hl(0, "GitCenterDiffContext", { fg = "#cdd6f4", default = true })
end

-- Check if Git Center is open
function M.is_open()
	return M.main_win ~= nil and vim.api.nvim_win_is_valid(M.main_win)
end

-- Close all Git Center windows (Untoggle)
function M.close_git_center()
	if M.preview_win and vim.api.nvim_win_is_valid(M.preview_win) then
		pcall(vim.api.nvim_win_close, M.preview_win, true)
	end
	if M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
		pcall(vim.api.nvim_win_close, M.main_win, true)
	end
	M.main_win = nil
	M.preview_win = nil
	M.main_buf = nil
	M.preview_buf = nil
end

-- Toggle open/close
function M.toggle_git_center()
	if M.is_open() then
		M.close_git_center()
	else
		M.open_git_center()
	end
end


-- Ejecutar comando Git nativo utilizando vim.system (Robusto en Windows/Linux, sin fallos de quoting)
local function run_git(args, cwd)
	cwd = cwd or vim.fn.getcwd()
	local cmd = { "git", "-C", cwd }

	if type(args) == "string" then
		for word in args:gmatch("%S+") do
			table.insert(cmd, word)
		end
	elseif type(args) == "table" then
		for _, arg in ipairs(args) do
			table.insert(cmd, arg)
		end
	end

	local obj = vim.system(cmd, { text = true }):wait()
	local stdout = obj.stdout or ""
	if stdout == "" then
		return {}
	end
	return vim.split(stdout, "[\r\n]+", { trimempty = true })
end

-- Obtener métricas y metadatos completos de Git
function M.get_git_info()
	local cwd = vim.fn.getcwd()
	if vim.fn.isdirectory(cwd .. "/.git") == 0 then
		local is_inside = run_git({ "rev-parse", "--is-inside-work-tree" })
		if not is_inside or is_inside[1] ~= "true" then
			return nil
		end
	end

	-- 1. Branch
	local branch_output = run_git({ "branch", "--show-current" })
	local branch = (branch_output and #branch_output > 0 and branch_output[1] ~= "") and branch_output[1] or "HEAD (Detached)"

	-- 2. Lines + and -
	local numstat = run_git({ "diff", "--numstat" })
	local numstat_cached = run_git({ "diff", "--cached", "--numstat" })
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
	local staged_files = run_git({ "diff", "--name-only", "--cached" })

	-- 4. Unstaged Files
	local unstaged_files = run_git({ "diff", "--name-only" })

	-- 5. Untracked Files
	local untracked_files = run_git({ "ls-files", "--others", "--exclude-standard" })

	-- 6. Linear Git Graph
	local graph = run_git({ "log", "--graph", "--oneline", "--all", "--decorate", "--color=never", "-n", "12" })

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
	local section_lines = {}

	-- HEADER
	table.insert(lines, string.format(" 🌿 Branch: %s", info.branch))
	table.insert(lines, string.format(" 📊 Changes: +%d -%d lines", info.added, info.deleted))
	table.insert(lines, string.format(" 🟢 Staged: %d  |  🔴 Unstaged: %d  |  ❓ Untracked: %d", #info.staged, #info.unstaged, #info.untracked))
	table.insert(lines, string.rep("═", left_width - 2))

	-- SECTION 1: Commit Box & Tag
	section_lines[1] = #lines + 1
	table.insert(lines, " 📝 [SECTION 1: COMMIT BOX & TAG] (Press 1)")
	table.insert(lines, "   [c] Title:       " .. (M.commit_data.title ~= "" and M.commit_data.title or "<Press c to edit in Vim>"))
	table.insert(lines, "   [m] Description: " .. (M.commit_data.description ~= "" and M.commit_data.description or "<Optional - Press m>"))
	table.insert(lines, "   [t] Tag:         " .. (M.commit_data.tag ~= "" and M.commit_data.tag or "<Optional - Press t>"))
	table.insert(lines, "   🚀 [C] Execute Commit & Tag")
	table.insert(lines, string.rep("─", left_width - 2))

	-- SECTION 2: Staged Files
	section_lines[2] = #lines + 1
	table.insert(lines, string.format(" 🟢 [SECTION 2: STAGED FILES (%d)] (Press 2 | [u] Unstage / [U] Unstage All)", #info.staged))
	if #info.staged > 0 then
		for _, f in ipairs(info.staged) do
			table.insert(lines, "   ✓ " .. f)
			line_map[#lines] = { type = "staged", file = f }
		end
	else
		table.insert(lines, "   (no files staged)")
	end
	table.insert(lines, string.rep("─", left_width - 2))

	-- SECTION 3: Unstaged & Untracked Files
	section_lines[3] = #lines + 1
	local total_unstaged = #info.unstaged + #info.untracked
	table.insert(lines, string.format(" 🔴 [SECTION 3: UNSTAGED & UNTRACKED FILES (%d)] (Press 3 | [s] Stage / [S] Stage All)", total_unstaged))
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

	-- SECTION 4: Linear Git Graph
	section_lines[4] = #lines + 1
	table.insert(lines, " 📜 [SECTION 4: LINEAR GIT GRAPH & TAGS] (Press 4)")
	if info.graph and #info.graph > 0 then
		for _, g_line in ipairs(info.graph) do
			table.insert(lines, "   " .. g_line)
		end
	else
		table.insert(lines, "   (no commit history)")
	end

	return lines, line_map, section_lines
end

-- Formateador Estilo VSCode para las diferencias (Omite cabeceras molestas de terminal y solo muestra fragmentos/hunks cambiados)
local function format_vscode_diff(raw_lines, is_untracked)
	local formatted = {}
	local line_types = {}

	-- nvim_buf_set_lines rejects any entry with an embedded newline; git
	-- output can smuggle one in (e.g. binary/CRLF-mangled content), so split
	-- defensively at the single point everything funnels through.
	local function push_line(text, ltype)
		for _, sub in ipairs(vim.split(text, "\n", { plain = true })) do
			table.insert(formatted, sub)
			table.insert(line_types, ltype)
		end
	end

	if is_untracked then
		push_line(" ─── 📄 New Untracked File ──────────────────────────────────────────", "header")
		for _, line in ipairs(raw_lines) do
			push_line("+ " .. line, "add")
		end
		return formatted, line_types
	end

	local in_header = true
	local hunk_count = 0

	for _, line in ipairs(raw_lines) do
		-- Omitir ruido de terminal de Git diff
		if line:match("^diff %--git") or line:match("^index %x+%.%.%x+") or line:match("^%-%-%- a/") or line:match("^%+%+%+ b/") or line:match("^new file mode") or line:match("^deleted file mode") then
			-- Ignorar líneas de cabecera de consola
		elseif line:match("^@@ %-%d+,?%d* %+%d+,?%d* @@") then
			in_header = false
			hunk_count = hunk_count + 1
			local hunk_info = line:match("@@ %-%d+,?%d* %+%d+,?%d* @@(.*)") or ""
			local hunk_range = line:match("(@@ %-%d+,?%d* %+%d+,?%d* @@)") or line
			local header_str = string.format(" ─── Hunk %d %s %s", hunk_count, hunk_range, hunk_info ~= "" and ("(" .. hunk_info:gsub("^%s*", "") .. ") ") or "")
			if #header_str < 65 then
				header_str = header_str .. string.rep("─", 65 - #header_str)
			end
			push_line(header_str, "header")
		elseif not in_header then
			if line:sub(1, 1) == "+" then
				push_line(line, "add")
			elseif line:sub(1, 1) == "-" then
				push_line(line, "delete")
			else
				push_line(line, "context")
			end
		end
	end

	if #formatted == 0 then
		push_line(" (no visible changes in this file)", "context")
	end

	return formatted, line_types
end

-- Abrir modal del editor nativo de Vim
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

-- Abrir o Refrescar el Centro de Git (<Ctrl+Shift+G>)
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

	setup_diff_highlights()
	M.diff_cache = {}

	local total_width = math.floor(vim.o.columns * 0.92)
	local total_height = math.floor(vim.o.lines * 0.85)
	local left_width = math.floor(total_width * 0.50)
	local right_width = total_width - left_width - 2
	local start_row = math.floor((vim.o.lines - total_height) / 2)
	local start_col = math.floor((vim.o.columns - total_width) / 2)

	-- Left Control Panel Window
	local main_buf = vim.api.nvim_create_buf(false, true)
	M.main_buf = main_buf
	M.main_win = vim.api.nvim_open_win(main_buf, true, {
		relative = "editor",
		width = left_width,
		height = total_height,
		row = start_row,
		col = start_col,
		style = "minimal",
		border = "rounded",
		title = " 🐙 Git Center (Ctrl+Shift+J/K Scroll Preview | Tab Focus | Ctrl+Shift+G Close) ",
		title_pos = "center",
	})

	-- Right Live Preview Window (VSCode Diff)
	local preview_buf = vim.api.nvim_create_buf(false, true)
	M.preview_buf = preview_buf
	M.preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = right_width,
		height = total_height,
		row = start_row,
		col = start_col + left_width + 2,
		style = "minimal",
		border = "rounded",
		title = " 👁️ VSCode Live Diff (+ / -) | Ctrl+Shift+J/K: Scroll Text ",
		title_pos = "center",
	})

	vim.api.nvim_set_option_value("number", true, { win = M.preview_win })
	vim.api.nvim_set_option_value("wrap", false, { win = M.preview_win })

	-- Autocomando de seguridad para limpiar variables al cerrar
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(M.main_win),
		once = true,
		callback = function()
			M.close_git_center()
		end,
	})

	local lines, line_map, section_lines = build_panel_content(info, left_width)
	M.line_map = line_map

	vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = main_buf })
	vim.api.nvim_set_option_value("cursorline", true, { win = M.main_win })

	-- Actualización del Preview con colores VSCode y filtrado de cabeceras
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
			local item = M.line_map[row]

			if not item or not item.file then
				vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { " 💡 Select a staged or unstaged file to view diff." })
				vim.api.nvim_buf_clear_namespace(preview_buf, ns_diff, 0, -1)
				return
			end

			local cache_key = item.type .. ":" .. item.file
			if not M.diff_cache[cache_key] then
				local raw_lines = {}
				local is_untracked = false

				if item.type == "staged" then
					raw_lines = run_git({ "diff", "--cached", "--color=never", "--", item.file })
				elseif item.type == "unstaged" then
					raw_lines = run_git({ "diff", "--color=never", "--", item.file })
				elseif item.type == "untracked" then
					is_untracked = true
					if vim.fn.filereadable(item.file) == 1 then
						raw_lines = vim.fn.readfile(item.file)
					else
						raw_lines = { "[ Empty or New File ]" }
					end
				end

				local formatted, line_types = format_vscode_diff(raw_lines, is_untracked)
				M.diff_cache[cache_key] = { formatted = formatted, line_types = line_types }
			end

			local cached_data = M.diff_cache[cache_key]
			vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, cached_data.formatted)
			vim.api.nvim_buf_clear_namespace(preview_buf, ns_diff, 0, -1)

			-- Aplicar los highlights de color estilo VSCode línea por línea
			for i, ltype in ipairs(cached_data.line_types) do
				local line_idx = i - 1
				if ltype == "add" then
					vim.api.nvim_buf_add_highlight(preview_buf, ns_diff, "GitCenterDiffAdd", line_idx, 0, -1)
				elseif ltype == "delete" then
					vim.api.nvim_buf_add_highlight(preview_buf, ns_diff, "GitCenterDiffDelete", line_idx, 0, -1)
				elseif ltype == "header" then
					vim.api.nvim_buf_add_highlight(preview_buf, ns_diff, "GitCenterDiffHeader", line_idx, 0, -1)
				elseif ltype == "context" then
					vim.api.nvim_buf_add_highlight(preview_buf, ns_diff, "GitCenterDiffContext", line_idx, 0, -1)
				end
			end
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

		local new_lines, new_line_map, new_section_lines = build_panel_content(cur_info, left_width)
		M.line_map = new_line_map
		line_map = new_line_map
		section_lines = new_section_lines

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
				local it = M.line_map[r]
				if it and it.file then
					table.insert(files_to_process, it.file)
				end
			end

			if #files_to_process > 0 then
				if action_type == "stage" then
					run_git({ "add", "--", unpack(files_to_process) })
				elseif action_type == "unstage" then
					run_git({ "restore", "--staged", "--", unpack(files_to_process) })
				end
			end
			refresh()
		end)
	end

	-- Códigos de teclas nativos exactos para Vim Motion <Ctrl+d> y <Ctrl+u> (Evita bugs de escape octal)
	local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
	local ctrl_u = vim.api.nvim_replace_termcodes("<C-u>", true, false, true)

	-- Función de desplazamiento fluido (Vim Motions Ctrl+d / Ctrl+u nativos) en el visor derecho
	local function scroll_preview(direction)
		if not M.preview_win or not vim.api.nvim_win_is_valid(M.preview_win) then return end
		vim.api.nvim_win_call(M.preview_win, function()
			if direction == "down" then
				vim.cmd("normal! " .. ctrl_d)
			else
				vim.cmd("normal! " .. ctrl_u)
			end
		end)
	end

	local scroll_down = function() scroll_preview("down") end
	local scroll_up = function() scroll_preview("up") end

	local key_opts = { buffer = main_buf, noremap = true, silent = true, nowait = true }

	-- NAVEGACIÓN DE DESPLAZAMIENTO DEL VISOR DERECHO CON CTRL+SHIFT+J / CTRL+SHIFT+K
	local nav_down = { "<C-S-j>", "<C-S-J>", "<C-j>", "<C-J>" }
	local nav_up = { "<C-S-k>", "<C-S-K>", "<C-k>", "<C-K>" }

	for _, k in ipairs(nav_down) do
		vim.keymap.set("n", k, scroll_down, { buffer = main_buf, noremap = true, silent = true, nowait = true })
		vim.keymap.set("n", k, scroll_down, { buffer = preview_buf, noremap = true, silent = true, nowait = true })
	end

	for _, k in ipairs(nav_up) do
		vim.keymap.set("n", k, scroll_up, { buffer = main_buf, noremap = true, silent = true, nowait = true })
		vim.keymap.set("n", k, scroll_up, { buffer = preview_buf, noremap = true, silent = true, nowait = true })
	end

	-- Alternar foco entre panel izquierdo y visor derecho con <Tab>
	local tab_toggle = function()
		if vim.api.nvim_get_current_win() == M.main_win then
			if M.preview_win and vim.api.nvim_win_is_valid(M.preview_win) then
				vim.api.nvim_set_current_win(M.preview_win)
			end
		else
			if M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
				vim.api.nvim_set_current_win(M.main_win)
			end
		end
	end
	vim.keymap.set("n", "<Tab>", tab_toggle, { buffer = main_buf, noremap = true, silent = true, nowait = true })
	vim.keymap.set("n", "<Tab>", tab_toggle, { buffer = preview_buf, noremap = true, silent = true, nowait = true })

	-- UNTOGGLE CON CUALQUIER COMBINACIÓN DE TECLAS DE CERRAR
	local close_keys = { "<C-S-g>", "<C-S-G>", "<C-g>", "<C-G>", "q", "<Esc>" }
	for _, k in ipairs(close_keys) do
		vim.keymap.set("n", k, M.close_git_center, key_opts)
		vim.keymap.set("v", k, M.close_git_center, key_opts)
		vim.keymap.set("n", k, M.close_git_center, { buffer = preview_buf, noremap = true, silent = true, nowait = true })
	end

	-- [1], [2], [3], [4]: Saltador directo a la Sección 1, 2, 3 o 4
	for i = 1, 4 do
		vim.keymap.set("n", tostring(i), function()
			if section_lines[i] and M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
				pcall(vim.api.nvim_win_set_cursor, M.main_win, { section_lines[i], 0 })
			end
		end, key_opts)
	end

	-- [c]: Editar Título del Commit
	vim.keymap.set("n", "c", function()
		open_vim_editor_modal("Commit Title", M.commit_data.title, function(input)
			M.commit_data.title = input
			refresh()
		end)
	end, key_opts)

	-- [m]: Editar Descripción del Commit
	vim.keymap.set("n", "m", function()
		open_vim_editor_modal("Commit Description", M.commit_data.description, function(input)
			M.commit_data.description = input
			refresh()
		end)
	end, key_opts)

	-- [t]: Editar Tag
	vim.keymap.set("n", "t", function()
		open_vim_editor_modal("Optional Tag (e.g. v1.0.0)", M.commit_data.tag, function(input)
			M.commit_data.tag = input
			refresh()
		end)
	end, key_opts)

	-- [s] en Normal: Stage archivo seleccionado
	vim.keymap.set("n", "s", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = M.line_map[row]
		if item and (item.type == "unstaged" or item.type == "untracked") then
			run_git({ "add", "--", item.file })
			refresh()
			vim.notify("🟢 Staged: " .. item.file, vim.log.levels.INFO, { title = "Git Center" })
		elseif item and item.type == "staged" then
			vim.notify("File is already staged", vim.log.levels.WARN, { title = "Git Center" })
		end
	end, key_opts)

	-- [s] en Visual: Visual Multi-Stage
	vim.keymap.set("v", "s", function()
		process_visual_selection("stage")
	end, key_opts)

	-- [S] (Shift + s): Stage All Files
	vim.keymap.set({ "n", "v" }, "S", function()
		run_git({ "add", "." })
		refresh()
		vim.notify("🟢 Staged all files", vim.log.levels.INFO, { title = "Git Center" })
	end, key_opts)

	-- [u] en Normal: Unstage archivo seleccionado (CORREGIDO)
	vim.keymap.set("n", "u", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = M.line_map[row]
		if item and item.type == "staged" then
			local res = run_git({ "restore", "--staged", "--", item.file })
			if #res > 0 and res[1]:match("fatal") then
				run_git({ "reset", "HEAD", "--", item.file })
			end
			refresh()
			vim.notify("🔴 Unstaged: " .. item.file, vim.log.levels.INFO, { title = "Git Center" })
		elseif item and (item.type == "unstaged" or item.type == "untracked") then
			vim.notify("File is not staged", vim.log.levels.WARN, { title = "Git Center" })
		else
			vim.notify("Please select a staged file (✓) to unstage", vim.log.levels.WARN, { title = "Git Center" })
		end
	end, key_opts)

	-- [u] en Visual: Visual Multi-Unstage (CORREGIDO)
	vim.keymap.set("v", "u", function()
		process_visual_selection("unstage")
	end, key_opts)

	-- [U] (Shift + u): Unstage All Files (CORREGIDO)
	vim.keymap.set({ "n", "v" }, "U", function()
		local res = run_git({ "restore", "--staged", "." })
		if #res > 0 and res[1]:match("fatal") then
			run_git({ "reset", "HEAD", "--", "." })
		end
		refresh()
		vim.notify("🔴 Unstaged all files", vim.log.levels.INFO, { title = "Git Center" })
	end, key_opts)

	-- [C]: Ejecutar Commit & Tag
	vim.keymap.set("n", "C", function()
		if M.commit_data.title == "" then
			vim.notify("Please enter a commit title first with [c]", vim.log.levels.WARN, { title = "Git Center" })
			return
		end

		local commit_args = { "commit", "-m", M.commit_data.title }
		if M.commit_data.description ~= "" then
			table.insert(commit_args, "-m")
			table.insert(commit_args, M.commit_data.description)
		end

		local res = run_git(commit_args)
		vim.notify("🚀 Commit executed:\n" .. table.concat(res, "\n"), vim.log.levels.INFO, { title = "Git Center" })

		if M.commit_data.tag ~= "" then
			run_git({ "tag", M.commit_data.tag })
			vim.notify("🏷️ Tag created: " .. M.commit_data.tag, vim.log.levels.INFO, { title = "Git Center" })
		end

		M.commit_data.title = ""
		M.commit_data.description = ""
		M.commit_data.tag = ""
		refresh()
	end, key_opts)

	-- [d]: Ver Diff completo en Diffview
	vim.keymap.set("n", "d", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = M.line_map[row]
		if item and item.file then
			M.close_git_center()
			vim.cmd("DiffviewOpen --selected-file=" .. vim.fn.fnameescape(item.file))
		end
	end, key_opts)

	-- [r]: Refrescar
	vim.keymap.set("n", "r", refresh, key_opts)
end

_G.GitCenter = M

-- lazy.nvim plugin spec
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

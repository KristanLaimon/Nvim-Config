-- ============================================================================
-- 🦊 KRS CONFIG: Barra de Herramientas Estilo IntelliJ (Play | Debug | Profiles)
-- ============================================================================
-- 1. Se renderiza automáticamente en la esquina superior derecha cuando existe .nvimkrs o tareas de proyecto.
-- 2. Ofrece un widget flotante visual:  🚀 [ ▶ Play | 🐞 Debug | ⚙️ Profiles ]
-- 3. Permite navegación con ratón (Click) o mediante comandos y Vim Motions (j/k, Enter, Esc, 1-9).
-- ============================================================================

local M = {}

M.toolbar_win = nil
M.toolbar_buf = nil

-- Verificar si el proyecto actual posee .nvimkrs o tareas de construcción
local function has_project_tasks()
	local tasks_mod = require("config.krs.tasks")
	local root = tasks_mod.get_project_root()
	local krs_file = root:gsub("\\", "/") .. "/.nvimkrs"
	if vim.fn.filereadable(krs_file) == 1 then
		return true, root
	end
	local discovered = tasks_mod.discover_tasks(root)
	if #discovered > 0 then
		return true, root
	end
	return false, root
end

-- Abrir Menú Modal de Ejecución (▶ Play)
function M.open_play_modal()
	local tasks_mod = require("config.krs.tasks")
	local root = tasks_mod.get_project_root()
	local pdata = tasks_mod.get_project_data(root)
	local default_name = "Sin configurar"
	if pdata.default_task then
		default_name = (type(pdata.default_task) == "table" and (pdata.default_task.name or pdata.default_task.cmd)) or tostring(pdata.default_task)
	end

	local items = {
		{ label = "▶ 1. Ejecutar Tarea por Defecto: " .. default_name, action = function() tasks_mod.run_default_or_menu() end },
		{ label = "📋 2. Abrir Menú Seleccionador de Tareas", action = function() tasks_mod.open_task_menu() end },
		{ label = "🔗 3. Crear o Ejecutar Cadena de Tareas", action = function() tasks_mod.open_task_menu() end },
	}

	M.open_popup_menu(" 🚀 IntelliJ Run Toolbar (Play) ", items)
end

-- Abrir Menú Modal de Depuración (🐞 Debug)
function M.open_debug_modal()
	local items = {
		{
			label = "▶ 1. Iniciar / Continuar Depuración (DAP Continue)",
			action = function()
				local ok, dap = pcall(require, "dap")
				if ok then dap.continue() else vim.notify("DAP no disponible", vim.log.levels.WARN) end
			end,
		},
		{
			label = "🔴 2. Alternar Punto de Interrupción (Toggle Breakpoint)",
			action = function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.toggle_breakpoint()
					vim.notify("🔴 Punto de interrupción alternado", vim.log.levels.INFO)
				end
			end,
		},
		{
			label = "⏭️ 3. Dar un Paso (Step Over)",
			action = function()
				local ok, dap = pcall(require, "dap")
				if ok then dap.step_over() end
			end,
		},
		{
			label = "⬇️ 4. Entrar en Función (Step Into)",
			action = function()
				local ok, dap = pcall(require, "dap")
				if ok then dap.step_into() end
			end,
		},
		{
			label = "🛑 5. Terminar Sesión de Depuración (DAP Terminate)",
			action = function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.terminate()
					pcall(function() require("dapui").close() end)
					vim.notify("🛑 Sesión de depuración terminada", vim.log.levels.INFO)
				end
			end,
		},
		{
			label = "🖥️ 6. Alternar Interfaz Visual de Depuración (DAP UI)",
			action = function()
				local ok, dapui = pcall(require, "dapui")
				if ok then dapui.toggle() end
			end,
		},
	}

	M.open_popup_menu(" 🐞 IntelliJ Debug Toolbar ", items)
end

-- Abrir Menú Modal de Perfiles y Tareas (⚙️ Profiles)
function M.open_profiles_modal()
	local tasks_mod = require("config.krs.tasks")
	tasks_mod.open_task_menu()
end

-- Renderizador Genérico de Ventanas Emergentes Modales con Vim Motions
function M.open_popup_menu(title, items)
	local max_width = #title + 4
	for _, it in ipairs(items) do
		if #it.label > max_width then
			max_width = #it.label
		end
	end
	max_width = math.min(math.max(max_width + 4, 45), 85)

	local buf = vim.api.nvim_create_buf(false, true)
	local lines = { " " .. title, string.rep("─", max_width - 2) }
	for _, it in ipairs(items) do
		table.insert(lines, "  " .. it.label)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local height = #lines
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - max_width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = max_width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
	})

	pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = win })

	local selected_idx = 1
	local function set_cursor_pos(idx)
		selected_idx = math.max(1, math.min(#items, idx))
		pcall(vim.api.nvim_win_set_cursor, win, { selected_idx + 2, 2 })
	end
	set_cursor_pos(1)

	local function close_win()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local function confirm()
		close_win()
		if items[selected_idx] and items[selected_idx].action then
			vim.schedule(items[selected_idx].action)
		end
	end

	local kopts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set("n", "<CR>", confirm, kopts)
	vim.keymap.set("n", "j", function() set_cursor_pos(selected_idx + 1) end, kopts)
	vim.keymap.set("n", "k", function() set_cursor_pos(selected_idx - 1) end, kopts)
	vim.keymap.set("n", "<Down>", function() set_cursor_pos(selected_idx + 1) end, kopts)
	vim.keymap.set("n", "<Up>", function() set_cursor_pos(selected_idx - 1) end, kopts)
	vim.keymap.set("n", "<Esc>", close_win, kopts)
	vim.keymap.set("n", "q", close_win, kopts)

	for i = 1, math.min(9, #items) do
		vim.keymap.set("n", tostring(i), function()
			selected_idx = i
			confirm()
		end, kopts)
	end
end

-- Renderizar o actualizar el widget superior derecho estilo IntelliJ
function M.render_toolbar()
	local has_tasks, _ = has_project_tasks()
	if not has_tasks then
		M.hide_toolbar()
		return
	end

	local toolbar_str = "  ▶ Play  |  🐞 Debug  |  ⚙️ Profiles  "
	local width = #toolbar_str + 2
	local col = math.max(0, vim.o.columns - width - 2)

	if M.toolbar_win and vim.api.nvim_win_is_valid(M.toolbar_win) then
		pcall(vim.api.nvim_win_set_config, M.toolbar_win, {
			relative = "editor",
			row = 0,
			col = col,
			width = width,
			height = 1,
		})
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	M.toolbar_buf = buf
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { toolbar_str })

	M.toolbar_win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = 0,
		col = col,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " 🚀 IntelliJ ",
		title_pos = "center",
		focusable = false,
	})

	vim.wo[M.toolbar_win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"

	-- Manejar clics del ratón sobre los botones del widget
	local function handle_click()
		local mouse_col = vim.fn.getmousepos().col
		local win_col = vim.api.nvim_win_get_position(M.toolbar_win)[2]
		local rel_col = mouse_col - win_col

		if rel_col <= 14 then
			M.open_play_modal()
		elseif rel_col <= 28 then
			M.open_debug_modal()
		else
			M.open_profiles_modal()
		end
	end

	vim.keymap.set("n", "<LeftMouse>", handle_click, { buffer = buf, noremap = true, silent = true })
end

function M.hide_toolbar()
	if M.toolbar_win and vim.api.nvim_win_is_valid(M.toolbar_win) then
		pcall(vim.api.nvim_win_close, M.toolbar_win, true)
	end
	M.toolbar_win = nil
	M.toolbar_buf = nil
end

function M.toggle_toolbar()
	if M.toolbar_win and vim.api.nvim_win_is_valid(M.toolbar_win) then
		M.hide_toolbar()
		vim.notify("IntelliJ Toolbar hidden", vim.log.levels.INFO)
	else
		M.render_toolbar()
		vim.notify("IntelliJ Toolbar visible", vim.log.levels.INFO)
	end
end

-- Inicializar autocomandos y comandos globales
function M.setup()
	local group = vim.api.nvim_create_augroup("IntelliJToolbarAuto", { clear = true })
	vim.api.nvim_create_autocmd({ "VimResized", "DirChanged", "BufEnter" }, {
		group = group,
		callback = function()
			vim.schedule(function()
				M.render_toolbar()
			end)
		end,
	})

	vim.api.nvim_create_user_command("IntelliJToolbarToggle", function()
		M.toggle_toolbar()
	end, { desc = "Toggle IntelliJ Top-Right Toolbar" })

	-- Keybindings globales para abrir modales Play, Debug y Profiles
	vim.keymap.set({ "n", "v" }, "<leader>rp", function() M.open_play_modal() end, { desc = "IntelliJ Play Modal" })
	vim.keymap.set({ "n", "v" }, "<leader>rd", function() M.open_debug_modal() end, { desc = "IntelliJ Debug Modal" })
	vim.keymap.set({ "n", "v" }, "<leader>rc", function() M.open_profiles_modal() end, { desc = "IntelliJ Profiles Modal" })
end

return M

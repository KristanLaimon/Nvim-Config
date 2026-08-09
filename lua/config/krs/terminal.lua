-- ============================================================================
-- 🦊 KRS CONFIG: Gestor de Terminales Múltiples (Lazy Loading Multi-Terminal Manager)
-- ============================================================================
-- 1. Permite gestionar 9 terminales independientes (1-9) con Carga Perezosa (Lazy Loading).
-- 2. <Alt + 1> .. <Alt + 9> selecciona y cambia a la terminal #n.
-- 3. <Ctrl + ;> abre/oculta alternadamente la terminal que esté SELECCIONADA actualmente.
-- 4. Soporta navegación limpia entre el editor de código y las terminales.
-- ============================================================================

local M = {}

local terminals = {} -- Estructura: [n] = { buf = number|nil, win = number|nil }
local selected_terminal = 1 -- Índice de la terminal actualmente seleccionada (1 por defecto)
local code_win = nil -- Ventana de código de origen para volver con foco limpio

-- Verificar si una ventana es válida
local function is_valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

-- Verificar si un buffer es válido
local function is_valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

-- Obtener o inicializar la referencia del terminal n (Lazy Loading)
local function get_term(n)
	local t = terminals[n]
	if not t then
		t = { buf = nil, win = nil }
		terminals[n] = t
	end
	return t
end

-- Obtener la ventana de terminal visible actualmente (si hay alguna)
local function get_active_terminal_win()
	for _, t in pairs(terminals) do
		if is_valid_win(t.win) then
			return t.win
		end
	end
	return nil
end

-- Obtener la terminal seleccionada actualmente (1-9)
function M.get_selected_terminal()
	return selected_terminal
end

-- Seleccionar la terminal #n (Alt + 1..9)
function M.select_terminal(n)
	selected_terminal = n
	local t = get_term(n)
	local current_win = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- Si no estamos en una ventana de terminal, guardar la ventana de código actual
	if not active_win or current_win ~= active_win then
		code_win = current_win
	end

	if is_valid_win(active_win) then
		-- Si ya hay una ventana de terminal split visible abajo: cambiar el buffer
		t.win = active_win
		if is_valid_buf(t.buf) then
			vim.api.nvim_win_set_buf(t.win, t.buf)
		else
			-- Lazy load terminal #n por primera vez
			vim.api.nvim_set_current_win(t.win)
			vim.cmd("terminal")
			t.buf = vim.api.nvim_get_current_buf()
			vim.bo[t.buf].buflisted = false
		end
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
	else
		-- Si no hay ventana de terminal abierta, abrir la terminal seleccionada
		M.open_terminal(n)
	end

	vim.notify("🖥️ Terminal #" .. n .. " activa", vim.log.levels.INFO, { title = "Multi-Terminal" })
end

-- Abrir/Mostrar una terminal específica
function M.open_terminal(n)
	n = n or selected_terminal
	selected_terminal = n
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- Guardar ventana de código
	if current ~= active_win then
		code_win = current
	end

	-- Si la ventana ya no es válida, limpiar referencia
	if t.win and not is_valid_win(t.win) then
		t.win = nil
	end

	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	-- Crear ventana split abajo (10 líneas)
	vim.cmd("botright 10split")
	t.win = vim.api.nvim_get_current_win()

	if is_valid_buf(t.buf) then
		vim.api.nvim_win_set_buf(t.win, t.buf)
	else
		-- Lazy loading del proceso de terminal #n
		vim.cmd("terminal")
		t.buf = vim.api.nvim_get_current_buf()
		vim.bo[t.buf].buflisted = false
	end

	-- Ajustes visuales de ventana de terminal
	vim.wo[t.win].number = false
	vim.wo[t.win].relativenumber = false
	vim.wo[t.win].signcolumn = "no"

	vim.cmd("startinsert")
end

-- Alternar (Toggle) la terminal SELECCIONADA con Ctrl + ;
function M.toggle_selected_terminal()
	local n = selected_terminal
	local t = get_term(n)
	local current = vim.api.nvim_get_current_win()
	local active_win = get_active_terminal_win()

	-- Caso 1: Si el cursor está en una ventana de terminal -> Ocultarla y volver al código
	if active_win and current == active_win then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.api.nvim_win_close, active_win, true)
		if t.win == active_win then
			t.win = nil
		end
		for _, term in pairs(terminals) do
			if term.win == active_win then
				term.win = nil
			end
		end

		if is_valid_win(code_win) then
			pcall(vim.api.nvim_set_current_win, code_win)
		else
			vim.cmd("wincmd p")
		end
		return
	end

	-- Caso 2: Si el terminal está abierto pero sin foco -> Enfocarlo
	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	-- Caso 3: Abrir el terminal seleccionado
	M.open_terminal(n)
end

-- Configuración de Keymaps globales
function M.setup()
	-- Alt + 1..9 para seleccionar/gestionar Terminal 1..9 en Normal, Insert y Terminal
	for n = 1, 9 do
		local alt_key = "<A-" .. n .. ">"
		vim.keymap.set({ "n", "i", "t" }, alt_key, function()
			if vim.api.nvim_get_mode().mode == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.select_terminal(n)
		end, { noremap = true, silent = true, desc = "Seleccionar Terminal #" .. n })
	end

	-- Ctrl + ; para abrir/ocultar alternadamente la terminal seleccionada actualmente
	vim.keymap.set({ "n", "i", "t" }, "<C-;>", function()
		M.toggle_selected_terminal()
	end, { noremap = true, silent = true, desc = "Alternar Terminal Seleccionada" })

	-- Permitir navegación estándar con Ctrl+W desde dentro de la terminal
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { noremap = true, silent = true })
end

return M

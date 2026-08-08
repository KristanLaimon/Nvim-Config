-- ============================================================================
-- 🦊 KRS CONFIG: Gestor de Terminales Alternables (Multi-Terminal Toggle Manager)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Mantiene una lista de terminales indexados del 1 al 9 en memoria Lua.
-- 2. Cada terminal tiene su propia ventana (`win`) y buffer (`buf`).
-- 3. Permite alternar (Toggle) cada terminal rápidamente mediante:
--      <leader>t o <leader>t1..9 o <Ctrl-;>
-- 4. Oculta el terminal automáticamente cuando el cursor sale de su ventana (WinLeave autocmd).
-- 5. Ajusta keymaps dentro del modo terminal ('t') para que Ctrl+W y Ctrl+; funcionen fluido.
-- ============================================================================

local M = {}

local terminals = {} -- Estructura: [n] = { buf = number|nil, win = number|nil }
local code_win = nil

-- Verificar si una ventana existe y es válida en la UI actual
local function is_valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

-- Verificar si un buffer existe y es válido
local function is_valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

-- Obtener o inicializar la referencia del terminal n
local function get_term(n)
	local t = terminals[n]
	if not t then
		t = { buf = nil, win = nil }
		terminals[n] = t
	end
	return t
end

-- Forzar el cierre de una ventana de terminal sin romper el layout
local function force_close_win(win)
	win = win or vim.api.nvim_get_current_win()
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		pcall(vim.api.nvim_win_close, win, true)
	else
		pcall(vim.api.nvim_buf_delete, vim.api.nvim_win_get_buf(win), { force = true })
	end
end

-- Ocultar el terminal específico n
function M.hide_terminal(n)
	local t = get_term(n or 1)
	if is_valid_win(t.win) then
		vim.api.nvim_win_close(t.win, true)
		t.win = nil
	end
end

-- Ocultar el terminal en el que esté actualmente posicionado el cursor
function M.hide_current_terminal()
	local current = vim.api.nvim_get_current_win()
	for n, t in pairs(terminals) do
		if t.win == current then
			M.toggle_terminal(n)
			return
		end
	end
end

-- Alternar visibilidad/enfoque del terminal indexado n (1-9)
function M.toggle_terminal(n)
	n = n or 1
	local t = get_term(n)

	-- Si la ventana ya no es válida (ej. se cerró manualmente), limpiar referencia
	if t.win and not is_valid_win(t.win) then
		t.win = nil
	end

	local current = vim.api.nvim_get_current_win()

	------------------------------------------------------------------
	-- Caso 1: El cursor ya está dentro del terminal -> Volver al editor
	------------------------------------------------------------------
	if is_valid_win(t.win) and current == t.win then
		vim.cmd("stopinsert")

		if is_valid_win(code_win) then
			vim.api.nvim_set_current_win(code_win)
		else
			vim.cmd("wincmd p")
		end
		return
	end

	------------------------------------------------------------------
	-- Guardar la ventana de código actual para recordar a dónde volver
	------------------------------------------------------------------
	code_win = current

	------------------------------------------------------------------
	-- Caso 2: El terminal está abierto en otra pestaña -> Cerrarlo allá
	------------------------------------------------------------------
	if is_valid_win(t.win) and vim.api.nvim_win_get_tabpage(t.win) ~= vim.api.nvim_get_current_tabpage() then
		vim.api.nvim_win_close(t.win, true)
		t.win = nil
	end

	------------------------------------------------------------------
	-- Caso 3: El terminal ya está abierto en la pestaña actual -> Enfocarlo
	------------------------------------------------------------------
	if is_valid_win(t.win) then
		vim.api.nvim_set_current_win(t.win)
		vim.cmd("startinsert")
		return
	end

	------------------------------------------------------------------
	-- Caso 4: Crear la ventana de terminal (split abajo de 7 líneas)
	------------------------------------------------------------------
	vim.cmd("botright 7split")
	t.win = vim.api.nvim_get_current_win()

	if is_valid_buf(t.buf) then
		vim.api.nvim_win_set_buf(t.win, t.buf)
	else
		vim.cmd("terminal")
		t.buf = vim.api.nvim_get_current_buf()
		-- Ocultar el terminal de la barra de pestañas/buffers
		vim.bo[t.buf].buflisted = false

		-- Shortcut interno: Ctrl+W Ctrl+C cierra el terminal definitivamente
		vim.keymap.set("n", "<C-w>c", function()
			force_close_win(t.win)
		end, { buffer = t.buf, noremap = true, silent = true, desc = "Cerrar terminal definitivamente" })
	end

	vim.cmd("startinsert")

	-- Auto-hide: Al salir de la ventana de terminal, se oculta automáticamente
	local group = vim.api.nvim_create_augroup("AutoHideTerminal" .. n, { clear = true })
	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		buffer = t.buf,
		callback = function()
			vim.schedule(function()
				M.hide_terminal(n)
			end)
		end,
	})
end

-- Inicialización de Mapeos de Teclado
function M.setup()
	-- Asignar <leader>t y <leader>t1..9 en modo Normal
	for n = 1, 9 do
		local lhs = n == 1 and "<leader>t" or ("<leader>t" .. n)
		vim.keymap.set("n", lhs, function()
			M.toggle_terminal(n)
		end, { noremap = true, silent = true, desc = "Alternar Terminal " .. n })
	end

	-- Alternar terminal desde modo terminal con <leader>t
	vim.keymap.set("t", "<leader>t", function()
		vim.cmd("stopinsert")
		M.hide_current_terminal()
	end, { noremap = true, silent = true, desc = "Alternar Terminal" })

	-- Alternar terminal 1 con Ctrl+; (tanto en modo Normal como Terminal)
	vim.keymap.set("n", "<C-;>", function()
		M.toggle_terminal(1)
	end, { noremap = true, silent = true, desc = "Alternar Terminal 1" })

	vim.keymap.set("t", "<C-;>", function()
		vim.cmd("stopinsert")
		M.hide_current_terminal()
	end, { noremap = true, silent = true, desc = "Alternar Terminal 1" })

	-- Permitir navegación estándar de ventanas con Ctrl+W dentro del modo terminal
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { noremap = true, silent = true })
end

return M

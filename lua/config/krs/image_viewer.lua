-- ============================================================================
-- 🦊 KRS CONFIG: Visualizador de Imágenes Pixel-Art (Chafa Terminal Viewer)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Obtiene la ruta del archivo actual abierto en el editor.
-- 2. Si estás posicionado en Neo-tree o un buffer vacío, busca automáticamente el primer buffer visible con archivo real.
-- 3. Crea una ventana flotante modal en el centro de la pantalla con bordes redondeados.
-- 4. Ejecuta el comando externo 'chafa' dentro del buffer usando `vim.fn.termopen`.
-- 5. Asigna teclas 'q' y 'Esc' locales al buffer flotante para cerrarlo instantáneamente.
-- ============================================================================

local M = {}

function M.view_current_image()
	local path = vim.api.nvim_buf_get_name(0)

	-- Si no hay archivo en la ventana actual o es Neo-tree, buscar primer buffer real activo
	if path == "" or vim.fn.filereadable(path) == 0 or vim.bo.filetype == "neo-tree" then
		path = ""
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype ~= "neo-tree" and vim.bo[b].buftype == "" then
				local name = vim.api.nvim_buf_get_name(b)
				if name ~= "" and vim.fn.filereadable(name) == 1 then
					path = name
					break
				end
			end
		end
	end

	if path == "" then
		vim.notify("No hay ningún archivo válido para mostrar", vim.log.levels.WARN, { title = "KRS Image Viewer" })
		return
	end

	-- Calcular dimensiones del cuadro flotante (80% del editor)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	-- Crear buffer efímero desvinculado (scratch buffer)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	})

	-- Ejecutar chafa en la terminal emulada
	vim.fn.termopen(string.format("chafa --size=%dx%d %s", width, height, vim.fn.shellescape(path)))

	-- Mapeos locales para cerrar la ventana con 'q' o 'Esc'
	vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", { buffer = buf, silent = true })
end

function M.setup()
	-- Asignar <leader>i para abrir el visualizador de imágenes en modo Normal
	vim.keymap.set(
		"n",
		"<leader>i",
		M.view_current_image,
		{ noremap = true, silent = true, desc = "Visualizar imagen con chafa" }
	)
end

return M

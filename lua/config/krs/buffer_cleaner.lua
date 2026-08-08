-- ============================================================================
-- 🦊 KRS CONFIG: Limpiador de Buffers y Cierre Inteligente (Buffer Manager)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. `Neotree_Smart_Quit`: Cierra el buffer/pestaña actual de forma inteligente:
--      - Si hay varias pestañas/buffers abiertos, cierra solo la pestaña actual y pasa a la anterior (sin cerrar Neovim).
--      - Si hay divisiones de pantalla (splits), cierra solo la ventana dividida actual.
--      - Si es el último archivo abierto, borra el buffer y vuelve al Menú Principal (Alpha Dashboard).
--      - Si ya estás en el Menú Principal (Alpha), `:q` cierra Neovim por completo.
-- 2. `CleanNoNameBuffers`: Autocomando que detecta y elimina automáticamente los buffers vacíos [No Name] sin modificar cuando abres archivos reales.
-- 3. `AddOpenedFolder`: Mantiene un registro de carpetas/proyectos abiertos recientemente para Telescope.
-- 4. Alias de comandos `:q` y `:q!`: Sobrescribe `:q` para llamar dinámicamente a la limpieza inteligente.
-- ============================================================================

local M = {}

-- Tabla global para registro de carpetas abiertas
_G.OpenedFolders = _G.OpenedFolders or {}

function _G.AddOpenedFolder(dir_path)
	if not dir_path or dir_path == "" then
		return
	end
	local clean = vim.fn.fnamemodify(dir_path, ":p"):gsub("[/\\]$", "")
	if vim.fn.isdirectory(clean) == 1 then
		_G.OpenedFolders[clean:lower()] = clean
	end
end

-- Función de Cierre Inteligente de Buffers y Pestañas (Smart Quit & Tab Manager)
function _G.Neotree_Smart_Quit(force)
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[cur_buf].filetype
	local bt = vim.bo[cur_buf].buftype

	-- 1. Si estamos en Alpha (Dashboard), :q cierra Neovim por completo
	if ft == "alpha" then
		vim.cmd(force and "qa!" or "qa")
		return
	end

	-- 2. Si estamos enfocados en Neo-tree, cerrar la barra lateral de Neo-tree
	if ft == "neo-tree" then
		pcall(vim.cmd, "Neotree close")
		return
	end

	-- 3. Si estamos en una ventana de terminal, cerrar esa ventana
	if bt == "terminal" then
		pcall(vim.cmd, force and "close!" or "close")
		return
	end

	-- Contar cuántas ventanas de código reales (excluyendo Neo-tree) hay en la pestaña actual
	local code_wins = 0
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_is_valid(win) then
			local b = vim.api.nvim_win_get_buf(win)
			local bft = vim.bo[b].filetype
			if bft ~= "neo-tree" and bft ~= "alpha" then
				code_wins = code_wins + 1
			end
		end
	end

	-- Si hay múltiples divisiones de ventana (splits de código), cerrar solo el split actual
	if code_wins > 1 then
		pcall(vim.cmd, force and "close!" or "close")
		return
	end

	-- Contar cuántos buffers reales de archivos están abiertos en total
	local bufs = vim.api.nvim_list_bufs()
	local real_bufs = {}
	for _, b in ipairs(bufs) do
		if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
			local bname = vim.api.nvim_buf_get_name(b)
			local bft = vim.bo[b].filetype
			if bft ~= "alpha" and bft ~= "neo-tree" then
				table.insert(real_bufs, b)
			end
		end
	end

	-- Si hay más de 1 buffer de archivo abierto en la barra de pestañas:
	if #real_bufs > 1 then
		-- Pasar al buffer anterior antes de borrar el actual para no cerrar la aplicación ni deformar el editor
		pcall(vim.cmd, "BufferLineCyclePrev")
		local cmd = force and ("bdelete! " .. cur_buf) or ("bdelete " .. cur_buf)
		pcall(vim.cmd, cmd)
	else
		-- Es el último buffer de archivo abierto -> Cerrar el buffer y mostrar el Menú Principal (Alpha Dashboard)
		local cmd = force and ("bdelete! " .. cur_buf) or ("bdelete " .. cur_buf)
		pcall(vim.cmd, cmd)
		vim.schedule(function()
			pcall(vim.cmd, "Alpha")
		end)
	end
end

function M.setup()
	-- Inicializar carpeta de trabajo actual en OpenedFolders
	_G.AddOpenedFolder(vim.fn.getcwd())

	-- Autocomando: Registrar cambio de directorio (:cd / Telescope projects)
	local group_track = vim.api.nvim_create_augroup("KRSTrackOpenedFolders", { clear = true })
	vim.api.nvim_create_autocmd("DirChanged", {
		group = group_track,
		callback = function(ctx)
			local dir = (ctx.file and ctx.file ~= "") and ctx.file or vim.fn.getcwd()
			_G.AddOpenedFolder(dir)
		end,
	})

	-- Autocomando: Limpieza automática de buffers vacíos [No Name] cuando hay archivos reales abiertos
	local group_clean = vim.api.nvim_create_augroup("KRSCleanNoNameBuffers", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group_clean,
		callback = function()
			vim.schedule(function()
				local bufs = vim.api.nvim_list_bufs()
				local real_files = 0
				for _, b in ipairs(bufs) do
					if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
						local bname = vim.api.nvim_buf_get_name(b)
						local btype = vim.bo[b].buftype
						local ftype = vim.bo[b].filetype
						if bname ~= "" and btype == "" and ftype ~= "alpha" and ftype ~= "neo-tree" then
							real_files = real_files + 1
						end
					end
				end

				-- Solo limpiar buffers [No Name] si hay al menos 1 archivo real abierto
				if real_files > 0 then
					local visible_bufs = {}
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) then
							visible_bufs[vim.api.nvim_win_get_buf(win)] = true
						end
					end

					for _, b in ipairs(bufs) do
						if vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1 then
							local bname = vim.api.nvim_buf_get_name(b)
							local btype = vim.bo[b].buftype
							local modified = vim.bo[b].modified
							if bname == "" and btype == "" and not modified and not visible_bufs[b] then
								pcall(vim.api.nvim_buf_delete, b, { force = true })
							end
						end
					end
				end
			end)
		end,
	})

	-- Mapeos de teclado para cierre inteligente de buffers (Ctrl+Q y Leader+q)
	vim.keymap.set("n", "<C-q>", function()
		_G.Neotree_Smart_Quit(false)
	end, { noremap = true, silent = true, desc = "Cerrar buffer/pestaña actual" })
	vim.keymap.set("n", "<leader>q", function()
		_G.Neotree_Smart_Quit(false)
	end, { noremap = true, silent = true, desc = "Cerrar buffer/pestaña actual" })

	-- Sobrescribir :q y :q! para llamar a la función inteligente
	vim.cmd([[
		cnoreabbrev <expr> q (getcmdtype() == ':' && getcmdline() ==# 'q') ? 'lua _G.Neotree_Smart_Quit(false)' : 'q'
		cnoreabbrev <expr> q! (getcmdtype() == ':' && getcmdline() ==# 'q!') ? 'lua _G.Neotree_Smart_Quit(true)' : 'q!'
	]])
end

return M

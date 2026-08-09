-- ============================================================================
-- 🦊 KRS CONFIG: Explorador de Archivos Flotante Nativo (Pure Lua Telescope)
-- ============================================================================
-- 1. 100% Nativo en Lua sin usar binarios externos (evita errores 'Executable not found').
-- 2. Se ejecuta por defecto en el Desktop del usuario (Multiplataforma).
-- 3. Permite crear archivos, carpetas, renombrar, eliminar y navegar.
-- 4. Tecla 'o' o '<C-o>' abre carpetas como Proyecto Activo (CWD).
-- ============================================================================

local M = {}

-- Obtener la ruta del Escritorio (Desktop) de forma multiplataforma (Windows / macOS / Linux)
function M.get_desktop_path()
	local home = vim.fn.expand("~")
	local desktop = home .. "/Desktop"
	if vim.fn.isdirectory(desktop) == 1 then
		return desktop
	end

	-- Soporte para OneDrive Desktop en Windows
	local onedrive_desktop = home .. "/OneDrive/Desktop"
	if vim.fn.isdirectory(onedrive_desktop) == 1 then
		return onedrive_desktop
	end

	return home
end

-- Abrir el explorador de archivos nativo en Telescope
function M.open_desktop_explorer(opts)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	opts = opts or {}
	local curr_dir = opts.path or M.get_desktop_path()
	curr_dir = vim.fn.fnamemodify(curr_dir, ":p"):gsub("[/\\]$", "")

	if vim.fn.isdirectory(curr_dir) == 0 then
		curr_dir = M.get_desktop_path()
	end

	-- Escanear elementos usando la API nativa de Neovim (fs_scandir)
	local entries = {}
	local handle = vim.uv.fs_scandir(curr_dir)
	if handle then
		while true do
			local name, type = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local full_path = curr_dir .. "/" .. name
			local is_dir = (type == "directory")
			table.insert(entries, {
				name = name,
				path = full_path,
				is_dir = is_dir,
				display = (is_dir and "📁 " or "📄 ") .. name,
			})
		end
	end

	-- Ordenar: Carpetas primero, luego archivos por orden alfabético
	table.sort(entries, function(a, b)
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name:lower() < b.name:lower()
	end)

	pickers.new({
		prompt_title = " 📁 Explorador: " .. curr_dir .. " ",
		results_title = " Archivos / Carpetas | Presiona [?] para ver ayuda ",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				return {
					value = entry,
					display = entry.display,
					ordinal = (entry.is_dir and "0_" or "1_") .. entry.name,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		layout_strategy = "horizontal",
		layout_config = {
			width = 0.85,
			height = 0.80,
			prompt_position = "top",
		},
		attach_mappings = function(prompt_bufnr, map)
			-- Enter: Entrar a carpeta o abrir archivo en el editor
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				if item.is_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = item.path })
					end)
				else
					actions.close(prompt_bufnr)
					vim.cmd("edit " .. vim.fn.fnameescape(item.path))
				end
			end)

			-- Teclas 'o', 'O' y '<C-o>': Establecer carpeta como Proyecto Activo (CWD)
			local set_project_cwd = function()
				local selection = action_state.get_selected_entry()
				local target = curr_dir
				if selection and selection.value and selection.value.is_dir then
					target = selection.value.path
				end
				actions.close(prompt_bufnr)
				pcall(vim.api.nvim_set_current_dir, target)

				local history_ok, history = pcall(require, "project_nvim.utils.history")
				if history_ok and history.recent_projects then
					table.insert(history.recent_projects, target)
					pcall(history.write_projects_to_history)
				end

				vim.notify("📁 Raíz del proyecto cambiada a:\n" .. target, vim.log.levels.INFO, { title = "Proyecto Activo" })
			end
			map("i", "<C-o>", set_project_cwd)
			map("n", "<C-o>", set_project_cwd)
			map("n", "o", set_project_cwd)
			map("n", "O", set_project_cwd)

			-- Tecla 'a': Crear archivo (ej: index.js) o carpeta (ej: src/ con barra al final)
			local create_item = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Crear nuevo (agrega '/' al final para carpeta): " }, function(name)
						if not name or name == "" then
							return
						end
						local full_path = curr_dir .. "/" .. name
						if name:sub(-1) == "/" or name:sub(-1) == "\\" then
							vim.fn.mkdir(full_path, "p")
							vim.notify("📁 Carpeta creada: " .. name, vim.log.levels.INFO)
						else
							local f = io.open(full_path, "w")
							if f then
								f:close()
								vim.notify("📄 Archivo creado: " .. name, vim.log.levels.INFO)
							end
						end
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "a", create_item)
			map("i", "<C-a>", create_item)

			-- Tecla 'r': Renombrar
			local rename_item = function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Renombrar a: ", default = item.name }, function(new_name)
						if not new_name or new_name == "" or new_name == item.name then
							return
						end
						local new_path = curr_dir .. "/" .. new_name
						os.rename(item.path, new_path)
						vim.notify("✏️ Renombrado a: " .. new_name, vim.log.levels.INFO)
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "r", rename_item)

			-- Tecla 'd': Eliminar
			local delete_item = function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then
					return
				end
				local item = selection.value
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "¿Eliminar '" .. item.name .. "'? (s/n): " }, function(confirm)
						if confirm and confirm:lower() == "s" then
							vim.fn.delete(item.path, "rf")
							vim.notify("🗑️ Eliminado: " .. item.name, vim.log.levels.INFO)
						end
						M.open_desktop_explorer({ path = curr_dir })
					end)
				end)
			end
			map("n", "d", delete_item)

			-- Teclas 'h' y '<BS>': Subir al directorio padre
			local go_parent = function()
				local parent = vim.fn.fnamemodify(curr_dir, ":h")
				if parent and parent ~= curr_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = parent })
					end)
				end
			end
			map("n", "h", go_parent)
			map("n", "<BS>", go_parent)

			-- Tecla 'l': Entrar a carpeta
			local drill_in = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value and selection.value.is_dir then
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_desktop_explorer({ path = selection.value.path })
					end)
				end
			end
			map("n", "l", drill_in)

			-- Teclas '?' y '<F1>': Ayuda contextual minimalista
			local show_help = function()
				require("config.krs.context_help").show_help()
			end
			map("n", "?", show_help)
			map("n", "<F1>", show_help)

			return true
		end,
	}):find()
end

-- Registrar el comando de usuario global
function M.setup()
	if vim.fn.exists(":TelescopeFileBrowserDesktop") == 0 then
		vim.api.nvim_create_user_command("TelescopeFileBrowserDesktop", function()
			M.open_desktop_explorer()
		end, { desc = "Abrir Explorador de Archivos (Desktop)" })
	end
end

return M

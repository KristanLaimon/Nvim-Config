-- ============================================================================
-- 🦊 KRS CONFIG: Gestor de Tareas y Ejecutor de Código por Proyecto (Task Runner)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Detecta la raíz del proyecto usando vim.fs.find (busca package.json, Makefile, Cargo.toml, etc.).
-- 2. Escanea automáticamente scripts en Makefile, package.json, Cargo.toml o go.mod.
-- 3. Permite guardar tareas personalizadas y definir una tarea por defecto (Star ⭐).
-- 4. Renderiza un menú interactivo en Telescope con accesos directos:
--      [Enter]  -> Ejecuta la tarea en un panel de terminal split abajo
--      [d]      -> Marcar/Desmarcar como tarea Por Defecto (Default)
--      [a]      -> Añadir una tarea personalizada nueva
--      [x]      -> Eliminar tarea personalizada o quitar marca por defecto
-- ============================================================================

local M = {}

-- Archivo donde se persisten las tareas custom por proyecto en formato JSON
local store_file = vim.fn.stdpath("data") .. "/project_tasks.json"

-- Función auxiliar: Cargar base de datos JSON de tareas
local function load_all_data()
	local f = io.open(store_file, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	return ok and type(data) == "table" and data or {}
end

-- Función auxiliar: Guardar base de datos JSON de tareas
local function save_all_data(data)
	local ok, encoded = pcall(vim.json.encode, data)
	if ok then
		local f = io.open(store_file, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

-- Obtener el directorio raíz del proyecto actual
function M.get_project_root()
	local current = vim.fn.expand("%:p:h")
	if current == "" then
		current = vim.fn.getcwd()
	end
	local root_files = { "Makefile", "package.json", "Cargo.toml", ".git", "go.mod", "pyproject.toml" }
	local match = vim.fs.find(root_files, { upward = true, path = current })
	if match and #match > 0 then
		return vim.fs.dirname(match[1])
	end
	return vim.fn.getcwd()
end

-- Descubrir tareas automáticamente examinando archivos de construcción del proyecto
function M.discover_tasks(root)
	local discovered = {}
	local norm_root = root:gsub("\\", "/")

	-- 1. Parsear Makefile
	local makefile = norm_root .. "/Makefile"
	if vim.fn.filereadable(makefile) == 1 then
		local lines = vim.fn.readfile(makefile)
		for _, line in ipairs(lines) do
			local target = line:match("^([a-zA-Z0-9_%-.]+):")
			if target and target ~= ".PHONY" and target ~= "all" and not target:find("^%.") then
				table.insert(discovered, { name = "make " .. target, cmd = "make " .. target, source = "Makefile" })
			end
		end
	end

	-- 2. Parsear package.json (Node.js / JS / TS)
	local pkg_json = norm_root .. "/package.json"
	if vim.fn.filereadable(pkg_json) == 1 then
		local content = table.concat(vim.fn.readfile(pkg_json), "\n")
		local ok, parsed = pcall(vim.json.decode, content)
		if ok and parsed and parsed.scripts then
			for script_name, _ in pairs(parsed.scripts) do
				table.insert(discovered, { name = "npm run " .. script_name, cmd = "npm run " .. script_name, source = "package.json" })
			end
		end
	end

	-- 3. Cargo.toml (Rust)
	local cargo = norm_root .. "/Cargo.toml"
	if vim.fn.filereadable(cargo) == 1 then
		table.insert(discovered, { name = "cargo run", cmd = "cargo run", source = "Cargo.toml" })
		table.insert(discovered, { name = "cargo build", cmd = "cargo build", source = "Cargo.toml" })
		table.insert(discovered, { name = "cargo test", cmd = "cargo test", source = "Cargo.toml" })
	end

	-- 4. go.mod (Go)
	local gomod = norm_root .. "/go.mod"
	if vim.fn.filereadable(gomod) == 1 then
		table.insert(discovered, { name = "go run .", cmd = "go run .", source = "go.mod" })
		table.insert(discovered, { name = "go test ./...", cmd = "go test ./...", source = "go.mod" })
	end

	return discovered
end

-- Obtener tareas guardadas para un proyecto en específico
function M.get_project_data(root)
	local key = root:gsub("\\", "/"):lower()
	local all = load_all_data()
	return all[key] or { default_task = nil, custom_tasks = {} }
end

-- Guardar datos de tareas para el proyecto
function M.save_project_data(root, pdata)
	local key = root:gsub("\\", "/"):lower()
	local all = load_all_data()
	all[key] = pdata
	save_all_data(all)
end

-- Ejecutar comando en una ventana de terminal en split inferior
function M.run_task_cmd(cmd, root)
	if not cmd or cmd == "" then
		vim.notify("No se especificó ningún comando", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	vim.cmd("silent! write")
	vim.cmd("botright 10split")
	local win = vim.api.nvim_get_current_win()
	vim.fn.termopen(cmd, { cwd = root })
	vim.cmd("startinsert")
	vim.notify("🚀 Ejecutando: " .. cmd .. " (CWD: " .. root .. ")", vim.log.levels.INFO, { title = "KRS Task Runner" })
end

-- Ejecutar la tarea por defecto o abrir el menú si no hay ninguna configurada
function M.run_default_or_menu()
	local root = M.get_project_root()
	local pdata = M.get_project_data(root)

	if pdata and pdata.default_task and pdata.default_task ~= "" then
		M.run_task_cmd(pdata.default_task, root)
	else
		M.open_task_menu()
	end
end

-- Abrir la interfaz interactiva de tareas en Telescope
function M.open_task_menu()
	local root = M.get_project_root()
	local pdata = M.get_project_data(root)
	local discovered = M.discover_tasks(root)

	local tasks = {}

	-- Tareas custom previamente guardadas
	for _, ct in ipairs(pdata.custom_tasks or {}) do
		table.insert(tasks, { name = ct.name or ct.cmd, cmd = ct.cmd, source = "custom", is_custom = true })
	end

	-- Tareas auto-descubiertas (sin duplicados)
	for _, dt in ipairs(discovered) do
		local exists = false
		for _, t in ipairs(tasks) do
			if t.cmd == dt.cmd then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(tasks, dt)
		end
	end

	if #tasks == 0 then
		-- Si no hay tareas detectadas, pedir una custom al usuario
		vim.ui.input({ prompt = "Sin tareas detectadas. Ingresa comando a ejecutar: " }, function(cmd)
			if cmd and cmd ~= "" then
				pdata.custom_tasks = pdata.custom_tasks or {}
				table.insert(pdata.custom_tasks, { name = cmd, cmd = cmd })
				pdata.default_task = cmd
				M.save_project_data(root, pdata)
				M.run_task_cmd(cmd, root)
			end
		end)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local themes = require("telescope.themes")

	local default_cmd = pdata.default_task or ""

	pickers.new(themes.get_dropdown({
		prompt_title = " 🛠️ Tareas del Proyecto (" .. vim.fn.fnamemodify(root, ":t") .. ") | [d]=Default [a]=Añadir [x]=Eliminar ",
		finder = finders.new_table({
			results = tasks,
			entry_maker = function(entry)
				local is_def = (entry.cmd == default_cmd)
				local tag = is_def and " ⭐ [DEFAULT]" or (" [" .. entry.source .. "]")
				local display = entry.name .. tag
				return {
					value = entry,
					display = display,
					ordinal = display .. " " .. entry.cmd,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			-- Enter: Ejecutar tarea elegida
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and selection.value then
					M.run_task_cmd(selection.value.cmd, root)
				end
			end)

			-- Tecla 'd': Marcar como Default
			local set_default = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					pdata.default_task = selection.value.cmd
					M.save_project_data(root, pdata)
					actions.close(prompt_bufnr)
					vim.notify("⭐ Tarea por defecto: " .. selection.value.cmd, vim.log.levels.INFO, { title = "KRS Task Runner" })
					vim.schedule(function()
						M.open_task_menu()
					end)
				end
			end
			map("i", "d", set_default)
			map("n", "d", set_default)

			-- Tecla 'a': Añadir Tarea Custom
			local add_custom = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Nuevo Comando de Tarea: " }, function(cmd)
						if cmd and cmd ~= "" then
							pdata.custom_tasks = pdata.custom_tasks or {}
							table.insert(pdata.custom_tasks, { name = cmd, cmd = cmd })
							M.save_project_data(root, pdata)
							M.open_task_menu()
						end
					end)
				end)
			end
			map("i", "a", add_custom)
			map("n", "a", add_custom)

			-- Tecla 'x': Eliminar Tarea
			local delete_task = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					local sel_cmd = selection.value.cmd
					if pdata.default_task == sel_cmd then
						pdata.default_task = nil
					end
					if pdata.custom_tasks then
						local new_custom = {}
						for _, ct in ipairs(pdata.custom_tasks) do
							if ct.cmd ~= sel_cmd then
								table.insert(new_custom, ct)
							end
						end
						pdata.custom_tasks = new_custom
					end
					M.save_project_data(root, pdata)
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_task_menu()
					end)
				end
			end
			map("i", "x", delete_task)
			map("n", "x", delete_task)

			return true
		end,
	}), {}):find()
end

return M

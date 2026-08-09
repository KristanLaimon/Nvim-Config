-- ============================================================================
-- 🦊 KRS CONFIG: Gestor de Tareas y Ejecutor de Código por Proyecto (Task Runner)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Detecta la raíz del proyecto usando vim.fs.find (busca .nvimkrs, package.json, Makefile, Cargo.toml, etc.).
-- 2. Escanea automáticamente scripts en Makefile, package.json, Cargo.toml o go.mod.
-- 3. Permite guardar tareas personalizadas y cadenas de tareas secuenciales en .nvimkrs.
-- 4. Soporta encadenamiento de tareas (Task Chains): si un paso falla, la cadena SE DETIENE inmediatamente
--    y abre un cuadro flotante de alerta de error en Neovim.
-- 5. Renderiza un menú interactivo en Telescope con accesos directos:
--      [Enter]  -> Ejecuta la tarea/cadena seleccionada
--      [d]      -> Marcar/Desmarcar como tarea Por Defecto (Default)
--      [a]      -> Añadir tarea individual nueva
--      [c]      -> Añadir Cadena de Tareas (Task Chain)
--      [x]      -> Eliminar tarea o quitar marca por defecto
-- ============================================================================

local M = {}

-- Archivo legacy donde se guardaban datos globales (mantenido para migración/fallback)
local legacy_store_file = vim.fn.stdpath("data") .. "/project_tasks.json"

local function load_legacy_data()
	local f = io.open(legacy_store_file, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	return ok and type(data) == "table" and data or {}
end

-- Obtener la ruta del archivo de configuración .nvimkrs del proyecto
local function get_krs_filepath(root)
	local norm_root = root:gsub("\\", "/")
	return norm_root .. "/.nvimkrs"
end

-- Obtener el directorio raíz del proyecto actual
function M.get_project_root()
	local current = vim.fn.expand("%:p:h")
	if current == "" then
		current = vim.fn.getcwd()
	end
	local root_files = { ".nvimkrs", "Makefile", "package.json", "Cargo.toml", ".git", "go.mod", "pyproject.toml" }
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

-- Obtener tareas guardadas desde .nvimkrs en la raíz del proyecto
function M.get_project_data(root)
	local filepath = get_krs_filepath(root)
	local f = io.open(filepath, "r")
	if f then
		local content = f:read("*a")
		f:close()
		local ok, data = pcall(vim.json.decode, content)
		if ok and type(data) == "table" then
			return {
				default_task = data.default_task,
				custom_tasks = type(data.custom_tasks) == "table" and data.custom_tasks or {},
			}
		end
	end

	-- Fallback a almacenamiento legacy si no existe .nvimkrs aún
	local key = root:gsub("\\", "/"):lower()
	local legacy_all = load_legacy_data()
	local legacy_data = legacy_all[key]
	if legacy_data then
		return legacy_data
	end

	return { default_task = nil, custom_tasks = {} }
end

-- Guardar datos de tareas en el archivo .nvimkrs de la raíz del proyecto
function M.save_project_data(root, pdata)
	local filepath = get_krs_filepath(root)
	local data_to_save = {
		default_task = pdata.default_task,
		custom_tasks = pdata.custom_tasks or {},
	}
	local ok, encoded = pcall(vim.json.encode, data_to_save)
	if ok then
		local f = io.open(filepath, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

-- Resolución de pasos individuales de una tarea (soporta cadenas y dependencias)
function M.resolve_steps(task_item, pdata)
	if not task_item then
		return {}
	end

	local steps = {}

	if type(task_item) == "string" then
		return { task_item }
	end

	if type(task_item) ~= "table" then
		return {}
	end

	-- 1. Si define dependencias previa (depends_on)
	if task_item.depends_on and type(task_item.depends_on) == "table" then
		for _, dep_name in ipairs(task_item.depends_on) do
			for _, ct in ipairs(pdata.custom_tasks or {}) do
				if (ct.name and ct.name == dep_name) or (ct.cmd and ct.cmd == dep_name) then
					local sub_steps = M.resolve_steps(ct, pdata)
					for _, s in ipairs(sub_steps) do
						table.insert(steps, s)
					end
				end
			end
		end
	end

	-- 2. Si define un arreglo de cadena (chain)
	if task_item.chain and type(task_item.chain) == "table" then
		for _, step in ipairs(task_item.chain) do
			if type(step) == "string" then
				table.insert(steps, step)
			end
		end
	elseif task_item.cmd and type(task_item.cmd) == "string" and task_item.cmd ~= "" then
		table.insert(steps, task_item.cmd)
	end

	return steps
end

-- Renderizar cuadro emergente flotante de error al fallar un paso en la cadena
local function show_failure_alert(step_idx, total_steps, failed_cmd, exit_code, remaining_count)
	local width = math.floor(vim.o.columns * 0.70)
	local lines = {
		" ❌ TASK CHAIN EXECUTION FAILED",
		string.rep("═", width - 4),
		string.format("  • Step %d of %d failed!", step_idx, total_steps),
		string.format("  • Failed Command: %s", failed_cmd),
		string.format("  • Exit Code: %d", exit_code),
		"",
		string.format(" ⛔ Execution HALTED. %d remaining task(s) CANCELLED.", remaining_count),
		"",
		" Press <Enter>, <Esc> or 'q' to close this alert and inspect logs below.",
	}
	local height = #lines + 2
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " 🚨 ALERT: Task Chain Interrupted ",
		title_pos = "center",
	})

	pcall(vim.api.nvim_set_option_value, "cursorline", false, { win = win })

	local function close_alert()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local kopts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set({ "n", "v", "i" }, "<CR>", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "<Esc>", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "q", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "<Space>", close_alert, kopts)
end

-- Variables globales para gestionar ventana y buffer de la tarea
M.task_win = nil
M.task_buf = nil

-- Ejecutar secuencia de pasos encadenados en el panel inferior
local function run_step_sequence(step_idx, steps, root, origin_win, task_name)
	local total = #steps
	local current_cmd = steps[step_idx]

	if step_idx == 1 then
		if M.task_win and vim.api.nvim_win_is_valid(M.task_win) then
			pcall(vim.api.nvim_win_close, M.task_win, true)
			M.task_win = nil
		end

		vim.cmd("botright 12split")
		M.task_win = vim.api.nvim_get_current_win()
		M.task_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(M.task_win, M.task_buf)

		vim.bo[M.task_buf].bufhidden = "wipe"
		vim.bo[M.task_buf].buflisted = false
		vim.bo[M.task_buf].filetype = "TaskRunner"

		vim.wo[M.task_win].number = false
		vim.wo[M.task_win].relativenumber = false
		vim.wo[M.task_win].signcolumn = "no"
	end

	local win = M.task_win
	local buf = M.task_buf

	vim.notify(
		string.format("🚀 Ejecutando Paso %d/%d: %s", step_idx, total, current_cmd),
		vim.log.levels.INFO,
		{ title = "KRS Task Runner" }
	)

	local job_id = vim.fn.termopen(current_cmd, {
		cwd = root,
		on_exit = function(_, exit_code, _)
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end

				if exit_code == 0 then
					if step_idx < total then
						-- Paso exitoso: Continuar con el siguiente paso en la cadena
						vim.notify(
							string.format("✅ Paso %d/%d completado. Iniciando Paso %d/%d...", step_idx, total, step_idx + 1, total),
							vim.log.levels.INFO,
							{ title = "KRS Task Runner" }
						)
						run_step_sequence(step_idx + 1, steps, root, origin_win, task_name)
					else
						-- Todos los pasos completados exitosamente
						pcall(vim.cmd, "stopinsert")
						if vim.api.nvim_win_is_valid(win) then
							pcall(vim.api.nvim_set_current_win, win)
						end

						local function close_task_window()
							if vim.api.nvim_win_is_valid(win) then
								pcall(vim.api.nvim_win_close, win, true)
							end
							if M.task_win == win then M.task_win = nil end
							if M.task_buf == buf then M.task_buf = nil end
							if origin_win and vim.api.nvim_win_is_valid(origin_win) then
								pcall(vim.api.nvim_set_current_win, origin_win)
							else
								pcall(vim.cmd, "wincmd p")
							end
						end

						local map_opts = { noremap = true, silent = true, buffer = buf }
						vim.keymap.set({ "n", "t" }, "<CR>", close_task_window, map_opts)
						vim.keymap.set({ "n", "t" }, "<Esc>", close_task_window, map_opts)
						vim.keymap.set({ "n", "t" }, "q", close_task_window, map_opts)
						vim.keymap.set({ "n", "t" }, "<Space>", close_task_window, map_opts)

						vim.notify(
							string.format("✅ Cadena de tareas '%s' (%d/%d pasos) finalizada con éxito. Presiona <Enter> para cerrar.", task_name or "Chain", total, total),
							vim.log.levels.INFO,
							{ title = "KRS Task Runner" }
						)
					end
				else
					-- ¡PASO FALLIDO! DETENER LA CADENA INMEDIATAMENTE Y MOSTRAR ALERTA
					pcall(vim.cmd, "stopinsert")
					if vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_set_current_win, win)
					end

					local function close_task_window()
						if vim.api.nvim_win_is_valid(win) then
							pcall(vim.api.nvim_win_close, win, true)
						end
						if M.task_win == win then M.task_win = nil end
						if M.task_buf == buf then M.task_buf = nil end
						if origin_win and vim.api.nvim_win_is_valid(origin_win) then
							pcall(vim.api.nvim_set_current_win, origin_win)
						else
							pcall(vim.cmd, "wincmd p")
						end
					end

					local map_opts = { noremap = true, silent = true, buffer = buf }
					vim.keymap.set({ "n", "t" }, "<CR>", close_task_window, map_opts)
					vim.keymap.set({ "n", "t" }, "<Esc>", close_task_window, map_opts)
					vim.keymap.set({ "n", "t" }, "q", close_task_window, map_opts)
					vim.keymap.set({ "n", "t" }, "<Space>", close_task_window, map_opts)

					local remaining = total - step_idx
					show_failure_alert(step_idx, total, current_cmd, exit_code, remaining)
				end
			end)
		end,
	})

	if job_id <= 0 then
		vim.notify("Error al iniciar el comando: " .. current_cmd, vim.log.levels.ERROR, { title = "KRS Task Runner" })
		return
	end

	vim.cmd("startinsert")
end

-- Ejecutar una tarea o cadena de tareas
function M.run_task_item(task_item, root)
	root = root or M.get_project_root()
	local pdata = M.get_project_data(root)
	local steps = M.resolve_steps(task_item, pdata)

	if #steps == 0 then
		vim.notify("No se encontraron pasos ejecutables para esta tarea", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	local origin_win = vim.api.nvim_get_current_win()
	vim.cmd("silent! write")

	local task_name = (type(task_item) == "table" and (task_item.name or task_item.cmd)) or tostring(task_item)
	run_step_sequence(1, steps, root, origin_win, task_name)
end

-- Wrapper de retrocompatibilidad
function M.run_task_cmd(cmd, root)
	M.run_task_item(cmd, root)
end

-- Ejecutar la tarea por defecto o abrir el menú si no hay ninguna configurada
function M.run_default_or_menu()
	local root = M.get_project_root()
	local pdata = M.get_project_data(root)

	if pdata and pdata.default_task then
		M.run_task_item(pdata.default_task, root)
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

	-- Tareas custom o cadenas previamente guardadas
	for _, ct in ipairs(pdata.custom_tasks or {}) do
		local steps = M.resolve_steps(ct, pdata)
		local name = ct.name or (type(ct.cmd) == "string" and ct.cmd) or "Chained Task"
		table.insert(tasks, {
			name = name,
			item = ct,
			steps_count = #steps,
			source = "custom",
			is_custom = true,
		})
	end

	-- Tareas auto-descubiertas (sin duplicados)
	for _, dt in ipairs(discovered) do
		local exists = false
		for _, t in ipairs(tasks) do
			if type(t.item) == "string" and t.item == dt.cmd then
				exists = true
				break
			elseif type(t.item) == "table" and t.item.cmd == dt.cmd then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(tasks, {
				name = dt.name,
				item = dt.cmd,
				steps_count = 1,
				source = dt.source,
			})
		end
	end

	if #tasks == 0 then
		-- Si no hay tareas detectadas, pedir una custom al usuario
		vim.ui.input({ prompt = "Sin tareas detectadas. Ingresa comando a ejecutar: " }, function(cmd)
			if cmd and cmd ~= "" then
				pdata.custom_tasks = pdata.custom_tasks or {}
				local new_t = { name = cmd, cmd = cmd }
				table.insert(pdata.custom_tasks, new_t)
				pdata.default_task = new_t
				M.save_project_data(root, pdata)
				M.run_task_item(new_t, root)
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

	local default_task = pdata.default_task

	pickers.new(themes.get_dropdown({
		prompt_title = " 🛠️ Tareas (" .. vim.fn.fnamemodify(root, ":t") .. ") | [d]=Default [a]=Añadir [c]=Cadena [x]=Eliminar ",
		finder = finders.new_table({
			results = tasks,
			entry_maker = function(entry)
				local is_def = false
				if default_task then
					if type(default_task) == "string" and (entry.name == default_task or entry.item == default_task) then
						is_def = true
					elseif type(default_task) == "table" and type(entry.item) == "table" and (default_task.name == entry.item.name or default_task.cmd == entry.item.cmd) then
						is_def = true
					end
				end

				local chain_tag = entry.steps_count > 1 and string.format(" 🔗 [%d pasos]", entry.steps_count) or ""
				local tag = is_def and " ⭐ [DEFAULT]" or (" [" .. entry.source .. "]" .. chain_tag)
				local display = entry.name .. tag
				return {
					value = entry,
					display = display,
					ordinal = display .. " " .. entry.name,
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
					M.run_task_item(selection.value.item, root)
				end
			end)

			-- Tecla 'd': Marcar como Default
			local set_default = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					pdata.default_task = selection.value.item
					M.save_project_data(root, pdata)
					actions.close(prompt_bufnr)
					vim.notify("⭐ Tarea por defecto guardada", vim.log.levels.INFO, { title = "KRS Task Runner" })
					vim.schedule(function()
						M.open_task_menu()
					end)
				end
			end
			map("i", "d", set_default)
			map("n", "d", set_default)

			-- Tecla 'a': Añadir Tarea Custom Individual
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

			-- Tecla 'c': Añadir Cadena de Tareas (Task Chain)
			local add_chain = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Nombre de la Cadena (ej. Build & Test): " }, function(chain_name)
						if not chain_name or chain_name == "" then return end
						vim.ui.input({ prompt = "Pasos en cadena (separados por '&&' o ','): " }, function(raw_steps)
							if not raw_steps or raw_steps == "" then return end
							local steps = {}
							for step in raw_steps:gmatch("[^&,]+") do
								local clean = step:gsub("^%s*", ""):gsub("%s*$", "")
								if clean ~= "" then
									table.insert(steps, clean)
								end
							end
							if #steps > 0 then
								pdata.custom_tasks = pdata.custom_tasks or {}
								table.insert(pdata.custom_tasks, { name = chain_name, chain = steps })
								M.save_project_data(root, pdata)
								vim.notify("🔗 Cadena de tareas guardada: " .. chain_name .. " (" .. #steps .. " pasos)", vim.log.levels.INFO, { title = "KRS Task Runner" })
							end
							M.open_task_menu()
						end)
					end)
				end)
			end
			map("i", "c", add_chain)
			map("n", "c", add_chain)

			-- Tecla 'x': Eliminar Tarea
			local delete_task = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					local sel_item = selection.value.item
					if pdata.default_task == sel_item then
						pdata.default_task = nil
					end
					if pdata.custom_tasks then
						local new_custom = {}
						for _, ct in ipairs(pdata.custom_tasks) do
							if ct ~= sel_item and ct.name ~= selection.value.name then
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

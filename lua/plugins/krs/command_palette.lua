-- ============================================================================
-- 🦊 KRS PLUGIN: Paleta de Comandos Estilo VSCode (Ctrl + Shift + P)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE PLUGIN?
-- 1. Se activa con <Ctrl+Shift+P> desde cualquier modo (Normal, Insert, Visual, Terminal).
-- 2. Presenta un buscador tipo Telescope con búsqueda difusa (loose string search).
-- 3. Utiliza una lista array configurable (`M.commands`) que soporta 3 tipos de acciones:
--      a) `cmd`: Ejecuta un comando de Neovim/Vimscript (ej. "Telescope find_files", "Lazy", "Mason")
--      b) `keys`: Simula la presión de un atajo de teclado (ej. "<C-k>", "<leader>e", "<F2>")
--      c) `fn`: Ejecuta una función personalizada de Lua directamente.
-- 4. Puedes añadir tus propios comandos en runtime usando `M.add_command({ ... })`.
-- ============================================================================

local M = {}

-- Array de comandos configurables por el usuario
M.commands = {
	-- --------------------------------------------------------------------------
	-- 📁 Archivos y Búsqueda
	-- --------------------------------------------------------------------------
	{ name = "🔍 Buscar Archivos (Find Files ROBERTO)", keys = "<C-k>", category = "Archivos" },
	{ name = "📝 Buscar Texto en Archivos (Live Grep)", keys = "<C-f>", category = "Archivos" },
	{ name = "📂 Abrir Carpeta (Open Folder)", keys = "<C-S-o>", category = "Archivos" },
	{ name = "⭐ Proyectos Recientes (Recent Projects)", keys = "<C-S-r>", category = "Archivos" },
	{ name = "📌 Menú Harpoon", keys = "<leader>hh", category = "Archivos" },
	{ name = "📌 Añadir Archivo Actual a Harpoon", keys = "<leader>ha", category = "Archivos" },

	-- --------------------------------------------------------------------------
	-- 🦊 Workspaces y Sesiones
	-- --------------------------------------------------------------------------
	{ name = "💼 Seleccionar Workspace (Workspaces UI)", cmd = "WorkspaceSelect", category = "Workspace" },
	{ name = "💾 Guardar Workspace Actual", cmd = "WorkspaceSave", category = "Workspace" },
	{ name = "🚪 Cerrar Workspace e ir al Menú Principal", cmd = "WorkspaceClose", category = "Workspace" },

	-- --------------------------------------------------------------------------
	-- 🛠️ Tareas y Ejecución de Código
	-- --------------------------------------------------------------------------
	{ name = "🚀 Ejecutar Tarea por Defecto del Proyecto", keys = "<C-S-a>", category = "Tareas" },
	{ name = "🛠️ Abrir Menú de Tareas del Proyecto", keys = "<leader>ta", category = "Tareas" },

	-- --------------------------------------------------------------------------
	-- 🌲 Explorador de Archivos y Git
	-- --------------------------------------------------------------------------
	{ name = "🌳 Alternar Explorador de Archivos (Neo-tree)", cmd = "Neotree toggle", category = "Explorador" },
	{ name = "🏷️ Renombrar Archivo Actual (F2)", keys = "<F2>", category = "Explorador" },
	{ name = "🐙 Alternar Panel de Git (Neogit)", cmd = "Neogit", category = "Git" },

	-- --------------------------------------------------------------------------
	-- 💻 Terminales
	-- --------------------------------------------------------------------------
	{ name = "💻 Alternar Terminal 1", keys = "<C-;>", category = "Terminal" },
	{ name = "💻 Alternar Terminal 2", keys = "<leader>t2", category = "Terminal" },
	{ name = "💻 Alternar Terminal 3", keys = "<leader>t3", category = "Terminal" },

	-- --------------------------------------------------------------------------
	-- 🧠 LSP, Diagnósticos y Formato
	-- --------------------------------------------------------------------------
	{ name = "💡 Quick-Fix / Acciones de Código (VSCode)", keys = "<C-.>", category = "LSP" },
	{ name = "🎯 Ir a Definición de Símbolo", keys = "<A-j>", category = "LSP" },
	{ name = "⚠️ Ver Detalle de Error / Diagnóstico en Cursor", keys = "<A-k>", category = "LSP" },
	{ name = "🎨 Formatear Archivo (Conform)", keys = "<leader>f", category = "LSP" },
	{ name = "ℹ️ Información del Servidor LSP", cmd = "LspInfo", category = "LSP" },
	{ name = "📦 Administrador de Servidores (Mason)", cmd = "Mason", category = "LSP" },

	-- --------------------------------------------------------------------------
	-- 🎨 Interfaz y Configuración
	-- --------------------------------------------------------------------------
	{ name = "🔍 Aumentar Tamaño de Fuente", cmd = "FontSizeIncrease", category = "Interfaz" },
	{ name = "🔍 Disminuir Tamaño de Fuente", cmd = "FontSizeDecrease", category = "Interfaz" },
	{ name = "🔍 Restablecer Tamaño de Fuente", cmd = "FontSizeReset", category = "Interfaz" },
	{ name = "🖼️ Ver Imagen con Chafa", keys = "<leader>i", category = "Interfaz" },
	{ name = "🧩 Administrador de Plugins (Lazy)", cmd = "Lazy", category = "Configuración" },
	{ name = "🔄 Recargar Configuración de Neovim", cmd = "ReloadConfig", category = "Configuración" },
	{ name = "🚪 Salir de Neovim (Quit All)", cmd = "qa", category = "Sistema" },
}

-- Función pública para agregar comandos dinámicamente desde cualquier plugin o config
function M.add_command(item)
	if type(item) == "table" and item.name then
		table.insert(M.commands, item)
	end
end

-- Ejecutar la acción asociada a la entrada seleccionada
local function execute_item(item)
	if not item then
		return
	end

	if item.cmd then
		-- Ejecutar comando Neovim/Vimscript
		vim.cmd(item.cmd)
	elseif item.keys then
		-- Simular la pulsación de teclas usando nvim_feedkeys
		local termcodes = vim.api.nvim_replace_termcodes(item.keys, true, false, true)
		vim.api.nvim_feedkeys(termcodes, "m", false)
	elseif item.fn and type(item.fn) == "function" then
		-- Ejecutar función Lua directamente
		item.fn()
	end
end

-- Abrir la Paleta de Comandos con Telescope
function M.open_palette()
	local ok_telescope, _ = pcall(require, "telescope")
	if not ok_telescope then
		vim.notify(
			"Telescope no está disponible para la Paleta de Comandos",
			vim.log.levels.ERROR,
			{ title = "Command Palette" }
		)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local themes = require("telescope.themes")

	pickers
		.new(
			themes.get_dropdown({
				prompt_title = " 🚀🦊 Paleta de Comandos (Ctrl+Shift+P) ",
				width = 0.75,
				results_title = "Comandos Disponibles",
			}),
			{
				finder = finders.new_table({
					results = M.commands,
					entry_maker = function(entry)
						local category = entry.category or "General"
						local shortcut = entry.keys or entry.cmd or ""
						local display_str =
							string.format("[%s] %s %s", category, entry.name, shortcut ~= "" and ("(" .. shortcut .. ")") or "")

						return {
							value = entry,
							display = display_str,
							-- Ordinal para la búsqueda difusa (loose search across name, category and action)
							ordinal = category .. " " .. entry.name .. " " .. shortcut,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection and selection.value then
							vim.schedule(function()
								execute_item(selection.value)
							end)
						end
					end)
					return true
				end,
			}
		)
		:find()
end

_G.CommandPalette = M

-- Especificación del Plugin para Lazy.nvim
local plugin_spec = {
	"nvim-telescope/telescope.nvim",
	cmd = "CommandPalette",
	keys = {
		{
			"<C-S-p>",
			function()
				M.open_palette()
			end,
			mode = { "n", "i", "v", "t" },
			desc = "Command Palette",
		},
		{
			"<C-S-P>",
			function()
				M.open_palette()
			end,
			mode = { "n", "i", "v", "t" },
			desc = "Command Palette",
		},
	},
	config = function()
		vim.api.nvim_create_user_command("CommandPalette", function()
			M.open_palette()
		end, { desc = "Abrir Paleta de Comandos" })

		-- Keymaps globales
		local modes = { "n", "i", "v", "t" }
		vim.keymap.set(modes, "<C-S-p>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_palette()
		end, { noremap = true, silent = true, desc = "Abrir Paleta de Comandos" })

		vim.keymap.set(modes, "<C-S-P>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_palette()
		end, { noremap = true, silent = true, desc = "Abrir Paleta de Comandos" })
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

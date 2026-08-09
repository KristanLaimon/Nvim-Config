-- ============================================================================
-- 🦊 KRS CONFIG: Sistema de Ayuda Contextual Ultra-Limpio (Context-Aware Help)
-- ============================================================================
-- 1. Detecta automáticamente el contexto (Neo-Tree, Git, Explorador, Editor).
-- 2. Presionar '?' o <F1> muestra una notificación minimalista de 4-5 líneas
--    con ÚNICAMENTE las teclas clave necesarias. Cero ruido, cero relleno.
-- ============================================================================

local M = {}

-- Detectar el contexto actual según el filetype y nombre de buffer
function M.get_context()
	local ft = vim.bo.filetype
	local buf_name = vim.api.nvim_buf_get_name(0)

	if ft == "neo-tree" then
		return "neotree"
	elseif ft:find("Neogit") or ft:find("Diffview") or ft:find("git") or buf_name:find("Git") then
		return "git"
	elseif ft == "TelescopePrompt" or ft == "TaskRunner" or buf_name:find("Telescope") or buf_name:find("project_tasks") then
		return "telescope"
	else
		return "editor"
	end
end

-- Mostrar notificación minimalista sin ruido
function M.show_help()
	local context = M.get_context()
	local title = ""
	local help_lines = {}

	if context == "neotree" then
		title = "🌳 Neo-Tree (Explorador)"
		help_lines = {
			"a : Crear Archivo   | A : Crear Carpeta",
			"r : Renombrar       | d : Eliminar",
			"c : Copiar          | x : Cortar | p : Pegar",
			"q : Cerrar explorador",
		}
	elseif context == "git" then
		title = "🦊 Git Center"
		help_lines = {
			"1..4: Ir a Sección 1, 2, 3 o 4",
			"Ctrl+Shift+J/K: Desplazar texto del visor derecho (scroll)",
			"s/S : Stage Archivo / Stage Todo",
			"u/U : Unstage Archivo / Unstage Todo",
			"c : Editar Título Commit | C : Commit & Tag",
			"Tab: Cambiar foco entre lista y preview",
			"d : Ver Diffview | q : Cerrar panel",
		}
	elseif context == "telescope" then
		title = "📁 Explorador de Archivos"
		help_lines = {
			"a : Crear (archivo.txt o carpeta/)",
			"r : Renombrar       | d : Eliminar",
			"c : Copiar          | m : Mover / Cortar",
			"o : Abrir Carpeta como Proyecto (CWD)",
			"Tab: Seleccionar varios en bloque",
		}
	else
		title = "⚡ Atajos Clave del Editor"
		help_lines = {
			"Ctrl + K        : Buscar Archivo por Nombre",
			"Ctrl + Shift + H/J/K/L : Buscar Archivo y Abrir en Split (← ↓ ↑ →)",
			"Ctrl + F        : Buscar Texto en Proyecto",
			"Ctrl + Shift + F: Explorador Flotante (Desktop)",
			"Ctrl + Shift + T: Menú de Tareas del Proyecto",
			"Alt + 1..9      : Terminal 1 a 9  |  Ctrl + ; : Toggle Terminal",
		}
	end

	local msg = table.concat(help_lines, "\n")
	vim.notify(msg, vim.log.levels.INFO, { title = title })
end

function M.setup()
	vim.keymap.set("n", "?", function()
		M.show_help()
	end, { noremap = true, silent = true, desc = "Ayuda Contextual" })

	vim.keymap.set("n", "<F1>", function()
		M.show_help()
	end, { noremap = true, silent = true, desc = "Ayuda Contextual" })
end

return M

-- ============================================================================
-- 🦊 KRS CONFIG: Previsualización en Vivo de Temas (Live Colorscheme Previewer)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Escucha eventos de la línea de comandos de Vim (`CmdlineChanged` y `CmdlineLeave`).
-- 2. Cuando escribes `:colorscheme <tema>` y navegas con `<Tab>`, captura el nombre del tema.
-- 3. Aplica temporalmente el tema en tiempo real para vista previa instantánea (`pcall(vim.cmd.colorscheme, name)`).
-- 4. Si cancelas la entrada (presionas Esc sin presionar Enter), restaura automáticamente el tema original anterior (`vim.v.event.abort`).
-- ============================================================================

local M = {}

local colorscheme_preview_orig = nil

function M.setup()
	local group = vim.api.nvim_create_augroup("KRSColorschemeLivePreview", { clear = true })

	-- Evento 1: Se modifica el texto en la línea de comandos
	vim.api.nvim_create_autocmd("CmdlineChanged", {
		group = group,
		callback = function()
			if vim.fn.getcmdtype() ~= ":" then
				return
			end

			local cmdline = vim.fn.getcmdline()
			local name = cmdline:match("^colo%S*%s+(%S+)%s*$")

			if not name then
				return
			end

			-- Recordar el tema inicial antes de previsualizar
			if colorscheme_preview_orig == nil then
				colorscheme_preview_orig = vim.g.colors_name
			end

			pcall(vim.cmd.colorscheme, name)
		end,
	})

	-- Evento 2: Se abandona o confirma la línea de comandos
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		callback = function()
			if vim.fn.getcmdtype() ~= ":" then
				return
			end

			local cmdline = vim.fn.getcmdline()
			local applied = cmdline:match("^colo%S*%s+(%S+)%s*$")

			-- Si fue cancelado con Esc (abort = true) y no se aplicó -> revertir al tema previo
			if colorscheme_preview_orig and vim.v.event.abort and not applied then
				pcall(vim.cmd.colorscheme, colorscheme_preview_orig)
			end

			colorscheme_preview_orig = nil
		end,
	})
end

return M

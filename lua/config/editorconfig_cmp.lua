local PROPERTIES = {
	root = {
		desc = "Declaración al inicio del archivo. Si es 'true', EditorConfig deja de buscar en directorios superiores.",
		values = {
			{ label = "true", desc = "Marca este directorio como la raíz del proyecto." },
			{ label = "false", desc = "Continúa buscando en directorios superiores." },
		},
	},
	indent_style = {
		desc = "Define si se usan espacios o tabulaciones para la sangría.",
		values = {
			{ label = "space", desc = "Usar espacios para sangrar." },
			{ label = "tab", desc = "Usar caracteres de tabulación para sangrar." },
		},
	},
	indent_size = {
		desc = "Número de espacios por nivel de sangría (o 'tab' para usar tab_width).",
		values = {
			{ label = "2", desc = "2 espacios por nivel." },
			{ label = "4", desc = "4 espacios por nivel." },
			{ label = "8", desc = "8 espacios por nivel." },
			{ label = "tab", desc = "Usar el mismo valor que tab_width." },
		},
	},
	tab_width = {
		desc = "Ancho visual equivalente a una tabulación.",
		values = {
			{ label = "2", desc = "2 caracteres de ancho." },
			{ label = "4", desc = "4 caracteres de ancho." },
			{ label = "8", desc = "8 caracteres de ancho." },
		},
	},
	end_of_line = {
		desc = "Estilo de carácter de fin de línea.",
		values = {
			{ label = "lf", desc = "Salto de línea Unix/macOS/Linux (LF)." },
			{ label = "crlf", desc = "Salto de línea Windows (CRLF)." },
			{ label = "cr", desc = "Salto de línea Classic Mac (CR)." },
		},
	},
	charset = {
		desc = "Codificación de caracteres del archivo.",
		values = {
			{ label = "utf-8", desc = "UTF-8 sin BOM (Estándar recomendado)." },
			{ label = "utf-8-bom", desc = "UTF-8 con marca de orden de bytes (BOM)." },
			{ label = "utf-16be", desc = "UTF-16 Big Endian." },
			{ label = "utf-16le", desc = "UTF-16 Little Endian." },
			{ label = "latin1", desc = "Codificación ISO-8859-1." },
		},
	},
	trim_trailing_whitespace = {
		desc = "Elimina los espacios en blanco sobrantes al final de cada línea al guardar.",
		values = {
			{ label = "true", desc = "Eliminar espacios sobrantes al final." },
			{ label = "false", desc = "Mantener espacios sobrantes al final." },
		},
	},
	insert_final_newline = {
		desc = "Garantiza que el archivo termine con un salto de línea al guardar.",
		values = {
			{ label = "true", desc = "Añadir salto de línea al final del archivo." },
			{ label = "false", desc = "No forzar salto de línea final." },
		},
	},
	max_line_length = {
		desc = "Longitud máxima recomendada de caracteres por línea.",
		values = {
			{ label = "80", desc = "Límite estándar de 80 caracteres." },
			{ label = "100", desc = "Límite de 100 caracteres." },
			{ label = "120", desc = "Límite moderno de 120 caracteres." },
			{ label = "off", desc = "Desactivar límite de longitud." },
		},
	},
}

local SECTION_TEMPLATES = {
	{ label = "[*]", desc = "Aplica a todos los archivos del proyecto." },
	{ label = "[*.{js,ts,jsx,tsx}]", desc = "Aplica a archivos JavaScript y TypeScript." },
	{ label = "[*.py]", desc = "Aplica a archivos Python." },
	{ label = "[*.lua]", desc = "Aplica a archivos Lua." },
	{ label = "[*.json]", desc = "Aplica a archivos JSON." },
	{ label = "[*.md]", desc = "Aplica a archivos Markdown." },
	{ label = "[*.css]", desc = "Aplica a archivos CSS." },
	{ label = "[*.html]", desc = "Aplica a archivos HTML." },
	{ label = "[Makefile]", desc = "Aplica al archivo Makefile." },
}

local M = {
	PROPERTIES = PROPERTIES,
	SECTION_TEMPLATES = SECTION_TEMPLATES,
}

function M.new(opts)
	return setmetatable({}, { __index = M })
end

function M:get_completions(context, callback)
	local line = context.line or ""
	local col = context.cursor[2]
	local line_before = string.sub(line, 1, col)

	local items = {}

	local key = line_before:match("^%s*([%w_]+)%s*=")
	if key then
		key = vim.trim(key)
		local prop = PROPERTIES[key]
		if prop and prop.values then
			for _, v in ipairs(prop.values) do
				table.insert(items, {
					label = v.label,
					kind = vim.lsp.protocol.CompletionItemKind.Value,
					detail = "EditorConfig Valor",
					documentation = {
						kind = "markdown",
						value = v.desc .. "\n\n*Propiedad:* `" .. key .. "`",
					},
					insertText = v.label,
				})
			end
		end
	elseif line_before:match("^%s*%[") then
		for _, s in ipairs(SECTION_TEMPLATES) do
			table.insert(items, {
				label = s.label,
				kind = vim.lsp.protocol.CompletionItemKind.Struct,
				detail = "Sección EditorConfig",
				documentation = {
					kind = "markdown",
					value = s.desc,
				},
				insertText = s.label,
			})
		end
	else
		-- Key completions
		for prop_key, prop_info in pairs(PROPERTIES) do
			table.insert(items, {
				label = prop_key,
				kind = vim.lsp.protocol.CompletionItemKind.Property,
				detail = "Propiedad EditorConfig",
				documentation = {
					kind = "markdown",
					value = prop_info.desc,
				},
				insertText = prop_key .. " = ",
			})
		end

		if #vim.trim(line_before) == 0 then
			for _, s in ipairs(SECTION_TEMPLATES) do
				table.insert(items, {
					label = s.label,
					kind = vim.lsp.protocol.CompletionItemKind.Struct,
					detail = "Sección EditorConfig",
					documentation = {
						kind = "markdown",
						value = s.desc,
					},
					insertText = s.label,
				})
			end
		end
	end

	callback({
		is_incomplete_forward = false,
		is_incomplete_backward = false,
		items = items,
	})
end

return M

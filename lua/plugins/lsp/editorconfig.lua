local cmp_module = require("config.editorconfig_cmp")
local PROPERTIES = cmp_module.PROPERTIES
local ns = vim.api.nvim_create_namespace("editorconfig_intellisense")

local function validate_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ft = vim.bo[bufnr].filetype
	local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
	if ft ~= "editorconfig" and ft ~= "dosini" and filename ~= ".editorconfig" then
		return
	end

	local diagnostics = {}
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, line in ipairs(lines) do
		local trimmed = vim.trim(line)
		-- Ignorar líneas vacías, comentarios (#, ;) y cabeceras de sección [...]
		if trimmed ~= "" and not trimmed:match("^[#;]") and not trimmed:match("^%[.*%]$") then
			local key, val = trimmed:match("^([%w_]+)%s*=%s*(.-)%s*$")
			if key then
				local prop = PROPERTIES[key]
				if not prop then
					table.insert(diagnostics, {
						lnum = i - 1,
						col = 0,
						end_col = #key,
						severity = vim.diagnostic.severity.WARN,
						message = "Propiedad desconocida de EditorConfig: '" .. key .. "'",
						source = "EditorConfig",
					})
				elseif prop.values and val ~= "" then
					local valid = false
					for _, v in ipairs(prop.values) do
						if v.label == val then
							valid = true
							break
						end
					end
					if
						not valid
						and tonumber(val)
						and (key == "indent_size" or key == "tab_width" or key == "max_line_length")
					then
						valid = true
					end

					if not valid then
						local allowed = {}
						for _, v in ipairs(prop.values) do
							table.insert(allowed, v.label)
						end
						table.insert(diagnostics, {
							lnum = i - 1,
							col = line:find("=") or 0,
							end_col = #line,
							severity = vim.diagnostic.severity.ERROR,
							message = "Valor no válido '"
								.. val
								.. "' para '"
								.. key
								.. "'. Valores permitidos: "
								.. table.concat(allowed, ", "),
							source = "EditorConfig",
						})
					end
				end
			end
		end
	end

	vim.diagnostic.set(ns, bufnr, diagnostics)
end

local function show_hover()
	local word = vim.fn.expand("<cword>")
	local prop = PROPERTIES[word]

	if not prop then
		local line = vim.api.nvim_get_current_line()
		local key = line:match("^%s*([%w_]+)%s*=")
		if key and PROPERTIES[key] then
			prop = PROPERTIES[key]
			word = key
		end
	end

	if prop then
		local lines = {
			"# " .. word .. " (EditorConfig)",
			"",
			prop.desc,
			"",
			"### Valores permitidos:",
		}
		for _, v in ipairs(prop.values) do
			table.insert(lines, "• `" .. v.label .. "`: " .. v.desc)
		end

		local floating_opts = {
			border = "rounded",
			focus_id = "editorconfig_hover",
		}

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].filetype = "markdown"

		vim.lsp.util.open_floating_preview(lines, "markdown", floating_opts)
	else
		vim.lsp.buf.hover()
	end
end

-- Asegurar tipo de archivo .editorconfig
vim.filetype.add({
	filename = {
		[".editorconfig"] = "editorconfig",
	},
})

-- Autocomandos para diagnóstico y keybind 'K'
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "TextChanged", "TextChangedI" }, {
	pattern = { ".editorconfig", "*.editorconfig" },
	callback = function(args)
		validate_buffer(args.buf)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "editorconfig", "dosini" },
	callback = function(args)
		validate_buffer(args.buf)
		vim.keymap.set("n", "K", show_hover, { buffer = args.buf, desc = "EditorConfig Hover Documentation" })
	end,
})

return {
	{
		"saghen/blink.cmp",
		opts = function(_, opts)
			opts.sources = opts.sources or {}
			opts.sources.providers = opts.sources.providers or {}
			opts.sources.providers.editorconfig = {
				name = "EditorConfig",
				module = "config.editorconfig_cmp",
				score_offset = 100,
				enabled = function()
					local ft = vim.bo.filetype
					local name = vim.fn.expand("%:t")
					return ft == "editorconfig" or ft == "dosini" or name == ".editorconfig"
				end,
			}

			if opts.sources.default and not vim.tbl_contains(opts.sources.default, "editorconfig") then
				table.insert(opts.sources.default, "editorconfig")
			end
		end,
	},
}

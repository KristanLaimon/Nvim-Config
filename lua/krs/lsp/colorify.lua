-- ============================================================================
-- KRS LSP: Colorify -- Hex color extraction & NvChad completion styling.
-- ============================================================================
-- Formats completion kind icons with distinct background & accent colors per kind,
-- provides contrast-aware dynamic background colors for CSS/Tailwind hex values,
-- and formats kind name labels on the right.
-- ============================================================================

local M = {}

--- Default Nerdfont icons matching NvChad completion layout.
M.kind_icons = {
	Text = "󰉿",
	Method = "󰆧",
	Function = "󰊕",
	Constructor = "",
	Field = "󰜢",
	Variable = "󰀫",
	Class = "󰌗",
	Interface = "",
	Module = "",
	Property = "󰜢",
	Unit = "󰑭",
	Value = "󰎠",
	Enum = "",
	Keyword = "󰌋",
	Snippet = "󰩫",
	Color = "󰏘",
	File = "󰈙",
	Reference = "EF",
	Folder = "󰉋",
	EnumMember = "",
	Constant = "󰏿",
	Struct = "󰙅",
	Event = "",
	Operator = "󰆕",
	TypeParameter = "󰅲",
}

--- Kind-to-palette color mapping for default fallback highlights.
M.kind_colors = {
	Function = { bg = "#E3A70E", fg = "#151515" },
	Method = { bg = "#E3A70E", fg = "#151515" },
	Constructor = { bg = "#E3A70E", fg = "#151515" },
	Snippet = { bg = "#D233A2", fg = "#FFFFFF" },
	Variable = { bg = "#d776ae", fg = "#151515" },
	Constant = { bg = "#d776ae", fg = "#151515" },
	Value = { bg = "#d776ae", fg = "#151515" },
	Keyword = { bg = "#6d7fd4", fg = "#FFFFFF" },
	Statement = { bg = "#6d7fd4", fg = "#FFFFFF" },
	Class = { bg = "#5cd7d7", fg = "#151515" },
	Interface = { bg = "#5cd7d7", fg = "#151515" },
	Struct = { bg = "#5cd7d7", fg = "#151515" },
	TypeParameter = { bg = "#5cd7d7", fg = "#151515" },
	Enum = { bg = "#5cd7d7", fg = "#151515" },
	Field = { bg = "#62e665", fg = "#151515" },
	Property = { bg = "#62e665", fg = "#151515" },
	Operator = { bg = "#62e665", fg = "#151515" },
	Module = { bg = "#d2824e", fg = "#151515" },
	Folder = { bg = "#d2824e", fg = "#151515" },
	File = { bg = "#95acbd", fg = "#151515" },
	Text = { bg = "#5b574a", fg = "#FFFFFF" },
	Color = { bg = "#5cd7d7", fg = "#151515" },
}

--- Calculates contrasting foreground text color (black or white) for a given hex background.
--- @param hex string e.g. "#ff0055"
--- @return string fg "#151515" or "#ffffff"
function M.get_contrast_fg(hex)
	if not hex or #hex < 7 then
		return "#ffffff"
	end
	local r = tonumber(hex:sub(2, 3), 16) or 255
	local g = tonumber(hex:sub(4, 5), 16) or 255
	local b = tonumber(hex:sub(6, 7), 16) or 255
	local luminance = (0.299 * r + 0.587 * g + 0.114 * b)
	if luminance > 140 then
		return "#151515"
	end
	return "#ffffff"
end

--- Parses a hex color string from input text (e.g. #fff, #123456, #abcdef00, rgb(255, 0, 0)).
--- @param str string|nil
--- @return string|nil hex_code
function M.extract_hex_color(str)
	if not str or type(str) ~= "string" then
		return nil
	end

	-- 6 or 8-digit hex
	local hex6 = str:match("#(%x%x%x%x%x%x)")
	if hex6 then
		return "#" .. hex6
	end

	-- 3-digit hex (#f00 -> #ff0000)
	local hex3 = str:match("^#(%x%x%x)%s*$") or str:match("%s#(%x%x%x)%s*$") or str:match("^#(%x%x%x)[%s;,\"'%)]")
	if hex3 then
		local r, g, b = hex3:sub(1, 1), hex3:sub(2, 2), hex3:sub(3, 3)
		return "#" .. r .. r .. g .. g .. b .. b
	end

	-- rgb(r, g, b)
	local r, g, b = str:match("rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
	if r and g and b then
		local nr, ng, nb = tonumber(r), tonumber(g), tonumber(b)
		if nr and ng and nb and nr <= 255 and ng <= 255 and nb <= 255 then
			return string.format("#%02x%02x%02x", nr, ng, nb)
		end
	end

	return nil
end

--- Generates or reuses a Neovim highlight group for a color hex string with background color.
--- @param hex string
--- @return string hl_name
function M.get_or_create_color_hl(hex)
	if not hex or type(hex) ~= "string" then
		return "Normal"
	end
	local sanitized = hex:gsub("#", "")
	local hl_name = "CmpColor_" .. sanitized
	local fg = M.get_contrast_fg(hex)
	pcall(vim.api.nvim_set_hl, 0, hl_name, { fg = fg, bg = hex, bold = true })
	return hl_name
end

--- Gets or initializes highlight group for a completion item kind with background and accent color.
--- @param kind string|nil
--- @return string hl_name
function M.get_kind_hl(kind)
	if not kind or kind == "" then
		kind = "Text"
	end

	local hl_name = "CmpKindBg_" .. kind
	local existing = vim.api.nvim_get_hl(0, { name = hl_name })
	if existing and (existing.bg or existing.fg) then
		return hl_name
	end

	-- Fallback highlight setup if theme hasn't declared CmpKindBg_<Kind>
	local spec = M.kind_colors[kind] or M.kind_colors.Text
	pcall(vim.api.nvim_set_hl, 0, hl_name, { fg = spec.fg, bg = spec.bg, bold = true })
	return hl_name
end

--- Formats completion item kind text on the right side of completion list (e.g. `<Snippet>`, `<Function>`).
--- @param kind string|nil
--- @return string formatted
function M.format_kind_label(kind)
	if not kind or kind == "" then
		return "<Item>"
	end
	return "<" .. kind .. ">"
end

--- Gets icon string for a completion item kind with NvChad-style padding.
--- @param kind string|nil
--- @return string icon
function M.get_kind_icon(kind)
	if not kind then
		return " 󰉿 "
	end
	local icon = M.kind_icons[kind] or "󰉿"
	return " " .. icon .. " "
end

return M

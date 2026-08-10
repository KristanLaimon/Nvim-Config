-- ============================================================================
-- 🦊 KRS PLUGIN: Tailwind Classes Organizer
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Can be toggled ON/OFF via Command Palette (`<C-S-p>`) or user command `:TailwindOrganizerToggle`.
-- 2. When active, automatically organizes `class="..."` / `className="..."` on save.
-- 3. Can also be run on-demand using `:TailwindOrganize` (or `<leader>tw`).
-- 4. Multi-row categorization rules:
--      Row 1: Size, Position & CORE Layout properties (flex, grid, absolute, w-*, h-*, z-*, items-*, etc.) - Alphabetized!
--      Row 2: Aesthetic Basic properties (colors, typography, spacing/padding/margin, borders, text-align, etc.) - Alphabetized!
--      Row 3+: Dedicated row for EACH responsive screen size (sm:*, md:*, lg:*, xl:*, 2xl:*, etc.) - Alphabetized!
-- ============================================================================

local M = {}

M.enabled = true
M.config = {
	auto_format_on_save = true,
	force_multiline = false,
}

-- Screen size breakpoint priority order
local SCREEN_SIZE_ORDER = {
	["sm"] = 1,
	["md"] = 2,
	["lg"] = 3,
	["xl"] = 4,
	["2xl"] = 5,
	["max-sm"] = 6,
	["max-md"] = 7,
	["max-lg"] = 8,
	["max-xl"] = 9,
	["max-2xl"] = 10,
	["portrait"] = 11,
	["landscape"] = 12,
}

-- Exact display/position/layout values for Row 1
local EXACT_LAYOUT = {
	["static"] = true,
	["fixed"] = true,
	["absolute"] = true,
	["relative"] = true,
	["sticky"] = true,
	["block"] = true,
	["inline-block"] = true,
	["inline"] = true,
	["flex"] = true,
	["inline-flex"] = true,
	["grid"] = true,
	["inline-grid"] = true,
	["table"] = true,
	["inline-table"] = true,
	["table-caption"] = true,
	["table-cell"] = true,
	["table-column"] = true,
	["table-column-group"] = true,
	["table-footer-group"] = true,
	["table-header-group"] = true,
	["table-row-group"] = true,
	["table-row"] = true,
	["flow-root"] = true,
	["contents"] = true,
	["hidden"] = true,
	["box-border"] = true,
	["box-content"] = true,
	["grow"] = true,
	["shrink"] = true,
}

-- Prefix matching patterns for Row 1 (Core Layout, Size & Position)
local LAYOUT_PREFIX_PATTERNS = {
	"^inset%-",
	"^inset%-x%-",
	"^inset%-y%-",
	"^top%-",
	"^right%-",
	"^bottom%-",
	"^left%-",
	"^z%-",
	"^flex%-",
	"^basis%-",
	"^grid%-",
	"^col%-",
	"^row%-",
	"^auto%-cols%-",
	"^auto%-rows%-",
	"^grid%-flow%-",
	"^items%-",
	"^justify%-",
	"^place%-items%-",
	"^place%-content%-",
	"^place%-self%-",
	"^self%-",
	"^gap%-",
	"^space%-x%-",
	"^space%-y%-",
	"^order%-",
	"^grow%-",
	"^shrink%-",
	"^w%-",
	"^min%-w%-",
	"^max%-w%-",
	"^h%-",
	"^min%-h%-",
	"^max%-h%-",
	"^size%-",
	"^overflow%-",
	"^overflow%-x%-",
	"^overflow%-y%-",
	"^float%-",
	"^clear%-",
	"^object%-",
	"^aspect%-",
}

-- Checks if class token starts with a screen size breakpoint prefix
local function get_screen_prefix(token)
	local prefix = token:match("^([%w%-]+):")
	if prefix then
		if
			SCREEN_SIZE_ORDER[prefix]
			or prefix:match("^sm$")
			or prefix:match("^md$")
			or prefix:match("^lg$")
			or prefix:match("^xl$")
			or prefix:match("^2xl$")
			or prefix:match("^max%-")
			or prefix:match("^min%-")
		then
			return prefix
		end
	end
	return nil
end

-- Checks if base token (no screen prefix) is Row 1 (Layout/Position/Size)
local function is_layout_position_size(token)
	if EXACT_LAYOUT[token] then
		return true
	end
	for _, pat in ipairs(LAYOUT_PREFIX_PATTERNS) do
		if token:match(pat) then
			return true
		end
	end
	return false
end

-- Organizes a raw class string into multi-line/sorted rows
function M.organize_classes(raw_class_str, row_indent, base_indent)
	local tokens = {}
	local seen = {}
	for cls in raw_class_str:gmatch("%S+") do
		if not seen[cls] then
			seen[cls] = true
			table.insert(tokens, cls)
		end
	end

	if #tokens == 0 then
		return ""
	end

	local row1 = {} -- Size, Position & CORE Layout properties
	local row2 = {} -- Aesthetic Basic properties (colors, text-align, spacing, etc.)
	local hover_row = {} -- Dedicated row for all hover: classes
	local screen_rows = {} -- Keyed by screen prefix

	for _, cls in ipairs(tokens) do
		local screen_prefix = get_screen_prefix(cls)
		if cls:match("hover:") then
			table.insert(hover_row, cls)
		elseif screen_prefix then
			if not screen_rows[screen_prefix] then
				screen_rows[screen_prefix] = {}
			end
			table.insert(screen_rows[screen_prefix], cls)
		elseif is_layout_position_size(cls) then
			table.insert(row1, cls)
		else
			table.insert(row2, cls)
		end
	end

	-- Alphabetize per row (each row restarts alphabetical order A-Z)
	table.sort(row1)
	table.sort(row2)
	table.sort(hover_row)

	-- Sort screen keys by priority order
	local screen_keys = {}
	for k, _ in pairs(screen_rows) do
		table.insert(screen_keys, k)
	end
	table.sort(screen_keys, function(a, b)
		local order_a = SCREEN_SIZE_ORDER[a] or 999
		local order_b = SCREEN_SIZE_ORDER[b] or 999
		if order_a ~= order_b then
			return order_a < order_b
		else
			return a < b
		end
	end)

	for _, k in ipairs(screen_keys) do
		table.sort(screen_rows[k])
	end

	-- Assemble all non-empty rows
	local all_rows = {}
	if #row1 > 0 then
		table.insert(all_rows, table.concat(row1, " "))
	end
	if #row2 > 0 then
		table.insert(all_rows, table.concat(row2, " "))
	end
	if #hover_row > 0 then
		table.insert(all_rows, table.concat(hover_row, " "))
	end
	for _, k in ipairs(screen_keys) do
		table.insert(all_rows, table.concat(screen_rows[k], " "))
	end

	if #all_rows == 0 then
		return ""
	end

	-- Single row format if only 1 row present and force_multiline is false
	if #all_rows == 1 and not M.config.force_multiline then
		return all_rows[1]
	end

	-- Multi-line format with line breaks per category row
	row_indent = row_indent or "  "
	base_indent = base_indent or ""
	local lines = {}
	for _, row_str in ipairs(all_rows) do
		table.insert(lines, row_indent .. row_str)
	end

	return "\n" .. table.concat(lines, "\n") .. "\n" .. base_indent
end

-- Helper to find indentation for match position in text
local function find_indent(text, pos)
	local line_start = 1
	local i = pos
	while i > 1 do
		if text:sub(i, i) == "\n" then
			line_start = i + 1
			break
		end
		i = i - 1
	end
	return text:sub(line_start, pos):match("^(%s*)") or ""
end

-- Organizes all class/className attributes in full text
function M.organize_full_text(full_text)
	local result = full_text

	-- Match double-quoted attributes (class="...", className="...", :class="...", class:list="...")
	result = result:gsub('()([%:%w%-]*class[%w%-]*%s*=%s*)(")([^"]-)(")', function(pos, prefix, q1, body, q2)
		local base_indent = find_indent(result, pos)
		local row_indent = base_indent .. "  "
		local cleaned = body:gsub("%s+", " "):match("^%s*(.-)%s*$")
		if not cleaned or cleaned == "" then
			return prefix .. q1 .. q2
		end
		local organized = M.organize_classes(cleaned, row_indent, base_indent)
		return prefix .. q1 .. organized .. q2
	end)

	-- Match single-quoted attributes
	result = result:gsub("()([%:%w%-]*class[%w%-]*%s*=%s*)(')([^']-)(')", function(pos, prefix, q1, body, q2)
		local base_indent = find_indent(result, pos)
		local row_indent = base_indent .. "  "
		local cleaned = body:gsub("%s+", " "):match("^%s*(.-)%s*$")
		if not cleaned or cleaned == "" then
			return prefix .. q1 .. q2
		end
		local organized = M.organize_classes(cleaned, row_indent, base_indent)
		return prefix .. q1 .. organized .. q2
	end)

	-- Match JSX template literals: className={`...`} or class={`...`}
	result = result:gsub('()([%:%w%-]*class[%w%-]*%s*=%s*{`)(.-)(`})', function(pos, prefix, body, suffix)
		local base_indent = find_indent(result, pos)
		local row_indent = base_indent .. "  "
		local cleaned = body:gsub("%s+", " "):match("^%s*(.-)%s*$")
		if not cleaned or cleaned == "" then
			return prefix .. suffix
		end
		local organized = M.organize_classes(cleaned, row_indent, base_indent)
		return prefix .. organized .. suffix
	end)

	return result
end

-- Organizes classes in current buffer
function M.organize_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local full_text = table.concat(lines, "\n")
	local organized_text = M.organize_full_text(full_text)

	if organized_text ~= full_text then
		local new_lines = {}
		for line in (organized_text .. "\n"):gmatch("(.-)\n") do
			table.insert(new_lines, line)
		end
		if #new_lines > 0 and new_lines[#new_lines] == "" and organized_text:sub(-1) ~= "\n" then
			table.remove(new_lines)
		end

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
		return true
	end
	return false
end

-- Toggle organizer state
function M.toggle()
	M.enabled = not M.enabled
	local status = M.enabled and "ACTIVATED (Auto-format on Save ON)" or "DEACTIVATED (Auto-format on Save OFF)"
	local level = M.enabled and vim.log.levels.INFO or vim.log.levels.WARN
	vim.notify("🎨 Tailwind Organizer: " .. status, level, { title = "Tailwind Organizer" })
end

-- Display status notification
function M.show_status()
	local status = M.enabled and "Active (Auto-format on Save ON)" or "Inactive (Auto-format on Save OFF)"
	vim.notify("🎨 Tailwind Organizer Status: " .. status, vim.log.levels.INFO, { title = "Tailwind Organizer" })
end

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "tailwind_organizer",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	keys = {
		{
			"<leader>tw",
			function()
				if M.organize_buffer(0) then
					vim.notify("✨ Tailwind classes organized!", vim.log.levels.INFO, { title = "Tailwind Organizer" })
				else
					vim.notify("Tailwind classes already organized.", vim.log.levels.INFO, { title = "Tailwind Organizer" })
				end
			end,
			desc = "Organize Tailwind Classes",
		},
		{
			"<leader>tt",
			function()
				M.toggle()
			end,
			desc = "Toggle Tailwind Organizer",
		},
	},
	config = function()
		-- Create User Commands
		vim.api.nvim_create_user_command("TailwindOrganizerToggle", function()
			M.toggle()
		end, { desc = "Toggle Tailwind Classes Organizer" })

		vim.api.nvim_create_user_command("TailwindOrganize", function()
			if M.organize_buffer(0) then
				vim.notify("✨ Tailwind classes organized!", vim.log.levels.INFO, { title = "Tailwind Organizer" })
			else
				vim.notify("Tailwind classes already organized.", vim.log.levels.INFO, { title = "Tailwind Organizer" })
			end
		end, { desc = "Organize Tailwind Classes in Current Buffer" })

		vim.api.nvim_create_user_command("TailwindOrganizerStatus", function()
			M.show_status()
		end, { desc = "Show Tailwind Organizer Status" })

		-- Autocmd for Auto-format on save (:w)
		local group = vim.api.nvim_create_augroup("TailwindOrganizerGroup", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = group,
			pattern = "*",
			callback = function(args)
				if M.enabled then
					M.organize_buffer(args.buf)
				end
			end,
		})

		-- Dynamically register commands with CommandPalette if available
		local ok_cp, command_palette = pcall(require, "plugins.krs.command_palette")
		if ok_cp and command_palette.add_command then
			command_palette.add_command({
				name = "🎨 Toggle Tailwind Organizer (Auto-Format on Save)",
				cmd = "TailwindOrganizerToggle",
				category = "Tailwind",
			})
			command_palette.add_command({
				name = "✨ Organize Tailwind Classes (Current File)",
				cmd = "TailwindOrganize",
				category = "Tailwind",
			})
			command_palette.add_command({
				name = "ℹ️ Tailwind Organizer Status",
				cmd = "TailwindOrganizerStatus",
				category = "Tailwind",
			})
		end
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

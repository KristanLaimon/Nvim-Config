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
	min_classes_for_multiline = 9,
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

-- Priority calculator for Row 1: Display & Position (Prio 1) > Width & Height (Prio 2) > Other Layout (Prio 3)
local function get_layout_priority(token)
	local base = token:match(":(.*)$") or token
	if EXACT_LAYOUT[base] then
		return 1
	end
	if
		base:match("^w%-")
		or base:match("^min%-w%-")
		or base:match("^max%-w%-")
		or base:match("^h%-")
		or base:match("^min%-h%-")
		or base:match("^max%-h%-")
		or base:match("^size%-")
	then
		return 2
	end
	return 3
end

local function sort_row1_classes(row)
	table.sort(row, function(a, b)
		local prio_a = get_layout_priority(a)
		local prio_b = get_layout_priority(b)
		if prio_a ~= prio_b then
			return prio_a < prio_b
		else
			return a < b
		end
	end)
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

	-- Row 1: Priority sort (Display/Pos > Dimensions w-*/h-* > Other layout)
	sort_row1_classes(row1)

	-- Row 2 & Hover: Alphabetize per row (A-Z)
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
		sort_row1_classes(screen_rows[k])
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

	-- Single row format if element has fewer than min_classes_for_multiline (default 9)
	-- or if only 1 row is present and force_multiline is false
	local min_count = M.config.min_classes_for_multiline or 9
	if #tokens < min_count or (#all_rows == 1 and not M.config.force_multiline) then
		return table.concat(all_rows, " ")
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

-- Organizes all class/className attributes in full text and tracks added lines before cursor & topline
function M.organize_full_text(full_text, cursor_byte_offset, topline_byte_offset)
	cursor_byte_offset = cursor_byte_offset or math.huge
	topline_byte_offset = topline_byte_offset or math.huge
	local result = full_text
	local added_lines_before_cursor = 0
	local added_lines_before_topline = 0

	local function calc_delta(pos, old_str, new_str)
		local _, old_nl = old_str:gsub("\n", "")
		local _, new_nl = new_str:gsub("\n", "")
		local diff = new_nl - old_nl
		if diff ~= 0 then
			if pos <= cursor_byte_offset then
				added_lines_before_cursor = added_lines_before_cursor + diff
			end
			if pos <= topline_byte_offset then
				added_lines_before_topline = added_lines_before_topline + diff
			end
		end
	end

	-- Match double-quoted attributes (class="...", className="...", :class="...", class:list="...")
	result = result:gsub('()([%:%w%-]*class[%w%-]*%s*=%s*)(")([^"]-)(")', function(pos, prefix, q1, body, q2)
		local base_indent = find_indent(result, pos)
		local row_indent = base_indent .. "  "
		local cleaned = body:gsub("%s+", " "):match("^%s*(.-)%s*$")
		if not cleaned or cleaned == "" then
			return prefix .. q1 .. q2
		end
		local organized = M.organize_classes(cleaned, row_indent, base_indent)
		local old_str = prefix .. q1 .. body .. q2
		local new_str = prefix .. q1 .. organized .. q2
		calc_delta(pos, old_str, new_str)
		return new_str
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
		local old_str = prefix .. q1 .. body .. q2
		local new_str = prefix .. q1 .. organized .. q2
		calc_delta(pos, old_str, new_str)
		return new_str
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
		local old_str = prefix .. body .. suffix
		local new_str = prefix .. organized .. suffix
		calc_delta(pos, old_str, new_str)
		return new_str
	end)

	return result, added_lines_before_cursor, added_lines_before_topline
end

-- Organizes classes in current buffer preserving cursor & view state with exact line shift tracking
function M.organize_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local view = nil
	local is_current = (bufnr == vim.api.nvim_get_current_buf())
	local cursor_byte_offset = math.huge
	local topline_byte_offset = math.huge

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	if is_current then
		view = vim.fn.winsaveview()
		topline_byte_offset = 0
		local top_lnum = math.min(view.topline or 1, #lines)
		for i = 1, top_lnum - 1 do
			topline_byte_offset = topline_byte_offset + #(lines[i] or "") + 1
		end

		cursor_byte_offset = 0
		local cur_lnum = math.min(view.lnum or 1, #lines)
		for i = 1, cur_lnum - 1 do
			cursor_byte_offset = cursor_byte_offset + #(lines[i] or "") + 1
		end
		cursor_byte_offset = cursor_byte_offset + (view.col or 0)
	end

	local full_text = table.concat(lines, "\n")
	local organized_text, added_lines_before_cursor, added_lines_before_topline =
		M.organize_full_text(full_text, cursor_byte_offset, topline_byte_offset)

	if organized_text ~= full_text then
		local new_lines = {}
		for line in (organized_text .. "\n"):gmatch("(.-)\n") do
			table.insert(new_lines, line)
		end
		if #new_lines > 0 and new_lines[#new_lines] == "" and organized_text:sub(-1) ~= "\n" then
			table.remove(new_lines)
		end

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)

		if view and is_current then
			local shifted_lnum = math.max(1, math.min(#new_lines, view.lnum + (added_lines_before_cursor or 0)))
			local shifted_topline = math.max(1, math.min(#new_lines, view.topline + (added_lines_before_topline or 0)))

			view.lnum = shifted_lnum
			view.topline = shifted_topline
			vim.fn.winrestview(view)
		end
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

function M.reload()
	package.loaded["plugins.krs.tailwind_organizer"] = nil
	package.loaded["plugins.krs.tailwind_organizer"] = nil
	local reloaded = require("plugins.krs.tailwind_organizer")
	reloaded.setup()
	vim.notify("🔄 Tailwind Organizer reloaded in-memory!", vim.log.levels.INFO, { title = "Tailwind Organizer" })
end

function M.setup()
	if vim.fn.exists(":TailwindOrganizerToggle") == 0 then
		vim.api.nvim_create_user_command("TailwindOrganizerToggle", function()
			M.toggle()
		end, { desc = "Toggle Tailwind Classes Organizer" })
	end

	if vim.fn.exists(":TailwindOrganize") == 0 then
		vim.api.nvim_create_user_command("TailwindOrganize", function()
			if M.organize_buffer(0) then
				vim.notify("✨ Tailwind classes organized!", vim.log.levels.INFO, { title = "Tailwind Organizer" })
			else
				vim.notify("Tailwind classes already organized.", vim.log.levels.INFO, { title = "Tailwind Organizer" })
			end
		end, { desc = "Organize Tailwind Classes in Current Buffer" })
	end

	if vim.fn.exists(":TailwindOrganizerStatus") == 0 then
		vim.api.nvim_create_user_command("TailwindOrganizerStatus", function()
			M.show_status()
		end, { desc = "Show Tailwind Organizer Status" })
	end

	if vim.fn.exists(":TailwindOrganizerReload") == 0 then
		vim.api.nvim_create_user_command("TailwindOrganizerReload", function()
			M.reload()
		end, { desc = "Hot-reload Tailwind Organizer module" })
	end

	vim.keymap.set("n", "<leader>tw", function()
		if M.organize_buffer(0) then
			vim.notify("✨ Tailwind classes organized!", vim.log.levels.INFO, { title = "Tailwind Organizer" })
		else
			vim.notify("Tailwind classes already organized.", vim.log.levels.INFO, { title = "Tailwind Organizer" })
		end
	end, { desc = "Organize Tailwind Classes" })

	vim.keymap.set("n", "<leader>tt", function()
		M.toggle()
	end, { desc = "Toggle Tailwind Organizer" })

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
end

-- Ensure setup runs on module load
M.setup()

_G.TailwindOrganizer = M

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_tailwind_organizer",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

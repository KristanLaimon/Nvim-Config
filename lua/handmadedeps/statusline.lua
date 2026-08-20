-- ============================================================================
-- HANDMADEDEPS: statusline -- pure-Lua replacement for nvim-lualine/lualine.nvim.
-- ============================================================================
-- Implements only the component/section vocabulary actually used by
-- plugins/krs/statusline_picker.lua's five themes: mode, branch, diff,
-- diagnostics, filename, filetype, encoding, fileformat, progress, location,
-- plus raw function components (M.lsp_status / M.fileformat_status).
-- ============================================================================

local M = {}

M.config = { options = {}, sections = {} }

local MODE_MAP = {
	n = "NORMAL", no = "NORMAL", nov = "NORMAL", noV = "NORMAL",
	i = "INSERT", ic = "INSERT", ix = "INSERT",
	v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
	s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
	R = "REPLACE", Rv = "V-REPLACE",
	c = "COMMAND", cv = "EX", ce = "EX",
	r = "MORE", rm = "MORE", ["r?"] = "CONFIRM",
	["!"] = "SHELL", t = "TERMINAL",
}

local MODE_COLORS = {
	NORMAL = "#61afef",
	INSERT = "#98c379",
	VISUAL = "#c678dd",
	["V-LINE"] = "#c678dd",
	["V-BLOCK"] = "#c678dd",
	SELECT = "#c678dd",
	["S-LINE"] = "#c678dd",
	["S-BLOCK"] = "#c678dd",
	REPLACE = "#e06c75",
	["V-REPLACE"] = "#e06c75",
	COMMAND = "#e5c07b",
	EX = "#e5c07b",
	MORE = "#e5c07b",
	CONFIRM = "#e5c07b",
	SHELL = "#56b6c2",
	TERMINAL = "#56b6c2",
}

local function get_hl(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl and next(hl) then
		return hl
	end
	return nil
end

local function hex(n)
	if not n then
		return nil
	end
	return string.format("#%06x", n)
end

--- Current mode name, e.g. "NORMAL", "INSERT", "V-BLOCK".
local function current_mode_name()
	local m = vim.api.nvim_get_mode().mode
	return MODE_MAP[m] or MODE_MAP[m:sub(1, 1)] or "NORMAL"
end

local function git_branch()
	local head = vim.b.gitsigns_head
	if head and head ~= "" then
		return head
	end
	return ""
end

local function diff_counts()
	local d = vim.b.gitsigns_status_dict
	if not d then
		return nil
	end
	return { added = d.added or 0, modified = d.changed or 0, removed = d.removed or 0 }
end

local function diagnostics_counts()
	local ok, counts = pcall(function()
		local c = { error = 0, warn = 0, info = 0, hint = 0 }
		for _, d in ipairs(vim.diagnostic.get(0)) do
			if d.severity == vim.diagnostic.severity.ERROR then
				c.error = c.error + 1
			elseif d.severity == vim.diagnostic.severity.WARN then
				c.warn = c.warn + 1
			elseif d.severity == vim.diagnostic.severity.INFO then
				c.info = c.info + 1
			elseif d.severity == vim.diagnostic.severity.HINT then
				c.hint = c.hint + 1
			end
		end
		return c
	end)
	return ok and counts or nil
end

local function default_filename()
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" then
		return "[No Name]"
	end
	return vim.fn.fnamemodify(name, ":.")
end

-- ---------------------------------------------------------------------------
-- Builtin component renderers. Each returns a plain string.
-- ---------------------------------------------------------------------------
local BUILTINS = {}

function BUILTINS.mode(opts)
	local name = current_mode_name()
	if opts.fmt then
		return opts.fmt(name)
	end
	return name
end

function BUILTINS.branch(opts)
	local b = git_branch()
	if b == "" then
		return ""
	end
	return (opts.icon or "") .. " " .. b
end

function BUILTINS.diff(opts)
	local d = diff_counts()
	if not d then
		return ""
	end
	local sym = opts.symbols or { added = "+", modified = "~", removed = "-" }
	local out = {}
	if d.added > 0 then
		table.insert(out, sym.added .. d.added)
	end
	if d.modified > 0 then
		table.insert(out, sym.modified .. d.modified)
	end
	if d.removed > 0 then
		table.insert(out, sym.removed .. d.removed)
	end
	return table.concat(out, " ")
end

function BUILTINS.diagnostics(opts)
	local c = diagnostics_counts()
	if not c then
		return ""
	end
	local sym = opts.symbols or { error = "E", warn = "W", info = "I", hint = "H" }
	local out = {}
	if c.error > 0 then
		table.insert(out, sym.error .. c.error)
	end
	if c.warn > 0 then
		table.insert(out, sym.warn .. c.warn)
	end
	if c.info > 0 then
		table.insert(out, sym.info .. c.info)
	end
	if c.hint > 0 then
		table.insert(out, sym.hint .. c.hint)
	end
	return table.concat(out, " ")
end

function BUILTINS.filename(opts)
	local name = default_filename()
	if opts.fmt then
		name = opts.fmt(name)
	end
	if opts.file_status ~= false then
		local sym = opts.symbols or {}
		if vim.bo.modified then
			name = name .. (sym.modified or " [+]")
		elseif vim.bo.readonly then
			name = name .. (sym.readonly or " [RO]")
		end
	end
	return name
end

function BUILTINS.filetype()
	return vim.bo.filetype ~= "" and vim.bo.filetype or ""
end

function BUILTINS.encoding()
	return (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding):upper()
end

function BUILTINS.fileformat()
	local map = { unix = "LF", dos = "CRLF", mac = "CR" }
	return map[vim.bo.fileformat] or vim.bo.fileformat:upper()
end

function BUILTINS.progress()
	local line = vim.fn.line(".")
	local total = vim.fn.line("$")
	if total <= 1 then
		return "All"
	end
	if line == 1 then
		return "Top"
	end
	if line == total then
		return "Bot"
	end
	return math.floor((line - 1) / (total - 1) * 100) .. "%%"
end

function BUILTINS.location(opts)
	local line = vim.fn.line(".")
	local col = vim.fn.col(".")
	local icon = opts.icon
	return (icon and (icon .. " ") or "") .. line .. ":" .. col
end

--- Renders one component entry: a builtin name, a raw function, or a
--- `{ name_or_fn, ...opts }` table.
local function render_component(comp)
	if type(comp) == "function" then
		local ok, res = pcall(comp)
		return ok and (res or "") or ""
	end
	if type(comp) == "string" then
		local fn = BUILTINS[comp]
		return fn and (fn({}) or "") or ""
	end
	if type(comp) == "table" then
		local head = comp[1]
		local fn = type(head) == "function" and head or BUILTINS[head]
		if not fn then
			return ""
		end
		local ok, res = pcall(fn, comp)
		return ok and (res or "") or ""
	end
	return ""
end

local function ensure_highlights()
	local mode = current_mode_name()
	local accent = MODE_COLORS[mode] or MODE_COLORS.NORMAL

	local statusline_hl = get_hl("StatusLine")
	local base_bg = hex(statusline_hl and statusline_hl.bg) or "#2c313c"
	local base_fg = hex((get_hl("Normal") or {}).fg) or "#abb2bf"

	vim.api.nvim_set_hl(0, "HmStatuslineA", { fg = "#1e1e1e", bg = accent, bold = true })
	vim.api.nvim_set_hl(0, "HmStatuslineB", { fg = base_fg, bg = base_bg })
	vim.api.nvim_set_hl(0, "HmStatuslineC", { fg = base_fg, bg = base_bg })
	vim.api.nvim_set_hl(0, "HmStatuslineX", { fg = base_fg, bg = base_bg })
	vim.api.nvim_set_hl(0, "HmStatuslineY", { fg = base_fg, bg = base_bg })
	vim.api.nvim_set_hl(0, "HmStatuslineZ", { fg = "#1e1e1e", bg = accent, bold = true })
end

local function render_section(list, sep)
	local rendered = {}
	for _, comp in ipairs(list or {}) do
		local text = render_component(comp)
		if text and text ~= "" then
			table.insert(rendered, text)
		end
	end
	return table.concat(rendered, sep or " ")
end

--- Builds the full `statusline` string for the current redraw.
function M.render()
	ensure_highlights()
	local sections = M.config.sections or {}
	local sep = " "

	local left = {
		string.format("%%#HmStatuslineA# %s ", render_section(sections.lualine_a, sep)),
		string.format("%%#HmStatuslineB# %s ", render_section(sections.lualine_b, sep)),
		string.format("%%#HmStatuslineC# %s ", render_section(sections.lualine_c, sep)),
	}

	local right = {
		string.format("%%#HmStatuslineX# %s ", render_section(sections.lualine_x, sep)),
		string.format("%%#HmStatuslineY# %s ", render_section(sections.lualine_y, sep)),
		string.format("%%#HmStatuslineZ# %s ", render_section(sections.lualine_z, sep)),
	}

	return table.concat(left) .. "%#StatusLine#%=" .. table.concat(right)
end

--- Configures the engine. Mirrors `lualine.setup(config)`.
--- @param config table `{ options = {...}, sections = {...} }`
function M.setup(config)
	M.config = config or { options = {}, sections = {} }

	-- Flipping 'laststatus'/'statusline' forces an immediate layout recalc.
	-- Doing that synchronously mid-startup (before the first frame settles)
	-- races Neovide's blur-behind compositor call and can leave it stuck
	-- flat-transparent instead of blurred. A same-tick vim.schedule() cut
	-- the failure rate but didn't eliminate it; waiting for the GUI to
	-- actually attach (UIEnter, same pattern config/options.lua uses for
	-- this exact race) plus a short real delay gives it real margin.
	local function apply()
		vim.defer_fn(function()
			vim.o.laststatus = M.config.options.globalstatus ~= false and 3 or 2
			vim.o.statusline = "%!v:lua.require'handmadedeps.statusline'.render()"
		end, 30)
	end
	vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, { once = true, callback = apply })

	local group = vim.api.nvim_create_augroup("HandmadedepsStatusline", { clear = true })
	vim.api.nvim_create_autocmd({ "ModeChanged", "ColorScheme" }, {
		group = group,
		callback = function()
			pcall(vim.cmd, "redrawstatus")
		end,
	})
end

return M

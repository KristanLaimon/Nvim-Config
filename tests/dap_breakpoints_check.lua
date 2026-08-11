-- Run: nvim --headless -n -S tests/dap_breakpoints_check.lua
-- Covers the enable/disable state of lua/plugins/krs/dap_breakpoints.lua:
-- disabling keeps the line but drops the breakpoint from nvim-dap, enabling
-- restores it with its condition, and both round-trip through breakpoints.json.

require("lazy").load({ plugins = { "nvim-dap" } })
local dap_bp = require("dap.breakpoints")
local krs = require("plugins.krs.dap_breakpoints")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local file = root .. "/sample.lua"
vim.fn.writefile({ "local a = 1", "local b = 2", "local c = 3" }, file)

vim.cmd.edit(file)
local bufnr = vim.api.nvim_get_current_buf()

local function live_lines()
	local out = {}
	for _, bp in ipairs(dap_bp.get(bufnr)[bufnr] or {}) do
		out[bp.line] = bp
	end
	return out
end

local function disabled_count()
	local placed = vim.fn.sign_getplaced(bufnr, { group = "krs_dap_disabled" })
	return #((placed[1] or {}).signs or {})
end

dap_bp.set({ condition = "a == 1" }, bufnr, 2)
assert(live_lines()[2], "breakpoint not set on line 2")

assert(krs.disable_at(bufnr, 2), "disable_at returned false")
assert(not live_lines()[2], "disabled breakpoint still live in nvim-dap")
assert(disabled_count() == 1, "disabled sign not placed")

assert(krs.enable_at(bufnr, 2), "enable_at returned false")
assert(live_lines()[2], "re-enabled breakpoint missing")
assert(live_lines()[2].condition == "a == 1", "condition lost across disable/enable")
assert(disabled_count() == 0, "disabled sign left behind")

-- Persistence: one live, one disabled.
dap_bp.set({}, bufnr, 3)
krs.disable_at(bufnr, 3)
krs.save_breakpoints(root)

local saved = vim.json.decode(table.concat(vim.fn.readfile(krs.get_breakpoints_filepath(root)), "\n"))
local entries = saved.breakpoints["sample.lua"]
assert(entries and #entries == 2, "expected 2 saved entries, got " .. vim.inspect(saved.breakpoints))
local by_line = {}
for _, e in ipairs(entries) do
	by_line[e.line] = e
end
assert(by_line[2].enabled == true, "line 2 should be saved enabled")
assert(by_line[2].condition == "a == 1", "condition not persisted")
assert(by_line[3].enabled == false, "line 3 should be saved disabled")

-- Restore into a clean buffer: disabled stays disabled.
-- remove_all() persists the now-empty set (that is the point of it), so keep a
-- copy of the file and put it back before restoring.
local json_path = krs.get_breakpoints_filepath(root)
local json_backup = vim.fn.readfile(json_path)
krs.remove_all()
assert(vim.tbl_isempty(live_lines()) and disabled_count() == 0, "remove_all left breakpoints")
assert(vim.json.decode(table.concat(vim.fn.readfile(json_path), "\n")).breakpoints["sample.lua"] == nil,
	"remove_all did not persist the empty set")
vim.fn.writefile(json_backup, json_path)
krs.restore_for_buffer(bufnr, root)
assert(live_lines()[2], "restore lost the enabled breakpoint")
assert(not live_lines()[3], "restore made the disabled breakpoint live")
assert(disabled_count() == 1, "restore lost the disabled breakpoint")

-- disable_all / enable_all round trip.
krs.disable_all()
assert(vim.tbl_isempty(live_lines()) and disabled_count() == 2, "disable_all failed")
krs.enable_all()
assert(live_lines()[2] and live_lines()[3] and disabled_count() == 0, "enable_all failed")

print("OK dap breakpoints enable/disable")
vim.cmd("qa!")

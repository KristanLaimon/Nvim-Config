-- ============================================================================
-- 🦊 KRS PLUGIN: Persistent DAP Breakpoints Manager (`breakpoints.json`)
-- ============================================================================
-- Automatically saves and restores DAP breakpoints across Neovim sessions
-- inside `.krsnvim/breakpoints.json` (or `.krslocal/breakpoints.json`).
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Disabled breakpoints
-- ---------------------------------------------------------------------------
-- nvim-dap has no concept of a disabled breakpoint: a breakpoint exists or it
-- does not. A disabled one is therefore removed from nvim-dap (so the adapter
-- never binds it) and kept here as our own sign, in our own sign group, with
-- the options it was carrying. Signs are used instead of raw line numbers so a
-- disabled breakpoint drifts with edits exactly like a live one.
local DISABLED_GROUP = "krs_dap_disabled"

-- [bufnr] = { [sign_id] = { condition, hit_condition, log_message } }
M.disabled = {}

local function disabled_signs(bufnr)
	local out = {}
	local ok, res = pcall(vim.fn.sign_getplaced, bufnr, { group = DISABLED_GROUP })
	if ok and res and res[1] then
		for _, sign in ipairs(res[1].signs or {}) do
			out[sign.id] = sign.lnum
		end
	end
	return out
end

local function disabled_at(bufnr, line)
	for sign_id, lnum in pairs(disabled_signs(bufnr)) do
		if lnum == line then
			return sign_id
		end
	end
end

-- Removing/adding a breakpoint behind nvim-dap's back leaves a running adapter
-- with the old set, so re-send this buffer's breakpoints. `get(bufnr)` returns
-- an empty table when the buffer has none left, which would skip the buffer
-- entirely and keep a stale breakpoint bound — hence the explicit key.
local function sync_session(bufnr)
	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap or not dap.session() then
		return
	end
	local dap_bp = require("dap.breakpoints")
	local bps = { [bufnr] = dap_bp.get(bufnr)[bufnr] or {} }
	for _, session in pairs(dap.sessions() or {}) do
		pcall(function()
			session:set_breakpoints(bps)
		end)
	end
end

local function place_disabled(bufnr, line, opts)
	local sign_id = vim.fn.sign_place(0, DISABLED_GROUP, "DapBreakpointDisabled", bufnr, {
		lnum = line,
		priority = 21,
	})
	if sign_id ~= -1 then
		M.disabled[bufnr] = M.disabled[bufnr] or {}
		M.disabled[bufnr][sign_id] = opts or {}
	end
	return sign_id
end

function M.disable_at(bufnr, line)
	local ok_dap, dap_bp = pcall(require, "dap.breakpoints")
	if not ok_dap then
		return false
	end
	for _, bp in ipairs(dap_bp.get(bufnr)[bufnr] or {}) do
		if bp.line == line then
			-- dap.breakpoints.get() hands back the DAP spelling (hitCondition,
			-- logMessage); dap.breakpoints.set() expects the snake_case one.
			local opts = {
				condition = bp.condition,
				hit_condition = bp.hitCondition,
				log_message = bp.logMessage,
			}
			dap_bp.remove(bufnr, line)
			place_disabled(bufnr, line, opts)
			sync_session(bufnr)
			return true
		end
	end
	return false
end

function M.enable_at(bufnr, line)
	local sign_id = disabled_at(bufnr, line)
	if not sign_id then
		return false
	end
	local opts = (M.disabled[bufnr] or {})[sign_id] or {}
	vim.fn.sign_unplace(DISABLED_GROUP, { buffer = bufnr, id = sign_id })
	if M.disabled[bufnr] then
		M.disabled[bufnr][sign_id] = nil
	end
	local ok_dap, dap_bp = pcall(require, "dap.breakpoints")
	if ok_dap then
		dap_bp.set(opts, bufnr, line)
		sync_session(bufnr)
	end
	return true
end

-- Enable <-> disable the breakpoint under the cursor, keeping it in place.
-- Returns whether there was a breakpoint to flip, so a keymap that shares its
-- key with another action can fall through when there was not.
function M.toggle_enabled(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]

	local changed = M.enable_at(bufnr, line) or M.disable_at(bufnr, line)
	if not changed then
		if not opts.silent then
			vim.notify("No breakpoint on this line", vim.log.levels.INFO)
		end
		return false
	end
	M.save_breakpoints()
	return true
end

function M.disable_all()
	local ok_dap, dap_bp = pcall(require, "dap.breakpoints")
	if not ok_dap then
		return
	end
	local count = 0
	for bufnr, bps in pairs(dap_bp.get()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			-- Collect first: disable_at mutates the sign list it walks.
			local lines = {}
			for _, bp in ipairs(bps) do
				table.insert(lines, bp.line)
			end
			for _, line in ipairs(lines) do
				if M.disable_at(bufnr, line) then
					count = count + 1
				end
			end
		end
	end
	M.save_breakpoints()
	vim.notify("Disabled " .. count .. " breakpoint(s)", vim.log.levels.INFO)
end

function M.enable_all()
	local count = 0
	for bufnr, _ in pairs(M.disabled) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			for _, line in pairs(disabled_signs(bufnr)) do
				if M.enable_at(bufnr, line) then
					count = count + 1
				end
			end
		end
	end
	M.save_breakpoints()
	vim.notify("Enabled " .. count .. " breakpoint(s)", vim.log.levels.INFO)
end

function M.remove_all()
	local ok_dap, dap = pcall(require, "dap")
	if ok_dap then
		dap.clear_breakpoints()
	end
	vim.fn.sign_unplace(DISABLED_GROUP)
	M.disabled = {}
	M.save_breakpoints()
	vim.notify("Removed all breakpoints", vim.log.levels.INFO)
end

function M.get_project_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local ok, tasks_mod = pcall(require, "plugins.krs.tasks")
	if ok and tasks_mod.get_project_root then
		return tasks_mod.get_project_root()
	end
	local current = vim.api.nvim_buf_get_name(bufnr)
	current = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
	return vim.fs.normalize(current)
end

function M.get_breakpoints_filepath(root)
	root = root or M.get_project_root()
	local norm_root = root:gsub("\\", "/")

	local krsnvim_file = norm_root .. "/.krsnvim/breakpoints.json"
	if vim.fn.filereadable(krsnvim_file) == 1 then
		return krsnvim_file
	end

	local krslocal_file = norm_root .. "/.krslocal/breakpoints.json"
	if vim.fn.filereadable(krslocal_file) == 1 then
		return krslocal_file
	end

	return krsnvim_file
end

function M.save_breakpoints(root)
	root = root or M.get_project_root()
	local ok_dap, dap_bp = pcall(require, "dap.breakpoints")
	if not ok_dap then
		return
	end

	local norm_root = root:gsub("\\", "/")
	local data = { breakpoints = {} }

	-- Both live and disabled breakpoints are persisted; `enabled` tells them
	-- apart on restore (missing = true, so files written by older versions
	-- still load as enabled).
	local entries_by_buf = {}
	for bufnr, bps in pairs(dap_bp.get()) do
		entries_by_buf[bufnr] = entries_by_buf[bufnr] or {}
		for _, bp in ipairs(bps) do
			table.insert(entries_by_buf[bufnr], {
				line = bp.line,
				condition = bp.condition,
				hit_condition = bp.hitCondition,
				log_message = bp.logMessage,
				enabled = true,
			})
		end
	end
	for bufnr, opts_by_sign in pairs(M.disabled) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			entries_by_buf[bufnr] = entries_by_buf[bufnr] or {}
			for sign_id, lnum in pairs(disabled_signs(bufnr)) do
				local opts = opts_by_sign[sign_id] or {}
				table.insert(entries_by_buf[bufnr], {
					line = lnum,
					condition = opts.condition,
					hit_condition = opts.hit_condition,
					log_message = opts.log_message,
					enabled = false,
				})
			end
		end
	end

	for bufnr, entries in pairs(entries_by_buf) do
		if vim.api.nvim_buf_is_valid(bufnr) and #entries > 0 then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			if buf_name ~= "" then
				local norm_buf = vim.fs.normalize(buf_name):gsub("\\", "/")
				local rel_path = norm_buf
				if norm_buf:sub(1, #norm_root) == norm_root then
					rel_path = norm_buf:sub(#norm_root + 2)
				end
				data.breakpoints[rel_path] = entries
			end
		end
	end

	local filepath = M.get_breakpoints_filepath(root)

	-- Don't create a .krsnvim/ in every project just to record "no breakpoints".
	-- An existing file is still rewritten, so clearing every breakpoint persists.
	if vim.tbl_isempty(data.breakpoints) and vim.fn.filereadable(filepath) == 0 then
		return
	end

	local dir = vim.fn.fnamemodify(filepath, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	local content = vim.json.encode(data)
	local f = io.open(filepath, "w")
	if f then
		f:write(content)
		f:close()
	end
end

local function read_saved(root)
	local filepath = M.get_breakpoints_filepath(root)
	if vim.fn.filereadable(filepath) == 0 then
		return nil
	end
	local f = io.open(filepath, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return nil
	end
	local ok, parsed = pcall(vim.json.decode, content)
	if not ok or type(parsed) ~= "table" or type(parsed.breakpoints) ~= "table" then
		return nil
	end
	return parsed.breakpoints
end

-- Restores into one concrete buffer only.
-- The old version looked every saved path up with `bufnr(path, true)`, which on
-- Windows creates a *second*, forward-slash buffer that is not the one on screen —
-- so the signs landed nowhere — and re-added the same breakpoints on every
-- BufReadPost, stacking duplicates.
function M.restore_for_buffer(bufnr, root)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	local buf_name = vim.api.nvim_buf_get_name(bufnr)
	if buf_name == "" then
		return
	end

	root = root or M.get_project_root(bufnr)
	local saved = read_saved(root)
	if not saved then
		return
	end

	local ok_dap, dap_bp = pcall(require, "dap.breakpoints")
	if not ok_dap then
		return
	end

	local norm_root = vim.fs.normalize(root):gsub("\\", "/"):lower()
	local norm_buf = vim.fs.normalize(buf_name):gsub("\\", "/")
	local rel = norm_buf
	if norm_buf:lower():sub(1, #norm_root) == norm_root then
		rel = norm_buf:sub(#norm_root + 2)
	end

	local bps
	for saved_path, saved_bps in pairs(saved) do
		if saved_path:gsub("\\", "/"):lower() == rel:lower() then
			bps = saved_bps
			break
		end
	end
	if not bps then
		return
	end

	local existing = {}
	for _, bp in ipairs((dap_bp.get(bufnr) or {})[bufnr] or {}) do
		existing[bp.line] = true
	end
	for _, lnum in pairs(disabled_signs(bufnr)) do
		existing[lnum] = true
	end

	for _, bp in ipairs(bps) do
		if not existing[bp.line] then
			local opts = {
				condition = bp.condition,
				hit_condition = bp.hit_condition,
				log_message = bp.log_message,
			}
			if bp.enabled == false then
				place_disabled(bufnr, bp.line, opts)
			else
				dap_bp.set(opts, bufnr, bp.line)
			end
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("KrsDapBreakpoints", { clear = true })

	vim.api.nvim_set_hl(0, "DapBreakpointDisabled", { fg = "#7f848e", default = true })
	vim.fn.sign_define("DapBreakpointDisabled", {
		text = "🐾",
		texthl = "DapBreakpointDisabled",
		linehl = "",
		numhl = "",
	})

	vim.api.nvim_create_user_command("DapBreakpointToggleEnabled", function()
		M.toggle_enabled()
	end, { desc = "Enable/disable the breakpoint under the cursor" })
	vim.api.nvim_create_user_command("DapBreakpointsEnableAll", function()
		M.enable_all()
	end, { desc = "Enable all disabled breakpoints" })
	vim.api.nvim_create_user_command("DapBreakpointsDisableAll", function()
		M.disable_all()
	end, { desc = "Disable all breakpoints (keeps them)" })
	vim.api.nvim_create_user_command("DapBreakpointsRemoveAll", function()
		M.remove_all()
	end, { desc = "Remove all breakpoints" })

	-- The file passed on the command line is read before this module's plugin spec
	-- would normally run, so its BufReadPost is already gone. Catch it here.
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.defer_fn(function()
				M.restore_for_buffer(bufnr)
			end, 150)
		end
	end

	-- Restore breakpoints for the buffer that was just opened
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = group,
		callback = function(args)
			vim.defer_fn(function()
				M.restore_for_buffer(args.buf)
			end, 100)
		end,
	})

	-- Signs get re-verified (and can flip to "rejected") during a session, so keep
	-- the file in sync when it ends instead of only at VimLeavePre.
	local ok_dap, dap = pcall(require, "dap")
	if ok_dap then
		for _, event in ipairs({ "event_terminated", "event_exited" }) do
			dap.listeners.after[event]["krs_breakpoints"] = function()
				M.save_breakpoints()
			end
		end
	end

	-- Save breakpoints before exiting Neovim
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			M.save_breakpoints(M.get_project_root())
		end,
	})
end

_G.DapBreakpoints = M

local plugin_spec = {
	name = "krs_dap_breakpoints",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

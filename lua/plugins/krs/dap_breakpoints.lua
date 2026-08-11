-- ============================================================================
-- 🦊 KRS PLUGIN: Persistent DAP Breakpoints Manager (`breakpoints.json`)
-- ============================================================================
-- Automatically saves and restores DAP breakpoints across Neovim sessions
-- inside `.krsnvim/breakpoints.json` (or `.krslocal/breakpoints.json`).
-- ============================================================================

local M = {}

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
	local bp_by_buf = dap_bp.get()
	local data = { breakpoints = {} }

	for bufnr, bps in pairs(bp_by_buf) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			if buf_name ~= "" then
				local norm_buf = vim.fs.normalize(buf_name):gsub("\\", "/")
				local rel_path = norm_buf
				if norm_buf:sub(1, #norm_root) == norm_root then
					rel_path = norm_buf:sub(#norm_root + 2)
				end

				if #bps > 0 then
					data.breakpoints[rel_path] = {}
					for _, bp in ipairs(bps) do
						table.insert(data.breakpoints[rel_path], {
							line = bp.line,
							condition = bp.condition,
							hit_condition = bp.hit_condition,
							log_message = bp.log_message,
						})
					end
				end
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

	for _, bp in ipairs(bps) do
		if not existing[bp.line] then
			dap_bp.set({
				condition = bp.condition,
				hit_condition = bp.hit_condition,
				log_message = bp.log_message,
			}, bufnr, bp.line)
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("KrsDapBreakpoints", { clear = true })

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
	dir = require("krs.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

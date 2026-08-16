-- ============================================================================
-- KRS PLUGIN: Pinned Tabs -- `.krsnvim/pins.json` & Workspaces
-- ============================================================================
-- WHAT IT DOES
--   * Pins / unpins the active code buffer tab when `<C-p>` is pressed.
--   * Restricts pinning to code buffer tabs only (buftype == "", valid file).
--   * Stores pinned tab paths in `.krsnvim/pins.json` (or workspace-specific
--     `.krsnvim/pins_<ws_id>.json` if a workspace is loaded).
--   * Syncs tab pin state with bufferline.nvim (`📌` icon, anchored on left).
--   * Restores pinned tabs on editor startup, directory change, or workspace switch.
-- ============================================================================

local store = require("krs.core.store")
local project = require("krs.core.project")
local path = require("krs.core.path")

local M = {}

--- Filetypes ignored for tab pinning.
M.ignored_filetypes = {
	"neo-tree",
	"dashboard",
	"alpha",
	"toggleterm",
	"TaskRunner",
	"qf",
	"help",
	"krsinputmodal",
	"lspinfo",
	"notify",
	"checkhealth",
}

--- Resolves the pins JSON storage path.
--- Workspace pins: <root>/.krsnvim/pins_<workspace_id>.json
--- Normal project pins: <root>/.krsnvim/pins.json
--- @return string filepath
function M.get_pins_file()
	local root = project.root()
	local ws_id = nil

	local ok_ws, workspaces = pcall(require, "plugins.krs.workspaces")
	if ok_ws and workspaces.get_active_workspace then
		local active = workspaces.get_active_workspace()
		if active and (active.id or active.name) then
			ws_id = active.id or active.name:gsub("[%s/\\]+", "_")
		end
	end

	if ws_id and ws_id ~= "" then
		return (project.config_path("pins_" .. ws_id .. ".json", root))
	else
		return (project.config_path("pins.json", root))
	end
end

--- Reads current pinned paths list from disk.
--- @return string[] pinned Relative or absolute file paths.
function M.load_pins()
	local file = M.get_pins_file()
	local data = store.load(file, { pinned = {} })
	return data.pinned or {}
end

--- Saves pinned paths list to disk.
--- @param pinned_list string[]
function M.save_pins(pinned_list)
	local file = M.get_pins_file()
	store.save(file, { pinned = pinned_list })
end

--- Checks if a buffer is a valid code buffer tab.
--- @param bufnr integer|nil Defaults to current buffer.
--- @return boolean
function M.is_code_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not bufnr or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local ft = vim.bo[bufnr].filetype
	if vim.tbl_contains(M.ignored_filetypes, ft) then
		return false
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" or name:match("^%a[%a%d+.-]+://") or name:match("^node:") then
		return false
	end

	return true
end

--- Toggles pin status of the active code buffer tab.
function M.toggle_pin()
	local bufnr = vim.api.nvim_get_current_buf()
	if not M.is_code_buffer(bufnr) then
		vim.notify("Pin tab (<Ctrl+P>) is only available in code buffer tabs", vim.log.levels.WARN, { title = "Pinned Tabs" })
		return
	end

	local abs_path = path.normalize(vim.api.nvim_buf_get_name(bufnr))
	local root = project.root()
	local rel_path = path.relative_to(abs_path, root) or abs_path

	local pins = M.load_pins()
	local existing_idx = nil
	for i, p in ipairs(pins) do
		if p == rel_path or p == abs_path or path.normalize(p) == abs_path then
			existing_idx = i
			break
		end
	end

	local is_now_pinned = false
	if existing_idx then
		table.remove(pins, existing_idx)
		is_now_pinned = false
	else
		table.insert(pins, rel_path)
		is_now_pinned = true
	end

	M.save_pins(pins)

	-- Toggle in bufferline
	pcall(function()
		require("bufferline.groups").toggle_pin(bufnr)
	end)

	local fname = vim.fn.fnamemodify(abs_path, ":t")
	if is_now_pinned then
		vim.notify("📌 Tab pinned: " .. fname, vim.log.levels.INFO, { title = "Pinned Tabs" })
	else
		vim.notify("Unpinned tab: " .. fname, vim.log.levels.INFO, { title = "Pinned Tabs" })
	end
end

--- Restores pinned tabs state into buffers and bufferline.
function M.restore_pins()
	local pins = M.load_pins()
	local root = project.root()

	local pin_map = {}
	local valid_pins = {}
	local cleaned_missing = false

	for _, p in ipairs(pins) do
		local is_abs = (path.is_absolute and path.is_absolute(p)) or (p:sub(1, 1) == "/" or p:match("^%a:") ~= nil)
		local full = is_abs and path.normalize(p) or path.join(root, p)
		if vim.fn.filereadable(full) == 1 then
			table.insert(valid_pins, p)
			pin_map[full] = true
		else
			cleaned_missing = true
		end
	end

	-- Auto-prune pins file on disk if any pinned file was deleted while Neovim was closed
	if cleaned_missing then
		M.save_pins(valid_pins)
	end

	-- Ensure valid pinned files are open in listed buffers
	for full_path, _ in pairs(pin_map) do
		local b = vim.fn.bufadd(full_path)
		vim.fn.bufload(b)
		vim.bo[b].buflisted = true
	end

	-- Apply pin state in bufferline for open buffers
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and M.is_code_buffer(bufnr) then
			local bpath = path.normalize(vim.api.nvim_buf_get_name(bufnr))
			local should_be_pinned = pin_map[bpath] == true
			pcall(function()
				local groups = require("bufferline.groups")
				if groups and groups.set_state then
					groups.set_state(bufnr, "pinned", should_be_pinned)
				end
			end)
		end
	end
end

--- Setup autocmds for automatic pin restoration.
function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	local group = vim.api.nvim_create_augroup("KRSPinnedTabsAuto", { clear = true })

	vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged", "BufReadPost" }, {
		group = group,
		callback = function()
			vim.schedule(M.restore_pins)
		end,
	})
end

return setmetatable({
	name = "krs_pinned_tabs",
	dir = require("krs.core.lazyspec").for_module(),
	event = { "BufReadPost", "DirChanged" },
	config = M.setup,
}, { __index = M })

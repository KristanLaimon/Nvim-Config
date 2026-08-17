-- ============================================================================
-- KEYMAP REGISTRY -- diagnoses shortcut collisions the moment they happen.
-- ============================================================================
-- Monkeypatches vim.keymap.set with an O(1) dictionary lookup keyed by
-- mode+lhs+scope. A second bind of the same key fires a toast instead of
-- silently overwriting the first one.
--
-- A key bound eagerly in config/keymaps/krs.lua is deliberately re-bound by
-- lazy.nvim's own `keys = {...}` stub handler for the matching plugin (see
-- krs.lua:17-20) -- confirmed at real startup: every intentional duplicate
-- has its second bind sourced from lazy.nvim's stub handler itself, so that
-- source is the actual signal to silence on, not a hand-maintained key list
-- (which would need updating for every alt-chord alias and miss new ones).
-- Detection never blocks the bind: last-wins behavior is unchanged.
-- ============================================================================

local M = {}

local seen = {}

--- Every un-allowlisted collision seen since startup, in order. A test can
--- inspect this after the fact even for collisions that happened before it
--- got a chance to install a vim.notify stub (e.g. the eager config.keymaps
--- load, which finishes before any spec file runs).
M.collisions = {}

--- Lua patterns matched against the collision's source (file:line). A match
--- silences the toast. Both entries are re-bind-on-purpose call sites:
--- - lazy.nvim's own lazy-load stub creation (see krs.lua:17-20).
--- - debug.lua's toggle_enabled keys, bound late on VimEnter after capturing
---   whatever was there via vim.fn.maparg so it can fall back to it -- see
---   debug.lua:163-193. Not an override that loses the old binding.
-- - plugins/krs/terminal.lua's terminal-mode <C-w>/<C-v>/<C-S-v>/<C-c>/<C-S-c>,
--   which duplicate editor.lua's global binds of the same keys with the same
--   underlying action (both call _G.Neotree_Smart_Quit for <C-w>, both do
--   '"+y'/paste-clipboard for copy/paste) -- confirmed via buffer_cleaner.lua,
--   whose own docstring says a terminal buffer's <C-w> closes the window, not
--   :bdelete, same as terminal.lua's fallback.
M.ALLOWLIST_SOURCE_PATTERNS = {
	"lazy/core/handler/keys%.lua",
	"config/keymaps/debug%.lua",
	"plugins/krs/terminal%.lua",
	-- search.lua binds these before telescope loads (see telescope.lua:170-171);
	-- telescope's own setup() rebinds the same keys to the same underlying
	-- functions (_G.FindFilesGitignore / _G.FindFilesNoIgnore) once it's up.
	"plugins/editor/telescope%.lua",
}

local function scope_of(opts)
	if not opts or opts.buffer == nil then
		return "global"
	end
	if opts.buffer == true then
		return tostring(vim.api.nvim_get_current_buf())
	end
	return tostring(opts.buffer)
end

local function source_allowlisted(source)
	for _, pattern in ipairs(M.ALLOWLIST_SOURCE_PATTERNS) do
		if source:find(pattern) then
			return true
		end
	end
	return false
end

--- Finds the real Lua call site, skipping C frames (e.g. a bare "[C]:-1"
--- when vim.keymap.set is invoked as `pcall(vim.keymap.set, ...)`, which
--- inserts pcall itself as an untraceable frame right above this wrapper).
local function source_of()
	for level = 3, 10 do
		local info = debug.getinfo(level, "Sl")
		if not info then
			break
		end
		if info.short_src ~= "[C]" then
			return info.short_src .. ":" .. info.currentline
		end
	end
	return "?"
end

--- Installs the monkeypatch. Idempotent -- calling twice is a no-op.
function M.install()
	if M.raw_set then
		return
	end
	M.raw_set = vim.keymap.set

	vim.keymap.set = function(mode, lhs, rhs, opts)
		local modes = type(mode) == "table" and mode or { mode }
		local scope = scope_of(opts)
		local source = source_of()

		for _, m in ipairs(modes) do
			local key = m .. ":" .. lhs .. ":" .. scope
			local prev = seen[key]
			local allowed = prev and (source_allowlisted(source) or source_allowlisted(prev.source))

			if prev and not allowed then
				local record = {
					lhs = lhs,
					mode = m,
					first_source = prev.source,
					first_desc = prev.desc,
					second_source = source,
					second_desc = opts and opts.desc,
				}
				table.insert(M.collisions, record)
				vim.notify(
					string.format(
						"Keymap collision on %s (mode %s)\n1st: %s -- %s\n2nd: %s -- %s",
						lhs,
						m,
						record.first_source,
						record.first_desc or "(no desc)",
						record.second_source,
						record.second_desc or "(no desc)"
					),
					vim.log.levels.WARN,
					{ title = "Keymap collision" }
				)
			end

			seen[key] = { desc = opts and opts.desc, source = source }
		end

		return M.raw_set(mode, lhs, rhs, opts)
	end
end

return M

-- ============================================================================
-- KEYMAP REGISTRY -- diagnoses shortcut collisions the moment they happen.
-- ============================================================================
-- Monkeypatches vim.keymap.set with an O(1) dictionary lookup keyed by
-- mode+lhs+scope. A second bind of the same key fires a permanent toast
-- (timeout = false) instead of silently overwriting the first one.
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

--- Lua pattern matched against the collision's source (file:line). A match
--- silences the toast -- the plugin manager's own lazy-load stub creation.
M.ALLOWLIST_SOURCE_PATTERN = "lazy/core/handler/keys%.lua"

local function scope_of(opts)
	if not opts or opts.buffer == nil then
		return "global"
	end
	if opts.buffer == true then
		return tostring(vim.api.nvim_get_current_buf())
	end
	return tostring(opts.buffer)
end

local function source_of()
	local info = debug.getinfo(3, "Sl")
	if not info then
		return "?"
	end
	return info.short_src .. ":" .. info.currentline
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
			local allowed = prev
				and (source:find(M.ALLOWLIST_SOURCE_PATTERN) or prev.source:find(M.ALLOWLIST_SOURCE_PATTERN))

			if prev and not allowed then
				vim.notify(
					string.format(
						"Keymap collision on %s (mode %s)\n1st: %s -- %s\n2nd: %s -- %s",
						lhs,
						m,
						prev.source,
						prev.desc or "(no desc)",
						source,
						(opts and opts.desc) or "(no desc)"
					),
					vim.log.levels.WARN,
					{ title = "Keymap collision", timeout = false }
				)
			end

			seen[key] = { desc = opts and opts.desc, source = source }
		end

		return M.raw_set(mode, lhs, rhs, opts)
	end
end

return M

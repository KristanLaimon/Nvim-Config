-- ============================================================================
-- 🦊 KRS PLUGIN: launch.json IntelliSense Completion Provider for blink.cmp
-- ============================================================================
-- Provides dynamic completion items inside `launch.json` for:
-- 1. `pre_launch_tasks`: Discovered project tasks (npm scripts, Makefile targets,
--    go/cargo commands, .krsnvim/tasks.json).
-- 2. `runtime`: Available runtimes (bun, node, deno, python, go, php, dotnet, custom).
-- 3. `mode`: Launch modes (run, debug).
-- ============================================================================

local M = {}

local RUNTIMES = {
	{ label = "bun", detail = "Bun JavaScript/TypeScript runtime" },
	{ label = "node", detail = "Node.js JavaScript runtime (npx tsx for TS)" },
	{ label = "deno", detail = "Deno TypeScript/JavaScript runtime" },
	{ label = "python", detail = "Python interpreter" },
	{ label = "go", detail = "Go toolchain (go run)" },
	{ label = "php", detail = "PHP CLI binary" },
	{ label = "dotnet", detail = ".NET CLI (dotnet run)" },
	{ label = "custom", detail = "Custom command string" },
}

local MODES = {
	{ label = "run", detail = "Execute in terminal task window" },
	{ label = "debug", detail = "Launch with DAP interactive debugger" },
}

function M.new()
	return setmetatable({}, { __index = M })
end

function M:get_completions(context, callback)
	local buf = context.bufnr or vim.api.nvim_get_current_buf()
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

	if name ~= "launch.json" then
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
		return
	end

	local line = context.line or ""
	local col = context.cursor[2] or #line
	local before_cursor = line:sub(1, col)

	local items = {}

	-- Detect context
	local in_pre_launch = before_cursor:match('"pre_launch_tasks"%s*:%s*%[')
		or line:match('"pre_launch_tasks"')
		or before_cursor:match('pre_launch_tasks')

	local in_runtime = before_cursor:match('"runtime"%s*:%s*') or line:match('"runtime"')
	local in_mode = before_cursor:match('"mode"%s*:%s*') or line:match('"mode"')

	if in_pre_launch then
		local ok_tasks, tasks_mod = pcall(require, "plugins.krs.tasks")
		if ok_tasks then
			local root = tasks_mod.get_project_root()
			local discovered = tasks_mod.discover_tasks(root) or {}
			local saved = tasks_mod.get_all_saved_tasks(root) or {}

			local seen = {}
			for _, t in ipairs(saved) do
				local tname = type(t) == "table" and (t.name or t.cmd) or tostring(t)
				if tname and not seen[tname] then
					seen[tname] = true
					table.insert(items, {
						label = tname,
						kind = 12, -- Value / Event
						detail = "Saved Project Task",
						insertText = tname,
					})
				end
			end

			for _, t in ipairs(discovered) do
				local tname = t.name or t.cmd
				if tname and not seen[tname] then
					seen[tname] = true
					table.insert(items, {
						label = tname,
						kind = 12,
						detail = "Discovered Task (" .. (t.source or "Project") .. ")",
						insertText = tname,
					})
				end
			end
		end
	elseif in_runtime then
		for _, r in ipairs(RUNTIMES) do
			table.insert(items, {
				label = r.label,
				kind = 12,
				detail = r.detail,
				insertText = r.label,
			})
		end
	elseif in_mode then
		for _, m in ipairs(MODES) do
			table.insert(items, {
				label = m.label,
				kind = 12,
				detail = m.detail,
				insertText = m.label,
			})
		end
	end

	callback({
		items = items,
		is_incomplete_forward = false,
		is_incomplete_backward = false,
	})
end

_G.LaunchCmp = M

local plugin_spec = {
	name = "krs_launch_cmp",
	dir = require("krs.lazydir").for_module(),
	lazy = false,
	config = function()
		-- launch.json completion provider module initialized
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

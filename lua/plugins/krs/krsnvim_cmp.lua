-- ============================================================================
-- KRS PLUGIN: .krsnvim IntelliSense -- a blink.cmp completion source.
-- ============================================================================
-- WHAT IT COMPLETES (only inside `*.krsnvim` files)
--   console.<method>   log, dir, info, warn, error, debug, json, dump
--   fetch.<method>     get, post, put, delete, patch, head
--   import("<module>") json, yaml, toml, terminal, cli, fs, fetch, console, ...
--   krsnvim.<module>   the same library modules, as fields
--   anything else      the top-level globals available to a script
--
-- HOW TO ADD COMPLETIONS
--   Everything is data: append to the relevant list in `M.settings.contexts`.
--   `pattern` is matched against the text BEFORE the cursor; the first context
--   that matches wins, and the last one (no pattern) is the fallback.
--
-- WIRING
--   Registered as a blink.cmp source in lua/plugins/lsp/blink_sources.lua.
-- ============================================================================

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- LSP CompletionItemKind values used below.
local KIND = { method = 2, object = 3, module = 9, value = 12 }

--- Marks an item's `insertText` as an LSP snippet (`${1:...}` placeholders).
local SNIPPET = 2

M.settings = {
	--- Files this source fires in.
	file_pattern = "%.krsnvim$",
	filetype = "krsnvim",

	--- Checked in order; the first matching `pattern` wins, and an entry with no
	--- pattern is the fallback.
	contexts = {
		{
			pattern = "console%.%a*$",
			kind = KIND.method,
			items = {
				{ label = "log", detail = "console.log(...) - Print space-separated args / pretty JSON tables", insertText = "log(${1:data})", insertTextFormat = SNIPPET },
				{ label = "dir", detail = "console.dir(obj) - Inspect table object in multi-line indented JSON", insertText = "dir(${1:object})", insertTextFormat = SNIPPET },
				{ label = "info", detail = "console.info(...) - Log with ℹ️ [INFO] prefix", insertText = "info(${1:message})", insertTextFormat = SNIPPET },
				{ label = "warn", detail = "console.warn(...) - Log with ⚠️ [WARN] prefix", insertText = "warn(${1:message})", insertTextFormat = SNIPPET },
				{ label = "error", detail = "console.error(...) - Log with ❌ [ERROR] prefix", insertText = "error(${1:message})", insertTextFormat = SNIPPET },
				{ label = "debug", detail = "console.debug(...) - Log with 🐛 [DEBUG] prefix", insertText = "debug(${1:message})", insertTextFormat = SNIPPET },
				{ label = "json", detail = "console.json(obj) - Format object to indented JSON string", insertText = "json(${1:object})", insertTextFormat = SNIPPET },
				{ label = "dump", detail = "console.dump(obj) - Alias for console.dir", insertText = "dump(${1:object})", insertTextFormat = SNIPPET },
			},
		},
		{
			pattern = "fetch%.%a*$",
			kind = KIND.method,
			items = {
				{ label = "get", detail = "fetch.get(url, opts) - Perform HTTP GET request", insertText = 'get("${1:url}")', insertTextFormat = SNIPPET },
				{ label = "post", detail = "fetch.post(url, body, opts) - Perform HTTP POST request", insertText = 'post("${1:url}", ${2:body})', insertTextFormat = SNIPPET },
				{ label = "put", detail = "fetch.put(url, body, opts) - Perform HTTP PUT request", insertText = 'put("${1:url}", ${2:body})', insertTextFormat = SNIPPET },
				{ label = "delete", detail = "fetch.delete(url, opts) - Perform HTTP DELETE request", insertText = 'delete("${1:url}")', insertTextFormat = SNIPPET },
				{ label = "patch", detail = "fetch.patch(url, body, opts) - Perform HTTP PATCH request", insertText = 'patch("${1:url}", ${2:body})', insertTextFormat = SNIPPET },
				{ label = "head", detail = "fetch.head(url, opts) - Perform HTTP HEAD request", insertText = 'head("${1:url}")', insertTextFormat = SNIPPET },
			},
		},
		{
			pattern = 'import%s*%(%s*"?%a*$',
			kind = KIND.value,
			items = {
				{ label = '"json"', detail = "krsnvim.json - JSON parser & file I/O", insertText = '"json"' },
				{ label = '"yaml"', detail = "krsnvim.yaml - YAML parser & file I/O", insertText = '"yaml"' },
				{ label = '"toml"', detail = "krsnvim.toml - TOML parser & file I/O", insertText = '"toml"' },
				{ label = '"terminal"', detail = "krsnvim.terminal - Cross-platform shell execution", insertText = '"terminal"' },
				{ label = '"cli"', detail = "krsnvim.cli - CLI argument parser & menu helper", insertText = '"cli"' },
				{ label = '"fs"', detail = "krsnvim.fs - File system helper suite", insertText = '"fs"' },
				{ label = '"fetch"', detail = "krsnvim.fetch - HTTP/HTTPS fetch client", insertText = '"fetch"' },
				{ label = '"console"', detail = "krsnvim.console - Console logger & pretty-JSON printer", insertText = '"console"' },
				{ label = '"debug"', detail = "krsnvim.debug - Console debugger alias", insertText = '"debug"' },
				{ label = '"tests"', detail = "krsnvim.tests - Vitest-like testing framework", insertText = '"tests"' },
			},
		},
		{
			pattern = "krsnvim%.%a*$",
			kind = KIND.module,
			items = {
				{ label = "console", detail = "krsnvim.console - Console logger & pretty-JSON printer", insertText = "console" },
				{ label = "fetch", detail = "krsnvim.fetch - HTTP/HTTPS fetch client", insertText = "fetch" },
				{ label = "json", detail = "krsnvim.json - JSON parser & file I/O", insertText = "json" },
				{ label = "yaml", detail = "krsnvim.yaml - YAML parser & file I/O", insertText = "yaml" },
				{ label = "toml", detail = "krsnvim.toml - TOML parser & file I/O", insertText = "toml" },
				{ label = "terminal", detail = "krsnvim.terminal - Shell execution suite", insertText = "terminal" },
				{ label = "cli", detail = "krsnvim.cli - CLI argument parser & UI", insertText = "cli" },
				{ label = "fs", detail = "krsnvim.fs - File system helpers", insertText = "fs" },
				{ label = "tests", detail = "krsnvim.tests - Testing framework runner", insertText = "tests" },
			},
		},
		{
			-- Fallback: the globals a script starts with.
			items = {
				{ label = "console", kind = KIND.object, detail = "krsnvim.console - Human-readable console logger & JSON printer", insertText = "console.log(${1:data})", insertTextFormat = SNIPPET },
				{ label = "fetch", kind = KIND.object, detail = "krsnvim.fetch - HTTP/HTTPS Web-standard fetch client", insertText = 'fetch.get("${1:url}")', insertTextFormat = SNIPPET },
				{ label = "import", kind = KIND.object, detail = "krsnvim.import - Smart module & file loader", insertText = 'import("${1:module}")', insertTextFormat = SNIPPET },
				{ label = "krsnvim", kind = KIND.module, detail = "krsnvim - Automation library suite", insertText = "krsnvim" },
			},
		},
	},
}

-- ============================================================================
-- BLINK.CMP SOURCE INTERFACE
-- ============================================================================

--- Constructs a source instance. Required by blink.cmp.
--- @return table source
function M.new()
	return setmetatable({}, { __index = M })
end

--- Completions for the expression under the cursor.
--- @param context table blink.cmp context.
--- @param callback fun(result: table)
function M:get_completions(context, callback)
	local function respond(items)
		callback({ items = items or {}, is_incomplete_forward = false, is_incomplete_backward = false })
	end

	local buf = context.bufnr or vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	if not (name:match(M.settings.file_pattern) or vim.bo[buf].filetype == M.settings.filetype) then
		return respond({})
	end

	local line = context.line or ""
	local before_cursor = line:sub(1, context.cursor[2] or #line)

	for _, ctx in ipairs(M.settings.contexts) do
		if not ctx.pattern or before_cursor:match(ctx.pattern) then
			local items = {}
			for _, item in ipairs(ctx.items) do
				table.insert(items, {
					label = item.label,
					kind = item.kind or ctx.kind,
					detail = item.detail,
					insertText = item.insertText,
					insertTextFormat = item.insertTextFormat,
				})
			end
			return respond(items)
		end
	end

	respond({})
end

-- ============================================================================
-- LAZY.NVIM SPEC -- no config(): blink.cmp instantiates this source itself.
-- ============================================================================

return setmetatable({
	name = "krs_krsnvim_cmp",
	dir = require("krs.core.lazyspec").for_module(),
	lazy = false,
}, { __index = M })

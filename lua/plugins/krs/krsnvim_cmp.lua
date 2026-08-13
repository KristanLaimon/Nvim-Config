-- ============================================================================
-- 🦊 KRS PLUGIN: .krsnvim IntelliSense Completion Provider for blink.cmp
-- ============================================================================
-- Dedicated IntelliSense completion provider for `.krsnvim` scripts (`*.krsnvim`).
-- Exclusively fires inside `.krsnvim` files and provides completions for:
-- 1. `console`: console.log, console.dir, console.info, console.warn, console.error, console.debug, console.json
-- 2. `fetch`: fetch.get, fetch.post, fetch.put, fetch.delete, fetch.patch, fetch.head
-- 3. `import`: import("json"), import("yaml"), import("toml"), import("fs"), import("fetch"), import("console")
-- 4. `krsnvim`: krsnvim.console, krsnvim.fetch, krsnvim.json, krsnvim.fs, krsnvim.terminal, etc.
-- ============================================================================

local M = {}

local TOP_LEVEL_GLOBALS = {
	{
		label = "console",
		kind = 3, -- Function / Object
		detail = "krsnvim.console - Human-readable console logger & JSON printer",
		insertText = "console.log(${1:data})",
		insertTextFormat = 2, -- Snippet
	},
	{
		label = "fetch",
		kind = 3,
		detail = "krsnvim.fetch - HTTP/HTTPS Web-standard fetch client",
		insertText = 'fetch.get("${1:url}")',
		insertTextFormat = 2,
	},
	{
		label = "import",
		kind = 3,
		detail = "krsnvim.import - Smart module & file loader",
		insertText = 'import("${1:module}")',
		insertTextFormat = 2,
	},
	{
		label = "krsnvim",
		kind = 9, -- Module
		detail = "krsnvim - Automation library suite",
		insertText = "krsnvim",
	},
}

local CONSOLE_METHODS = {
	{ label = "log", detail = "console.log(...) - Print space-separated args / pretty JSON tables", insertText = "log(${1:data})", insertTextFormat = 2 },
	{ label = "dir", detail = "console.dir(obj) - Inspect table object in multi-line indented JSON", insertText = "dir(${1:object})", insertTextFormat = 2 },
	{ label = "info", detail = "console.info(...) - Log with ℹ️ [INFO] prefix", insertText = "info(${1:message})", insertTextFormat = 2 },
	{ label = "warn", detail = "console.warn(...) - Log with ⚠️ [WARN] prefix", insertText = "warn(${1:message})", insertTextFormat = 2 },
	{ label = "error", detail = "console.error(...) - Log with ❌ [ERROR] prefix", insertText = "error(${1:message})", insertTextFormat = 2 },
	{ label = "debug", detail = "console.debug(...) - Log with 🐛 [DEBUG] prefix", insertText = "debug(${1:message})", insertTextFormat = 2 },
	{ label = "json", detail = "console.json(obj) - Format object to indented JSON string", insertText = "json(${1:object})", insertTextFormat = 2 },
	{ label = "dump", detail = "console.dump(obj) - Alias for console.dir", insertText = "dump(${1:object})", insertTextFormat = 2 },
}

local FETCH_METHODS = {
	{ label = "get", detail = "fetch.get(url, opts) - Perform HTTP GET request", insertText = 'get("${1:url}")', insertTextFormat = 2 },
	{ label = "post", detail = "fetch.post(url, body, opts) - Perform HTTP POST request", insertText = 'post("${1:url}", ${2:body})', insertTextFormat = 2 },
	{ label = "put", detail = "fetch.put(url, body, opts) - Perform HTTP PUT request", insertText = 'put("${1:url}", ${2:body})', insertTextFormat = 2 },
	{ label = "delete", detail = "fetch.delete(url, opts) - Perform HTTP DELETE request", insertText = 'delete("${1:url}")', insertTextFormat = 2 },
	{ label = "patch", detail = "fetch.patch(url, body, opts) - Perform HTTP PATCH request", insertText = 'patch("${1:url}", ${2:body})', insertTextFormat = 2 },
	{ label = "head", detail = "fetch.head(url, opts) - Perform HTTP HEAD request", insertText = 'head("${1:url}")', insertTextFormat = 2 },
}

local IMPORT_MODULES = {
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
}

local KRSNVIM_SUBMODULES = {
	{ label = "console", detail = "krsnvim.console - Console logger & pretty-JSON printer", insertText = "console" },
	{ label = "fetch", detail = "krsnvim.fetch - HTTP/HTTPS fetch client", insertText = "fetch" },
	{ label = "json", detail = "krsnvim.json - JSON parser & file I/O", insertText = "json" },
	{ label = "yaml", detail = "krsnvim.yaml - YAML parser & file I/O", insertText = "yaml" },
	{ label = "toml", detail = "krsnvim.toml - TOML parser & file I/O", insertText = "toml" },
	{ label = "terminal", detail = "krsnvim.terminal - Shell execution suite", insertText = "terminal" },
	{ label = "cli", detail = "krsnvim.cli - CLI argument parser & UI", insertText = "cli" },
	{ label = "fs", detail = "krsnvim.fs - File system helpers", insertText = "fs" },
	{ label = "tests", detail = "krsnvim.tests - Testing framework runner", insertText = "tests" },
}

function M.new()
	return setmetatable({}, { __index = M })
end

function M:get_completions(context, callback)
	local buf = context.bufnr or vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(buf)
	local ft = vim.bo[buf].filetype

	-- Only activate inside .krsnvim files
	if not (buf_name:match("%.krsnvim$") or ft == "krsnvim") then
		callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
		return
	end

	local line = context.line or ""
	local col = context.cursor[2] or #line
	local before_cursor = line:sub(1, col)

	local items = {}

	if before_cursor:match("console%.%a*$") then
		for _, item in ipairs(CONSOLE_METHODS) do
			table.insert(items, {
				label = item.label,
				kind = 2, -- Method
				detail = item.detail,
				insertText = item.insertText,
				insertTextFormat = item.insertTextFormat,
			})
		end
	elseif before_cursor:match("fetch%.%a*$") then
		for _, item in ipairs(FETCH_METHODS) do
			table.insert(items, {
				label = item.label,
				kind = 2,
				detail = item.detail,
				insertText = item.insertText,
				insertTextFormat = item.insertTextFormat,
			})
		end
	elseif before_cursor:match('import%s*%(%s*"?%a*$') then
		for _, item in ipairs(IMPORT_MODULES) do
			table.insert(items, {
				label = item.label,
				kind = 12, -- Value
				detail = item.detail,
				insertText = item.insertText,
			})
		end
	elseif before_cursor:match("krsnvim%.%a*$") then
		for _, item in ipairs(KRSNVIM_SUBMODULES) do
			table.insert(items, {
				label = item.label,
				kind = 9, -- Module
				detail = item.detail,
				insertText = item.insertText,
			})
		end
	else
		for _, item in ipairs(TOP_LEVEL_GLOBALS) do
			table.insert(items, {
				label = item.label,
				kind = item.kind,
				detail = item.detail,
				insertText = item.insertText,
				insertTextFormat = item.insertTextFormat,
			})
		end
	end

	callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
end

local plugin_spec = {
	name = "krs_krsnvim_cmp",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
}

return setmetatable(plugin_spec, {
	__index = M,
})

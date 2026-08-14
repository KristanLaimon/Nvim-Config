-- ============================================================================
-- krs.core.store -- JSON file persistence for every KRS module.
-- ============================================================================
-- WHY THIS EXISTS
--   Ten plugins each carried their own `io.open` + `vim.json.decode` + pcall
--   dance to persist state (tasks, launch profiles, breakpoints, favorites,
--   workspaces, fonts, nuget cache...). Same six lines, ten chances to forget a
--   `pcall` and hard-error the editor on a truncated file.
--
-- CONTRACT
--   * Reads never throw. A missing or corrupt file yields the caller's fallback.
--   * Writes create parent directories and return ok/err instead of throwing.
--   * `nil` is never written: `save` refuses non-table values.
--
-- USAGE
--   local store = require("krs.core.store")
--   local data = store.load(path, {})           -- always a table here
--   local ok, err = store.save(path, data)      -- creates parent dirs
-- ============================================================================

local path_util = require("krs.core.path")

local M = {}

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

--- Reads a whole file as a string.
---
--- @param filepath string Path to read.
--- @return string|nil content File contents, or nil when unreadable.
function M.read_file(filepath)
	local f = io.open(filepath, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

--- Loads and decodes a JSON file.
--- Never throws: unreadable, empty and malformed files all return `fallback`.
---
--- @param filepath string Path to a JSON file.
--- @param fallback any Value returned when the file cannot be decoded. Default `{}`.
--- @return any data Decoded table, or `fallback`.
function M.load(filepath, fallback)
	if fallback == nil then
		fallback = {}
	end
	local content = M.read_file(filepath)
	if not content or content == "" then
		return fallback
	end
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	end
	return fallback
end

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

--- Writes a string to a file, creating parent directories as needed.
---
--- @param filepath string Destination path.
--- @param content string Content to write.
--- @return boolean ok
--- @return string|nil err Error message when `ok` is false.
function M.write_file(filepath, content)
	path_util.ensure_dir(vim.fs.dirname(filepath))
	local f, err = io.open(filepath, "w")
	if not f then
		return false, err or ("cannot open for writing: " .. filepath)
	end
	f:write(content)
	f:close()
	return true
end

--- Encodes a table as JSON and writes it, creating parent directories.
---
--- @param filepath string Destination path.
--- @param data table Table to serialize.
--- @return boolean ok
--- @return string|nil err Error message when `ok` is false.
function M.save(filepath, data)
	if type(data) ~= "table" then
		return false, "store.save expects a table, got " .. type(data)
	end
	local ok, encoded = pcall(vim.json.encode, data)
	if not ok then
		return false, tostring(encoded)
	end
	return M.write_file(filepath, encoded)
end

return M

--- @module krsnvim
--- Master Entry Point & Global `import()` helper for the `krsnvimscript` automation library suite.
--- Exposes `json`, `yaml`, `toml`, `terminal`, `cli`, `fs`, `fetch`, `wiki`, and `tests`.
---
--- @field json module krsnvim.json JSON parser and file I/O.
--- @field yaml module krsnvim.yaml YAML parser and file I/O.
--- @field toml module krsnvim.toml TOML parser and file I/O.
--- @field terminal module krsnvim.terminal Terminal command execution suite.
--- @field cli module krsnvim.cli CLI argument parser and menu UI helper.
--- @field fs module krsnvim.fs File system helper functions.
--- @field fetch module krsnvim.fetch Pure Lua HTTP/HTTPS fetch client.
--- @field wiki module krsnvim.wiki Floating documentation wiki system.
--- @field tests module krsnvim.tests Test suite runner.
---
--- @example
--- require("krsnvim")
--- local fetch = import("fetch")
--- local json = import("json")
--- local config = import("config.yaml")
local M = {}

M.json = require("krsnvim.json")
M.yaml = require("krsnvim.yaml")
M.toml = require("krsnvim.toml")
M.terminal = require("krsnvim.terminal")
M.cli = require("krsnvim.cli")
M.fs = require("krsnvim.fs")
M.fetch = require("krsnvim.fetch")
M.wiki = require("krsnvim.wiki")
M.tests = require("krsnvim.tests")
M.krsnvimtranspiler = require("krsnvim.krsnvimtranspiler")
M.exporter = M.krsnvimtranspiler

--- Global smart import function for `krsnvimscript`.
--- Automatically detects file extensions (`.json`, `.yaml`, `.yml`, `.toml`) or module aliases (`"fetch"`, `"json"`, `"fs"`, etc.).
---
--- @param target string Module name alias or file path to import.
--- @return any module_or_data Module table or parsed data structure.
---
--- @note Edge Cases & Errors:
--- - Throws error if `target` is `nil` or empty string.
--- - Automatically loads and decodes `.json`, `.yaml`, `.yml`, and `.toml` files if specified.
---
--- @see krsnvim.json.load
--- @see krsnvim.yaml.load
--- @see krsnvim.toml.load
---
--- @example
--- local fs = import("fs")
--- local fetch = import("fetch")
--- local pkg = import("package.json")
--- print(pkg.name)
_G.import = function(target)
	if not target or type(target) ~= "string" then
		error("import(): Target must be a non-empty string")
	end

	if target == "krsnvim.terminal" or target == "terminal" then
		return M.terminal
	elseif target == "krsnvim.json" or target == "json" then
		return M.json
	elseif target == "krsnvim.yaml" or target == "yaml" then
		return M.yaml
	elseif target == "krsnvim.toml" or target == "toml" then
		return M.toml
	elseif target == "krsnvim.cli" or target == "cli" then
		return M.cli
	elseif target == "krsnvim.fs" or target == "fs" then
		return M.fs
	elseif target == "krsnvim.fetch" or target == "fetch" then
		return M.fetch
	elseif target == "krsnvim.test" or target == "test" or target == "tests" then
		return M.tests
	elseif target == "krsnvim.krsnvimtranspiler" or target == "krsnvimtranspiler" or target == "krsnvim.exporter" or target == "exporter" then
		return M.krsnvimtranspiler
	end

	if target:match("%.json$") then
		return M.json.load(target)
	elseif target:match("%.yaml$") or target:match("%.yml$") then
		return M.yaml.load(target)
	elseif target:match("%.toml$") then
		return M.toml.load(target)
	end

	local ok, res = pcall(require, target)
	if ok then
		return res
	end

	if M.fs.exists(target) then
		if target:match("%.json$") then return M.json.load(target) end
		if target:match("%.yaml$") or target:match("%.yml$") then return M.yaml.load(target) end
		if target:match("%.toml$") then return M.toml.load(target) end
	end

	error("import(): Cannot import target: " .. tostring(target))
end

return M

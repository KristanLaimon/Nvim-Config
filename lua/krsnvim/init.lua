--- @module "krsnvim"
--- Master Entry Point for the `krsnvimscript` automation library suite.
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
--- local krs = require("krsnvim")
--- local fetch = krs.fetch
--- local json = krs.json
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
M.console = require("krsnvim.console")
M.debug = require("krsnvim.debug")
M.async = require("krsnvim.async")
M.concurrent = M.async
M.parallel = M.async
M.krsnvimtranspiler = require("krsnvim.krsnvimtranspiler")
M.exporter = M.krsnvimtranspiler

M.setTimeout = M.async.setTimeout
M.clearTimeout = M.async.clearTimeout
M.setInterval = M.async.setInterval
M.clearInterval = M.async.clearInterval

--- Setup global functions (setTimeout, clearTimeout, setInterval, clearInterval).
function M.setup_globals()
	_G.setTimeout = M.setTimeout
	_G.clearTimeout = M.clearTimeout
	_G.setInterval = M.setInterval
	_G.clearInterval = M.clearInterval
end

return M

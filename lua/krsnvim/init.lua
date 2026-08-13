local M = {}

M.json = require("krsnvim.json")
M.yaml = require("krsnvim.yaml")
M.toml = require("krsnvim.toml")
M.terminal = require("krsnvim.terminal")
M.cli = require("krsnvim.cli")
M.fs = require("krsnvim.fs")
M.wiki = require("krsnvim.wiki")
M.tests = require("krsnvim.tests")

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

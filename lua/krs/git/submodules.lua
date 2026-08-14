-- ============================================================================
-- krs.git.submodules -- Submodule discovery, listing and sorting.
-- ============================================================================
-- WHAT IT PRODUCES
--   A list of repository targets for Git Center:
--     [1] Root git repository (cwd / project root)
--     [2..n] Submodule repositories in alphabetical order
--
-- WHY THIS LIVES IN LAYER 2 (krs.git)
--   Pure Lua parsing and resolution with no UI or keymap dependencies, so it
--   can be unit-tested without floating windows or Neovim UI state.
-- ============================================================================

local git = require("krs.git.cmd")
local path_util = require("krs.core.path")

local M = {}

-- ---------------------------------------------------------------------------
-- Parsing
-- ---------------------------------------------------------------------------

--- Parses `git submodule status` lines into relative submodule paths.
--- Output lines look like:
---   ` 68b5a03bf18274a2b130e9d57a91176b91176b91 path/to/submodule (heads/main)`
---   `-68b5a03bf18274a2b130e9d57a91176b91176b91 path/to/submodule`
---   `+68b5a03bf18274a2b130e9d57a91176b91176b91 path/to/submodule`
---   `U68b5a03bf18274a2b130e9d57a91176b91176b91 path/to/submodule`
---
--- @param lines string[] Output lines from `git submodule status`.
--- @return string[] paths Clean list of relative submodule paths.
function M.parse_submodules(lines)
	local paths = {}
	local seen = {}

	for _, line in ipairs(lines or {}) do
		local clean_line = vim.trim(line)
		if clean_line ~= "" then
			-- Format: optional indicator [ + - U], commit hash, space, path
			local rel_path = clean_line:match("^[%+%-U%s]?%x+%s+(%S+)")
			if not rel_path then
				-- Fallback for lines like "submodule.<name>.path <path>" from git config
				rel_path = clean_line:match("^submodule%..*%.path%s+(.+)$")
			end

			if rel_path and rel_path ~= "" then
				rel_path = path_util.normalize(rel_path)
				if not seen[rel_path] then
					seen[rel_path] = true
					table.insert(paths, rel_path)
				end
			end
		end
	end

	return paths
end

-- ---------------------------------------------------------------------------
-- Discovery & Resolution
-- ---------------------------------------------------------------------------

--- Discovers submodules inside `root_cwd`.
---
--- @param root_cwd string|nil Repository root directory.
--- @return string[] paths Alphabetically sorted relative submodule paths.
function M.discover(root_cwd)
	root_cwd = root_cwd or vim.fn.getcwd()
	if not git.is_repository(root_cwd) then
		return {}
	end

	local lines = git.lines({ "submodule", "status" }, root_cwd)
	if #lines == 0 then
		-- Fallback check for .gitmodules config if status returned nothing
		lines = git.lines({ "config", "--file", ".gitmodules", "--get-regexp", "^submodule\\..*\\.path$" }, root_cwd)
	end

	local paths = M.parse_submodules(lines)
	table.sort(paths, function(a, b)
		return a:lower() < b:lower()
	end)
	return paths
end

--- Builds the complete list of repository tabs for Git Center.
---
--- @param root_cwd string|nil Root repository directory.
--- @return table[] targets Array of `{ name, path, is_root, full_path }`
function M.list(root_cwd)
	root_cwd = path_util.normalize(root_cwd or vim.fn.getcwd())
	local root_name = vim.fs.basename(root_cwd) or "Root"
	if root_name == "" then
		root_name = "Root"
	end

	local targets = {
		{
			name = string.format("📦 %s (Root)", root_name),
			path = ".",
			is_root = true,
			full_path = root_cwd,
		},
	}

	local submodules = M.discover(root_cwd)
	for _, sub_path in ipairs(submodules) do
		table.insert(targets, {
			name = string.format("📁 %s", sub_path),
			path = sub_path,
			is_root = false,
			full_path = path_util.join(root_cwd, sub_path),
		})
	end

	return targets
end

return M

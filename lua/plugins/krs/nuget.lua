-- ============================================================================
-- 🦊 KRS PLUGIN: Nuget Package Manager (C# projects only)
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Only activates when the current project contains a .csproj file.
-- 2. Reads <PackageReference> entries straight from the .csproj (no `dotnet
--    list package` dependency, works even on older SDKs).
-- 3. Add/Update/Remove shell out to the `dotnet` CLI, which is the tool that
--    actually mutates the .csproj correctly.
-- 4. Telescope picker (`:NugetManager`, `<leader>ng`):
--      [a] Add package      [u] Update package      [d] Remove package
-- ============================================================================

local M = {}

function M.has_csharp_project()
	return #vim.fn.globpath(vim.fn.getcwd(), "**/*.csproj", false, true) > 0
end

local function find_csproj(callback)
	local matches = vim.fn.globpath(vim.fn.getcwd(), "**/*.csproj", false, true)
	if #matches == 0 then
		vim.notify("No .csproj found in current project", vim.log.levels.WARN, { title = "Nuget" })
		return
	end
	if #matches == 1 then
		callback(matches[1])
		return
	end
	vim.ui.select(matches, { prompt = "Select .csproj:" }, function(choice)
		if choice then
			callback(choice)
		end
	end)
end

-- Parse <PackageReference Include="X" Version="Y" /> entries (either
-- attribute order) directly from the .csproj file
local function parse_packages(csproj_path)
	local packages = {}
	local seen = {}
	local f = io.open(csproj_path, "r")
	if not f then
		return packages
	end
	local content = f:read("*a")
	f:close()

	local function add(name, version)
		if not seen[name] then
			seen[name] = true
			table.insert(packages, { name = name, version = version })
		end
	end

	for include, version in content:gmatch('<PackageReference%s+Include="([^"]+)"%s+Version="([^"]+)"') do
		add(include, version)
	end
	for version, include in content:gmatch('<PackageReference%s+Version="([^"]+)"%s+Include="([^"]+)"') do
		add(include, version)
	end

	table.sort(packages, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return packages
end

local function run_dotnet(args, on_done)
	vim.notify("dotnet " .. table.concat(args, " "), vim.log.levels.INFO, { title = "Nuget" })
	vim.system(vim.list_extend({ "dotnet" }, args), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify(
					(result.stderr ~= "" and result.stderr or result.stdout) or "dotnet command failed",
					vim.log.levels.ERROR,
					{ title = "Nuget" }
				)
			else
				vim.notify("Done", vim.log.levels.INFO, { title = "Nuget" })
			end
			if on_done then
				on_done(result.code == 0)
			end
		end)
	end)
end

function M.show_picker(csproj)
	local ok_telescope = pcall(require, "telescope")
	if not ok_telescope then
		vim.notify("Telescope is not available for Nuget Manager", vim.log.levels.ERROR, { title = "Nuget" })
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local themes = require("telescope.themes")

	local packages = parse_packages(csproj)

	pickers
		.new(
			themes.get_dropdown({
				prompt_title = string.format(
					" 📦 Nuget [%s] (a: Add | u: Update | d: Remove) ",
					vim.fn.fnamemodify(csproj, ":t")
				),
				width = 0.75,
				results_title = "Package References",
			}),
			{
				finder = finders.new_table({
					results = packages,
					entry_maker = function(entry)
						return {
							value = entry,
							display = string.format("%s  (%s)", entry.name, entry.version),
							ordinal = entry.name,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, map)
					local function refresh()
						vim.schedule(function()
							M.show_picker(csproj)
						end)
					end

					local function add_package()
						actions.close(prompt_bufnr)
						vim.schedule(function()
							vim.ui.input({ prompt = "Package name to add: " }, function(name)
								if not name or name == "" then
									return
								end
								vim.ui.input({ prompt = "Version (blank = latest): " }, function(version)
									local args = { "add", csproj, "package", name }
									if version and version ~= "" then
										table.insert(args, "--version")
										table.insert(args, version)
									end
									run_dotnet(args, refresh)
								end)
							end)
						end)
					end
					map("n", "a", add_package)
					map("i", "<C-a>", add_package)

					local function remove_package()
						local selection = action_state.get_selected_entry()
						if not selection then
							return
						end
						actions.close(prompt_bufnr)
						vim.schedule(function()
							run_dotnet({ "remove", csproj, "package", selection.value.name }, refresh)
						end)
					end
					map("n", "d", remove_package)
					map("i", "<C-d>", remove_package)

					local function update_package()
						local selection = action_state.get_selected_entry()
						if not selection then
							return
						end
						actions.close(prompt_bufnr)
						vim.schedule(function()
							vim.ui.input(
								{ prompt = "New version for " .. selection.value.name .. " (blank = latest): " },
								function(version)
									local args = { "add", csproj, "package", selection.value.name }
									if version and version ~= "" then
										table.insert(args, "--version")
										table.insert(args, version)
									end
									run_dotnet(args, refresh)
								end
							)
						end)
					end
					map("n", "u", update_package)
					map("i", "<C-u>", update_package)

					return true
				end,
			}
		)
		:find()
end

function M.open_manager()
	find_csproj(function(csproj)
		M.show_picker(csproj)
	end)
end

function M.setup()
	if vim.fn.exists(":NugetManager") == 0 then
		vim.api.nvim_create_user_command("NugetManager", function()
			if not M.has_csharp_project() then
				vim.notify("No C# project (.csproj) found in current workspace", vim.log.levels.WARN, { title = "Nuget" })
				return
			end
			M.open_manager()
		end, { desc = "Open Nuget Package Manager (C# projects only)" })
	end

	vim.keymap.set("n", "<leader>ng", function()
		vim.cmd("NugetManager")
	end, { desc = "Nuget Package Manager" })
end

M.setup()

_G.NugetManager = M

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_nuget_manager",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

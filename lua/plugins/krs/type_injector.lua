-- ============================================================================
-- 🦊 KRS PLUGIN: Modular Type Injector (Lua & TypeScript / JavaScript)
-- ============================================================================
-- HOW THIS PLUGIN WORKS:
-- 1. Scans available type schemas from:
--      - /nvim/schemas-langs/lua/<schema_name>/
--      - /nvim/schemas-langs/typescript_javascript/<schema_name>/
-- 2. Integrates NPM Type Package Manager for TS/JS:
--      - Install @types packages directly from NPM
--      - Display version following from package.json
--      - Enable, Disable, Delete, and Version Update schemas
-- 3. Stores project-specific schema activations in .krsnvim/types.json (or .nvimkrs).
-- 4. Applies them per language:
--      - lua_ls  : Lua.workspace.library, live via didChangeConfiguration
--      - tsgo    : a single generated .krsnvim/types.d.ts holding /// <reference path>
-- 5. Offers an emergent Telescope popup menu.
-- 6. Portable lazy plugin spec exportable across Neovim configs.
-- ============================================================================

local M = {}

function M.get_project_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if (client.name == "tsgo" or client.name == "lua_ls") and client.root_dir then
			return vim.fs.normalize(client.root_dir)
		end
	end

	local dir = vim.api.nvim_buf_get_name(bufnr)
	dir = dir ~= "" and vim.fs.dirname(dir) or vim.fn.getcwd()
	dir = vim.fs.normalize(dir)

	local root = vim.fs.root(dir, {
		"tsconfig.json",
		"jsconfig.json",
		"package.json",
		".krsnvim",
		".nvimkrs",
		".git",
	})
	local home = vim.fs.normalize(vim.env.USERPROFILE or vim.env.HOME or ""):lower()
	if not root or vim.fs.normalize(root):lower() == home then
		return dir
	end
	return vim.fs.normalize(root)
end

function M.get_config_path(root)
	root = root or M.get_project_root()
	local norm_root = root:gsub("\\", "/")
	local krs_dir = norm_root .. "/.krsnvim"

	if vim.fn.isdirectory(krs_dir) == 1 then
		return krs_dir .. "/types.json"
	end

	local nvimkrs_file = norm_root .. "/.nvimkrs"
	if vim.fn.filereadable(nvimkrs_file) == 1 then
		return nvimkrs_file
	end

	return krs_dir .. "/types.json"
end

function M.load_project_types(root)
	root = root or M.get_project_root()
	local filepath = M.get_config_path(root)

	if vim.fn.filereadable(filepath) == 0 then
		return { lua = {}, typescript_javascript = {} }
	end

	local content = table.concat(vim.fn.readfile(filepath), "\n")
	if content == "" then
		return { lua = {}, typescript_javascript = {} }
	end

	local ok, parsed = pcall(vim.json.decode, content)
	if not ok or type(parsed) ~= "table" then
		return { lua = {}, typescript_javascript = {} }
	end

	if parsed.types and type(parsed.types) == "table" then
		parsed = parsed.types
	end

	local lua_types = (type(parsed.lua) == "table") and parsed.lua or {}
	local ts_types = (type(parsed.typescript_javascript) == "table") and parsed.typescript_javascript or {}

	return {
		lua = lua_types,
		typescript_javascript = ts_types,
	}
end

function M.save_project_types(root, data)
	root = root or M.get_project_root()
	local filepath = M.get_config_path(root)
	local norm_filepath = filepath:gsub("\\", "/")

	local parent_dir = vim.fs.dirname(norm_filepath)
	if parent_dir and vim.fn.isdirectory(parent_dir) == 0 then
		vim.fn.mkdir(parent_dir, "p")
	end

	if norm_filepath:sub(-8) == ".nvimkrs" and vim.fn.filereadable(norm_filepath) == 1 then
		local content = table.concat(vim.fn.readfile(norm_filepath), "\n")
		local ok, parsed = pcall(vim.json.decode, content)
		if ok and type(parsed) == "table" then
			parsed.types = data
			local json_str = vim.json.encode(parsed)
			vim.fn.writefile(vim.split(json_str, "\n"), norm_filepath)
			return
		end
	end

	local json_str = vim.json.encode(data)
	vim.fn.writefile(vim.split(json_str, "\n"), norm_filepath)
end

function M.get_schema_roots(lang)
	return {
		vim.fs.normalize(vim.fn.stdpath("data") .. "/schemas-langs/" .. lang),
		vim.fs.normalize(vim.fn.stdpath("config") .. "/schemas-langs/" .. lang),
	}
end

function M.get_schemas_base_dir(lang)
	return M.get_schema_roots(lang)[1]
end

function M.resolve_schema_dir(lang, schema_name)
	for _, root in ipairs(M.get_schema_roots(lang)) do
		local p = root .. "/" .. schema_name
		if vim.fn.isdirectory(p) == 1 then
			return p
		end
	end
	return nil
end

function M.scan_available_schemas(lang)
	local seen = {}
	local results = {}
	for _, schemas_dir in ipairs(M.get_schema_roots(lang)) do
		if vim.fn.isdirectory(schemas_dir) == 1 then
			for _, name in ipairs(vim.fn.readdir(schemas_dir)) do
				if not seen[name] and vim.fn.isdirectory(schemas_dir .. "/" .. name) == 1 then
					seen[name] = true
					table.insert(results, name)
				end
			end
		end
	end
	table.sort(results)
	return results
end

function M.get_schema_version(lang, schema_name)
	local schemas_dir = M.resolve_schema_dir(lang, schema_name)
	if not schemas_dir then
		return nil
	end

	local paths_to_try = {
		schemas_dir .. "/package.json",
		schemas_dir .. "/node_modules/@types/" .. schema_name .. "/package.json",
	}

	for _, p in ipairs(paths_to_try) do
		if vim.fn.filereadable(p) == 1 then
			local content = table.concat(vim.fn.readfile(p), "\n")
			local ok, parsed = pcall(vim.json.decode, content)
			if ok and parsed and parsed.version then
				return "v" .. tostring(parsed.version)
			end
		end
	end
	return nil
end

function M.get_active_lua_libraries(root)
	local active = M.load_project_types(root).lua
	local lib_paths = { vim.env.VIMRUNTIME }

	for _, name in ipairs(active) do
		local schema_path = M.resolve_schema_dir("lua", name)
		if schema_path then
			table.insert(lib_paths, schema_path)
		end
	end
	return lib_paths
end

M.REF_FILE = ".krsnvim/types.d.ts"
M.INCLUDE_GLOB = ".krsnvim/**/*.d.ts"

local function patch_include(cfg, glob)
	local content = table.concat(vim.fn.readfile(cfg), "\n")
	if content:find(glob, 1, true) then
		return true
	end

	local patched
	if content:find('"include"%s*:%s*%[%s*%]') then
		patched = content:gsub('"include"%s*:%s*%[%s*%]', '"include": ["' .. glob .. '"]', 1)
	elseif content:find('"include"%s*:%s*%[') then
		patched = content:gsub('("include"%s*:%s*%[)', '%1 "' .. glob .. '",', 1)
	elseif content:find("^%s*{") then
		local entries = content:find('"files"%s*:') and '"' .. glob .. '"' or '"**/*", "' .. glob .. '"'
		patched = content:gsub("^(%s*{)", "%1\n\t\"include\": [" .. entries .. "],", 1)
	else
		return false
	end

	if patched == content then
		return false
	end
	vim.fn.writefile(vim.split(patched, "\n"), cfg)
	return true
end

local function ensure_ts_project_config(norm_root)
	local found = vim.fs.find({ "tsconfig.json", "jsconfig.json" }, {
		path = norm_root,
		upward = true,
		type = "file",
		limit = 1,
	})
	local cfg = found[1]

	if not cfg then
		vim.fn.writefile({
			"{",
			'\t"compilerOptions": {',
			'\t\t"allowJs": true',
			"\t},",
			'\t"include": ["**/*", "' .. M.INCLUDE_GLOB .. '"]',
			"}",
		}, norm_root .. "/tsconfig.json")
		vim.notify(
			"Created tsconfig.json -- tsgo ignores injected types without one.",
			vim.log.levels.INFO,
			{ title = "KRS Type Injector" }
		)
		return
	end

	cfg = vim.fs.normalize(cfg)

	local cfg_dir = vim.fs.dirname(cfg)
	local glob = M.INCLUDE_GLOB
	if cfg_dir:lower() ~= norm_root:lower() then
		glob = norm_root:sub(#cfg_dir + 2) .. "/" .. M.INCLUDE_GLOB
	end

	if not patch_include(cfg, glob) then
		vim.notify(
			'Add "' .. glob .. '" to "include" in ' .. cfg .. "\ninjected types stay inactive until then.",
			vim.log.levels.WARN,
			{ title = "KRS Type Injector" }
		)
	end
end

local function active_schema_entries(active_names)
	local entries = {}
	for _, name in ipairs(active_names) do
		local schema_dir = M.resolve_schema_dir("typescript_javascript", name)
		if schema_dir then
			local types_dir = schema_dir .. "/node_modules/@types"
			if vim.fn.isdirectory(types_dir) == 1 then
				for pkg, kind in vim.fs.dir(types_dir) do
					local index = types_dir .. "/" .. pkg .. "/index.d.ts"
					if kind == "directory" and vim.fn.filereadable(index) == 1 then
						table.insert(entries, index)
					end
				end
			else
				local index = schema_dir .. "/index.d.ts"
				if vim.fn.filereadable(index) == 1 then
					table.insert(entries, index)
				else
					for _, f in ipairs(vim.fn.glob(schema_dir .. "/*.d.ts", false, true)) do
						table.insert(entries, vim.fs.normalize(f))
					end
				end
			end
		end
	end
	table.sort(entries)
	return entries
end

function M.sync_ts_type_links(root, active_names)
	local norm_root = vim.fs.normalize(root)
	local ref_file = norm_root .. "/" .. M.REF_FILE
	local entries = active_schema_entries(active_names or {})

	local function notify_tsgo(kind, also_config)
		local changes = { { uri = vim.uri_from_fname(ref_file), type = kind } }
		if also_config then
			table.insert(changes, { uri = vim.uri_from_fname(norm_root .. "/tsconfig.json"), type = 1 })
		end
		for _, client in ipairs(vim.lsp.get_clients({ name = "tsgo" })) do
			client:notify("workspace/didChangeWatchedFiles", { changes = changes })
		end
	end

	if #entries == 0 then
		if vim.fn.filereadable(ref_file) == 1 then
			vim.fn.delete(ref_file)
			notify_tsgo(3, false)
		end
		return
	end

	local had_config = vim.fn.filereadable(norm_root .. "/tsconfig.json") == 1
	ensure_ts_project_config(norm_root)

	local ref_dir = vim.fs.dirname(ref_file)
	if vim.fn.isdirectory(ref_dir) == 0 then
		vim.fn.mkdir(ref_dir, "p")
	end

	local ref_lines = { "// Auto-generated by KRS Type Injector -- do not edit." }
	for _, path in ipairs(entries) do
		table.insert(ref_lines, '/// <reference path="' .. path .. '" />')
	end
	vim.fn.writefile(ref_lines, ref_file)

	notify_tsgo(1, not had_config)
end

function M.apply_lsp_settings(root, opts)
	root = root or M.get_project_root()
	opts = opts or {}
	local active_data = M.load_project_types(root)

	local lua_libs = M.get_active_lua_libraries(root)
	local lua_clients = vim.lsp.get_clients({ name = "lua_ls" })
	for _, client in ipairs(lua_clients) do
		if client.config and client.config.settings and client.config.settings.Lua then
			client.config.settings.Lua.workspace = client.config.settings.Lua.workspace or {}
			client.config.settings.Lua.workspace.library = lua_libs
			client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
		end
	end
	M.sync_ts_type_links(root, active_data.typescript_javascript)
end

function M.install_npm_types(input_pkg, callback)
	if not input_pkg or input_pkg == "" then
		return
	end

	local pkg_name = input_pkg:gsub("^%s+", ""):gsub("%s+$", "")
	local target_ver = ""
	
	if pkg_name:find("@", 2) then
		local at_idx = pkg_name:find("@", 2)
		target_ver = pkg_name:sub(at_idx + 1)
		pkg_name = pkg_name:sub(1, at_idx - 1)
	end

	local full_npm_pkg = pkg_name
	local schema_folder = pkg_name

	if not pkg_name:find("^@") then
		full_npm_pkg = "@types/" .. pkg_name
		schema_folder = pkg_name
	else
		schema_folder = pkg_name:gsub("^@", ""):gsub("/", "__")
	end

	if target_ver ~= "" then
		full_npm_pkg = full_npm_pkg .. "@" .. target_ver
	end

	local base_dir = M.get_schemas_base_dir("typescript_javascript")
	local schema_dir = base_dir .. "/" .. schema_folder

	if vim.fn.isdirectory(schema_dir) == 0 then
		vim.fn.mkdir(schema_dir, "p")
	end

	vim.notify("📦 Installing " .. full_npm_pkg .. " via npm...", vim.log.levels.INFO, { title = "KRS Type Injector" })

	local pkg_json = schema_dir .. "/package.json"
	if vim.fn.filereadable(pkg_json) == 0 then
		vim.fn.writefile({ '{"name": "krs-schema-' .. schema_folder .. '", "private": true}' }, pkg_json)
	end

	local cmd = { "npm", "install", "--save-dev", full_npm_pkg }

	vim.system(cmd, { cwd = schema_dir }, function(obj)
		vim.schedule(function()
			if obj.code == 0 then
				vim.notify("✅ Installed " .. full_npm_pkg .. " successfully!", vim.log.levels.INFO, { title = "KRS Type Injector" })
				if callback then
					callback(true, schema_folder)
				end
			else
				vim.notify("❌ Failed to install " .. full_npm_pkg .. ":\n" .. (obj.stderr or ""), vim.log.levels.ERROR, { title = "KRS Type Injector" })
				if callback then
					callback(false, schema_folder)
				end
			end
		end)
	end)
end

function M.open_menu()
	local root = M.get_project_root()
	local current_ft = vim.bo.filetype
	local active_data = M.load_project_types(root)

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local function open_schema_picker(lang_key, lang_label)
		local available = M.scan_available_schemas(lang_key)
		local active_set = {}
		for _, name in ipairs(active_data[lang_key] or {}) do
			active_set[name] = true
		end

		local items = {}
		for _, name in ipairs(available) do
			local is_active = active_set[name] == true
			local ver = M.get_schema_version(lang_key, name)
			local ver_tag = ver and (" (" .. ver .. ")") or ""
			local display_name = (is_active and "✅ " or "⬜ ") .. name .. ver_tag
			table.insert(items, {
				name = name,
				is_active = is_active,
				display = display_name,
				lang = lang_key,
			})
		end

		if #items == 0 and lang_key == "typescript_javascript" then
			table.insert(items, {
				name = "__install_new__",
				is_active = false,
				display = "➕ [No schemas found] Press Ctrl+N to install from NPM",
				lang = lang_key,
			})
		end

		pickers.new({
			prompt_title = " 💉 Type Injector (" .. lang_label .. ") | Enter/Tab: Toggle | Ctrl+N: Install NPM | Ctrl+D: Delete ",
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					local active_prefix = entry.is_active and "0_" or "1_"
					return {
						value = entry,
						display = entry.display,
						ordinal = active_prefix .. entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local function toggle_selected()
					local selection = action_state.get_selected_entry()
					if not selection or not selection.value then
						return
					end
					local item = selection.value

					if item.name == "__install_new__" then
						actions.close(prompt_bufnr)
						vim.schedule(function()
							vim.ui.input({ prompt = "Enter NPM package name (e.g. node, express, react): " }, function(pkg)
								if pkg and pkg ~= "" then
									M.install_npm_types(pkg, function(ok, installed_schema)
										if ok then
											table.insert(active_data.typescript_javascript, installed_schema)
											M.save_project_types(root, active_data)
											M.apply_lsp_settings(root)
										end
										M.open_menu()
									end)
								end
							end)
						end)
						return
					end

					if item.is_active then
						local new_list = {}
						for _, n in ipairs(active_data[lang_key]) do
							if n ~= item.name then
								table.insert(new_list, n)
							end
						end
						active_data[lang_key] = new_list
					else
						table.insert(active_data[lang_key], item.name)
					end

					M.save_project_types(root, active_data)
					M.apply_lsp_settings(root)

					actions.close(prompt_bufnr)
					vim.schedule(function()
						open_schema_picker(lang_key, lang_label)
					end)
				end

				actions.select_default:replace(toggle_selected)
				map("n", "<Space>", toggle_selected)
				map({ "i", "n" }, "<Tab>", toggle_selected)

				local function install_action()
					actions.close(prompt_bufnr)
					vim.schedule(function()
						vim.ui.input({ prompt = "Enter NPM type package (e.g. node, express@18, react): " }, function(pkg)
							if pkg and pkg ~= "" then
								M.install_npm_types(pkg, function(ok, installed_schema)
									if ok then
										local exists = false
										for _, n in ipairs(active_data.typescript_javascript) do
											if n == installed_schema then
												exists = true
												break
											end
										end
										if not exists then
											table.insert(active_data.typescript_javascript, installed_schema)
											M.save_project_types(root, active_data)
											M.apply_lsp_settings(root)
										end
									end
									M.open_menu()
								end)
							end
						end)
					end)
				end

				map({ "i", "n" }, "<C-n>", install_action)
				map({ "i", "n" }, "<C-i>", install_action)
				map("n", "i", install_action)

				local function delete_action()
					local selection = action_state.get_selected_entry()
					if not selection or not selection.value then
						return
					end
					local item = selection.value
					if item.name == "__install_new__" then
						return
					end

					actions.close(prompt_bufnr)
					vim.schedule(function()
						vim.ui.input({ prompt = "Delete schema '" .. item.name .. "' from store? (y/n): " }, function(ans)
							if ans and ans:lower() == "y" then
								local schema_dir = M.resolve_schema_dir(lang_key, item.name)
								if schema_dir then
									vim.fn.delete(schema_dir, "rf")
								end

								local new_list = {}
								for _, n in ipairs(active_data[lang_key]) do
									if n ~= item.name then
										table.insert(new_list, n)
									end
								end
								active_data[lang_key] = new_list
								M.save_project_types(root, active_data)
								M.apply_lsp_settings(root)
								vim.notify("🗑️ Schema deleted: " .. item.name, vim.log.levels.INFO, { title = "KRS Type Injector" })
							end
							open_schema_picker(lang_key, lang_label)
						end)
					end)
				end

				map({ "i", "n" }, "<C-d>", delete_action)
				map("n", "d", delete_action)

				return true
			end,
		}):find()
	end

	if current_ft == "lua" then
		open_schema_picker("lua", "Lua")
	elseif current_ft == "typescript" or current_ft == "javascript" or current_ft == "typescriptreact" or current_ft == "javascriptreact" then
		open_schema_picker("typescript_javascript", "TypeScript / JavaScript")
	else
		vim.ui.select({ "1. Lua", "2. TypeScript / JavaScript" }, { prompt = "Select Language for Type Injector:" }, function(choice)
			if choice and choice:find("Lua") then
				open_schema_picker("lua", "Lua")
			elseif choice and choice:find("TypeScript") then
				open_schema_picker("typescript_javascript", "TypeScript / JavaScript")
			end
		end)
	end
end

function M.gitignore_generated(root)
	root = root or M.get_project_root()
	local norm_root = vim.fs.normalize(root):gsub("\\", "/")
	local gitignore = norm_root .. "/.gitignore"
	local entry = M.REF_FILE

	local lines = {}
	if vim.fn.filereadable(gitignore) == 1 then
		lines = vim.fn.readfile(gitignore)
		for _, l in ipairs(lines) do
			if vim.trim(l) == entry then
				vim.notify(entry .. " ya está en .gitignore", vim.log.levels.INFO, { title = "KRS Type Injector" })
				return
			end
		end
	end

	table.insert(lines, entry)
	vim.fn.writefile(lines, gitignore)
	vim.notify("Agregado '" .. entry .. "' a .gitignore", vim.log.levels.INFO, { title = "KRS Type Injector" })
end

function M.setup()
	vim.api.nvim_create_user_command("TypeInjector", function()
		M.open_menu()
	end, { desc = "Open KRS Modular Type Injector Menu" })

	vim.api.nvim_create_user_command("KrsTypes", function()
		M.open_menu()
	end, { desc = "Open KRS Modular Type Injector Menu" })

	vim.api.nvim_create_user_command("KrsGitignoreGenerated", function()
		M.gitignore_generated()
	end, { desc = "Add .krsnvim/types.d.ts (auto-generated) to .gitignore" })

	local group = vim.api.nvim_create_augroup("KrsTypeInjectorGroup", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client and (client.name == "lua_ls" or client.name == "tsgo") then
				M.apply_lsp_settings(M.get_project_root())
			end
		end,
	})
end

_G.TypeInjector = M

M.setup()

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_type_injector",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

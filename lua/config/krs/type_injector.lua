-- ============================================================================
-- 🦊 KRS CONFIG: Modular Type Injector (Lua & TypeScript / JavaScript)
-- ============================================================================
-- HOW THIS MODULE WORKS:
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
--      - tsgo    : a single generated .krsnvim/types.d.ts holding /// <reference
--                  path> lines pointing straight into the schema store. Nothing is
--                  installed or copied into the project. Changes are pushed with
--                  didChangeWatchedFiles, so toggling applies without a restart.
--                  Needs a tsconfig.json/jsconfig.json whose `include` lists
--                  .krsnvim/**/*.d.ts (default globs skip dot-directories); one is
--                  created, or the glob patched in, when missing. Also requires
--                  Automatic Type Acquisition to be off (see lua/plugins/lsp/lsp.lua)
--                  or tsgo supplies its own @types a few seconds after attach and
--                  the enable/disable state means nothing.
-- 5. Offers an emergent Telescope popup menu (accessed via Command Palette or :TypeInjector).
-- ============================================================================

local M = {}

-- Project root for type activation. This MUST agree with the root the language
-- server picked: anything written outside it is invisible to the server, so the
-- generated files land somewhere harmless-looking and nothing works.
--
-- tasks.get_project_root() is deliberately not reused here. It searches upward for
-- .git/Makefile/package.json/..., and a bare project that has none of them escapes
-- into an unrelated ancestor -- a lone main.ts under AppData/Local/Temp/... resolves
-- all the way up to C:/Users/<you>/AppData/Local/Temp.
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

	-- Same markers tsgo's root_dir uses, with the same guard against rooting at $HOME
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

-- Resolve configuration filepath (.krsnvim/types.json or .nvimkrs)
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

	-- Default to .krsnvim directory
	return krs_dir .. "/types.json"
end

-- Read project type activations
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

-- Save project type activations
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

-- All roots a schema may live in: stdpath("data") is the npm install target,
-- stdpath("config") ships the hand-written ones. Both are always searched --
-- picking only one silently hides half the store.
function M.get_schema_roots(lang)
	return {
		vim.fs.normalize(vim.fn.stdpath("data") .. "/schemas-langs/" .. lang),
		vim.fs.normalize(vim.fn.stdpath("config") .. "/schemas-langs/" .. lang),
	}
end

-- Where new npm schemas get installed
function M.get_schemas_base_dir(lang)
	return M.get_schema_roots(lang)[1]
end

-- Absolute path of one schema, searched across every root
function M.resolve_schema_dir(lang, schema_name)
	for _, root in ipairs(M.get_schema_roots(lang)) do
		local p = root .. "/" .. schema_name
		if vim.fn.isdirectory(p) == 1 then
			return p
		end
	end
	return nil
end

-- Discover available schema subdirectories across all schemas-langs/<lang>/ roots
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

-- Read version string from package.json if available
function M.get_schema_version(lang, schema_name)
	local schemas_dir = M.resolve_schema_dir(lang, schema_name)
	if not schemas_dir then
		return nil
	end

	-- Try direct package.json or node_modules/@types/<schema>/package.json
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

-- Get list of absolute directory paths for active Lua schemas
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

-- The single generated file activation writes into a project.
-- It lives beside types.json in .krsnvim/. tsconfig's default `include` of "**/*"
-- never matches dot-prefixed folders, so the project's config must list the glob
-- below explicitly -- see ensure_ts_project_config.
M.REF_FILE = ".krsnvim/types.d.ts"
M.INCLUDE_GLOB = ".krsnvim/**/*.d.ts"

-- tsgo only loads the generated reference file when the project is a *configured*
-- project. With no tsconfig/jsconfig it builds an inferred project holding just the
-- opened files, and every injected type is silently ignored. Create the smallest
-- config that fixes that, unless some directory above already provides one (a
-- monorepo package is covered by the config at the repo root).
-- allowJs is the one non-empty setting: without it a bare `{}` would leave .js
-- files out of the program, so activation would do nothing in a JS project.
-- Add the .krsnvim glob to an existing config's `include`, editing the text rather
-- than re-encoding it: tsconfig files are routinely JSONC, and a parse/encode round
-- trip would strip the user's comments and reorder their keys. Returns false when
-- the shape is unfamiliar, so the caller can ask for the one-line edit instead.
local function patch_include(cfg, glob)
	local content = table.concat(vim.fn.readfile(cfg), "\n")
	if content:find(glob, 1, true) then
		return true
	end

	local patched
	if content:find('"include"%s*:%s*%[%s*%]') then
		-- empty array; replacing wholesale avoids leaving a trailing comma
		patched = content:gsub('"include"%s*:%s*%[%s*%]', '"include": ["' .. glob .. '"]', 1)
	elseif content:find('"include"%s*:%s*%[') then
		patched = content:gsub('("include"%s*:%s*%[)', '%1 "' .. glob .. '",', 1)
	elseif content:find("^%s*{") then
		-- no include key. Spelling out "**/*" keeps the default that adding an
		-- include would otherwise cancel -- except when `files` already narrows
		-- the program on purpose, where broadening it would be wrong.
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

	-- The config may sit above us in a monorepo; its include globs are relative to
	-- itself, so the path has to be walked back from there.
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

-- Entry .d.ts of each active schema, as absolute paths into the schema store.
local function active_schema_entries(active_names)
	local entries = {}
	for _, name in ipairs(active_names) do
		local schema_dir = M.resolve_schema_dir("typescript_javascript", name)
		if schema_dir then
			-- npm-installed schema: every @types package it pulled in
			local types_dir = schema_dir .. "/node_modules/@types"
			if vim.fn.isdirectory(types_dir) == 1 then
				for pkg, kind in vim.fs.dir(types_dir) do
					local index = types_dir .. "/" .. pkg .. "/index.d.ts"
					if kind == "directory" and vim.fn.filereadable(index) == 1 then
						table.insert(entries, index)
					end
				end
			else
				-- hand-written schema folder: index.d.ts, else every .d.ts in it
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

-- Point the project at the schemas without copying, installing or linking anything.
--
-- One generated file, .krsnvim/types.d.ts, holds a `/// <reference path>` per active
-- schema, each an absolute path straight into the nvim schema store. Nothing enters
-- the project's node_modules -- it need not even exist. Transitive deps still
-- resolve, because TypeScript resolves them relative to the referenced .d.ts's own
-- location, which is inside the store's node_modules (@types/node finds its
-- undici-types there).
--
-- Deactivating removes the file, and with it every injected type.
--
-- tsgo is told about the change with workspace/didChangeWatchedFiles rather than
-- being restarted. The old code ran `:LspRestart tsgo` inside a pcall, but that
-- command does not exist here (E492) -- the pcall swallowed it and every toggle was
-- a silent no-op, so nothing took effect until nvim was restarted. The notification
-- is also instant and keeps the client and its warm project state alive.
function M.sync_ts_type_links(root, active_names)
	local norm_root = vim.fs.normalize(root)
	local ref_file = norm_root .. "/" .. M.REF_FILE
	local entries = active_schema_entries(active_names or {})

	-- 1 = Created, 3 = Deleted (LSP FileChangeType)
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

-- Live apply active schema settings to running LSP clients
function M.apply_lsp_settings(root, opts)
	root = root or M.get_project_root()
	opts = opts or {}
	local active_data = M.load_project_types(root)

	-- 1. Apply to lua_ls
	local lua_libs = M.get_active_lua_libraries(root)
	local lua_clients = vim.lsp.get_clients({ name = "lua_ls" })
	for _, client in ipairs(lua_clients) do
		if client.config and client.config.settings and client.config.settings.Lua then
			client.config.settings.Lua.workspace = client.config.settings.Lua.workspace or {}
			client.config.settings.Lua.workspace.library = lua_libs
			client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
		end
	end
	-- 2. Apply to TypeScript / JavaScript: rewrite the generated reference file and
	-- tell tsgo it changed. sync_ts_type_links handles the notification itself, so
	-- toggling takes effect immediately without restarting the client.
	M.sync_ts_type_links(root, active_data.typescript_javascript)
end

-- Asynchronously install npm type package into /nvim-data/schemas-langs/typescript_javascript/<schema_name>
function M.install_npm_types(input_pkg, callback)
	if not input_pkg or input_pkg == "" then
		return
	end

	-- Parse package name and optional version
	local pkg_name = input_pkg:gsub("^%s+", ""):gsub("%s+$", "")
	local target_ver = ""
	
	if pkg_name:find("@", 2) then
		local at_idx = pkg_name:find("@", 2)
		target_ver = pkg_name:sub(at_idx + 1)
		pkg_name = pkg_name:sub(1, at_idx - 1)
	end

	-- Ensure @types/ prefix if user provided short package name like 'express' or 'node'
	local full_npm_pkg = pkg_name
	local schema_folder = pkg_name

	if not pkg_name:find("^@") then
		full_npm_pkg = "@types/" .. pkg_name
	elseif pkg_name:find("^@types/") then
		schema_folder = pkg_name:sub(8)
	end

	if target_ver ~= "" then
		full_npm_pkg = full_npm_pkg .. "@" .. target_ver
	end

	local target_dir = M.get_schemas_base_dir("typescript_javascript") .. "/" .. schema_folder
	if vim.fn.isdirectory(target_dir) == 0 then
		vim.fn.mkdir(target_dir, "p")
	end

	vim.notify("📦 Installing " .. full_npm_pkg .. " via npm...", vim.log.levels.INFO, { title = "KRS Type Injector" })

	-- Minimal package.json so npm installs here instead of walking up to a parent
	local pkg_json = target_dir .. "/package.json"
	if vim.fn.filereadable(pkg_json) == 0 then
		vim.fn.writefile({ '{ "name": "krs-schema-' .. schema_folder .. '", "private": true }' }, pkg_json)
	end

	-- List form + cwd: no shell involved, so it works under bash, cmd and pwsh alike.
	-- Windows needs npm.cmd explicitly; the extensionless "npm" shim is a shell script.
	local npm = vim.fn.has("win32") == 1 and "npm.cmd" or "npm"

	vim.fn.jobstart({ npm, "install", full_npm_pkg, "--save-dev" }, {
		cwd = target_dir,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				local root = M.get_project_root()
				local active_data = M.load_project_types(root)
				
				-- Auto-activate schema for current project
				local exists = false
				for _, s in ipairs(active_data.typescript_javascript) do
					if s == schema_folder then exists = true break end
				end
				if not exists then
					table.insert(active_data.typescript_javascript, schema_folder)
					table.sort(active_data.typescript_javascript)
					M.save_project_types(root, active_data)
				end

				M.apply_lsp_settings(root)

				local ver_str = M.get_schema_version("typescript_javascript", schema_folder) or ""
				vim.notify("✅ Successfully installed " .. full_npm_pkg .. " " .. ver_str, vim.log.levels.INFO, { title = "KRS Type Injector" })
			else
				vim.notify("❌ Failed to install " .. full_npm_pkg .. " via npm.", vim.log.levels.ERROR, { title = "KRS Type Injector" })
			end
			if callback then callback(exit_code == 0) end
		end,
	})
end

-- Delete schema directory from disk
function M.delete_schema(lang, schema_name, callback)
	local root = M.get_project_root()

	-- Drop any links into this schema before the target disappears
	M.sync_ts_type_links(root, {})

	local schema_dir = M.resolve_schema_dir(lang, schema_name)
	if schema_dir then
		vim.fn.delete(schema_dir, "rf")
	end

	-- Deactivate from current project if active
	local active_data = M.load_project_types(root)
	local new_list = {}
	for _, name in ipairs(active_data[lang] or {}) do
		if name ~= schema_name then
			table.insert(new_list, name)
		end
	end
	active_data[lang] = new_list
	M.save_project_types(root, active_data)
	M.apply_lsp_settings(root)

	vim.notify("🗑️ Deleted schema '" .. schema_name .. "'", vim.log.levels.INFO, { title = "KRS Type Injector" })
	if callback then callback() end
end

-- Open interactive Telescope / UI picker for schema selection
function M.open_menu()
	local ok_telescope, pickers = pcall(require, "telescope.pickers")
	local finders = pcall(require, "telescope.finders") and require("telescope.finders")
	local conf = pcall(require, "telescope.config") and require("telescope.config").values
	local actions = pcall(require, "telescope.actions") and require("telescope.actions")
	local action_state = pcall(require, "telescope.actions.state") and require("telescope.actions.state")

	local root = M.get_project_root()
	local active_data = M.load_project_types(root)

	local function open_schema_picker(lang, title)
		active_data = M.load_project_types(root)
		local available = M.scan_available_schemas(lang)
		local active_set = {}
		for _, name in ipairs(active_data[lang] or {}) do
			active_set[name] = true
		end

		local items = {}

		-- For TS/JS, add NPM install option at the top
		if lang == "typescript_javascript" then
			table.insert(items, {
				name = "__INSTALL_NPM__",
				display = "📦 [ + Install New Types from NPM ]",
				is_action = true,
			})
		end

		for _, name in ipairs(available) do
			local ver = M.get_schema_version(lang, name)
			local ver_suffix = ver and (" (" .. ver .. ")") or ""
			local icon = active_set[name] and " [✓] " or " [  ] "
			table.insert(items, {
				name = name,
				display = icon .. name .. ver_suffix,
				active = active_set[name] or false,
				ver = ver,
			})
		end

		if #items == 0 then
			vim.notify("No schemas found in /nvim/schemas-langs/" .. lang, vim.log.levels.WARN, { title = "Type Injector" })
			return
		end

		local function handle_item_action(selected_item)
			if selected_item.name == "__INSTALL_NPM__" then
				vim.ui.input({ prompt = "Enter npm type package (e.g. @types/express, node@20, react): " }, function(input)
					if input and input ~= "" then
						M.install_npm_types(input, function()
							vim.schedule(function()
								open_schema_picker(lang, title)
							end)
						end)
					end
				end)
				return
			end

			-- Open action sub-menu for existing schema
			if ok_telescope then
				pickers.new({}, {
					prompt_title = " ⚙️ Options for '" .. selected_item.name .. "' ",
					finder = finders.new_table({
						results = {
							{ action = "toggle", label = (selected_item.active and "🔴 Disable for Current Project" or "🟢 Enable for Current Project") },
							{ action = "update", label = "🔄 Update / Change Version via NPM" },
							{ action = "delete", label = "🗑️ Delete Schema from Disk" },
						},
						entry_maker = function(entry)
							return { value = entry.action, display = entry.label, ordinal = entry.label }
						end,
					}),
					sorter = conf.generic_sorter({}),
					attach_mappings = function(prompt_bufnr, map)
						actions.select_default:replace(function()
							local act_selection = action_state.get_selected_entry()
							actions.close(prompt_bufnr)
							if act_selection and act_selection.value then
								local act = act_selection.value
								if act == "toggle" then
									active_set[selected_item.name] = not selected_item.active
									local new_list = {}
									for k, v in pairs(active_set) do
										if v then table.insert(new_list, k) end
									end
									table.sort(new_list)
									active_data[lang] = new_list
									M.save_project_types(root, active_data)
									M.apply_lsp_settings(root)
									vim.notify(
										"Schema '" .. selected_item.name .. "' is now " .. (active_set[selected_item.name] and "ACTIVE 🟢" or "INACTIVE 🔴"),
										vim.log.levels.INFO,
										{ title = "KRS Type Injector" }
									)
									vim.schedule(function() open_schema_picker(lang, title) end)
								elseif act == "update" then
									vim.ui.input({ prompt = "Enter target version for @types/" .. selected_item.name .. " (e.g. latest, 20.0.0): " }, function(ver_input)
										if ver_input and ver_input ~= "" then
											M.install_npm_types("@types/" .. selected_item.name .. "@" .. ver_input, function()
												vim.schedule(function() open_schema_picker(lang, title) end)
											end)
										end
									end)
								elseif act == "delete" then
									M.delete_schema(lang, selected_item.name, function()
										vim.schedule(function() open_schema_picker(lang, title) end)
									end)
								end
							end
						end)
						return true
					end,
				}):find()
			else
				-- vim.ui.select fallback
				local options = {
					selected_item.active and "1. Disable for Current Project" or "1. Enable for Current Project",
					"2. Update / Change Version via NPM",
					"3. Delete Schema from Disk",
				}
				vim.ui.select(options, { prompt = "Options for " .. selected_item.name .. ":" }, function(choice)
					if choice then
						if choice:find("1.") then
							active_set[selected_item.name] = not selected_item.active
							local new_list = {}
							for k, v in pairs(active_set) do
								if v then table.insert(new_list, k) end
							end
							table.sort(new_list)
							active_data[lang] = new_list
							M.save_project_types(root, active_data)
							M.apply_lsp_settings(root)
						elseif choice:find("2.") then
							vim.ui.input({ prompt = "Enter version: " }, function(v)
								if v then M.install_npm_types("@types/" .. selected_item.name .. "@" .. v) end
							end)
						elseif choice:find("3.") then
							M.delete_schema(lang, selected_item.name)
						end
					end
				end)
			end
		end

		if not ok_telescope then
			local display_opts = {}
			for idx, item in ipairs(items) do
				table.insert(display_opts, string.format("%d. %s", idx, item.display))
			end
			vim.ui.select(display_opts, { prompt = title }, function(choice, idx)
				if choice and idx then
					handle_item_action(items[idx])
				end
			end)
			return
		end

		pickers.new({}, {
			prompt_title = " 💉 Injectable Types: " .. title .. " (Press [Enter] for Actions) ",
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.display,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and selection.value then
						handle_item_action(selection.value)
					end
				end)
				return true
			end,
		}):find()
	end

	-- Language selection step
	if ok_telescope then
		pickers.new({}, {
			prompt_title = " 💉 KRS Modular Type Injector: Select Language ",
			finder = finders.new_table({
				results = {
					{ name = "Lua", key = "lua", label = "🌙 Lua Type Schemas" },
					{ name = "TypeScript / JavaScript", key = "typescript_javascript", label = "⚡ TypeScript / JavaScript Type Schemas (NPM Types)" },
				},
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.label,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and selection.value then
						open_schema_picker(selection.value.key, selection.value.name)
					end
				end)
				return true
			end,
		}):find()
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

-- Initialize KRS Type Injector autocommands & user commands
function M.setup()
	vim.api.nvim_create_user_command("TypeInjector", function()
		M.open_menu()
	end, { desc = "Open KRS Modular Type Injector Menu" })

	vim.api.nvim_create_user_command("KrsTypes", function()
		M.open_menu()
	end, { desc = "Open KRS Modular Type Injector Menu" })

	-- Autocommand: Apply project type definitions when LSP attaches
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

return M

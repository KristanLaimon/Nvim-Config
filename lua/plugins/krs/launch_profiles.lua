--- @module plugins.krs.launch_profiles
--- Per-Project Launch Profiles Manager (`.krsnvim/launch.json`).
--- Controls project entry points, runtimes, args, env, pre-launch tasks, DAP debugger integration, and card picker UI.
---
--- @example
--- local lp = require("plugins.krs.launch_profiles")
--- lp.handle_smart_launch()
--- lp.open_management_menu()
local M = {}

local RUNTIMES = { "bun", "node", "deno", "python", "go", "php", "dotnet", "krsnvimscript", "krsnvimtranspiler", "custom" }

--- Resolves the current project root directory.
--- @return string root Absolute path to project root.
function M.get_project_root()
	local ok, tasks_mod = pcall(require, "plugins.krs.tasks")
	if ok and tasks_mod.get_project_root then
		return tasks_mod.get_project_root()
	end
	local current = vim.fn.expand("%:p:h")
	if current == "" then
		current = vim.fn.getcwd()
	end
	return current
end

--- Resolves the file path for `launch.json` (`.krsnvim/launch.json`, `.krslocal/launch.json`, `.nvimkrs/launch.json`).
--- @param root string|nil Optional root directory.
--- @return string filepath Path to launch.json.
function M.get_launch_filepath(root)
	root = root or M.get_project_root()
	local norm_root = root:gsub("\\", "/")

	local krsnvim_file = norm_root .. "/.krsnvim/launch.json"
	if vim.fn.filereadable(krsnvim_file) == 1 then
		return krsnvim_file
	end

	local krslocal_file = norm_root .. "/.krslocal/launch.json"
	if vim.fn.filereadable(krslocal_file) == 1 then
		return krslocal_file
	end

	local nvimkrs_file = norm_root .. "/.nvimkrs/launch.json"
	if vim.fn.filereadable(nvimkrs_file) == 1 then
		return nvimkrs_file
	end

	return krsnvim_file
end

--- Loads all launch profiles defined for the project.
--- @param root string|nil Optional root directory.
--- @return table data Table containing `profiles` array.
function M.load_profiles(root)
	local filepath = M.get_launch_filepath(root)
	local f = io.open(filepath, "r")
	if not f then
		return { profiles = {} }
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return { profiles = {} }
	end
	local ok, parsed = pcall(vim.json.decode, content)
	if ok and type(parsed) == "table" then
		parsed.profiles = parsed.profiles or {}
		return parsed
	end
	return { profiles = {} }
end

function M.save_profiles(root, data)
	root = root or M.get_project_root()
	local filepath = M.get_launch_filepath(root)
	local dir = vim.fn.fnamemodify(filepath, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	local content = vim.json.encode(data)
	local f = io.open(filepath, "w")
	if f then
		f:write(content)
		f:close()
	else
		vim.notify("Error writing " .. filepath, vim.log.levels.ERROR, { title = "Launch Profiles" })
	end
end

function M.toggle_default(profile_id, root)
	root = root or M.get_project_root()
	local data = M.load_profiles(root)
	local updated_name = ""
	for _, p in ipairs(data.profiles) do
		if p.id == profile_id then
			p.is_default = not p.is_default
			updated_name = p.name
		else
			p.is_default = false
		end
	end
	M.save_profiles(root, data)
	vim.notify("⭐ Primary default profile set: " .. updated_name, vim.log.levels.INFO, { title = "Launch Profiles" })
end

function M.rename_profile(profile_id, new_name, root)
	root = root or M.get_project_root()
	local data = M.load_profiles(root)
	local old_name = ""
	local updated = false
	for _, p in ipairs(data.profiles) do
		if p.id == profile_id then
			old_name = p.name
			p.name = new_name
			updated = true
			break
		end
	end
	if updated then
		M.save_profiles(root, data)
		vim.notify("✏️ Profile renamed: " .. old_name .. " ➜ " .. new_name, vim.log.levels.INFO, { title = "Launch Profiles" })
	end
end

function M.run_pre_launch_tasks(tasks_list, callback)
	if not tasks_list or #tasks_list == 0 then
		callback(true)
		return
	end

	local tasks_mod = require("plugins.krs.tasks")
	local idx = 1

	local function run_next()
		if idx > #tasks_list then
			callback(true)
			return
		end

		local task_item = tasks_list[idx]
		local task_cmd = type(task_item) == "table" and (task_item.cmd or task_item.name) or tostring(task_item)

		vim.notify("⚙️ Executing pre-launch task [" .. idx .. "/" .. #tasks_list .. "]: " .. task_cmd, vim.log.levels.INFO, { title = "Pre-Launch Tasks" })

		tasks_mod.run_custom_command(task_cmd, nil, function(exit_code)
			if exit_code ~= 0 then
				vim.notify(
					"❌ Pre-launch task failed with exit code " .. exit_code .. ": " .. task_cmd,
					vim.log.levels.ERROR,
					{ title = "Launch Profile Aborted" }
				)
				callback(false)
			else
				idx = idx + 1
				run_next()
			end
		end)
	end

	run_next()
end

-- How to run a .ts/.tsx file under node. Shared with lua/plugins/editor/dap.lua.
local node_major -- memoized, `node -v` costs ~50ms
function M.ts_runtime(root, entry)
	if not entry:match("%.[cm]?tsx?$") then
		return { exe = "node", args = {} }
	end
	-- tsx first when the project has it: handles tsconfig paths, enums, decorators.
	if vim.fn.isdirectory(root .. "/node_modules/tsx") == 1 then
		return { exe = "node", args = { "--import", "tsx" } }
	end
	if not node_major then
		local major, minor = (vim.fn.system("node -v") or ""):match("v(%d+)%.(%d+)")
		node_major = tonumber(major) and (tonumber(major) + tonumber(minor) / 1000) or 0
	end
	-- Node strips TypeScript types natively since 22.18 / 23.6.
	if node_major >= 22.018 then
		return { exe = "node", args = {} }
	end
	local npx = vim.fn.exepath("npx")
	return { exe = npx ~= "" and npx or "npx", args = { "tsx" } }
end

-- Locate the built assembly for a .csproj (or a project directory) entry point.
local function find_dotnet_dll(root, entry)
	local full = (root .. "/" .. entry):gsub("\\", "/")
	if entry:match("%.dll$") then
		return full
	end
	local proj_dir = entry:match("%.csproj$") and vim.fn.fnamemodify(full, ":h") or full
	local name = entry:match("([^/\\]+)%.csproj$") or vim.fn.fnamemodify(proj_dir, ":t")
	local newest, newest_time = nil, -1
	for _, dll in ipairs(vim.fn.glob(proj_dir .. "/bin/**/" .. name .. ".dll", false, true)) do
		local t = vim.fn.getftime(dll)
		if t > newest_time then
			newest, newest_time = dll:gsub("\\", "/"), t
		end
	end
	return newest
end

-- Maps a profile runtime to a real DAP configuration.
-- Adapter names must match what mason-nvim-dap / dap-go register:
--   pwa-node (js-debug) | go (nvim-dap-go) | python (debugpy) | php (xdebug) | coreclr (netcoredbg)
function M.build_dap_config(profile, root)
	local runtime = profile.runtime or "node"
	local entry = profile.entry_point or ""
	local full_entry = (root .. "/" .. entry):gsub("\\", "/")
	local is_ts = entry:match("%.[cm]?tsx?$") ~= nil

	if runtime == "krsnvimscript" then
		return {
			type = "krsnvimscript",
			request = "launch",
			name = profile.name,
			program = full_entry,
			cwd = root,
		}
	elseif runtime == "go" then
		return {
			type = "go",
			request = "launch",
			name = profile.name,
			mode = "debug",
			program = full_entry,
			cwd = root,
		}
	elseif runtime == "python" then
		return {
			type = "python",
			request = "launch",
			name = profile.name,
			program = full_entry,
			cwd = root,
			console = "integratedTerminal",
		}
	elseif runtime == "php" then
		-- Xdebug is a listener: nvim waits, the PHP process connects back to 9003.
		return {
			type = "php",
			request = "launch",
			name = profile.name,
			port = 9003,
			pathMappings = { ["/var/www/html"] = root },
		}
	elseif runtime == "dotnet" then
		-- netcoredbg launches the built assembly, not the project. With auto_build the
		-- `dotnet build` already ran as a pre-launch task, so the dll is on disk by now.
		local dll = find_dotnet_dll(root, entry)
		if not dll then
			vim.notify(
				"❌ No built DLL found for " .. entry .. ".\n  Enable Auto Build on the profile, or point the entry point at bin/Debug/<tfm>/App.dll.",
				vim.log.levels.ERROR,
				{ title = "Launch Profiles Debugger" }
			)
			return nil
		end
		return {
			type = "coreclr",
			request = "launch",
			name = profile.name,
			program = dll,
			cwd = root,
		}
	end

	if runtime == "bun" then
		-- Bun's own adapter (WebKit inspector protocol). It spawns bun itself, so no
		-- runtimeExecutable, and it runs .ts directly with no loader.
		return {
			type = "bun",
			request = "launch",
			name = profile.name,
			program = full_entry,
			cwd = root,
			stopOnEntry = false,
			watchMode = false,
		}
	end

	-- Everything else goes through js-debug.
	local cfg = {
		type = "pwa-node",
		request = "launch",
		name = profile.name,
		program = full_entry,
		cwd = root,
		-- Keeps the child process in a nvim terminal buffer instead of popping
		-- external cmd.exe windows for .cmd shims on Windows.
		console = "integratedTerminal",
		sourceMaps = true,
		-- Keeps js-debug out of node internals and the tsx loader; without it the
		-- debugger stops there and nvim-dap lists those files as bufferline tabs.
		skipFiles = { "<node_internals>/**", "**/node_modules/**" },
	}

	if runtime == "deno" then
		cfg.runtimeExecutable = "deno"
		cfg.runtimeArgs = { "run", "--inspect-wait", "--allow-all" }
		cfg.attachSimplePort = 9229
		return cfg
	end

	if is_ts then
		local rt = M.ts_runtime(root, entry)
		cfg.runtimeExecutable = rt.exe
		cfg.runtimeArgs = #rt.args > 0 and rt.args or nil
	end

	return cfg
end

function M.run_profile(profile)
	if not profile then
		return
	end

	if type(profile) == "string" then
		local root = M.get_project_root()
		local data = M.load_profiles(root)
		local found = nil
		for _, p in ipairs(data.profiles or {}) do
			if p.id == profile then
				found = p
				break
			end
		end
		if not found then
			vim.notify("❌ Profile not found: " .. profile, vim.log.levels.ERROR, { title = "Launch Profiles" })
			return
		end
		profile = found
	end

	local profile_name = profile.name or profile.id or "Unnamed Profile"
	local pre_tasks = vim.deepcopy(profile.pre_launch_tasks or {})

	-- auto_build: reuse the pre-launch task runner instead of a second build pipeline.
	if profile.auto_build and (profile.runtime or "node") == "dotnet" then
		local target = profile.entry_point or ""
		if target:match("%.dll$") then
			target = vim.fn.fnamemodify(target, ":h")
		end
		table.insert(pre_tasks, 1, "dotnet build " .. target)
	end

	M.run_pre_launch_tasks(pre_tasks, function(success)
		if not success then
			return
		end

		local runtime = profile.runtime or "node"
		local entry = profile.entry_point or ""
		local args = profile.args or {}
		local args_str = type(args) == "table" and table.concat(args, " ") or tostring(args)
		local env = profile.env or {}

		local cmd = ""
		if runtime == "bun" then
			cmd = "bun " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "node" then
			if entry:match("%.ts$") or entry:match("%.tsx$") then
				cmd = "npx tsx " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
			else
				cmd = "node " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
			end
		elseif runtime == "deno" then
			cmd = "deno run -A " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "python" then
			cmd = "python " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "go" then
			cmd = "go run " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "php" then
			cmd = "php " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "dotnet" then
			cmd = "dotnet run --project " .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "krsnvimscript" then
			cmd = 'nvim --headless -c "lua require[[krsnvim]].setup_globals()" -l ' .. entry .. (args_str ~= "" and (" " .. args_str) or "")
		elseif runtime == "krsnvimtranspiler" then
			local transpiler = require("krsnvim").krsnvimtranspiler
			local root = M.get_project_root()
			local full_path = (root .. "/" .. entry):gsub("\\", "/")
			if args_str == "sh" then
				transpiler.export_sh(full_path)
			elseif args_str == "ps1" then
				transpiler.export_ps1(full_path)
			else
				transpiler.export_both(full_path)
			end
			return
		else
			cmd = entry .. (args_str ~= "" and (" " .. args_str) or "")
		end

		if profile.mode == "debug" then
			local dap_ok, dap = pcall(require, "dap")
			if not dap_ok then
				vim.notify("DAP is not installed", vim.log.levels.ERROR, { title = "Launch Profiles" })
				return
			end

			local root = M.get_project_root()
			local dap_config = M.build_dap_config(profile, root)
			if not dap_config then
				return
			end
			if args and #args > 0 then
				dap_config.args = args
			end

			if not dap.adapters[dap_config.type] then
				local how = dap_config.type == "bun" and ":KrsBunDapInstall, then restart nvim"
					or ":Mason (or restart nvim to let mason-nvim-dap fetch it)"
				vim.notify(
					"❌ Debug adapter '" .. dap_config.type .. "' is not installed.\n  Install it with " .. how .. ".",
					vim.log.levels.ERROR,
					{ title = "Launch Profiles Debugger" }
				)
				return
			end

			vim.notify("🐞 Launching DAP Debugger for " .. profile_name .. " (" .. runtime .. ")", vim.log.levels.INFO, { title = "Launch Profiles Debugger" })
			dap.run(dap_config)
		else
			vim.notify("🚀 Launching profile: " .. profile_name .. " (" .. cmd .. ")", vim.log.levels.INFO, { title = "Launch Profiles" })
			local tasks_mod = require("plugins.krs.tasks")
			tasks_mod.run_custom_command(cmd, env)
		end
	end)
end

-- ============================================================================
-- 🚀 SINGLE-SCREEN FLOATING FORM WINDOW EDITOR
-- ============================================================================
function M.open_form_editor(root, existing_profile, on_saved)
	root = root or M.get_project_root()
	local is_edit = existing_profile ~= nil

	local p = existing_profile and vim.deepcopy(existing_profile) or {
		id = "profile-" .. os.time(),
		name = "Run " .. vim.fn.fnamemodify(root, ":t"),
		runtime = "bun",
		entry_point = "src/index.ts",
		args = {},
		env = {},
		pre_launch_tasks = {},
		mode = "run",
		is_default = false,
		auto_build = false,
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "krslaunchform"

	local width = 78
	local height = 18

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(math.floor(((vim.o.lines or 24) - height) / 2), 1),
		col = math.max(math.floor(((vim.o.columns or 80) - width) / 2), 1),
		style = "minimal",
		border = "rounded",
		title = is_edit and " 📝 Edit Launch Profile Form " or " 🚀 New Launch Profile Form ",
		title_pos = "center",
	})

	local selected_field = 1

	local function render_form()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local args_str = (p.args and #p.args > 0) and table.concat(p.args, " ") or "(none)"
		local pre_str = (p.pre_launch_tasks and #p.pre_launch_tasks > 0) and table.concat(p.pre_launch_tasks, ", ") or "(none)"

		local lines = {
			" ────────────── Launch Profile Specifications (Form View) ──────────────",
			"",
			string.format("  %s [1] Profile Name:     %s", selected_field == 1 and "👉" or "  ", p.name),
			string.format("  %s [2] Runtime:          %s", selected_field == 2 and "👉" or "  ", p.runtime:upper() .. "  (" .. table.concat(RUNTIMES, " | ") .. ")"),
			string.format("  %s [3] Entry Point File: %s", selected_field == 3 and "👉" or "  ", p.entry_point),
			string.format("  %s [4] Command Args:     %s", selected_field == 4 and "👉" or "  ", args_str),
			string.format("  %s [5] Pre-launch Tasks: %s", selected_field == 5 and "👉" or "  ", pre_str),
			string.format("  %s [6] Execution Mode:   %s", selected_field == 6 and "👉" or "  ", p.mode == "debug" and "🐞 DAP Debugger" or "🖥️ Terminal Task Slot"),
			string.format("  %s [7] Primary Default:  %s", selected_field == 7 and "👉" or "  ", p.is_default and "✅ YES (Primary for Ctrl+Shift+S)" or "❌ No"),
			string.format("  %s [8] Auto Build:      %s", selected_field == 8 and "👉" or "  ", p.auto_build and "✅ YES (dotnet build before launch)" or "❌ No  (dotnet only)"),
			"",
			" ───────────────────────────────────────────────────────────────────────",
			"  Navigation: [1-8] Select Field  |  [j/k/Tab] Move  |  [Enter/Space] Edit/Cycle",
			"  [S] Save Profile  |  [Esc/q] Cancel",
		}
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	render_form()

	local function save_and_close()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end

		local data = M.load_profiles(root)
		if p.is_default then
			for _, prof in ipairs(data.profiles) do
				if prof.id ~= p.id then
					prof.is_default = false
				end
			end
		end

		local found = false
		for idx, prof in ipairs(data.profiles) do
			if prof.id == p.id then
				data.profiles[idx] = p
				found = true
				break
			end
		end
		if not found then
			table.insert(data.profiles, p)
		end

		M.save_profiles(root, data)
		vim.notify("✅ Saved Launch Profile: " .. p.name, vim.log.levels.INFO, { title = "Launch Profiles" })
		if on_saved then
			on_saved(p)
		end
	end

	local function edit_field(field_num)
		selected_field = field_num
		render_form()

		local input = require("plugins.krs.input_modal")

		if field_num == 1 then
			input.open({
				label = "Profile Name",
				default_value = p.name,
				callback = function(ok, val)
					if ok and val ~= "" then
						p.name = val
					end
					render_form()
				end,
			})
		elseif field_num == 2 then
			local cur_idx = 1
			for idx, r in ipairs(RUNTIMES) do
				if r == p.runtime then
					cur_idx = idx
					break
				end
			end
			p.runtime = RUNTIMES[(cur_idx % #RUNTIMES) + 1]
			render_form()
		elseif field_num == 3 then
			input.open({
				label = "Entry Point File (relative path)",
				default_value = p.entry_point,
				callback = function(ok, val)
					if ok and val ~= "" then
						p.entry_point = val
					end
					render_form()
				end,
			})
		elseif field_num == 4 then
			local cur_args = (p.args and #p.args > 0) and table.concat(p.args, " ") or ""
			input.open({
				label = "Command Arguments (space separated)",
				default_value = cur_args,
				callback = function(ok, val)
					p.args = {}
					if ok and val ~= "" then
						for arg in val:gmatch("%S+") do
							table.insert(p.args, arg)
						end
					end
					render_form()
				end,
			})
		elseif field_num == 5 then
			local cur_pre = (p.pre_launch_tasks and #p.pre_launch_tasks > 0) and table.concat(p.pre_launch_tasks, ", ") or ""
			input.open({
				label = "Pre-launch Tasks (comma separated)",
				default_value = cur_pre,
				callback = function(ok, val)
					p.pre_launch_tasks = {}
					if ok and val ~= "" then
						for task in val:gmatch("[^,]+") do
							local trimmed = vim.trim(task)
							if trimmed ~= "" then
								table.insert(p.pre_launch_tasks, trimmed)
							end
						end
					end
					render_form()
				end,
			})
		elseif field_num == 6 then
			p.mode = (p.mode == "run") and "debug" or "run"
			render_form()
		elseif field_num == 7 then
			p.is_default = not p.is_default
			render_form()
		elseif field_num == 8 then
			p.auto_build = not p.auto_build
			render_form()
		end
	end

	local kopts = { buffer = buf, noremap = true, silent = true }

	local FIELD_COUNT = 8

	vim.keymap.set("n", "j", function()
		selected_field = (selected_field % FIELD_COUNT) + 1
		render_form()
	end, kopts)
	vim.keymap.set("n", "k", function()
		selected_field = (selected_field - 2) % FIELD_COUNT + 1
		render_form()
	end, kopts)
	vim.keymap.set("n", "<Tab>", function()
		selected_field = (selected_field % FIELD_COUNT) + 1
		render_form()
	end, kopts)

	for i = 1, FIELD_COUNT do
		vim.keymap.set("n", tostring(i), function()
			edit_field(i)
		end, kopts)
	end

	vim.keymap.set("n", "<CR>", function()
		edit_field(selected_field)
	end, kopts)
	vim.keymap.set("n", "<Space>", function()
		edit_field(selected_field)
	end, kopts)

	vim.keymap.set("n", "S", save_and_close, kopts)
	vim.keymap.set("n", "s", save_and_close, kopts)
	vim.keymap.set("n", "<C-s>", save_and_close, kopts)

	local function close_cancel()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	vim.keymap.set("n", "<Esc>", close_cancel, kopts)
	vim.keymap.set("n", "q", close_cancel, kopts)
end

function M.open_creation_wizard(root, on_created)
	M.open_form_editor(root, nil, on_created)
end

function M.open_management_menu(root)
	root = root or M.get_project_root()
	local data = M.load_profiles(root)

	if #data.profiles == 0 then
		vim.notify("No Launch Profiles found. Opening Form Editor...", vim.log.levels.INFO, { title = "Launch Profiles" })
		M.open_creation_wizard(root, function(new_profile)
			M.run_profile(new_profile)
		end)
		return
	end

	local telescope_ok, pickers = pcall(require, "telescope.pickers")
	if not telescope_ok then
		vim.notify("Telescope is required for Launch Profiles UI", vim.log.levels.ERROR)
		return
	end

	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local profile_previewer = previewers.new_buffer_previewer({
		title = " 📋 Profile Card Preview ",
		define_preview = function(self, entry, status)
			local p = entry.value
			if not p then
				return
			end

			local lines = {
				"┌──────────────────────────────────────────────────────────────┐",
				string.format("│ 🚀 PROFILE CARD: %-43s │", p.name:sub(1, 43)),
				"├──────────────────────────────────────────────────────────────┤",
				string.format("│ ⚡ Runtime:        %-42s │", tostring(p.runtime):upper():sub(1, 42)),
				string.format("│ 📄 Entry Point:    %-42s │", tostring(p.entry_point):sub(1, 42)),
				string.format("│ 📌 Arguments:      %-42s │", (p.args and #p.args > 0) and table.concat(p.args, " "):sub(1, 42) or "(none)"),
				string.format("│ ⚙️ Pre-Tasks:      %-42s │", (p.pre_launch_tasks and #p.pre_launch_tasks > 0) and table.concat(p.pre_launch_tasks, ", "):sub(1, 42) or "(none)"),
				string.format("│ 🛠️ Exec Mode:      %-42s │", (p.mode == "debug" and "🐞 DAP Debugger" or "🖥️ Terminal Task Slot"):sub(1, 42)),
				string.format("│ ⭐ Primary Default: %-42s │", (p.is_default and "✅ YES (Primary for Ctrl+Shift+S)" or "❌ No"):sub(1, 42)),
				string.format("│ 🔨 Auto Build:     %-42s │", (p.auto_build and "✅ YES (dotnet build first)" or "❌ No"):sub(1, 42)),
				"└──────────────────────────────────────────────────────────────┘",
			}
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			pcall(function()
				vim.bo[self.state.bufnr].filetype = "markdown"
			end)
		end,
	})

	local entries = {}
	for idx, p in ipairs(data.profiles) do
		local star = p.is_default and "⭐ [DEFAULT]" or "           "
		local mode_str = p.mode == "debug" and "🐞 DEBUG" or "🚀 RUN  "
		local args_str = (p.args and #p.args > 0) and (" [" .. table.concat(p.args, " ") .. "]") or ""
		local tasks_str = (p.pre_launch_tasks and #p.pre_launch_tasks > 0) and (" (pre: " .. table.concat(p.pre_launch_tasks, ", ") .. ")") or ""

		local display_line = string.format("%s  %s  %-20s ──>  %-22s%s%s", star, mode_str, p.name, p.runtime .. ":" .. p.entry_point, args_str, tasks_str)

		table.insert(entries, {
			display = display_line,
			value = p,
			ordinal = (p.is_default and "0_" or "1_") .. p.name .. " " .. p.runtime .. " " .. p.entry_point,
			index = idx,
		})
	end

	pickers.new({}, {
		prompt_title = " 🚀 Launch Profiles | <Enter>: Run | [d] Delete | [r] Rename | [e] Edit | [f] Favorite | [a] New ",
		layout_strategy = "horizontal",
		layout_config = {
			horizontal = {
				preview_width = 0.48,
				width = 0.9,
				height = 0.8,
			},
			preview_cutoff = 0,
		},
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				return {
					value = entry.value,
					display = entry.display,
					ordinal = entry.ordinal,
				}
			end,
		}),
		previewer = profile_previewer,
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and selection.value then
					M.run_profile(selection.value)
				end
			end)

			local function action_delete(selection)
				if selection and selection.value then
					local profile_id = selection.value.id
					local cur_data = M.load_profiles(root)
					local updated = {}
					for _, p in ipairs(cur_data.profiles) do
						if p.id ~= profile_id then
							table.insert(updated, p)
						end
					end
					cur_data.profiles = updated
					M.save_profiles(root, cur_data)
					vim.notify("🗑️ Deleted launch profile: " .. selection.value.name, vim.log.levels.INFO, { title = "Launch Profiles" })
					M.open_management_menu(root)
				end
			end

			local function action_rename(selection)
				if selection and selection.value then
					local input = require("plugins.krs.input_modal")
					input.open({
						label = "Rename Launch Profile",
						default_value = selection.value.name,
						callback = function(ok, new_name)
							if ok and new_name ~= "" and new_name ~= selection.value.name then
								M.rename_profile(selection.value.id, new_name, root)
							end
							M.open_management_menu(root)
						end,
					})
				end
			end

			local function action_edit(selection)
				if selection and selection.value then
					M.open_form_editor(root, selection.value, function()
						M.open_management_menu(root)
					end)
				end
			end

			local function action_toggle_favorite(selection)
				if selection and selection.value then
					M.toggle_default(selection.value.id, root)
					M.open_management_menu(root)
				end
			end

			local function action_create_new()
				M.open_creation_wizard(root, function()
					M.open_management_menu(root)
				end)
			end

			-- Normal mode keymaps: d = delete, r = rename, e = edit form, f = favorite, a = add new
			map("n", "d", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_delete(selection)
			end)

			map("n", "r", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_rename(selection)
			end)

			map("n", "e", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_edit(selection)
			end)

			map("n", "f", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_toggle_favorite(selection)
			end)

			map("n", "a", function()
				actions.close(prompt_bufnr)
				action_create_new()
			end)

			-- Shortcuts for insert/normal backwards compatibility (<C-d>, <C-e>, <C-n>, <C-x>)
			map({ "n", "i" }, "<C-d>", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_toggle_favorite(selection)
			end)

			map({ "n", "i" }, "<C-e>", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_edit(selection)
			end)

			map({ "n", "i" }, "<C-n>", function()
				actions.close(prompt_bufnr)
				action_create_new()
			end)

			map({ "n", "i" }, "<C-x>", function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				action_delete(selection)
			end)

			return true
		end,
	}):find()
end

function M.handle_smart_launch()
	local has_dap, dap = pcall(require, "dap")
	if has_dap and dap.session() then
		dap.terminate()
		vim.notify("⏹️ Debug session terminated", vim.log.levels.INFO, { title = "Launch Profiles" })
		return
	end

	local root = M.get_project_root()
	local data = M.load_profiles(root)

	if #data.profiles == 0 then
		M.open_creation_wizard(root, function(new_profile)
			M.run_profile(new_profile)
		end)
		return
	end

	local default_profile = nil
	for _, p in ipairs(data.profiles) do
		if p.is_default then
			default_profile = p
			break
		end
	end

	if default_profile then
		M.run_profile(default_profile)
	else
		M.open_management_menu(root)
	end
end

_G.LaunchProfiles = M

local plugin_spec = {
	name = "krs_launch_profiles",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		pcall(vim.api.nvim_create_user_command, "LaunchProfiles", function()
			M.open_management_menu()
		end, { desc = "Open Launch Profiles Management UI" })

		pcall(vim.api.nvim_create_user_command, "LaunchProfilesSmart", function()
			M.handle_smart_launch()
		end, { desc = "Run Default Launch Profile or Open Management UI" })

		local modes = { "n", "i", "v", "t" }
		for _, mode in ipairs(modes) do
			for _, key in ipairs({ "<C-S-s>", "<C-S-S>" }) do
				vim.keymap.set(mode, key, function()
					if vim.fn.mode() == "t" then
						pcall(vim.cmd, "stopinsert")
					end
					M.handle_smart_launch()
				end, { noremap = true, silent = true, desc = "Smart Launch / Profile Debug UI" })
			end

			for _, key in ipairs({ "<C-S-q>", "<C-S-Q>" }) do
				vim.keymap.set(mode, key, function()
					if vim.fn.mode() == "t" then
						pcall(vim.cmd, "stopinsert")
					end
					M.open_management_menu()
				end, { noremap = true, silent = true, desc = "Open Launch Profiles Management UI" })
			end
		end
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})


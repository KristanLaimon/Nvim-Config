--- @module plugins.krs.tasks
--- Per-Project Task Manager, Task Chain Executor & Terminal Output Manager.
--- Automatically scans Makefile, package.json, Cargo.toml, go.mod, and `.krsnvim/tasks.json`.
---
--- @example
--- local tasks = require("plugins.krs.tasks")
--- tasks.open_task_menu()
--- tasks.run_default_or_menu()
local M = {}

local legacy_store_file = vim.fn.stdpath("data") .. "/project_tasks.json"

local function load_legacy_data()
	local f = io.open(legacy_store_file, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	return ok and type(data) == "table" and data or {}
end

local function get_krs_filepath(root)
	local norm_root = root:gsub("\\", "/")
	local krs_dir = norm_root .. "/.krsnvim"
	local krs_tasks_file = krs_dir .. "/tasks.json"

	if vim.fn.filereadable(krs_tasks_file) == 1 then
		return krs_tasks_file
	end

	local nvimkrs_file = norm_root .. "/.nvimkrs"
	if vim.fn.filereadable(nvimkrs_file) == 1 then
		return nvimkrs_file
	end

	return krs_tasks_file
end

function M.get_project_root()
	local current = vim.fn.expand("%:p:h")
	if current == "" then
		current = vim.fn.getcwd()
	end
	local root_files = { ".krsnvim", ".nvimkrs", "Makefile", "package.json", "Cargo.toml", ".git", "go.mod", "pyproject.toml" }
	local match = vim.fs.find(root_files, { upward = true, path = current })
	if match and #match > 0 then
		return vim.fs.dirname(match[1])
	end
	return vim.fn.getcwd()
end

function M.discover_tasks(root)
	local discovered = {}
	local norm_root = root:gsub("\\", "/")

	local makefile = norm_root .. "/Makefile"
	if vim.fn.filereadable(makefile) == 1 then
		local lines = vim.fn.readfile(makefile)
		for _, line in ipairs(lines) do
			local target = line:match("^([a-zA-Z0-9_%-.]+):")
			if target and target ~= ".PHONY" and target ~= "all" and not target:find("^%.") then
				table.insert(discovered, { name = "make " .. target, cmd = "make " .. target, source = "Makefile" })
			end
		end
	end

	local pkg_json = norm_root .. "/package.json"
	if vim.fn.filereadable(pkg_json) == 1 then
		local content = table.concat(vim.fn.readfile(pkg_json), "\n")
		local ok, parsed = pcall(vim.json.decode, content)
		if ok and parsed and parsed.scripts then
			for script_name, _ in pairs(parsed.scripts) do
				table.insert(discovered, { name = "npm run " .. script_name, cmd = "npm run " .. script_name, source = "package.json" })
			end
		end
	end

	local cargo = norm_root .. "/Cargo.toml"
	if vim.fn.filereadable(cargo) == 1 then
		table.insert(discovered, { name = "cargo run", cmd = "cargo run", source = "Cargo.toml" })
		table.insert(discovered, { name = "cargo build", cmd = "cargo build", source = "Cargo.toml" })
		table.insert(discovered, { name = "cargo test", cmd = "cargo test", source = "Cargo.toml" })
	end

	local gomod = norm_root .. "/go.mod"
	if vim.fn.filereadable(gomod) == 1 then
		table.insert(discovered, { name = "go run .", cmd = "go run .", source = "go.mod" })
		table.insert(discovered, { name = "go test ./...", cmd = "go test ./...", source = "go.mod" })
	end

	return discovered
end

function M.get_project_data(root)
	local filepath = get_krs_filepath(root)
	local f = io.open(filepath, "r")
	if f then
		local content = f:read("*a")
		f:close()
		local ok, data = pcall(vim.json.decode, content)
		if ok and type(data) == "table" then
			return {
				default_task = data.default_task,
				custom_tasks = type(data.custom_tasks) == "table" and data.custom_tasks or {},
			}
		end
	end

	local key = root:gsub("\\", "/"):lower()
	local legacy_all = load_legacy_data()
	local legacy_data = legacy_all[key]
	if legacy_data then
		return legacy_data
	end

	return { default_task = nil, custom_tasks = {} }
end

function M.save_project_data(root, pdata)
	local norm_root = root:gsub("\\", "/")
	local krs_dir = norm_root .. "/.krsnvim"
	if vim.fn.isdirectory(krs_dir) == 0 then
		vim.fn.mkdir(krs_dir, "p")
	end
	local filepath = krs_dir .. "/tasks.json"
	local data_to_save = {
		default_task = pdata.default_task,
		custom_tasks = pdata.custom_tasks or {},
	}
	local ok, encoded = pcall(vim.json.encode, data_to_save)
	if ok then
		local f = io.open(filepath, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

function M.resolve_steps(task_item, pdata)
	if not task_item then
		return {}
	end

	local steps = {}

	if type(task_item) == "string" then
		return { task_item }
	end

	if type(task_item) ~= "table" then
		return {}
	end

	if task_item.depends_on and type(task_item.depends_on) == "table" then
		for _, dep_name in ipairs(task_item.depends_on) do
			for _, ct in ipairs(pdata.custom_tasks or {}) do
				if (ct.name and ct.name == dep_name) or (ct.cmd and ct.cmd == dep_name) then
					local sub_steps = M.resolve_steps(ct, pdata)
					for _, s in ipairs(sub_steps) do
						table.insert(steps, s)
					end
				end
			end
		end
	end

	if task_item.chain and type(task_item.chain) == "table" then
		for _, step in ipairs(task_item.chain) do
			if type(step) == "string" then
				table.insert(steps, step)
			end
		end
	elseif task_item.cmd and type(task_item.cmd) == "string" and task_item.cmd ~= "" then
		table.insert(steps, task_item.cmd)
	end

	return steps
end

local function show_failure_alert(step_idx, total_steps, failed_cmd, exit_code, remaining_count)
	local width = math.floor(vim.o.columns * 0.70)
	local lines = {
		" ❌ TASK CHAIN EXECUTION FAILED",
		string.rep("═", width - 4),
		string.format("  • Step %d of %d failed!", step_idx, total_steps),
		string.format("  • Failed Command: %s", failed_cmd),
		string.format("  • Exit Code: %d", exit_code),
		"",
		string.format(" ⛔ Execution HALTED. %d remaining task(s) CANCELLED.", remaining_count),
		"",
		" Press <Enter>, <Esc> or 'q' to close this alert and inspect logs below.",
	}
	local height = #lines + 2
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " 🚨 ALERT: Task Chain Interrupted ",
		title_pos = "center",
	})

	pcall(vim.api.nvim_set_option_value, "cursorline", false, { win = win })

	local function close_alert()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local kopts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set({ "n", "v", "i" }, "<CR>", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "<Esc>", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "q", close_alert, kopts)
	vim.keymap.set({ "n", "v", "i" }, "<Space>", close_alert, kopts)
end

M.slots = {}
M.last_slot = nil
M.origin_win = nil

function M.sync_task_slots()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) then
			local ft = vim.bo[b].filetype
			local is_task = vim.b[b].krs_is_task or ft == "TaskRunner"
			if is_task then
				local slot = vim.b[b].krs_task_slot
				local tname = vim.b[b].krs_task_name or "Task Output"

				if not slot or slot < 1 or slot > 4 then
					for i = 1, 4 do
						if not M.slots[i] or not M.slots[i].buf or not vim.api.nvim_buf_is_valid(M.slots[i].buf) then
							slot = i
							break
						end
					end
				end

				if slot and slot >= 1 and slot <= 4 then
					if not M.slots[slot] or not M.slots[slot].buf or not vim.api.nvim_buf_is_valid(M.slots[slot].buf) then
						local win = nil
						for _, w in ipairs(vim.api.nvim_list_wins()) do
							if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == b then
								win = w
								break
							end
						end
						M.slots[slot] = { win = win, buf = b, job_id = nil, name = tname }
						vim.b[b].krs_is_task = true
						vim.b[b].krs_task_slot = slot
						if not M.last_slot then
							M.last_slot = slot
						end
					end
				end
			end
		end
	end
end

local function get_free_slot()
	M.sync_task_slots()
	for i = 1, 4 do
		local s = M.slots[i]
		if not s or not s.job_id then
			return i
		end
	end
	return nil
end

local function enforce_bottom_layout()
	local term_win = nil
	local task_win = nil

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) then
				local bt = vim.bo[buf].buftype
				local ft = vim.bo[buf].filetype
				local is_task = vim.b[buf].krs_is_task or ft == "TaskRunner"
				local is_term = (bt == "terminal" and not is_task) or vim.b[buf].krs_is_multi_term
				if is_term and not term_win then
					term_win = win
				elseif is_task and not task_win then
					task_win = win
				end
			end
		end
	end

	if term_win and task_win then
		local term_pos = vim.api.nvim_win_get_position(term_win)
		local task_pos = vim.api.nvim_win_get_position(task_win)

		if term_pos[2] > task_pos[2] then
			local cur_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(task_win)
			vim.cmd("wincmd x")
			if vim.api.nvim_win_is_valid(cur_win) then
				pcall(vim.api.nvim_set_current_win, cur_win)
			end
		end
	end
end
M.enforce_bottom_layout = enforce_bottom_layout

local function open_or_attach_bottom_win(height)
	local existing_task_win = nil
	local existing_term_win = nil

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) then
				local bt = vim.bo[buf].buftype
				local ft = vim.bo[buf].filetype
				local is_task = vim.b[buf].krs_is_task or ft == "TaskRunner"
				local is_term = (bt == "terminal" and not is_task) or vim.b[buf].krs_is_multi_term
				if is_task and not existing_task_win then
					existing_task_win = win
				elseif is_term and not existing_term_win then
					existing_term_win = win
				end
			end
		end
	end

	local new_win
	if existing_task_win then
		vim.api.nvim_set_current_win(existing_task_win)
		vim.cmd("rightbelow vsplit")
		new_win = vim.api.nvim_get_current_win()
	elseif existing_term_win then
		vim.api.nvim_set_current_win(existing_term_win)
		vim.cmd("rightbelow vsplit")
		new_win = vim.api.nvim_get_current_win()
	else
		vim.cmd("botright " .. height .. "split")
		new_win = vim.api.nvim_get_current_win()
	end

	enforce_bottom_layout()
	return new_win
end

local function bind_task_buffer_keys(buf, slot)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local task_toggle_keys = { "<C-o>", "<C-O>", "<C-`>", "<C-~>", "<C-S-o>", "<C-S-O>", "<C-A-S-j>", "<C-[>" }
	for _, tk in ipairs(task_toggle_keys) do
		vim.keymap.set({ "n", "t", "i", "v" }, tk, function()
			if vim.fn.mode() == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.toggle_slot_window(slot)
		end, { noremap = true, silent = true, buffer = buf, desc = "Toggle Task Output Window" })
	end

	vim.keymap.set("t", "<Esc><Esc>", function()
		pcall(vim.cmd, "stopinsert")
		if M.origin_win and vim.api.nvim_win_is_valid(M.origin_win) then
			pcall(vim.api.nvim_set_current_win, M.origin_win)
		end
	end, { noremap = true, silent = true, buffer = buf, desc = "Return to Code Editor" })

	local function paste_clipboard()
		local clip = vim.fn.getreg("+")
		if not clip or clip == "" then
			clip = vim.fn.getreg("*")
		end
		if clip and clip ~= "" then
			vim.api.nvim_paste(clip, true, -1)
		end
	end

	vim.keymap.set({ "n", "t", "i" }, "<C-v>", paste_clipboard, { noremap = true, silent = true, buffer = buf, desc = "Paste OS Clipboard" })
	vim.keymap.set({ "n", "t", "i" }, "<C-S-v>", paste_clipboard, { noremap = true, silent = true, buffer = buf, desc = "Paste OS Clipboard" })
	vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, silent = true, buffer = buf, desc = "Copy selection to OS Clipboard" })
	vim.keymap.set("v", "<C-S-c>", '"+y', { noremap = true, silent = true, buffer = buf, desc = "Copy selection to OS Clipboard" })
end

function M.toggle_slot_window(n)
	M.sync_task_slots()
	local s = M.slots[n]
	if not s or not s.buf or not vim.api.nvim_buf_is_valid(s.buf) then
		vim.notify("No task in slot " .. n, vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	if s.win and vim.api.nvim_win_is_valid(s.win) then
		pcall(vim.cmd, "stopinsert")
		pcall(vim.api.nvim_win_close, s.win, true)
		s.win = nil
		if M.origin_win and vim.api.nvim_win_is_valid(M.origin_win) then
			pcall(vim.api.nvim_set_current_win, M.origin_win)
		else
			pcall(vim.cmd, "wincmd p")
		end
	else
		local current = vim.api.nvim_get_current_win()
		local active_slot_win = nil
		for _, slot in pairs(M.slots) do
			if slot.win and vim.api.nvim_win_is_valid(slot.win) then
				active_slot_win = slot.win
				break
			end
		end
		if current ~= active_slot_win then
			M.origin_win = current
		end

		s.win = open_or_attach_bottom_win(12)
		vim.api.nvim_win_set_buf(s.win, s.buf)
		vim.wo[s.win].number = false
		vim.wo[s.win].relativenumber = false
		vim.wo[s.win].signcolumn = "no"
		bind_task_buffer_keys(s.buf, n)
	end
	M.last_slot = n
end

function M.toggle_last_slot_window()
	M.sync_task_slots()
	if not M.last_slot then
		vim.notify("No task has been run yet", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end
	M.toggle_slot_window(M.last_slot)
end

-- opts (optional): { env = <dict passed to the shell>, on_done = function(exit_code) }
-- on_done fires once per chain: 0 when every step succeeded, the failing step's exit
-- code otherwise. Callers that gate further work on the result (launch profiles'
-- pre-launch tasks) need this; nothing else passes opts.
local function run_step_sequence(step_idx, steps, root, origin_win, task_name, slot, task_item, opts)
	opts = opts or {}
	local total = #steps
	local current_cmd = steps[step_idx]

	if step_idx == 1 then
		local prev = M.slots[slot]
		if prev then
			if prev.job_id and prev.job_id > 0 then
				prev.is_killing_for_restart = true
				pcall(vim.fn.jobstop, prev.job_id)
			end
			if prev.win and vim.api.nvim_win_is_valid(prev.win) then
				pcall(vim.api.nvim_win_close, prev.win, true)
			end
			if prev.buf and vim.api.nvim_buf_is_valid(prev.buf) then
				pcall(vim.api.nvim_buf_delete, prev.buf, { force = true })
			end
		end

		local win = open_or_attach_bottom_win(12)
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(win, buf)

		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].buflisted = false
		vim.bo[buf].filetype = "TaskRunner"
		vim.b[buf].krs_is_task = true
		vim.b[buf].krs_task_slot = slot
		vim.b[buf].krs_task_name = task_name

		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
		bind_task_buffer_keys(buf, slot)

		M.slots[slot] = {
			win = win,
			buf = buf,
			job_id = nil,
			name = task_name,
			task_item = task_item,
			root = root,
			steps = steps,
			is_killing_for_restart = false,
			is_killing = false,
		}
		M.last_slot = slot
	end

	local s = M.slots[slot]
	local win = s.win
	local buf = s.buf

	vim.notify(
		string.format("🚀 Running Step %d/%d: %s", step_idx, total, current_cmd),
		vim.log.levels.INFO,
		{ title = "KRS Task Runner" }
	)

	local term_opts = {
		cwd = root,
		on_exit = function(_, exit_code, _)
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(buf) then
					if opts.on_done then
						opts.on_done(exit_code)
					end
					return
				end

				local cur_s = M.slots[slot]
				if cur_s and (cur_s.is_killing_for_restart or cur_s.is_killing) then
					-- Stopped or restarted by hand: never report success, or a waiting
					-- caller would treat a cancelled build as a passing one.
					if opts.on_done then
						opts.on_done(exit_code == 0 and 1 or exit_code)
					end
					return
				end

				if exit_code == 0 then
					if step_idx < total then
						vim.notify(
							string.format("✅ Step %d/%d completed. Starting Step %d/%d...", step_idx, total, step_idx + 1, total),
							vim.log.levels.INFO,
							{ title = "KRS Task Runner" }
						)
						run_step_sequence(step_idx + 1, steps, root, origin_win, task_name, slot, task_item, opts)
					else
						if M.slots[slot] then M.slots[slot].job_id = nil end
						pcall(vim.cmd, "stopinsert")
						if vim.api.nvim_win_is_valid(win) then
							pcall(vim.api.nvim_set_current_win, win)
						end

						local function close_task_window()
							if origin_win and vim.api.nvim_win_is_valid(origin_win) then
								pcall(vim.api.nvim_set_current_win, origin_win)
							else
								pcall(vim.cmd, "wincmd p")
							end
							if vim.api.nvim_win_is_valid(win) then
								pcall(vim.api.nvim_win_close, win, true)
							end
							if M.slots[slot] and M.slots[slot].win == win then M.slots[slot].win = nil end
						end

						local map_opts = { noremap = true, silent = true, nowait = true, buffer = buf }
						vim.keymap.set({ "n", "t", "i", "v" }, "<CR>", close_task_window, map_opts)
						vim.keymap.set({ "n", "t", "i", "v" }, "<Esc>", close_task_window, map_opts)
						vim.keymap.set({ "n", "t", "i", "v" }, "q", close_task_window, map_opts)
						vim.keymap.set({ "n", "t", "i", "v" }, "<Space>", close_task_window, map_opts)

						vim.notify(
							string.format("✅ Task chain '%s' (%d/%d steps) finished successfully. Press <Enter> to close.", task_name or "Chain", total, total),
							vim.log.levels.INFO,
							{ title = "KRS Task Runner" }
						)

						if opts.on_done then
							opts.on_done(0)
						end
					end
				else
					if M.slots[slot] then M.slots[slot].job_id = nil end
					pcall(vim.cmd, "stopinsert")
					if vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_set_current_win, win)
					end

					local function close_task_window()
						if origin_win and vim.api.nvim_win_is_valid(origin_win) then
							pcall(vim.api.nvim_set_current_win, origin_win)
						else
							pcall(vim.cmd, "wincmd p")
						end
						if vim.api.nvim_win_is_valid(win) then
							pcall(vim.api.nvim_win_close, win, true)
						end
						if M.slots[slot] and M.slots[slot].win == win then M.slots[slot].win = nil end
					end

					local map_opts = { noremap = true, silent = true, nowait = true, buffer = buf }
					vim.keymap.set({ "n", "t", "i", "v" }, "<CR>", close_task_window, map_opts)
					vim.keymap.set({ "n", "t", "i", "v" }, "<Esc>", close_task_window, map_opts)
					vim.keymap.set({ "n", "t", "i", "v" }, "q", close_task_window, map_opts)
					vim.keymap.set({ "n", "t", "i", "v" }, "<Space>", close_task_window, map_opts)

					local remaining = total - step_idx
					show_failure_alert(step_idx, total, current_cmd, exit_code, remaining)

					if opts.on_done then
						opts.on_done(exit_code)
					end
				end
			end)
		end,
	}

	local sanitized_env = {}
	if opts.env and type(opts.env) == "table" then
		for k, v in pairs(opts.env) do
			if v ~= nil then
				sanitized_env[tostring(k)] = tostring(v)
			end
		end
	end

	-- Enforce UTF-8 encoding across process environments (Python, Node, Go, Rust, System)
	sanitized_env["PYTHONIOENCODING"] = sanitized_env["PYTHONIOENCODING"] or "utf-8"
	sanitized_env["NODE_IO_ENCODING"] = sanitized_env["NODE_IO_ENCODING"] or "utf-8"
	sanitized_env["LANG"] = sanitized_env["LANG"] or "en_US.UTF-8"
	sanitized_env["LC_ALL"] = sanitized_env["LC_ALL"] or "en_US.UTF-8"
	term_opts.env = sanitized_env

	local exec_target = current_cmd
	if type(current_cmd) == "string" and current_cmd ~= "" and not current_cmd:find("[|&><;]") then
		local argv = {}
		for q, word in current_cmd:gmatch([=[["'](.-)["']|(%S+)]=]) do
			table.insert(argv, q or word)
		end
		if #argv > 0 then
			exec_target = argv
		end
	end

	local job_id = vim.fn.termopen(exec_target, term_opts)

	if job_id <= 0 then
		vim.notify("Error starting command: " .. current_cmd, vim.log.levels.ERROR, { title = "KRS Task Runner" })
		if opts.on_done then
			opts.on_done(1)
		end
		return
	end

	s.job_id = job_id
	vim.cmd("startinsert")
end

function M.run_task_item(task_item, root, opts)
	opts = opts or {}
	root = root or M.get_project_root()
	local pdata = M.get_project_data(root)
	local steps = M.resolve_steps(task_item, pdata)

	-- Every bail-out below has to report failure too, or a caller waiting on on_done
	-- (launch profiles) would sit there forever instead of aborting.
	local function abort(msg)
		vim.notify(msg, vim.log.levels.WARN, { title = "KRS Task Runner" })
		if opts.on_done then
			opts.on_done(1)
		end
	end

	if #steps == 0 then
		return abort("No executable steps found for this task")
	end

	M.sync_task_slots()

	local task_name = (type(task_item) == "table" and (task_item.name or task_item.cmd)) or tostring(task_item)

	-- Check if a task with the same name/definition is ALREADY running in any slot
	local running_slot = nil
	for i = 1, 4 do
		local s = M.slots[i]
		if s and s.job_id and s.job_id > 0 then
			local s_name = s.name or ""
			if s_name == task_name or (s.task_item and (s.task_item == task_item or (type(s.task_item) == "table" and type(task_item) == "table" and s.task_item.name == task_item.name))) then
				running_slot = i
				break
			end
		end
	end

	local slot = running_slot or get_free_slot()
	if not slot then
		return abort("All 4 task slots are busy. Stop one first (Ctrl+Shift+Alt+1..4 to view, q/<CR> in it once done).")
	end

	if running_slot then
		local s = M.slots[running_slot]
		s.is_killing_for_restart = true
		pcall(vim.fn.jobstop, s.job_id)
		s.job_id = nil
		vim.notify(string.format("🔄 Killed old running task '%s' (Slot #%d). Rerunning...", task_name, slot), vim.log.levels.INFO, { title = "KRS Task Runner" })
	end

	local origin_win = vim.api.nvim_get_current_win()
	vim.cmd("silent! write")

	run_step_sequence(1, steps, root, origin_win, task_name, slot, task_item, opts)
end

function M.run_task_cmd(cmd, root)
	M.run_task_item(cmd, root)
end

-- Run one shell command in a task slot, with an environment and a completion
-- callback. This is what launch_profiles calls for pre-launch tasks and for run-mode
-- profiles; before it existed both paths errored on a nil value.
function M.run_custom_command(cmd, env, on_exit)
	M.run_task_item(cmd, nil, { env = env, on_done = on_exit })
end

function M.get_active_or_last_slot()
	M.sync_task_slots()
	local cur_buf = vim.api.nvim_get_current_buf()
	local cur_slot = vim.b[cur_buf] and vim.b[cur_buf].krs_task_slot
	if cur_slot and M.slots[cur_slot] then
		return cur_slot
	end

	if M.last_slot and M.slots[M.last_slot] then
		return M.last_slot
	end

	for i = 1, 4 do
		if M.slots[i] then
			return i
		end
	end

	return nil
end

function M.stop_task(slot)
	slot = slot or M.get_active_or_last_slot()
	if not slot or not M.slots[slot] then
		vim.notify("No task found to stop", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return false
	end

	local s = M.slots[slot]
	if s.job_id and s.job_id > 0 then
		s.is_killing = true
		pcall(vim.fn.jobstop, s.job_id)
		s.job_id = nil
		vim.notify(string.format("🛑 Stopped task '%s' (Slot #%d)", s.name or "Task", slot), vim.log.levels.INFO, { title = "KRS Task Runner" })
		return true
	else
		vim.notify(string.format("Task '%s' (Slot #%d) is not currently running", s.name or "Task", slot), vim.log.levels.WARN, { title = "KRS Task Runner" })
		return false
	end
end

function M.restart_task(slot)
	slot = slot or M.get_active_or_last_slot()
	if not slot or not M.slots[slot] then
		vim.notify("No active task found to restart. Run a task first (<C-S-t> or Command Palette).", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	local s = M.slots[slot]
	local task_item = s.task_item
	local root = s.root or M.get_project_root()
	local task_name = s.name or "Task"

	if not task_item then
		vim.notify("Cannot restart task: no stored task definition found for slot #" .. slot, vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	local was_running = s.job_id and s.job_id > 0
	if was_running then
		s.is_killing_for_restart = true
		pcall(vim.fn.jobstop, s.job_id)
		s.job_id = nil
		vim.notify(string.format("🔄 Killed running task '%s' (Slot #%d). Restarting...", task_name, slot), vim.log.levels.INFO, { title = "KRS Task Runner" })
	else
		vim.notify(string.format("🔄 Restarting task '%s' (Slot #%d)...", task_name, slot), vim.log.levels.INFO, { title = "KRS Task Runner" })
	end

	local pdata = M.get_project_data(root)
	local steps = M.resolve_steps(task_item, pdata)
	if #steps == 0 then
		vim.notify("No executable steps found for task", vim.log.levels.WARN, { title = "KRS Task Runner" })
		return
	end

	local origin_win = vim.api.nvim_get_current_win()
	vim.cmd("silent! write")

	run_step_sequence(1, steps, root, origin_win, task_name, slot, task_item)
end

function M.run_default_or_menu()
	local root = M.get_project_root()
	local pdata = M.get_project_data(root)

	if pdata and pdata.default_task then
		M.run_task_item(pdata.default_task, root)
	else
		M.open_task_menu()
	end
end

function M.open_task_menu()
	local root = M.get_project_root()
	local pdata = M.get_project_data(root)
	local discovered = M.discover_tasks(root)

	local tasks = {}

	for _, ct in ipairs(pdata.custom_tasks or {}) do
		local steps = M.resolve_steps(ct, pdata)
		local name = ct.name or (type(ct.cmd) == "string" and ct.cmd) or "Chained Task"
		table.insert(tasks, {
			name = name,
			item = ct,
			steps_count = #steps,
			source = "custom",
			is_custom = true,
		})
	end

	for _, dt in ipairs(discovered) do
		local exists = false
		for _, t in ipairs(tasks) do
			if type(t.item) == "string" and t.item == dt.cmd then
				exists = true
				break
			elseif type(t.item) == "table" and t.item.cmd == dt.cmd then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(tasks, {
				name = dt.name,
				item = dt.cmd,
				steps_count = 1,
				source = dt.source,
			})
		end
	end

	if #tasks == 0 then
		vim.ui.input({ prompt = "No tasks detected. Enter command to execute: " }, function(cmd)
			if cmd and cmd ~= "" then
				pdata.custom_tasks = pdata.custom_tasks or {}
				local new_t = { name = cmd, cmd = cmd }
				table.insert(pdata.custom_tasks, new_t)
				pdata.default_task = new_t
				M.save_project_data(root, pdata)
				M.run_task_item(new_t, root)
			end
		end)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local themes = require("telescope.themes")

	local default_task = pdata.default_task

	pickers.new(themes.get_dropdown({
		prompt_title = " 🛠️ Tasks (" .. vim.fn.fnamemodify(root, ":t") .. ") | [d]=Default [a]=Add [c]=Chain [x]=Delete ",
		finder = finders.new_table({
			results = tasks,
			entry_maker = function(entry)
				local is_def = false
				if default_task then
					if type(default_task) == "string" and (entry.name == default_task or entry.item == default_task) then
						is_def = true
					elseif type(default_task) == "table" and type(entry.item) == "table" and (default_task.name == entry.item.name or default_task.cmd == entry.item.cmd) then
						is_def = true
					end
				end

				local chain_tag = entry.steps_count > 1 and string.format(" 🔗 [%d steps]", entry.steps_count) or ""
				local tag = is_def and " ⭐ [DEFAULT]" or (" [" .. entry.source .. "]" .. chain_tag)
				local display = entry.name .. tag
				return {
					value = entry,
					display = display,
					ordinal = display .. " " .. entry.name,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and selection.value then
					M.run_task_item(selection.value.item, root)
				end
			end)

			local set_default = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					pdata.default_task = selection.value.item
					M.save_project_data(root, pdata)
					actions.close(prompt_bufnr)
					vim.notify("⭐ Default task saved", vim.log.levels.INFO, { title = "KRS Task Runner" })
					vim.schedule(function()
						M.open_task_menu()
					end)
				end
			end
			map("i", "d", set_default)
			map("n", "d", set_default)

			local add_custom = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "New Task Command: " }, function(cmd)
						if cmd and cmd ~= "" then
							pdata.custom_tasks = pdata.custom_tasks or {}
							table.insert(pdata.custom_tasks, { name = cmd, cmd = cmd })
							M.save_project_data(root, pdata)
							M.open_task_menu()
						end
					end)
				end)
			end
			map("i", "a", add_custom)
			map("n", "a", add_custom)

			local add_chain = function()
				actions.close(prompt_bufnr)
				vim.schedule(function()
					vim.ui.input({ prompt = "Chain Name (e.g. Build & Test): " }, function(chain_name)
						if not chain_name or chain_name == "" then return end
						vim.ui.input({ prompt = "Chained steps (separated by '&&' or ','): " }, function(raw_steps)
							if not raw_steps or raw_steps == "" then return end
							local steps = {}
							for step in raw_steps:gmatch("[^&,]+") do
								local clean = step:gsub("^%s*", ""):gsub("%s*$", "")
								if clean ~= "" then
									table.insert(steps, clean)
								end
							end
							if #steps > 0 then
								pdata.custom_tasks = pdata.custom_tasks or {}
								table.insert(pdata.custom_tasks, { name = chain_name, chain = steps })
								M.save_project_data(root, pdata)
								vim.notify("🔗 Task chain saved: " .. chain_name .. " (" .. #steps .. " steps)", vim.log.levels.INFO, { title = "KRS Task Runner" })
							end
							M.open_task_menu()
						end)
					end)
				end)
			end
			map("i", "c", add_chain)
			map("n", "c", add_chain)

			local delete_task = function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					local sel_item = selection.value.item
					if pdata.default_task == sel_item then
						pdata.default_task = nil
					end
					if pdata.custom_tasks then
						local new_custom = {}
						for _, ct in ipairs(pdata.custom_tasks) do
							if ct ~= sel_item and ct.name ~= selection.value.name then
								table.insert(new_custom, ct)
							end
						end
						pdata.custom_tasks = new_custom
					end
					M.save_project_data(root, pdata)
					actions.close(prompt_bufnr)
					vim.schedule(function()
						M.open_task_menu()
					end)
				end
			end
			map("i", "x", delete_task)
			map("n", "x", delete_task)

			return true
		end,
	}), {}):find()
end

function M.setup()
	vim.api.nvim_create_user_command("TaskRunner", function()
		M.open_task_menu()
	end, { desc = "Open KRS Project Task Runner" })

	vim.api.nvim_create_user_command("TaskMenu", function()
		M.open_task_menu()
	end, { desc = "Open KRS Project Task Runner" })

	vim.api.nvim_create_user_command("TaskRestart", function()
		M.restart_task()
	end, { desc = "Kill and restart active project task" })

	vim.api.nvim_create_user_command("TaskKill", function()
		M.stop_task()
	end, { desc = "Kill active project task" })

	vim.api.nvim_create_user_command("TaskRunDefault", function()
		M.run_default_or_menu()
	end, { desc = "Run default project task" })

	local modes = { "n", "i", "v", "t" }
	for _, mode in ipairs(modes) do
		vim.keymap.set(mode, "<C-S-t>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_task_menu()
		end, { noremap = true, silent = true, desc = "Open Project Task Menu" })

		vim.keymap.set(mode, "<C-S-T>", function()
			if vim.fn.mode() == "t" then
				vim.cmd("stopinsert")
			end
			M.open_task_menu()
		end, { noremap = true, silent = true, desc = "Open Project Task Menu" })
	end

	vim.keymap.set("n", "<F5>", function()
		M.run_default_or_menu()
	end, { noremap = true, silent = true, desc = "Run Default Project Task" })

	vim.keymap.set("n", "<F6>", function()
		M.open_task_menu()
	end, { noremap = true, silent = true, desc = "Open Project Task Menu" })

	for i = 1, 4 do
		vim.keymap.set({ "n", "i", "t" }, "<C-A-S-" .. i .. ">", function()
			if vim.fn.mode() == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.toggle_slot_window(i)
		end, { noremap = true, silent = true, desc = "Toggle Task Slot #" .. i })
	end

	for _, m in ipairs({ "n", "i", "v", "t" }) do
		pcall(vim.keymap.del, m, "<C-[>")
		pcall(vim.keymap.del, m, "<C-S-[>")
		pcall(vim.keymap.del, m, "<C-{>")
	end

	local toggle_last_keys = { "<C-o>", "<C-O>", "<C-`>", "<C-S-o>", "<C-S-O>", "<C-A-S-j>" }
	for _, k in ipairs(toggle_last_keys) do
		vim.keymap.set({ "n", "i", "v", "t" }, k, function()
			if vim.fn.mode() == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			M.toggle_last_slot_window()
		end, { noremap = true, silent = true, desc = "Toggle Last Task Slot Window" })
	end
end

_G.ProjectTasks = M

M.setup()

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_tasks",
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

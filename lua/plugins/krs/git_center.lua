-- ============================================================================
-- KRS PLUGIN: Git Center (Ctrl + Shift + G) -- stage, commit, push, review.
-- ============================================================================
-- LAYOUT
--   Left  A control panel in four sections: commit box, staged files, unstaged
--         and untracked files, and a shortcut reference.
--   Right A live VSCode-style diff of the file under the cursor.
--
-- KEYS (inside the panel)
--   1..4 jump to a section          Tab   switch panel focus
--   s/S  stage file / everything    u/U   unstage file / everything
--   r/R  restore file / section     d     full-screen diff modal
--   c/m/t edit title/description/tag      C  commit (and tag)
--   P    push (asks about the upstream)   <F5>/<C-r> refresh
--   <C-S-j>/<C-S-k> scroll the preview    q/<Esc>/<C-S-g> close
--
-- OUTSIDE THE PANEL
--   <C-S-g> toggles the Git Center, <C-S-x> / <A-s> stage everything.
--
-- STRUCTURE
--   krs.git.cmd     Running git (sync reads, async writes).
--   krs.git.status  Parsing the repository state.
--   krs.git.diff    Formatting and colouring diffs.
--   this file       Windows, panel rendering and key handling.
-- ============================================================================

local git = require("krs.git.cmd")
local status = require("krs.git.status")
local diff = require("krs.git.diff")
local ui = require("krs.core.ui")

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.settings = {
	--- Git Center geometry, as a fraction of the editor. The left panel takes
	--- `left_ratio` of the total width; the preview gets the rest.
	width_ratio = 0.92,
	height_ratio = 0.85,
	left_ratio = 0.50,

	--- Full-screen diff modal geometry.
	modal_width_ratio = 0.94,
	modal_height_ratio = 0.90,

	--- Commit message editor modal.
	editor_width_ratio = 0.65,
	editor_height = 6,

	--- Preview refresh delay after the cursor moves, in milliseconds. Enough to
	--- coalesce held-down `j`, short enough to feel immediate.
	preview_debounce_ms = 40,

	--- Notification titles.
	notify_title = "Git Center",
	control_title = "Git Control Center",

	keys = {
		--- Toggle the Git Center from anywhere.
		toggle = { "<C-S-g>", "<C-S-G>" },
		--- Stage everything from anywhere. Many aliases because terminals and GUIs
		--- disagree about how Alt/Meta combinations arrive.
		stage_all = {
			"<C-S-x>", "<C-S-X>",
			"<C-A-s>", "<C-A-S>", "<C-M-s>", "<C-M-S>",
			"<A-C-s>", "<A-C-S>", "<M-C-s>", "<M-C-S>",
			"<A-s>", "<A-S>", "<M-s>", "<M-S>",
		},
		--- Close the panel.
		close = { "<C-S-g>", "<C-S-G>", "<C-g>", "<C-G>", "q", "<Esc>" },
		--- Scroll the preview pane.
		scroll_down = { "<C-S-j>", "<C-S-J>", "<C-j>", "<C-J>" },
		scroll_up = { "<C-S-k>", "<C-S-K>", "<C-k>", "<C-K>" },
		--- Refresh the panel.
		refresh = { "<F5>", "<C-r>" },
		--- Close the diff modal.
		modal_close = { "q", "<Esc>", "<C-c>" },
	},
}

-- ============================================================================
-- STATE -- open windows and the commit form
-- ============================================================================

M.main_win, M.main_buf = nil, nil
M.preview_win, M.preview_buf = nil, nil
M.diff_modal_win, M.diff_modal_buf = nil, nil

--- Formatted diffs, keyed "<type>:<file>". Cleared on every refresh.
M.diff_cache = {}

--- Panel line number -> `{ type = "staged"|"unstaged"|"untracked", file = ... }`.
M.line_map = {}

--- The commit form, kept between openings so a draft is not lost.
M.commit_data = { title = "", description = "", tag = "" }

--- Notification helper carrying the module's title.
--- @param msg string
--- @param level integer|nil Defaults to INFO.
--- @param title string|nil Defaults to `M.settings.notify_title`.
local function notify(msg, level, title)
	vim.notify(msg, level or vim.log.levels.INFO, { title = title or M.settings.notify_title })
end

-- ============================================================================
-- WINDOW LIFECYCLE
-- ============================================================================

--- True when the Git Center is on screen.
--- @return boolean
function M.is_open()
	return M.main_win ~= nil and vim.api.nvim_win_is_valid(M.main_win)
end

--- Closes every window this module owns and forgets their handles.
function M.close_git_center()
	for _, win in ipairs({ M.diff_modal_win, M.preview_win, M.main_win }) do
		ui.close(win)
	end
	M.main_win, M.main_buf = nil, nil
	M.preview_win, M.preview_buf = nil, nil
	M.diff_modal_win, M.diff_modal_buf = nil, nil
end

--- Opens the Git Center, or closes it when it is already open.
function M.toggle_git_center()
	if M.is_open() then
		M.close_git_center()
	else
		M.open_git_center()
	end
end

-- ============================================================================
-- REPOSITORY QUERIES
-- ============================================================================

--- Snapshot of the current repository.
--- @return table|nil info nil when the working directory is not a repository.
function M.get_git_info()
	return status.info()
end

--- Raw diff lines for one file, or its contents when it is untracked.
--- @param file string Path relative to the repository.
--- @param file_type string "staged" | "unstaged" | "untracked".
--- @param cwd string|nil Repository directory.
--- @return string[] lines
--- @return boolean is_untracked
local function raw_diff_for(file, file_type, cwd)
	if file_type == "staged" then
		return git.lines({ "diff", "--cached", "--color=never", "--", file }, cwd), false
	end
	if file_type == "unstaged" then
		return git.lines({ "diff", "--color=never", "--", file }, cwd), false
	end

	local full_path = cwd and (cwd .. "/" .. file) or file
	if vim.fn.filereadable(full_path) == 1 then
		return vim.fn.readfile(full_path), true
	end
	return { "[ Empty or New File ]" }, true
end

-- ============================================================================
-- STAGE ALL (also reachable without opening the panel)
-- ============================================================================

--- Stages every unstaged and untracked change, reporting how many files moved.
--- Retries once after clearing a stale `index.lock`, which is the usual cause of
--- a failed `git add` right after a crash.
---
--- @param cwd string|nil Repository directory.
function M.stage_all_with_modal(cwd)
	cwd = cwd or vim.fn.getcwd()
	git.clean_stale_lock(cwd)

	local info = M.get_git_info()
	if not info then
		notify("❌ Not inside a valid Git repository.", vim.log.levels.ERROR, M.settings.control_title)
		return
	end

	local pending = #info.unstaged + #info.untracked
	if pending == 0 then
		notify(
			"ℹ️ Nothing to stage: no unstaged or untracked changes found.",
			vim.log.levels.WARN,
			M.settings.control_title
		)
		return
	end

	local function execute(is_retry)
		git.run({ "add", "-A" }, function(ok, output)
			if ok then
				notify(
					string.format("✅ Successfully staged %d file%s!", pending, pending == 1 and "" or "s"),
					vim.log.levels.INFO,
					M.settings.control_title
				)
			elseif output:match("index%.lock") and not is_retry and git.clean_stale_lock(cwd) then
				execute(true)
				return
			else
				notify(
					"❌ Failed to stage changes:\n" .. (output ~= "" and output or "Error executing git add"),
					vim.log.levels.ERROR,
					M.settings.control_title
				)
			end

			if M.is_open() then
				pcall(M.open_git_center)
			end
		end, cwd)
	end

	execute(false)
end

-- ============================================================================
-- PANEL CONTENT
-- ============================================================================

--- Renders the control panel.
---
--- @param info table Repository snapshot.
--- @param width integer Panel width, used for the separators.
--- @return string[] lines Panel text.
--- @return table line_map Line number -> `{ type, file }` for file rows.
--- @return table section_lines Section number (1-4) -> line number.
local function build_panel_content(info, width)
	local lines, line_map, section_lines = {}, {}, {}

	local function add(text)
		table.insert(lines, text)
		return #lines
	end

	local function separator(char)
		add(string.rep(char, width - 2))
	end

	--- Adds a file row and records what it points at.
	local function add_file(prefix, file, file_type)
		line_map[add("   " .. prefix .. " " .. file)] = { type = file_type, file = file }
	end

	add(string.format(" 🌿 Branch: %s%s", info.branch, info.upstream and (" (Tracking " .. info.upstream .. ")") or ""))
	add(string.format(" 📊 Changes: +%d -%d lines", info.added, info.deleted))
	add(string.format(
		" 🟢 Staged: %d  |  🔴 Unstaged: %d  |  ❓ Untracked: %d",
		#info.staged, #info.unstaged, #info.untracked
	))
	separator("═")

	section_lines[1] = add(" 📝 [SECTION 1: COMMIT BOX & TAG] (Press 1)")
	add("   [c] Title:       " .. (M.commit_data.title ~= "" and M.commit_data.title or "<Press c to edit in Vim>"))
	add("   [m] Description: " .. (M.commit_data.description ~= "" and M.commit_data.description or "<Optional - Press m>"))
	add("   [t] Tag:         " .. (M.commit_data.tag ~= "" and M.commit_data.tag or "<Optional - Press t>"))
	add("   🚀 [C] Execute Commit & Tag  |  [P] Push Remote")
	separator("─")

	section_lines[2] = add(string.format(
		" 🟢 [SECTION 2: STAGED FILES (%d)] (Press 2 | [u] Unstage / [U] Unstage All)",
		#info.staged
	))
	for _, file in ipairs(info.staged) do
		add_file("✓", file, "staged")
	end
	if #info.staged == 0 then
		add("   (no files staged)")
	end
	separator("─")

	local pending = #info.unstaged + #info.untracked
	section_lines[3] = add(string.format(
		" 🔴 [SECTION 3: UNSTAGED & UNTRACKED FILES (%d)] (Press 3 | [s] Stage / [S] Stage All)",
		pending
	))
	for _, file in ipairs(info.unstaged) do
		add_file("M", file, "unstaged")
	end
	for _, file in ipairs(info.untracked) do
		add_file("?", file, "untracked")
	end
	if pending == 0 then
		add("   (working tree clean)")
	end
	separator("─")

	section_lines[4] = add(" ⚡ [SECTION 4: QUICK ACTIONS & SHORTCUTS] (Press 4)")
	for _, help in ipairs({
		"   [s] Stage file  |  [S] Stage All",
		"   [u] Unstage file  |  [U] Unstage All",
		"   [r] Restore File (Confirm)  |  [R] Restore Section (Confirm)",
		"   [P] Push to Remote (Confirm & Upstream Picker)",
		"   [c] Edit Commit Title  |  [C] Execute Commit & Tag",
		"   [Tab] Switch panel focus  |  [Ctrl+Shift+J/K] Scroll preview",
	}) do
		add(help)
	end

	return lines, line_map, section_lines
end

-- ============================================================================
-- DIFF MODAL
-- ============================================================================

--- Full-screen diff viewer with file rotation and hunk navigation.
--- The working directory is captured up front and restored on close, so nothing
--- here can move the project root out from under neo-tree.
---
--- @param target_file string|nil File to open on. Defaults to the first changed file.
--- @param _target_type string|nil Unused; kept for call-site compatibility.
function M.open_diff_modal(target_file, _target_type)
	local orig_cwd = vim.fn.getcwd()

	local info = M.get_git_info()
	if not info then
		notify("Not a valid Git repository", vim.log.levels.WARN)
		return
	end

	local files = {}
	for _, file_type in ipairs({ "staged", "unstaged", "untracked" }) do
		for _, file in ipairs(info[file_type]) do
			table.insert(files, { file = file, type = file_type })
		end
	end
	if #files == 0 then
		notify("No changed files to show diff", vim.log.levels.INFO)
		return
	end

	local index = 1
	for idx, item in ipairs(files) do
		if target_file and item.file == target_file then
			index = idx
			break
		end
	end

	diff.setup_highlights()

	local buf, win = ui.float({
		width = M.settings.modal_width_ratio,
		height = M.settings.modal_height_ratio,
		title = " 🔍 Git Center Diff Modal ",
		modifiable = true,
	})
	M.diff_modal_buf, M.diff_modal_win = buf, win

	for option, value in pairs({ number = true, wrap = false, cursorline = true }) do
		vim.api.nvim_set_option_value(option, value, { win = win })
	end

	--- Renders file `idx`, wrapping around at both ends.
	local function render(idx)
		index = ((idx - 1) % #files) + 1
		local item = files[index]

		local raw_lines, is_untracked = raw_diff_for(item.file, item.type, orig_cwd)
		local lines, kinds = diff.format(raw_lines, is_untracked)

		local label = item.type == "staged" and "🟢 Staged"
			or (item.type == "unstaged" and "🔴 Unstaged" or "❓ Untracked")
		pcall(vim.api.nvim_win_set_config, win, {
			title = string.format(
				" 🔍 Diff (%d/%d): %s [%s] | [q/Esc]: Close | [Tab/S-Tab]: Switch File | []c/[c]: Next/Prev Hunk ",
				index, #files, item.file, label
			),
			title_pos = "center",
		})

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		diff.apply_highlights(buf, kinds)
		pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
	end

	render(index)

	local function close_modal()
		ui.close(M.diff_modal_win)
		M.diff_modal_win, M.diff_modal_buf = nil, nil
		if orig_cwd and vim.fn.isdirectory(orig_cwd) == 1 then
			pcall(vim.fn.chdir, orig_cwd)
		end
	end

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = close_modal,
	})

	local opts = { buffer = buf, noremap = true, silent = true, nowait = true }
	for _, key in ipairs(M.settings.keys.modal_close) do
		vim.keymap.set("n", key, close_modal, opts)
	end

	for _, key in ipairs({ "<Tab>", "]" }) do
		vim.keymap.set("n", key, function()
			render(index + 1)
		end, opts)
	end
	for _, key in ipairs({ "<S-Tab>", "[" }) do
		vim.keymap.set("n", key, function()
			render(index - 1)
		end, opts)
	end

	--- Moves the cursor to the next/previous hunk separator.
	--- @param step integer 1 forward, -1 backward.
	local function jump_hunk(step)
		local current = vim.api.nvim_win_get_cursor(win)[1]
		local last = step > 0 and vim.api.nvim_buf_line_count(buf) or 1

		for line = current + step, last, step do
			local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
			if text:match("─── Hunk") or text:match("^@@") then
				vim.api.nvim_win_set_cursor(win, { line, 0 })
				return
			end
		end
	end

	vim.keymap.set("n", "]c", function()
		jump_hunk(1)
	end, opts)
	vim.keymap.set("n", "[c", function()
		jump_hunk(-1)
	end, opts)
end

-- ============================================================================
-- MAIN PANEL
-- ============================================================================

--- Opens the Git Center. Calling it while open closes it, which is what makes
--- the same key a toggle.
function M.open_git_center()
	if M.is_open() then
		M.close_git_center()
		return
	end

	local info = M.get_git_info()
	if not info then
		notify("Current directory is not a valid Git repository", vim.log.levels.WARN, "Git Center (KRS)")
		return
	end

	diff.setup_highlights()
	M.diff_cache = {}

	-- ------------------------------------------------------------------
	-- Windows
	-- ------------------------------------------------------------------
	local total_width = math.floor(vim.o.columns * M.settings.width_ratio)
	local total_height = math.floor(vim.o.lines * M.settings.height_ratio)
	local left_width = math.floor(total_width * M.settings.left_ratio)
	local right_width = total_width - left_width - 2
	local start_row = math.floor((vim.o.lines - total_height) / 2)
	local start_col = math.floor((vim.o.columns - total_width) / 2)

	local main_buf = vim.api.nvim_create_buf(false, true)
	M.main_buf = main_buf
	M.main_win = vim.api.nvim_open_win(main_buf, true, {
		relative = "editor",
		width = left_width,
		height = total_height,
		row = start_row,
		col = start_col,
		style = "minimal",
		border = "rounded",
		title = " 🐙 Git Center (Ctrl+Shift+J/K Scroll Preview | Tab Focus | Ctrl+Shift+G Close) ",
		title_pos = "center",
	})

	local preview_buf = vim.api.nvim_create_buf(false, true)
	M.preview_buf = preview_buf
	M.preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		width = right_width,
		height = total_height,
		row = start_row,
		col = start_col + left_width + 2,
		style = "minimal",
		border = "rounded",
		title = " 👁️ VSCode Live Diff (+ / -) | Ctrl+Shift+J/K: Scroll Text ",
		title_pos = "center",
	})

	vim.api.nvim_set_option_value("number", true, { win = M.preview_win })
	vim.api.nvim_set_option_value("wrap", false, { win = M.preview_win })

	-- Closing the panel by any other means still has to clean up the preview.
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(M.main_win),
		once = true,
		callback = M.close_git_center,
	})

	local lines, line_map, section_lines = build_panel_content(info, left_width)
	M.line_map = line_map

	vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = main_buf })
	vim.api.nvim_set_option_value("cursorline", true, { win = M.main_win })

	-- ------------------------------------------------------------------
	-- Live preview
	-- ------------------------------------------------------------------
	local preview_timer = nil

	--- Re-renders the preview shortly after the cursor settles.
	local function update_preview()
		if preview_timer then
			preview_timer:stop()
			if not preview_timer:is_closing() then
				preview_timer:close()
			end
			preview_timer = nil
		end

		preview_timer = vim.uv.new_timer()
		preview_timer:start(
			M.settings.preview_debounce_ms,
			0,
			vim.schedule_wrap(function()
				if not M.is_open() or not (M.preview_win and vim.api.nvim_win_is_valid(M.preview_win)) then
					return
				end

				local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
				local item = M.line_map[row]

				if not item or not item.file then
					vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
						" 💡 Select a staged or unstaged file to view diff.",
					})
					vim.api.nvim_buf_clear_namespace(preview_buf, diff.namespace, 0, -1)
					return
				end

				local cache_key = item.type .. ":" .. item.file
				if not M.diff_cache[cache_key] then
					local raw_lines, is_untracked = raw_diff_for(item.file, item.type, nil)
					local formatted, kinds = diff.format(raw_lines, is_untracked)
					M.diff_cache[cache_key] = { lines = formatted, kinds = kinds }
				end

				local cached = M.diff_cache[cache_key]
				vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, cached.lines)
				diff.apply_highlights(preview_buf, cached.kinds)
			end)
		)
	end

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = vim.api.nvim_create_augroup("KRSGitCenterPreview", { clear = true }),
		buffer = main_buf,
		callback = update_preview,
	})
	update_preview()

	-- ------------------------------------------------------------------
	-- Actions
	-- ------------------------------------------------------------------

	--- Redraws the panel in place -- no window is closed, so there is no flicker.
	local function refresh()
		local current = M.get_git_info()
		if not current or not M.is_open() then
			return
		end

		local new_lines, new_line_map, new_sections = build_panel_content(current, left_width)
		M.line_map = new_line_map
		section_lines = new_sections

		local cursor = vim.api.nvim_win_get_cursor(M.main_win)
		vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, new_lines)
		pcall(vim.api.nvim_win_set_cursor, M.main_win, { math.min(cursor[1], #new_lines), cursor[2] })

		M.diff_cache = {}
		update_preview()
	end

	--- File the cursor is on, or nil.
	--- @return table|nil item `{ type, file }`
	local function current_item()
		return M.line_map[vim.api.nvim_win_get_cursor(M.main_win)[1]]
	end

	--- Runs git synchronously in the repository, for the quick staging actions.
	--- @param args string[] Arguments after `git`.
	--- @return string[] output
	local function git_lines(args)
		return git.lines(args)
	end

	--- Unstaging changed spelling across git versions: `restore --staged` is the
	--- modern form, `reset HEAD` the fallback for older ones.
	--- @param paths string[] Paths, or `{ "." }` for everything.
	local function unstage(paths)
		local args = { "restore", "--staged", "--" }
		vim.list_extend(args, paths)
		local result = git_lines(args)

		if #result > 0 and result[1]:match("fatal") then
			local fallback = { "reset", "HEAD", "--" }
			vim.list_extend(fallback, paths)
			git_lines(fallback)
		end
	end

	--- Applies a staging action to every file inside the visual selection.
	--- @param action "stage"|"unstage"
	local function process_visual_selection(action)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

		vim.schedule(function()
			local first = vim.api.nvim_buf_get_mark(main_buf, "<")[1]
			local last = vim.api.nvim_buf_get_mark(main_buf, ">")[1]
			if first > last then
				first, last = last, first
			end

			local files = {}
			for row = first, last do
				local item = M.line_map[row]
				if item and item.file then
					table.insert(files, item.file)
				end
			end

			if #files > 0 then
				if action == "stage" then
					local args = { "add", "--" }
					vim.list_extend(args, files)
					git_lines(args)
				else
					unstage(files)
				end
			end
			refresh()
		end)
	end

	-- ------------------------------------------------------------------
	-- Keymaps
	-- ------------------------------------------------------------------
	local key_opts = { buffer = main_buf, noremap = true, silent = true, nowait = true }
	local preview_opts = { buffer = preview_buf, noremap = true, silent = true, nowait = true }

	--- Scrolls the preview with a native half-page motion, so it behaves exactly
	--- like <C-d>/<C-u> would inside that window.
	local ctrl_d = vim.api.nvim_replace_termcodes("<C-d>", true, false, true)
	local ctrl_u = vim.api.nvim_replace_termcodes("<C-u>", true, false, true)

	local function scroll_preview(direction)
		if not (M.preview_win and vim.api.nvim_win_is_valid(M.preview_win)) then
			return
		end
		vim.api.nvim_win_call(M.preview_win, function()
			vim.cmd("normal! " .. (direction == "down" and ctrl_d or ctrl_u))
		end)
	end

	for _, key in ipairs(M.settings.keys.scroll_down) do
		vim.keymap.set("n", key, function()
			scroll_preview("down")
		end, key_opts)
		vim.keymap.set("n", key, function()
			scroll_preview("down")
		end, preview_opts)
	end
	for _, key in ipairs(M.settings.keys.scroll_up) do
		vim.keymap.set("n", key, function()
			scroll_preview("up")
		end, key_opts)
		vim.keymap.set("n", key, function()
			scroll_preview("up")
		end, preview_opts)
	end

	local function toggle_focus()
		local target = vim.api.nvim_get_current_win() == M.main_win and M.preview_win or M.main_win
		if target and vim.api.nvim_win_is_valid(target) then
			vim.api.nvim_set_current_win(target)
		end
	end
	vim.keymap.set("n", "<Tab>", toggle_focus, key_opts)
	vim.keymap.set("n", "<Tab>", toggle_focus, preview_opts)

	for _, key in ipairs(M.settings.keys.close) do
		vim.keymap.set("n", key, M.close_git_center, key_opts)
		vim.keymap.set("v", key, M.close_git_center, key_opts)
		vim.keymap.set("n", key, M.close_git_center, preview_opts)
	end

	for section = 1, 4 do
		vim.keymap.set("n", tostring(section), function()
			if section_lines[section] and M.is_open() then
				pcall(vim.api.nvim_win_set_cursor, M.main_win, { section_lines[section], 0 })
			end
		end, key_opts)
	end

	--- Commit form fields, each edited through the shared input modal.
	local commit_fields = {
		{ key = "c", field = "title", label = "Commit Title" },
		{ key = "m", field = "description", label = "Commit Description" },
		{ key = "t", field = "tag", label = "Optional Tag (e.g. v1.0.0)" },
	}
	for _, entry in ipairs(commit_fields) do
		vim.keymap.set("n", entry.key, function()
			require("plugins.krs.input_modal").open({
				label = entry.label,
				default_value = M.commit_data[entry.field],
				relative = "editor",
				callback = function(ok, input)
					if ok then
						M.commit_data[entry.field] = input
						refresh()
					end
				end,
			})
		end, key_opts)
	end

	vim.keymap.set("n", "s", function()
		local item = current_item()
		if item and (item.type == "unstaged" or item.type == "untracked") then
			git_lines({ "add", "--", item.file })
			refresh()
			notify("🟢 Staged: " .. item.file)
		elseif item and item.type == "staged" then
			notify("File is already staged", vim.log.levels.WARN)
		end
	end, key_opts)

	vim.keymap.set("v", "s", function()
		process_visual_selection("stage")
	end, key_opts)

	vim.keymap.set({ "n", "v" }, "S", function()
		local current = M.get_git_info()
		if current and (#current.unstaged > 0 or #current.untracked > 0) then
			git_lines({ "add", "-A" })
			refresh()
			notify("🟢 Staged all files")
		else
			notify("ℹ️ Nothing to stage: working tree is clean.", vim.log.levels.WARN)
		end
	end, key_opts)

	vim.keymap.set("n", "u", function()
		local item = current_item()
		if item and item.type == "staged" then
			unstage({ item.file })
			refresh()
			notify("🔴 Unstaged: " .. item.file)
		elseif item and (item.type == "unstaged" or item.type == "untracked") then
			notify("File is not staged", vim.log.levels.WARN)
		else
			notify("Please select a staged file (✓) to unstage", vim.log.levels.WARN)
		end
	end, key_opts)

	vim.keymap.set("v", "u", function()
		process_visual_selection("unstage")
	end, key_opts)

	vim.keymap.set({ "n", "v" }, "U", function()
		unstage({ "." })
		refresh()
		notify("🔴 Unstaged all files")
	end, key_opts)

	vim.keymap.set("n", "C", function()
		if M.commit_data.title == "" then
			notify("Please enter a commit title first with [c]", vim.log.levels.WARN)
			return
		end

		local args = { "commit", "-m", M.commit_data.title }
		if M.commit_data.description ~= "" then
			table.insert(args, "-m")
			table.insert(args, M.commit_data.description)
		end

		notify("🚀 Commit executed:\n" .. table.concat(git_lines(args), "\n"))

		if M.commit_data.tag ~= "" then
			git_lines({ "tag", M.commit_data.tag })
			notify("🏷️ Tag created: " .. M.commit_data.tag)
		end

		M.commit_data = { title = "", description = "", tag = "" }
		refresh()
	end, key_opts)

	vim.keymap.set("n", "d", function()
		local item = current_item()
		M.open_diff_modal(item and item.file or nil, item and item.type or nil)
	end, key_opts)

	vim.keymap.set("n", "r", function()
		local item = current_item()
		if not (item and item.file) then
			notify("Please place cursor over a file to restore", vim.log.levels.WARN)
			return
		end
		if vim.fn.confirm("⚠️ Discard changes / Restore '" .. item.file .. "'?", "&Yes\n&No", 2) ~= 1 then
			return
		end

		if item.type == "staged" then
			unstage({ item.file })
			git_lines({ "restore", "--", item.file })
		elseif item.type == "unstaged" then
			git_lines({ "restore", "--", item.file })
		elseif vim.fn.isdirectory(item.file) == 1 then
			vim.fn.delete(item.file, "rf")
		else
			os.remove(item.file)
		end

		refresh()
		notify("↺ Restored: " .. item.file)
	end, key_opts)

	vim.keymap.set("n", "R", function()
		local row = vim.api.nvim_win_get_cursor(M.main_win)[1]
		local item = M.line_map[row]

		-- Either the file under the cursor is staged, or the cursor sits inside
		-- section 2 (the staged block) with no file selected.
		local in_staged_section = (item and item.type == "staged")
			or (row >= (section_lines[2] or 0) and row < (section_lines[3] or 999))

		local label = in_staged_section and "STAGED FILES" or "UNSTAGED & UNTRACKED FILES"
		if vim.fn.confirm("⚠️ RESTORE ALL " .. label .. "? Changes will be permanently lost!", "&Yes\n&No", 2) ~= 1 then
			return
		end

		if in_staged_section then
			unstage({ "." })
			git_lines({ "restore", "." })
		else
			git_lines({ "restore", "." })
			git_lines({ "clean", "-fd" })
		end

		refresh()
		notify("↺ Restored all " .. label:lower())
	end, key_opts)

	vim.keymap.set("n", "P", function()
		local current = M.get_git_info()
		local branch = current and current.branch or "HEAD"

		if vim.fn.confirm("🚀 Execute 'git push' for branch '" .. branch .. "'?", "&Yes\n&No", 1) ~= 1 then
			return
		end

		--- Pushes `branch` to `remote/target`, optionally setting the upstream.
		local function perform_push(remote, target, set_upstream)
			notify("🚀 Pushing to " .. remote .. "/" .. target .. "...")

			local args = { "push" }
			if set_upstream then
				table.insert(args, "-u")
			end
			table.insert(args, remote)
			table.insert(args, branch .. ":" .. target)

			git.run(args, function(ok, output)
				if ok then
					notify("✅ Push successful to " .. remote .. "/" .. target .. "!", nil, M.settings.control_title)
				else
					notify(
						"❌ Push failed:\n" .. (output ~= "" and output or "Unknown error"),
						vim.log.levels.ERROR,
						M.settings.control_title
					)
				end
				refresh()
			end)
		end

		local remotes = git_lines({ "remote" })
		if #remotes == 0 then
			require("plugins.krs.input_modal").open({
				label = "No remote found. Add remote URL (origin)",
				default_value = "",
				relative = "editor",
				callback = function(ok, url)
					if ok and url and url ~= "" then
						git_lines({ "remote", "add", "origin", url })
						perform_push("origin", branch, true)
					end
				end,
			})
			return
		end

		local remote = remotes[1] or "origin"

		local upstream = git_lines({ "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}" })
		local has_upstream = #upstream > 0 and not upstream[1]:match("fatal") and not upstream[1]:match("error")

		if has_upstream then
			notify("🚀 Pushing to upstream...")
			git.run({ "push" }, function(ok, output)
				if ok then
					notify("✅ Push successful to remote repository!", nil, M.settings.control_title)
				else
					notify(
						"❌ Push failed:\n" .. (output ~= "" and output or "Unknown error"),
						vim.log.levels.ERROR,
						M.settings.control_title
					)
				end
				refresh()
			end)
			return
		end

		-- No upstream yet: offer to create one, or to target an existing branch.
		git_lines({ "fetch", remote })

		local remote_branches = {}
		for _, line in ipairs(git_lines({ "branch", "-r" })) do
			local name = vim.trim(line)
			if name ~= "" and not name:match("%->") then
				table.insert(remote_branches, name)
			end
		end

		local choices = {
			"1. 🚀 Push and set upstream to " .. remote .. "/" .. branch
				.. " (git push -u " .. remote .. " " .. branch .. ")",
		}
		for index, name in ipairs(remote_branches) do
			table.insert(choices, string.format("%d. 🌿 Push to existing remote branch: %s", index + 1, name))
		end

		pcall(vim.ui.select, choices, {
			prompt = "No upstream branch set for '" .. branch .. "'. Select target branch:",
		}, function(choice, index)
			if not choice or not index then
				return
			end
			if index == 1 then
				perform_push(remote, branch, true)
				return
			end

			local chosen = remote_branches[index - 1]
			if chosen then
				perform_push(remote, chosen:gsub("^[^/]+/", ""), true)
			end
		end)
	end, key_opts)

	for _, key in ipairs(M.settings.keys.refresh) do
		vim.keymap.set("n", key, refresh, key_opts)
	end
end

-- ============================================================================
-- SETUP
-- ============================================================================

--- Registers the user commands and the global keymaps.
--- Runs from the lazy spec's `config`, i.e. once neogit is loaded.
function M.setup()
	pcall(vim.api.nvim_create_user_command, "GitCenter", function()
		M.toggle_git_center()
	end, { desc = "Toggle Git Control Center" })

	pcall(vim.api.nvim_create_user_command, "GitStageAll", function()
		M.stage_all_with_modal()
	end, { desc = "Stage All Unstaged & Untracked Changes with Modal Confirmation" })

	--- Reloads this module from disk, for editing it without restarting nvim.
	local function reload()
		package.loaded["plugins.krs.git_center"] = nil
		_G.GitCenter = nil
		local reloaded = require("plugins.krs.git_center")
		if reloaded and reloaded.config then
			reloaded.config()
		end
		notify("🐙 Git Control Center reloaded successfully!")
	end

	for _, name in ipairs({ "GitCenterReload", "ReloadGitCenter" }) do
		pcall(vim.api.nvim_create_user_command, name, reload, { desc = "Reload Git Control Center" })
	end

	--- Leaves terminal mode first, so the mapping works from a terminal too.
	local function from_any_mode(fn)
		return function()
			if vim.fn.mode() == "t" then
				pcall(vim.cmd, "stopinsert")
			end
			fn()
		end
	end

	for _, key in ipairs(M.settings.keys.toggle) do
		vim.keymap.set({ "n", "i", "v", "t" }, key, from_any_mode(M.toggle_git_center), {
			noremap = true,
			silent = true,
			desc = "Toggle Git Control Center",
		})
	end
	for _, key in ipairs(M.settings.keys.stage_all) do
		vim.keymap.set({ "n", "i", "v", "t" }, key, from_any_mode(function()
			M.stage_all_with_modal()
		end), {
			noremap = true,
			silent = true,
			desc = "Stage All Unstaged & Untracked Changes (Modal Confirmation)",
		})
	end
end

-- Legacy global kept for user scripts and older keybinds that reference it.
_G.GitCenter = M

-- ============================================================================
-- LAZY.NVIM SPEC -- attached to neogit, which supplies the heavier git UI
-- ============================================================================

return setmetatable({
	"NeogitOrg/neogit",
	cmd = { "GitCenter", "GitStageAll", "GitCenterReload", "ReloadGitCenter", "Neogit" },
	keys = {
		{ "<C-S-g>", function() M.toggle_git_center() end, mode = { "n", "i", "v", "t" }, desc = "Toggle Git Center" },
		{ "<C-S-G>", function() M.toggle_git_center() end, mode = { "n", "i", "v", "t" }, desc = "Toggle Git Center" },
		{ "<C-S-x>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
		{ "<C-S-X>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
		{ "<C-A-s>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
		{ "<C-A-S>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
		{ "<A-s>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
		{ "<A-S>", function() M.stage_all_with_modal() end, mode = { "n", "i", "v", "t" }, desc = "Stage All Unstaged & Untracked Changes" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"nvim-telescope/telescope.nvim",
	},
	config = M.setup,
}, { __index = M })

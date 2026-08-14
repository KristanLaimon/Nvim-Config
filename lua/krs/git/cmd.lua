-- ============================================================================
-- krs.git.cmd -- Running git, synchronously and in the background.
-- ============================================================================
-- WHY A MODULE
--   The Git Center used to build `{ "git", "-C", cwd, ... }` by hand in a dozen
--   places, each with its own output handling. Everything that talks to git now
--   goes through here, so quoting, the working directory and error handling are
--   decided once.
--
-- WHICH FUNCTION TO USE
--   `lines()`  Fast, read-only queries (status, diff, remote). Blocks, but git
--              answers these in milliseconds.
--   `run()`    Anything that writes (push, add -A). Never blocks the editor.
--
-- USAGE
--   local git = require("krs.git.cmd")
--   local branches = git.lines({ "branch", "-r" })
--   git.run({ "push" }, function(ok, output) ... end)
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

--- Git executable. Change it to pin a specific build.
M.executable = "git"

--- Lock file git leaves behind when a previous process was killed.
M.lock_file = "index.lock"

-- ---------------------------------------------------------------------------
-- Command construction
-- ---------------------------------------------------------------------------

--- Builds the argv for a git invocation rooted at `cwd`.
--- @param args string|string[] Arguments after `git`. A string is split on spaces.
--- @param cwd string|nil Repository directory. Defaults to the working directory.
--- @return string[] argv
function M.build(args, cwd)
	local argv = { M.executable, "-C", cwd or vim.fn.getcwd() }

	if type(args) == "string" then
		for word in args:gmatch("%S+") do
			table.insert(argv, word)
		end
	else
		vim.list_extend(argv, args)
	end
	return argv
end

--- Starts git without waiting. Several calls can be in flight at once.
--- @param args string|string[] Arguments after `git`.
--- @param cwd string|nil Repository directory.
--- @return table process `vim.system` handle; call `:wait()` on it.
function M.spawn(args, cwd)
	return vim.system(M.build(args, cwd), { text = true })
end

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

--- Waits for a spawned process and splits its stdout into lines.
--- @param process table Handle from `M.spawn`.
--- @return string[] lines Empty when the command printed nothing.
function M.collect(process)
	local result = process:wait()
	local stdout = result.stdout or ""
	if stdout == "" then
		return {}
	end
	return vim.split(stdout, "[\r\n]+", { trimempty = true })
end

--- Runs git and returns its stdout as lines. Blocking.
--- @param args string|string[] Arguments after `git`.
--- @param cwd string|nil Repository directory.
--- @return string[] lines
function M.lines(args, cwd)
	return M.collect(M.spawn(args, cwd))
end

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

--- Runs git in the background. `on_done` is called on the main loop with the
--- combined stderr+stdout, so failure messages are never lost.
---
--- @param args string|string[] Arguments after `git`.
--- @param on_done fun(ok: boolean, output: string)
--- @param cwd string|nil Repository directory.
function M.run(args, on_done, cwd)
	vim.system(
		M.build(args, cwd),
		{ text = true },
		vim.schedule_wrap(function(result)
			local output = ((result.stderr or "") .. (result.stdout or "")):gsub("%s+$", "")
			on_done(result.code == 0, output)
		end)
	)
end

-- ---------------------------------------------------------------------------
-- Repository state
-- ---------------------------------------------------------------------------

--- Absolute path of the repository's git directory.
--- Handles worktrees and submodules, where `.git` is a file, not a directory.
---
--- @param cwd string Repository directory.
--- @return string git_dir
function M.git_dir(cwd)
	local candidate = cwd .. "/.git"
	if vim.fn.isdirectory(candidate) == 1 then
		return candidate
	end

	local result = vim.system({ M.executable, "-C", cwd, "rev-parse", "--git-dir" }, { text = true }):wait()
	if result.code ~= 0 or not result.stdout then
		return candidate
	end

	local git_dir = vim.trim(result.stdout)
	-- `rev-parse` may answer relatively (".git"); make it absolute.
	if not git_dir:match("^/") and not git_dir:match("^%a:") then
		git_dir = cwd .. "/" .. git_dir
	end
	return git_dir
end

--- Removes a leftover `index.lock`.
--- A killed git process leaves one behind and every later command fails with
--- "Unable to create index.lock" until it is gone.
---
--- @param cwd string|nil Repository directory.
--- @return boolean removed True when a lock file was actually deleted.
function M.clean_stale_lock(cwd)
	cwd = cwd or vim.fn.getcwd()
	local lock = M.git_dir(cwd) .. "/" .. M.lock_file

	if not (vim.uv or vim.loop).fs_stat(lock) then
		return false
	end
	pcall((vim.uv or vim.loop).fs_unlink, lock)
	return true
end

--- True when `cwd` is inside a git work tree.
--- @param cwd string|nil Repository directory.
--- @return boolean
function M.is_repository(cwd)
	cwd = cwd or vim.fn.getcwd()
	if vim.fn.isdirectory(cwd .. "/.git") == 1 then
		return true
	end
	local out = M.lines({ "rev-parse", "--is-inside-work-tree" }, cwd)
	return out[1] == "true"
end

return M

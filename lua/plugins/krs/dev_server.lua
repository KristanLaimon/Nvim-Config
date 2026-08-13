-- ============================================================================
-- 🦊 KRS PLUGIN: Dev Server Bridge (Vite / Astro / SvelteKit / Next / Angular)
-- ============================================================================
-- Browser debug configs need a URL that is already serving. This starts the
-- project's dev server (or reuses one that is already up) and hands back its URL.
--
-- Meant to be used as a *function value* inside a nvim-dap configuration:
-- nvim-dap resolves those inside a coroutine, so yielding here waits for the server
-- without blocking the editor, and the browser only launches once the port answers.
-- ============================================================================

local M = {}

-- ponytail: fixed candidate list instead of parsing vite/astro/angular/next configs,
-- each of which puts the port somewhere different (and can be overridden by CLI flags
-- anyway). Set `vim.g.krs_dev_ports = { 1234 }` for a project that serves elsewhere.
local DEFAULT_PORTS = {
	5173, -- vite / sveltekit
	4321, -- astro
	3000, -- next / nuxt / remix
	4200, -- angular
	5174, -- vite, second instance
	8080,
	1420, -- tauri
	3001,
}

local function candidate_ports()
	return vim.g.krs_dev_ports or DEFAULT_PORTS
end

local function root()
	return require("plugins.krs.tasks").get_project_root()
end

-- Yield helpers. Every public entry point below must run inside a coroutine.
local function await(start)
	local co = assert(coroutine.running(), "krs dev_server must be called from a coroutine")
	local result, done = nil, false
	start(function(value)
		result, done = value, true
		if coroutine.status(co) == "suspended" then
			coroutine.resume(co)
		end
	end)
	if not done then
		coroutine.yield()
	end
	return result
end

local function sleep(ms)
	await(function(resume)
		vim.defer_fn(resume, ms)
	end)
end

-- A TCP connect is the only check that proves something is *accepting*. Parsing
-- `netstat` would report a bound socket and race the server's first real listen.
local function probe(port, cb)
	local sock = vim.uv.new_tcp()
	local settled = false
	local function finish(ok)
		if settled then
			return
		end
		settled = true
		pcall(function()
			sock:close()
		end)
		vim.schedule(function()
			cb(ok)
		end)
	end
	sock:connect("127.0.0.1", port, function(err)
		finish(err == nil)
	end)
	vim.defer_fn(function()
		finish(false)
	end, 400)
end

-- Returns the first candidate port that answers, or nil.
function M.find_running_port()
	return await(function(resume)
		local ports = candidate_ports()
		local pending, answered = #ports, false
		for _, port in ipairs(ports) do
			probe(port, function(ok)
				pending = pending - 1
				if ok and not answered then
					answered = true
					resume(port)
				elseif pending == 0 and not answered then
					resume(nil)
				end
			end)
		end
	end)
end

-- Lockfile decides the package manager; package.json decides the script name.
function M.dev_command(project_root)
	project_root = project_root or root()
	local runner = "npm run"
	if vim.fn.filereadable(project_root .. "/bun.lock") == 1 or vim.fn.filereadable(project_root .. "/bun.lockb") == 1 then
		runner = "bun run"
	elseif vim.fn.filereadable(project_root .. "/pnpm-lock.yaml") == 1 then
		runner = "pnpm"
	elseif vim.fn.filereadable(project_root .. "/yarn.lock") == 1 then
		runner = "yarn"
	end

	local script = "dev"
	local pkg_path = project_root .. "/package.json"
	if vim.fn.filereadable(pkg_path) == 1 then
		local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(pkg_path), "\n"))
		local scripts = (ok and type(pkg) == "table" and pkg.scripts) or {}
		for _, name in ipairs({ "dev", "start", "serve" }) do
			if scripts[name] then
				script = name
				break
			end
		end
	end

	return runner .. " " .. script
end

-- Returns "http://localhost:<port>", starting the dev server if nothing is up yet.
-- Returns nil (and notifies) if the server never came up, which aborts the debug
-- session instead of launching a browser at a dead URL.
function M.url(timeout_ms)
	timeout_ms = timeout_ms or 60000

	local port = M.find_running_port()
	if port then
		return "http://localhost:" .. port
	end

	local project_root = root()
	local cmd = M.dev_command(project_root)
	vim.notify("🌐 Starting dev server: " .. cmd, vim.log.levels.INFO, { title = "Dev Server" })
	require("plugins.krs.tasks").run_task_cmd(cmd, project_root)

	local deadline = vim.uv.now() + timeout_ms
	repeat
		sleep(500)
		port = M.find_running_port()
	until port or vim.uv.now() > deadline

	if not port then
		vim.notify(
			"❌ No dev server answered on " .. table.concat(candidate_ports(), ", ") .. " within "
				.. math.floor(timeout_ms / 1000) .. "s.\n  Set vim.g.krs_dev_ports if it serves on a different port.",
			vim.log.levels.ERROR,
			{ title = "Dev Server" }
		)
		return nil
	end

	vim.notify("✅ Dev server up on port " .. port, vim.log.levels.INFO, { title = "Dev Server" })
	return "http://localhost:" .. port
end

-- For attach configs: never starts anything, just points at what is already serving.
function M.existing_url()
	local port = M.find_running_port()
	if not port then
		vim.notify(
			"❌ No dev server found on " .. table.concat(candidate_ports(), ", ") .. ".\n  Use a 'Launch' config to start one.",
			vim.log.levels.ERROR,
			{ title = "Dev Server" }
		)
		return nil
	end
	return "http://localhost:" .. port
end

_G.DevServer = M

local plugin_spec = {
	name = "krs_dev_server",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		-- Dev server bridge module initialized
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

-- ============================================================================
-- krs.launch.runtimes -- One table describing every runtime a launch profile
-- can use: how to RUN it in a terminal, and how to DEBUG it through DAP.
-- ============================================================================
-- WHY THIS EXISTS
--   Adding a language used to mean editing two long if/elseif chains inside
--   launch_profiles.lua and hoping neither was missed. Both chains now live here
--   as data, so "add a language" is "add one entry to `M.registry`".
--
-- HOW TO ADD A RUNTIME
--   1. Add an entry to `M.registry` (see the shape below).
--   2. Add its key to `M.order` so the profile form can cycle to it.
--   3. If it needs a debug adapter, make sure mason-nvim-dap installs it and that
--      `adapter_hint` explains how, or the error message will be useless.
--
-- ENTRY SHAPE
--   command      string|function(ctx) -> string
--                  Executable prefix. The entry point and args are appended by
--                  the caller. An empty string runs the entry point directly.
--   dap          function(profile, root, ctx) -> table|nil
--                  DAP configuration. Omit to use the js-debug default.
--   execute      function(ctx) -> boolean
--                  Fully custom launch. Return true when the runtime handled the
--                  launch itself and no command should be run.
--
-- CONTEXT (`ctx`) passed to every callback
--   { root, entry, full_entry, is_ts, args, args_str, profile }
-- ============================================================================

local path = require("krs.core.path")

local M = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- Runtime keys in the order the profile form cycles through them.
M.order = {
	"bun",
	"node",
	"deno",
	"python",
	"go",
	"php",
	"dotnet",
	"krsnvimscript",
	"krsnvimtranspiler",
	"custom",
}

--- Runtime used when a profile does not name one.
M.default_runtime = "node"

--- Port Xdebug listens on. PHP connects back to nvim, not the other way around.
M.php_debug_port = 9003

--- Port the Deno inspector attaches to.
M.deno_inspect_port = 9229

--- Paths js-debug must never step into, so the debugger does not stop inside
--- node internals or the tsx loader (which also pollutes the bufferline).
M.js_skip_files = { "<node_internals>/**", "**/node_modules/**" }

-- ============================================================================
-- TYPESCRIPT & .NET HELPERS
-- ============================================================================

--- Memoized `node -v` result; the call costs ~50ms and never changes per session.
local node_major

--- Decides how a `.ts`/`.tsx` entry point should be started under node.
--- Preference order: the project's own `tsx` (handles tsconfig paths, enums and
--- decorators), then native node type stripping (22.18+/23.6+), then `npx tsx`.
---
--- Shared with lua/plugins/editor/dap.lua -- keep the return shape stable.
---
--- @param root string Project root.
--- @param entry string Entry point path, relative to root.
--- @return table runtime `{ exe = string, args = string[] }`
function M.ts_runtime(root, entry)
	if not entry:match("%.[cm]?tsx?$") then
		return { exe = "node", args = {} }
	end

	if path.is_dir(path.join(root, "node_modules", "tsx")) then
		return { exe = "node", args = { "--import", "tsx" } }
	end

	if not node_major then
		local major, minor = (vim.fn.system("node -v") or ""):match("v(%d+)%.(%d+)")
		node_major = tonumber(major) and (tonumber(major) + tonumber(minor) / 1000) or 0
	end
	if node_major >= 22.018 then
		return { exe = "node", args = {} }
	end

	local npx = vim.fn.exepath("npx")
	return { exe = npx ~= "" and npx or "npx", args = { "tsx" } }
end

--- Finds the newest built assembly for a `.csproj` (or project directory) entry.
--- netcoredbg launches the DLL, not the project, so this has to resolve it.
---
--- @param root string Project root.
--- @param entry string Entry point: a `.dll`, a `.csproj`, or a directory.
--- @return string|nil dll Absolute path to the newest matching DLL.
function M.find_dotnet_dll(root, entry)
	local full = path.join(root, entry)
	if entry:match("%.dll$") then
		return full
	end

	local proj_dir = entry:match("%.csproj$") and vim.fn.fnamemodify(full, ":h") or full
	local name = entry:match("([^/\\]+)%.csproj$") or vim.fn.fnamemodify(proj_dir, ":t")

	local newest, newest_time = nil, -1
	for _, dll in ipairs(vim.fn.glob(proj_dir .. "/bin/**/" .. name .. ".dll", false, true)) do
		local mtime = vim.fn.getftime(dll)
		if mtime > newest_time then
			newest, newest_time = path.normalize(dll), mtime
		end
	end
	return newest
end

-- ============================================================================
-- RUNTIME REGISTRY
-- ============================================================================

--- Every supported runtime. Adapter type names must match what mason-nvim-dap and
--- nvim-dap-go register: pwa-node (js-debug), go, python, php (xdebug),
--- coreclr (netcoredbg), bun (krs bun adapter), krsnvimscript (built in).
M.registry = {
	bun = {
		command = "bun",
		-- Bun ships its own adapter (WebKit inspector protocol). It spawns bun
		-- itself, so no runtimeExecutable, and it runs .ts with no loader.
		dap = function(profile, root, ctx)
			return {
				type = "bun",
				request = "launch",
				name = profile.name,
				program = ctx.full_entry,
				cwd = root,
				stopOnEntry = false,
				watchMode = false,
			}
		end,
	},

	node = {
		-- Terminal runs go through npx tsx for plain .ts/.tsx only; the debugger
		-- path (js_debug_config) is the one that also handles .mts/.cts.
		command = function(ctx)
			return ctx.entry:match("%.tsx?$") and "npx tsx" or "node"
		end,
	},

	deno = {
		command = "deno run -A",
		dap = function(profile, root, ctx)
			local cfg = M.js_debug_config(profile, root, ctx)
			cfg.runtimeExecutable = "deno"
			cfg.runtimeArgs = { "run", "--inspect-wait", "--allow-all" }
			cfg.attachSimplePort = M.deno_inspect_port
			return cfg
		end,
	},

	python = {
		command = "python",
		dap = function(profile, root, ctx)
			return {
				type = "python",
				request = "launch",
				name = profile.name,
				program = ctx.full_entry,
				cwd = root,
				console = "integratedTerminal",
			}
		end,
	},

	go = {
		command = "go run",
		dap = function(profile, root, ctx)
			return {
				type = "go",
				request = "launch",
				name = profile.name,
				mode = "debug",
				program = ctx.full_entry,
				cwd = root,
			}
		end,
	},

	php = {
		command = "php",
		-- Xdebug is a listener: nvim waits and the PHP process connects back.
		dap = function(profile, root)
			return {
				type = "php",
				request = "launch",
				name = profile.name,
				port = M.php_debug_port,
				pathMappings = { ["/var/www/html"] = root },
			}
		end,
	},

	dotnet = {
		command = "dotnet run --project",
		-- With auto_build enabled, `dotnet build` already ran as a pre-launch task,
		-- so the DLL is on disk by the time this runs.
		dap = function(profile, root, ctx)
			local dll = M.find_dotnet_dll(root, ctx.entry)
			if not dll then
				vim.notify(
					"❌ No built DLL found for "
						.. ctx.entry
						.. ".\n  Enable Auto Build on the profile, or point the entry point at bin/Debug/<tfm>/App.dll.",
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
		end,
	},

	krsnvimscript = {
		command = 'nvim --headless -l',
		dap = function(profile, root, ctx)
			return {
				type = "krsnvimscript",
				request = "launch",
				name = profile.name,
				program = ctx.full_entry,
				cwd = root,
			}
		end,
	},

	-- Not a process: transpiles the script to shell files and returns.
	-- `args_str` selects the target ("sh", "ps1", anything else = both).
	krsnvimtranspiler = {
		execute = function(ctx)
			local transpiler = require("krsnvim").krsnvimtranspiler
			if ctx.args_str == "sh" then
				transpiler.export_sh(ctx.full_entry)
			elseif ctx.args_str == "ps1" then
				transpiler.export_ps1(ctx.full_entry)
			else
				transpiler.export_both(ctx.full_entry)
			end
			return true
		end,
	},

	-- Runs the entry point as-is, for anything not covered above.
	custom = { command = "" },
}

-- ============================================================================
-- API
-- ============================================================================

--- Base js-debug configuration, used by node, deno and any unknown runtime.
---
--- @param profile table Launch profile.
--- @param root string Project root.
--- @param ctx table Launch context.
--- @return table config nvim-dap configuration.
function M.js_debug_config(profile, root, ctx)
	local cfg = {
		type = "pwa-node",
		request = "launch",
		name = profile.name,
		program = ctx.full_entry,
		cwd = root,
		-- Keeps the child process in a nvim terminal buffer instead of popping
		-- external cmd.exe windows for .cmd shims on Windows.
		console = "integratedTerminal",
		sourceMaps = true,
		skipFiles = M.js_skip_files,
	}

	if ctx.is_ts then
		local rt = M.ts_runtime(root, ctx.entry)
		cfg.runtimeExecutable = rt.exe
		cfg.runtimeArgs = #rt.args > 0 and rt.args or nil
	end

	return cfg
end

--- Builds the launch context shared by command building and DAP configuration.
---
--- @param profile table Launch profile.
--- @param root string Project root.
--- @return table ctx `{ root, entry, full_entry, is_ts, args, args_str, profile }`
function M.context(profile, root)
	local entry = profile.entry_point or ""
	local args = profile.args or {}
	return {
		profile = profile,
		root = root,
		entry = entry,
		full_entry = path.join(root, entry),
		is_ts = entry:match("%.[cm]?tsx?$") ~= nil,
		args = args,
		args_str = type(args) == "table" and table.concat(args, " ") or tostring(args),
	}
end

--- Looks up a runtime definition, falling back to `custom` for unknown names.
---
--- @param name string|nil Runtime key.
--- @return table definition
function M.get(name)
	return M.registry[name or M.default_runtime] or M.registry.custom
end

--- Builds the shell command that runs a profile in a terminal.
---
--- @param profile table Launch profile.
--- @param root string Project root.
--- @return string|nil cmd Command line, or nil when the runtime executes itself.
--- @return table ctx Launch context, reusable by the caller.
function M.build_command(profile, root)
	local ctx = M.context(profile, root)
	local def = M.get(profile.runtime)

	if def.execute then
		return nil, ctx
	end

	local prefix = type(def.command) == "function" and def.command(ctx) or def.command
	local cmd = prefix ~= "" and (prefix .. " " .. ctx.entry) or ctx.entry
	if ctx.args_str ~= "" then
		cmd = cmd .. " " .. ctx.args_str
	end

	return cmd, ctx
end

--- Builds the nvim-dap configuration for a profile.
---
--- @param profile table Launch profile.
--- @param root string Project root.
--- @return table|nil config nil when the runtime cannot be debugged right now.
function M.build_dap_config(profile, root)
	local ctx = M.context(profile, root)
	local def = M.get(profile.runtime)

	if def.dap then
		return def.dap(profile, root, ctx)
	end
	return M.js_debug_config(profile, root, ctx)
end

return M

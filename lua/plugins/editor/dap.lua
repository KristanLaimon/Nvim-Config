return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"jay-babu/mason-nvim-dap.nvim",
			"theHamsta/nvim-dap-virtual-text",
			"leoluz/nvim-dap-go",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- nvim 0.12 defaults switchbuf to "uselast", which only reuses the current
			-- window when its buftype is "". Stop with focus in the dapui console/repl
			-- and the source lands in winnr('#') instead of the code window. Prefer a
			-- window already showing the file, then any visible one.
			dap.defaults.fallback.switchbuf = "useopen,usevisible,uselast"

			-- Without this js-debug stops inside node internals and the tsx/ts-node
			-- loader. nvim-dap force-lists every frame's buffer (session.lua: buflisted
			-- = true), so each one becomes a bufferline tab with a long absolute path.
			local js_skip = { "<node_internals>/**", "**/node_modules/**" }

			-- ----------------------------------------------------------------------
			-- Browser configurations (Vite / Astro / SvelteKit / Next / Angular)
			-- ----------------------------------------------------------------------
			-- Two shapes per browser:
			--   Launch  — starts the dev server if nothing is serving yet, then opens
			--             the browser on it. `url` is a function; nvim-dap resolves
			--             config values inside a coroutine, so it can wait for the port.
			--   Attach  — never starts anything. Chromium needs to have been started
			--             with --remote-debugging-port=9222 for this to find it.
			local function browser_configs()
				local dev = function()
					return require("plugins.krs.dev_server").url()
				end
				local existing = function()
					return require("plugins.krs.dev_server").existing_url()
				end

				local configs = {}
				-- ponytail: no sourceMapPathOverrides. js-debug's defaults already resolve
				-- vite's /@fs/ and webpack:// layouts; add overrides only if a framework
				-- shows unbound (⭕) breakpoints.
				for _, browser in ipairs({
					{ type = "pwa-chrome", icon = "🌐", label = "Chrome" },
					{ type = "pwa-msedge", icon = "🔷", label = "Edge" },
				}) do
					table.insert(configs, {
						type = browser.type,
						request = "launch",
						name = browser.icon .. " Launch " .. browser.label .. " + Dev Server",
						url = dev,
						webRoot = "${workspaceFolder}",
						sourceMaps = true,
						skipFiles = js_skip,
						-- false = use the real profile instead of a throwaway one, so the
						-- session, extensions and logins are the ones already set up.
						userDataDir = false,
					})
					table.insert(configs, {
						type = browser.type,
						request = "attach",
						name = browser.icon .. " Attach to running " .. browser.label .. " (port 9222)",
						port = 9222,
						url = existing,
						webRoot = "${workspaceFolder}",
						sourceMaps = true,
						skipFiles = js_skip,
					})
				end

				-- Firefox has no CDP, so js-debug cannot drive it — this is the separate
				-- firefox-debug-adapter. reAttach reuses an already-open Firefox instead
				-- of spawning a second one, which is the closest it gets to "attach".
				table.insert(configs, {
					type = "firefox",
					request = "launch",
					name = "🦊 Launch Firefox + Dev Server",
					reAttach = true,
					url = dev,
					webRoot = "${workspaceFolder}",
					firefoxExecutable = vim.fn.exepath("firefox"),
				})

				return configs
			end

			local mason_dap_ok, mason_dap = pcall(require, "mason-nvim-dap")
			if mason_dap_ok then
				mason_dap.setup({
					-- These are nvim-dap adapter names, NOT mason package names.
					-- (js -> js-debug-adapter, python -> debugpy, coreclr -> netcoredbg)
					ensure_installed = {
						"js",
						-- Firefox has no js-debug equivalent, it needs its own adapter.
						"firefox",
						"delve",
						"python",
						"php",
						"coreclr",
					},
					automatic_installation = true,
					handlers = {
						function(config)
							require("mason-nvim-dap").default_setup(config)
						end,
					},
				})
			end

			-- Setup Go DAP helper if available
			local dap_go_ok, dap_go = pcall(require, "dap-go")
			if dap_go_ok then
				dap_go.setup()
			end

			-- ----------------------------------------------------------------------
			-- JS/TS/Bun Debug Adapters (js-debug-adapter)
			-- ----------------------------------------------------------------------
			local mason_path = (vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter"):gsub("\\", "/")
			local dap_server = mason_path .. "/js-debug/src/dapDebugServer.js"
			local cmd_bin = mason_path .. "/js-debug-adapter.cmd"

			if vim.fn.filereadable(dap_server) == 1 then
				dap.adapters["pwa-node"] = {
					type = "server",
					host = "localhost",
					port = "${port}",
					executable = {
						command = "node",
						args = { dap_server, "${port}" },
					},
				}
				dap.adapters["pwa-chrome"] = {
					type = "server",
					host = "localhost",
					port = "${port}",
					executable = {
						command = "node",
						args = { dap_server, "${port}" },
					},
				}
				-- Edge is Chromium: same js-debug server, different browser binary.
				dap.adapters["pwa-msedge"] = dap.adapters["pwa-chrome"]
			elseif vim.fn.filereadable(cmd_bin) == 1 then
				dap.adapters["pwa-node"] = {
					type = "executable",
					command = cmd_bin,
				}
				dap.adapters["pwa-chrome"] = {
					type = "executable",
					command = cmd_bin,
				}
				dap.adapters["pwa-msedge"] = dap.adapters["pwa-chrome"]
			end

			-- ----------------------------------------------------------------------
			-- Bun Debug Adapter
			-- ----------------------------------------------------------------------
			-- Bun speaks the WebKit inspector protocol, not CDP, so pwa-node cannot
			-- drive it. `bun_dap` checks out Bun's own adapter and gives it the stdio
			-- entry point the VSCode extension never shipped. See its header comment.
			local bun_dap = require("plugins.krs.bun_dap")
			if bun_dap.installed() then
				dap.adapters.bun = {
					type = "executable",
					command = "bun",
					args = { bun_dap.server },
				}
			end

			-- ----------------------------------------------------------------------
			-- PHP Configuration (Xdebug)
			-- ----------------------------------------------------------------------
			dap.configurations.php = {
				{
					type = "php",
					request = "launch",
					name = "Listen for Xdebug",
					port = 9003,
				},
			}

			-- ----------------------------------------------------------------------
			-- TypeScript / JavaScript / Bun / Node.js Configurations
			-- ----------------------------------------------------------------------
			-- Node cannot execute .ts directly. Same resolver the launch profiles use.
			local function ts_launch()
				return require("plugins.krs.launch_profiles").ts_runtime(vim.fn.getcwd(), vim.fn.expand("%:p"))
			end

			for _, language in
				ipairs({
					"typescript",
					"javascript",
					"typescriptreact",
					"javascriptreact",
					"svelte",
					"vue",
					"astro",
				})
			do
				dap.configurations[language] = {
					{
						-- Bun's own adapter; it spawns `bun --inspect-wait` itself, so no
						-- runtimeExecutable/runtimeArgs here. .ts needs no loader either.
						type = "bun",
						request = "launch",
						name = "🐰 Launch Current File (Bun)",
						program = "${file}",
						cwd = "${workspaceFolder}",
						stopOnEntry = false,
						watchMode = false,
					},
					{
						type = "bun",
						request = "attach",
						name = "🐰 Attach to Bun (--inspect)",
						-- `bun --inspect` prints the ws:// URL it is listening on; paste it.
						url = function()
							return vim.fn.input("Bun inspector URL: ", "ws://localhost:6499/", "file")
						end,
					},
					{
						type = "pwa-node",
						request = "launch",
						name = "🚀 Launch Current File (Node/TS)",
						program = "${file}",
						cwd = "${workspaceFolder}",
						-- integratedTerminal keeps the process inside a nvim terminal buffer;
						-- without it Windows pops external cmd.exe windows for npx/.cmd shims.
						console = "integratedTerminal",
						sourceMaps = true,
						skipFiles = js_skip,
						runtimeExecutable = function()
							return ts_launch().exe
						end,
						runtimeArgs = function()
							return ts_launch().args
						end,
					},
					{
						type = "pwa-node",
						request = "attach",
						name = "🔗 Attach to Node Process",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
						skipFiles = js_skip,
					},
					unpack(browser_configs()),
				}
			end

			-- ----------------------------------------------------------------------
			-- Python Configuration
			-- ----------------------------------------------------------------------
			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch Current File (Python)",
					program = "${file}",
					cwd = "${workspaceFolder}",
					console = "integratedTerminal",
					pythonPath = function()
						local cwd = vim.fn.getcwd()
						if vim.fn.executable(cwd .. "/venv/Scripts/python.exe") == 1 then
							return cwd .. "/venv/Scripts/python.exe"
						elseif vim.fn.executable(cwd .. "/.venv/Scripts/python.exe") == 1 then
							return cwd .. "/.venv/Scripts/python.exe"
						elseif vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
							return cwd .. "/venv/bin/python"
						elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
							return cwd .. "/.venv/bin/python"
						end
						return "python"
					end,
				},
			}

			-- ----------------------------------------------------------------------
			-- C# (.NET) Configuration
			-- ----------------------------------------------------------------------
			dap.configurations.cs = {
				{
					type = "coreclr",
					name = "Launch DLL (C#)",
					request = "launch",
					program = function()
						return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
					end,
				},
			}

			-- Standard VS Code route: if the project has .vscode/launch.json, its
			-- configurations show up in the picker alongside the ones above.
			-- load_launchjs is deprecated — nvim-dap reads .vscode/launch.json on demand
			-- now. It still needs this table to know which filetypes a `type` applies to,
			-- otherwise a config is only offered when filetype == type (so `"type": "bun"`
			-- would only ever appear in a file of filetype "bun", i.e. never).
			local web_filetypes =
				{ "typescript", "javascript", "typescriptreact", "javascriptreact", "svelte", "vue", "astro" }
			require("dap.ext.vscode").type_to_filetypes = {
				bun = web_filetypes,
				["pwa-node"] = web_filetypes,
				["pwa-chrome"] = web_filetypes,
				["pwa-msedge"] = web_filetypes,
				node = web_filetypes,
				chrome = web_filetypes,
				firefox = web_filetypes,
				coreclr = { "cs" },
				python = { "python" },
				php = { "php" },
				go = { "go" },
			}

			dapui.setup({
				layouts = {
					{
						-- Right, not left: keeps the code window between the file tree and
						-- the debugger instead of sandwiched between two fixed-width panels.
						-- Fractional size scales with the terminal; the default was a flat
						-- 40 columns, which crushed the code window on narrow screens.
						elements = { "scopes", "stacks", "breakpoints", "watches" },
						size = 0.24,
						position = "right",
					},
					{
						elements = { "repl", "console" },
						size = 0.26,
						position = "bottom",
					},
				},
			})

			local virtual_text_ok, virtual_text = pcall(require, "nvim-dap-virtual-text")
			if virtual_text_ok then
				virtual_text.setup()
			end

			-- nvim-dap only jumps to the stopped frame when
			-- `reason ~= "pause" or allThreadsStopped` (dap/session.lua). js-debug always
			-- reports allThreadsStopped=false, so every pause-type stop — a `debugger`
			-- statement, pause on entry, the pause button — leaves the session stopped
			-- with no source buffer, no cursor move and no stopped-line sign. Jump for it.
			-- js-debug returns a non-zero sourceReference for scripts node ran through
			-- in-memory TypeScript stripping, even though the file exists on disk.
			-- source_to_bufnr (dap/session.lua) checks sourceReference before path, so
			-- nvim-dap opens "dap-src://<session>/<ref>/<path>" with adapter-served
			-- content: a second buffer holding the same code, no breakpoint signs, and a
			-- junk entry in the bufferline. before.stackTrace runs before nvim-dap reads
			-- the response, so dropping the ref here sends it back to the real file.
			dap.listeners.before.stackTrace["krs_prefer_disk_source"] = function(_, _, response)
				for _, frame in ipairs((response or {}).stackFrames or {}) do
					local src = frame.source
					if
						src
						and src.sourceReference
						and src.sourceReference ~= 0
						and src.path
						and vim.fn.filereadable(src.path) == 1
					then
						src.sourceReference = 0
					end
				end
			end

			dap.listeners.after.event_stopped["krs_jump_on_pause"] = function(session, body)
				if body.reason ~= "pause" or body.allThreadsStopped or not body.threadId then
					return
				end
				session:request("stackTrace", { threadId = body.threadId, startFrame = 0, levels = 1 }, function(err, resp)
					local frame = resp and resp.stackFrames and resp.stackFrames[1]
					if not err and frame and frame.source and frame.source.path then
						session:_frame_set(frame)
					end
				end)
			end

			-- Auto open/close DAP UI when debugging starts/stops.
			-- Opening on launch/attach (not on event_initialized) shows the panels
			-- immediately, so a session that never reaches "initialized" is visible.
			dap.listeners.before.launch["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.attach["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- Custom Breakpoint and Execution line signs.
			-- DapBreakpointRejected ("R") is what nvim-dap shows when the adapter refuses
			-- to bind a breakpoint — usually the file never got loaded by the running
			-- program, or its source map does not line up.
			vim.fn.sign_define("DapBreakpoint", { text = "🦊", texthl = "DapBreakpoint", linehl = "", numhl = "" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "🔶", texthl = "DapBreakpoint", linehl = "", numhl = "" })
			vim.fn.sign_define("DapBreakpointRejected", { text = "⭕", texthl = "DapBreakpointRejected", linehl = "", numhl = "" })
			vim.fn.sign_define("DapLogPoint", { text = "💬", texthl = "DapLogPoint", linehl = "", numhl = "" })
			vim.fn.sign_define("DapStopped", { text = "🟡", texthl = "DapStopped", linehl = "DebugHighlight", numhl = "" })

			-- These highlight groups were referenced above but never defined, so the
			-- stopped line rendered with no highlight at all. Re-applied on colorscheme
			-- changes because :colorscheme clears user-defined groups.
			local function define_dap_highlights()
				vim.api.nvim_set_hl(0, "DebugHighlight", { bg = "#3a2f1b", default = true })
				vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e06c75", default = true })
				vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#7f848e", default = true })
				vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef", default = true })
				vim.api.nvim_set_hl(0, "DapStopped", { fg = "#e5c07b", default = true })
			end
			define_dap_highlights()
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = vim.api.nvim_create_augroup("KrsDapHighlights", { clear = true }),
				callback = define_dap_highlights,
			})
		end,
	},
}

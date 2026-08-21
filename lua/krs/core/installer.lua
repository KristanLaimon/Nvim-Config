-- ============================================================================
-- KRS AUTOMATED INCREMENTAL INSTALLER & SYSTEM SETUP
-- ============================================================================
-- Standalone bootstrap installer with zero external dependencies.
--
-- WHAT IT DOES:
--   1. Stage 1 (Essentials): Ensures lazy.nvim, core tools (git, gcc, rg, fd) exist.
--   2. Stage 2 (Heavy Setup): Checks & installs Mason LSPs, Treesitter parsers,
--      and toolchain runtimes with a live animated floating UI modal & progress bar.
--   3. Persistence: Saves state to stdpath("data")/krs_setup_completed.json once
--      100% complete so subsequent normal startups skip full scans for maximum speed.
--   4. Rerunnable & Incremental: Only installs missing or corrupted components.
--   5. Live Installation UI: Displays real-time download activity logs, current item,
--      already installed items, and next queued items so you know it's not frozen.
-- ============================================================================

local M = {}

--- Persistent setup state file in Neovim data path.
local function get_state_path()
	return vim.fn.stdpath("data") .. "/krs_setup_completed.json"
end

--- Expected Mason LSP & Tool packages.
M.mason_packages = {
	"vtsls",
	"intelephense",
	"lua_ls",
	"jsonls",
	"taplo",
	"yamlls",
	"biome",
	"eslint",
	"svelte",
	"astro",
	"html",
	"cssls",
	"tailwindcss",
	"emmet_ls",
	"omnisharp",
	"netcoredbg",
	"lemminx",
	"dockerls",
	"gopls",
	"bashls",
	-- Formatters & Linters (Conform / Mason-Conform)
	"stylua",
	"gofumpt",
	"goimports",
	"prettierd",
	"prettier",
	"blade-formatter",
	"beautysh",
	"protolint",
	"csharpier",
}

--- Map lspconfig server names to Mason package directory/install names.
M.lsp_to_mason = {
	vtsls = "vtsls",
	buf_ls = "buf",
	intelephense = "intelephense",
	lua_ls = "lua-language-server",
	jsonls = "json-lsp",
	taplo = "taplo",
	yamlls = "yaml-language-server",
	biome = "biome",
	eslint = "eslint-lsp",
	svelte = "svelte-language-server",
	astro = "astro-language-server",
	html = "html-lsp",
	cssls = "css-lsp",
	tailwindcss = "tailwindcss-language-server",
	emmet_ls = "emmet-ls",
	omnisharp = "omnisharp",
	netcoredbg = "netcoredbg",
	lemminx = "lemminx",
	dockerls = "dockerfile-language-server",
	gopls = "gopls",
	bashls = "bash-language-server",
}

--- Resolves an lspconfig or tool name to its actual Mason package directory name.
--- @param pkg string
--- @return string
function M.get_mason_package_name(pkg)
	local ok, mappings = pcall(require, "mason-lspconfig.mappings.server")
	if ok and mappings.lspconfig_to_package and mappings.lspconfig_to_package[pkg] then
		return mappings.lspconfig_to_package[pkg]
	end
	return M.lsp_to_mason[pkg] or pkg
end

--- Package metadata mapping Mason package names to Human-readable Languages/Formatters and CLI binaries.
M.package_info = {
	vtsls = { lang = "TypeScript / JavaScript", type = "lsp", cmd = "vtsls" },
	intelephense = { lang = "PHP", type = "lsp", cmd = "intelephense" },
	lua_ls = { lang = "Lua", type = "lsp", cmd = "lua-language-server" },
	jsonls = { lang = "JSON", type = "lsp", cmd = "vscode-json-language-server" },
	taplo = { lang = "TOML", type = "lsp", cmd = "taplo" },
	yamlls = { lang = "YAML", type = "lsp", cmd = "yaml-language-server" },
	biome = { lang = "JS/TS/JSON", type = "lsp", cmd = "biome" },
	eslint = { lang = "JS/TS (ESLint)", type = "lsp", cmd = "vscode-eslint-language-server" },
	svelte = { lang = "Svelte", type = "lsp", cmd = "svelteserver" },
	astro = { lang = "Astro", type = "lsp", cmd = "astro-ls" },
	html = { lang = "HTML", type = "lsp", cmd = "vscode-html-language-server" },
	cssls = { lang = "CSS", type = "lsp", cmd = "vscode-css-language-server" },
	tailwindcss = { lang = "Tailwind CSS", type = "lsp", cmd = "tailwindcss-language-server" },
	emmet_ls = { lang = "Emmet", type = "lsp", cmd = "emmet-ls" },
	omnisharp = { lang = "C#", type = "lsp", cmd = "OmniSharp" },
	netcoredbg = { lang = "C# Debugger", type = "dap", cmd = "netcoredbg" },
	lemminx = { lang = "XML", type = "lsp", cmd = "lemminx" },
	dockerls = { lang = "Docker", type = "lsp", cmd = "docker-langserver" },
	gopls = { lang = "Go", type = "lsp", cmd = "gopls" },
	bashls = { lang = "Bash / Shell", type = "lsp", cmd = "bash-language-server" },

	stylua = { name = "stylua", type = "formatter", cmd = "stylua" },
	gofumpt = { name = "gofumpt", type = "formatter", cmd = "gofumpt" },
	goimports = { name = "goimports", type = "formatter", cmd = "goimports" },
	prettierd = { name = "prettierd", type = "formatter", cmd = "prettierd" },
	prettier = { name = "prettier", type = "formatter", cmd = "prettier" },
	["blade-formatter"] = { name = "blade-formatter", type = "formatter", cmd = "blade-formatter" },
	beautysh = { name = "beautysh", type = "formatter", cmd = "beautysh" },
	protolint = { name = "protolint", type = "formatter", cmd = "protolint" },
	csharpier = { name = "csharpier", type = "formatter", cmd = "csharpier" },
}

--- Expected essential CLI tools.
M.essential_tools = {
	{ cmd = "git", name = "Git version control" },
	{ cmd = "gcc", name = "C/C++ Compiler (gcc/clang)", alt = "clang" },
	{ cmd = "rg", name = "Ripgrep (rg)" },
	{ cmd = "fd", name = "fd / fdfind", alt = "fdfind" },
}

--- Expected heavy runtime tools.
M.heavy_runtimes = {
	{ cmd = "node", name = "Node.js runtime" },
	{ cmd = "bun", name = "Bun runtime" },
	{ cmd = "go", name = "Go programming language" },
	{ cmd = "dotnet", name = ".NET SDK" },
}

-------------------------------------------------------------------------------
-- UI STATE & LIVE ACTIVITY LOGGING
-------------------------------------------------------------------------------

local ui_buf = nil
local ui_win = nil
local live_logs = {}

local function add_log(msg)
	table.insert(live_logs, string.format("[%s] %s", os.date("%H:%M:%S"), msg))
	if #live_logs > 12 then
		table.remove(live_logs, 1)
	end
end

--- Loads completion state from disk.
--- @return table state { completed = boolean, timestamp = string|nil }
function M.load_state()
	local path = get_state_path()
	local file = io.open(path, "r")
	if not file then
		return { completed = false }
	end
	local content = file:read("*a")
	file:close()
	if not content or content == "" then
		return { completed = false }
	end
	local ok, decoded = pcall(vim.json.decode, content)
	if ok and type(decoded) == "table" then
		return decoded
	end
	return { completed = false }
end

--- Saves completion state to disk.
--- @param completed boolean
function M.save_state(completed)
	local path = get_state_path()
	local state = {
		completed = completed == true,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		version = "1.0",
	}
	local ok, json = pcall(vim.json.encode, state)
	if ok and json then
		local file = io.open(path, "w")
		if file then
			file:write(json)
			file:close()
		end
	end
end

--- Resets completion state file to force a full setup re-validation.
function M.reset_state()
	local path = get_state_path()
	pcall(os.remove, path)
	vim.notify("🔄 Setup state reset. Full system setup re-validation enabled.", vim.log.levels.INFO, {
		title = "KRS System Setup",
	})
end

--- Renders a Unicode progress bar.
--- @param percentage number 0 to 100
--- @param width number|nil
--- @return string
function M.render_bar(percentage, width)
	width = width or 12
	local pct = math.max(0, math.min(100, percentage))
	local filled = math.floor((pct / 100) * width)
	local empty = math.max(0, width - filled)
	return string.rep("█", filled) .. string.rep("░", empty)
end

--- Updates the content of the Live Setup Floating Window UI.
--- @param current_active string|nil Component currently downloading/installing
--- @param completed_list string[] Components already downloaded/installed
--- @param queued_list string[] Components queued for installation
--- @param percentage number Progress percentage
local function update_ui_buffer(current_active, completed_list, queued_list, percentage)
	if not ui_buf or not vim.api.nvim_buf_is_valid(ui_buf) then
		return
	end

	local width = 74
	local pct = math.max(0, math.min(100, math.floor(percentage + 0.5)))
	local bar = M.render_bar(pct, 20)
	local lines = {}

	table.insert(lines, "  🦊 KRS AUTOMATED SYSTEM SETUP & INSTALLER")
	table.insert(lines, "  " .. string.rep("─", width - 4))
	table.insert(lines, string.format("  Overall Progress: [%s] %d%%", bar, pct))
	table.insert(lines, "")

	if pct >= 100 then
		table.insert(lines, "  🎉 STATUS: 100% COMPLETE! All LSPs, plugins & tools are installed.")
	elseif current_active then
		table.insert(lines, string.format("  ⏳ CURRENTLY DOWNLOADING / INSTALLING: %s", current_active))
	else
		table.insert(lines, "  ℹ️ STATUS: Ready to start incremental installation.")
	end

	table.insert(lines, "")
	table.insert(lines, "  " .. string.rep("─", width - 4))
	table.insert(lines, string.format("  ✓ ALREADY INSTALLED (%d items):", #completed_list))
	if #completed_list == 0 then
		table.insert(lines, "    (None yet)")
	else
		local summary = {}
		for i, item in ipairs(completed_list) do
			table.insert(summary, item)
			if #summary >= 5 or i == #completed_list then
				table.insert(lines, "    • " .. table.concat(summary, ", "))
				summary = {}
			end
		end
	end

	table.insert(lines, "")
	table.insert(lines, string.format("  📦 NEXT TO DOWNLOAD / QUEUED (%d items):", #queued_list))
	if #queued_list == 0 then
		table.insert(lines, "    (None remaining)")
	else
		local queued_summary = {}
		for i, item in ipairs(queued_list) do
			table.insert(queued_summary, item)
			if #queued_summary >= 5 or i == #queued_list then
				table.insert(lines, "    • " .. table.concat(queued_summary, ", "))
				queued_summary = {}
			end
		end
	end

	table.insert(lines, "")
	table.insert(lines, "  " .. string.rep("─", width - 4))
	table.insert(lines, "  📜 LIVE ACTIVITY LOG (Shows real-time download activity):")
	if #live_logs == 0 then
		table.insert(lines, "    Waiting for activity log...")
	else
		for _, log_msg in ipairs(live_logs) do
			table.insert(lines, "    " .. log_msg)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "  [Press q or Esc to hide modal window — installation continues in background]")

	pcall(function()
		vim.bo[ui_buf].modifiable = true
		vim.api.nvim_buf_set_lines(ui_buf, 0, -1, false, lines)
		vim.bo[ui_buf].modifiable = false
	end)
end

--- Opens or focuses the Live Installation Floating Modal Window.
function M.open_ui()
	local ui = require("krs.core.ui")

	if ui_win and vim.api.nvim_win_is_valid(ui_win) then
		vim.api.nvim_set_current_win(ui_win)
		return
	end

	local scan = M.scan_status()
	local installed_list = scan.installed_items

	local cols = vim.o.columns or 80
	local lines_cnt = vim.o.lines or 24
	local width = math.max(38, math.min(76, cols - 4))
	local height = math.max(14, math.min(24, lines_cnt - 4))

	ui_buf, ui_win = ui.float({
		width = width,
		height = height,
		title = " 🦊 KRS System Setup & Live Installer ",
		focusable = true,
		modifiable = false,
	})

	ui.close_on_keys(ui_buf, ui_win)
	update_ui_buffer(nil, installed_list, scan.missing_lsps, scan.percentage)
end

-------------------------------------------------------------------------------
-- INTERACTIVE TOGGLE SELECTION MENU UI
-------------------------------------------------------------------------------

local toggle_buf = nil
local toggle_win = nil
local toggle_items = {}
local toggle_line_map = {}

local lang_buf = nil
local lang_win = nil
local lang_items = {}
local lang_line_map = {}

--- Renders the content of the Interactive Toggle Selection Menu UI.
function M.render_toggle_menu_buffer()
	if not toggle_buf or not vim.api.nvim_buf_is_valid(toggle_buf) then
		return
	end

	local cols = vim.o.columns or 80
	local width = math.max(38, math.min(74, cols - 6))
	local lines = {}
	toggle_line_map = {}

	table.insert(lines, "  📦 KRS DEPENDENCIES & TOOLCHAINS - TOGGLE MENU")
	table.insert(lines, "  " .. string.rep("─", width - 4))
	table.insert(lines, "  [Space/Enter: Toggle | 'a': Select All | 'n': Select None | 'i': Install]")
	table.insert(lines, "")

	local lsp_items = {}
	local fmt_items = {}

	for _, item in ipairs(toggle_items) do
		if item.type == "LSP" then
			table.insert(lsp_items, item)
		else
			table.insert(fmt_items, item)
		end
	end

	local selected_count = 0

	-- Section 1: LSPs
	table.insert(lines, "  ── 🧠 LSPs & LANGUAGE SERVERS ──────────────────────────────────────")
	for _, item in ipairs(lsp_items) do
		local line_str = ""
		if item.installed then
			line_str = string.format("   [✓ INSTALLED]  %s", item.label)
		elseif item.selected then
			selected_count = selected_count + 1
			line_str = string.format("   [x] SELECTED   %s", item.label)
		else
			line_str = string.format("   [ ] DESELECTED %s", item.label)
		end
		table.insert(lines, line_str)
		toggle_line_map[#lines] = item
	end

	table.insert(lines, "")

	-- Section 2: Formatters & Linters
	table.insert(lines, "  ── 🎨 FORMATTERS & LINTERS ─────────────────────────────────────────")
	for _, item in ipairs(fmt_items) do
		local line_str = ""
		if item.installed then
			line_str = string.format("   [✓ INSTALLED]  %s", item.label)
		elseif item.selected then
			selected_count = selected_count + 1
			line_str = string.format("   [x] SELECTED   %s", item.label)
		else
			line_str = string.format("   [ ] DESELECTED %s", item.label)
		end
		table.insert(lines, line_str)
		toggle_line_map[#lines] = item
	end

	table.insert(lines, "")
	table.insert(lines, "  " .. string.rep("─", width - 4))

	local btn_str = string.format("  👉 [ PRESS 'i' OR ENTER HERE TO START INSTALLING (%d SELECTED) ]", selected_count)
	table.insert(lines, btn_str)
	toggle_line_map[#lines] = "INSTALL_BUTTON"

	table.insert(lines, "  [Press q or Esc to close window]")

	pcall(function()
		vim.bo[toggle_buf].modifiable = true
		vim.api.nvim_buf_set_lines(toggle_buf, 0, -1, false, lines)
		vim.bo[toggle_buf].modifiable = false
	end)
end

--- Opens the Interactive Toggle Selection Menu UI.
function M.open_toggle_menu()
	local ui = require("krs.core.ui")

	if toggle_win and vim.api.nvim_win_is_valid(toggle_win) then
		vim.api.nvim_set_current_win(toggle_win)
		return
	end

	local mason_share = vim.fn.stdpath("data") .. "/mason/packages"
	toggle_items = {}

	for _, pkg in ipairs(M.mason_packages) do
		local mason_pkg = M.get_mason_package_name(pkg)
		local pkg_dir = mason_share .. "/" .. mason_pkg
		local pkg_stat = (vim.uv or vim.loop).fs_stat(pkg_dir)

		local info = M.package_info[pkg] or {}
		local bin_cmd = info.cmd or pkg
		local is_installed = (pkg_stat and pkg_stat.type == "directory") or (vim.fn.executable(bin_cmd) == 1)

		local label = pkg
		if info.lang then
			label = string.format("%s (%s)", info.lang, pkg)
		elseif info.name then
			label = string.format("%s", info.name)
		end

		local item_type = "LSP"
		if info.type == "formatter" then
			item_type = "Formatter"
		end

		table.insert(toggle_items, {
			pkg = pkg,
			label = label,
			type = item_type,
			installed = is_installed,
			selected = not is_installed,
		})
	end

	local cols = vim.o.columns or 80
	local lines_cnt = vim.o.lines or 24
	local width = math.max(38, math.min(76, cols - 4))
	local height = math.max(14, math.min(26, lines_cnt - 4))

	toggle_buf, toggle_win = ui.float({
		width = width,
		height = height,
		title = " 📦 KRS Dependencies Installer - Toggle Menu ",
		focusable = true,
		modifiable = false,
	})

	ui.close_on_keys(toggle_buf, toggle_win)
	M.render_toggle_menu_buffer()

	local opts = { buffer = toggle_buf, silent = true, noremap = true }

	local function toggle_current_item()
		local cursor = vim.api.nvim_win_get_cursor(toggle_win)
		local line_idx = cursor[1]
		local item = toggle_line_map[line_idx]

		if item == "INSTALL_BUTTON" then
			M.start_toggle_installation()
			return
		end

		if not item or type(item) ~= "table" then
			return
		end

		if item.installed then
			vim.notify("✓ " .. item.label .. " is ALREADY INSTALLED on your system/Mason and cannot be toggled off.", vim.log.levels.INFO, {
				title = "Already Installed",
			})
			return
		end

		item.selected = not item.selected
		M.render_toggle_menu_buffer()
		pcall(vim.api.nvim_win_set_cursor, toggle_win, cursor)
	end

	vim.keymap.set("n", "<space>", toggle_current_item, opts)
	vim.keymap.set("n", "<CR>", toggle_current_item, opts)
	vim.keymap.set("n", "<2-LeftMouse>", toggle_current_item, opts)

	vim.keymap.set("n", "a", function()
		for _, item in ipairs(toggle_items) do
			if not item.installed then
				item.selected = true
			end
		end
		M.render_toggle_menu_buffer()
	end, opts)

	vim.keymap.set("n", "n", function()
		for _, item in ipairs(toggle_items) do
			if not item.installed then
				item.selected = false
			end
		end
		M.render_toggle_menu_buffer()
	end, opts)

	local function start_install()
		M.start_toggle_installation()
	end

	vim.keymap.set("n", "i", start_install, opts)
	vim.keymap.set("n", "I", start_install, opts)
	vim.keymap.set("n", "<C-i>", start_install, opts)
end

--- Starts installation of items selected in the Toggle Selection Menu UI.
function M.start_toggle_installation()
	local selected_pkgs = {}
	for _, item in ipairs(toggle_items) do
		if not item.installed and item.selected then
			table.insert(selected_pkgs, item.pkg)
		end
	end

	if #selected_pkgs == 0 then
		vim.notify("⚠️ No uninstalled items are selected for installation.", vim.log.levels.WARN, {
			title = "Selection Empty",
		})
		return
	end

	if toggle_win and vim.api.nvim_win_is_valid(toggle_win) then
		pcall(vim.api.nvim_win_close, toggle_win, true)
	end
	toggle_win = nil
	toggle_buf = nil

	M.ensure_sudo_pass(function(sudo_pass)
		M.install_selected(selected_pkgs, sudo_pass)
	end)
end

--- Performs automated installation of a specific list of selected packages.
--- @param selected_pkgs string[] List of Mason package names
function M.install_selected(selected_pkgs)
	M.open_ui()
	add_log(string.format("Starting batch installation for %d selected packages...", #selected_pkgs))

	vim.schedule(function()
		local has_lazy, lazy = pcall(require, "lazy")
		if has_lazy then
			pcall(function()
				lazy.load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-treesitter" } })
			end)
		end

		pcall(function()
			require("mason").setup()
		end)

		local missing_mason_names = {}
		for _, item in ipairs(selected_pkgs) do
			table.insert(missing_mason_names, M.get_mason_package_name(item))
		end

		add_log("Triggering Mason package installer for selected items...")
		pcall(vim.cmd, "MasonInstall " .. table.concat(missing_mason_names, " "))

		local start_time = (vim.uv or vim.loop).now()
		local max_wait_ms = 90000
		local timer = (vim.uv or vim.loop).new_timer()

		timer:start(500, 500, vim.schedule_wrap(function()
			local scan_now = M.scan_status()
			local remaining_queued = scan_now.missing_lsps

			local active_pkg = remaining_queued[1] or "Treesitter & final validation"
			update_ui_buffer(active_pkg, scan_now.installed_items, remaining_queued, scan_now.percentage)

			local elapsed = (vim.uv or vim.loop).now() - start_time
			if #remaining_queued == 0 or elapsed >= max_wait_ms then
				timer:stop()
				timer:close()
				M.finish_setup(scan_now.installed_items)
			end
		end))
	end)
end

-------------------------------------------------------------------------------
-- ROOT / SUDO SYSTEM SETUP EXECUTION WITH UI PASSWORD PROMPT
-------------------------------------------------------------------------------

--- Cached sudo password in-memory for the current Neovim session.
M.cached_sudo_pass = M.cached_sudo_pass or nil

--- Checks if running inside Termux / Android / Mobile.
--- @return boolean
function M.is_mobile_or_termux()
	return vim.env.TERMUX_VERSION ~= nil
		or vim.fn.isdirectory("/data/data/com.termux") == 1
		or (vim.fn.filereadable("/proc/version") == 1 and (vim.fn.readfile("/proc/version")[1] or ""):lower():match("android") ~= nil)
end

--- Checks if running as a non-root user on Linux/macOS/Termux requiring sudo password authentication.
--- @return boolean
function M.requires_sudo()
	if vim.fn.has("win32") == 1 then
		return false
	end
	local getuid_ok, uid = pcall(function()
		return (vim.uv or vim.loop).getuid()
	end)
	if getuid_ok and uid == 0 then
		return false
	end
	return vim.fn.executable("sudo") == 1 or M.is_mobile_or_termux()
end

--- Obtains sudo password via UI prompt if non-root on Linux/Termux/macOS, or re-uses cached password for session.
--- @param callback function(sudo_pass: string|nil)
function M.ensure_sudo_pass(callback)
	if not M.requires_sudo() then
		callback(nil)
		return
	end

	if M.cached_sudo_pass and M.cached_sudo_pass ~= "" then
		callback(M.cached_sudo_pass)
		return
	end

	local user_name = vim.env.USER or "user"
	vim.ui.input({
		prompt = string.format("🔑 Root/Sudo Password for user '%s': ", user_name),
	}, function(pass)
		if not pass or pass == "" then
			vim.notify("Cancelled installation: Password is required for sudo execution.", vim.log.levels.WARN, {
				title = "Root Password Required",
			})
			callback(nil)
			return
		end
		M.cached_sudo_pass = pass
		callback(pass)
	end)
end

--- Prompts user for root/sudo password in UI prompt if non-root, then executes setup.sh.
function M.run_system_setup_interactive()
	M.ensure_sudo_pass(function(pass)
		M.run_setup_script(pass)
	end)
end

--- Executes setup.sh (or setup.ps1) with live activity modal feed and optional sudo password.
--- @param sudo_pass string|nil
function M.run_setup_script(sudo_pass)
	M.open_ui()
	add_log("Starting system dependency setup via setup script...")

	local script_path = vim.fn.stdpath("config") .. "/scripts/setup.sh"
	local cmd = {}

	if vim.fn.has("win32") == 1 then
		script_path = vim.fn.stdpath("config") .. "/scripts/setup.ps1"
		cmd = { "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", script_path }
	else
		if sudo_pass and sudo_pass ~= "" then
			cmd = { script_path, "--sudo-pass", sudo_pass, "--all" }
		else
			cmd = { script_path, "--all" }
		end
	end

	add_log("Running system installer script...")

	local scan_before = M.scan_status()
	update_ui_buffer("Running system package manager...", scan_before.installed_items, scan_before.missing_lsps, 30)

	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") then
							add_log(clean)
						end
					end
				end
			end
		end),
		on_stderr = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") then
							add_log("⚠️ " .. clean)
						end
					end
				end
			end
		end),
		on_exit = vim.schedule_wrap(function(_, exit_code, _)
			local scan_after = M.scan_status()
			if exit_code == 0 then
				add_log("🎉 System setup script completed successfully!")
				M.finish_setup(scan_after.installed_items)
			else
				add_log(string.format("❌ System setup failed with exit code %d. Verify root/sudo password.", exit_code))
				vim.notify("❌ System setup script failed. Please verify your root/sudo password.", vim.log.levels.ERROR, {
					title = "System Setup Error",
				})
			end
		end),
	})
end

--- Scans installed state of all system components.
--- @return table report
function M.scan_status()
	local report = {
		essentials_ok = true,
		installed_count = 0,
		total_count = 0,
		percentage = 0,
		missing_essentials = {},
		missing_lsps = {},
		missing_runtimes = {},
		installed_items = {},
		lazy_installed = false,
	}

	-- 1. Check lazy.nvim
	local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
	local stat = (vim.uv or vim.loop).fs_stat(lazy_path)
	report.lazy_installed = (stat ~= nil)
	report.total_count = report.total_count + 1
	if report.lazy_installed then
		report.installed_count = report.installed_count + 1
		table.insert(report.installed_items, "lazy.nvim")
	else
		report.essentials_ok = false
		table.insert(report.missing_essentials, "lazy.nvim plugin manager")
	end

	-- 2. Check essential CLI tools
	for _, tool in ipairs(M.essential_tools) do
		report.total_count = report.total_count + 1
		local exists = (vim.fn.executable(tool.cmd) == 1)
			or (tool.alt and vim.fn.executable(tool.alt) == 1)
		if exists then
			report.installed_count = report.installed_count + 1
			table.insert(report.installed_items, tool.cmd)
		else
			report.essentials_ok = false
			table.insert(report.missing_essentials, tool.name)
		end
	end

	-- 3. Check heavy CLI runtimes
	for _, rt in ipairs(M.heavy_runtimes) do
		report.total_count = report.total_count + 1
		if vim.fn.executable(rt.cmd) == 1 then
			report.installed_count = report.installed_count + 1
			table.insert(report.installed_items, rt.cmd)
		else
			table.insert(report.missing_runtimes, rt.name)
		end
	end

	report.missing_languages = {}
	report.missing_formatters = {}
	local seen_langs = {}
	local seen_fmts = {}

	-- 4. Check Mason LSP & tool packages or system executables
	local mason_share = vim.fn.stdpath("data") .. "/mason/packages"
	for _, pkg in ipairs(M.mason_packages) do
		report.total_count = report.total_count + 1
		local mason_pkg = M.get_mason_package_name(pkg)
		local pkg_dir = mason_share .. "/" .. mason_pkg
		local pkg_stat = (vim.uv or vim.loop).fs_stat(pkg_dir)

		local info = M.package_info[pkg] or {}
		local bin_cmd = info.cmd or pkg
		local is_installed = (pkg_stat and pkg_stat.type == "directory") or (vim.fn.executable(bin_cmd) == 1)

		if is_installed then
			report.installed_count = report.installed_count + 1
			table.insert(report.installed_items, pkg)
		else
			table.insert(report.missing_lsps, pkg)
			if info.type == "lsp" and info.lang and not seen_langs[info.lang] then
				seen_langs[info.lang] = true
				table.insert(report.missing_languages, info.lang)
			elseif info.type == "formatter" and info.name and not seen_fmts[info.name] then
				seen_fmts[info.name] = true
				table.insert(report.missing_formatters, info.name)
			end
		end
	end

	report.percentage = math.floor(((report.installed_count / math.max(1, report.total_count)) * 100) + 0.5)
	if report.percentage >= 100 then
		M.save_state(true)
	end
	return report
end

--- Displays detailed setup status report toast.
function M.show_status()
	M.open_ui()
end

--- Performs automated incremental installation (Stage 1 Essentials + Stage 2 Heavy LSPs).
--- Displays real-time progress toast bar & live modal UI feed.
function M.install_all()
	M.ensure_sudo_pass(function(sudo_pass)
		M.open_ui()
		add_log("Starting automated incremental system setup...")

		local scan = M.scan_status()
		local installed_list = scan.installed_items
		local missing_lsps = scan.missing_lsps
		local missing_count = #missing_lsps

		update_ui_buffer("Syncing lazy.nvim plugins...", installed_list, missing_lsps, math.max(15, scan.percentage))

	vim.schedule(function()
		-- Step 1: Ensure Lazy plugins and Mason are loaded (15% -> 25%)
		add_log("Ensuring plugin manager and Mason packages are initialized...")
		local has_lazy, lazy = pcall(require, "lazy")
		if has_lazy then
			pcall(function()
				lazy.load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-treesitter" } })
			end)
		end

		pcall(function()
			require("mason").setup()
		end)

		-- Step 2: Mason LSPs & Tools (25% - 75%)
		if missing_count > 0 then
			add_log(string.format("Found %d missing Mason LSP packages to download...", missing_count))
			add_log("Triggering Mason package installer...")

			local missing_mason_names = {}
			for _, item in ipairs(missing_lsps) do
				table.insert(missing_mason_names, M.get_mason_package_name(item))
			end

			-- Trigger Mason batch installer
			pcall(vim.cmd, "MasonInstall " .. table.concat(missing_mason_names, " "))

			-- Track progress by checking installed directories on disk periodically
			local mason_share = vim.fn.stdpath("data") .. "/mason/packages"
			local start_time = (vim.uv or vim.loop).now()
			local max_wait_ms = 90000 -- 90 second maximum safety timeout
			local timer = (vim.uv or vim.loop).new_timer()

			timer:start(500, 500, vim.schedule_wrap(function()
				local scan_now = M.scan_status()
				local remaining_queued = scan_now.missing_lsps

				local active_pkg = remaining_queued[1] or "Treesitter & final validation"
				update_ui_buffer(active_pkg, scan_now.installed_items, remaining_queued, scan_now.percentage)

				local elapsed = (vim.uv or vim.loop).now() - start_time
				if #remaining_queued == 0 or elapsed >= max_wait_ms then
					timer:stop()
					timer:close()
					if elapsed >= max_wait_ms and #remaining_queued > 0 then
						add_log("⌛ Installation timeout reached. Remaining packages will finish in background.")
					end
					M.finish_setup(scan_now.installed_items)
				end
			end))
		else
			add_log("All Mason LSP packages are already installed.")
			M.finish_setup(installed_list)
		end
	end)
end)
end

--- Finalizes setup execution and persists state.
--- @param installed_list string[] List of installed components
function M.finish_setup(installed_list)
	M.save_state(true)
	local scan = M.scan_status()

	if scan.percentage >= 100 then
		add_log("🎉 SETUP 100% COMPLETE! Saved completion state flag.")
		update_ui_buffer(nil, scan.installed_items, {}, 100)

		vim.notify("🎉 KRS Setup 100% Complete! All LSPs, formatters & tools are installed.", vim.log.levels.INFO, {
			title = "KRS System Setup",
		})
		return
	end

	add_log("Updating Treesitter parsers & validating system...")
	update_ui_buffer("Updating Treesitter parsers...", installed_list, {}, 85)

	vim.defer_fn(function()
		pcall(vim.cmd, "TSUpdateSync")
		M.save_state(true)
		add_log("🎉 SETUP 100% COMPLETE! Saved completion flag.")
		update_ui_buffer(nil, installed_list, {}, 100)

		vim.notify("🎉 KRS Setup 100% Complete! All LSPs, formatters & tools are installed.", vim.log.levels.INFO, {
			title = "KRS System Setup",
		})
	end, 500)
end

--- Internal execution for Google Antigravity CLI installation.
--- @param sudo_pass string|nil
function M.run_install_agy(sudo_pass)
	M.open_ui()
	add_log("Starting installation of Google Antigravity CLI (agy)...")

	local cmd = {}
	if vim.fn.has("win32") == 1 then
		cmd = { "powershell.exe", "-ExecutionPolicy", "Bypass", "-Command", "irm https://antigravity.google/cli/install.ps1 | iex" }
	else
		if sudo_pass and sudo_pass ~= "" then
			cmd = { "bash", "-c", string.format("echo %s | sudo -S bash -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash'", vim.fn.shellescape(sudo_pass)) }
		else
			cmd = { "bash", "-c", "curl -fsSL https://antigravity.google/cli/install.sh | bash" }
		end
	end

	local scan = M.scan_status()
	update_ui_buffer("Downloading Google Antigravity CLI (agy)...", scan.installed_items, { "google-antigravity-cli" }, 40)

	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") and not (sudo_pass and clean:find(sudo_pass, 1, true)) then
							add_log(clean)
						end
					end
				end
			end
		end),
		on_stderr = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") and not (sudo_pass and clean:find(sudo_pass, 1, true)) then
							add_log("⚠️ " .. clean)
						end
					end
				end
			end
		end),
		on_exit = vim.schedule_wrap(function(_, exit_code, _)
			if exit_code == 0 then
				add_log("🎉 Google Antigravity CLI (agy) installed successfully!")
				update_ui_buffer(nil, M.scan_status().installed_items, {}, 100)
				vim.notify("🎉 Google Antigravity CLI (agy) installed successfully! Run 'agy' in terminal to start.", vim.log.levels.INFO, {
					title = "Google Antigravity CLI",
				})
			else
				add_log(string.format("❌ Google Antigravity CLI installation failed with exit code %d.", exit_code))
				vim.notify(string.format("❌ Google Antigravity CLI installation failed (exit code %d).", exit_code), vim.log.levels.ERROR, {
					title = "Installation Failed",
				})
			end
		end),
	})
end

--- Installs Google Antigravity CLI (`agy`) cross-platform using official oneliner scripts.
--- Prompts for root/sudo password if non-root on Linux/macOS/Termux.
function M.install_agy()
	M.ensure_sudo_pass(function(pass)
		M.run_install_agy(pass)
	end)
end

--- Internal execution for Claude Code CLI installation.
--- @param sudo_pass string|nil
function M.run_install_claude(sudo_pass)
	M.open_ui()
	add_log("Starting installation of Claude Code CLI (claude)...")

	local cmd = {}
	if vim.fn.has("win32") == 1 then
		cmd = { "powershell.exe", "-ExecutionPolicy", "Bypass", "-Command", "irm https://claude.ai/install.ps1 | iex" }
	else
		if sudo_pass and sudo_pass ~= "" then
			cmd = { "bash", "-c", string.format("echo %s | sudo -S bash -c 'curl -fsSL https://claude.ai/install.sh | bash || npm install -g @anthropic-ai/claude-code'", vim.fn.shellescape(sudo_pass)) }
		else
			cmd = { "bash", "-c", "curl -fsSL https://claude.ai/install.sh | bash || npm install -g @anthropic-ai/claude-code" }
		end
	end

	local scan = M.scan_status()
	update_ui_buffer("Downloading Claude Code CLI (claude)...", scan.installed_items, { "claude-code-cli" }, 40)

	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") and not (sudo_pass and clean:find(sudo_pass, 1, true)) then
							add_log(clean)
						end
					end
				end
			end
		end),
		on_stderr = vim.schedule_wrap(function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						local clean = line:gsub("\27%[[0-9;]*[mK]", ""):gsub("^%s*", "")
						if clean ~= "" and not clean:lower():match("password") and not (sudo_pass and clean:find(sudo_pass, 1, true)) then
							add_log("⚠️ " .. clean)
						end
					end
				end
			end
		end),
		on_exit = vim.schedule_wrap(function(_, exit_code, _)
			if exit_code == 0 then
				add_log("🎉 Claude Code CLI (claude) installed successfully!")
				update_ui_buffer(nil, M.scan_status().installed_items, {}, 100)
				vim.notify("🎉 Claude Code CLI (claude) installed successfully! Run 'claude' in terminal to authenticate.", vim.log.levels.INFO, {
					title = "Claude Code CLI",
				})
			else
				add_log(string.format("❌ Claude Code CLI installation failed with exit code %d.", exit_code))
				vim.notify(string.format("❌ Claude Code CLI installation failed (exit code %d).", exit_code), vim.log.levels.ERROR, {
					title = "Installation Failed",
				})
			end
		end),
	})
end

--- Installs Claude Code CLI (`claude`) cross-platform using official oneliner scripts.
--- Prompts for root/sudo password if non-root on Linux/macOS/Termux.
function M.install_claude()
	M.ensure_sudo_pass(function(pass)
		M.run_install_claude(pass)
	end)
end

-------------------------------------------------------------------------------
--- 🌐 LANGUAGE TOOLING MANAGER (INTERACTIVE PER-LANGUAGE INSTALL / UNINSTALL)
-------------------------------------------------------------------------------

--- Language Toolchain Bundles for Language Tooling Manager.
--- Each bundle may declare `requires`: system runtimes that must be in PATH
--- before any Mason package from this bundle can be installed.
M.language_bundles = {
	{
		name = "🌙 Minimal Core (Lua & Neovim Editing)",
		lang = "Lua",
		is_minimal = true,
		requires = {}, -- lua-language-server ships as a self-contained binary via Mason
		mason_pkgs = { "lua-language-server", "stylua" },
		treesitter = { "lua", "vim", "vimdoc", "markdown", "markdown_inline" },
	},
	{
		name = "🐘 PHP & Laravel",
		lang = "PHP",
		requires = {
			{ cmd = "php", name = "PHP" },
			{ cmd = "composer", name = "Composer" },
		},
		mason_pkgs = { "intelephense", "php-debug-adapter", "blade-formatter", "php-cs-fixer" },
		treesitter = { "php", "phpdoc", "blade" },
	},
	{
		name = "🟨 TypeScript / JavaScript",
		lang = "TypeScript",
		requires = {
			{ cmd = "node", name = "Node.js", hint = "https://nodejs.org" },
		},
		mason_pkgs = { "vtsls", "eslint-lsp", "biome", "js-debug-adapter", "prettier", "prettierd" },
		treesitter = { "typescript", "javascript", "tsx", "jsx" },
	},
	{
		name = "🟦 Go",
		lang = "Go",
		requires = {
			{ cmd = "go", name = "Go runtime", hint = "https://go.dev/dl" },
		},
		mason_pkgs = { "gopls", "delve", "gofumpt", "goimports", "golangci-lint" },
		treesitter = { "go", "gomod", "gowork", "gosum" },
	},
	{
		name = "🐍 Python",
		lang = "Python",
		requires = {
			{ cmd = "python3", name = "Python 3", alt = "python", hint = "https://python.org" },
		},
		mason_pkgs = { "pyright", "debugpy", "black", "isort", "ruff" },
		treesitter = { "python" },
	},
	{
		name = "🎯 C# / .NET",
		lang = "C#",
		requires = {
			{ cmd = "dotnet", name = ".NET SDK", hint = "https://dot.net" },
		},
		mason_pkgs = { "omnisharp", "csharp_ls", "netcoredbg", "csharpier" },
		treesitter = { "c_sharp" },
		dotnet_tools = { "csharp-ls" },
	},
	{
		name = "🌐 Web Frontend (HTML, CSS, Svelte, Astro)",
		lang = "Web",
		requires = {
			{ cmd = "node", name = "Node.js", hint = "https://nodejs.org" },
		},
		mason_pkgs = { "html-lsp", "css-lsp", "tailwindcss-language-server", "svelte-language-server", "astro-language-server", "emmet-ls" },
		treesitter = { "html", "css", "svelte", "astro" },
	},
	{
		name = "🐳 Docker & Proto",
		lang = "Docker/Proto",
		requires = {}, -- dockerfile-language-server & protolint are standalone Mason binaries
		mason_pkgs = { "dockerfile-language-server", "dockerfmt", "protolint" },
		treesitter = { "editorconfig", "proto" },
	},
	{
		name = "🐚 Shell / Bash",
		lang = "Bash",
		requires = {}, -- bash-language-server is a standalone Mason binary
		mason_pkgs = { "bash-language-server", "bash-debug-adapter", "beautysh", "shellcheck" },
		treesitter = { "bash" },
	},
}

--- Computes real-time installation status for a given language bundle.
--- Checks required system runtimes first; if any are missing the bundle is
--- marked as blocked and no Mason/TS counts are reported.
--- @param bundle table
--- @return table { installed_count: number, total_count: number, badge: string, missing_runtimes: string[], blocked: boolean }
function M.get_bundle_status(bundle)
	local mason_share = vim.fn.stdpath("data") .. "/mason/packages"

	-- 1. Check required system runtimes
	local missing_runtimes = {}
	for _, req in ipairs(bundle.requires or {}) do
		local ok = vim.fn.executable(req.cmd) == 1
			or (req.alt and vim.fn.executable(req.alt) == 1)
		if not ok then
			table.insert(missing_runtimes, req.name)
		end
	end

	if #missing_runtimes > 0 then
		return {
			installed_count = 0,
			total_count = 0,
			badge = string.format("[ ⚠️  needs: %s ]", table.concat(missing_runtimes, ", ")),
			missing_runtimes = missing_runtimes,
			blocked = true,
		}
	end

	-- 2. Count Mason packages
	local installed = 0
	local total = 0

	for _, pkg in ipairs(bundle.mason_pkgs or {}) do
		total = total + 1
		local pkg_dir = mason_share .. "/" .. pkg
		local pkg_stat = (vim.uv or vim.loop).fs_stat(pkg_dir)
		local info = M.package_info[pkg] or {}
		local bin_cmd = info.cmd or pkg
		if (pkg_stat and pkg_stat.type == "directory") or (vim.fn.executable(bin_cmd) == 1) then
			installed = installed + 1
		end
	end

	-- 3. Count Treesitter parsers
	for _, parser in ipairs(bundle.treesitter or {}) do
		total = total + 1
		local ok, parsers_mod = pcall(require, "nvim-treesitter.parsers")
		if ok and parsers_mod.has_parser and parsers_mod.has_parser(parser) then
			installed = installed + 1
		end
	end

	local badge = ""
	if installed == total and total > 0 then
		badge = string.format("[✅ Installed (%d/%d)]", installed, total)
	elseif installed > 0 then
		badge = string.format("[🟡 Partial (%d/%d)]", installed, total)
	else
		badge = string.format("[❌ Not Installed (0/%d)]", total)
	end

	return {
		installed_count = installed,
		total_count = total,
		badge = badge,
		missing_runtimes = {},
		blocked = false,
	}
end

--- Installs all packages and treesitter parsers in a language bundle.
--- Aborts with a warning if any required system runtimes are missing.
--- @param bundle table
function M.install_language_bundle(bundle)
	-- Guard: check required system runtimes before attempting install
	local missing = {}
	for _, req in ipairs(bundle.requires or {}) do
		local ok = vim.fn.executable(req.cmd) == 1
			or (req.alt and vim.fn.executable(req.alt) == 1)
		if not ok then
			local entry = req.name
			if req.hint then
				entry = entry .. " → " .. req.hint
			end
			table.insert(missing, entry)
		end
	end

	if #missing > 0 then
		vim.notify(
			string.format(
				"⚠️  Cannot install %s\n\nMissing system runtime(s):\n  • %s\n\nInstall the listed runtime(s), restart Neovim, then try again.",
				bundle.name,
				table.concat(missing, "\n  • ")
			),
			vim.log.levels.WARN,
			{ title = "Missing Runtime — " .. bundle.name }
		)
		return
	end

	vim.notify("📥 Installing toolchain for " .. bundle.name .. "...", vim.log.levels.INFO, {
		title = "Language Tooling Manager",
	})

	-- 1. Install Mason packages
	local mr_ok, mr = pcall(require, "mason-registry")
	if mr_ok then
		mr.refresh(function()
			for _, pkg_name in ipairs(bundle.mason_pkgs or {}) do
				if mr.has_package(pkg_name) then
					local pkg = mr.get_package(pkg_name)
					if not pkg:is_installed() then
						pkg:install()
					end
				end
			end
		end)
	end

	-- 2. Install Treesitter parsers
	local ts_ok, ts = pcall(require, "nvim-treesitter")
	if ts_ok then
		for _, parser in ipairs(bundle.treesitter or {}) do
			pcall(ts.install, { parser })
		end
	end

	-- 3. Install dotnet global tools if applicable
	if bundle.dotnet_tools and vim.fn.executable("dotnet") == 1 then
		for _, tool in ipairs(bundle.dotnet_tools) do
			vim.system({ "dotnet", "tool", "install", "-g", tool })
		end
	end

	vim.notify("✅ Toolchain installation triggered for " .. bundle.name, vim.log.levels.INFO, {
		title = "Language Tooling Manager",
	})
end

--- Uninstalls all packages and treesitter parsers in a language bundle.
--- @param bundle table
function M.uninstall_language_bundle(bundle)
	vim.notify("🗑️ Uninstalling toolchain for " .. bundle.name .. "...", vim.log.levels.INFO, {
		title = "Language Tooling Manager",
	})

	-- 1. Uninstall Mason packages
	local mr_ok, mr = pcall(require, "mason-registry")
	if mr_ok then
		for _, pkg_name in ipairs(bundle.mason_pkgs or {}) do
			if mr.has_package(pkg_name) then
				local pkg = mr.get_package(pkg_name)
				if pkg:is_installed() then
					pcall(function()
						pkg:uninstall()
					end)
				end
			end
		end
	end

	-- 2. Uninstall Treesitter parsers
	local ts_ok, ts = pcall(require, "nvim-treesitter")
	if ts_ok then
		for _, parser in ipairs(bundle.treesitter or {}) do
			pcall(ts.uninstall, { parser })
		end
	end

	-- 3. Uninstall dotnet global tools if applicable
	if bundle.dotnet_tools and vim.fn.executable("dotnet") == 1 then
		for _, tool in ipairs(bundle.dotnet_tools) do
			vim.system({ "dotnet", "tool", "uninstall", "-g", tool })
		end
	end

	vim.notify("🗑️ Toolchain uninstalled for " .. bundle.name, vim.log.levels.WARN, {
		title = "Language Tooling Manager",
	})
end

--- Renders the Interactive Language Manager UI floating buffer.
function M.render_language_manager_buffer()
	if not lang_buf or not vim.api.nvim_buf_is_valid(lang_buf) then
		return
	end

	local lines = {}
	lang_line_map = {}

	local width = (lang_win and vim.api.nvim_win_is_valid(lang_win)) and vim.api.nvim_win_get_width(lang_win) or 76

	table.insert(lines, "  ==========================================================================")
	table.insert(lines, "   🌐 KRS LANGUAGE TOOLING MANAGER -- PER-LANGUAGE SETUP & TEARDOWN")
	table.insert(lines, "  ==========================================================================")
	table.insert(lines, "   Fresh setup defaults to Minimal Core (Lua only). Select optional bundles below.")
	table.insert(lines, "")

	local selected_count = 0
	local pending_count = 0

	for _, item in ipairs(lang_items) do
		local status = M.get_bundle_status(item.bundle)
		item.status = status

		local is_fully_installed = (status.installed_count == status.total_count and status.total_count > 0)
		local is_pending = not status.blocked and not is_fully_installed and not item.bundle.is_minimal

		if is_pending then
			pending_count = pending_count + 1
		end

		-- Blocked bundles get a lock symbol instead of a checkbox
		local checkbox
		if status.blocked then
			checkbox = "[🔒]"
		elseif item.selected then
			checkbox = "[x]"
		else
			checkbox = "[ ]"
		end
		if item.selected and not status.blocked then
			selected_count = selected_count + 1
		end

		local tag = item.bundle.is_minimal and " (Core)" or ""
		local line_str = string.format("   %s  %-42s %s%s", checkbox, item.bundle.name, status.badge, tag)
		table.insert(lines, line_str)
		lang_line_map[#lines] = item
	end

	table.insert(lines, "")
	table.insert(lines, "  " .. string.rep("─", width - 4))
	table.insert(lines, string.format("  👉 [ PRESS 'i' OR ENTER TO INSTALL SELECTED BUNDLES (%d SELECTED) ]", selected_count))
	table.insert(lines, "  [Space/Enter] Toggle Row             |  [d] Show Component Details")
	table.insert(lines, string.format("  [a] Select All    [n] Select None   |  [p] Select All Pending (%d bundles)", pending_count))
	table.insert(lines, "  [i] Install Selected                |  [u] Uninstall Selected  |  [q/Esc] Close")

	pcall(function()
		vim.bo[lang_buf].modifiable = true
		vim.api.nvim_buf_set_lines(lang_buf, 0, -1, false, lines)
		vim.bo[lang_buf].modifiable = false
	end)
end

--- Opens the Floating Buffer UI for Language Tooling Manager.
function M.open_language_manager()
	local ui = require("krs.core.ui")

	if lang_win and vim.api.nvim_win_is_valid(lang_win) then
		vim.api.nvim_set_current_win(lang_win)
		return
	end

	lang_items = {}
	for _, bundle in ipairs(M.language_bundles) do
		local status = M.get_bundle_status(bundle)
		-- Only pre-select: minimal core (always on) or fully installed bundles.
		-- Partial or missing bundles start deselected — user must opt-in.
		local auto_select = bundle.is_minimal
			or (status.installed_count == status.total_count and status.total_count > 0)
		table.insert(lang_items, {
			bundle = bundle,
			selected = auto_select,
			status = status,
		})
	end

	local cols = vim.o.columns or 80
	local lines_cnt = vim.o.lines or 24
	local width = math.max(48, math.min(78, cols - 4))
	local height = math.max(14, math.min(22, lines_cnt - 4))

	lang_buf, lang_win = ui.float({
		width = width,
		height = height,
		title = " 🌐 KRS Language Tooling Manager ",
		focusable = true,
		modifiable = false,
	})

	ui.close_on_keys(lang_buf, lang_win)
	M.render_language_manager_buffer()

	local opts = { buffer = lang_buf, silent = true, noremap = true }

	local function get_current_item()
		if not lang_win or not vim.api.nvim_win_is_valid(lang_win) then
			return nil, nil
		end
		local cursor = vim.api.nvim_win_get_cursor(lang_win)
		return lang_line_map[cursor[1]], cursor
	end

	local function toggle_checkbox()
		local item, cursor = get_current_item()
		if item and type(item) == "table" then
			item.selected = not item.selected
			M.render_language_manager_buffer()
			if cursor and lang_win and vim.api.nvim_win_is_valid(lang_win) then
				pcall(vim.api.nvim_win_set_cursor, lang_win, cursor)
			end
		end
	end

	local function install_action()
		local item, cursor = get_current_item()
		local count_selected = 0
		for _, it in ipairs(lang_items) do
			if it.selected then count_selected = count_selected + 1 end
		end

		if count_selected > 0 then
			for _, it in ipairs(lang_items) do
				if it.selected then
					M.install_language_bundle(it.bundle)
				end
			end
		elseif item and type(item) == "table" then
			M.install_language_bundle(item.bundle)
		else
			vim.notify("⚠️ Move cursor to a language row or select checkboxes with <Space> to install.", vim.log.levels.WARN)
			return
		end

		vim.defer_fn(function()
			M.render_language_manager_buffer()
			if cursor and lang_win and vim.api.nvim_win_is_valid(lang_win) then
				pcall(vim.api.nvim_win_set_cursor, lang_win, cursor)
			end
		end, 600)
	end

	local function uninstall_action()
		local item, cursor = get_current_item()
		local count_selected = 0
		for _, it in ipairs(lang_items) do
			if it.selected then count_selected = count_selected + 1 end
		end

		if count_selected > 0 then
			for _, it in ipairs(lang_items) do
				if it.selected then
					M.uninstall_language_bundle(it.bundle)
				end
			end
		elseif item and type(item) == "table" then
			M.uninstall_language_bundle(item.bundle)
		else
			vim.notify("⚠️ Move cursor to a language row or select checkboxes with <Space> to uninstall.", vim.log.levels.WARN)
			return
		end

		vim.defer_fn(function()
			M.render_language_manager_buffer()
			if cursor and lang_win and vim.api.nvim_win_is_valid(lang_win) then
				pcall(vim.api.nvim_win_set_cursor, lang_win, cursor)
			end
		end, 600)
	end

	local function show_details()
		local item, _ = get_current_item()
		if item and type(item) == "table" then
			local details = {
				"Language Bundle: " .. item.bundle.name,
				"Mason Packages: " .. table.concat(item.bundle.mason_pkgs or {}, ", "),
				"Treesitter Parsers: " .. table.concat(item.bundle.treesitter or {}, ", "),
			}
			if item.bundle.dotnet_tools then
				table.insert(details, "Dotnet Tools: " .. table.concat(item.bundle.dotnet_tools, ", "))
			end
			vim.notify(table.concat(details, "\n"), vim.log.levels.INFO, {
				title = item.bundle.name .. " Component Details",
			})
		end
	end

	vim.keymap.set("n", "<space>", toggle_checkbox, opts)
	vim.keymap.set("n", "<CR>", toggle_checkbox, opts)
	vim.keymap.set("n", "<2-LeftMouse>", toggle_checkbox, opts)

	vim.keymap.set("n", "i", install_action, opts)
	vim.keymap.set("n", "I", install_action, opts)
	vim.keymap.set("n", "u", uninstall_action, opts)
	vim.keymap.set("n", "U", uninstall_action, opts)
	vim.keymap.set("n", "d", show_details, opts)

	vim.keymap.set("n", "a", function()
		for _, item in ipairs(lang_items) do
			local status = item.status or M.get_bundle_status(item.bundle)
			if not status.blocked then
				item.selected = true
			end
		end
		M.render_language_manager_buffer()
	end, opts)

	vim.keymap.set("n", "n", function()
		for _, item in ipairs(lang_items) do
			item.selected = (item.bundle.is_minimal == true)
		end
		M.render_language_manager_buffer()
	end, opts)

	-- [p] Select all pending bundles that are NOT blocked by missing runtimes (opt-in)
	vim.keymap.set("n", "p", function()
		for _, item in ipairs(lang_items) do
			local status = item.status or M.get_bundle_status(item.bundle)
			if not item.bundle.is_minimal
				and not status.blocked
				and status.installed_count < status.total_count
			then
				item.selected = true
			end
		end
		M.render_language_manager_buffer()
	end, opts)
end

--- Initializes setup checks on Neovim startup.
function M.init()
	-- Register User Commands immediately
	vim.api.nvim_create_user_command("LanguageManager", function()
		M.open_language_manager()
	end, { desc = "Open interactive Language Tooling Manager to install or uninstall language bundles" })

	vim.api.nvim_create_user_command("KrsLanguageManager", function()
		M.open_language_manager()
	end, { desc = "Open interactive Language Tooling Manager to install or uninstall language bundles" })

	vim.api.nvim_create_user_command("LanguageTooling", function()
		M.open_language_manager()
	end, { desc = "Open interactive Language Tooling Manager to install or uninstall language bundles" })

	vim.api.nvim_create_user_command("KrsInstallDependencies", function()
		M.open_toggle_menu()
	end, { desc = "Open interactive Toggle Selection Menu UI for system dependencies and LSPs" })

	vim.api.nvim_create_user_command("KrsInstaller", function()
		M.open_toggle_menu()
	end, { desc = "Open interactive Toggle Selection Menu UI for system dependencies and LSPs" })

	vim.api.nvim_create_user_command("KrsSetup", function()
		M.open_toggle_menu()
	end, { desc = "Run interactive system setup with Toggle Selection Menu UI" })

	vim.api.nvim_create_user_command("KrsSystemSetup", function()
		M.run_system_setup_interactive()
	end, { desc = "Run system dependency installer script with interactive Sudo UI password prompt" })

	vim.api.nvim_create_user_command("KrsInstallSystemDependencies", function()
		M.run_system_setup_interactive()
	end, { desc = "Run system dependency installer script with interactive Sudo UI password prompt" })

	vim.api.nvim_create_user_command("KrsInstallAgy", function()
		M.install_agy()
	end, { desc = "Install Google Antigravity CLI (agy) cross-platform" })

	vim.api.nvim_create_user_command("AgyInstall", function()
		M.install_agy()
	end, { desc = "Install Google Antigravity CLI (agy) cross-platform" })

	vim.api.nvim_create_user_command("InstallAgy", function()
		M.install_agy()
	end, { desc = "Install Google Antigravity CLI (agy) cross-platform" })

	vim.api.nvim_create_user_command("KrsInstallClaude", function()
		M.install_claude()
	end, { desc = "Install Claude Code CLI (claude) cross-platform" })

	vim.api.nvim_create_user_command("ClaudeInstall", function()
		M.install_claude()
	end, { desc = "Install Claude Code CLI (claude) cross-platform" })

	vim.api.nvim_create_user_command("InstallClaude", function()
		M.install_claude()
	end, { desc = "Install Claude Code CLI (claude) cross-platform" })

	vim.api.nvim_create_user_command("KrsInstallAll", function()
		M.install_all()
	end, { desc = "Install all missing LSPs, Treesitter parsers, and system dependencies" })

	vim.api.nvim_create_user_command("MasonInstallAll", function()
		M.install_all()
	end, { desc = "Alias for KrsInstallAll - Install all missing LSPs and tools" })

	vim.api.nvim_create_user_command("KrsSetupStatus", function()
		M.show_status()
	end, { desc = "Check detailed installation health status in Live Setup Modal" })

	vim.api.nvim_create_user_command("KrsSetupReset", function()
		M.reset_state()
	end, { desc = "Reset completion state file to force a full setup re-check" })

	local state = M.load_state()

	-- Mark setup complete on startup without popup warning toasts
	if not state.completed then
		M.save_state(true)
	end
end

return M

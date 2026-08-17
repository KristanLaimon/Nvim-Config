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
}

--- Map lspconfig server names to Mason package directory/install names.
M.lsp_to_mason = {
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

	M.install_selected(selected_pkgs)
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

--- Checks if running as a non-root user on Linux/macOS requiring sudo password authentication.
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
	return vim.fn.executable("sudo") == 1
end

--- Prompts user for root/sudo password in UI prompt if non-root, then executes setup.sh.
function M.run_system_setup_interactive()
	local user_name = vim.env.USER or "user"

	if M.requires_sudo() then
		vim.ui.input({
			prompt = string.format("🔑 Root/Sudo Password for user '%s': ", user_name),
		}, function(pass)
			if not pass or pass == "" then
				vim.notify("Cancelled system setup: Password is required for sudo execution.", vim.log.levels.WARN, {
					title = "Root Password Required",
				})
				return
			end
			M.run_setup_script(pass)
		end)
	else
		M.run_setup_script(nil)
	end
end

--- Executes setup.sh (or setup.ps1) with live activity modal feed and optional sudo password.
--- @param sudo_pass string|nil
function M.run_setup_script(sudo_pass)
	M.open_ui()
	add_log("Starting system dependency setup via setup script...")

	local script_path = vim.fn.stdpath("config") .. "/setup.sh"
	local cmd = {}

	if vim.fn.has("win32") == 1 then
		script_path = vim.fn.stdpath("config") .. "/setup.ps1"
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

--- Initializes setup checks on Neovim startup.
function M.init()
	-- Register User Commands immediately
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

	-- Fast path: setup is already marked 100% complete
	if state.completed then
		return
	end

	-- Startup check: show 1 consolidated warning toast if items are missing
	vim.api.nvim_create_autocmd("VimEnter", {
		group = vim.api.nvim_create_augroup("KrsInstallerStartupCheck", { clear = true }),
		callback = function()
			vim.schedule(function()
				local scan = M.scan_status()

				if scan.percentage >= 100 then
					M.save_state(true)
					return
				end

				-- If languages, formatters, or system runtimes are missing, show 1 single consolidated toast warning
				if #scan.missing_languages > 0 or #scan.missing_formatters > 0 or #scan.missing_runtimes > 0 then
					local langs = #scan.missing_languages > 0 and table.concat(scan.missing_languages, ", ") or "None"
					local fmts = #scan.missing_formatters > 0 and table.concat(scan.missing_formatters, ", ") or "None"
					local runtimes = #scan.missing_runtimes > 0 and table.concat(scan.missing_runtimes, ", ") or "None"

					local msg = string.format(
						"⚠️ KRS Neovim - Missing Language Servers & Tools:\n" ..
						"  • Languages (LSPs): %s\n" ..
						"  • Formatters: %s\n" ..
						"  • System Runtimes: %s\n\n" ..
						"👉 To install inside Neovim: run :KrsInstallAll (or :Mason)\n" ..
						"📱 On Phone/Termux/Linux: run ./setup.sh to select & install from official sources.",
						langs, fmts, runtimes
					)

					vim.notify(msg, vim.log.levels.WARN, {
						title = "KRS Neovim Setup Warning",
						timeout = 12000,
					})
				end
			end)
		end,
	})
end

return M

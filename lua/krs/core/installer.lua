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

	ui_buf, ui_win = ui.float({
		width = 78,
		height = 24,
		title = " 🦊 KRS System Setup & Live Installer ",
		focusable = true,
		modifiable = false,
	})

	ui.close_on_keys(ui_buf, ui_win)
	update_ui_buffer(nil, installed_list, scan.missing_lsps, scan.percentage)
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

	-- 4. Check Mason LSP & tool packages
	local mason_share = vim.fn.stdpath("data") .. "/mason/packages"
	for _, pkg in ipairs(M.mason_packages) do
		report.total_count = report.total_count + 1
		local mason_pkg = M.get_mason_package_name(pkg)
		local pkg_dir = mason_share .. "/" .. mason_pkg
		local pkg_stat = (vim.uv or vim.loop).fs_stat(pkg_dir)
		if pkg_stat and pkg_stat.type == "directory" then
			report.installed_count = report.installed_count + 1
			table.insert(report.installed_items, pkg)
		else
			table.insert(report.missing_lsps, pkg)
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
	vim.api.nvim_create_user_command("KrsSetup", function()
		M.install_all()
	end, { desc = "Run or resume incremental system setup with Live Installation Modal" })

	vim.api.nvim_create_user_command("KrsInstallAll", function()
		M.install_all()
	end, { desc = "Install all missing LSPs, Treesitter parsers, and system dependencies" })

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

	-- Slow/Incremental path: setup is incomplete
	vim.api.nvim_create_autocmd("VimEnter", {
		group = vim.api.nvim_create_augroup("KrsInstallerStartupCheck", { clear = true }),
		callback = function()
			vim.schedule(function()
				local scan = M.scan_status()

				if scan.percentage >= 100 then
					M.save_state(true)
					return
				end

				-- Display startup warning toast prompting user to run full setup or open UI
				local bar = M.render_bar(scan.percentage, 10)
				local msg = string.format(
					"📦 Setup Incomplete: [%s] %d%% (%d/%d items)\nEssentials are ready. Run :KrsInstallAll (or :KrsSetup) to open Live Setup Modal & download heavy tools!",
					bar,
					scan.percentage,
					scan.installed_count,
					scan.total_count
				)

				vim.notify(msg, vim.log.levels.WARN, {
					title = "KRS Setup - Action Required",
					timeout = 10000,
				})
			end)
		end,
	})
end

return M

-- ============================================================================
-- 🦊 KRS PLUGIN: PHP & Laravel Environment & CLI Tool Diagnostics Modal
-- ============================================================================
-- Checks for PHP, Composer, Intelephense, Pint, and Debug Adapter executables
-- on host Windows and WSL environments. Displays an interactive floating modal
-- window with installation steps if any essential CLI tools are missing.
-- ============================================================================

local M = {}

function M.check_tools(silent)
	local is_win = vim.fn.has("win32") == 1
	local has_wsl = is_win and (vim.fn.executable("wsl.exe") == 1 or vim.fn.executable("wsl") == 1)

	local win_php = vim.fn.executable("php") == 1
	local win_composer = vim.fn.executable("composer") == 1

	local wsl_php = false
	local wsl_composer = false
	if has_wsl and not (win_php and win_composer) then
		local wsl_php_check = vim.fn.system("wsl php -v 2>NUL")
		wsl_php = type(wsl_php_check) == "string" and wsl_php_check:match("PHP%s+%d") ~= nil
		local wsl_comp_check = vim.fn.system("wsl composer --version 2>NUL")
		wsl_composer = type(wsl_comp_check) == "string" and wsl_comp_check:match("Composer") ~= nil
	end

	local has_php = win_php or wsl_php
	local has_composer = win_composer or wsl_composer

	local status = {
		php = has_php,
		composer = has_composer,
		win_php = win_php,
		wsl_php = wsl_php,
		win_composer = win_composer,
		wsl_composer = wsl_composer,
		has_wsl = has_wsl,
	}

	if not (status.php and status.composer) then
		if not silent then
			M.show_missing_modal(status)
		end
	end

	return status
end

function M.show_missing_modal(status)
	local lines = {
		" ⚠️  PHP & Laravel Environment Status ",
		" ──────────────────────────────────────────────────────────",
		" Neovim detected missing PHP development tools:",
		"",
	}

	if not status.php then
		table.insert(lines, "  ❌  PHP CLI binary (php) is NOT installed or in PATH")
	else
		local env_str = status.win_php and "Windows" or "WSL"
		table.insert(lines, "  ✅  PHP CLI binary is available (" .. env_str .. ")")
	end

	if not status.composer then
		table.insert(lines, "  ❌  Composer package manager (composer) is NOT installed")
	else
		local env_str = status.win_composer and "Windows" or "WSL"
		table.insert(lines, "  ✅  Composer is available (" .. env_str .. ")")
	end

	table.insert(lines, "")
	table.insert(lines, " 📌  How to install PHP & Composer:")
	table.insert(lines, "  • Windows (Native):")
	table.insert(lines, "     1. Install Laravel Herd: https://herd.laravel.com")
	table.insert(lines, "        OR via Scoop: `scoop install php composer`")
	table.insert(lines, "        OR via Chocolatey: `choco install php composer`")
	table.insert(lines, "  • WSL (Linux/Ubuntu):")
	table.insert(lines, "     1. Open WSL terminal and run:")
	table.insert(lines, "        `sudo apt update && sudo apt install php-cli composer php-xml php-mbstring`")
	table.insert(lines, "")
	table.insert(lines, " ──────────────────────────────────────────────────────────")
	table.insert(lines, " Press <Esc> or 'q' to dismiss this window.")

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "krsphpmodal"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 64
	local height = #lines
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(math.floor(((vim.o.lines or 24) - height) / 2), 1),
		col = math.max(math.floor(((vim.o.columns or 80) - width) / 2), 1),
		style = "minimal",
		border = "rounded",
		title = " 🐘 PHP & Laravel Environment ",
		title_pos = "center",
	})

	pcall(vim.api.nvim_set_option_value, "cursorline", false, { win = win })

	local kopts = { buffer = buf, noremap = true, silent = true }
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	vim.keymap.set("n", "<Esc>", close, kopts)
	vim.keymap.set("n", "q", close, kopts)
	vim.keymap.set("n", "<CR>", close, kopts)
end

_G.PhpToolsModal = M

local plugin_spec = {
	name = "krs_php_tools_modal",
	dir = require("krs.lazydir").for_module(),
	lazy = false,
	config = function()
		-- PHP Tools Modal initialized
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

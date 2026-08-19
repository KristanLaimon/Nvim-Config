-- ============================================================================
-- 🦊 run_me.lua -- Master CLI Runner for KRSNVIM Scripts (Pure Lua)
-- ============================================================================

local root = vim.fn.stdpath("config")
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

-- Explicit krsnvimscript library imports
local cli = require("krsnvim.cli")
local terminal = require("krsnvim.terminal")
local console = require("krsnvim.console")

local schema = {
	name = "run_me",
	description = "Master CLI to run KRSNVIM setup, tests, syntax check, and utility scripts.",
	options = {
		["tests"] = "Run project test suite (run_tests)",
		["syntax"] = "Run syntax check on all Lua files (run_sintaxcheck)",
		["setup"] = "Run dependency setup script (setup.ps1 / setup.sh)",
		["setup-ps"] = "Configure Windows Terminal keymaps (setup-powershell.ps1)",
		["unsetup-ps"] = "Restore Windows Terminal keymaps (unsetup-powershell.ps1)",
		["example"] = "Run example script (example.krsnvim)",
		["help"] = "Show this CLI help screen",
	},
}

local function run_tests()
	console.log("[run_me] Running Test Suite...")
	_G.arg = {}
	dofile(root .. "/tests/run.lua")
end

local function run_syntax()
	console.log("[run_me] Running Syntax Check...")
	dofile(root .. "/tests/syntax_check.lua")
end

local function run_setup()
	console.log("[run_me] Running Setup Dependencies...")
	if vim.fn.has("win32") == 1 then
		terminal.run("powershell.exe -ExecutionPolicy Bypass -File " .. vim.fn.shellescape(root .. "/scripts/setup.ps1"))
	else
		terminal.run("bash " .. vim.fn.shellescape(root .. "/scripts/setup.sh"))
	end
end

local function run_setup_ps()
	console.log("[run_me] Setting up Windows Terminal Keymaps...")
	terminal.run(
		"powershell.exe -ExecutionPolicy Bypass -File " .. vim.fn.shellescape(root .. "/scripts/setup-powershell.ps1")
	)
end

local function run_unsetup_ps()
	console.log("[run_me] Restoring Windows Terminal Keymaps...")
	terminal.run(
		"powershell.exe -ExecutionPolicy Bypass -File " .. vim.fn.shellescape(root .. "/scripts/unsetup-powershell.ps1")
	)
end

local function run_example()
	console.log("[run_me] Running Example Script...")
	dofile(root .. "/scripts/example.krsnvim")
end

local function show_menu()
	local options = {
		"Run Test Suite (tests/run.lua)",
		"Run Syntax Check (tests/syntax_check.lua)",
		"Run Setup Dependencies (setup.ps1 / setup.sh)",
		"Setup Windows Terminal Keymaps (setup-powershell.ps1)",
		"Unsetup Windows Terminal Keymaps (unsetup-powershell.ps1)",
		"Run Example Script (scripts/example.krsnvim)",
		"Exit",
	}

	cli.menu({ title = "KRSNVIM", subtitle = "Master CLI Script Runner", items = options }, function(choice, idx)
		if idx == 1 then
			run_tests()
		elseif idx == 2 then
			run_syntax()
		elseif idx == 3 then
			run_setup()
		elseif idx == 4 then
			run_setup_ps()
		elseif idx == 5 then
			run_unsetup_ps()
		elseif idx == 6 then
			run_example()
		else
			print(cli.colorize("Exiting run_me CLI.", cli.colors.yellow))
		end
	end)
end

-- Parse CLI Flags
local raw_args = arg or {}
local parsed = cli.parse_args(raw_args, schema)

if parsed.flags.help or parsed.flags.h then
	print(cli.help(schema))
elseif parsed.flags.tests or parsed.flags.t then
	run_tests()
elseif parsed.flags.syntax or parsed.flags.s then
	run_syntax()
elseif parsed.flags.setup then
	run_setup()
elseif parsed.flags["setup-ps"] then
	run_setup_ps()
elseif parsed.flags["unsetup-ps"] then
	run_unsetup_ps()
elseif parsed.flags.example or parsed.flags.e then
	run_example()
else
	show_menu()
end

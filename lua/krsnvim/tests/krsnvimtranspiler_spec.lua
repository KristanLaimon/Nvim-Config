local M = {}

function M.run()
	local transpiler = require("krsnvim.krsnvimtranspiler")

	-- Test 1: Function transpilation & parameters
	local fn_code = 'function deploy(target, verbose)\nprint("Deploying:", target)\nend'
	local sh_fn = transpiler.to_sh(fn_code)
	local ps1_fn = transpiler.to_ps1(fn_code)
	assert(sh_fn:find("deploy() {", 1, true), "Bash function declaration missing")
	assert(sh_fn:find('local target="$1"', 1, true), "Bash param $1 missing")
	assert(ps1_fn:find("function deploy($target, $verbose) {", 1, true), "PS1 function declaration missing")

	-- Test 2: Advanced loops (while, for i, ipairs)
	local loop_code = 'for i = 1, 5 do\nprint(i)\nend\nfor _, item in ipairs(items) do\nprint(item)\nend'
	local sh_loop = transpiler.to_sh(loop_code)
	local ps1_loop = transpiler.to_ps1(loop_code)
	assert(sh_loop:find("for ((i=1; i<=5; i++)); do", 1, true), "Bash numeric for loop missing")
	assert(sh_loop:find('for item in "${items[@]}"; do', 1, true), "Bash ipairs loop missing")
	assert(ps1_loop:find("for ($i = 1; $i -le 5; $i++) {", 1, true), "PS1 numeric for loop missing")
	assert(ps1_loop:find("foreach ($item in $items) {", 1, true), "PS1 foreach loop missing")

	-- Test 3: Assertions & Errors
	local err_code = 'assert(fs.exists("config.json"), "Config missing")\nerror("Fatal stop")'
	local sh_err = transpiler.to_sh(err_code)
	local ps1_err = transpiler.to_ps1(err_code)
	assert(sh_err:find('[ fs.exists("config.json") ] || { echo "Config missing" >&2; exit 1; }', 1, true), "Bash assert missing")
	assert(sh_err:find('echo "Fatal stop" >&2', 1, true), "Bash error missing")
	assert(ps1_err:find('if (-not (fs.exists("config.json"))) { throw "Config missing" }', 1, true), "PS1 assert missing")
	assert(ps1_err:find('throw "Fatal stop"', 1, true), "PS1 throw missing")

	print("  ✓ krsnvim.krsnvimtranspiler spec passed")
end

return M

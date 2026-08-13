local M = {}

local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

local function run_cmd(cmd_str, opts)
	opts = opts or {}
	if type(cmd_str) == "table" then
		cmd_str = table.concat(cmd_str, " ")
	end

	local shell_cmd
	if is_windows then
		shell_cmd = { "cmd.exe", "/C", cmd_str }
	else
		shell_cmd = { "bash", "-c", cmd_str }
	end

	local stdout = vim.fn.system(shell_cmd)
	local exit_code = vim.v.shell_error

	return {
		code = exit_code,
		ok = (exit_code == 0),
		stdout = stdout or "",
		stderr = "",
		output = stdout or "",
	}
end

setmetatable(M, {
	__call = function(_, cmd_str, opts)
		return run_cmd(cmd_str, opts)
	end,
})

M.exec = run_cmd
M.run = run_cmd
M.is_windows = is_windows

function M.cwd()
	return vim.fn.getcwd()
end

function M.echo(msg)
	print(msg)
end

return M

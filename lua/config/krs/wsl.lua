-- ============================================================================
-- 🦊 KRS CONFIG: WSL (Windows Subsystem for Linux) Detection & Helpers
-- ============================================================================
-- 1. Detects WSL availability on Windows hosts.
-- 2. Lists installed distros via `wsl.exe -l -q`.
-- 3. Parses `\\wsl.localhost\<Distro>\...` / `\\wsl$\<Distro>\...` UNC paths.
-- 4. Builds the `wsl.exe -d <Distro> --cd <linux-path>` launch command so the
--    integrated terminal drops into the right distro/dir automatically.
-- ============================================================================

local M = {}

function M.is_windows()
	return vim.fn.has("win32") == 1
end

function M.available()
	if not M.is_windows() then
		return false
	end
	return vim.fn.executable("wsl.exe") == 1 or vim.fn.executable("wsl") == 1
end

-- List installed WSL distro names.
-- `wsl.exe -l -q` prints UTF-16LE, and Neovim's system() mangles the NUL
-- high-bytes (turns embedded \0 into a stray control byte) rather than
-- stripping them, so naive gmatch splitting produces garbage/phantom
-- entries. Work around it by keeping only the low byte of each UTF-16 code
-- unit (safe since distro names are ASCII), which reconstructs plain text
-- regardless of what the high byte got mangled into.
function M.list_distros()
	if not M.available() then
		return {}
	end
	local out = vim.fn.system({ "wsl.exe", "-l", "-q" })
	if vim.v.shell_error ~= 0 then
		return {}
	end

	local chars = {}
	for i = 1, #out, 2 do
		local b = out:byte(i)
		if b then
			table.insert(chars, string.char(b))
		end
	end
	local text = table.concat(chars)

	local distros = {}
	for line in text:gmatch("[^\r\n]+") do
		line = line:gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then
			table.insert(distros, line)
		end
	end
	return distros
end

-- Parse a Windows path pointing into a WSL distro's filesystem.
-- Returns distro, linux_path or nil if the path is not a WSL UNC path.
function M.parse_wsl_path(path)
	if not path or path == "" then
		return nil
	end
	local p = path:gsub("\\", "/")
	local distro, rest = p:match("^//wsl%.localhost/([^/]+)(/.*)$")
	if not distro then
		distro, rest = p:match("^//wsl%$/([^/]+)(/.*)$")
	end
	if not distro then
		distro = p:match("^//wsl%.localhost/([^/]+)$") or p:match("^//wsl%$/([^/]+)$")
		rest = "/"
	end
	if distro then
		return distro, (rest ~= "" and rest or "/")
	end
	return nil
end

function M.is_wsl_path(path)
	return M.parse_wsl_path(path) ~= nil
end

-- UNC root path for a distro's filesystem, browsable like any local folder
function M.distro_root(distro)
	return "//wsl.localhost/" .. distro
end

-- Command to launch a WSL shell rooted at the given Windows cwd, or nil if
-- the cwd is not inside a WSL distro.
function M.shell_command_for_cwd(cwd)
	local distro, linux_path = M.parse_wsl_path(cwd)
	if not distro then
		return nil
	end
	return string.format("wsl.exe -d %s --cd %s", distro, vim.fn.shellescape(linux_path))
end

return M

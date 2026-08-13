local M = {}

function M.exists(path)
	if not path or path == "" then return false end
	return vim.fn.empty(vim.fn.glob(path)) == 0 or vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

function M.read(path)
	local f = io.open(path, "r")
	if not f then error("krsnvim.fs: Cannot read file: " .. tostring(path)) end
	local content = f:read("*a")
	f:close()
	return content
end

function M.write(path, content)
	local f = io.open(path, "w")
	if not f then error("krsnvim.fs: Cannot write file: " .. tostring(path)) end
	f:write(content or "")
	f:close()
	return true
end

function M.mkdir(path)
	if vim.fn.isdirectory(path) == 0 then
		return vim.fn.mkdir(path, "p") == 1
	end
	return true
end

function M.list(dir_path)
	return vim.fn.glob(dir_path .. "/*", false, true)
end

return M

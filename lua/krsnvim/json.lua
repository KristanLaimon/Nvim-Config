local M = {}

function M.decode(str)
	if not str or str == "" then
		return nil
	end
	local ok, res = pcall(vim.json.decode, str)
	if not ok then
		error("krsnvim.json: Error decoding JSON: " .. tostring(res))
	end
	return res
end

function M.encode(obj, opts)
	opts = opts or {}
	local ok, res = pcall(vim.json.encode, obj)
	if not ok then
		error("krsnvim.json: Error encoding JSON: " .. tostring(res))
	end
	return res
end

function M.load(filepath)
	local f = io.open(filepath, "r")
	if not f then
		error("krsnvim.json: Cannot open file: " .. tostring(filepath))
	end
	local content = f:read("*a")
	f:close()
	return M.decode(content)
end

function M.save(filepath, obj)
	local str = M.encode(obj)
	local f = io.open(filepath, "w")
	if not f then
		error("krsnvim.json: Cannot write file: " .. tostring(filepath))
	end
	f:write(str)
	f:close()
	return true
end

return M

local M = {}

local function parse_scalar(val)
	if not val then return nil end
	val = val:match("^%s*(.-)%s*$")
	if val == "true" then return true end
	if val == "false" then return false end
	local num = tonumber(val)
	if num then return num end
	if (val:sub(1, 1) == '"' and val:sub(-1) == '"') or (val:sub(1, 1) == "'" and val:sub(-1) == "'") then
		return val:sub(2, -2)
	end
	if val:sub(1, 1) == "[" and val:sub(-1) == "]" then
		local items = {}
		local inner = val:sub(2, -2)
		for item in inner:gmatch("[^,%s]+") do
			table.insert(items, parse_scalar(item))
		end
		return items
	end
	return val
end

function M.decode(str)
	if not str or str == "" then return {} end
	local root = {}
	local current_section = root

	for line in str:gmatch("[^\r\n]+") do
		local uncommented = line:match("^([^#]*)")
		if uncommented then
			local trimmed = uncommented:match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				local section = trimmed:match("^%[%s*([%w_%-%.]+)%s*%]$")
				if section then
					root[section] = root[section] or {}
					current_section = root[section]
				else
					local k, v = trimmed:match("^([%w_%-%.]+)%s*=%s*(.-)$")
					if k and v then
						current_section[k] = parse_scalar(v)
					end
				end
			end
		end
	end

	return root
end

function M.encode(obj)
	if not obj then return "" end
	local lines = {}
	local sections = {}

	for k, v in pairs(obj) do
		if type(v) == "table" then
			sections[k] = v
		else
			table.insert(lines, string.format("%s = %s", k, type(v) == "string" and ('"' .. v .. '"') or tostring(v)))
		end
	end

	for sec_name, sec_table in pairs(sections) do
		table.insert(lines, "\n[" .. sec_name .. "]")
		for k, v in pairs(sec_table) do
			table.insert(lines, string.format("%s = %s", k, type(v) == "string" and ('"' .. v .. '"') or tostring(v)))
		end
	end

	return table.concat(lines, "\n")
end

function M.load(filepath)
	local f = io.open(filepath, "r")
	if not f then
		error("krsnvim.toml: Cannot open file: " .. tostring(filepath))
	end
	local content = f:read("*a")
	f:close()
	return M.decode(content)
end

function M.save(filepath, obj)
	local str = M.encode(obj)
	local f = io.open(filepath, "w")
	if not f then
		error("krsnvim.toml: Cannot write file: " .. tostring(filepath))
	end
	f:write(str)
	f:close()
	return true
end

return M

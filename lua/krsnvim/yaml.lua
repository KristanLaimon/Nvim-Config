local M = {}

local function parse_scalar(val)
	if not val then return nil end
	val = val:match("^%s*(.-)%s*$")
	if val == "" or val == "~" or val:lower() == "null" then return nil end
	if val:lower() == "true" or val:lower() == "yes" then return true end
	if val:lower() == "false" or val:lower() == "no" then return false end
	local num = tonumber(val)
	if num then return num end
	if (val:sub(1, 1) == '"' and val:sub(-1) == '"') or (val:sub(1, 1) == "'" and val:sub(-1) == "'") then
		return val:sub(2, -2)
	end
	return val
end

function M.decode(str)
	if not str or str == "" then return {} end
	local lines = {}
	for line in str:gmatch("[^\r\n]+") do
		local uncommented = line:match("^([^#]*)")
		if uncommented and uncommented:find("%S") then
			table.insert(lines, uncommented)
		end
	end

	local function parse_lines(index, current_indent)
		local result = {}
		local is_array = false

		while index <= #lines do
			local line = lines[index]
			local indent = #(line:match("^(%s*)") or "")
			if indent < current_indent then
				break
			end

			local trimmed = line:match("^%s*(.-)%s*$")
			if trimmed:sub(1, 2) == "- " or trimmed == "-" then
				is_array = true
				local item_str = trimmed:sub(3)
				if item_str == "" then
					local item_val, next_idx = parse_lines(index + 1, indent + 2)
					table.insert(result, item_val)
					index = next_idx - 1
				else
					table.insert(result, parse_scalar(item_str))
				end
			else
				local key, rest = trimmed:match("^([%w_%-%.]+)%s*:%s*(.*)$")
				if key then
					if rest == "" then
						local child_val, next_idx = parse_lines(index + 1, indent + 2)
						result[key] = child_val
						index = next_idx - 1
					else
						result[key] = parse_scalar(rest)
					end
				end
			end
			index = index + 1
		end

		return result, index
	end

	local res, _ = parse_lines(1, 0)
	return res
end

local function dump_val(val, indent)
	local spaces = string.rep("  ", indent)
	local t = type(val)
	if t == "table" then
		local is_list = vim.islist and vim.islist(val) or (#val > 0)
		local out = {}
		if is_list then
			for _, v in ipairs(val) do
				if type(v) == "table" then
					table.insert(out, spaces .. "-\n" .. dump_val(v, indent + 1))
				else
					table.insert(out, spaces .. "- " .. tostring(v))
				end
			end
		else
			for k, v in pairs(val) do
				if type(v) == "table" then
					table.insert(out, spaces .. tostring(k) .. ":\n" .. dump_val(v, indent + 1))
				else
					table.insert(out, spaces .. tostring(k) .. ": " .. tostring(v))
				end
			end
		end
		return table.concat(out, "\n")
	elseif t == "boolean" or t == "number" then
		return tostring(val)
	else
		return tostring(val)
	end
end

function M.encode(obj)
	if not obj then return "" end
	return dump_val(obj, 0)
end

function M.load(filepath)
	local f = io.open(filepath, "r")
	if not f then
		error("krsnvim.yaml: Cannot open file: " .. tostring(filepath))
	end
	local content = f:read("*a")
	f:close()
	return M.decode(content)
end

function M.save(filepath, obj)
	local str = M.encode(obj)
	local f = io.open(filepath, "w")
	if not f then
		error("krsnvim.yaml: Cannot write file: " .. tostring(filepath))
	end
	f:write(str)
	f:close()
	return true
end

return M

local M = {}

function M.parse_args(raw_args, schema)
	raw_args = raw_args or arg or {}
	schema = schema or {}

	local parsed = {
		flags = {},
		positional = {},
	}

	for _, a in ipairs(raw_args) do
		if a:sub(1, 2) == "--" then
			local key, val = a:sub(3):match("^([^=]+)=(.*)$")
			if key then
				parsed.flags[key] = val
			else
				parsed.flags[a:sub(3)] = true
			end
		elseif a:sub(1, 1) == "-" and #a > 1 then
			parsed.flags[a:sub(2)] = true
		else
			table.insert(parsed.positional, a)
		end
	end

	return parsed
end

function M.help(schema)
	schema = schema or {}
	local lines = {}
	table.insert(lines, "Usage: " .. (schema.name or "krsnvimscript") .. " [options] [arguments]")
	if schema.description then
		table.insert(lines, "\n" .. schema.description .. "\n")
	end
	if schema.options then
		table.insert(lines, "Options:")
		for opt, desc in pairs(schema.options) do
			table.insert(lines, string.format("  --%-15s %s", opt, desc))
		end
	end
	return table.concat(lines, "\n")
end

function M.menu(title, options, callback)
	print("\n==========================================")
	print(" " .. (title or "Select an Option:"))
	print("==========================================")

	for i, opt in ipairs(options) do
		print(string.format("  [%d] %s", i, tostring(opt)))
	end
	print("==========================================")

	-- If running in interactive Neovim UI, use vim.ui.select
	if vim and vim.ui and vim.ui.select then
		vim.ui.select(options, { prompt = title }, function(choice, idx)
			if callback then
				callback(choice, idx)
			end
		end)
	else
		io.write("Select option (1-" .. #options .. "): ")
		local input = io.read()
		local choice_num = tonumber(input)
		if choice_num and options[choice_num] then
			if callback then
				callback(options[choice_num], choice_num)
			end
			return options[choice_num], choice_num
		else
			print("Invalid selection.")
		end
	end
end

return M

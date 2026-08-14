--- @module "krsnvim.cli"
--- CLI Argument Parsing, `--help` Generator, and Interactive Selection Menu Helper for `krsnvimscript`.
---
--- @example
--- local cli = import("krsnvim.cli")
--- local args = cli.parse_args({ "--env=production", "--verbose", "build" })
--- print(args.flags.env)     -- "production"
--- print(args.flags.verbose) -- true
--- print(args.positional[1]) -- "build"
local M = {}

--- @class ParsedArgs
--- @field flags table<string, string|boolean> Map of `--flag` or `--key=value` parsed options.
--- @field positional string[] List of positional non-flag command line arguments.

--- Parses raw CLI arguments into flags (named options) and positional arguments.
--- Supports `--key=value`, `--flag` (`true`), `-f` (`true`), and raw positional strings.
---
--- @param raw_args string[]|nil Array of raw argument strings. Defaults to `arg` or `{}`.
--- @param schema table|nil Optional schema definition for flag validation.
--- @return ParsedArgs parsed Parsed flags and positional arguments structure.
---
--- @note Edge Cases:
--- - `--key=val` parses `key` with string value `"val"`.
--- - `--flag` parses `flag` with boolean value `true`.
--- - `-v` parses `v` with boolean value `true`.
--- - Positional values preserve original array ordering.
---
--- @see krsnvim.cli.help
--- @see krsnvim.cli.menu
---
--- @example
--- local args = cli.parse_args(arg)
--- if args.flags.help then
---     print(cli.help({ name = "mytool", description = "My CLI tool" }))
--- end
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

--- Generates a formatted `--help` text output string based on a CLI schema definition.
---
--- @param schema table Schema configuration specifying `name`, `description`, and `options`.
--- @return string help_text Formatted help document text.
---
--- @see krsnvim.cli.parse_args
---
--- @example
--- local help_doc = cli.help({
---     name = "build-script",
---     description = "Compiles project assets into dist/",
---     options = {
---         env = "Target environment (development|production)",
---         minify = "Enable code minification"
---     }
--- })
--- print(help_doc)
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

--- Displays an interactive numerical selection menu in terminal or Neovim UI (`vim.ui.select`).
---
--- @param title string Header title for the menu.
--- @param options string[] Array list of selectable text options.
--- @param callback function|nil Callback function `callback(choice, index)` invoked upon selection.
--- @return string|nil choice Selected text option (when synchronous in terminal).
--- @return number|nil index Selected option index 1-N (when synchronous in terminal).
---
--- @note Edge Cases:
--- - In Neovim GUI/TUI, uses `vim.ui.select` (Telescope / Dressing floating picker).
--- - In standalone Lua scripts, falls back to `io.read()` stdout/stdin selection.
---
--- @see krsnvim.cli.parse_args
---
--- @example
--- cli.menu("Choose Target Framework", { "React", "Vue", "Svelte" }, function(choice, idx)
---     print("Selected framework:", choice)
--- end)
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

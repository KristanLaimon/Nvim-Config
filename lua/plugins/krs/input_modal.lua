-- ============================================================================
-- 🦊 KRS PLUGIN: Reusable Floating Input / Rename Modal Box
-- ============================================================================
-- Component props / options:
--   opts = {
--     label = "Rename",             -- Modal title label (string)
--     title = "Rename",             -- Alias for label
--     default_value = "current",    -- Initial text content (string)
--     default = "current",          -- Alias for default_value
--     relative = "editor"|"cursor", -- Window anchoring (default: "editor")
--     callback = function(ok, new_text) end -- Callback function
--   }
-- ============================================================================

local M = {}

function M.open(opts)
	opts = opts or {}
	local label = opts.label or opts.title or opts.prompt or "Input"
	label = label:gsub("^%s*", ""):gsub(":%s*$", "")

	local default_val = opts.default_value or opts.default or ""
	local callback = opts.callback or function() end
	local relative = opts.relative or "editor"

	local orig_win = vim.api.nvim_get_current_win()

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "krsinputmodal"
	vim.b[buf].completion = false
	vim.api.nvim_buf_set_name(buf, "Input: " .. label)

	local lines = vim.split(default_val, "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local function recalculate_dimensions(cur_lines)
		local cols = vim.o.columns or 80
		local lines_count = vim.o.lines or 24
		local max_allowed_width = math.max(30, math.floor(cols * 0.70))
		local min_width = math.min(math.max(#label + 10, 36), max_allowed_width)

		local max_line_len = 0
		for _, l in ipairs(cur_lines) do
			if #l > max_line_len then
				max_line_len = #l
			end
		end

		local new_w = math.min(math.max(max_line_len + 6, min_width), max_allowed_width)

		local display_height = 0
		for _, l in ipairs(cur_lines) do
			if #l == 0 then
				display_height = display_height + 1
			else
				display_height = display_height + math.ceil(#l / math.max(new_w, 1))
			end
		end

		local max_allowed_height = math.max(3, math.floor(lines_count * 0.70))
		local new_h = math.min(math.max(display_height, 1), max_allowed_height)

		local new_row = math.max(0, math.floor((lines_count - (new_h + 2)) / 2))
		local new_col = math.max(0, math.floor((cols - (new_w + 2)) / 2))

		return new_w, new_h, new_row, new_col
	end

	local width, height, row, col = recalculate_dimensions(lines)

	local win_opts = {
		relative = relative,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " 📝 " .. label .. " ",
		title_pos = "center",
	}

	if relative == "cursor" then
		win_opts.row = 1
		win_opts.col = 0
	else
		win_opts.relative = "editor"
		win_opts.row = row
		win_opts.col = col
	end

	local win = vim.api.nvim_open_win(buf, true, win_opts)
	pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
	pcall(vim.api.nvim_set_option_value, "linebreak", true, { win = win })
	pcall(vim.api.nvim_set_option_value, "scrolloff", 0, { win = win })
	pcall(vim.api.nvim_set_option_value, "cursorline", false, { win = win })

	vim.cmd("startinsert!")

	local finished = false

	local function close_win()
		-- <CR> confirms from insert mode, but closing the float does not leave it:
		-- focus returns to the caller's buffer still in insert, which moves the cursor
		-- and fires blink.cmp there. Leave insert before giving the window back.
		vim.cmd("stopinsert")
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(function()
				vim.bo[buf].modified = false
			end)
		end
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
		if vim.api.nvim_win_is_valid(orig_win) then
			pcall(vim.api.nvim_set_current_win, orig_win)
		end
	end

	local function confirm()
		if finished then
			return
		end
		finished = true
		local text_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local result_text = table.concat(text_lines, "\n")
		close_win()
		callback(true, result_text)
	end

	local function cancel()
		if finished then
			return
		end
		finished = true
		close_win()
		callback(false, "")
	end

	-- Dynamic resizing on text change
	local function resize()
		if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local cur_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local new_w, new_h, new_row, new_col = recalculate_dimensions(cur_lines)
		local new_config = { width = new_w, height = new_h }
		if relative == "editor" then
			new_config.relative = "editor"
			new_config.row = new_row
			new_config.col = new_col
		end
		pcall(vim.api.nvim_win_set_config, win, new_config)
		pcall(vim.api.nvim_win_call, win, function()
			vim.fn.winrestview({ topline = 1 })
		end)
	end

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
		buffer = buf,
		callback = resize,
	})

	local kopts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set({ "n", "i" }, "<CR>", confirm, kopts)

	local function insert_newline()
		if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local cursor = vim.api.nvim_win_get_cursor(win)
		local row, col = cursor[1], cursor[2]
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		local before = line:sub(1, col)
		local after = line:sub(col + 1)
		vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { before, after })
		local new_row = row + 1
		vim.api.nvim_win_set_cursor(win, { new_row, 0 })
		resize()
		pcall(vim.api.nvim_win_call, win, function()
			vim.fn.winrestview({ topline = 1 })
		end)
	end

	vim.keymap.set({ "n", "i" }, "<S-CR>", insert_newline, kopts)
	vim.keymap.set({ "n", "i" }, "<S-Enter>", insert_newline, kopts)
	vim.keymap.set({ "n", "i" }, "<M-CR>", insert_newline, kopts)

	vim.keymap.set("i", "<Esc>", "<Cmd>stopinsert<CR>", kopts)
	vim.keymap.set("n", "<Esc>", cancel, kopts)
	vim.keymap.set("n", "q", cancel, kopts)
	vim.keymap.set("n", "<C-c>", cancel, kopts)

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			confirm()
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			if not finished then
				finished = true
				if vim.api.nvim_buf_is_valid(buf) then
					pcall(function()
						vim.bo[buf].modified = false
					end)
				end
				callback(false, "")
			end
		end,
	})
end

-- Override default vim.ui.input to use our reusable modal
function M.setup_ui_input_override()
	vim.ui.input = function(opts, on_confirm)
		opts = opts or {}
		M.open({
			label = opts.prompt or "Input",
			default_value = opts.default or "",
			relative = "editor",
			callback = function(ok, new_text)
				if ok then
					on_confirm(new_text)
				else
					on_confirm(nil)
				end
			end,
		})
	end
end

_G.InputModal = M

M.setup_ui_input_override()

-- Plugin specification for Lazy.nvim
local plugin_spec = {
	name = "krs_input_modal",
	dir = require("lazyscripts.lazydir").for_module(),
	lazy = false,
	config = function()
		M.setup_ui_input_override()
	end,
}

return setmetatable(plugin_spec, {
	__index = M,
})

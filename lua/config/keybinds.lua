-- GLOBAL CONFIG
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

-- VSCode Migration (Old habits never die)
vim.keymap.set("n", "<C-_>", "gcc", { remap = true, desc = "Comment line" })
vim.keymap.set("v", "<C-_>", "gc", { remap = true, desc = "Comment selection" })

-- QOL Features
vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, desc = "Copy to clipboard" })

-- Movements across panels
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Ir a la ventana izquierda" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Ir a la ventana derecha" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Ir a la ventana de abajo" })
-- vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })

-- Errors
vim.keymap.set("n", "<leader>k", vim.diagnostic.open_float, { desc = "Ver info del error" })
vim.keymap.set("n", "<leader>u", vim.diagnostic.goto_prev, { desc = "Error anterior" })
vim.keymap.set("n", "<leader>o", vim.diagnostic.goto_prev, { desc = "Siguiente error" })

vim.keymap.set("n", "<leader>f", function()
	vim.lsp.buf.format()
end, { desc = "Format file" })

local function Configure_Terminal_Toggle()
	-- ============================================================
	-- Toggle Terminal
	-- ============================================================
	local term_buf = nil
	local term_win = nil
	local code_win = nil

	local function is_valid_win(win)
		return win and vim.api.nvim_win_is_valid(win)
	end

	local function is_valid_buf(buf)
		return buf and vim.api.nvim_buf_is_valid(buf)
	end

	function ToggleTerminal()
		-- Window may have been closed
		if term_win and not is_valid_win(term_win) then
			term_win = nil
		end

		local current = vim.api.nvim_get_current_win()

		------------------------------------------------------------------
		-- Currently in terminal -> return to editor
		------------------------------------------------------------------
		if is_valid_win(term_win) and current == term_win then
			vim.cmd("stopinsert")

			if is_valid_win(code_win) then
				vim.api.nvim_set_current_win(code_win)
			else
				vim.cmd("wincmd p")
			end

			return
		end

		------------------------------------------------------------------
		-- Remember editor window
		------------------------------------------------------------------
		code_win = current

		------------------------------------------------------------------
		-- Terminal already visible
		------------------------------------------------------------------
		if is_valid_win(term_win) then
			vim.api.nvim_set_current_win(term_win)
			vim.cmd("startinsert")
			return
		end

		------------------------------------------------------------------
		-- Create terminal window
		------------------------------------------------------------------
		vim.cmd("botright 7split")
		term_win = vim.api.nvim_get_current_win()

		if is_valid_buf(term_buf) then
			vim.api.nvim_win_set_buf(term_win, term_buf)
		else
			vim.cmd("terminal")
			term_buf = vim.api.nvim_get_current_buf()
		end

		vim.cmd("startinsert")
	end

	function HideTerminal()
		if is_valid_win(term_win) then
			vim.api.nvim_win_close(term_win, true)
			term_win = nil
		end
	end

	-- ============================================================
	-- Keymaps
	-- ============================================================

	-- Toggle terminal
	vim.keymap.set("n", "<leader>t", ToggleTerminal, {
		noremap = true,
		silent = true,
		desc = "Toggle Terminal",
	})

	vim.keymap.set("t", "<leader>t", function()
		vim.cmd("stopinsert")
		ToggleTerminal()
	end, {
		noremap = true,
		silent = true,
		desc = "Toggle Terminal",
	})

	-- Make Ctrl+W work naturally inside terminal mode
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], {
		noremap = true,
		silent = true,
	})

	-- Close current window with Ctrl+Shift+W
	vim.keymap.set({ "n", "t" }, "<C-S-w>", function()
		if vim.fn.mode() == "t" then
			vim.cmd("stopinsert")
		end
		vim.cmd("close")
	end, {
		noremap = true,
		silent = true,
		desc = "Close current window",
	})
end
Configure_Terminal_Toggle()

-- =========== Plugin Specifics =================
-- Neo-tree
-- Open/Close (Sidebar)

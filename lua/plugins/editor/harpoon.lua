return {
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		keys = {
			{ "<leader>ha", desc = "Harpoon add file" },
			{ "<leader>hh", desc = "Harpoon menu" },
			{ "<leader>1", desc = "Harpoon item 1" },
			{ "<leader>2", desc = "Harpoon item 2" },
			{ "<leader>3", desc = "Harpoon item 3" },
			{ "<leader>hd", desc = "Harpoon delete current" },
			{ "<leader>hm", desc = "Harpoon move current up" },
			{ "<C-S-P>", desc = "Harpoon previous" },
			{ "<C-S-N>", desc = "Harpoon next" },
			{ "<leader>fl", desc = "Harpoon telescope list" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},

		config = function()

			local harpoon = require("harpoon")
			harpoon:setup()

			local list = harpoon:list()

			--[[
            Harpoon keybinds:

              <leader>ha     Add current file
              <leader>hh     Open Harpoon menu

              <leader>1-3    Jump to Harpoon item 1, 2, 3

              <leader>hd     Delete current Harpoon item

              <leader>hm     Move current item

              <leader>fl     Open Harpoon list through Telescope

              <C-S-P>        Previous Harpoon item
              <C-S-N>        Next Harpoon item


            Behavior:

              Harpoon uses a dynamic list:

                1 -> file.lua
                2 -> main.ts
                3 -> app.js

              Removing item 2:

                1 -> file.lua
                2 -> app.js

              Items automatically shift.
            ]]

			----------------------------------------------------
			-- Helper: find the current buffer's index in the list
			----------------------------------------------------

			local function get_current_index()
				local current_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
				local item, idx = list:get_by_value(current_path)
				return item and idx or nil
			end

			----------------------------------------------------
			-- Add / Menu
			----------------------------------------------------

			vim.keymap.set("n", "<leader>ha", function()
				list:add()
			end, {
				desc = "Harpoon add file",
			})

			vim.keymap.set("n", "<leader>hh", function()
				harpoon.ui:toggle_quick_menu(list)
			end, {
				desc = "Harpoon menu",
			})

			----------------------------------------------------
			-- Quick jump
			----------------------------------------------------

			for i = 1, 3 do
				vim.keymap.set("n", "<leader>" .. i, function()
					if list.items[i] then
						list:select(i)
					else
						vim.notify("Harpoon slot " .. i .. " is empty")
					end
				end, {
					desc = "Harpoon item " .. i,
				})
			end

			----------------------------------------------------
			-- Delete current item
			----------------------------------------------------

			vim.keymap.set("n", "<leader>hd", function()
				local current = get_current_index()

				if current then
					list:remove_at(current)
				else
					vim.notify("Current file is not in the Harpoon list")
				end
			end, {
				desc = "Harpoon delete current",
			})

			----------------------------------------------------
			-- Move current item up one slot
			----------------------------------------------------

			vim.keymap.set("n", "<leader>hm", function()
				local current = get_current_index()

				if not current then
					vim.notify("Current file is not in the Harpoon list")
					return
				end

				if current == 1 then
					vim.notify("Already at the top of the Harpoon list")
					return
				end

				list.items[current], list.items[current - 1] = list.items[current - 1], list.items[current]
			end, {
				desc = "Harpoon move current up",
			})

			----------------------------------------------------
			-- Previous / Next
			----------------------------------------------------

			vim.keymap.set("n", "<C-S-P>", function()
				list:prev()
			end, {
				desc = "Harpoon previous",
			})

			vim.keymap.set("n", "<C-S-N>", function()
				list:next()
			end, {
				desc = "Harpoon next",
			})

			----------------------------------------------------
			-- Telescope integration
			----------------------------------------------------

			vim.keymap.set("n", "<leader>fl", function()
				local conf = require("telescope.config").values
				local themes = require("telescope.themes")

				local files = {}

				for _, item in ipairs(list.items) do
					table.insert(files, item.value)
				end

				require("telescope.pickers")
					.new(
						themes.get_ivy({
							prompt_title = "Harpoon List",
						}),
						{
							finder = require("telescope.finders").new_table({
								results = files,
							}),
							previewer = conf.file_previewer({}),
							sorter = conf.generic_sorter({}),
						}
					)
					:find()
			end, {
				desc = "Harpoon telescope list",
			})
		end,
	},
}

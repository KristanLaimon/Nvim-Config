return {
    {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
	config = function()
	    local harpoon = require("harpoon")

	    -- REQUIRED
	    harpoon:setup()
	    -- REQUIRED

	    vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
	    vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

	    vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end)
	    vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end)
	    vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end)

	    -- Toggle previous & next buffers stored within Harpoon list
	    vim.keymap.set("n", "<C-S-P>", function() harpoon:list():prev() end)
	    vim.keymap.set("n", "<C-S-N>", function() harpoon:list():next() end)

	    -- Basic telescope integration 
	    -- Start Link: https://github.com/tonybanters/nvim/blob/master/after/plugin/harpoon.lua
		vim.keymap.set("n", "<leader>fl", function()
		    local conf = require("telescope.config").values
		    local themes = require("telescope.themes")
		    local file_paths = {}
		    for _, item in ipairs(harpoon:list().items) do
			table.insert(file_paths, item.value)
		    end
		    require("telescope.pickers").new(themes.get_ivy({ prompt_title = "Working List" }), {
			finder = require("telescope.finders").new_table({ results = file_paths }),
			previewer = conf.file_previewer({}),
			sorter = conf.generic_sorter({}),
		    }):find()
		end, { desc = "Open harpoon window" })
	    -- End Link: https://github.com/tonybanters/nvim/blob/master/after/plugin/harpoon.lua
	end
    }
}

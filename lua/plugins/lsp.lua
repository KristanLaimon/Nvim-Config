return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  opts = {
      servers = {
	  lua_ls = {
	      settings = {
		  Lua = {
		      diagnostics = {
			  globals = { "vim" },
		      },
		  }
	      }
	  }
      }
  },
  config = function(_, opts)
    -- 1. Initialize Mason
    require("mason").setup()
    require("mason-lspconfig").setup({ ensure_installed = {"lua_ls"}, })

    vim.diagnostic.config({
	virtual_text = true,
	underline = true
    })

    for server, config in pairs(opts.servers) do
	vim.lsp.config(server, config)
	vim.lsp.enable(server)
    end
 end
}

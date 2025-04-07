vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  -- Telescope
  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.8',
	  -- or                            , branch = '0.1.x',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }
  -- Catppuccin theme
  use { "catppuccin/nvim", as = "catppuccin", config = function()	
	  vim.cmd.colorscheme "catppuccin-mocha" end
  }
  -- Treesitter
  use {	'nvim-treesitter/nvim-treesitter',
	 run = ':TSUpdate'
  }
  -- Treesitter playground
  use { 'nvim-treesitter/playground' }
  -- Harpoon
  use "nvim-lua/plenary.nvim" 
  use {
	  "ThePrimeagen/harpoon",
	  branch = "harpoon2",
	  requires = { {"nvim-lua/plenary.nvim"} }
  }
  -- Undotree
  use {"mbbill/undotree"}
  -- FuGITive
  use {"tpope/vim-fugitive"}
  -- Base plugins for LSP-zero
  use({'neovim/nvim-lspconfig'})
  use({'hrsh7th/nvim-cmp'})
  use({'hrsh7th/cmp-nvim-lsp'})
  -- Mason LSP
  use {'williamboman/mason.nvim'}
  use {'williamboman/mason-lspconfig.nvim'}
end)


local ensure_packer = function()
    local fn = vim.fn
    local install_path =
        fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        print('Installing packer.nvim plugin...')
        fn.system({
            'git',
            'clone',
            '--depth',
            '1',
            'https://github.com/wbthomason/packer.nvim',
            install_path,
        })
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end
local packer_bootstrap = ensure_packer()
local status_ok, packer = pcall(require, 'packer')
if not status_ok then
    print('Plugin not loaded (CRUCIAL): ', 'packer')
    print('Automatic installation failed.', 'Follow installation instructions in packer.nvim repo.')
    return
end
packer.startup(function(use)

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
  ---------------------------------------------------------------------------------------------------------
  --------------------------------------------- COMPLETION RELATED ----------------------------------------
  use "hrsh7th/nvim-cmp"                    -- completion plugin
  use "hrsh7th/cmp-buffer"                  -- buffer completions
  use "hrsh7th/cmp-path"                    -- path completions
  use "hrsh7th/cmp-cmdline"                 -- cmdline completions
  use "saadparwaiz1/cmp_luasnip"            -- snippet completions
  use "hrsh7th/cmp-nvim-lua"                -- lua vim completions
  use "hrsh7th/cmp-nvim-lsp"                -- LSP completions
  use "hrsh7th/cmp-nvim-lsp-signature-help" -- function parameters completions
  ---------------------------------------------------------------------------------------------------------
  --------------------------------------------- SNIPPETS RELATED ------------------------------------------
  use "L3MON4D3/LuaSnip"             -- snippet engine
  use "rafamadriz/friendly-snippets" -- a bunch of ready-to-use snippets
  ---------------------------------------------------------------------------------------------------------
  ------------------------------------------------ LSP RELATED --------------------------------------------
  use "neovim/nvim-lspconfig"
  use "williamboman/mason.nvim"
  use "williamboman/mason-lspconfig.nvim"
  use "jose-elias-alvarez/null-ls.nvim"   -- for linting purposes
  use "folke/trouble.nvim"                -- for LSP\Linter warnings\errors
  use "Hoffs/omnisharp-extended-lsp.nvim" -- for proper go-to-definition support for omnisharp
  ---------------------------------------------------------------------------------------------------------
  ------------------------------------------------ UI -----------------------------------------------------
  use 'nvim-tree/nvim-web-devicons'         -- more icons for dev 
  use 'nvim-tree/nvim-tree.lua'             -- fancy file explorer
  use 'lukas-reineke/indent-blankline.nvim' -- showing indentation (especially usefull for Python)
  -- Lua line
  use {
      'nvim-lualine/lualine.nvim',
      requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  }
  -- Startup.vim
  use {
      "startup-nvim/startup.nvim",
      requires = {"nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim", "nvim-telescope/telescope-file-browser.nvim"},
      config = function()
          require"startup".setup({theme = "evil"})
      end
  }

  if packer_bootstrap then
      require('packer').sync()
  end
end)

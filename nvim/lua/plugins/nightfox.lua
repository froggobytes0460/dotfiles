return {
  -- Disable LazyVim's default colorschemes
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", name = "catppuccin", enabled = false },

  -- Use a built-in scheme as fallback during install
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "default",
    },
  },

  -- Nightfox (includes nordfox, duskfox, carbonfox, etc.)
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      options = {
        styles = {
          comments = "italic",
          keywords = "bold",
          functions = "italic",
        },
      },
    },
    config = function()
      vim.cmd("colorscheme nordfox")
    end,
  },
}

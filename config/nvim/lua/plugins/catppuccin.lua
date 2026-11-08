return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    flavour = "macchiato", -- latte, frappe, macchiato, mocha
    transparent_background = true, -- respeta la opacidad de kitty
    integrations = {
      cmp = true,
      gitsigns = true,
      nvimtree = true,
      telescope = true,
      notify = true,
      mini = true,
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}

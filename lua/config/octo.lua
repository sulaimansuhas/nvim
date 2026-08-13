return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Octo" },
  keys = {
    { "<leader>gr", "<cmd>Octo pr list<cr>", desc = "Octo: List PRs" },
  },
  config = function()
    require("octo").setup({
      use_local_fs = true,
      picker = "telescope",
    })
  end,
}

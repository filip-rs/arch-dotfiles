return {
  "nvim-tree/nvim-tree.lua",
  dependencies = "nvim-tree/nvim-web-devicons",
  keys = {
    { "<leader>ee", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
    { "<leader>et", "<cmd>NvimTreeFindFileToggle<CR>", desc = "Toggle on current file" },
    { "<leader>ec", "<cmd>NvimTreeCollapse<CR>", desc = "Collapse file explorer" },
    { "<leader>er", "<cmd>NvimTreeRefresh<CR>", desc = "Refresh file explorer" },
  },
  init = function()
    -- Load nvim-tree in background after startup
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(function()
          require("lazy").load({ plugins = { "nvim-tree.lua" } })
        end, 100)
      end,
    })
  end,
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    require("nvim-tree").setup({
      view = {
        width = 35,
        relativenumber = true,
      },
      renderer = {
        indent_markers = { enable = true },
      },
      actions = {
        open_file = {
          window_picker = { enable = false },
        },
      },
      git = { ignore = false },
    })
  end,
}

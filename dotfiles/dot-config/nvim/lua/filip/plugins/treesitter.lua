return {
  "nvim-treesitter/nvim-treesitter",
  event = "BufReadPost",
  build = ":TSUpdate",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
    "windwp/nvim-ts-autotag",
  },
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require("nvim-treesitter").setup({
      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "python",
        "go",
        "gomod",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "html",
        "css",
        "bash",
        "markdown",
        "markdown_inline",
      },
    })

    -- Enable treesitter features
    vim.treesitter.language.register("bash", "sh")

    -- Incremental selection keymaps
    vim.keymap.set("n", "<C-space>", function()
      require("nvim-treesitter.incremental_selection").init_selection()
    end, { desc = "Init selection" })
    vim.keymap.set("x", "<C-space>", function()
      require("nvim-treesitter.incremental_selection").node_incremental()
    end, { desc = "Increment selection" })
    vim.keymap.set("x", "<bs>", function()
      require("nvim-treesitter.incremental_selection").node_decremental()
    end, { desc = "Decrement selection" })

    -- Textobjects
    local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
    vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
    vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

    -- Setup autotag
    require("nvim-ts-autotag").setup()
  end,
}

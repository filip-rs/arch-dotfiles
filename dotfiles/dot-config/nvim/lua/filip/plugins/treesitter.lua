return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = "BufReadPost",
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")

      ts.setup({
        ensure_installed = {
          "lua", "vim", "vimdoc", "python", "go", "gomod",
          "javascript", "typescript", "tsx", "json", "yaml",
          "html", "css", "bash", "markdown", "markdown_inline",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })

      -- Install missing parsers
      local installed = ts.get_installed and ts.get_installed() or {}
      local to_install = {}
      for _, lang in ipairs({ "lua", "vim", "vimdoc", "python", "go", "javascript", "typescript", "json", "yaml", "html", "css", "bash", "markdown" }) do
        if not vim.tbl_contains(installed, lang) then
          table.insert(to_install, lang)
        end
      end
      if #to_install > 0 and ts.install then
        ts.install(to_install)
      end

      -- Enable treesitter highlighting for buffers
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      local ts_textobjects = require("nvim-treesitter-textobjects")

      if ts_textobjects.setup then
        ts_textobjects.setup({
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            keys = {
              goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
              goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
            },
          },
        })
      end
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    event = "BufReadPost",
    opts = {},
  },
}

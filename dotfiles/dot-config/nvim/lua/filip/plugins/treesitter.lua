return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")

      -- On the main branch, setup() only accepts install_dir; parser
      -- installation and feature activation are done explicitly below.
      local ensure_installed = {
        "lua", "vim", "vimdoc", "query",
        "python",
        "rust", "toml",
        "go", "gomod", "gowork", "gosum",
        "javascript", "typescript", "tsx", "json", "yaml",
        "html", "css", "markdown", "markdown_inline",
        "bash",
      }

      -- Install any parsers that aren't present yet (needs the tree-sitter CLI).
      local installed = ts.get_installed and ts.get_installed() or {}
      local to_install = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
      end, ensure_installed)
      if #to_install > 0 then
        ts.install(to_install)
      end

      -- Enable highlighting + treesitter-based indentation per buffer.
      local function start(buf)
        if pcall(vim.treesitter.start, buf) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("filip_treesitter", { clear = true }),
        callback = function(ev)
          start(ev.buf)
        end,
      })

      -- Apply to any buffers already open when treesitter loads.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          start(buf)
        end
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local map = vim.keymap.set

      -- Selection
      local selections = {
        ["af"] = { "@function.outer", "Select outer function" },
        ["if"] = { "@function.inner", "Select inner function" },
        ["ac"] = { "@class.outer", "Select outer class" },
        ["ic"] = { "@class.inner", "Select inner class" },
        ["aa"] = { "@parameter.outer", "Select outer parameter" },
        ["ia"] = { "@parameter.inner", "Select inner parameter" },
      }
      for lhs, spec in pairs(selections) do
        map({ "x", "o" }, lhs, function()
          select.select_textobject(spec[1], "textobjects")
        end, { desc = spec[2] })
      end

      -- Movement
      map({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function start" })
      map({ "n", "x", "o" }, "]c", function() move.goto_next_start("@class.outer", "textobjects") end, { desc = "Next class start" })
      map({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Prev function start" })
      map({ "n", "x", "o" }, "[c", function() move.goto_previous_start("@class.outer", "textobjects") end, { desc = "Prev class start" })
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}

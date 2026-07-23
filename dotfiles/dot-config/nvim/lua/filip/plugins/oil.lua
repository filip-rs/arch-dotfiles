return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- Load early so that `-` and netrw hijacking work from the start.
  lazy = false,
  config = function()
    -- Fully replace netrw
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1

    require("oil").setup({
      default_file_explorer = true, -- hijack netrw
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      prompt_save_on_select_new_entry = true,
      cleanup_delay_ms = 1000,

      view_options = {
        show_hidden = true,
        natural_order = true,
        is_always_hidden = function(name)
          return name == ".." or name == ".git"
        end,
      },

      float = {
        padding = 2,
        max_width = 0.6,
        max_height = 0.5,
        border = "rounded",
        win_options = {
          winblend = 0,
        },
      },

      -- Make oil buffers feel like regular file buffers where it makes sense
      buf_options = {
        buflisted = false,
        bufhidden = "hide",
      },

      -- Keymaps inside oil buffers (these are in addition to the powerful defaults)
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-s>"] = "actions.select_split",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-l>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
      },
    })

    local oil = require("oil")

    -- Primary explorer keys (designed to feel as instant as nvim-tree)
    -- <leader>ee → floating explorer at project root (cwd). Feels like "open the tree".
    vim.keymap.set("n", "<leader>ee", function()
      oil.toggle_float(vim.fn.getcwd())
    end, { desc = "Oil: floating explorer (project root)" })

    -- <leader>ef → floating explorer for the directory of the current file (reveal)
    vim.keymap.set("n", "<leader>ef", function()
      oil.toggle_float()
    end, { desc = "Oil: floating explorer (current file dir)" })

    -- Open oil as a regular buffer for the current file's directory.
    -- This is great when you want to do heavy editing / multi-file ops.
    vim.keymap.set("n", "<leader>et", function()
      oil.open()
    end, { desc = "Oil: edit current directory (buffer)" })

    -- The killer oil key. Press `-` in any buffer to open its parent directory.
    -- This is the muscle-memory equivalent of "go up" and becomes addictive.
    vim.keymap.set("n", "-", function()
      oil.open()
    end, { desc = "Oil: open parent directory" })

    -- <leader>e as a convenient short alias for the floating explorer
    vim.keymap.set("n", "<leader>e", function()
      oil.toggle_float(vim.fn.getcwd())
    end, { desc = "Oil: file explorer (float at root)" })
  end,
}

return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "SmiteshP/nvim-navic",
  },
  event = "VeryLazy",
  config = function()
    local navic = require("nvim-navic")

    require("lualine").setup({
      options = {
        theme = "tokyonight",
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "NvimTree", "oil", "alpha", "lazy", "mason" },
          winbar = { "NvimTree", "oil", "alpha", "lazy", "mason", "help" },
        },
        -- Reduce how often lualine (and thus the navic winbar) forces redraws.
        -- Higher numbers = fewer updates = less interference with fast scrolling.
        refresh = {
          statusline = 800,
          tabline = 1000,
          winbar = 250,   -- winbar (your code context) can stay a bit more responsive
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          {
            "filename",
            path = 1, -- relative path
            symbols = { modified = " ●", readonly = " 󰌾", unnamed = "[No Name]" },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      -- Winbar shows the current code context (function / impl / class etc.)
      -- This replaces the old treesitter-context sticky header with a lighter
      -- LSP-based solution that only updates when the LSP sends new symbols.
      winbar = {
        lualine_c = {
          {
            function()
              return navic.get_location()
            end,
            cond = function()
              return navic.is_available()
            end,
            color = { fg = "#7d99ab" }, -- subtle, matches gutter-ish tone
          },
        },
      },
      inactive_winbar = {
        lualine_c = {
          {
            function()
              return navic.get_location()
            end,
            cond = function()
              return navic.is_available()
            end,
          },
        },
      },
    })
  end,
}

return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy", -- show the bar shortly after startup
  keys = {
    -- Cycle through open files. <S-h>/<S-l> work in every terminal; the
    -- <C-Tab> pair only works in terminals that speak the kitty keyboard
    -- protocol (kitty, wezterm, foot, ghostty, ...), hence the reliable
    -- Shift-h/l fallback.
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
    { "<C-Tab>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
    { "<C-S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
    -- Reorder the current buffer left/right in the bar.
    { "<leader>b<", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer left" },
    { "<leader>b>", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer right" },
    -- Jump to a buffer by its letter label.
    { "<leader>bb", "<cmd>BufferLinePick<cr>", desc = "Pick buffer" },
    -- Pin/unpin so important files stay put on the left.
    { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin/unpin buffer" },
    -- Close buffers.
    { "<leader>bd", "<cmd>bdelete<cr>", desc = "Close buffer" },
    { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other buffers" },
  },
  opts = {
    options = {
      mode = "buffers", -- one entry per FILE (not per tabpage)
      diagnostics = "nvim_lsp", -- show LSP error/warn counts on each buffer
      diagnostics_indicator = function(_, _, diag)
        local s = {}
        if diag.error then s[#s + 1] = " " .. diag.error end
        if diag.warning then s[#s + 1] = " " .. diag.warning end
        return table.concat(s, " ")
      end,
      show_buffer_close_icons = true,
      show_close_icon = false,
      separator_style = "thin",
      -- Reserve a slot for the file tree so it sits beside the bar and is
      -- never rendered as a buffer/tab entry.
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          highlight = "Directory",
          separator = true,
        },
      },
    },
  },
}

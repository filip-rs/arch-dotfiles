return {
  "karb94/neoscroll.nvim",
  event = "BufReadPost",
  opts = {
    mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
    hide_cursor = true,
    easing = "sine",
  },
}

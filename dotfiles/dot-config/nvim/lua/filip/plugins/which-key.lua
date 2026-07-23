return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    -- Time (ms) after a prefix before the popup appears. Low = snappy.
    -- 0 is instant but can flash the popup on fast, memorized chords.
    delay = 100,
    -- Keep it lightweight: only show for common prefixes
    triggers = {
      { "<auto>", mode = "nixsotc" },
      { "<leader>", mode = "n" },
    },
    win = {
      border = "rounded",
    },
    layout = {
      spacing = 4,
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- Explicit groups for discoverability (especially useful with the new Rust keys)
    wk.add({
      { "<leader>b", group = "Buffer" },
      { "<leader>f", group = "Find" },
      { "<leader>r", group = "Rust" },
      { "<leader>t", group = "Tab" },
      { "<leader>h", group = "Git Hunk" },
      { "<leader>x", group = "Debug" },
    })
  end,
}

return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function()
    local transparent = false

    -- Load generated theme colors, fall back to coolnight defaults
    local ok, tc = pcall(require, "filip.theme_colors")
    if not ok then
      tc = {
        bg = "#010d1a",
        bg_dark = "#01111f",
        bg_highlight = "#122d42",
        bg_search = "#0a64ac",
        bg_visual = "#0f3f63",
        fg = "#CBE0F0",
        fg_dark = "#a3bfd0",
        fg_gutter = "#7d99ab",
        border = "#547998",
      }
    end

    require("tokyonight").setup({
      style = "night",
      transparent = transparent,
      styles = {
        sidebars = transparent and "transparent" or "dark",
        floats = transparent and "transparent" or "dark",
      },
      on_colors = function(colors)
        colors.bg = tc.bg
        colors.bg_dark = transparent and colors.none or tc.bg_dark
        colors.bg_float = transparent and colors.none or tc.bg_dark
        colors.bg_highlight = tc.bg_highlight
        colors.bg_popup = tc.bg_dark
        colors.bg_search = tc.bg_search
        colors.bg_sidebar = transparent and colors.none or tc.bg_dark
        colors.bg_statusline = transparent and colors.none or tc.bg_dark
        colors.bg_visual = tc.bg_visual
        colors.border = tc.border
        colors.fg = tc.fg
        colors.fg_dark = tc.fg_dark
        colors.fg_float = tc.fg
        colors.fg_gutter = tc.fg_gutter
        colors.fg_sidebar = tc.fg_dark
      end,
    })

    vim.cmd("colorscheme tokyonight")
  end,
}

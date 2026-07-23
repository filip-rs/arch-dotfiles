return {
  "saecki/crates.nvim",
  event = { "BufRead Cargo.toml" },
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local crates = require("crates")

    crates.setup({
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
      completion = {
        cmp = {
          enabled = true,
        },
      },
      popup = {
        border = "rounded",
      },
    })

    -- Show crates info on Cargo.toml
    crates.show()

    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = true, silent = true, desc = desc })
    end

    -- Crates keymaps (only active in Cargo.toml buffers)
    map("<leader>ct", crates.toggle, "Crates: toggle")
    map("<leader>cr", crates.reload, "Crates: reload")
    map("<leader>cv", crates.show_versions_popup, "Crates: versions")
    map("<leader>cf", crates.show_features_popup, "Crates: features")
    map("<leader>cu", crates.update_crate, "Crates: update crate")
    map("<leader>cU", crates.upgrade_crate, "Crates: upgrade crate")
    map("<leader>ca", crates.update_all_crates, "Crates: update all")
    map("<leader>cA", crates.upgrade_all_crates, "Crates: upgrade all")
    map("<leader>cH", crates.open_homepage, "Crates: homepage")
    map("<leader>cR", crates.open_repository, "Crates: repository")
    map("<leader>cD", crates.open_documentation, "Crates: docs")
  end,
}

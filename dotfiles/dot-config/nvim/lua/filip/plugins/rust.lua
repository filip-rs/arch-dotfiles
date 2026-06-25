return {
  "mrcjkb/rustaceanvim",
  version = "^6",
  ft = { "rust" },
  config = function()
    -- rustaceanvim manages rust-analyzer itself (do NOT also enable it via
    -- lspconfig/mason-lspconfig). It reads this global when it attaches.
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    vim.g.rustaceanvim = {
      server = {
        capabilities = capabilities,
        default_settings = {
          ["rust-analyzer"] = {
            -- Analyze with the SAME features cargo build uses (default set).
            -- `allFeatures = true` can surface phantom type errors when a crate
            -- has cfg-gated or non-additive features. If you need a specific
            -- feature analyzed, set e.g. cargo = { features = { "foo" } }.
            checkOnSave = true,
            check = { command = "clippy" },
            -- rust-analyzer's native (non-cargo) type engine raises false
            -- E0605 "non-primitive cast" errors on macro-generated `as` casts
            -- (e.g. dyn-Value logging macros). `cargo check` stays clean, so
            -- trust flycheck and silence the native version of this code.
            diagnostics = {
              disabled = { "E0605", "E0308", "E0608" },
            },
          },
        },
      },
    }
  end,
}

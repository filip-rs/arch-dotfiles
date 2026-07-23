return {
  "mrcjkb/rustaceanvim",
  version = "^6",
  ft = { "rust" },
  config = function()
    -- rustaceanvim manages rust-analyzer itself (do NOT also enable it via
    -- lspconfig/mason-lspconfig). It reads this global when it attaches.
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- A hover/action float that scales with the window instead of hugging the
    -- cursor, so long type signatures and doc blocks stay readable.
    local function readable_float_opts()
      local available_width = math.max(vim.o.columns - 6, 20)
      local width = math.min(
        math.max(math.floor(vim.o.columns * 0.72), math.min(64, available_width)),
        96,
        available_width
      )

      return {
        border = "rounded",
        width = width,
        max_width = width,
        max_height = math.min(math.max(math.floor(vim.o.lines * 0.35), 12), 24),
        wrap = true,
      }
    end

    local function rust_lsp(command)
      return function()
        vim.cmd.RustLsp(command)
      end
    end

    vim.g.rustaceanvim = {
      tools = {
        -- Fall back to vim.ui.select when there are grouped code actions.
        code_actions = { ui_select_fallback = true },
        float_win_config = readable_float_opts(),
      },
      server = {
        capabilities = capabilities,
        on_attach = function(_client, bufnr)
          -- Render inlay hints for this buffer (rust-analyzer produces them
          -- from the inlayHints settings below).
          if vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end

          -- Rust buffers also trigger the generic LspAttach handler in
          -- lspconfig.lua (Telescope gd/gr, [d/]d, <leader>rs restart, etc.),
          -- which we keep. Set the Rust-specific maps via vim.schedule so they
          -- win the race and override K after that handler runs.
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end

            local map = function(lhs, rhs, desc, mode)
              vim.keymap.set(mode or "n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
            end

            -- Hover shows docs AND the available code actions in one popup.
            map("K", rust_lsp({ "hover", "actions" }), "Rust hover actions")

            map("<leader>rr", rust_lsp("runnables"), "Rust runnables")
            map("<leader>rd", rust_lsp("debuggables"), "Rust debuggables")
            map("<leader>rt", rust_lsp("testables"), "Rust testables")
            map("<leader>re", rust_lsp("explainError"), "Rust explain error")
            map("<leader>rD", rust_lsp("renderDiagnostic"), "Rust render diagnostic")
            map("<leader>rf", function()
              vim.cmd.RustLsp({ "flyCheck", "run" })
            end, "Rust fly check")
            map("<leader>rm", rust_lsp("expandMacro"), "Rust expand macro")
            map("<leader>rM", rust_lsp("rebuildProcMacros"), "Rust rebuild proc macros")
            map("<leader>rc", rust_lsp("openCargo"), "Rust open Cargo.toml")
            map("<leader>rC", rust_lsp("crateGraph"), "Rust crate graph")
            map("<leader>rp", rust_lsp("parentModule"), "Rust parent module")
            map("<leader>rj", rust_lsp("joinLines"), "Rust join lines", { "n", "x" })
            map("<leader>ro", rust_lsp("openDocs"), "Rust docs.rs")
            map("<leader>rh", function()
              if not vim.lsp.inlay_hint then
                return
              end
              local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
              vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
            end, "Rust toggle inlay hints")
          end)
        end,
        default_settings = {
          ["rust-analyzer"] = {
            -- Analyze with the SAME features cargo build uses (default set).
            -- `allFeatures = true` can surface phantom type errors when a crate
            -- has cfg-gated or non-additive features. If you need a specific
            -- feature analyzed, set e.g. cargo = { features = { "foo" } }.
            checkOnSave = true,
            check = { command = "clippy", allTargets = true },
            -- rust-analyzer's native (non-cargo) type engine raises false
            -- E0605 "non-primitive cast" errors on macro-generated `as` casts
            -- (e.g. dyn-Value logging macros). `cargo check` stays clean, so
            -- trust flycheck and silence the native version of this code.
            diagnostics = {
              disabled = { "E0605", "E0308", "E0608" },
            },
            cargo = {
              -- Deliberately no allFeatures (see checkOnSave note above).
              loadOutDirsFromCheck = true,
              buildScripts = { enable = true },
            },
            procMacro = { enable = true },
            completion = {
              fullFunctionSignatures = { enable = true },
            },
            lens = { enable = true },
            imports = {
              granularity = { group = "module" },
              prefix = "crate",
            },
            -- A tasteful inlay-hint set. Bump any of these to "always" if you
            -- want more (e.g. lifetimeElisionHints, reborrowHints).
            inlayHints = {
              bindingModeHints = { enable = true },
              chainingHints = { enable = true },
              closingBraceHints = { enable = true, minLines = 25 },
              closureReturnTypeHints = { enable = "with_block" },
              lifetimeElisionHints = { enable = "skip_trivial", useParameterNames = true },
              parameterHints = { enable = true },
              reborrowHints = { enable = "mutable" },
              typeHints = { enable = true },
            },
          },
        },
      },
    }
  end,
}

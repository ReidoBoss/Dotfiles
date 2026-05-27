-- Place in your init.lua or loaded before rustaceanvim starts
vim.g.rustaceanvim = {
  server = {
    on_attach = function(client, bufnr)
      -- Keymaps set on attach (see mappings tab)
    end,
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
        },
        checkOnSave = {
          command = "clippy", -- Use clippy instead of check
          allTargets = true,
        },
        procMacro = {
          enable = true,
        },
        inlayHints = {
          bindingModeHints = { enable = false },
          chainingHints    = { enable = true  },
          parameterHints   = { enable = true  },
          typeHints        = { enable = true  },
        },
      },
    },
  },
  tools = {
    hover_actions = {
      auto_focus = true,
    },
  },
}

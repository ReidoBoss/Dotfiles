require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "taplo" }
vim.lsp.enable(servers)


-- go.nvim
-- https://github.com/ray-x/go.nvim
-- All-in-one Go plugin: gopls setup, test/build/run, coverage,
-- tags, iferr, import formatting, DAP debugging (via nvim-dap), etc.
-- Uses gopls from your PATH (install with: go install golang.org/x/tools/gopls@latest)

vim.pack.add {
  'https://github.com/ray-x/go.nvim',
  -- Optional floating-window UI used by some go.nvim features (e.g. :GoTermClose list)
  'https://github.com/ray-x/guihua.lua',
}

require('go').setup {
  -- Let kickstart's own LSP config keep managing gopls; go.nvim fills in
  -- Go-specific commands on top. Set to true if you want go.nvim to fully
  -- own the gopls setup instead.
  lsp_cfg = false,
  lsp_gofumpt = true,
}

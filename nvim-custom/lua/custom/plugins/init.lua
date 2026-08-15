-- Custom configuration layered on top of kickstart.nvim.
-- This file is the single entry point: `require 'custom.plugins'` in init.lua.
-- Keeping init.lua stock (except that one uncommented line) makes upstream
-- kickstart merges conflict-free.

-- [[ Kickstart example plugins ]]
-- Enable the optional kickstart examples we want. These live in
-- lua/kickstart/plugins/*.lua (stock, unmodified) and are loaded via require.
require 'kickstart.plugins.indent_line'
require 'kickstart.plugins.lint'
require 'kickstart.plugins.autopairs'
require 'kickstart.plugins.gitsigns' -- adds gitsigns recommended keymaps
-- NOTE: neo-tree is loaded from custom/plugins/neo-tree.lua below (custom overrides).
-- require 'kickstart.plugins.debug' -- DAP setup (uncomment to enable)

-- [[ Custom LSP configuration ]]
-- Enables gopls (from lspconfig defaults or a workspace-local `.nvim/lsp/gopls.lua`)
-- and appends `.nvim` to the runtimepath when found. Runs after kickstart's
-- SECTION 6, so nvim-lspconfig is already loaded.
require 'custom.lsp'

-- [[ Custom plugins ]]
-- Auto-load every *.lua file in this directory (except init.lua).
local plugins_dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'custom', 'plugins')
for file_name, type in vim.fs.dir(plugins_dir, { follow = true }) do
  if (type == 'file' or type == 'link') and file_name:match '%.lua$' and file_name ~= 'init.lua' then
    local module = file_name:gsub('%.lua$', '')
    require('custom.plugins.' .. module)
  end
end

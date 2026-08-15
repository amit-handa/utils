-- Project-local LSP configuration.
-- Enables gopls from lspconfig defaults, or from a workspace-local
-- `.nvim/lsp/gopls.lua` (e.g. the pedregal monorepo) when present.
-- Requires nvim >= 0.11 (vim.lsp.config / vim.lsp.enable API).

-- Find the nearest ancestor of `cwd` containing `pattern` (e.g. ".nvim").
---@param cwd string
---@param pattern string
---@return string|nil
local function find_ancestor_dir(cwd, pattern)
  local current = cwd
  while current ~= '/' do
    local path = current .. '/' .. pattern
    if vim.fn.isdirectory(path) == 1 then return path end
    current = vim.fn.fnamemodify(current, ':h')
  end
  return nil
end

-- If a `.nvim` directory exists in an ancestor, append it to the runtimepath
-- so its `lsp/*.lua` configs are picked up by `vim.lsp.enable`.
local project_config = find_ancestor_dir(vim.fn.getcwd(), '.nvim')
if project_config then
  -- Later rtp entries win when merging `lsp/*.lua` configs, so the project
  -- config takes precedence over the default nvim-lspconfig `gopls` config.
  vim.opt.runtimepath:append(project_config)
end

-- Enable gopls unconditionally:
--  - With a project-local `.nvim/lsp/gopls.lua` on the rtp, `vim.lsp.enable`
--    loads it (the project override wins over lspconfig defaults).
--  - Without one, lspconfig's default `lsp/gopls.lua` is used.
-- nvim-lspconfig is already loaded (stock init.lua SECTION 6 runs before us),
-- so `require('lspconfig.util')` inside a project config resolves correctly.
vim.lsp.config('gopls', {})
vim.lsp.enable('gopls')

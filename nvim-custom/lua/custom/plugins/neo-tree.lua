-- Neo-tree file explorer — custom overrides on top of kickstart's example.
-- https://github.com/nvim-neo-tree/neo-tree.nvim
--
-- kickstart ships lua/kickstart/plugins/neo-tree.lua with a `reveal` keymap
-- and a filesystem window mapping that closes the tree on `\`. We prefer a
-- toggle-reveal keymap and the default window setup, so we load neo-tree
-- here instead of requiring the kickstart example.

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree toggle reveal<CR>', { desc = 'NeoTree reveal toggle', silent = true })

require('neo-tree').setup {}

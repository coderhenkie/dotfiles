-- Notes/markdown (runs for every markdown buffer, also the first one LazyVim's own autocmds miss)
local o = vim.opt_local
o.list = false      -- no invisible characters: trailing spaces showed up as "-" (templates are full of them)
o.wrap = true       -- long lines wrap on screen...
o.linebreak = true  -- ...at word boundaries
o.spell = false     -- LazyVim's English spell check would flag every Dutch word (also lua/config/autocmds.lua)
vim.b.snacks_indent = false  -- no indent guide "│" under the block the cursor is in

-- Fold only headings, exactly like Obsidian (lua/markdown_fold.lua). LazyVim would use treesitter or,
-- once a server attaches, LSP folds: those also fold lists, obsidian-ls ends sections too early and an
-- empty heading folded its parent section. A non-default value here makes LazyVim leave it alone.
o.foldmethod = "expr"
o.foldexpr = "v:lua.require'markdown_fold'.expr()"
require("markdown_fold").attach(vim.api.nvim_get_current_buf())

-- Enter while typing continues lists and tasks like Obsidian (lua/markdown_list.lua)
require("markdown_list").attach(vim.api.nvim_get_current_buf())

-- Tab on a heading folds/unfolds its section (like the arrow in Obsidian); elsewhere Tab keeps its
-- normal meaning (jump forward in the jump list). Enter does the same (lua/plugins/obsidian.lua).
vim.keymap.set("n", "<Tab>", function()
    local fold = require("markdown_fold")
    return fold.is_heading() and fold.toggle_keys() or "<Tab>"
end, { buffer = true, expr = true, desc = "Fold/unfold heading" })

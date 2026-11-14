-- Notes/markdown (runs for every markdown buffer, also the first one LazyVim's own autocmds miss)
local o = vim.opt_local
o.list = false      -- no invisible characters: trailing spaces showed up as "-" (templates are full of them)
o.wrap = true       -- long lines wrap on screen...
o.linebreak = true  -- ...at word boundaries
o.spell = false     -- LazyVim's English spell check would flag every Dutch word
vim.b.snacks_indent = false  -- no indent guide "│" under the block the cursor is in

-- Tab on a heading folds/unfolds its section (like the arrow in Obsidian); elsewhere Tab keeps its
-- normal meaning (jump forward in the jump list)
vim.keymap.set("n", "<Tab>", function()
    return vim.fn.getline("."):match("^#+%s") and "za" or "<Tab>"
end, { buffer = true, expr = true, desc = "Fold/unfold heading" })

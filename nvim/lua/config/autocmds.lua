-- Live theme reload: when apply-theme.sh rewrites ~/.cache/theme/nvim.lua (theme/wallpaper switch),
-- every open Neovim recolors itself immediately.
local uv = vim.uv or vim.loop
local cache_dir = vim.fn.expand("~/.cache/theme")
local watcher = uv.new_fs_event()
if watcher and vim.fn.isdirectory(cache_dir) == 1 then
    watcher:start(cache_dir, {}, vim.schedule_wrap(function(err, filename)
        if not err and (not filename or filename == "nvim.lua") then
            vim.cmd.colorscheme("colorengine")
        end
    end))
end

-- No spell check in markdown: LazyVim's wrap_spell autocmd turns English spell check on, which
-- underlines every Dutch word in notes. after/ftplugin/markdown.lua turns it off too, but when nvim
-- starts without a file (`obsidian` -> +"Obsidian today") LazyVim's autocmd is registered later and
-- runs after the ftplugin; this one is registered after LazyVim's, so it always wins.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("markdown_no_spell", { clear = true }),
    pattern = "markdown",
    callback = function() vim.opt_local.spell = false end,
})

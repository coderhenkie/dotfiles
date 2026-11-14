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

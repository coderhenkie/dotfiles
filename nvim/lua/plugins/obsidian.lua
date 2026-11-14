-- Obsidian vaults in Neovim (obsidian.nvim). Typing `obsidian` in a terminal opens today's daily
-- note (scripts/obsidian-tui.sh). Same files as the Obsidian app; Obsidian Sync runs headless while
-- the app is closed (scripts/obsidian-sync.sh).
--
-- Vaults are read from the Obsidian app's own list (~/.config/obsidian/obsidian.json) and from the
-- vault linked by `obsidian-sync setup`, so nothing is hardcoded; without vaults the plugin isn't loaded.
-- Daily notes match the app's Daily notes settings: calendar/daily, YY-MM-DD, "daily template".

local function vaults()
    local paths = {}
    -- Vaults known to the Obsidian app
    local file = vim.fn.expand("~/.config/obsidian/obsidian.json")
    if vim.fn.filereadable(file) == 1 then
        local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
        if ok and type(data) == "table" and type(data.vaults) == "table" then
            for _, v in pairs(data.vaults) do
                if type(v.path) == "string" then table.insert(paths, v.path) end
            end
        end
    end
    -- The vault linked by `obsidian-sync setup` (headless), for machines where the app never ran
    local linked = vim.fn.expand("~/.config/obsidian-sync/vault")
    if vim.fn.filereadable(linked) == 1 then table.insert(paths, vim.fn.readfile(linked)[1]) end

    local list, seen = {}, {}
    for _, p in ipairs(paths) do
        p = vim.fn.fnamemodify(p, ":p"):gsub("/$", "")
        if not seen[p] and vim.fn.isdirectory(p) == 1 then
            seen[p] = true
            table.insert(list, { name = vim.fn.fnamemodify(p, ":t"), path = p })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local workspaces = vaults()

local events = {}
for _, w in ipairs(workspaces) do
    table.insert(events, "BufReadPre " .. w.path .. "/*.md")
    table.insert(events, "BufNewFile " .. w.path .. "/*.md")
end

local function in_vault(path)
    for _, w in ipairs(workspaces) do
        if path:sub(1, #w.path + 1) == w.path .. "/" then return true end
    end
    return false
end

return {
    -- Writing prose: no word/snippet suggestions in markdown, only the useful completions from the
    -- LSPs (note names after [[, tags after #) and file paths
    {
        "saghen/blink.cmp",
        optional = true,
        opts = {
            sources = {
                per_filetype = { markdown = { "lsp", "path" } },
            },
        },
    },
    -- render-markdown: LazyVim's markdown extra turns checkbox rendering and heading icons off; turn
    -- them back on, plus icons for obsidian.nvim's extra checkbox states (Enter cycles [ ] [~] [!] [>] [x])
    {
        "MeanderingProgrammer/render-markdown.nvim",
        optional = true,
        opts = {
            heading = { icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " } },
            checkbox = {
                enabled = true,
                custom = {
                    cancelled = { raw = "[~]", rendered = "󰰱 ", highlight = "RenderMarkdownCancelled" },
                    important = { raw = "[!]", rendered = " ", highlight = "RenderMarkdownImportant" },
                    forwarded = { raw = "[>]", rendered = " ", highlight = "RenderMarkdownForwarded" },
                },
            },
        },
    },
    -- No markdownlint in notes (Obsidian notes aren't strict markdown); READMEs etc. keep it
    {
        "mfussenegger/nvim-lint",
        optional = true,
        opts = {
            linters = {
                ["markdownlint-cli2"] = {
                    condition = function(ctx) return not in_vault(ctx.filename) end,
                },
            },
        },
    },
    {
        "obsidian-nvim/obsidian.nvim",
        version = "*",
        enabled = #workspaces > 0,
        -- Load for markdown files inside a vault, or for any :Obsidian command
        event = events,
        cmd = "Obsidian",
        init = function()
            -- No format-on-save in vaults: LazyVim's markdown formatters (prettier, markdownlint-cli2
            -- --fix, markdown-toc) would rewrite notes on every :w (list markers, blank lines, tables),
            -- and those rewrites would sync to every device. Code/READMEs outside vaults keep it.
            vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
                group = vim.api.nvim_create_augroup("obsidian_no_autoformat", { clear = true }),
                callback = function(ev)
                    if not in_vault(vim.fn.fnamemodify(ev.match, ":p")) then return end
                    vim.b[ev.buf].autoformat = false
                end,
            })

            -- Links like in the Obsidian app:
            --   Enter       on a link: open it in place of this note (saved first; its tab closes)
            --   Ctrl+Enter  on a link: open it in a new tab (bufferline), this note stays open
            -- Enter elsewhere keeps obsidian.nvim's smart action (checkbox, fold heading, tag).
            -- Set on ObsidianNoteEnter, which fires right after obsidian.nvim maps its own Enter.
            local function follow(replace)
                local old = vim.api.nvim_get_current_buf()
                if replace then
                    if vim.bo[old].modified then vim.cmd("silent write") end
                    local id = vim.api.nvim_create_autocmd("BufEnter", {
                        once = true,
                        callback = function(e)
                            if e.buf ~= old and vim.api.nvim_buf_is_valid(old) then
                                vim.schedule(function() Snacks.bufdelete({ buf = old }) end)
                            end
                        end,
                    })
                    -- Link to a heading in this note, a URL or a cancelled picker: no BufEnter follows
                    vim.defer_fn(function() pcall(vim.api.nvim_del_autocmd, id) end, 5000)
                end
                vim.cmd("Obsidian follow_link")
            end
            vim.api.nvim_create_autocmd("User", {
                pattern = "ObsidianNoteEnter",
                group = vim.api.nvim_create_augroup("obsidian_link_keys", { clear = true }),
                callback = function()
                    local buf = vim.api.nvim_get_current_buf()
                    local api, actions = require("obsidian.api"), require("obsidian.actions")
                    vim.keymap.set("n", "<CR>", function()
                        if api.cursor_link() then
                            vim.schedule(function() follow(true) end)
                            return ""
                        end
                        return actions.smart_action()
                    end, { buffer = buf, expr = true, desc = "Open link here / toggle checkbox / fold" })
                    vim.keymap.set("n", "<C-CR>", function()
                        if api.cursor_link() then follow(false) end
                    end, { buffer = buf, desc = "Open link in new tab" })
                end,
            })
        end,
        opts = {
            legacy_commands = false,
            workspaces = workspaces,
            picker = { name = "snacks.picker" },
            -- Keep notes exactly like the app writes them: readable file names, no extra frontmatter
            note_id_func = function(title)
                return title or tostring(os.time())
            end,
            frontmatter = { enabled = false },
            new_notes_location = "current_dir",
            daily_notes = {
                folder = "calendar/daily",
                date_format = "YY-MM-DD",
                template = "daily template.md",
                default_tags = {},
                workdays_only = false,
            },
            templates = { folder = "calendar/templates" },
            -- render-markdown.nvim (LazyVim markdown extra) already draws checkboxes, bullets, links
            ui = { enable = false },
        },
        keys = {
            { "<leader>o", "", desc = "+obsidian" },
            { "<leader>ot", "<cmd>Obsidian today<cr>", desc = "Today's note" },
            { "<leader>oy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's note" },
            { "<leader>om", "<cmd>Obsidian tomorrow<cr>", desc = "Tomorrow's note" },
            { "<leader>od", "<cmd>Obsidian dailies<cr>", desc = "Daily notes" },
            { "<leader>of", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
            { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search notes" },
            { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
            { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
            { "<leader>og", "<cmd>Obsidian tags<cr>", desc = "Tags" },
            { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links in note" },
            { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note (updates links)" },
            { "<leader>oT", "<cmd>Obsidian template<cr>", desc = "Insert template" },
            { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
            { "<leader>ow", "<cmd>Obsidian workspace<cr>", desc = "Switch vault" },
            { "<leader>oo", "<cmd>Obsidian open<cr>", desc = "Open in Obsidian app" },
        },
    },
}

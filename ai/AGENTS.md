# Global rules for AI agents (Claude Code, Antigravity CLI)
Template: scripts/ai-vault-access.sh fills in {{VAULT}} and writes the result to
~/.config/ai/AGENTS.md (outside the repo), linked as ~/.claude/CLAUDE.md and ~/.gemini/GEMINI.md.

## Obsidian vault
- The Obsidian vault in `{{VAULT}}` may be read and edited when the user explicitly asks for it.
  Access is allowed in the tools' settings, so no permission prompt appears.
- A question about whether you *can* access the vault ("can you see my notes?") is not a request
  to access it: answer in words without running anything on the vault (no `ls`, `find`, counts or reads).
  Only touch the vault when the user asks you to do something with it ("look up X in my notes").
- The vault syncs to other devices (Obsidian Sync / `obsidian-sync`): every change spreads.
  Before moving, deleting or renaming many files, make a backup outside the vault first (e.g. `~/Backups`).
- Layout (PARA): `1 Projects`, `2 Areas`, `3 Resources`, `4 Archive`, `attachments` (all non-note files),
  `calendar/daily` (daily notes, `YY-MM-DD.md`), `calendar/templates` (daily/weekly template), `Clippings`.
- Notes are edited in Neovim (obsidian.nvim) as well as the app: use plain `[[wikilinks]]`,
  no `#tags` and no Markdown tables in templates.
- Notes contain private data: never send vault content to external services and never quote
  secrets back unless asked.

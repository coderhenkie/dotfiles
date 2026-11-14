/*
 * ColorEngine for Obsidian (source: ~/dotfiles/obsidian/colorengine, installed into vaults by
 * scripts/obsidian-colorengine.sh).
 *
 * On a machine with the dotfiles it reads ~/.cache/theme/obsidian.css (written by
 * scripts/apply-theme.sh) and, while active:
 *   - switches the vault's community theme off LOCALLY (in memory, never saved), so the
 *     ColorEngine colors apply the same way whatever theme is chosen in Settings
 *   - applies the colors + desktop font through Obsidian's built-in CSS variables
 *   - forces dark mode on this machine
 *   - reloads live when the file changes (theme or font switch on the desktop)
 *
 * It never writes to the vault or its config, so Obsidian Sync never carries a theme change to
 * other devices. Where the file doesn't exist (phone, Windows, machines without the dotfiles)
 * it does nothing. Command palette: "ColorEngine: Toggle desktop theme" (remembered per machine
 * in localStorage, which is not synced).
 */
const { Plugin, Notice } = require("obsidian");
const fs = require("fs");
const os = require("os");
const path = require("path");

const CSS_FILE = path.join(os.homedir(), ".cache", "theme", "obsidian.css");
const STORAGE_KEY = "colorengine-disabled";
const BODY_CLASS = "colorengine";

module.exports = class ColorEngine extends Plugin {
    async onload() {
        this.styleEls = new Map(); // document -> <style>
        this.active = false;

        this.addCommand({
            id: "toggle",
            name: "Toggle desktop theme",
            callback: () => {
                const disabled = !this.isDisabledHere();
                try { window.localStorage.setItem(STORAGE_KEY, disabled ? "1" : "0"); } catch (e) {}
                this.refresh();
                new Notice(disabled ? "ColorEngine off: using the synced theme" : "ColorEngine on");
            },
        });

        // Re-assert after Obsidian reloads the theme (e.g. a synced cssTheme change or picking
        // one in Settings) or switches light/dark
        this.registerEvent(this.app.workspace.on("css-change", () => this.active && this.enforce()));
        // Popout windows get their own document
        this.registerEvent(this.app.workspace.on("window-open", () => this.active && this.applyCss()));

        fs.watchFile(CSS_FILE, { interval: 1000 }, () => this.refresh());
        this.register(() => fs.unwatchFile(CSS_FILE));

        this.app.workspace.onLayoutReady(() => this.refresh());
    }

    onunload() {
        this.deactivate();
    }

    isDisabledHere() {
        try { return window.localStorage.getItem(STORAGE_KEY) === "1"; } catch (e) { return false; }
    }

    readCss() {
        try { return fs.readFileSync(CSS_FILE, "utf8"); } catch (e) { return null; }
    }

    refresh() {
        const css = this.isDisabledHere() ? null : this.readCss();
        if (css === null) { this.deactivate(); return; }
        this.css = css;
        this.active = true;
        this.applyCss();
        this.enforce();
    }

    documents() {
        const docs = new Set([document]);
        this.app.workspace.iterateAllLeaves((leaf) => {
            const doc = leaf.view && leaf.view.containerEl && leaf.view.containerEl.ownerDocument;
            if (doc) docs.add(doc);
        });
        return docs;
    }

    applyCss() {
        for (const doc of this.documents()) {
            let el = this.styleEls.get(doc);
            if (!el || !el.isConnected) {
                el = doc.createElement("style");
                el.id = "colorengine-theme";
                doc.head.appendChild(el); // last in <head>: after the theme + snippet styles
                this.styleEls.set(doc, el);
            }
            if (el.textContent !== this.css) el.textContent = this.css;
            doc.body.classList.add(BODY_CLASS);
        }
    }

    enforce() {
        // Community theme off, in memory only. setTheme() would save it to appearance.json (synced),
        // so set the field directly and let Obsidian reload. Guarded: internal API.
        const customCss = this.app.customCss;
        try {
            if (customCss && customCss.theme) {
                customCss.theme = "";
                customCss.requestLoadTheme();
            }
        } catch (e) {
            console.warn("ColorEngine: could not switch the community theme off locally", e);
        }
        // Dark mode on this machine (classes only, nothing saved)
        for (const doc of this.documents()) {
            if (!doc.body.classList.contains("theme-dark")) {
                doc.body.classList.remove("theme-light");
                doc.body.classList.add("theme-dark");
            }
        }
    }

    deactivate() {
        const wasActive = this.active;
        this.active = false;
        for (const [doc, el] of this.styleEls) {
            el.remove();
            doc.body && doc.body.classList.remove(BODY_CLASS);
        }
        this.styleEls.clear();
        if (!wasActive) return;
        // Back to the synced settings: the community theme and light/dark mode from appearance.json
        try { this.app.customCss.reloadTheme(); } catch (e) {}
        try { this.app.updateTheme(); } catch (e) {}
    }
};

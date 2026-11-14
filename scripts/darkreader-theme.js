#!/usr/bin/env node
// ==========================================
// Dark Reader (Thorium) follows the Color Engine
// ==========================================
// Dark Reader has no managed policy, so its colors are written straight into its extension storage
// (Thorium's LevelDB "Local Extension Settings/<id>", one JSON value per setting key). Only the
// colors in `theme` are set (background, text, selection, scrollbar) and `syncSettings` is turned
// off so Dark Reader reads this local storage; every other setting (brightness, contrast, site
// lists, ...) is kept, and Dark Reader fills in defaults for missing theme fields.
//
// The database is locked while Thorium runs, so:
//   darkreader-theme.js apply   apply ~/.cache/theme/current.theme now if Thorium is closed,
//                               otherwise mark it pending (~/.cache/theme/darkreader.pending)
//   darkreader-theme.js pending apply only if marked pending (scripts/thorium-launch.sh, before start)
// Exit code 0 also when skipped (Dark Reader not installed yet, Thorium running).

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const HOME = os.homedir();
const EXT_ID = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
const DB_DIR = path.join(HOME, ".config/thorium/Default/Local Extension Settings", EXT_ID);
const CACHE = path.join(HOME, ".cache/theme");
const PENDING = path.join(CACHE, "darkreader.pending");
const LIB = path.join(HOME, ".local/lib/dotfiles-node/node_modules/classic-level");

function thoriumRunning() {
    try { execFileSync("pgrep", ["-x", "thorium"], { stdio: "ignore" }); return true; } catch { return false; }
}

function readPalette() {
    const out = {};
    for (const line of fs.readFileSync(path.join(CACHE, "current.theme"), "utf8").split("\n")) {
        const m = line.match(/^(\w+)=(#[0-9a-fA-F]{6})$/);
        if (m) out[m[1]] = m[2].toLowerCase();
    }
    if (!out.bg || !out.fg || !out.accent) throw new Error("incomplete ~/.cache/theme/current.theme");
    return out;
}

function blend(c1, c2, weight) { // like blend_hex in apply-theme.sh: weight = % of c2
    const a = [1, 3, 5].map((i) => parseInt(c1.slice(i, i + 2), 16));
    const b = [1, 3, 5].map((i) => parseInt(c2.slice(i, i + 2), 16));
    return "#" + a.map((v, i) => Math.round((v * (100 - weight) + b[i] * weight) / 100).toString(16).padStart(2, "0")).join("");
}

async function apply() {
    if (!fs.existsSync(DB_DIR)) return "Dark Reader not installed (yet): skipped";
    const { bg, fg, accent } = readPalette();
    const { ClassicLevel } = require(LIB);
    const db = new ClassicLevel(DB_DIR, { keyEncoding: "utf8", valueEncoding: "utf8" });
    await db.open({ createIfMissing: false });
    try {
        let theme = {};
        try { theme = JSON.parse(await db.get("theme")) || {}; } catch { /* not saved yet: defaults */ }
        Object.assign(theme, {
            mode: 1, // dark
            darkSchemeBackgroundColor: bg,
            darkSchemeTextColor: fg,
            selectionColor: blend(bg, accent, 28),   // BG_VISUAL
            scrollbarColor: blend(bg, fg, 8),        // BG_ALT
        });
        await db.batch([
            { type: "put", key: "theme", value: JSON.stringify(theme) },
            { type: "put", key: "syncSettings", value: "false" },
        ]);
    } finally {
        await db.close();
    }
    return `Dark Reader colors set (background ${bg}, text ${fg})`;
}

(async () => {
    const cmd = process.argv[2];
    if (cmd !== "apply" && cmd !== "pending") {
        console.error("usage: darkreader-theme.js apply|pending");
        process.exit(1);
    }
    if (cmd === "pending" && !fs.existsSync(PENDING)) return;
    if (thoriumRunning()) {
        fs.mkdirSync(CACHE, { recursive: true });
        fs.writeFileSync(PENDING, "");
        console.log("Thorium is running: Dark Reader colors are applied at its next start");
        return;
    }
    const msg = await apply();
    // Not installed yet: keep it pending so the colors land once it is
    if (msg.startsWith("Dark Reader colors set")) fs.rmSync(PENDING, { force: true });
    else fs.writeFileSync(PENDING, "");
    console.log(msg);
})().catch((err) => {
    console.error("darkreader-theme:", err.message);
    process.exit(0); // never block a theme switch or Thorium's start
});

# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/20-appimages.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 4. AppImages: Neovim, Obsidian & Thorium Browser
# ==========================================
log "Downloading and configuring AppImages..."
APPIMAGE_DIR="$HOME/appimages"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOCAL_BIN"

# Every GitHub download below is verified against GitHub's published SHA-256 checksum
# (scripts/lib/github-download.sh, sourced at the top)

# --- NEOVIM (install, or update when a newer release exists) ---
NVIM_CURRENT=""
[ -x "$APPIMAGE_DIR/nvim.appimage" ] && NVIM_CURRENT=$("$APPIMAGE_DIR/nvim.appimage" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
NVIM_RC=0
gh_check_update "neovim/neovim" '^nvim-linux-x86_64\.appimage$' "$NVIM_CURRENT" || NVIM_RC=$?
if [ "$NVIM_RC" -eq 0 ]; then
    info "Installing Neovim $GH_LATEST_VERSION (installed: ${NVIM_CURRENT:-none})..."
    if gh_download_verified "$GH_URL" "$GH_DIGEST" "$APPIMAGE_DIR/nvim.appimage"; then
        chmod u+x "$APPIMAGE_DIR/nvim.appimage"
        ok "Neovim $GH_LATEST_VERSION installed."
    else
        warn "Neovim could not be installed/updated (continuing setup)."
    fi
elif [ "$NVIM_RC" -eq 1 ]; then
    ok "Neovim is up to date ($NVIM_CURRENT)."
else
    warn "Could not check for Neovim updates (offline or GitHub API limit)."
fi
[ -x "$APPIMAGE_DIR/nvim.appimage" ] && ln -sfn "$APPIMAGE_DIR/nvim.appimage" "$LOCAL_BIN/nvim"

# --- OBSIDIAN (LATEST, NO ARM64) ---
if [ ! -f "$APPIMAGE_DIR/obsidian.appimage" ]; then
    info "Fetching latest Obsidian release (checksum-verified)..."
    if gh_install_latest "obsidianmd/obsidian-releases" '^Obsidian-[0-9.]+\.AppImage$' "$APPIMAGE_DIR/obsidian.appimage"; then
        chmod u+x "$APPIMAGE_DIR/obsidian.appimage"
        ok "Obsidian installed."
    else
        warn "Obsidian could not be installed (continuing setup)."
    fi
else
    ok "Obsidian is already installed."
fi
# `obsidian` in a terminal = today's daily note in Neovim; `obsidian-app` (and Rofi) = the app.
# Sync while the app is closed: Obsidian Headless (scripts/obsidian-sync.sh daemon, started by i3)
ln -sfn "$DOTFILES_DIR/scripts/obsidian-tui.sh" "$LOCAL_BIN/obsidian"
ln -sfn "$DOTFILES_DIR/scripts/obsidian-app.sh" "$LOCAL_BIN/obsidian-app"

# Create the .desktop entry for Rofi. No --no-sandbox: Debian 13 allows unprivileged user
# namespaces, so Electron's sandbox works inside the AppImage.
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/obsidian.desktop"
[Desktop Entry]
Name=Obsidian
Exec=$HOME/.local/bin/obsidian-app %U
Terminal=false
Type=Application
Icon=obsidian
StartupWMClass=md.obsidian.Obsidian
Comment=Obsidian Markdown Note-taking
Categories=Office;
MimeType=x-scheme-handler/obsidian;
EOF

# Icons from the AppImage itself (Icon=obsidian), so the launcher doesn't depend on a .deb install
if [ -f "$APPIMAGE_DIR/obsidian.appimage" ] && [ ! -f "$HOME/.local/share/icons/hicolor/256x256/apps/obsidian.png" ]; then
    OBS_TMP=$(mktemp -d)
    TMP_PATHS+=("$OBS_TMP")
    obsidian_icons() {
        (cd "$OBS_TMP" && "$APPIMAGE_DIR/obsidian.appimage" --appimage-extract 'usr/share/icons/*' >/dev/null 2>&1) \
            && mkdir -p "$HOME/.local/share/icons" \
            && cp -r "$OBS_TMP/squashfs-root/usr/share/icons/hicolor" "$HOME/.local/share/icons/" 2>/dev/null
    }
    try "Extracting the Obsidian icons" obsidian_icons
fi
# obsidian:// links (Sync login, "Open in Obsidian") go to the AppImage
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || warn "update-desktop-database failed (continuing)."
try "Registering obsidian:// links" xdg-mime default obsidian.desktop x-scheme-handler/obsidian

# --- THORIUM BROWSER (NEWEST VERIFIED AVX2 / SSE4 APPIMAGE + EXTENSIONS + GTK THEME) ---
# update-thorium.sh installs or updates to the newest checksum-verified build (also runs at i3 login)
bash "$DOTFILES_DIR/scripts/update-thorium.sh" || warn "Thorium could not be installed/updated (continuing setup)."

# Create the .desktop entry for Thorium in Rofi
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/thorium.desktop"
[Desktop Entry]
Name=Thorium Browser
GenericName=Web Browser
Exec=$DOTFILES_DIR/scripts/thorium-launch.sh --no-default-browser-check %U
Terminal=false
Type=Application
Icon=thorium
StartupWMClass=thorium
Comment=Thorium High-Performance Web Browser
Categories=Network;WebBrowser;
EOF

# Discord: web app in its own Thorium profile (scripts/discord.sh). The profile is created at
# first launch in ~/.local/share/discord-web, outside the repo.
ln -sfn "$DOTFILES_DIR/scripts/discord.sh" "$LOCAL_BIN/discord"
cat <<EOF > "$HOME/.local/share/applications/discord-web.desktop"
[Desktop Entry]
Name=Discord
Exec=$DOTFILES_DIR/scripts/discord.sh
Terminal=false
Type=Application
Icon=discord
StartupWMClass=discord-web
Comment=Discord web app in an isolated Thorium profile
Categories=Network;Chat;
Keywords=discord;chat;voice;bellen;
EOF

# Configure automatic installation of latest Chrome Web Store extensions for Thorium:
# 1. Thorium Material Dark Theme (dahfohiipmpcppjbablgfoggbogdmddp)
# 2. Bitwarden Password Manager  (nngceckbapebfimnlniiiahkandclblb)
# 3. Ghostery Tracker/Ad Blocker (mlomiejdfkolichcflejclcbmpeaniij)
# 4. Vimium Keyboard Navigation  (dbepggeogbaibhgnhhndojpepiihcmeb)
# 5. Dark Reader                 (eimadpbcbfnmbkopoojfekhnkhdbieeh)
THORIUM_EXT_IDS=(
    "dahfohiipmpcppjbablgfoggbogdmddp"
    "nngceckbapebfimnlniiiahkandclblb"
    "mlomiejdfkolichcflejclcbmpeaniij"
    "dbepggeogbaibhgnhhndojpepiihcmeb"
    "eimadpbcbfnmbkopoojfekhnkhdbieeh"
)

# Force-install policy, built from the list above (one place to add an extension)
sudo mkdir -p /etc/chromium/policies/managed /etc/opt/chrome/policies/managed
printf '%s\n' "${THORIUM_EXT_IDS[@]}" \
    | jq -R '. + ";https://clients2.google.com/service/update2/crx"' | jq -s '{ExtensionInstallForcelist: .}' \
    | sudo tee /etc/chromium/policies/managed/thorium_extensions.json /etc/opt/chrome/policies/managed/thorium_extensions.json >/dev/null

# Memory Saver: tabs you haven't used for a while are put to sleep and reload when you click them.
# MemorySaverModeSavings: 0 moderate, 1 balanced, 2 maximum. Chromium only allows these as managed
# (fixed) policies, so the toggle in thorium://settings/performance is locked; change it here.
sudo tee /etc/chromium/policies/managed/thorium_performance.json /etc/opt/chrome/policies/managed/thorium_performance.json >/dev/null <<EOF
{
  "HighEfficiencyModeEnabled": true,
  "MemorySaverModeSavings": 1
}
EOF

mkdir -p "$HOME/.config/thorium/External Extensions"
for ext_id in "${THORIUM_EXT_IDS[@]}"; do
    cat <<EOF > "$HOME/.config/thorium/External Extensions/${ext_id}.json"
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF
done

# Bootstrap Thorium Default Preferences to use GTK+ theme colors from the Color Engine (lib/bootstrap.sh)
thorium_bootstrap_prefs

# Thorium default web fonts -> generic families. Fontconfig maps those to the active font module
# ($mod+Shift+f), so web pages follow the font picker without touching Thorium again.
# Thorium rewrites Preferences on exit, so this only runs while Thorium is closed.
THORIUM_PREFS="$HOME/.config/thorium/Default/Preferences"
if [ -f "$THORIUM_PREFS" ] && ! pgrep -x thorium >/dev/null; then
    THORIUM_TMP=$(mktemp "$THORIUM_PREFS.XXXXXX")
    TMP_PATHS+=("$THORIUM_TMP")
    if jq '.webkit.webprefs.fonts = ((.webkit.webprefs.fonts // {}) + {
            "standard":  {"Zyyy": "sans-serif"},
            "sansserif": {"Zyyy": "sans-serif"},
            "serif":     {"Zyyy": "serif"},
            "fixed":     {"Zyyy": "monospace"}
        })' "$THORIUM_PREFS" > "$THORIUM_TMP"; then
        mv "$THORIUM_TMP" "$THORIUM_PREFS"
        ok "Thorium default web fonts follow the active font."
    else
        rm -f "$THORIUM_TMP"
    fi
elif pgrep -x thorium >/dev/null; then
    warn "Thorium is running: close it and re-run setup.sh to set its default web fonts."
fi


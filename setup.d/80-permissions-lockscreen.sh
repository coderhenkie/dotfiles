# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/80-permissions-lockscreen.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 8. Set Executable Permissions & Screen Lock CLI
# ==========================================
log "Setting executable permissions on scripts..."

if [ -f "$DOTFILES_DIR/polybar/launch.sh" ]; then
    chmod +x "$DOTFILES_DIR/polybar/launch.sh"
fi

chmod +x "$DOTFILES_DIR/scripts/"*.sh
[ -f "$DOTFILES_DIR/autorandr/postswitch" ] && chmod +x "$DOTFILES_DIR/autorandr/postswitch"
# autorandr hotplug: udev triggers this service on every plug/unplug (HDMI, dock, lid).
# Without saved profiles it falls back to autorandr/default -> common (mirror all screens).
sudo systemctl enable autorandr.service >/dev/null 2>&1 || warn "autorandr.service could not be enabled (continuing setup)."

# Multiple screens: ask which one is left / (middle) / right and save it as autorandr profile `main`
# (scripts/monitor-layout.sh, re-run it any time). Needs the X session, so it is skipped from a TTY.
if [ -n "${DISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
    log "Detecting screens..."
    bash "$DOTFILES_DIR/scripts/monitor-layout.sh" || warn "Monitor layout skipped (continuing setup)."
else
    warn "No X session: arrange multiple screens later with $DOTFILES_DIR/scripts/monitor-layout.sh"
fi

log "Adding the dotfiles tools to Rofi (font picker, themes, clipboard, ...)..."
try "Adding the Rofi entries" bash "$DOTFILES_DIR/scripts/desktop-entries.sh"

log "Setting default applications (Thorium, Zathura, imv, mpv, Thunar)..."
try "Setting the default applications" bash "$DOTFILES_DIR/scripts/default-apps.sh"

# ==========================================
# 8.5 LightDM & light-locker Color Engine Integration
# ==========================================
log "Configuring LightDM GTK Greeter and light-locker for Color Engine..."
try "Lock screen setup" bash "$DOTFILES_DIR/scripts/lockscreen-setup.sh"

# Auto-suspend after 30 min locked (scripts/lock-suspend.sh). A locked session is inactive for
# logind, which then asks for an admin password to suspend; this rule lets only this user suspend
# from a local session without one. Bare metal only: VMs never auto-suspend.
if machine_is_vm; then
    ok "$(machine_type) detected: skipping auto-suspend polkit rule."
else
    log "Bare metal detected: allowing suspend while locked (polkit rule)..."
    sudo tee /etc/polkit-1/rules.d/50-lock-suspend.rules >/dev/null <<POLKIT
// Managed by the dotfiles setup.sh: lets $USER suspend while the screen is locked (lock-suspend.sh)
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions") &&
        subject.user == "$USER" && subject.local) {
        return polkit.Result.YES;
    }
});
POLKIT
fi


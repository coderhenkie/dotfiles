# shellcheck shell=bash disable=SC2154  # variables come from apply-theme.sh and the earlier parts
# scripts/theme.d/05-gtk-lightdm-icons.sh: part of apply-theme.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 5. Thunar / GTK3 CSS, Thorium Browser, LightDM Greeter & Dynamic Folder Icons
# ==========================================
mkdir -p "$HOME/.config/gtk-3.0"
cat <<EOF > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=ColorEngine
gtk-icon-theme-name=ColorEngine
gtk-font-name=$FONT_UI 10
EOF

cat <<EOF > "$CACHE_DIR/gtk.css"
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");

* { font-family: "$FONT_UI"; }

@define-color theme_bg_color $BG_ALT;
@define-color theme_fg_color $FG;
@define-color theme_base_color $BG;
@define-color theme_text_color $FG;
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $BG;
@define-color theme_unfocused_bg_color $BG_ALT;
@define-color theme_unfocused_text_color $FG_MUTED;
@define-color borders $BG_VISUAL;
@define-color lightdm_bg_color $BG;
@define-color lightdm_fg_color $FG;
@define-color error_bg_color $ANSI_RED;
@define-color error_fg_color $BG;
@define-color warning_bg_color $ANSI_YELLOW;
@define-color warning_fg_color $BG;

/* Tell lightdm-gtk-greeter to drop its built-in default colors to FALLBACK priority,
 * otherwise they are applied at APPLICATION priority and override this theme. */
@define-color lightdm-gtk-greeter-override-defaults $ACCENT;

/* Color symbolic sidebar icons in Thunar with the accent color */
.sidebar image,
placessidebar image {
    color: $ACCENT;
}

/* GTK3 Headerbar / Toolbar styling for Thorium Browser (GTK+ Theme Mode) */
headerbar,
.titlebar,
menubar,
toolbar {
    background-color: $BG;
    color: $FG;
}

headerbar:backdrop,
.titlebar:backdrop {
    background-color: $BG_ALT;
    color: $FG_MUTED;
}

selection {
    background-color: $ACCENT;
    color: $BG;
}

/* ==========================================
 * LightDM GTK Greeter & light-locker Styling
 * ========================================== */
/* Screen overlay: keep transparent so the synced wallpaper stays visible */
.lightdm-gtk-greeter {
    background-color: transparent;
    color: $FG;
}

/* Top panel bar (matches Polybar) */
#panel_window {
    background-color: alpha($BG, 0.88);
    color: $FG;
    border-bottom: 2px solid $ACCENT;
    box-shadow: none;
}

#panel_window #menubar,
#panel_window menubar,
#panel_window .menubar,
#panel_window menubar > menuitem,
#panel_window .menubar > .menuitem {
    background-color: transparent;
    color: $FG;
    font-weight: bold;
    border: none;
    box-shadow: none;
    text-shadow: none;
}

#panel_window menubar > separator {
    background: transparent;
}

#panel_window menu,
#panel_window .menu,
#login_window menu,
#login_window .menu {
    background-color: $BG_ALT;
    color: $FG;
    border: 2px solid $ACCENT;
    border-radius: 4px;
}

#panel_window menu menuitem,
#login_window menu menuitem {
    color: $FG;
}

#panel_window menu menuitem:hover,
#login_window menu menuitem:hover {
    background-color: $ACCENT;
    color: $BG;
}

/* Login / Unlock dialog and power dialog (3px accent border + 4px radius matching i3 & picom) */
#login_window,
#power_window,
#shutdown_dialog,
#restart_dialog {
    background-color: alpha($BG, 0.91);
    color: $FG;
    border: 3px solid $ACCENT;
    border-radius: 4px;
    box-shadow: 0 8px 24px alpha(#000000, 0.6);
}

#content_frame {
    background-color: transparent;
    color: $FG;
    border: none;
    padding-bottom: 14px;
}

#buttonbox_frame {
    background-color: $BG_ALT;
    background-image: none;
    color: $FG;
    border-top: 1px solid $BG_VISUAL;
    border-bottom-left-radius: 4px;
    border-bottom-right-radius: 4px;
    padding-top: 16px;
    box-shadow: none;
}

#user_image_border {
    background-color: $BG_ALT;
    background-image: none;
    border: 2px solid $ACCENT;
    border-radius: 4px;
    box-shadow: none;
}

#user_image {
    padding: 4px;
    border-radius: 4px;
    box-shadow: none;
}

#login_window #user_combobox,
#login_window #user_combobox button {
    background-color: $BG_ALT;
    background-image: none;
    color: $FG;
    border: 1px solid $BG_VISUAL;
    border-radius: 4px;
    box-shadow: none;
}

#login_window entry,
#login_window .entry,
#prompt_entry {
    background-color: $BG_ALT;
    background-image: none;
    color: $FG;
    caret-color: $ACCENT;
    border: 2px solid $BG_VISUAL;
    border-radius: 4px;
    padding: 6px 10px;
    box-shadow: none;
}

#login_window entry:focus,
#login_window .entry:focus,
#prompt_entry:focus {
    border-color: $ACCENT;
    box-shadow: none;
}

#login_window entry selection,
#prompt_entry selection {
    background-color: $ACCENT;
    color: $BG;
}

#login_window button,
#power_window button,
#cancel_button,
#power_cancel_button {
    background-color: $BG_ALT;
    background-image: none;
    color: $FG;
    border: 2px solid $BG_VISUAL;
    border-radius: 4px;
    padding: 6px 16px;
    box-shadow: none;
    text-shadow: none;
}

#login_button,
#power_ok_button,
#login_window button.default,
#power_window button.default {
    background-color: $ACCENT;
    background-image: none;
    color: $BG;
    font-weight: bold;
    border: 2px solid $ACCENT;
    border-radius: 4px;
    box-shadow: none;
    text-shadow: none;
}

#login_button:hover,
#power_ok_button:hover,
#login_window button:hover,
#power_window button:hover {
    background-color: $ACCENT_SOFT;
    border-color: $ACCENT_SOFT;
    color: $BG;
}

#greeter_infobar {
    background-color: $ANSI_RED;
    color: $BG;
    border: none;
    font-weight: bold;
}

#greeter_infobar #message_label,
#greeter_infobar label {
    color: $BG;
    font-weight: bold;
}
EOF
ln -sf "$CACHE_DIR/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

# User-level ColorEngine GTK3 theme
USER_THEME_DIR="$HOME/.themes/ColorEngine"
mkdir -p "$USER_THEME_DIR/gtk-3.0"
cat <<EOF > "$USER_THEME_DIR/index.theme"
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=ColorEngine
Comment=Dynamic Color Engine GTK3 & LightDM Theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=ColorEngine
IconTheme=ColorEngine
Font=$FONT_UI 10
EOF
ln -sf "$CACHE_DIR/gtk.css" "$USER_THEME_DIR/gtk-3.0/gtk.css"

# Resolve active feh wallpaper from ~/.fehbg (bootstrap if missing)
DEFAULT_WALLPAPER="$DOTFILES_DIR/wallpapers/background.jpg"
if [ ! -f "$HOME/.fehbg" ] && [ -f "$DEFAULT_WALLPAPER" ]; then
    cat <<EOF > "$HOME/.fehbg"
#!/bin/sh
feh --no-fehbg --bg-fill '$DEFAULT_WALLPAPER'
EOF
    chmod +x "$HOME/.fehbg"
fi

WALLPAPER_PATH=""
if [ -f "$HOME/.fehbg" ]; then
    WALLPAPER_PATH=$(sed -n "s/.*'\([^']*\)'.*/\1/p" "$HOME/.fehbg" | head -n 1 || true)
fi
if [ -z "$WALLPAPER_PATH" ] || [ ! -f "$WALLPAPER_PATH" ]; then
    WALLPAPER_PATH="$DEFAULT_WALLPAPER"
fi

if [ -f "$WALLPAPER_PATH" ]; then
    cp -f "$WALLPAPER_PATH" "$CACHE_DIR/lock-wallpaper"
    chmod 644 "$CACHE_DIR/lock-wallpaper"
fi

# Sync ColorEngine GTK3 theme and active feh wallpaper to /usr/share/themes/ColorEngine for LightDM & light-locker
SYSTEM_THEME_DIR="/usr/share/themes/ColorEngine"
if [ -d "$SYSTEM_THEME_DIR" ] && [ -w "$SYSTEM_THEME_DIR" ]; then
    mkdir -p "$SYSTEM_THEME_DIR/gtk-3.0"
    cp -f "$USER_THEME_DIR/index.theme" "$SYSTEM_THEME_DIR/index.theme"
    cp -f "$CACHE_DIR/gtk.css" "$SYSTEM_THEME_DIR/gtk-3.0/gtk.css"
    chmod 644 "$SYSTEM_THEME_DIR/index.theme" "$SYSTEM_THEME_DIR/gtk-3.0/gtk.css"
    if [ -f "$CACHE_DIR/lock-wallpaper" ]; then
        cp -f "$CACHE_DIR/lock-wallpaper" "$SYSTEM_THEME_DIR/wallpaper"
        chmod 644 "$SYSTEM_THEME_DIR/wallpaper"
    fi
fi

# Ensure Thorium Browser is configured to inherit GTK+ theme colors (first run only; lib/bootstrap.sh)
thorium_bootstrap_prefs

# Dynamic Icon Theme (ColorEngine) for Thunar folders & LightDM Greeter
ICON_DIR="$HOME/.local/share/icons/ColorEngine"
mkdir -p "$ICON_DIR/scalable/places" "$ICON_DIR/scalable/status" "$ICON_DIR/16x16/places" "$ICON_DIR/16x16/status"

cat <<EOF > "$ICON_DIR/index.theme"
[Icon Theme]
Name=ColorEngine
Comment=Dynamic Color Engine Folder Icons (inherits from Adwaita)
Inherits=Adwaita,AdwaitaLegacy,hicolor
Directories=scalable/places,scalable/status,16x16/places,16x16/status

[scalable/places]
Context=Places
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/status]
Context=Status
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[16x16/places]
Context=Places
Size=16
MinSize=8
MaxSize=512
Type=Scalable

[16x16/status]
Context=Status
Size=16
MinSize=8
MaxSize=512
Type=Scalable
EOF

# Shades for the folder back, base, front, and highlight
FOLDER_BACK=$(blend_hex "$BG" "$ACCENT" 65)
FOLDER_BASE="$ACCENT_DIM"
FOLDER_FRONT="$ACCENT"
FOLDER_SHINE=$(blend_hex "$FG" "$ACCENT" 45)

if [ -d "/usr/share/icons/Adwaita/scalable/places" ]; then
    for svg in /usr/share/icons/Adwaita/scalable/places/folder*.svg \
               /usr/share/icons/Adwaita/scalable/places/user-home.svg \
               /usr/share/icons/Adwaita/scalable/places/user-desktop.svg \
               /usr/share/icons/Adwaita/scalable/places/user-bookmarks.svg; do
        [ -f "$svg" ] || continue
        fname=$(basename "$svg")
        sed -e "s/#438de6/$FOLDER_BACK/gI" \
            -e "s/#62a0ea/$FOLDER_BASE/gI" \
            -e "s/#a4caee/$FOLDER_FRONT/gI" \
            -e "s/#afd4ff/$FOLDER_SHINE/gI" \
            -e "s/#c0d5ea/$ACCENT_SOFT/gI" \
            "$svg" > "$ICON_DIR/scalable/places/$fname"
        ln -sf "../../scalable/places/$fname" "$ICON_DIR/16x16/places/$fname"
    done
fi

if [ -f "/usr/share/icons/Adwaita/scalable/status/folder-open.svg" ]; then
    sed -e "s/#438de6/$FOLDER_BACK/gI" \
        -e "s/#62a0ea/$FOLDER_BASE/gI" \
        -e "s/#a4caee/$FOLDER_FRONT/gI" \
        -e "s/#afd4ff/$FOLDER_SHINE/gI" \
        -e "s/#c0d5ea/$ACCENT_SOFT/gI" \
        "/usr/share/icons/Adwaita/scalable/status/folder-open.svg" > "$ICON_DIR/scalable/status/folder-open.svg"
    ln -sf "../../scalable/status/folder-open.svg" "$ICON_DIR/16x16/status/folder-open.svg"
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true
fi

# Sync ColorEngine icons to /usr/share/icons/ColorEngine for LightDM & light-locker
SYSTEM_ICON_DIR="/usr/share/icons/ColorEngine"
if [ -d "$SYSTEM_ICON_DIR" ] && [ -w "$SYSTEM_ICON_DIR" ]; then
    cp -rf "$ICON_DIR/"* "$SYSTEM_ICON_DIR/"
    chmod -R a+rX "$SYSTEM_ICON_DIR"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$SYSTEM_ICON_DIR" >/dev/null 2>&1 || true
    fi
fi


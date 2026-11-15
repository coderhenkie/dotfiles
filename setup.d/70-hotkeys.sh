# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/70-hotkeys.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# Migrate existing hotkeys.conf files: the Rofi tools were renamed to scripts/menu-*.sh
# (must run before the migrations below, which look for the new names)
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ]; then
    sed -i -E \
        -e 's#scripts/theme-selector\.sh#scripts/menu-theme.sh#g' \
        -e 's#scripts/ai-theme\.sh#scripts/menu-wallpaper.sh#g' \
        -e 's#scripts/font-picker\.sh#scripts/menu-font.sh#g' \
        -e 's#scripts/hotkey-menu\.sh#scripts/menu-hotkeys.sh#g' \
        -e 's#scripts/power-menu\.sh#scripts/menu-power.sh#g' \
        -e 's#scripts/clipboard\.sh#scripts/menu-clipboard.sh#g' \
        -e 's#scripts/calculator\.sh#scripts/menu-calc.sh#g' \
        -e 's#scripts/emoji\.sh#scripts/menu-emoji.sh#g' \
        -e 's#scripts/notifications\.sh#scripts/menu-notifications.sh#g' \
        "$DOTFILES_DIR/i3/hotkeys.conf"
fi

# Initialize local i3 hotkeys.conf from hotkeys.default only on first install
if [ ! -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && [ -f "$DOTFILES_DIR/i3/hotkeys.default" ]; then
    cp "$DOTFILES_DIR/i3/hotkeys.default" "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Initialized i3/hotkeys.conf from hotkeys.default."
elif [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/lock.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/menu-hotkeys\.sh/a bindsym $mod+Shift+x exec --no-startup-id ~/dotfiles/scripts/lock.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added screen lock hotkey (\$mod+Shift+x) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the area screenshot hotkey once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/screenshot.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i '/scripts\/lock\.sh/a bindsym Control+Shift+s exec --no-startup-id ~/dotfiles/scripts/screenshot.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added screenshot hotkey (Control+Shift+s) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the notification hotkeys once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-notifications.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/scripts\/lock\.sh/a bindsym $mod+n exec --no-startup-id ~/dotfiles/scripts/menu-notifications.sh toggle\nbindsym $mod+Shift+n exec --no-startup-id ~/dotfiles/scripts/menu-notifications.sh menu' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added notification hotkeys (\$mod+n / \$mod+Shift+n) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the font picker once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-font.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/scripts\/lock\.sh/a bindsym $mod+Shift+f exec --no-startup-id ~/dotfiles/scripts/menu-font.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added font picker hotkey (\$mod+Shift+f) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the UI scale hotkeys once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/ui-scale.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/scripts\/menu-font\.sh/a bindsym $mod+Shift+equal exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh up\nbindsym $mod+Shift+minus exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh down\nbindsym $mod+Shift+KP_Add exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh up\nbindsym $mod+Shift+KP_Subtract exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh down\nbindsym $mod+Shift+BackSpace exec --no-startup-id ~/dotfiles/scripts/ui-scale.sh reset' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added UI scale hotkeys (\$mod+Shift+plus / minus / BackSpace) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: volume keys step 5% instead of 10%
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && grep -Fq 'set-sink-volume @DEFAULT_SINK@ +10%' "$DOTFILES_DIR/i3/hotkeys.conf"; then
    sed -i 's/set-sink-volume @DEFAULT_SINK@ +10%/set-sink-volume @DEFAULT_SINK@ +5%/; s/set-sink-volume @DEFAULT_SINK@ -10%/set-sink-volume @DEFAULT_SINK@ -5%/' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Volume keys now step 5% in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: power menu replaces the i3-nagbar exit prompt
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-power.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i 's|^bindsym \$mod+Shift+e exec "i3-nagbar.*$|bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/menu-power.sh|' "$DOTFILES_DIR/i3/hotkeys.conf"
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    grep -Fq "scripts/menu-power.sh" "$DOTFILES_DIR/i3/hotkeys.conf" \
        || echo 'bindsym $mod+Shift+e exec --no-startup-id ~/dotfiles/scripts/menu-power.sh' >> "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Power menu bound to \$mod+Shift+e in existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the monitor menu (mirror / extend) once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-monitors.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/scripts\/lock\.sh/a bindsym $mod+p exec --no-startup-id ~/dotfiles/scripts/menu-monitors.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added monitor menu hotkey (\$mod+p) to existing i3/hotkeys.conf."
fi

# Migrate existing hotkeys.conf files: add the Rofi tools (clipboard, calculator, emoji) once
if [ -f "$DOTFILES_DIR/i3/hotkeys.conf" ] && ! grep -Fq "scripts/menu-clipboard.sh" "$DOTFILES_DIR/i3/hotkeys.conf"; then
    # shellcheck disable=SC2016  # $HOME/$PATH/$mod are written literally into a config file
    sed -i '/scripts\/lock\.sh/a bindsym $mod+c exec --no-startup-id ~/dotfiles/scripts/menu-clipboard.sh menu\nbindsym $mod+equal exec --no-startup-id ~/dotfiles/scripts/menu-calc.sh\nbindsym $mod+Shift+period exec --no-startup-id ~/dotfiles/scripts/menu-emoji.sh' "$DOTFILES_DIR/i3/hotkeys.conf"
    ok "Added clipboard (\$mod+c), calculator (\$mod+equal) and emoji (\$mod+Shift+period) hotkeys to existing i3/hotkeys.conf."
fi


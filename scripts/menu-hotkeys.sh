#!/usr/bin/env bash

# ==========================================
# i3 Hotkey Manager (Rofi)
# ==========================================
# Interactive Rofi menu to view, rebind (by pressing the key combo directly),
# or swap i3 hotkeys. Validates every change with 'i3 -C' and reloads i3 live.

set -u

I3_MAIN_CONFIG="$HOME/dotfiles/i3/config"
I3_DEFAULT_HOTKEYS="$HOME/dotfiles/i3/hotkeys.default"
I3_CONFIG="$HOME/dotfiles/i3/hotkeys.conf"

# Initialize hotkeys.conf from hotkeys.default if it does not exist yet
if [ ! -f "$I3_CONFIG" ] && [ -f "$I3_DEFAULT_HOTKEYS" ]; then
    cp "$I3_DEFAULT_HOTKEYS" "$I3_CONFIG"
fi

ROFI_MAIN='window { width: 45%; } listview { lines: 14; }'
ROFI_SUB='window { width: 42%; } listview { lines: 6; }'
ROFI_WAIT='window { width: 40%; } inputbar { enabled: false; } listview { lines: 1; }'

# Ensure DISPLAY and I3SOCK are set even if launched from terminal/SSH
export DISPLAY="${DISPLAY:-:0}"
if [ -z "${I3SOCK:-}" ]; then
    I3SOCK=$(ls "/run/user/$(id -u)/i3/"ipc-socket.* 2>/dev/null | head -n 1 || true)
    [ -n "$I3SOCK" ] && export I3SOCK
fi

# ==========================================
# Helper Functions
# ==========================================

rofi_menu() {
    local prompt="$1"
    local mesg="$2"
    local theme_str="${3:-$ROFI_MAIN}"
    local extra_args=("${@:4}")

    if [ -n "$mesg" ]; then
        rofi -dmenu -i -markup-rows -p "$prompt" -mesg "$mesg" -theme-str "$theme_str" "${extra_args[@]}"
    else
        rofi -dmenu -i -markup-rows -p "$prompt" -theme-str "$theme_str" "${extra_args[@]}"
    fi
}

rofi_error() {
    local msg="$1"
    printf "OK\n" | rofi_menu "Error" "$msg" "$ROFI_SUB" >/dev/null
}

reload_i3_safe() {
    if [ -n "${I3SOCK:-}" ] && [ -S "${I3SOCK:-}" ]; then
        i3-msg -s "$I3SOCK" reload >/dev/null 2>&1 || true
    else
        i3-msg reload >/dev/null 2>&1 || true
    fi
    # Short pause so i3 finishes re-grabbing keys before Rofi opens again
    sleep 0.15
}

get_current_mod() {
    if grep -Fq 'set $mod Mod4' "$I3_CONFIG"; then
        echo "Super (Mod4)"
    elif grep -Fq 'set $mod Mod1' "$I3_CONFIG"; then
        echo "Alt (Mod1)"
    else
        echo "Custom"
    fi
}

# Short, concise English descriptions for i3 actions
describe_action() {
    local mode="$1"
    local cmd="$2"
    local prefix=""
    if [ "$mode" != "default" ]; then
        prefix="[Resize] "
    fi

    case "$cmd" in
        *menu-theme.sh*)                     echo "${prefix}Theme selector" ;;
        *menu-wallpaper.sh*)                 echo "${prefix}AI wallpaper theme" ;;
        *menu-hotkeys.sh*)                   echo "${prefix}Hotkey menu" ;;
        *lock.sh*)                           echo "${prefix}Lock screen" ;;
        *screenshot.sh*)                     echo "${prefix}Screenshot (area)" ;;
        *menu-power.sh*)                     echo "${prefix}Power menu" ;;
        *menu-clipboard.sh*)                 echo "${prefix}Clipboard history" ;;
        *menu-calc.sh*)                      echo "${prefix}Calculator" ;;
        *menu-emoji.sh*)                     echo "${prefix}Emoji picker" ;;
        *menu-font.sh*)                      echo "${prefix}Font picker" ;;
        *"menu-notifications.sh toggle"*)    echo "${prefix}Silent mode (notifications)" ;;
        *"menu-notifications.sh menu"*)      echo "${prefix}Notification menu" ;;
        *toggle-modkey.sh*)                  echo "${prefix}Switch Mod key" ;;
        *"ui-scale.sh up"*)                  echo "${prefix}UI scale +10%" ;;
        *"ui-scale.sh down"*)                echo "${prefix}UI scale -10%" ;;
        *"ui-scale.sh reset"*)               echo "${prefix}UI scale reset (100%)" ;;
        "exec kitty")        echo "${prefix}Open terminal" ;;
        "kill")              echo "${prefix}Close window" ;;
        *"rofi -show drun"*)                 echo "${prefix}App launcher" ;;
        "focus left")        echo "${prefix}Focus left" ;;
        "focus down")        echo "${prefix}Focus down" ;;
        "focus up")          echo "${prefix}Focus up" ;;
        "focus right")       echo "${prefix}Focus right" ;;
        "move left")         echo "${prefix}Move window left" ;;
        "move down")         echo "${prefix}Move window down" ;;
        "move up")           echo "${prefix}Move window up" ;;
        "move right")        echo "${prefix}Move window right" ;;
        "split h")           echo "${prefix}Split horizontal" ;;
        "split v")           echo "${prefix}Split vertical" ;;
        "fullscreen toggle") echo "${prefix}Toggle fullscreen" ;;
        "layout stacking")   echo "${prefix}Layout: stacking" ;;
        "layout tabbed")     echo "${prefix}Layout: tabbed" ;;
        "layout toggle split") echo "${prefix}Layout: toggle split" ;;
        "floating toggle")   echo "${prefix}Toggle floating" ;;
        "focus mode_toggle") echo "${prefix}Focus tiling/floating" ;;
        "focus parent")      echo "${prefix}Focus parent" ;;
        "workspace number \$ws"*)
            local ws="${cmd##*\$ws}"
            echo "${prefix}Workspace $ws"
            ;;
        "move container to workspace number \$ws"*)
            local ws="${cmd##*\$ws}"
            echo "${prefix}Move to workspace $ws"
            ;;
        "reload")            echo "${prefix}Reload i3" ;;
        "restart")           echo "${prefix}Restart i3" ;;
        *"i3-nagbar"*)                       echo "${prefix}Exit i3" ;;
        'mode "resize"')     echo "${prefix}Enter resize mode" ;;
        'mode "default"')    echo "${prefix}Exit resize mode" ;;
        *"resize shrink width"*)             echo "${prefix}Shrink width" ;;
        *"resize grow height"*)              echo "${prefix}Grow height" ;;
        *"resize shrink height"*)            echo "${prefix}Shrink height" ;;
        *"resize grow width"*)               echo "${prefix}Grow width" ;;
        *"set-sink-volume"*+*) echo "${prefix}Volume up" ;;
        *"set-sink-volume"*-*) echo "${prefix}Volume down" ;;
        *"set-sink-mute"*)                   echo "${prefix}Mute audio" ;;
        *"set-source-mute"*)                 echo "${prefix}Mute mic" ;;
        *)
            local clean="${cmd#exec --no-startup-id }"
            clean="${clean#exec }"
            if [ "${#clean}" -gt 28 ]; then
                clean="${clean:0:25}..."
            fi
            echo "${prefix}${clean}"
            ;;
    esac
}

# Parse all bindsym lines from i3/config
# Output format: LINENO|MODE|KEY|CMD
parse_bindings() {
    awk '
    BEGIN { mode = "default" }
    /^[[:space:]]*mode[[:space:]]+"[^"]+"/ {
        if (match($0, /"[^"]+"/)) {
            m = substr($0, RSTART+1, RLENGTH-2)
            if ($0 ~ /\{/) mode = m
        }
        next
    }
    mode != "default" && /^[[:space:]]*\}/ {
        mode = "default"
        next
    }
    /^[[:space:]]*bindsym[[:space:]]+/ {
        line = $0
        sub(/^[[:space:]]*bindsym[[:space:]]+/, "", line)
        match(line, /^[^[:space:]]+/)
        key = substr(line, RSTART, RLENGTH)
        cmd = substr(line, RSTART + RLENGTH)
        sub(/^[[:space:]]+/, "", cmd)
        printf "%d|%s|%s|%s\n", NR, mode, key, cmd
    }
    ' "$I3_CONFIG"
}

# Validate and reload i3 config safely (automatic rollback on error)
apply_and_validate() {
    local backup_file="$1"
    local err_out
    if err_out=$(i3 -C -c "$I3_MAIN_CONFIG" 2>&1); then
        rm -f "$backup_file"
        reload_i3_safe
        return 0
    else
        cp "$backup_file" "$I3_CONFIG"
        rm -f "$backup_file"
        local short_err
        short_err=$(echo "$err_out" | grep -E "ERROR:" | head -n 2 | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        [ -z "$short_err" ] && short_err="Invalid key or i3 config syntax error."
        rofi_error "<b>Reverted change (invalid syntax):</b>\n<code>$short_err</code>"
        return 1
    fi
}

# Replace a specific line in i3/config by line number
replace_line_in_config() {
    local target_line="$1"
    local new_content="$2"
    local tmp_file
    tmp_file=$(mktemp)

    TARGET_LINE="$target_line" NEW_CONTENT="$new_content" awk '
    BEGIN {
        target = ENVIRON["TARGET_LINE"] + 0
        repl = ENVIRON["NEW_CONTENT"]
    }
    NR == target {
        match($0, /^[[:space:]]*/)
        indent = substr($0, RSTART, RLENGTH)
        print indent repl
        next
    }
    { print $0 }
    ' "$I3_CONFIG" > "$tmp_file"
    mv "$tmp_file" "$I3_CONFIG"
    chmod 644 "$I3_CONFIG"
}

# Delete a specific line in i3/config by line number
delete_line_in_config() {
    local target_line="$1"
    sed -i "${target_line}d" "$I3_CONFIG"
}

# ==========================================
# Live Key-Combo Capture via X11 + Rofi Popup
# ==========================================
capture_key_combo() {
    local desc="$1"
    local old_key="$2"
    local mode="$3"
    local mod_var="Mod1"
    if grep -Fq 'set $mod Mod4' "$I3_CONFIG"; then
        mod_var="Mod4"
    fi

    local safe_desc="${desc//&/&amp;}"
    safe_desc="${safe_desc//</&lt;}"
    safe_desc="${safe_desc//>/&gt;}"
    local safe_old="${old_key//&/&amp;}"
    safe_old="${safe_old//</&lt;}"
    safe_old="${safe_old//>/&gt;}"

    local msg="<b>$safe_desc</b>  (current: <b>$safe_old</b>)\nPress a single key or key combo now  │  <b>Esc</b> to exit"

    # Show Rofi popup holding active X11 keyboard grab so i3 does not intercept $mod+<key>
    printf "  Listening for key press...\n" | rofi -dmenu -markup-rows \
        -kb-accept-entry "" -kb-accept-custom "" -kb-cancel "" \
        -p "Press Key" -mesg "$msg" -theme-str "$ROFI_WAIT" >/dev/null 2>&1 &
    local rofi_pid=$!

    local captured
    captured=$(ROFI_PID="$rofi_pid" TARGET_MODE="$mode" MOD_VAR="$mod_var" python3 -c '
import ctypes, os, signal, sys, time

rofi_pid = int(os.environ.get("ROFI_PID", "0"))
mod_var = os.environ.get("MOD_VAR", "Mod1")

x11 = ctypes.CDLL("libX11.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XQueryKeymap.argtypes = [ctypes.c_void_p, ctypes.c_char * 32]
x11.XKeycodeToKeysym.restype = ctypes.c_ulong
x11.XKeycodeToKeysym.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int]
x11.XKeysymToString.restype = ctypes.c_char_p
x11.XKeysymToString.argtypes = [ctypes.c_ulong]

dpy = x11.XOpenDisplay(None)
if not dpy:
    if rofi_pid > 0:
        try:
            os.kill(rofi_pid, signal.SIGTERM)
        except OSError:
            pass
    sys.exit(1)

MOD_NAMES = {
    "Shift_L": "Shift", "Shift_R": "Shift",
    "Control_L": "Control", "Control_R": "Control",
    "Alt_L": "Mod1", "Alt_R": "Mod1", "Meta_L": "Mod1", "Meta_R": "Mod1",
    "Super_L": "Mod4", "Super_R": "Mod4",
    "ISO_Level3_Shift": "Mod5", "Mode_switch": "Mod5",
    "Num_Lock": "Ignore", "Scroll_Lock": "Ignore", "Shift_Lock": "Ignore"
}

kc_to_name = {}
for kc in range(8, 256):
    ks = x11.XKeycodeToKeysym(dpy, kc, 0)
    if ks:
        s = x11.XKeysymToString(ks)
        if s:
            kc_to_name[kc] = s.decode("utf-8", errors="ignore")

def get_pressed(buf):
    x11.XQueryKeymap(dpy, buf)
    raw = bytes(buf)
    pressed = []
    for kc, name in kc_to_name.items():
        if raw[kc >> 3] & (1 << (kc & 7)):
            pressed.append(name)
    return pressed

buf = (ctypes.c_char * 32)()

# 1. Wait until the Enter/Return key from selecting the menu item is released
t0 = time.time()
while time.time() - t0 < 5.0:
    pressed = get_pressed(buf)
    non_mods = [k for k in pressed if k not in MOD_NAMES]
    if not non_mods:
        break
    time.sleep(0.01)

# 2. Poll for the new single key or key combination
result = ""
while True:
    if rofi_pid > 0:
        try:
            os.kill(rofi_pid, 0)
        except OSError:
            break

    pressed = get_pressed(buf)
    mods_held = set()
    non_mods = []
    for k in pressed:
        if k in MOD_NAMES:
            m = MOD_NAMES[k]
            if m != "Ignore":
                mods_held.add(m)
        else:
            non_mods.append(k)

    if non_mods:
        key = non_mods[0]
        # Esc or Caps_Lock (swapped Esc) without modifiers always exits the hotkey menu
        if key in ("Escape", "Caps_Lock") and not mods_held:
            result = "EXIT_MENU"
            break
        if key == "Caps_Lock":
            key = "Escape"

        parts = []
        if mod_var in mods_held:
            parts.append("$mod")
            mods_held.discard(mod_var)
        if "Control" in mods_held:
            parts.append("Control")
        if "Mod4" in mods_held:
            parts.append("Mod4")
        if "Mod1" in mods_held:
            parts.append("Mod1")
        if "Shift" in mods_held:
            parts.append("Shift")

        parts.append(key)
        result = "+".join(parts)
        break

    time.sleep(0.01)

# 3. Wait until the key is released before closing Rofi so key release never leaks
t1 = time.time()
while time.time() - t1 < 2.0:
    pressed = get_pressed(buf)
    non_mods = [k for k in pressed if k not in MOD_NAMES]
    if not non_mods:
        break
    time.sleep(0.01)

x11.XCloseDisplay(dpy)
if rofi_pid > 0:
    try:
        os.kill(rofi_pid, signal.SIGTERM)
    except OSError:
        pass

print(result)
')

    wait "$rofi_pid" 2>/dev/null || true
    echo "$captured"
}

# ==========================================
# Action: Change hotkey for selected item
# ==========================================
change_key_for_line() {
    local lineno="$1"
    local mode="$2"
    local old_key="$3"
    local cmd="$4"
    local desc="$5"

    local new_key
    new_key=$(capture_key_combo "$desc" "$old_key" "$mode")

    if [ -z "$new_key" ] || [ "$new_key" = "EXIT_MENU" ]; then
        exit 0
    fi

    if [ "${new_key,,}" = "${old_key,,}" ]; then
        return 0
    fi

    local conflict_line=""
    local conflict_key=""
    local conflict_cmd=""
    while IFS='|' read -r lno m k c; do
        if [ "$m" = "$mode" ] && [ "$lno" != "$lineno" ] && [ "${k,,}" = "${new_key,,}" ]; then
            conflict_line="$lno"
            conflict_key="$k"
            conflict_cmd="$c"
            break
        fi
    done < <(parse_bindings)

    local backup_file
    backup_file=$(mktemp)
    cp "$I3_CONFIG" "$backup_file"

    if [ -n "$conflict_line" ]; then
        local conflict_desc
        conflict_desc=$(describe_action "$mode" "$conflict_cmd")
        local c_msg="<b>$new_key</b> is already used by <b>$conflict_desc</b>:"
        local c_choice
        c_choice=$(printf "1. Swap keys (%s ⇄ %s)\n2. Overwrite (remove %s)\n3. Cancel\n" \
            "$new_key" "$old_key" "$conflict_desc" | rofi_menu "Key Conflict" "$c_msg" "$ROFI_SUB")

        case "$c_choice" in
            "1. Swap keys"*)
                replace_line_in_config "$lineno" "bindsym $new_key $cmd"
                replace_line_in_config "$conflict_line" "bindsym $old_key $conflict_cmd"
                apply_and_validate "$backup_file"
                ;;
            "2. Overwrite"*)
                replace_line_in_config "$lineno" "bindsym $new_key $cmd"
                delete_line_in_config "$conflict_line"
                apply_and_validate "$backup_file"
                ;;
            "3. Cancel"*)
                rm -f "$backup_file"
                return 0
                ;;
            *)
                rm -f "$backup_file"
                exit 0
                ;;
        esac
    else
        replace_line_in_config "$lineno" "bindsym $new_key $cmd"
        apply_and_validate "$backup_file"
    fi
}

# ==========================================
# Main Menu Loop
# ==========================================
main_loop() {
    while true; do
        local current_mod
        current_mod=$(get_current_mod)
        local header_msg="Mod: <b>$current_mod</b>  │  Select a hotkey and press the new key combo (Esc to close)"

        local menu_lines=()
        local menu_records=()

        menu_lines+=("$(printf "%-20s │ %s" "[Switch Mod Key]" "Toggle Alt (Mod1) / Super (Mod4)")")
        menu_records+=("MOD_SWITCH")

        menu_lines+=("$(printf "%-20s │ %s" "[Edit in Neovim]" "Open i3 config in terminal")")
        menu_records+=("OPEN_NVIM")

        while IFS='|' read -r lno mode key cmd; do
            local desc
            desc=$(describe_action "$mode" "$cmd")
            local safe_key="${key//&/&amp;}"
            safe_key="${safe_key//</&lt;}"
            safe_key="${safe_key//>/&gt;}"
            local safe_desc="${desc//&/&amp;}"
            safe_desc="${safe_desc//</&lt;}"
            safe_desc="${safe_desc//>/&gt;}"

            menu_lines+=("$(printf "%-20s │ %s" "$safe_key" "$safe_desc")")
            menu_records+=("$lno|$mode|$key|$cmd|$desc")
        done < <(parse_bindings)

        local chosen_idx
        chosen_idx=$(printf "%s\n" "${menu_lines[@]}" | rofi_menu "Hotkeys" "$header_msg" "$ROFI_MAIN" -format 'i')

        if [ -z "$chosen_idx" ] || ! [[ "$chosen_idx" =~ ^[0-9]+$ ]]; then
            exit 0
        fi

        local rec="${menu_records[$chosen_idx]:-}"
        case "$rec" in
            "MOD_SWITCH")
                bash "$HOME/dotfiles/scripts/toggle-modkey.sh" >/dev/null 2>&1
                sleep 0.15
                ;;
            "OPEN_NVIM")
                nohup kitty -e "$HOME/.local/bin/nvim" "$I3_CONFIG" >/dev/null 2>&1 &
                exit 0
                ;;
            "")
                exit 0
                ;;
            *)
                IFS='|' read -r lno mode key cmd desc <<< "$rec"
                change_key_for_line "$lno" "$mode" "$key" "$cmd" "$desc"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_loop
fi

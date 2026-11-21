# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/95-network.sh: part of setup.sh, sourced in order in the same shell (not run on its own)

# ==========================================
# 9.5 Hand installer Wi-Fi over to NetworkManager (last step: keeps the connection alive during the setup)
# ==========================================
# The Debian installer writes the Wi-Fi it used into /etc/network/interfaces (wpa-ssid/wpa-psk). ifupdown then
# runs its own wpa_supplicant on that card and NetworkManager leaves it alone: only that one network works and
# the Wi-Fi menu stays empty. scripts/lib/ifupdown-wifi-to-nm.py turns that network into a root-only
# NetworkManager profile (the password never passes through this shell), backs the file up and comments the
# Wi-Fi lines out. The switch happens right away: ifdown first (so ifupdown's wpa_supplicant lets go of the card;
# leaving it running makes NetworkManager fail with "couldn't grab this interface" on its next restart), then
# NetworkManager is restarted and connects with the new profile. WIFI_IN_IFUPDOWN comes from setup.d/10-system.sh.

if [ "${WIFI_IN_IFUPDOWN:-0}" = 1 ]; then
    handover=(sudo python3 -I "$DOTFILES_DIR/scripts/lib/ifupdown-wifi-to-nm.py")
    if [ -n "${SSH_CONNECTION:-}" ]; then
        # The switch drops Wi-Fi for a moment and moves it to another stack: over SSH that can lock you out
        warn "Wi-Fi is configured in /etc/network/interfaces, so NetworkManager cannot manage it."
        echo "    Not changed over SSH. Run setup.sh again locally to hand it over to NetworkManager." >&2
    else
        log "Handing Wi-Fi from /etc/network/interfaces over to NetworkManager..."
        check_rc=0
        wifi_ifaces=$("${handover[@]}" check /etc/network/interfaces) || check_rc=$?
        case "$check_rc" in
            0)
                info "Wi-Fi drops for a few seconds while NetworkManager takes over."
                for iface in $wifi_ifaces; do
                    sudo ifdown "$iface" >/dev/null 2>&1 || true
                done
                if "${handover[@]}" apply /etc/network/interfaces; then
                    sudo systemctl restart NetworkManager
                    # Wait (max ~30 s) for NetworkManager to connect with the new profile
                    connected=0
                    for _ in $(seq 30); do
                        if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -qx 'wifi:connected'; then
                            connected=1; break
                        fi
                        sleep 1
                    done
                    if [ "$connected" = 1 ]; then
                        ok "Wi-Fi now runs through NetworkManager (pick other networks in the polybar Wi-Fi menu)."
                    else
                        warn "NetworkManager has not connected to Wi-Fi yet; reboot, or pick the network in the polybar Wi-Fi menu."
                    fi
                else
                    warn "Wi-Fi handover failed; /etc/network/interfaces is unchanged. Restoring the old connection..."
                    for iface in $wifi_ifaces; do
                        sudo ifup "$iface" >/dev/null 2>&1 || warn "ifup $iface failed: reboot to restore Wi-Fi."
                    done
                fi ;;
            3) warn "Wi-Fi stays with ifupdown (see above)." ;;
            4) ;;   # Wi-Fi only in interfaces.d (warned below)
            *) warn "Wi-Fi handover check failed (exit $check_rc); /etc/network/interfaces is unchanged." ;;
        esac
    fi
    # Other files (interfaces.d) are never edited automatically
    if sudo sh -c "grep -qsE '^[[:space:]]*(auto|allow-[a-z]+|iface)[[:space:]]+(.*[[:space:]])?wl' /etc/network/interfaces.d/*"; then
        warn "Wi-Fi is also configured in /etc/network/interfaces.d/: comment those lines out by hand and reboot."
    fi
fi

if [ "${NEEDS_REBOOT:-0}" = 1 ]; then
    warn "Reboot required for the Wi-Fi driver options (/etc/modprobe.d/rtw88-bt-coex.conf)."
fi

ok "Setup completed!"

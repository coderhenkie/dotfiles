#!/usr/bin/env bash

# 1. NVIDIA GPU (via nvidia-smi)
if command -v nvidia-smi >/dev/null 2>&1; then
    val=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d '[:space:]')
    if [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "${val}%"
        exit 0
    fi
fi

# 2. AMD GPU (via amdgpu sysfs gpu_busy_percent)
for f in /sys/class/drm/card*/device/gpu_busy_percent; do
    if [ -r "$f" ]; then
        val=$(tr -d '[:space:]' < "$f" 2>/dev/null)
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            echo "${val}%"
            exit 0
        fi
    fi
done

# 3. Intel GPU (via i915 / xe RC6 idle residency delta)
for f in /sys/class/drm/card*/gt/gt0/rc6_residency_ms \
         /sys/class/drm/card*/power/rc6_residency_ms \
         /sys/class/drm/card*/device/tile0/gt0/gtidle/idle_residency_ms; do
    if [ -r "$f" ]; then
        rc6_now=$(tr -d '[:space:]' < "$f" 2>/dev/null)
        t_now=$(date +%s%3N)
        state_file="/tmp/polybar_gpu_rc6_${UID}"
        if [[ "$rc6_now" =~ ^[0-9]+$ ]] && [ "$rc6_now" -gt 0 ]; then
            if [ -r "$state_file" ]; then
                read -r t_prev rc6_prev < "$state_file" || true
                dt=$(( t_now - t_prev ))
                drc6=$(( rc6_now - rc6_prev ))
                if [ "$dt" -gt 0 ] && [ "$drc6" -ge 0 ]; then
                    busy=$(( 100 - (drc6 * 100 / dt) ))
                    [ "$busy" -lt 0 ] && busy=0
                    [ "$busy" -gt 100 ] && busy=100
                    echo "$t_now $rc6_now" > "$state_file"
                    echo "${busy}%"
                    exit 0
                fi
            fi
            echo "$t_now $rc6_now" > "$state_file"
        fi
    fi
done

# 4. Intel GPU fallback (via current vs min/max frequency scaling)
for card in /sys/class/drm/card*; do
    cur_file=""
    min_file=""
    max_file=""
    if [ -r "$card/gt_cur_freq_mhz" ] && [ -r "$card/gt_max_freq_mhz" ]; then
        cur_file="$card/gt_cur_freq_mhz"
        min_file="$card/gt_RPn_freq_mhz"
        [ ! -r "$min_file" ] && min_file="$card/gt_min_freq_mhz"
        max_file="$card/gt_max_freq_mhz"
    elif [ -r "$card/gt/gt0/rps_cur_freq_mhz" ] && [ -r "$card/gt/gt0/rps_max_freq_mhz" ]; then
        cur_file="$card/gt/gt0/rps_cur_freq_mhz"
        min_file="$card/gt/gt0/rps_RPn_freq_mhz"
        [ ! -r "$min_file" ] && min_file="$card/gt/gt0/rps_min_freq_mhz"
        max_file="$card/gt/gt0/rps_max_freq_mhz"
    elif [ -r "$card/device/tile0/gt0/freq0/cur_freq" ] && [ -r "$card/device/tile0/gt0/freq0/max_freq" ]; then
        cur_file="$card/device/tile0/gt0/freq0/cur_freq"
        min_file="$card/device/tile0/gt0/freq0/min_freq"
        max_file="$card/device/tile0/gt0/freq0/max_freq"
    fi

    if [ -n "$cur_file" ]; then
        cur=$(tr -d '[:space:]' < "$cur_file" 2>/dev/null)
        max=$(tr -d '[:space:]' < "$max_file" 2>/dev/null)
        min=0
        [ -n "$min_file" ] && [ -r "$min_file" ] && min=$(tr -d '[:space:]' < "$min_file" 2>/dev/null)
        if [[ "$cur" =~ ^[0-9]+$ ]] && [[ "$max" =~ ^[0-9]+$ ]] && [ "$max" -gt "$min" ]; then
            if [ "$cur" -le "$min" ]; then
                echo "0%"
            else
                pct=$(( (cur - min) * 100 / (max - min) ))
                [ "$pct" -lt 0 ] && pct=0
                [ "$pct" -gt 100 ] && pct=100
                echo "${pct}%"
            fi
            exit 0
        fi
    fi
done

# 5. Fallback: distinguish VM from baremetal
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --vm --quiet; then
    echo "0% (VM)"
else
    echo "0%"
fi

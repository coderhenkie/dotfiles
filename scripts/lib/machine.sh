#!/usr/bin/env bash
# ==========================================
# Machine type detection (sourced by lock-suspend.sh and setup.sh)
# ==========================================
# machine_is_vm      -> exit 0 inside a virtual machine (KVM/QEMU, VirtualBox, VMware, Hyper-V, ...)
# machine_type       -> prints "vm (<hypervisor>)" or "baremetal"
#
# Uses systemd-detect-virt when available; otherwise falls back to the CPU
# "hypervisor" flag and the DMI vendor/product strings.

machine_is_vm() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        systemd-detect-virt --vm --quiet
        return
    fi
    grep -qw hypervisor /proc/cpuinfo 2>/dev/null && return 0
    cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null \
        | grep -qiE 'qemu|kvm|virtualbox|vmware|xen|bochs|parallels|microsoft corporation virtual|innotek'
}

machine_type() {
    if machine_is_vm; then
        local hv=""
        command -v systemd-detect-virt >/dev/null 2>&1 && hv=$(systemd-detect-virt --vm 2>/dev/null)
        echo "vm${hv:+ ($hv)}"
    else
        echo "baremetal"
    fi
}

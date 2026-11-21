#!/usr/bin/env python3
"""Hand Wi-Fi configured in /etc/network/interfaces (Debian installer, ifupdown) over to NetworkManager.

Usage (as root): ifupdown-wifi-to-nm.py check|apply [INTERFACES_FILE] [CONNECTIONS_DIR]

  check  print the wl* interfaces that can be converted (one per line), change nothing
  apply  write a root-only NetworkManager keyfile per network, back the file up (0600) and comment
         its Wi-Fi lines out

Exit codes: 0 = ok, 3 = a Wi-Fi stanza this can't convert safely (nothing changed), 4 = no Wi-Fi stanza.
Only the installer's shape is converted: `iface wlX inet dhcp` with wpa-ssid [+ wpa-psk] (plus an optional
option-less inet6 auto/dhcp stanza). Static addresses, wpa-conf files, WEP etc. are left to the user.
The password is never printed. Used by setup.d/95-network.sh.
"""
import datetime
import os
import re
import sys
import uuid

os.umask(0o077)  # every file written here (keyfile, backup, temp file) holds the Wi-Fi password

mode = sys.argv[1] if len(sys.argv) > 1 else ""
path = sys.argv[2] if len(sys.argv) > 2 else "/etc/network/interfaces"
conn_dir = sys.argv[3] if len(sys.argv) > 3 else "/etc/NetworkManager/system-connections"
if mode not in ("check", "apply"):
    sys.exit(__doc__)

with open(path) as f:
    lines = f.read().splitlines()

STANZA = re.compile(r"^(iface|auto|allow-[a-z]+|mapping|source|source-directory|no-auto-down|no-scripts)$")


def is_wl(name):
    return name.startswith("wl")


def is_comment(line):  # interfaces(5) only has full-line comments: '#' inside a value (a password) is data
    return line.lstrip().startswith("#")


# The wl* iface stanzas: an iface line plus its option lines, up to the next stanza keyword
stanzas, current = [], None
for i, line in enumerate(lines):
    if is_comment(line) or not line.strip():
        continue
    words = line.split()
    if STANZA.match(words[0]):
        current = None
        if words[0] == "iface" and len(words) >= 2 and is_wl(words[1]):
            current = {"iface": words[1], "family": words[2:4], "lines": [i], "opts": {}}
            stanzas.append(current)
    elif current is not None:
        current["lines"].append(i)
        parts = line.strip().split(None, 1)
        current["opts"][parts[0]] = parts[1] if len(parts) > 1 else ""


def unquote(v):
    return v[1:-1] if len(v) >= 2 and v[0] == v[-1] == '"' else v


def refuse(iface, why):
    print(f"[!] {path}: the {iface} Wi-Fi setup {why}; not converted. Move it to NetworkManager by hand "
          "(nm-connection-editor), then comment it out.", file=sys.stderr)
    sys.exit(3)


networks = {}
for s in stanzas:
    fam, opts = s["family"], s["opts"]
    if fam in (["inet6", "auto"], ["inet6", "dhcp"]) and not opts:
        continue
    if fam != ["inet", "dhcp"] or "wpa-ssid" not in opts or set(opts) - {"wpa-ssid", "wpa-psk"}:
        refuse(s["iface"], "is not the installer's DHCP + wpa-ssid/wpa-psk shape")
    ssid, psk = unquote(opts["wpa-ssid"]), unquote(opts.get("wpa-psk", ""))
    if not ssid or ("wpa-psk" in opts and not psk):
        refuse(s["iface"], "has an empty wpa-ssid or wpa-psk")
    networks[s["iface"]] = (ssid, psk)
if not networks:
    sys.exit(4)

if mode == "check":
    print("\n".join(networks))
    sys.exit(0)


def esc(v):  # GKeyFile string escaping
    v = v.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return "\\s" + v[1:] if v.startswith(" ") else v


def ssid_value(ssid):  # NM keyfile: plain string, or a byte list when ';' or non-printables would be ambiguous
    if ";" in ssid or not ssid.isprintable():
        return ";".join(str(b) for b in ssid.encode()) + ";"
    return esc(ssid)


os.makedirs(conn_dir, mode=0o700, exist_ok=True)
existing = ""
for name in os.listdir(conn_dir):
    try:
        with open(os.path.join(conn_dir, name)) as f:
            existing += f.read() + "\n"
    except OSError:
        pass

for iface, (ssid, psk) in networks.items():
    if re.search(r"^ssid=" + re.escape(ssid_value(ssid)) + r"$", existing, re.M):
        print(f" -> NetworkManager already has a profile for the {iface} network; keeping it.")
        continue
    sec = f"\n[wifi-security]\nkey-mgmt=wpa-psk\npsk={esc(psk)}\n" if psk else ""
    body = (f"[connection]\nid={esc(ssid)}\nuuid={uuid.uuid4()}\ntype=wifi\n\n"
            f"[wifi]\nmode=infrastructure\nssid={ssid_value(ssid)}\n{sec}\n"
            "[ipv4]\nmethod=auto\n\n[ipv6]\naddr-gen-mode=default\nmethod=auto\n\n[proxy]\n")
    fname = re.sub(r"[^A-Za-z0-9._-]", "_", ssid) or "wifi"
    target, n = os.path.join(conn_dir, fname + ".nmconnection"), 1
    while os.path.exists(target):
        n += 1
        target = os.path.join(conn_dir, f"{fname}-{n}.nmconnection")
    with os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as f:
        f.write(body)
    print(f" -> NetworkManager profile created for the {iface} network: {target}")

# Comment out the stanzas; drop the wl* names from auto/allow-* lines (a line naming only wl* is commented out)
drop = {i for s in stanzas for i in s["lines"]}
out = []
for i, line in enumerate(lines):
    words = [] if is_comment(line) else line.split()
    if i in drop:
        out.append("# " + line)
    elif words and re.match(r"^(auto|allow-[a-z]+)$", words[0]) and any(is_wl(w) for w in words[1:]):
        keep = [w for w in words[1:] if not is_wl(w)]
        out.append(f"{words[0]} {' '.join(keep)}" if keep else "# " + line)
    else:
        out.append(line)

stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"{path}.dotfiles-{stamp}"
with open(path, "rb") as src, os.fdopen(os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as dst:
    dst.write(src.read())
tmp = path + ".dotfiles-tmp"
with os.fdopen(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
    f.write(f"# Wi-Fi moved to NetworkManager by dotfiles setup.sh ({stamp}); original: {backup}\n")
    f.write("\n".join(out) + "\n")
os.replace(tmp, path)
print(f" -> Wi-Fi lines commented out in {path} (backup: {backup}; it also holds the password, "
      "delete it once Wi-Fi works).")

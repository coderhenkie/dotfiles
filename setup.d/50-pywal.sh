# shellcheck shell=bash disable=SC2154  # variables come from setup.sh and the earlier parts
# setup.d/50-pywal.sh: part of setup.sh, sourced in order in the same shell (not run on its own)
# ==========================================
# 6. Install Pywal (AI Color Engine)
# ==========================================
log "Installing Pywal and Python dependencies..."
sudo nala install -y python3-pip python3-venv imagemagick

log "Creating virtual environment for Pywal in ~/.local/pywal-venv..."
python3 -m venv "$HOME/.local/pywal-venv"
try "Installing/upgrading Pywal" "$HOME/.local/pywal-venv/bin/pip" install --upgrade pip pywal
ln -sfn "$HOME/.local/pywal-venv/bin/wal" "$LOCAL_BIN/wal"


import os

# Laad de standaard instellingen zodat we niets breken
config.load_autoconfig(False)

# Zoek naar het dynamische kleurenbestand van onze Color Engine
theme_file = os.path.expanduser("~/.cache/theme/qutebrowser.py")

# Als het bestand bestaat, laad de kleuren in
if os.path.exists(theme_file):
    config.source(theme_file)

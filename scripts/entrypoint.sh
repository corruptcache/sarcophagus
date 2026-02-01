#!/bin/bash
# Checks if the user has a config. If not, copies the default one.

CONFIG_FILE="/config/config.yaml"
DEFAULT_FILE="/defaults/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[INIT] No config found at $CONFIG_FILE"
    echo "[INIT] Copying default configuration..."
    cp "$DEFAULT_FILE" "$CONFIG_FILE"
else
    echo "[INIT] Config found. Skipping copy."
fi

# Start OliveTin
exec "$@"

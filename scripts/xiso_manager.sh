#!/bin/bash
# @name: xiso_manager.sh
# @description: Total lifecycle management for Xbox ISO files.
# @dependencies: extract-xiso

LOG_FILE="/var/log/sarcophagus_xbox.log"
DRY_RUN=0
TARGET_DIR=""

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$LOG_FILE"; }

while getopts "d:n" opt; do
    case $opt in
        d) TARGET_DIR="$OPTARG" ;;
        n) DRY_RUN=1 ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then echo "Usage: $0 -d <dir>"; exit 1; fi

log "INFO" "Starting Xbox Optimization..."

find "$TARGET_DIR" -name "*.iso" | while read -r file; do
    log "INFO" "Optimizing: $(basename "$file")"
    if [ $DRY_RUN -eq 0 ]; then
        # -r: Rewrite mode (Creates optimized ISO, replaces original)
        extract-xiso -r "$file" > /dev/null
    fi
done

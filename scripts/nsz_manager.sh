#!/bin/bash
# @name: chd_manager.sh
# @description: Total lifecycle management for CHD files (Convert, Revert, Repair, Cleanup).
# @dependencies: python3

LOG_FILE="/var/log/nsz_manager.log"
DRY_RUN=0
TARGET_DIR=""
MODE="convert" # convert, revert, cleanup

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$LOG_FILE"; }
usage() { echo "Usage: $0 -d <dir> [-m convert|revert|cleanup] [-n]"; exit 1; }

while getopts "d:m:n" opt; do
    case $opt in
        d) TARGET_DIR="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        *) usage ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then usage; fi
if ! command -v nsz &> /dev/null; then log "CRITICAL" "Tool 'nsz' not found."; exit 1; fi

log "INFO" "Starting NSZ Manager. Mode: $MODE | Target: $TARGET_DIR"

if [ "$MODE" == "convert" ]; then
    find "$TARGET_DIR" -name "*.nsp" -o -name "*.xci" | while read -r file; do
        if [[ "$file" == *.nsz ]] || [[ "$file" == *.xcz ]]; then continue; fi
        log "INFO" "Compressing: $(basename "$file")"
        if [ $DRY_RUN -eq 0 ]; then
            # -C: Solid Compression, -V: Verify, -w: Overwrite (removes source)
            nsz -C -V -w "$file"
        fi
    done

elif [ "$MODE" == "revert" ]; then
    find "$TARGET_DIR" -name "*.nsz" -o -name "*.xcz" | while read -r file; do
        log "INFO" "Decompressing: $(basename "$file")"
        if [ $DRY_RUN -eq 0 ]; then nsz -D "$file" && rm "$file"; fi
    done

elif [ "$MODE" == "cleanup" ]; then
    # Removes uncompressed source if compressed exists
    find "$TARGET_DIR" -name "*.nsz" | while read -r file; do
        source="${file%.*}.nsp"
        if [ -f "$source" ]; then
            log "CLEAN" "Removing duplicate source: $(basename "$source")"
            [ $DRY_RUN -eq 0 ] && rm "$source"
        fi
    done
fi

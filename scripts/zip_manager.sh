#!/bin/bash
# @name: zip_manager.sh
# @description: Standard Archiving: Reversible compression using 7-Zip.
# @dependencies: 7z

LOG_FILE="/var/log/sarcophagus_zip.log"
DRY_RUN=0
TARGET_DIR=""
MODE="convert" # convert, revert, cleanup
TYPE="file"    # file (NES/SNES/GEN), folder (Vita)

# --- UTILS ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$LOG_FILE"; }
usage() { echo "Usage: $0 -d <dir> -t <file|vita> [-m convert|revert|cleanup] [-n]"; exit 1; }

while getopts "d:t:m:n" opt; do
    case $opt in
        d) TARGET_DIR="$OPTARG" ;;
        t) TYPE="$OPTARG" ;; # 'file' for carts, 'vita' for folder->vpk
        m) MODE="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        *) usage ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then usage; fi
if [ $DRY_RUN -eq 1 ]; then log "WARN" "DRY RUN ENABLED"; fi

log "INFO" "Starting Zip Manager. Type: $TYPE | Mode: $MODE"

# ------------------------------------------------------------------------------
# CORE ZIP LOGIC
# ------------------------------------------------------------------------------

# --- MODE: CONVERT ---
if [ "$MODE" == "convert" ]; then
    if [ "$TYPE" == "vita" ]; then
        # FOLDER -> VPK (Vita)
        find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
            if [ -f "$dir/eboot.bin" ] || [ -f "$dir/sce_sys/icon0.png" ]; then
                vpk_name="${dir}.vpk"
                if [ -f "$vpk_name" ]; then log "SKIP" "VPK exists: $(basename "$vpk_name")"; continue; fi

                log "INFO" "Archiving Vita: $(basename "$dir") -> .vpk"
                if [ $DRY_RUN -eq 0 ]; then
                    cd "$dir" && 7z a -tzip -mx=3 "../$(basename "$dir").vpk" ./* > /dev/null
                    cd .. && rm -rf "$dir"
                fi
            fi
        done
    else
        # FILE -> ZIP (Carts)
        # Find uncompressed roms (ignoring .zip, .7z, .rar)
        find "$TARGET_DIR" -type f ! -name "*.zip" ! -name "*.7z" ! -name "*.rar" ! -name "*.sh" | while read -r file; do
            zip_file="${file%.*}.zip"
            if [ -f "$zip_file" ]; then log "SKIP" "Zip exists: $(basename "$zip_file")"; continue; fi

            log "INFO" "Zipping Cart: $(basename "$file")"
            if [ $DRY_RUN -eq 0 ]; then
                # -mx=9: Ultra compression, -tzip: Force zip format
                7z a -tzip -mx=9 "$zip_file" "$file" > /dev/null && rm "$file"
            fi
        done
    fi

# --- MODE: REVERT ---
elif [ "$MODE" == "revert" ]; then
    if [ "$TYPE" == "vita" ]; then
        # VPK -> FOLDER
        find "$TARGET_DIR" -name "*.vpk" | while read -r file; do
            folder="${file%.*}"
            if [ -d "$folder" ]; then log "SKIP" "Folder exists: $(basename "$folder")"; continue; fi

            log "INFO" "Extracting Vita: $(basename "$file")"
            if [ $DRY_RUN -eq 0 ]; then
                7z x "$file" -o"$folder" > /dev/null && rm "$file"
            fi
        done
    else
        # ZIP -> FILE
        find "$TARGET_DIR" -name "*.zip" | while read -r file; do
            # Check if extracted file already exists is tricky without peeking inside zip
            # We assume if zip exists, we unzip it. 7zip skips overwrite by default.
            log "INFO" "Unzipping Cart: $(basename "$file")"
            if [ $DRY_RUN -eq 0 ]; then
                # -aos: Skip extracting if file exists
                7z x "$file" -o"$(dirname "$file")" -aos > /dev/null && rm "$file"
            fi
        done
    fi

# --- MODE: CLEANUP ---
elif [ "$MODE" == "cleanup" ]; then
    # Logic to find duplicates (zip + uncompressed)
    log "WARN" "Cleanup not yet implemented for general Zip Manager safety."
fi

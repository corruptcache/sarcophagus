#!/bin/bash
# @name: rvz_manager.sh
# @description: Total lifecycle management for GameCube/Wii RVZ files.
# @dependencies: dolphin-tool

# --- DEFAULTS ---
TARGET_DIR=""
LOG_FILE="/var/log/rvz_manager.log"
MODE="convert" # Modes: convert, revert, verify, cleanup
DRY_RUN=false
RECURSIVE=true
# Standard exclusions (Recycle bins, etc.)
EXCLUDE_LIST="@Recycle|#recycle"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- USAGE ---
usage() {
    echo -e "${CYAN}Exodia RVZ Manager${NC}"
    echo "Usage: $0 -d <directory> [options]"
    echo ""
    echo "Options:"
    echo "  -d <path>    Target directory (Required)"
    echo "  -m <mode>    Operation mode (Default: convert)"
    echo "               Modes: convert | revert | verify | cleanup"
    echo "  -n           Dry Run (Simulate only)"
    echo "  -f           Flat scan (Disable recursion)"
    echo "  -l <file>    Custom log file"
    echo "  -h           Show help"
    echo ""
    exit 1
}

# --- ARGUMENT PARSING ---
while getopts "d:m:nl:fh" opt; do
    case $opt in
        d) TARGET_DIR="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        n) DRY_RUN=true ;;
        l) LOG_FILE="$OPTARG" ;;
        f) RECURSIVE=false ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then echo -e "${RED}Error: -d required.${NC}"; usage; fi

# --- HELPERS ---
log() { echo -e "$(date "+%Y-%m-%d %H:%M:%S") [$1] $2" | tee -a "$LOG_FILE"; }

is_excluded() { echo "$1" | grep -iqE "$EXCLUDE_LIST"; }

check_deps() {
    if ! command -v dolphin-tool &> /dev/null; then
        log "ERROR" "dolphin-tool not found. This script requires the Dolphin container."
        exit 1
    fi
}

verify_and_clean() {
    local RVZ="$1"
    local SOURCE="$2"
    log "INFO" "Verifying: $RVZ"

    # Verify the new RVZ integrity
    dolphin-tool verify -i "$RVZ" >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "SUCCESS" "Verification Passed. Removing source."
        rm -f "$SOURCE"
        # Cleanup nkit junk if present
        find "$(dirname "$SOURCE")" -maxdepth 1 -iname "$(basename "$SOURCE" .iso).nkit.iso" -delete
    else
        log "ERROR" "Verification Failed! Deleting corrupt RVZ."
        rm -f "$RVZ"
    fi
}

# --- MODE 1: CONVERT (ISO/GCM -> RVZ) ---
convert_files() {
    local FIND="find \"$TARGET_DIR\" -type f \( -iname \"*.iso\" -o -iname \"*.gcm\" -o -iname \"*.wbfs\" \)"
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read FILE; do
        if is_excluded "$FILE"; then continue; fi
        DIR=$(dirname "$FILE"); BASE=$(basename "$FILE"); NAME="${BASE%.*}"
        RVZ="$DIR/$NAME.rvz"

        if [ -f "$RVZ" ]; then continue; fi
        log "INFO" "Converting: $FILE"
        [ "$DRY_RUN" = true ] && { log "DRY" "Would convert $FILE to RVZ"; continue; }

        # Conversion: RVZ format, Zstd compression, Level 5 (Sweet spot)
        dolphin-tool convert -i "$FILE" -o "$RVZ" -f rvz -c zstd -l 5 >> "$LOG_FILE" 2>&1
        [ $? -eq 0 ] && verify_and_clean "$RVZ" "$FILE" || { log "ERROR" "Failed"; rm -f "$RVZ"; }
    done
}

# --- MODE 2: REVERT (RVZ -> ISO) ---
revert_files() {
    local FIND="find \"$TARGET_DIR\" -type f -iname \"*.rvz\""
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read RVZ; do
        if is_excluded "$RVZ"; then continue; fi
        DIR=$(dirname "$RVZ"); BASE=$(basename "$RVZ"); NAME="${BASE%.*}"
        ISO="$DIR/$NAME.iso"

        log "INFO" "Reverting: $RVZ"
        [ "$DRY_RUN" = true ] && { log "DRY" "Would revert $RVZ to ISO"; continue; }

        # Convert back to ISO
        dolphin-tool convert -i "$RVZ" -o "$ISO" -f iso >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log "SUCCESS" "Reverted to ISO. Deleting RVZ."
            rm -f "$RVZ"
        else
            log "ERROR" "Revert failed for $RVZ"
            rm -f "$ISO"
        fi
    done
}

# --- MODE 3: CLEANUP (Delete Duplicates) ---
cleanup_only() {
    local FIND="find \"$TARGET_DIR\" -type f -iname \"*.rvz\""
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read RVZ; do
        if is_excluded "$RVZ"; then continue; fi
        DIR=$(dirname "$RVZ"); NAME="$(basename "$RVZ" .rvz)"

        for EXT in iso gcm wbfs zip; do
            find "$DIR" -maxdepth 1 -iname "$NAME.$EXT" | while read DUPE; do
                [ "$DRY_RUN" = true ] && log "DRY" "Would delete $DUPE" || { log "CLEAN" "Deleted $DUPE"; rm -f "$DUPE"; }
            done
        done
    done
}

# --- EXECUTION ---
check_deps
log "START" "Mode: $MODE | Target: $TARGET_DIR | DryRun: $DRY_RUN"

case "$MODE" in
    convert) convert_files ;;
    revert)  revert_files ;;
    cleanup) cleanup_only ;;
    verify)
        find "$TARGET_DIR" -iname "*.rvz" | while read F; do
             dolphin-tool verify -i "$F" >> "$LOG_FILE" 2>&1 || log "ERROR" "Bad RVZ: $F"
        done
        ;;
    *) echo "Invalid mode."; exit 1 ;;
esac

log "END" "Finished."

#!/bin/bash
# @name: chd_manager.sh
# @description: Total lifecycle management for CHD files (Convert, Revert, Repair, Cleanup).
# @dependencies: chdman

# --- DEFAULTS ---
TARGET_DIR=""
LOG_FILE="/var/log/chd_manager.log"
MODE="convert" # Modes: convert, revert, repair, verify, cleanup
DRY_RUN=false
RECURSIVE=true
EXCLUDE_LIST="gamecube|wii|wiiu|xbox"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- USAGE ---
usage() {
    echo -e "${CYAN}Exodia CHD Manager${NC}"
    echo "Usage: $0 -d <directory> [options]"
    echo ""
    echo "Options:"
    echo "  -d <path>    Target directory (Required)"
    echo "  -m <mode>    Operation mode (Default: convert)"
    echo "               Modes: convert | revert | repair | verify | cleanup"
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
    if ! command -v chdman &> /dev/null; then
        log "WARN" "chdman missing. Auto-installing..."
        command -v apk &> /dev/null && apk add --no-cache mame-tools grep
        command -v apt-get &> /dev/null && (apt-get update && apt-get install -y mame-tools grep)
    fi
}

verify_and_clean() {
    local CHD="$1"
    local SOURCE="$2"
    log "INFO" "Verifying: $CHD"
    chdman verify -i "$CHD" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Verification Passed. Removing source."
        rm -f "$SOURCE"
        [[ "$SOURCE" == *.cue ]] && find "$(dirname "$SOURCE")" -maxdepth 1 -iname "$(basename "$SOURCE" .cue).bin" -delete
    else
        log "ERROR" "Verification Failed! Deleting corrupt CHD."
        rm -f "$CHD"
    fi
}

# --- MODE 1: CONVERT (ISO/CUE -> CHD) ---
convert_files() {
    local FIND="find \"$TARGET_DIR\" -type f \( -iname \"*.iso\" -o -iname \"*.cue\" \)"
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read FILE; do
        if is_excluded "$FILE"; then continue; fi
        DIR=$(dirname "$FILE"); BASE=$(basename "$FILE"); NAME="${BASE%.*}"
        CHD="$DIR/$NAME.chd"

        if [ -f "$CHD" ]; then continue; fi
        log "INFO" "Converting: $FILE"
        [ "$DRY_RUN" = true ] && { log "DRY" "Would convert $FILE"; continue; }

        chdman createcd -i "$FILE" -o "$CHD" >> "$LOG_FILE" 2>&1
        [ $? -eq 0 ] && verify_and_clean "$CHD" "$FILE" || { log "ERROR" "Failed"; rm -f "$CHD"; }
    done
}

# --- MODE 2: REVERT (CHD -> ISO/BIN) ---
revert_files() {
    local FIND="find \"$TARGET_DIR\" -type f -iname \"*.chd\""
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read CHD; do
        if is_excluded "$CHD"; then continue; fi
        DIR=$(dirname "$CHD"); BASE=$(basename "$CHD"); NAME="${BASE%.*}"

        log "INFO" "Reverting: $CHD"
        [ "$DRY_RUN" = true ] && { log "DRY" "Would revert $CHD"; continue; }

        # Attempt CD (Bin/Cue)
        CUE="$DIR/$NAME.cue"; BIN="$DIR/$NAME.bin"
        chdman extractcd -i "$CHD" -o "$CUE" -ob "$BIN" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            log "SUCCESS" "Reverted to BIN/CUE. Deleting CHD."
            rm -f "$CHD"
            continue
        fi
        rm -f "$CUE" "$BIN" # Cleanup failed attempt

        # Attempt DVD (ISO)
        ISO="$DIR/$NAME.iso"
        chdman extractdvd -i "$CHD" -o "$ISO" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            log "SUCCESS" "Reverted to ISO. Deleting CHD."
            rm -f "$CHD"
        else
            log "ERROR" "Revert failed for $CHD"
            rm -f "$ISO"
        fi
    done
}

# --- MODE 3: REPAIR (Re-encode bad CHDs) ---
repair_files() {
    local FIND="find \"$TARGET_DIR\" -type f -iname \"*.chd\""
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read CHD; do
        if is_excluded "$CHD"; then continue; fi
        log "INFO" "Repairing: $CHD"
        [ "$DRY_RUN" = true ] && { log "DRY" "Would repair $CHD"; continue; }

        DIR=$(dirname "$CHD"); NAME="$(basename "$CHD" .chd)"
        TEMP="$DIR/$NAME.repair.iso"

        # Extract (Try DVD first as that's the common failure point for PS2)
        chdman extractdvd -i "$CHD" -o "$TEMP" >> "$LOG_FILE" 2>&1
        [ $? -ne 0 ] && chdman extractcd -i "$CHD" -o "$TEMP" >> "$LOG_FILE" 2>&1

        if [ -f "$TEMP" ]; then
            rm -f "$CHD" # Delete bad CHD
            chdman createcd -i "$TEMP" -o "$CHD" >> "$LOG_FILE" 2>&1
            [ $? -eq 0 ] && verify_and_clean "$CHD" "$TEMP" || log "CRITICAL" "Repair failed. ISO left at $TEMP"
        fi
    done
}

# --- MODE 4: CLEANUP (Delete Duplicates) ---
cleanup_only() {
    local FIND="find \"$TARGET_DIR\" -type f -iname \"*.chd\""
    [ "$RECURSIVE" = false ] && FIND="$FIND -maxdepth 1"

    eval "$FIND" | while read CHD; do
        if is_excluded "$CHD"; then continue; fi
        DIR=$(dirname "$CHD"); NAME="$(basename "$CHD" .chd)"

        for EXT in iso bin cue zip; do
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
    repair)  repair_files ;;
    cleanup) cleanup_only ;;
    verify)
        find "$TARGET_DIR" -iname "*.chd" | while read F; do
             chdman verify -i "$F" >> "$LOG_FILE" 2>&1 || log "ERROR" "Bad CHD: $F"
        done
        ;;
    *) echo "Invalid mode."; exit 1 ;;
esac

log "END" "Finished."

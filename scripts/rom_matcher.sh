#!/bin/bash
# @name: rom_matcher.sh
# @description: Generates strict "No-Intro" regex strings from a list of game titles to filter junk/demos.
# @dependencies: sed

# --- DEFAULTS ---
INPUT_FILE=""
REGION="USA"
# Standard hardcoded list if no file is provided
DEFAULT_GAMES=(
    "Airblade"
    "Graffiti Kingdom"
    "Gungrave"
    "Hidden Invasion"
    "IGPX - Immortal Grand Prix"
    "Samurai Western"
    "Scooby-Doo! Night of 100 Frights"
    "Seven Samurai 20XX"
    "Shinobi"
    "Tokobot Plus - Mysteries of the Karakuri"
    "Wizardry - Tale of the Forsaken Land"
    "Ys VI - The Ark of Napishtim"
)

# --- COLORS ---
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# --- USAGE ---
usage() {
    echo -e "${CYAN}Exodia ROM Matcher${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -f <file>    Path to text file containing game names (one per line)."
    echo "               If excluded, uses the internal default list."
    echo "  -r <region>  Set strict region match (Default: USA)."
    echo "               Valid: USA, Japan, Europe, Korea."
    echo "  -h           Show help"
    echo ""
    echo "Example:"
    echo "  $0 -f my_wishlist.txt -r Japan"
    exit 1
}

# --- ARGUMENT PARSING ---
while getopts "f:r:h" opt; do
    case $opt in
        f) INPUT_FILE="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# --- VALIDATION ---
case "$REGION" in
    USA|Japan|Europe|Korea) ;;
    *) echo -e "${RED}Error: Invalid region '$REGION'. Allowed: USA, Japan, Europe, Korea.${NC}"; exit 1 ;;
esac

# --- EXECUTION ---
# Load Game List
if [ -n "$INPUT_FILE" ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}Error: File '$INPUT_FILE' not found.${NC}"
        exit 1
    fi
    IFS=$'\n' read -d '' -r -a GAME_LIST < "$INPUT_FILE"
else
    GAME_LIST=("${DEFAULT_GAMES[@]}")
fi

# Process List (Escape regex characters)
SANITIZED_LIST=()
for game in "${GAME_LIST[@]}"; do
    # Trim whitespace
    game=$(echo "$game" | xargs)
    [[ -z "$game" ]] && continue

    # Escape special regex chars: . ^ $ * + ? ( ) [ ] { } | \
    cleaned_game=$(echo "$game" | sed 's/[][\.^$*+?(){}|\]/\\&/g')
    SANITIZED_LIST+=("$cleaned_game")
done

# Join with OR pipe (|)
JOINED_GAMES=$(IFS=\|; echo "${SANITIZED_LIST[*]}")

# Construct Regex
# 1. Start Anchor ^
# 2. Non-capturing group (?:Title|Title)
# 3. Disc tag optional (?: \(Disc \d\))?
# 4. Region tag \(Region\)
# 5. Version tag optional (?: \(v[\d\.]+\))?
# 6. Ext and End Anchor \.zip$
REGEX_STRING="^(?:${JOINED_GAMES})(?: \(Disc \d\))? \(${REGION}\)(?: \(v[\d\.]+\))?\.zip$"

# Output
echo "--- Copy the Regex below ---"
echo "$REGEX_STRING"
echo "----------------------------"

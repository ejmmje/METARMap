#!/usr/bin/env bash

set -Eeuo pipefail
trap 'echo "Error: setup failed on line $LINENO."; exit 1' ERR

# ANSI color codes for better formatting
BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
cd "$PROJECT_DIR"

RUN_NONINTERACTIVE=false
FORCE_RECONFIGURE=false

for arg in "$@"; do
    case "$arg" in
        --non-interactive)
            RUN_NONINTERACTIVE=true
            ;;
        --reconfigure)
            FORCE_RECONFIGURE=true
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: bash setup.sh [--non-interactive] [--reconfigure]"
            exit 1
            ;;
    esac
done

run_as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

is_interactive() {
    [[ -t 0 && -t 1 && "$RUN_NONINTERACTIVE" == false ]]
}

prompt_text() {
    local question="$1"
    local default_value="$2"

    if ! is_interactive; then
        echo "$default_value"
        return
    fi

    local response
    read -r -p "$question" response || true
    response="${response:-$default_value}"
    echo "$response"
}

prompt_int() {
    local question="$1"
    local default_value="$2"
    local response

    response="$(prompt_text "$question" "$default_value")"

    if [[ "$response" =~ ^[0-9]+$ ]]; then
        echo "$response"
    else
        echo "$default_value"
    fi
}

prompt_bool() {
    local question="$1"
    local default_value="$2"
    local prompt_text_value
    local default_bool

    case "${default_value,,}" in
        y|yes|true)
            prompt_text_value="Y/n"
            default_bool="true"
            ;;
        n|no|false)
            prompt_text_value="y/N"
            default_bool="false"
            ;;
        *)
            prompt_text_value="Y/n"
            default_bool="true"
            ;;
    esac

    if ! is_interactive; then
        echo "$default_bool"
        return
    fi

    local response
    read -r -p "$question [$prompt_text_value]: " response || true
    response="${response:-$default_value}"

    case "${response,,}" in
        y|yes|true)
            echo "true"
            ;;
        n|no|false)
            echo "false"
            ;;
        *)
            echo "$default_bool"
            ;;
    esac
}

echo -e "${BOLD}METARMap Setup Script${NC}"
echo "Project directory: $PROJECT_DIR"

if [[ "$RUN_NONINTERACTIVE" == true ]]; then
    echo -e "${YELLOW}Running in non-interactive mode. Existing config will be preserved if present.${NC}"
fi

# Update package index and install required system packages
echo -e "${GREEN}Installing system dependencies...${NC}"
run_as_root apt-get update
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-pip python3-venv python3-dev build-essential git \
    libjpeg-dev zlib1g-dev libpng-dev libfreetype6-dev liblcms2-dev \
    libtiff-dev libwebp-dev libopenjp2-7-dev libraqm-dev libharfbuzz-dev \
    libfribidi-dev libxcb1-dev

# Create or reuse virtual environment
if [[ ! -d metarmap_env ]]; then
    echo -e "${GREEN}Creating virtual environment...${NC}"
    python3 -m venv metarmap_env
else
    echo -e "${GREEN}Reusing existing virtual environment...${NC}"
fi

# Activate venv and install required Python libraries
# shellcheck source=/dev/null
source metarmap_env/bin/activate
echo -e "${GREEN}Installing Python dependencies...${NC}"
pip install --upgrade pip wheel
pip install --upgrade rpi_ws281x adafruit-circuitpython-neopixel adafruit-blinka requests RPi.GPIO

# Default configuration values
LED_COUNT=50
ACTIVATE_WINDCONDITION_ANIMATION=true
ACTIVATE_LIGHTNING_ANIMATION=true
FADE_INSTEAD_OF_BLINK=true
ALWAYS_BLINK_FOR_GUSTS=false
ACTIVATE_DAYTIME_DIMMING=true
USE_SUNRISE_SUNSET=true
LOCATION="Detroit"
ACTIVATE_EXTERNAL_METAR_DISPLAY=false
SHOW_LEGEND=false
REPLACE_CAT_WITH_CLOSEST=true

KEEP_EXISTING_CONFIG=false
if [[ -f config.json && "$FORCE_RECONFIGURE" == false ]]; then
    if is_interactive; then
        KEEP_EXISTING_CONFIG="$(prompt_bool "config.json already exists. Keep current configuration?" "y")"
    else
        KEEP_EXISTING_CONFIG=true
    fi
fi

if [[ "$FORCE_RECONFIGURE" == true ]]; then
    KEEP_EXISTING_CONFIG=false
fi

if [[ "$KEEP_EXISTING_CONFIG" == false ]]; then
    echo -e "${BOLD}Configuring METARMap settings...${NC}"

    LED_COUNT="$(prompt_int "How many LEDs are in your strip? (default: 50): " "50")"

    echo -e "${BLUE}ACTIVATE_WINDCONDITION_ANIMATION: Blink/fade on windy conditions.${NC}"
    ACTIVATE_WINDCONDITION_ANIMATION="$(prompt_bool "Enable wind condition animation?" "y")"

    echo -e "${BLUE}ACTIVATE_LIGHTNING_ANIMATION: Flash for lightning conditions.${NC}"
    ACTIVATE_LIGHTNING_ANIMATION="$(prompt_bool "Enable lightning animation?" "y")"

    echo -e "${BLUE}FADE_INSTEAD_OF_BLINK: Use fade effect instead of hard blink.${NC}"
    FADE_INSTEAD_OF_BLINK="$(prompt_bool "Use fade instead of blink?" "y")"

    echo -e "${BLUE}ALWAYS_BLINK_FOR_GUSTS: Animate on gusts even below threshold.${NC}"
    ALWAYS_BLINK_FOR_GUSTS="$(prompt_bool "Always blink for gusts?" "n")"

    echo -e "${BLUE}ACTIVATE_DAYTIME_DIMMING: Dim LEDs during day/night schedule.${NC}"
    ACTIVATE_DAYTIME_DIMMING="$(prompt_bool "Enable daytime dimming?" "y")"

    if [[ "$ACTIVATE_DAYTIME_DIMMING" == true ]]; then
        echo -e "${BLUE}USE_SUNRISE_SUNSET: Use city sunrise/sunset instead of fixed times.${NC}"
        USE_SUNRISE_SUNSET="$(prompt_bool "Use sunrise/sunset times?" "y")"
        if [[ "$USE_SUNRISE_SUNSET" == true ]]; then
            LOCATION="$(prompt_text "Enter your city for sunrise/sunset calculations (default: Detroit): " "Detroit")"
        else
            LOCATION="Detroit"
        fi
    else
        USE_SUNRISE_SUNSET=false
        LOCATION="Detroit"
    fi

    echo -e "${BLUE}ACTIVATE_EXTERNAL_METAR_DISPLAY: Enable OLED display support.${NC}"
    ACTIVATE_EXTERNAL_METAR_DISPLAY="$(prompt_bool "Enable external METAR display?" "n")"

    echo -e "${BLUE}SHOW_LEGEND: Show legend colors on extra LEDs.${NC}"
    SHOW_LEGEND="$(prompt_bool "Show color legend?" "n")"

    echo -e "${BLUE}REPLACE_CAT_WITH_CLOSEST: Fill missing categories with nearest station.${NC}"
    REPLACE_CAT_WITH_CLOSEST="$(prompt_bool "Replace missing categories with closest station?" "y")"

    LOCATION_ESCAPED="${LOCATION//\"/\\\"}"

    cat > config.json <<CONFIG_EOF
{
  "LED_COUNT": $LED_COUNT,
  "LED_PIN": "board.D18",
  "LED_BRIGHTNESS": 0.5,
  "LED_ORDER": "neopixel.GRB",
  "COLOR_VFR": [255, 0, 0],
  "COLOR_VFR_FADE": [125, 0, 0],
  "COLOR_MVFR": [0, 0, 255],
  "COLOR_MVFR_FADE": [0, 0, 125],
  "COLOR_IFR": [0, 255, 0],
  "COLOR_IFR_FADE": [0, 125, 0],
  "COLOR_LIFR": [0, 125, 125],
  "COLOR_LIFR_FADE": [0, 75, 75],
  "COLOR_CLEAR": [0, 0, 0],
  "COLOR_LIGHTNING": [255, 255, 255],
  "COLOR_HIGH_WINDS": [255, 255, 0],
  "ACTIVATE_WINDCONDITION_ANIMATION": $ACTIVATE_WINDCONDITION_ANIMATION,
  "ACTIVATE_LIGHTNING_ANIMATION": $ACTIVATE_LIGHTNING_ANIMATION,
  "FADE_INSTEAD_OF_BLINK": $FADE_INSTEAD_OF_BLINK,
  "WIND_BLINK_THRESHOLD": 15,
  "HIGH_WINDS_THRESHOLD": 25,
  "ALWAYS_BLINK_FOR_GUSTS": $ALWAYS_BLINK_FOR_GUSTS,
  "BLINK_SPEED": 2.0,
  "BLINK_TOTALTIME_SECONDS": 300,
  "ACTIVATE_DAYTIME_DIMMING": $ACTIVATE_DAYTIME_DIMMING,
  "BRIGHT_TIME_START": "08:00",
  "DIM_TIME_START": "19:00",
  "LED_BRIGHTNESS_DIM": 0.1,
  "USE_SUNRISE_SUNSET": $USE_SUNRISE_SUNSET,
  "LOCATION": "$LOCATION_ESCAPED",
  "ACTIVATE_EXTERNAL_METAR_DISPLAY": $ACTIVATE_EXTERNAL_METAR_DISPLAY,
  "DISPLAY_ROTATION_SPEED": 5.0,
  "SHOW_LEGEND": $SHOW_LEGEND,
  "OFFSET_LEGEND_BY": 0,
  "REPLACE_CAT_WITH_CLOSEST": $REPLACE_CAT_WITH_CLOSEST
}
CONFIG_EOF

    echo "Configuration saved to config.json"
else
    echo -e "${GREEN}Keeping existing config.json${NC}"
fi

# Install optional libraries based on current config
activate_flag() {
    local key="$1"
    python3 - <<PYCODE
import json
with open("config.json") as f:
    cfg = json.load(f)
print(str(bool(cfg.get("$key", False))).lower())
PYCODE
}

USE_SUNRISE_SUNSET="$(activate_flag "USE_SUNRISE_SUNSET")"
ACTIVATE_EXTERNAL_METAR_DISPLAY="$(activate_flag "ACTIVATE_EXTERNAL_METAR_DISPLAY")"

if [[ "$USE_SUNRISE_SUNSET" == true ]]; then
    echo -e "${GREEN}Installing astral for sunrise/sunset support...${NC}"
    pip install --upgrade astral
fi

if [[ "$ACTIVATE_EXTERNAL_METAR_DISPLAY" == true ]]; then
    echo -e "${GREEN}Installing display dependencies...${NC}"
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pil
    pip install --upgrade adafruit-circuitpython-ssd1306 pillow

    if command -v raspi-config >/dev/null 2>&1; then
        run_as_root raspi-config nonint do_i2c 0
        echo "I2C enabled. Reboot if this is your first time enabling it."
    else
        echo -e "${YELLOW}raspi-config not found; enable I2C manually if needed.${NC}"
    fi
fi

deactivate

# Ensure script permissions
chmod +x setup.sh update.sh refresh.sh lightsoff.sh

# Create airports file if it doesn't exist
if [[ ! -f airports ]]; then
    echo "Creating sample airports file..."
    {
        echo "KDTW"
        echo "NULL"
    } > airports
    echo "Please edit the airports file to add your desired airports."
else
    echo "airports file already exists."
fi

# Create display airports file if display is enabled and file doesn't exist
if [[ "$ACTIVATE_EXTERNAL_METAR_DISPLAY" == true && ! -f displayairports ]]; then
    echo "Creating sample displayairports file..."
    cp airports displayairports
fi

# Set up cron jobs for automated execution
# Replace existing METARMap-managed block to keep schedule idempotent
echo -e "${GREEN}Configuring crontab...${NC}"
CURRENT_CRON="$(mktemp)"
NEW_CRON="$(mktemp)"

if run_as_root crontab -l > "$CURRENT_CRON" 2>/dev/null; then
    :
else
    : > "$CURRENT_CRON"
fi

awk '
BEGIN {skip=0}
/^# >>> METARMap >>>$/ {skip=1; next}
/^# <<< METARMap <<<$/{skip=0; next}
skip==0 {print}
' "$CURRENT_CRON" > "$NEW_CRON"

cat >> "$NEW_CRON" <<CRON_EOF
# >>> METARMap >>>
# Managed by setup.sh in $PROJECT_DIR
# For custom schedules, visit https://crontab.guru/
*/5 7-21 * * * /bin/bash '$PROJECT_DIR/refresh.sh'
5 22 * * * /bin/bash '$PROJECT_DIR/lightsoff.sh'
# <<< METARMap <<<
CRON_EOF

run_as_root crontab "$NEW_CRON"
rm -f "$CURRENT_CRON" "$NEW_CRON"

echo -e "${BOLD}Setup complete!${NC}"
echo "To test manually, run: sudo $PROJECT_DIR/metarmap_env/bin/python3 $PROJECT_DIR/metar.py"
echo "To reconfigure prompts, run: sudo bash $PROJECT_DIR/setup.sh --reconfigure"

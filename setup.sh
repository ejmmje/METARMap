#!/bin/bash

# METARMap Setup Script
# This script automates the installation and configuration of the METARMap project on a Raspberry Pi.
# It sets up a virtual environment, installs dependencies, configures files, and schedules cron jobs.
# Run this script with sudo privileges: sudo bash setup.sh

echo -e "${BOLD}METARMap Setup Script${NC}"
echo "This script will install the necessary dependencies and set up the METARMap project."
echo "Please run this script as a user with sudo privileges."

# Function to check if the previous command succeeded
# If not, print an error message and exit the script
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Please check your system and try again."
        exit 1
    fi
}

# ANSI color codes for better formatting
BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m'  # No Color

# Get project directory
PROJECT_DIR=$(pwd)
echo "Project directory: $PROJECT_DIR"

# Update the system's package list and upgrade installed packages
# This ensures the system is up-to-date before installing new software
echo -e "${GREEN}Updating system packages...${NC}"
sudo apt-get update
check_command "apt-get update"
sudo apt-get upgrade -y
check_command "apt-get upgrade"

# Install Python 3, pip, and virtual environment support
# These are required for creating and managing the virtual environment
echo -e "${GREEN}Installing Python3 and pip3...${NC}"
sudo apt-get install -y python3 python3-pip python3-venv
check_command "apt-get install python3 python3-pip python3-venv"

# Create a virtual environment for Python packages
# This isolates the project's dependencies from the system Python
if [ -d metarmap_env ]; then
    echo "Removing existing virtual environment for clean slate..."
    rm -rf metarmap_env
fi
echo -e "${GREEN}Creating virtual environment...${NC}"
python3 -m venv metarmap_env
check_command "Creating virtual environment"
echo -e "${GREEN}Activating virtual environment...${NC}"
. metarmap_env/bin/activate
check_command "Activating virtual environment"

# Upgrade pip inside the virtual environment
# Ensures the latest version of pip is used for installations
echo -e "${GREEN}Upgrading pip in virtual environment...${NC}"
pip install --upgrade pip
check_command "Upgrading pip"

# Install required Python libraries in the virtual environment
# These are core dependencies for LED control and HTTP requests
echo -e "${GREEN}Installing required Python libraries...${NC}"
pip install rpi_ws281x adafruit-circuitpython-neopixel adafruit-blinka requests
check_command "Installing required libraries"

# Deactivate the virtual environment
# No longer needed until runtime
deactivate

# Set execute permissions on shell scripts
# Allows them to be run directly
echo -e "${GREEN}Setting permissions...${NC}"
chmod +x refresh.sh
check_command "Setting permissions for refresh.sh"
chmod +x lightsoff.sh
check_command "Setting permissions for lightsoff.sh"

# Update script paths to use the current project directory
sed -i "s|PLACEHOLDER_PROJECT_DIR|$PROJECT_DIR|g" lightsoff.sh
sed -i "s|PLACEHOLDER_PROJECT_DIR|$PROJECT_DIR|g" refresh.sh

# Create configuration file based on user input
echo -e "${BOLD}Configuring METARMap settings...${NC}"
echo "Please answer the following questions to customize your setup."
echo ""

# LED Count
read -p "How many LEDs are in your strip? (default: 50): " LED_COUNT
LED_COUNT=${LED_COUNT:-50}

# Wind animation
echo -e "${BLUE}ACTIVATE_WINDCONDITION_ANIMATION: Enable blinking/fading for windy conditions (LEDs animate when wind exceeds threshold).${NC}"
read -p "Enable wind condition animation? (y/n, default: y): " wind_anim
case $wind_anim in
    [Nn]* ) ACTIVATE_WINDCONDITION_ANIMATION=false ;;
    * ) ACTIVATE_WINDCONDITION_ANIMATION=true ;;
esac

# Lightning animation
echo -e "${BLUE}ACTIVATE_LIGHTNING_ANIMATION: Enable flashing for lightning in the vicinity of airports.${NC}"
read -p "Enable lightning animation? (y/n, default: y): " lightning_anim
case $lightning_anim in
    [Nn]* ) ACTIVATE_LIGHTNING_ANIMATION=false ;;
    * ) ACTIVATE_LIGHTNING_ANIMATION=true ;;
esac

# Fade vs blink
echo -e "${BLUE}FADE_INSTEAD_OF_BLINK: Use fade effect instead of on/off blinking for animations.${NC}"
read -p "Use fade instead of blink? (y/n, default: y): " fade_blink
case $fade_blink in
    [Nn]* ) FADE_INSTEAD_OF_BLINK=false ;;
    * ) FADE_INSTEAD_OF_BLINK=true ;;
esac

# Gusts always blink
echo -e "${BLUE}ALWAYS_BLINK_FOR_GUSTS: Always animate LEDs for gusts, regardless of wind speed.${NC}"
read -p "Always blink for gusts? (y/n, default: n): " gusts_blink
case $gusts_blink in
    [Yy]* ) ALWAYS_BLINK_FOR_GUSTS=true ;;
    * ) ALWAYS_BLINK_FOR_GUSTS=false ;;
esac

# Daytime dimming
echo -e "${BLUE}ACTIVATE_DAYTIME_DIMMING: Enable brightness dimming during the day to save energy.${NC}"
read -p "Enable daytime dimming? (y/n, default: y): " dimming
case $dimming in
    [Nn]* ) ACTIVATE_DAYTIME_DIMMING=false ;;
    * ) ACTIVATE_DAYTIME_DIMMING=true ;;
esac

# If dimming enabled, ask for location
if [ "$ACTIVATE_DAYTIME_DIMMING" = true ]; then
    echo -e "${BLUE}USE_SUNRISE_SUNSET: Use actual sunrise/sunset times for dimming (requires city).${NC}"
    read -p "Use sunrise/sunset times? (y/n, default: y): " sunrise_sunset
    case $sunrise_sunset in
        [Nn]* ) USE_SUNRISE_SUNSET=false ;;
        * ) USE_SUNRISE_SUNSET=true ;;
    esac

    if [ "$USE_SUNRISE_SUNSET" = true ]; then
        read -p "Enter your city for sunrise/sunset calculations (default: Detroit): " LOCATION
        LOCATION=${LOCATION:-Detroit}
    else
        LOCATION="Detroit"
    fi
else
    USE_SUNRISE_SUNSET=false
    LOCATION="Detroit"
fi

# External display
echo -e "${BLUE}ACTIVATE_EXTERNAL_METAR_DISPLAY: Enable OLED display for showing detailed METAR information.${NC}"
read -p "Enable external METAR display? (y/n, default: y): " display
case $display in
    [Nn]* ) ACTIVATE_EXTERNAL_METAR_DISPLAY=false ;;
    * ) ACTIVATE_EXTERNAL_METAR_DISPLAY=true ;;
esac

# Legend
echo -e "${BLUE}SHOW_LEGEND: Display a color legend on extra LEDs to show what each color means.${NC}"
read -p "Show color legend? (y/n, default: n): " legend
case $legend in
    [Yy]* ) SHOW_LEGEND=true ;;
    * ) SHOW_LEGEND=false ;;
esac

# Replace missing categories
echo -e "${BLUE}REPLACE_CAT_WITH_CLOSEST: Fill missing flight categories with data from the nearest station.${NC}"
read -p "Replace missing categories with closest station? (y/n, default: y): " replace_cat
case $replace_cat in
    [Nn]* ) REPLACE_CAT_WITH_CLOSEST=false ;;
    * ) REPLACE_CAT_WITH_CLOSEST=true ;;
esac

# Generate config.json
cat > config.json << EOF
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
  "LOCATION": "$LOCATION",
  "ACTIVATE_EXTERNAL_METAR_DISPLAY": $ACTIVATE_EXTERNAL_METAR_DISPLAY,
  "DISPLAY_ROTATION_SPEED": 5.0,
  "SHOW_LEGEND": $SHOW_LEGEND,
  "OFFSET_LEGEND_BY": 0,
  "REPLACE_CAT_WITH_CLOSEST": $REPLACE_CAT_WITH_CLOSEST
}
EOF

echo "Configuration saved to config.json"

# Create airports file if it doesn't exist
# This file lists the airport codes to monitor
if [ -f airports ]; then
    echo "airports file already exists. Skipping creation."
else
    echo "Creating sample airports file..."
    echo "KDTW" > airports
    echo "NULL" >> airports
    check_command "Creating airports file"
    echo "Please edit the airports file to add your desired airports."
fi

# Create display airports file if display is enabled
# This specifies which airports to show on the external display
if [ "$ACTIVATE_EXTERNAL_METAR_DISPLAY" = true ]; then
    if [ -f displayairports ]; then
        echo "displayairports file already exists. Skipping creation."
    else
        echo "Creating sample displayairports file..."
        cp airports displayairports
        check_command "Creating displayairports file"
    fi
fi

# Install optional libraries based on configuration
if [ "$USE_SUNRISE_SUNSET" = true ]; then
    echo -e "${GREEN}Installing astral for sunrise/sunset dimming...${NC}"
    . metarmap_env/bin/activate
    pip install astral
    check_command "Installing astral"
    deactivate
fi

if [ "$ACTIVATE_EXTERNAL_METAR_DISPLAY" = true ]; then
    echo -e "${GREEN}Installing libraries for external display...${NC}"
    # Install system package for image handling
    sudo apt-get install -y python3-pil
    check_command "Installing python3-pil"
    # Activate venv for pip installs
    . metarmap_env/bin/activate
    # Install Python libraries for OLED display control
    pip install adafruit-circuitpython-ssd1306 pillow
    check_command "Installing display libraries"
    deactivate
    # Enable I2C interface for the display hardware
    sudo raspi-config nonint do_i2c 0
    check_command "Enabling I2C"
    echo "I2C enabled. Please reboot after setup if needed."
fi

# Set up cron jobs for automated execution
# This schedules the map to run during the day and turn off at night
echo -e "${GREEN}Setting up crontab...${NC}"
if crontab -l > /dev/null 2>&1; then
    crontab -l > current_crontab
else
    touch current_crontab
fi

# Check if METARMap cron jobs are already configured
# Avoid adding duplicate entries
if grep -q "# METARMap Crontab Configuration" current_crontab; then
    echo "Crontab already configured for METARMap. Skipping crontab setup."
    rm current_crontab
else
    # Create new crontab with METARMap entries
    cat current_crontab > new_crontab
    echo "" >> new_crontab
    echo "# METARMap Crontab Configuration" >> new_crontab
    echo "# This crontab runs the METARMap every 5 minutes from 7 AM to 9 PM," >> new_crontab
    echo "# and turns off the lights at 10 PM." >> new_crontab
    echo "# Project directory: $PROJECT_DIR" >> new_crontab
    echo "# For custom schedules, visit https://crontab.guru/" >> new_crontab
    echo "" >> new_crontab
    echo "# Run METARMap every 5 minutes from 7:00 AM to 9:00 PM" >> new_crontab
    echo "*/5 7-21 * * * $PROJECT_DIR/refresh.sh" >> new_crontab
    echo "" >> new_crontab
    echo "# Turn off lights at 8:00 PM" >> new_crontab
    echo "5 22 * * * $PROJECT_DIR/lightsoff.sh" >> new_crontab

    crontab new_crontab
    check_command "Setting up crontab"
    rm current_crontab new_crontab
fi

# Setup is complete - provide user with next steps
echo -e "${BOLD}Setup complete!${NC}"
echo "To activate the virtual environment in future sessions, run: source $PROJECT_DIR/metarmap_env/bin/activate"
echo "Please edit config.json to customize settings."
echo "Edit airports file to add your airports."
echo "If using display, edit displayairports if needed."
echo "To test, run: sudo $PROJECT_DIR/metarmap_env/bin/python3 $PROJECT_DIR/metar.py"
echo "The system will run automatically via crontab."

# Optional test run
echo ""
echo "Would you like to run a quick test of the LED colors and display?"
echo "The test will light up the first 7 LEDs with colors for VFR (red), MVFR (blue), IFR (green), LIFR (cyan), lightning (white), high winds (yellow), and clear (off)."
echo "If external display is enabled, it will show a sample METAR entry."
read -p "Run test? (y/n): " run_test
if [ "$run_test" = "y" ]; then
    echo -e "${GREEN}Running LED and display test...${NC}"
    . metarmap_env/bin/activate
    python3 -c "
import board
import neopixel
import time
import json
try:
    with open('config.json') as f:
        config = json.load(f)
    LED_COUNT = config['LED_COUNT']
    LED_PIN = eval(config['LED_PIN'])
    LED_BRIGHTNESS = config['LED_BRIGHTNESS']
    LED_ORDER = eval(config['LED_ORDER'])
    ACTIVATE_EXTERNAL_METAR_DISPLAY = config['ACTIVATE_EXTERNAL_METAR_DISPLAY']
    pixels = neopixel.NeoPixel(LED_PIN, LED_COUNT, brightness=LED_BRIGHTNESS, pixel_order=LED_ORDER, auto_write=False)
    # Test colors: VFR, MVFR, IFR, LIFR, lightning, high winds, clear
    colors = [(255,0,0), (0,0,255), (0,255,0), (0,125,125), (255,255,255), (255,255,0), (0,0,0)]
    for i, color in enumerate(colors):
        if i < LED_COUNT:
            pixels[i] = color
            print(f'testing LED {i} with color {color}')
        else:
            break
    pixels.show()
    time.sleep(5)
    if ACTIVATE_EXTERNAL_METAR_DISPLAY:
        try:
            import displaymetar
            disp = displaymetar.startDisplay()
            displaymetar.clearScreen(disp)
            displaymetar.outputMetar(disp, 'TEST', {'flightCategory': 'VFR', 'tempC': 20, 'windSpeed': 10})
            print('Testing external display with sample METAR')
            time.sleep(5)
            displaymetar.clearScreen(disp)
        except Exception as e:
            print(f'Display test failed: {e}')
    pixels.fill((0,0,0))
    pixels.show()
    print('Test complete')
except Exception as e:
    print(f'Test failed: {e}')
"
    deactivate
fi

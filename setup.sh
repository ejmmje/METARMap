#!/bin/bash

# METARMap Setup Script
# This script automates the installation and configuration of the METARMap project on a Raspberry Pi.
# It sets up a virtual environment, installs dependencies, configures files, and schedules cron jobs.
# Run this script with sudo privileges: sudo bash setup.sh

echo "METARMap Setup Script"
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

# Get project directory
PROJECT_DIR=$(pwd)
echo "Project directory: $PROJECT_DIR"

# Update the system's package list and upgrade installed packages
# This ensures the system is up-to-date before installing new software
echo "Updating system packages..."
sudo apt-get update
check_command "apt-get update"
sudo apt-get upgrade -y
check_command "apt-get upgrade"

# Install Python 3, pip, and virtual environment support
# These are required for creating and managing the virtual environment
echo "Installing Python3 and pip3..."
sudo apt-get install -y python3 python3-pip python3-venv
check_command "apt-get install python3 python3-pip python3-venv"

# Create a virtual environment for Python packages
# This isolates the project's dependencies from the system Python
if [ -d metarmap_env ]; then
    echo "Removing existing virtual environment for clean slate..."
    rm -rf metarmap_env
fi
echo "Creating virtual environment..."
python3 -m venv metarmap_env
check_command "Creating virtual environment"
echo "Activating virtual environment..."
. metarmap_env/bin/activate
check_command "Activating virtual environment"

# Upgrade pip inside the virtual environment
# Ensures the latest version of pip is used for installations
echo "Upgrading pip in virtual environment..."
pip install --upgrade pip
check_command "Upgrading pip"

# Install required Python libraries in the virtual environment
# These are core dependencies for LED control and HTTP requests
echo "Installing required Python libraries..."
pip install rpi_ws281x adafruit-circuitpython-neopixel adafruit-blinka requests
check_command "Installing required libraries"

# Prompt user for optional features and install additional libraries if requested
read -p "Do you want to enable sunrise/sunset dimming? (y/n): " dimming
if [ "$dimming" = "y" ]; then
    echo "Installing astral for sunrise/sunset dimming..."
    pip install astral
    check_command "Installing astral"
fi

read -p "Do you want to enable external METAR display? (y/n): " display
if [ "$display" = "y" ]; then
    echo "Installing libraries for external display..."
    # Install system package for image handling
    sudo apt-get install -y python3-pil
    check_command "Installing python3-pil"
    # Install Python libraries for OLED display control
    pip install adafruit-circuitpython-ssd1306 pillow
    check_command "Installing display libraries"
    # Enable I2C interface for the display hardware
    sudo raspi-config nonint do_i2c 0
    check_command "Enabling I2C"
    echo "I2C enabled. Please reboot after setup if needed."
fi

# Deactivate the virtual environment
# No longer needed until runtime
deactivate

# Set execute permissions on shell scripts
# Allows them to be run directly
echo "Setting permissions..."
chmod +x refresh.sh
check_command "Setting permissions for refresh.sh"
chmod +x lightsoff.sh
check_command "Setting permissions for lightsoff.sh"

# Update script paths to use the current project directory
sed -i "s|PLACEHOLDER_PROJECT_DIR|$PROJECT_DIR|g" lightsoff.sh
sed -i "s|PLACEHOLDER_PROJECT_DIR|$PROJECT_DIR|g" refresh.sh

# Create configuration file if it doesn't exist
# This file contains settings like LED count, colors, etc.
if [ -f config.json ]; then
    echo "config.json already exists. Skipping creation."
else
    echo "Creating default config.json..."
    if [ -f config.json.example ]; then
        cp config.json.example config.json
        check_command "Copying config.json.example to config.json"
    else
        echo "Warning: config.json.example not found. Please create config.json manually."
    fi
fi

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
if [ "$display" = "y" ]; then
    if [ -f displayairports ]; then
        echo "displayairports file already exists. Skipping creation."
    else
        echo "Creating sample displayairports file..."
        cp airports displayairports
        check_command "Creating displayairports file"
    fi
fi

# Set up cron jobs for automated execution
# This schedules the map to run during the day and turn off at night
echo "Setting up crontab..."
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
    echo "# This crontab runs the METARMap every 5 minutes from 7 AM to 7 PM," >> new_crontab
    echo "# and turns off the lights at 8 PM." >> new_crontab
    echo "# Project directory: $PROJECT_DIR" >> new_crontab
    echo "# For custom schedules, visit https://crontab.guru/" >> new_crontab
    echo "" >> new_crontab
    echo "# Run METARMap every 5 minutes from 7:00 AM to 7:00 PM" >> new_crontab
    echo "*/5 7-18 * * * $PROJECT_DIR/refresh.sh" >> new_crontab
    echo "" >> new_crontab
    echo "# Turn off lights at 8:00 PM" >> new_crontab
    echo "5 19 * * * $PROJECT_DIR/lightsoff.sh" >> new_crontab

    crontab new_crontab
    check_command "Setting up crontab"
    rm current_crontab new_crontab
fi

# Setup is complete - provide user with next steps
echo "Setup complete!"
echo "To activate the virtual environment in future sessions, run: source $PROJECT_DIR/metarmap_env/bin/activate"
echo "Please edit config.json to customize settings."
echo "Edit airports file to add your airports."
echo "If using display, edit displayairports if needed."
echo "To test, run: sudo $PROJECT_DIR/metarmap_env/bin/python3 $PROJECT_DIR/metar.py"
echo "The system will run automatically via crontab."

# METARMap

A Raspberry Pi project to visualize flight conditions on a map using WS2811 LEDs. The LEDs change colors based on METAR weather data from aviationweather.gov.

## Features

- Real-time weather visualization with color-coded LEDs
- Support for wind and lightning animations
- Optional daytime dimming based on sunrise/sunset
- Optional external mini OLED display for METAR details
- Automated scheduling via crontab

## Prerequisites

- Raspberry Pi (any model with GPIO)
- WS2811 LED strip (or compatible)
- Optional: Mini OLED display (SSD1306) for METAR details
- Internet connection for fetching weather data
- Basic knowledge of connecting LEDs to Raspberry Pi GPIO

## Hardware Setup

1. Connect the WS2811 LED strip to your Raspberry Pi:
   - Data pin to GPIO 18 (physical pin 12)
   - Power and ground as appropriate
   - For more details, see the [Adafruit NeoPixel guide](https://learn.adafruit.com/neopixels-on-raspberry-pi)

2. If using the optional display:
   - Connect the SSD1306 OLED display via I2C
   - Enable I2C in raspi-config

## Installation

***If you have already installed this version before and just need to update to the newest version - [skip to here](#updates)***

1. Log into your Raspberry Pi via SSH or terminal.

2. Download or clone this repository to your Raspberry Pi. If needed install git first:
   ```
   git --version || sudo apt install git -y
   ```
   Then clone the repo:
   ```
   git clone --branch docker_support https://github.com/ejmmje/METARMap.git
   cd METARMap
   ```

3. Run the setup script next. The only part of the setup that is not necessarily automatic is the crontab setup. The script looks to see if anything already exists so that it doesn't overwrite anything. So, clear out the sudo crontab if you want or edit it yourself manually afterwords:
   ```
   sudo bash setup.sh
   ```
   This will install dependencies, set permissions, and configure crontab.

4. If using an external display, you may need to reboot after I2C was enabled for the display.
    ```
    sudo reboot
    ```
   
5. This is it! The map should now run on the next 5 minute mark between 7:00am and 9:59pm based on the example airports listed in the airports file. To edit them, see the Configuration section below.

## Configuration


### Airports

### Changing airports display

You need to do this *manually* by editing the `airports` file. If you have an external display and wish to only display a subset, you need to ALSO edit the `displayairports` file.
For example, to edit the airports file:

```
nano airports
```
I recommend typing out your airport codes in a text editor on your computer, then copying and pasting into the terminal window.

To cut out the existing contents inside aiports, first ```nano``` then hold `Ctrl+K` to cut all lines, then paste your new list.


Edit the `airports` file to include the ICAO codes of the airports you want to monitor. Each airport on a new line. Use "NULL" for gaps in your LED strip.

Example:
```
KDTW
NULL
KJFK
KLAX
```

Make your changes, then save and exit by pressing `Ctrl+X`, then `Y`, then `Enter`.

**FULL CODE EXAMPLE:**
```
nano airports
```
- Ctrl+K to cut all lines
- Copy your new list from your text editor
- Shift + Insert to paste in your new list or Ctrl+V
- Ctrl+X, then Y, then Enter to save and exit

### Display Airports (Optional)

If using the external display, edit `displayairports` to specify which airports to show details for. If not present, all airports will rotate.

### To Change any other settings not set by the setup script
Edit the `config.json` file to customize settings such as colors, animation speeds, and more.

```
sudo nano config.json
```

## Final Considerations
Make sure that you disable any cron jobs from the previous version of METARMap if you had it installed before. You can do this by running:
```
sudo crontab -e
```

The only cron jobs that should be there are the ones added by the setup script. If you see any others, delete them.
They follow this general format:
```
# METARMap Crontab Configuration
# This crontab runs the METARMap every 5 minutes from 7 AM to 9 PM,
# and turns off the lights at 10 PM.
# Project directory: /This/is/Different/for/Everyone/METARMap
# For custom schedules, visit https://crontab.guru/

# Run METARMap every 5 minutes from 7:00 AM to 9:00 PM
*/5 7-21 * * * /This/is/Different/for/Everyone/refresh.sh

# Turn off lights at 8:00 PM
5 22 * * * /This/is/Different/for/Everyone/lightsoff.sh
```

## Updates
To update the code only, run the following commands in the METARMap directory:
```
sudo bash update.sh
```
This code will save your airports and displayairports files, pull the latest code from GitHub, and restore your airport files. It will initiate a re-run of the setup file as well. 

## Settings List for Reference or Custom Configuration

Edit `config.json` to customize the behavior of METARMap. Below is a detailed explanation of each configuration option:

#### LED Hardware Configuration
- **`LED_COUNT`**: Number of LEDs in your WS2811 strip. Must match the physical number of LEDs. Example: `50`
- **`LED_PIN`**: GPIO pin connected to the LED strip data line. For Raspberry Pi, use `"board.D18"` (GPIO 18). Example: `"board.D18"`
- **`LED_BRIGHTNESS`**: Default brightness level for the LEDs. Range: 0.0 (off) to 1.0 (full brightness). Example: `0.5`
- **`LED_ORDER`**: Color order of your LED strip. Usually `"neopixel.GRB"` for most WS2811 strips. Example: `"neopixel.GRB"`

#### Color Definitions
RGB color values (0-255) for different flight categories:
- **`COLOR_VFR`**: Color for Visual Flight Rules (good weather). Default: `[255, 0, 0]` (Green)
- **`COLOR_VFR_FADE`**: Faded color for VFR animations. Default: `[125, 0, 0]` (Green Fade)
- **`COLOR_MVFR`**: Color for Marginal VFR (moderate weather). Default: `[0, 0, 255]` (Blue)
- **`COLOR_MVFR_FADE`**: Faded color for MVFR animations. Default: `[0, 0, 125]` (Blue Fade)
- **`COLOR_IFR`**: Color for Instrument Flight Rules (poor weather). Default: `[0, 255, 0]` (Red)
- **`COLOR_IFR_FADE`**: Faded color for IFR animations. Default: `[0, 125, 0]` (Red Fade)
- **`COLOR_LIFR`**: Color for Low IFR (very poor weather). Default: `[0, 125, 125]` (Magenta)
- **`COLOR_LIFR_FADE`**: Faded color for LIFR animations. Default: `[0, 75, 75]` (Magenta Fade)
- **`COLOR_CLEAR`**: Color for no data or off. Default: `[0, 0, 0]` (Clear)
- **`COLOR_LIGHTNING`**: Color for lightning conditions. Default: `[255, 255, 255]` (White)
- **`COLOR_HIGH_WINDS`**: Color for high wind conditions. Default: `[255, 255, 0]` (Yellow)

#### Animation Settings
- **`ACTIVATE_WINDCONDITION_ANIMATION`**: Enable blinking/fading for windy conditions. Set to `true` or `false`. Default: `true`
- **`ACTIVATE_LIGHTNING_ANIMATION`**: Enable flashing for lightning in vicinity. Set to `true` or `false`. Default: `true`
- **`FADE_INSTEAD_OF_BLINK`**: Use fade effect instead of on/off blink. Set to `true` or `false`. Default: `true`
- **`WIND_BLINK_THRESHOLD`**: Wind speed (knots) to trigger wind animation. Example: `15`
- **`HIGH_WINDS_THRESHOLD`**: Wind speed for high winds (yellow color). Set to `-1` to disable. Example: `25`
- **`ALWAYS_BLINK_FOR_GUSTS`**: Always animate for gusts regardless of speed. Set to `true` or `false`. Default: `false`
- **`BLINK_SPEED`**: Speed of animation cycles in seconds. Example: `2.0`
- **`BLINK_TOTALTIME_SECONDS`**: Total time the script runs in seconds. Example: `300` (5 minutes)

#### Daytime Dimming Settings
- **`ACTIVATE_DAYTIME_DIMMING`**: Enable brightness dimming during the day. Set to `true` or `false`. Default: `true`
- **`BRIGHT_TIME_START`**: Time to start full brightness (HH:MM). Example: `"07:00"`
- **`DIM_TIME_START`**: Time to start dimming (HH:MM). Example: `"19:00"`
- **`LED_BRIGHTNESS_DIM`**: Dimmed brightness level (0.0 to 1.0). Example: `0.1`
- **`USE_SUNRISE_SUNSET`**: Use actual sunrise/sunset times instead of fixed times. Set to `true` or `false`. Default: `true`
- **`LOCATION`**: City name for sunrise/sunset calculations (if enabled). Example: `"Detroit"`

#### External Display Settings
- **`ACTIVATE_EXTERNAL_METAR_DISPLAY`**: Enable the OLED display for METAR details. Set to `true` or `false`. Default: `true`
- **`DISPLAY_ROTATION_SPEED`**: Seconds between display updates. Example: `5.0`

#### Legend Display Settings
- **`SHOW_LEGEND`**: Show a color legend on extra LEDs. Set to `true` or `false`. Default: `false`
- **`OFFSET_LEGEND_BY`**: Position offset for the legend. Example: `0`

#### Data Processing Settings
- **`REPLACE_CAT_WITH_CLOSEST`**: Fill missing flight categories with the nearest station's data. Set to `true` or `false`. Default: `true`

## Testing

To test the setup:
```
sudo metarmap_env/bin/python3 metar.py
```

The LEDs should light up according to current weather conditions.

## Running Automatically

The setup script configures crontab to run the map every 5 minutes between 7:00 AM and 9:59 PM, and turn off lights at 10:05 PM.

To view or modify the schedule:
```
sudo crontab -e
```

## Flight Categories

- **VFR (Visual Flight Rules)**: Green - Good weather
- **MVFR (Marginal VFR)**: Blue - Moderate weather
- **IFR (Instrument Flight Rules)**: Red - Poor weather
- **LIFR (Low IFR)**: Magenta - Very poor weather

## Animations

- **Wind**: LEDs fade/blink for windy conditions
- **Lightning**: White flashes for thunderstorms
- **High Winds**: Yellow for very high winds

## Troubleshooting

- Ensure the Raspberry Pi has internet access
- Check LED connections and power supply
- Verify airport codes are correct ICAO codes
- For display issues, ensure I2C is enabled and wiring is correct



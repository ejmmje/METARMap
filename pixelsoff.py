# METARMap LED Shutdown Script
# This script turns off all LEDs and optionally shuts down the external display.
# It is used to cleanly stop the LED display when the system is shutting down or at night.

# Import required libraries
import board  # For GPIO pin definitions
import neopixel  # For controlling WS2811 LED strips
import json  # For loading configuration

# Load configuration from JSON file
# This ensures we use the same LED settings as the main script
with open('config.json') as f:
    config = json.load(f)

# Try to import the display module
# If not available, display functionality will be skipped
try:
    import displaymetar  # Custom module for external OLED display
except ImportError:
    displaymetar = None  # Set to None if not installed

# Initialize the LED strip with the configured settings
pixels = neopixel.NeoPixel(eval(config['LED_PIN']), config['LED_COUNT'])

# Turn off all LEDs by deinitializing the strip
pixels.deinit()

# If the display module is available, shut down the external display
if displaymetar is not None:
    disp = displaymetar.startDisplay()  # Initialize display
    displaymetar.shutdownDisplay(disp)  # Shut down display

print("LEDs off")  # Confirmation message

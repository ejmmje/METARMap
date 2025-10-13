# METARMap Display Module
# This module handles the external OLED display for showing METAR information.
# It provides functions to initialize, clear, and update the display with weather data.

# Try to import required libraries for the display
# If not available, set a flag to disable display functionality
try:
    from board import SCL, SDA  # GPIO pins for I2C communication
    import busio  # For I2C bus interface
    from PIL import Image, ImageDraw, ImageFont  # For image creation and text drawing
    import adafruit_ssd1306  # SSD1306 OLED display driver
    noDisplayLibraries = False  # Libraries are available
except ImportError:
    noDisplayLibraries = True  # Libraries not installed, disable display

# This additional file is to support the functionality for an external display
# If you only want to have the LEDs light up, then you do not need this file

# Function to initialize and start the OLED display
def startDisplay():
    if noDisplayLibraries:  # Check if libraries are available
        return None  # Return None if display cannot be used

    # Create I2C bus using SCL and SDA pins
    i2c = busio.I2C(SCL, SDA)
    # Initialize SSD1306 display with 128x64 resolution
    disp = adafruit_ssd1306.SSD1306_I2C(128, 64, i2c)
    disp.poweron()  # Turn on the display
    return disp  # Return the display object

# Function to shut down the display
def shutdownDisplay(disp):
    if noDisplayLibraries:  # Check if libraries are available
        return  # Do nothing if display not available

    disp.poweroff()  # Turn off the display

# Function to clear the display screen
def clearScreen(disp):
    if noDisplayLibraries:  # Check if libraries are available
        return  # Do nothing if display not available

    disp.fill(0)  # Fill display with black (clear)
    disp.show()  # Update the display

# Function to output METAR information to the display
def outputMetar(disp, station, condition):
    if noDisplayLibraries:  # Check if libraries are available
        return  # Do nothing if display not available

    # Get display dimensions
    width = disp.width
    height = disp.height
    padding = -2  # Padding for text positioning
    x = 0  # Starting x position
    # Create a new black and white image for the display
    image = Image.new("1", (width, height))
    draw = ImageDraw.Draw(image)
    # Draw a black filled box to clear the image.
    draw.rectangle((0, 0, width, height), outline=0, fill=0)

    top = padding  # Top margin
    bottom = height - padding  # Bottom margin

    # Load fonts for different text sizes
    fontLarge = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 16)
    fontSmall = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 10)

    # Draw a vertical line separator
    draw.line([(x + 62, top + 18), (x + 62, bottom)], fill=255, width=1)

    # Draw the station code and flight category
    draw.text((x, top + 0), station + "-" + condition["flightCategory"], font=fontLarge, fill=255)
    # Draw the observation time
    draw.text((x + 90, top + 0), condition["obsTime"].strftime("%H:%MZ"), font=fontSmall, fill=255)

    # Draw wind information
    draw.text((x, top + 15), condition["windDir"] + "@" + str(condition["windSpeed"]) + ("G" + str(condition["windGustSpeed"]) if condition["windGust"] else ""), font=fontSmall, fill=255)
    # Draw visibility and weather observations
    draw.text((x + 64, top + 15), str(condition["vis"]) + "SM " + condition["obs"], font=fontSmall, fill=255)
    # Draw temperature and dewpoint
    draw.text((x, top + 25), str(condition["tempC"]) + "C/" + str(condition["dewpointC"]) + "C", font=fontSmall, fill=255)
    # Draw altimeter setting
    draw.text((x + 64, top + 25), "A" + str(condition["altimHg"]) + "Hg", font=fontSmall, fill=255)
    yOff = 35  # Starting y offset for sky conditions
    xOff = 0  # Starting x offset
    NewLine = False  # Flag for alternating lines
    # Draw sky conditions (clouds)
    for skyIter in condition["skyConditions"]:
        draw.text((x + xOff, top + yOff), skyIter["cover"] + ("@" + str(skyIter["base"]) if skyIter["base"] > 0 else ""), font=fontSmall, fill=255)
        if NewLine:  # If on a new line
            yOff += 10  # Move down
            xOff = 0  # Reset x
            NewLine = False  # Reset flag
        else:
            xOff = 64  # Move to right column
            NewLine = True  # Set flag for next iteration
    # Send the image to the display
    disp.image(image)
    disp.show()

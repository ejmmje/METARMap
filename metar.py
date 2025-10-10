#!/usr/bin/env python3
import json
import urllib.request
import xml.etree.ElementTree as ET
import board
import neopixel
import time
import datetime
import math
import requests

try:
    import astral
except ImportError:
    astral = None
try:
    import displaymetar
except ImportError:
    displaymetar = None

# metar.py script iteration 1.7.0 (added fltCat fallback by nearest airport)

# ---------------------------------------------------------------------------
# ------------START OF CONFIGURATION-----------------------------------------
# ---------------------------------------------------------------------------

# NeoPixel LED Configuration
LED_COUNT        = 50
LED_PIN          = board.D18
LED_BRIGHTNESS   = 0.5
LED_ORDER        = neopixel.GRB

COLOR_VFR        = (255,0,0)
COLOR_VFR_FADE   = (125,0,0)
COLOR_MVFR       = (0,0,255)
COLOR_MVFR_FADE  = (0,0,125)
COLOR_IFR        = (0,255,0)
COLOR_IFR_FADE   = (0,125,0)
COLOR_LIFR       = (0,125,125)
COLOR_LIFR_FADE  = (0,75,75)
COLOR_CLEAR      = (0,0,0)
COLOR_LIGHTNING  = (255,255,255)
COLOR_HIGH_WINDS = (255,255,0)

ACTIVATE_WINDCONDITION_ANIMATION = True
ACTIVATE_LIGHTNING_ANIMATION     = True
FADE_INSTEAD_OF_BLINK            = True
WIND_BLINK_THRESHOLD             = 15
HIGH_WINDS_THRESHOLD             = 25
ALWAYS_BLINK_FOR_GUSTS           = False
BLINK_SPEED                      = 1.0
BLINK_TOTALTIME_SECONDS          = 300

ACTIVATE_DAYTIME_DIMMING         = True
BRIGHT_TIME_START                = datetime.time(7,0)
DIM_TIME_START                   = datetime.time(19,0)
LED_BRIGHTNESS_DIM               = 0.1
USE_SUNRISE_SUNSET               = True
LOCATION                         = "Detroit"

ACTIVATE_EXTERNAL_METAR_DISPLAY  = True
DISPLAY_ROTATION_SPEED           = 5.0

SHOW_LEGEND                      = False
OFFSET_LEGEND_BY                 = 0

# Replace missing fltCat with nearest valid station's fltCat
REPLACE_CAT_WITH_CLOSEST         = True

# ---------------------------------------------------------------------------
# ------------END OF CONFIGURATION-------------------------------------------
# ---------------------------------------------------------------------------

print("Running metar.py at " + datetime.datetime.now().strftime('%d/%m/%Y %H:%M'))

# Figure out sunrise/sunset times if astral is being used
if astral is not None and USE_SUNRISE_SUNSET:
    try:
        ast = astral.Astral()
        try:
            city = ast[LOCATION]
        except KeyError:
            print("Error: Location not recognized, please check list of supported cities and reconfigure")
        else:
            print(city)
            sun = city.sun(date = datetime.datetime.now().date(), local = True)
            BRIGHT_TIME_START = sun['sunrise'].time()
            DIM_TIME_START = sun['sunset'].time()
    except AttributeError:
        import astral.geocoder
        import astral.sun
        try:
            city = astral.geocoder.lookup(LOCATION, astral.geocoder.database())
        except KeyError:
            print("Error: Location not recognized, please check list of supported cities and reconfigure")
        else:
            print(city)
            sun = astral.sun.sun(city.observer, date = datetime.datetime.now().date(), tzinfo=city.timezone)
            BRIGHT_TIME_START = sun['sunrise'].time()
            DIM_TIME_START = sun['sunset'].time()
    print("Sunrise:" + BRIGHT_TIME_START.strftime('%H:%M') + " Sunset:" + DIM_TIME_START.strftime('%H:%M'))

# Initialize the LED strip
bright = BRIGHT_TIME_START < datetime.datetime.now().time() < DIM_TIME_START
print("Wind animation:" + str(ACTIVATE_WINDCONDITION_ANIMATION))
print("Lightning animation:" + str(ACTIVATE_LIGHTNING_ANIMATION))
print("Daytime Dimming:" + str(ACTIVATE_DAYTIME_DIMMING) + (" using Sunrise/Sunset" if USE_SUNRISE_SUNSET and ACTIVATE_DAYTIME_DIMMING else ""))
print("External Display:" + str(ACTIVATE_EXTERNAL_METAR_DISPLAY))
pixels = neopixel.NeoPixel(LED_PIN, LED_COUNT, brightness = LED_BRIGHTNESS_DIM if (ACTIVATE_DAYTIME_DIMMING and bright == False) else LED_BRIGHTNESS, pixel_order = LED_ORDER, auto_write = False)

# Read airports
with open("PATH/TO/airports") as f:
    airports = f.readlines()
airports = [x.strip() for x in airports]
try:
    with open("PATH/TO/displaymetar.py") as f2:
        displayairports = f2.readlines()
    displayairports = [x.strip() for x in displayairports]
    print("Using subset airports for LED display")
except IOError:
    print("Rotating through all airports on LED display")
    displayairports = None

if len(airports) > LED_COUNT:
    print()
    print("WARNING: Too many airports in airports file, please increase LED_COUNT or reduce the number of airports")
    print("Airports: " + str(len(airports)) + " LED_COUNT: " + str(LED_COUNT))
    print()
    quit()

# --- Safe parsing helpers ---
def safe_int(value, default=0):
    try:
        return int(float(str(value).strip() or default))
    except (ValueError, TypeError):
        return default

def safe_float(value, default=0.0):
    try:
        return float(str(value).strip() or default)
    except (ValueError, TypeError):
        return default

def safe_str(value, default=""):
    return str(value).strip() if value not in [None, "None"] else default

def safe_round(value, default=0.0):
    try:
        return round(float(str(value).strip() or default))
    except (ValueError, TypeError):
        return default

 # -- Take nearest valid station's fltCat if missing --
def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0  # km
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# --- Fetch METAR data ---
url = f'https://aviationweather.gov/api/data/metar?ids={",".join([item for item in airports if item != "NULL"])}&format=json&taf=false'
print(url)

req = requests.get(url)
output = json.loads(req.text)

# --- Parse response ---
station_count = 0
conditionDict = {}
station_list = []
station_meta = []

for location in output:
    icaoId = safe_str(location.get("icaoId"))
    receiptTime = safe_str(location.get("receiptTime"))
    # 1. Pulls Obs time
    obsTime = safe_str(location.get("obsTime"))
    # 2. Converts to datetime for display
    try:
        obsTime = datetime.datetime.fromtimestamp(int(obsTime))
    except ValueError:
        # Default to epoch if invalid 00:00Z
        obsTime = datetime.datetime(1970, 1, 1)

    reportTimeE = safe_str(location.get("reportTime"))
    temp = safe_round(location.get("temp", 0.0))
    dewp = safe_round(location.get("dewp", 0.0))
    wdir = safe_str(location.get("wdir"))
    wspd = safe_int(location.get("wspd", 0))
    wgst_speed = safe_int(location.get("wgst", 0))
    wgst = True if ALWAYS_BLINK_FOR_GUSTS or wgst_speed > WIND_BLINK_THRESHOLD else False

    visib_str = str(location.get("visib") or "0").replace("+", "").strip()
    visib = safe_int(visib_str)

    altim = safe_float(location.get("altim", 0.0))
    slp = safe_float(location.get("slp", 0.0))
    wxString = safe_str(location.get("wxString"))
    presTend = safe_float(location.get("presTend", 0.0))
    maxT = safe_float(location.get("maxT", 0.0))
    minT = safe_float(location.get("minT", 0.0))
    maxT24 = safe_float(location.get("maxT24", 0.0))
    minT24 = safe_float(location.get("minT24", 0.0))
    precip = safe_float(location.get("precip", 0.0))
    pcp3hr = safe_float(location.get("pcp3hr", 0.0))
    pcp6hr = safe_float(location.get("pcp6hr", 0.0))
    pcp24hr = safe_float(location.get("pcp24hr", 0.0))
    snow = safe_float(location.get("snow", 0.0))
    vertVis = safe_int(location.get("vertVis", 0))
    metarType = safe_str(location.get("metarType"))
    rawOb = safe_str(location.get("rawOb"))
    lat = safe_float(location.get("lat", 0.0))
    lon = safe_float(location.get("lon", 0.0))
    elev = safe_int(location.get("elev", 0))
    name = safe_str(location.get("name"))
    clouds = location.get("clouds") or []
    # Base cloud conditions
    if clouds:
        cloudBaseFt = int(clouds[0]["base"])
    else:
        cloudBaseFt = 0

    fltCat = safe_str(location.get("fltCat"))

    # --- Lightning detection ---
    raw_upper = rawOb.upper()
    lightning = not (
        (raw_upper.find("LTG", 4) == -1 and raw_upper.find("TS", 4) == -1)
        or raw_upper.find("TSNO", 4) != -1
    )

    # --- Populate results ---
    if icaoId:
        station_count += 1
        conditionDict[icaoId] = {
            "flightCategory": fltCat,
            "obsTime": obsTime,
            "windDir": wdir,
            "windSpeed": wspd,
            "windGust": wgst,
            "windGustSpeed": wgst_speed,
            "vis": visib,
            "obs": wxString,
            "tempC": temp,
            "dewpointC": dewp,
            "altimHg": altim,
            "skyConditions": clouds,
            "cloudBaseFt": cloudBaseFt,
            "lightning": lightning,
        }
        station_list.append(icaoId)

        # --- store for lookup ---
        station_meta.append({
            "icaoId": icaoId,
            "lat": lat,
            "lon": lon,
            "fltCat": fltCat
        })

print(f"Parsed {station_count} stations.")

# --- fill missing fltCat by nearest valid station ---
valid_stations = [s for s in station_meta if s["fltCat"] and s["lat"] and s["lon"]]

for s in station_meta:
    if not s["fltCat"] and s["lat"] and s["lon"] and valid_stations and REPLACE_CAT_WITH_CLOSEST:
        nearest = None
        nearest_dist = float("inf")
        for ref in valid_stations:
            dist = haversine(s["lat"], s["lon"], ref["lat"], ref["lon"])
            if dist < nearest_dist:
                nearest = ref
                nearest_dist = dist
        if nearest:
            conditionDict[s["icaoId"]]["flightCategory"] = nearest["fltCat"]
            print(f"{s['icaoId']} missing fltCat — using nearest {nearest['icaoId']} ({nearest_dist:.1f} km, {nearest['fltCat']})")


# Start up external display output
disp = None
if displaymetar is not None and ACTIVATE_EXTERNAL_METAR_DISPLAY:
    print("setting up external display")
    disp = displaymetar.startDisplay()
    displaymetar.clearScreen(disp)


# Setting LED colors based on weather conditions
looplimit = int(round(BLINK_TOTALTIME_SECONDS / BLINK_SPEED)) if (ACTIVATE_WINDCONDITION_ANIMATION or ACTIVATE_LIGHTNING_ANIMATION or ACTIVATE_EXTERNAL_METAR_DISPLAY) else 1

windCycle = False
displayTime = 0.0
displayAirportCounter = 0
numAirports = station_count
while looplimit > 0:
    i = 0
    for airportcode in airports:
        # Skip NULL entries
        if airportcode == "NULL":
            i += 1
            continue

        color = COLOR_CLEAR
        conditions = conditionDict.get(airportcode, None)
        windy = False
        highWinds = False
        lightningConditions = False

        if conditions != None:
            windy = True if (ACTIVATE_WINDCONDITION_ANIMATION and windCycle == True and (conditions["windSpeed"] >= WIND_BLINK_THRESHOLD or conditions["windGust"] == True)) else False
            highWinds = True if (windy and HIGH_WINDS_THRESHOLD != -1 and (conditions["windSpeed"] >= HIGH_WINDS_THRESHOLD or conditions["windGustSpeed"] >= HIGH_WINDS_THRESHOLD)) else False
            lightningConditions = True if (ACTIVATE_LIGHTNING_ANIMATION and windCycle == False and conditions["lightning"] == True) else False
            if conditions["flightCategory"] == "VFR":
                color = COLOR_VFR if not (windy or lightningConditions) else COLOR_LIGHTNING if lightningConditions else COLOR_HIGH_WINDS if highWinds else (COLOR_VFR_FADE if FADE_INSTEAD_OF_BLINK else COLOR_CLEAR) if windy else COLOR_CLEAR
            elif conditions["flightCategory"] == "MVFR":
                color = COLOR_MVFR if not (windy or lightningConditions) else COLOR_LIGHTNING if lightningConditions else COLOR_HIGH_WINDS if highWinds else (COLOR_MVFR_FADE if FADE_INSTEAD_OF_BLINK else COLOR_CLEAR) if windy else COLOR_CLEAR
            elif conditions["flightCategory"] == "IFR":
                color = COLOR_IFR if not (windy or lightningConditions) else COLOR_LIGHTNING if lightningConditions else COLOR_HIGH_WINDS if highWinds else (COLOR_IFR_FADE if FADE_INSTEAD_OF_BLINK else COLOR_CLEAR) if windy else COLOR_CLEAR
            elif conditions["flightCategory"] == "LIFR":
                color = COLOR_LIFR if not (windy or lightningConditions) else COLOR_LIGHTNING if lightningConditions else COLOR_HIGH_WINDS if highWinds else (COLOR_LIFR_FADE if FADE_INSTEAD_OF_BLINK else COLOR_CLEAR) if windy else COLOR_CLEAR
            else:
                color = COLOR_CLEAR

        print("Setting LED " + str(i) + " for " + airportcode + " to " + ("lightning " if lightningConditions else "") + ("very " if highWinds else "") + ("windy " if windy else "") + (conditions["flightCategory"] if conditions != None else "None") + " " + str(color))
        pixels[i] = color
        i += 1

    # Legend
    if SHOW_LEGEND:
        pixels[i + OFFSET_LEGEND_BY] = COLOR_VFR
        pixels[i + OFFSET_LEGEND_BY + 1] = COLOR_MVFR
        pixels[i + OFFSET_LEGEND_BY + 2] = COLOR_IFR
        pixels[i + OFFSET_LEGEND_BY + 3] = COLOR_LIFR
        if ACTIVATE_LIGHTNING_ANIMATION == True:
            pixels[i + OFFSET_LEGEND_BY + 4] = COLOR_LIGHTNING if windCycle else COLOR_VFR # lightning
        if ACTIVATE_WINDCONDITION_ANIMATION == True:
            pixels[i+ OFFSET_LEGEND_BY + 5] = COLOR_VFR if not windCycle else (COLOR_VFR_FADE if FADE_INSTEAD_OF_BLINK else COLOR_CLEAR)    # windy
            if HIGH_WINDS_THRESHOLD != -1:
                pixels[i + OFFSET_LEGEND_BY + 6] = COLOR_VFR if not windCycle else COLOR_HIGH_WINDS  # high winds

    # Update actual LEDs all at once
    pixels.show()

    # Rotate through airports METAR on external display
    if disp is not None:
        if displayTime <= DISPLAY_ROTATION_SPEED:
            displaymetar.outputMetar(disp, station_list[displayAirportCounter], conditionDict.get(station_list[displayAirportCounter], None))
            displayTime += BLINK_SPEED
        else:
            displayTime = 0.0
            displayAirportCounter = displayAirportCounter + 1 if displayAirportCounter < numAirports-1 else 0
            print("showing METAR Display for " + station_list[displayAirportCounter])

    # Switching between animation cycles
    time.sleep(BLINK_SPEED)
    windCycle = False if windCycle else True
    looplimit -= 1

print()
print("Done")



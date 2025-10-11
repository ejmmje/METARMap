FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    gcc \
    make \
    build-essential \
    cron \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    rpi_ws281x \
    adafruit-circuitpython-neopixel \
    requests \
    astral \
    adafruit-circuitpython-ssd1306 \
    pillow

COPY metar.py pixelsoff.py airports refresh.sh lightsoff.sh displaymetar.py start.sh /app/

WORKDIR /app

RUN chmod +x refresh.sh lightsoff.sh start.sh

CMD ["./start.sh"]
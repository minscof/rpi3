#!/bin/bash
#
# https://www.jeffgeerling.com/blogs/jeff-geerling/controlling-pwr-act-leds-raspberry-pi
#
set -x

echo none >/sys/class/leds/led0/trigger
echo 0 >/sys/class/leds/led0/brightness
echo 0 >/sys/class/leds/led1/brightness
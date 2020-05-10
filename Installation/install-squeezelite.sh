#!/bin/bash
#
# Automatisation de l'installation de squeeze lite sur un serveur raspberry
#
# http://www.compu-tek.fr/blog/tutoriel-installer-squeezelite-sur-raspbian/
# http://www.geekmag.fr/installer-squeezelite-sur-raspbian/
#

set -x

ipLms="192.168.0.30"
sudo apt-get install -y libflac-dev libfaad2 libmad0
cd ~
mkdir squeezelite
cd squeezelite
wget http://www.gerrelt.nl/RaspberryPi/squeezelite_settings.sh
sudo mv squeezelite_settings.sh /usr/local/bin
sudo chmod a+x /usr/local/bin/squeezelite_settings.sh
wget http://www.gerrelt.nl/RaspberryPi/squeezelitehf.sh
sudo mv squeezelitehf.sh /etc/init.d/squeezelite
sudo chmod a+x /etc/init.d/squeezelite
wget http://www.gerrelt.nl/RaspberryPi/squeezelite.service
sudo mv squeezelite.service /etc/systemd/system
sudo systemctl enable squeezelite.service
wget -O squeezelite-armv6hf http://ralph_irving.users.sourceforge.net/pico/squeezelite-armv6hf-noffmpeg
sudo mv squeezelite-armv6hf /usr/bin
sudo chmod a+x /usr/bin/squeezelite-armv6hf
sudo /usr/bin/squeezelite-armv6hf -l
sudo /usr/bin/squeezelite-armv6hf -o default:CARD=ALSA -s ${ipLms}
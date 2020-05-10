#!/bin/sh
#
# Partir d'un raspberry avec la distribution raspbian installée et opérationnelle, de préférence sur un disque SSD plutôt qu'une carte sd pas assez fiable
# cf ce tuto : https://www.jeedom.com/forum/viewtopic.php?f=152&t=27615&hilit=rpi+ssd
# 1 Préparer\Graver votre SSD avec la derniere image Raspbian Lite : https://downloads.raspberrypi.org/raspbian_lite_latest (utiliser win32diskimager - initialiser le disque (GPT) et créer un volume sans le formater pour obtenir une lettre d'accès
# 2 Créer un fichier "ssh" sans extension sur la partition boot du SSD (la partition /boot est la seule accessible quand le SSD est branché à votre PC)
#
#
# Automatisation de l'installation du serveur jeedom
#

#Changer adresse mac : pourquoi ? pour garder l'adresse IP 192.168.0.9 sans doute
#Optionnel
#sudo nano /boot/cmdline.txt
#dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p7 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait smsc95xx.macaddr=b8:27:eb:ec:91:d0


#max memory for server (min for graphic..)
sudo echo "gpu_mem=16" >> /boot/config.txt

#max de puissance sur les ports USB
sudo echo "max_usb_current=1" >> /boot/config.txt

#désactiver le wifi
sudo echo "dtoverlay=pi3-disable-wifi" >> /boot/config.txt

#désactiver le bluetooth interne si dongle externe
#sudo echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt

#réduire la fréquence GPU pour être compatible RPI2 [rpi3 default = 400]
#sudo echo "gpu_freq=250" >> /boot/config.txt

#nom sur la connexion hdmi-cec
sudo echo "cec_osd_name=jeedombis" >> /boot/config.txt

#interdire l'affichage de ce pi sur l'écran télé à son démarrage
sudo echo "hdmi_ignore_cec_init=1" >> /boot/config.txt
	
sudo wget https://raw.githubusercontent.com/jeedom/core/stable/install/install.sh
sudo chmod +x install.sh
sudo ./install.sh

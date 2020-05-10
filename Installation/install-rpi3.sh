#!/bin/bash
#this shell must be launched with user privilege that can do sudo command
#set -x

#cleartext password inside !
#this shell must be launched with root privilege
#set -x

. $(dirname "${0}")/colors.sh
. $(dirname "${0}")/config_rpi.sh
. $(dirname "${0}")/secrets.sh

echo "${cyan}Start configuration of this server${white}"

# Everything else needs to be run as root
if [ $(id -u) -eq 0 ]; then
  echo "${red}Script must not be run as root. Try './install-rpi'${white}"
  exit 1
fi

#
# Partir d'un raspberry avec la distribution raspbian installée et opérationnelle, de préférence sur un disque SSD plutôt qu'une carte sd pas assez fiable
# cf ce tuto : https://www.jeedom.com/forum/viewtopic.php?f=152&t=27615&hilit=rpi+ssd
# 1 Préparer\Graver votre SSD avec la derniere image Raspbian Lite : https://downloads.raspberrypi.org/raspbian_lite_latest (utiliser win32diskimager - initialisr le disque (GPT) et créer un volume sans le formater pour obtenir une lettre d'accès
# 2 Créer un fichier "ssh" sans extension sur la partition boot du SSD (la partition /boot est la seule accessible quand le SSD est branché à votre PC)
#
# 3 lancer sudo raspi-config
#
#  localisation
#    locale => unset en_GB, set fr_FR.UTF8
#       defaut local 
#
#  interfacing options => ssh
#
#                expand filesystem ensures that all of th sd card 
#    
#    smsc95xx.macaddr=b8:27:eb:f6:db:32  <= pour le rpi avec l'adresse .30 (nginx etc..) à ajouter dans /boot/cmdline
#
# Automatisation de l'installation du serveur jeedom
#

#call this function with 2 parameters : name of the file, text to add
set_line () {
	if [ `grep -c "^${2@Q}" "$1"` == 0 ]
	then 
	    echo "${2}" >> "${1}"
	fi
}

#call this function with 3 parameters : name of the file, name of the parameter and value
set_parameter () {
	if [ `grep -c "^$2=" "$1"` == 0 ]
	then 
	    sudo echo "$2=$3" >> "$1"
	else 
	    sudo sed -i "s/^$2=.*/$2=$3/g" "$1"
	fi
}


echo "${green}$(tr -d '\0' </proc/device-tree/model)${white}"

myIP=$(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|grep 192)
echo "Ip address=${green}${myIP}${white}"
case ${myIP} in
  ${jeedomSec_ip})  echo "${jeedomSec_name}" > /etc/hostname
  				CEC-OSD="${jeedomSec_name}";;
  ${kodi_ip}) echo "${kodi_name}" > /etc/hostname
  				CEC-OSD="${kodi_name}";;
  ${jeedom_ip}) echo "${jeedom_name}" > /etc/hostname
  				CEC-OSD="${jeedom_name}";;
  ${parent_ip}) echo "${parent_name}" > /etc/hostname
  				CEC-OSD="${parent_name}";;
  *) CEC-OSD="inconnu"
  	 echo "${red}RPI unknown inconfiguration file, please add it : ${myIP};;
esac

case ${CEC-OSD} in
  kodi) GPU-MEM="256";;
  *) GPU-MEM="16";;
esac

case ${CEC-OSD} in
  kodi|parent) DTPARAM=AUDIO="on";;
  *) DTPARAM=AUDIO="off";;
esac

case ${CEC-OSD} in
  parent) DTPARAM=act_led_trigger="none";;
  *) DTPARAM=act_led_trigger="heartbeat";;
esac

#disable ipv6
file="/boot/cmdline.txt"
sudo sed -i "/ipv6/!s/$/ ipv6.disable=1/" ${file}
sudo sed -i "/ipv6.disable=0/ipv6.disable=1/" ${file}



#Changer adresse mac : pourquoi ? pour garder l'adresse IP 192.168.0.9 sans doute
#Optionnel
#sudo nano /boot/cmdline.txt
#dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p7 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait smsc95xx.macaddr=b8:27:eb:ec:91:d0


#Linux raspberrypi 4.14.79-v7+ #1159 SMP Sun Nov 4 17:50:20 GMT 2018 armv7l

set_line "/boot/config.txt" "#[jeedom]"

#max memory for server (min for graphic..)
#sudo echo "gpu_mem=16" >> /boot/config.txt
set_parameter "/boot/config.txt" "gpu_mem" ${GPU-MEM}

#max de puissance sur les ports USB
#sudo echo "max_usb_current=1" >> /boot/config.txt
set_parameter "/boot/config.txt" "max_usb_current" "1"

#désactiver le wifi
#sudo echo "dtoverlay=pi-disable-wifi" >> /boot/config.txt
set_parameter "/boot/config.txt" "dtoverlay" "pi-disable-wifi"
	
#désactiver le bluetooth interne si dongle externe
#sudo echo "dtoverlay=pi-disable-bt" >> /boot/config.txt
#set_parameter "/boot/config.txt" "dtoverlay" "pi-disable-bt"

#réduire la fréquence GPU pour être compatible RPI2 [rpi3 default = 400]
#sudo echo "gpu_freq=250" >> /boot/config.txt

#nom sur la connexion hdmi-cec
#sudo echo "cec_osd_name=jeedom" >> /boot/config.txt
set_parameter "/boot/config.txt" "cec_osd_name" ${CEC-OSD}

#interdire l'affichage de ce pi sur l'écran télé à son démarrage
sudo echo "hdmi_ignore_cec_init=1" >> /boot/config.txt
set_parameter "/boot/config.txt" "hdmi_ignore_cec_init" "1"


# Enable audio (loads snd_bcm2835)
set_parameter "/boot/config.txt" "dtparam=audio" ${DTPARAM=AUDIO}


# Disable the ACT LED.
#dtparam=act_led_trigger=none
#dtparam=act_led_activelow=off

# Disable the PWR LED.
#dtparam=pwr_led_trigger=none
#dtparam=pwr_led_activelow=off


#Optimisation du swap

#echo "vm.swappiness = 10" >> /etc/sysctl.conf
set_parameter "/etc/sysctl.conf" "vm.swappiness" "10"


swapoff -a && swapon -a
set_parameter "/etc/dphys-swapfile" "CONF_SWAPSIZE" "1024"
sudo systemctl stop dphys-swapfile
sudo systemctl start dphys-swapfile

timedatectl set-timezone Europe/Paris

#
# Mise à jour du système
#

sudo apt update
sudo apt -y upgrade
sudo apt -y autoremove
#sudo apt-get install rpi-update -y
#sudo rpi-update

#
# Modification du fichier fstab - montage du SSD externe
#
#cd ~
#mkdir music
#modifier fstab pour ajouter
#/dev/sda2     /home/jeedom/music  ext4 noatime,discard,defaults 0 0
if [ `grep -c "tmpfs" /etc/fstab` == 0 ] then 
	sudo sh -c "echo \"tmpfs /tmp/jeedom tmpfs defaults,noatime,nosuid,size=128m 0 0\" >> /etc/fstab"
fi

#sudo sh -c 'echo "/dev/sda2     /home/jeedom/music  ext4 noatime,discard,defaults 0 0" >> /etc/fstab'

optimize_ssd () {
#SSD optimize
	/etc/systemd/journald.conf
	\[Journal\]
	Storage=volatile
	RuntimeMaxUse=30M
}

#reduce logging : create  /etc/rsyslog.d/jeedom.conf
cat > /etc/rsyslog.d/jeedom.conf << EOF
:msg, contains, "www-data" ~
if $programname == "sudo" and $msg contains "session closed for user root" then stop
if $programname == "sudo" and $msg contains "session opened for user root" then stop
if $programname == "CRON" and $msg contains "jeeCron.php >> /dev/null" then stop
if $programname == "CRON" and $msg contains "No MTA" then stop
if $programname == "CRON" and $msg contains "watchdog" then stop
EOF

#systemctl restart rsyslog
echo "${cyan}End basic configuration of this server${white}"

install_jeedom () {
	wget -O- https://raw.githubusercontent.com/jeedom/core/master/install/install.sh | sudo bash
}

install_fing () {
	#fing
	cd ~
	mkdir fing
	cd fing
	sudo apt-get install libpcap-dev
	#sudo apt-get install chkconfig	
	#https://www.fingbox.com/download?plat=[win|osx|lx32|lx64|arm]&ext=[rpm|deb|tgz|exe|dmg]
	#rpi 1&2 => armhf : rpi 3&4 => arm64 ou arm...
	wget https://www.fingbox.com/download?plat=arm&ext=deb
	#wget https://39qiv73eht2y1az3q51pykkf-wpengine.netdna-ssl.com/wp-content/uploads/2018/02/FingKit_CLI_Linux_Debian.zip
	mv download?plat=arm overlook-fing-3.0.deb
	sudo dpkg -i overlook-fing-3.0.deb 
}


add_user_jeedom () {
	useradd jeedom
	passwd jeedom ${jeedom_password}
	if [ $(sudo grep "jeedom" /etc/sudoers.d/* | wc -l) == 0 ] then 
		sudo sh -c "echo \"jeedom ALL=\(ALL\) NOPASSWD: ALL\" >> /etc/sudoers.d/010_jeedom-nopasswd"
	fi
}

install_ssh () {
	#installation de clés SSH : ex pour gérer à distance kodi (user jeedom, ip = 192.168.0.30)
	#rem the mysql database for kodi is remote on mars
	#création de clé ssh pour le user www-data (soit jeedom) afin de pouvoir faire des actions sur d'autres serveurs en gardant comme user www-data
	mkdir -p /var/www
	mkdir -p /home/www-data/.ssh
	chown -R www-data:www-data /home/www-data/ /var/www
	
	apt install -y expect
	cat > ./login_jeedom.expect << EOF
	#!/usr/bin/expect -f
	#send jeedom password
	spawn ssh-copy-id -i /home/www-data/.ssh/id_rsa ${argv}
	expect "password:"
	send "${jeedom_password}\n"
	expect eof
	EOF
	chmod a+x ./login_jeedom.expect
	sed -i "s/clearpassword/${1}/g" /home/pi/login_jeedom.expect
		
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/' /etc/passwd
	su - www-data
	
	#se mettre en tant que compte www-data  sudo su;su www-data ou sudo su - www-data
	#s'assurer que la clé privé a comme nom id_rsa et non sshkey
	
	ssh-keygen -b 2048 -t rsa -f /home/www-data/.ssh/id_rsa -C www-data -q -N ""
	
	#ssh-copy-id -i /home/www-data/.ssh/id_rsa.pub jeedom@192.168.0.30
	
	
	/home/pi/login_jeedom.expect 192.168.0.65
	/home/pi/login_jeedom.expect jeedom@192.168.0.30
	#ssh -i /home/www-data/.ssh/id_rsa jeedom@192.168.0.30
	#sudo su
	#cp /home/pi/.ssh/sshkey* /home/pi/.ssh/known_hosts /var/www/.ssh/
	#chown www-data.www-data /var/www/.ssh/*
	#exit
	exit
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/' /etc/passwd
}

install_ebus () {
	cd
	sudo apt -y install git autoconf automake g++ make libmosquitto-dev
	git clone https://github.com/john30/ebusd.git
	cd ebusd
	./autogen.sh
	make
	./src/ebusd/ebusd --help
	sudo make install
	git clone https://github.com/john30/ebusd-configuration.git
	if [ -d /etc/ebusd ]; then sudo mv /etc/ebusd /etc/ebusd.old; fi
	sudo ln -s ${PWD}/ebusd-configuration/ebusd-2.1.x/de /etc/ebusd
	sudo apt-get -y install mosquitto
	sudo cp contrib/debian/default/ebusd /etc/default/
	sudo cp contrib/debian/systemd/ebusd.service /etc/systemd/system/
	sudo systemctl enable ebusd
	sudo service ebusd start
	
}

install_audioBT () {
	#Bluetooth section
	#remove sap error
	sudo sed -i 's|^ExecStart=/usr/lib/bluetooth/bluetoothd$|ExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=sap|' /lib/systemd/system/bluetooth.service
		
	#pour transformer le rpi en récepteur audio bluetooth
	#https://gist.github.com/mill1000/74c7473ee3b4a5b13f6325e9994ff84c
	# s'assurer que le user hermes est bien dans le groupe bluetooth
	sudo vi /lib/systemd/system/bluealsa.service
	#ajouter ces 2 paramètres bluealsa -p a2dp-source -p a2dp-sink
	#puis
	sudo systemctl daemon-reload
	sudo systemctl stop bluealsa
	sudo systemctl start bluealsa
	bluetootctl
	#puis
	remove 24:0A:64:C3:B3:8E
	power on
	agent on
	default-agent
	scan on
	#attendre la découverte de l'équipement
	scan off
	trust 24:0A:64:C3:B3:8E
	pair 24:0A:64:C3:B3:8E
	\[agent\] Confirm passkey 369073 \(yes/no\): yes et du côté de l'équipement valider aussi ce code		
	mettre l'ampli en mode input auto et non coax, pour tester la carte son usb	
	aplay -D hw:CARD=Device piano2.wav
}
 
install_sshpass () {
	#sshpass pour script manageopenelec
	sudo apt-get install sshpass
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/' /etc/passwd
	sudo su - www-data
	ssh root@192.168.0.23
	exit
	exit
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/' /etc/passwd
	#nécessite de faire une connexion en ssh avec le serveur concerné sous l'identité www-data
}

install_cec () {
	#cec-client	
	sudo apt-get install libraspberrypi-dev 
	sudo apt-get install cmake liblockdev1-dev libudev-dev libxrandr-dev python-dev swig
	cd
	git clone https://github.com/Pulse-Eight/platform.git
	mkdir platform/build
	cd platform/build
	cmake ..
	make
	sudo make install
	cd
	git clone https://github.com/Pulse-Eight/libcec.git
	mkdir libcec/build
	cd libcec/build
	cmake -DRPI_INCLUDE_DIR=/opt/vc/include -DRPI_LIB_DIR=/opt/vc/lib ..
	make -j4
	sudo make install
	sudo ldconfig
		
	cd ~
	mkdir cecHdmi
	cd cecHdmi
	wget http://localhost/plugins/script/core/ressources/scriptHDMI.tgz
	tar -xvzf scriptHDMI.tgz
	rm scriptHDMI.tgz
	chmod a+x *
	chown root.root monitorHDMI
	mv monitorHDMI /etc/init.d/
	update-rc.d monitorHDMI defaults   	
}		

install_kodi () {
	sudo apt -y install kodi
	mkdir -p ~/videos/mars
	dir=/home/${USER}
	sudo ln -s ${dir} /storage
	#ne pas utiliser fstab mais autofs
	#if [ `grep -c "multimedia2" /etc/fstab` == 0 ]
	#then 
	#	sudo sh -c "echo \"192.168.0.15:/media/multimedia2/videos /storage/videos/mars nfs user,auto 0 0\" >> /etc/fstab"
	#fi
	sudo apt-get -y install autofs
	if [ -f /etc/auto.master ]; then
		if [ `grep -c "hermes" /etc/auto.master` == 0 ]; then
			sudo sh -c "echo \"/home/hermes /etc/auto.nfs --ghost,--timeout=60\" >> /etc/auto.master"
		fi
	else
		sudo sh -c "echo \"/home/hermes/video /etc/auto.nfs --ghost,--timeout=60\" >> /etc/auto.master"
	fi
	#sudo sh -c "echo \"mars      -rsize=8192,wsize=8292,timeo=14,intr,rw,uid=1000,gid=1000    192.168.0.15:/media/multimedia2/videos\"  >> /etc/auto.nfs"
	sudo sh -c "echo \"mars -fstype=nfs,rw   192.168.0.15:/media/multimedia2/videos\"  >> /etc/auto.nfs"
	sudo systemctl restart autofs
}

migrate_pi2hermes () {
# nécessite qu'on soit connecté sous le user root
# Find the file /etc/ssh/sshd_config
# Comment the line #PermitRootLogin without-password
# Add the line PermitRootLogin yes
# Save, exit, restart ssh with systemctl restart ssh
# create passwd for root sudo passwd root
# at the end remove password of root : sudo passwd -l root
# modify pi by hermes in sudoers
	usermod --login hermes --move-home --home /home/hermes pi
	groupmod --new-name hermes pi
}

install_mysensor () {
#
# Installation de la Gateway logicielle mysensors
#
#sudo modprobe spi_bcm2835
#sudo raspi-config
#activer spi
	cd ~
	mkdir mysensors
	cd mysensors
	wget https://github.com/TMRh20/RF24/archive/master.zip
	unzip master.zip
	rm -f master.zip
	cd RF24-master
	make all
	sudo make install
	
	cd ~/mysensors
	wget https://github.com/mysensors/Raspberry/archive/master.zip
	unzip master.zip
	rm -f master.zip
	cd Raspberry-master
	make all
	sudo make install
	sudo make enable-gwserial
	sudo adduser www-data tty
	#créer le lien symbolique /dev/ttyACM0 	!! ou patcher le nom du lien symbolique dans le code source avant compilation...
	# [ -h /dev/ttyMySensorsGateway ] && [ ! -h /dev/ttyACM0 ] && ln -s /dev/pts/0 /dev/ttyACM0
	#...PiGatewaySerial.cpp:    #define _TTY_NAME "/dev/ttyMySensorsGateway"
}


#
# Installation de samba
#

#sudo apt-get -o APT::Install-Recommends=false -o APT::Install-Suggests=false install samba

#sudo systemctl stop smbd
#sudo systemctl stop nmbd

#copy smb.conf dans /etc/samba/
#sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.ori
#sudo vi /etc/samba/smb.conf

#sudo systemctl start nmbd
#sudo systemctl start smbd
			

#
# Installation de logitechmediaserver
#


#http://downloads.slimdevices.com/nightly/7.9/sc/7b09e1c/logitechmediaserver_7.9.0~1454098279_arm.deb
#wget http://www.mysqueezebox.com/update/?version=7.9.0&revision=1&geturl=1&os=deb
#cachedir="/var/cache/logitechmediaserver"
#[ ! -d ${cachedir} ] && sudo mkdir -p ${cachedir}
#installed_lms=$(dpkg-query -W -f '${status} ${package} ${version}\n'|grep logitech |cut -d " " -f 5)
#latest_lms=$(wget -q -O - "http://www.mysqueezebox.com/update/?version=7.9.0&revision=1&geturl=1&os=deb")
#lms_deb=$(echo ${latest_lms}|cut -d "/" -f8)
#sudo wget -c -P ${cachedir} ${latest_lms}
#sudo dpkg -i "${cachedir}/${lms_deb}"	

#restaurer les préférences
#sudo systemctl stop logitechmediaserver
#sudo mv /var/lib/squeezeboxserver/prefs /var/lib/squeezeboxserver/prefs.ori
#restaurer la sauvegarde de prefs
#sauvegarde dropbox plus pertinente
# quid du projet https://github.com/andreafabrizi/Dropbox-Uploader pour supprimer les vieilles sauvegardes sur dropbox ?
#sudo mount -a
#sudo cp /home/jeedom/music/_thierry/prefs.tgz .
#sudo tar -xvgz prefs.tgz
#sudo chown -R squeezeboxserver.nogroup prefs
#sudo rm prefs.tgz
#modifier le fichier /etc/init.d/logitechmediaserver pour remplacer le premier $all par $syslog par exemple
#et enlever les autres $all
#sed -i.bak 's/^# Required-Start:.*/# Required-Start:       $syslog/' /etc/init.d/logitechmediaserver
#sed -i.bak 's/^# Required-Stop:.*/# Required-Stop:/' /etc/init.d/logitechmediaserver
#sed -i.bak 's/^# Should-Start:.*/# Should-Start:/' /etc/init.d/logitechmediaserver
#sed -i.bak 's/^# Should-Stop:.*/# Should-Stop:/' /etc/init.d/logitechmediaserver
#sudo systemctl start logitechmediaserver


#
# Installation de rpi-clone
#

#cd ~
#git clone https://github.com/billw2/rpi-clone.git
#cd rpi-clone
#sudo cp rpi-clone /usr/local/sbin
	
#sudo systemctl stop logitechmediaserver	
#sudo systemctl stop nginx
#sudo systemctl stop jeedom
#sudo systemctl stop php5-fpm
#sudo systemctl stop mysql
#sudo systemctl stop cron
#sudo systemctl stop smbd
#sudo systemctl stop nmbd
	
#sudo umount /dev/sda2
#sudo apt-get install dosfstools	
#sudo rpi-clone sdb -f
	
#sudo mount -a
#sudo systemctl start logitechmediaserver	
#sudo systemctl start nmbd
#sudo systemctl start smbd
#sudo systemctl start mysql
#sudo systemctl start jeedom
#sudo systemctl start php5-fpm
#sudo systemctl start cron
#sudo systemctl start nginx
	

echo "${cyan}End configuration of this server${white}"
#!/bin/bash
############################################################################
#
# Usage: install-rpi.sh [options] file ...
#
# Count the number of lines in a given list of files.
# Uses a for loop over all arguments.
# modules are composed of routines
# eg. modules
#
# Options:
#  -h        ... help message
#  -v        ... verbose
#  -l        ... list : list modules
#  -r        ... list : list routines
#  -a        ... configure all the modules for this host
#  -m module ... configure only this module
#
# Limitations:
#  . only one option should be given; a second one overrides
#  . must be launched with user privilege that can do sudo command
#
############################################################################


############################################################################
#
# role : set of modules
# module : set of routines
# routine : elementary task
#
############################################################################

#set -x
. $(dirname "${0}")/colors.sh

verbose=0
# defaults
modules=""
printRoutines=0
printModules=0

print_help () {
	no_of_lines=`cat $0 | awk 'BEGIN { n = 0; } \
				/^$/ { print n; \
				exit; } \
				{ n++; }'`
	echo "`head -$no_of_lines $0`"
}

while getopts "hvlram:w:" option ; do
	case ${option} in
		h)	print_help
			exit 0
			;;
		v)	verbose=1
			;;
		l)	printModules=1
			;;
		r)	printRoutines=1
			;;
		a)
			;;
		m)	modules=${OPTARG}
			;;
		\?)	echo "${red}Invalid option ${yellow}-${option}${white}"
			print_help
			exit 1
			;;
	esac
done

shift "$((OPTIND-1))"

if [ $# -lt 1 ]; then
	echo "Usage: $0 file ..."
	exit 1
fi

if [ ${verbose} -eq 1 ]; then
	echo "$0 verbose activated"
fi

# Everything else needs to be run as root
if [ $(id -u) -eq 0 ]; then
	echo "${red}Script must not be run as root. Try './install-rpi'${white}"
	exit 2
fi

echo "${cyan}Start configuration of this server${white}"
. $(dirname "${0}")/config_rpi.sh
. $(dirname "${0}")/secrets.sh

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
#
# Automatisation de l'installation du serveur jeedom
#

#call this function with 2 parameters : name of the file, text to add
set_line () {
	if [ $(grep -c "^${2@Q}" "$1") == 0 ]
	then
		sudo sh -c "echo ${2} >> ${1}"
	fi
}

#call this function with 3 parameters : name of the file, name of the parameter and value
set_parameter () {
	if [ $(grep -c "^$2=" "$1") == 0 ]
	then
		sudo sh -c "echo $2=$3 >> $1"
	else
		sudo sed -i "s/^$2=.*/$2=$3/g" "$1"
	fi
}

identify_system () {
	echo "${cyan}Start identify this server${white}"
	prefix=($(echo ${lan_network} | tr "." " "))
	prefix=${prefix[0]}.${prefix[1]}
	myIP=$(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|grep ${prefix})
	echo "Ip address=${green}${myIP}${white}"
	CEC_OSD="inconnu"
	role="inconnu"
	case ${myIP} in
	  ${jeedomSec_ip})
		sudo sh -c "echo ${jeedomSec_name} > /etc/hostname";
		CEC_OSD=${jeedomSec_name}
		role=${jeedomSec_role};;
	  ${kodi_ip})
		sudo sh -c "echo ${kodi_name} > /etc/hostname";
		CEC_OSD=${kodi_name}
		role=${kodi_role};;
	  ${jeedom_ip})
		sudo sh -c "echo ${jeedom_name} > /etc/hostname";
		CEC_OSD=${jeedom_name}
		role=${jeedom_role};;
	  ${parent_ip})
		sudo sh -c "echo ${parent_name} > /etc/hostname";
		CEC_OSD=${parent_name}
		role=${parent_role};;
	  *)
		CEC_OSD="inconnu"
		echo "${red}RPI unknown in configuration file, please add it : ${myIP}${white}";;
	esac
	echo "Name=${green}$(cat /etc/hostname)${white}"
	echo "Role=${green}${role}${white}"
	echo "${cyan}End identify this server${white}"
}

install_test () {
	echo "${cyan}Start installation test${white}"
	echo "${green}test module does nothing...${white}"
	echo "${cyan}End installation test${white}"
}

configure_localization () {
	echo "${cyan}Start localization this server${white}"
	echo "${green}$(tr -d '\0' </proc/device-tree/model)${white}"
	L='fr' && sudo sed -i 's/XKBLAYOUT=\"\w*"/XKBLAYOUT=\"'$L'\"/g' /etc/default/keyboard
	#modify keyboard

	timedatectl set-timezone Europe/Paris
	echo "${cyan}End localization this server${white}"
}


configure_system () {
	echo "${cyan}Start system configuration${white}"

	case ${CEC_OSD} in
	  kodi) GPU_MEM="256";;
	  *) GPU_MEM="16";;
	esac

	case ${CEC_OSD} in
	  kodi|parent) DTPARAM=AUDIO="on";;
	  *) DTPARAM=AUDIO="off";;
	esac

	case ${CEC_OSD} in
	  parent) DTPARAM=act_led_trigger="none";;
	  *) DTPARAM=act_led_trigger="heartbeat";;
	esac

	#disable ipv6
	file="/boot/cmdline.txt"
	sudo sed -i "/ipv6/!s/$/ ipv6.disable=1/" ${file}
	sudo sed -i "s/ipv6.disable=0/ipv6.disable=1/" ${file}

	if [ $(grep -c "noipv6rs" /etc/dhcpcd.conf) == 0 ]; then
		sudo sh -c 'echo "# disable ipv6 in /etc/dhcpcd.conf " >> /etc/dhcpcd.conf'
		sudo sh -c 'echo " " >> /etc/dhcpcd.conf'
		sudo sh -c 'echo "noipv6rs" >> /etc/dhcpcd.conf'
		sudo sh -c 'echo "noipv6" >> /etc/dhcpcd.conf'
	fi
	
	file="/etc/avahi/avahi-daemon.conf"
	if [ $(grep -c "use-ipv6" ${file} ) == 0 ]; then
		sudo sed -i '/^\[server\]/a\\nuse-ipv6=no' ${file}
	else
		sudo sed -i "s/use-ipv6=yes/use-ipv6=no/" ${file}
	fi

	set_line "/boot/config.txt" "#[jeedom]"

	#max memory for server (min for graphic..)
	set_parameter "/boot/config.txt" "gpu_mem" ${GPU_MEM}

	#max de puissance sur les ports USB
	set_parameter "/boot/config.txt" "max_usb_current" "1"

	#désactiver le wifi
	set_parameter "/boot/config.txt" "dtoverlay" "pi-disable-wifi"

	sudo systemctl stop wpa_supplicant
	sudo systemctl disable wpa_supplicant

	#désactiver le bluetooth interne si dongle externe
	set_parameter "/boot/config.txt" "dtoverlay" "pi-disable-bt"

	#réduire la fréquence GPU pour être compatible RPI2 [rpi3 default = 400]
	#sudo echo "gpu_freq=250" >> /boot/config.txt

	#nom sur la connexion hdmi-cec
	set_parameter "/boot/config.txt" "cec_osd_name" ${CEC_OSD}

	#interdire l'affichage de ce pi sur l'écran télé à son démarrage
	set_parameter "/boot/config.txt" "hdmi_ignore_cec_init" "1"

	# Enable audio (loads snd_bcm2835)
	set_parameter "/boot/config.txt" "dtparam=audio" ${DTPARAM=AUDIO}


	# Disable the ACT LED.
	#dtparam=act_led_trigger=none
	#dtparam=act_led_activelow=off

	# Disable the PWR LED.
	#dtparam=pwr_led_trigger=none
	#dtparam=pwr_led_activelow=off


	#remove sap error
	sudo sed -i 's|^ExecStart=/usr/lib/bluetooth/bluetoothd$|ExecStart=/usr/lib/bluetooth/bluetoothd --noplugin=sap|' /lib/systemd/system/bluetooth.service
	echo "${cyan}End system configuration${white}"
}

#
# Mise à jour du système
#
upgrade_system () {
	echo "${cyan}Start upgrade this server${white}"
	sudo apt update
	sudo apt -y upgrade
	sudo apt -y autoremove
	#sudo apt-get install rpi-update -y
	#sudo rpi-update
	echo "${cyan}End upgrade this server${white}"
}

optimize_drive () {
	echo "${cyan}Start optimization for ssd or sdcard${white}"
	#Optimisation du swap

	#echo "vm.swappiness = 10" >> /etc/sysctl.conf
	set_parameter "/etc/sysctl.conf" "vm.swappiness" "10"

	sudo swapoff -a && swapon -a
	set_parameter "/etc/dphys-swapfile" "CONF_SWAPSIZE" "1024"
	sudo systemctl stop dphys-swapfile
	sudo systemctl start dphys-swapfile
	#
	# Modification du fichier fstab - montage du SSD externe
	#
	#modifier fstab pour ajouter
	if [ $(grep -c "jeedom tmpfs" /etc/fstab) == 0 ]; then
		sudo sh -c 'echo "tmpfs /tmp/jeedom tmpfs defaults,noatime,nosuid,size=128m 0 0" >> /etc/fstab'
	fi

	#sdcard and SSD optimize
	#journald
	if [ $(grep -c 'Storage=volatile' /etc/systemd/journald.conf) == 0 ]; then
		sudo sed -i '/^\[Journal\]/a\Storage=volatile\nRuntimeMaxUse=30M\n' /etc/systemd/journald.conf
	fi

	#reduce logging : create  /etc/rsyslog.d/jeedom.conf
	sudo sh -c 'cat > /etc/rsyslog.d/jeedom.conf <<-EOF
	:msg, contains, "www-data" stop
	if \$programname == "sudo" and \$msg contains "session closed for user root" then stop
	if \$programname == "sudo" and \$msg contains "session opened for user root" then stop
	if \$programname == "CRON" and \$msg contains "jeeCron.php >> /dev/null" then stop
	if \$programname == "CRON" and \$msg contains "No MTA" then stop
	if \$programname == "CRON" and \$msg contains "watchdog" then stop
	EOF'
	#systemctl restart rsyslog
	echo "${cyan}End optimization for ssd or sdcard${white}"
}

echo "${cyan}End basic and common configuration of this server${white}"

install_jeedom () {
	echo "${cyan}Start installation jeedom${white}"
	wget -O- https://raw.githubusercontent.com/jeedom/core/master/install/install.sh | sudo bash
	echo "${cyan}End installation jeedom${white}"
}

install_fing () {
	echo "${cyan}Start installation fing${white}"
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
	echo "${cyan}End installation fing${white}"
}

add_user_jeedom () {
	useradd jeedom
	passwd jeedom ${jeedom_password}
	if [ $(sudo grep "jeedom" /etc/sudoers.d/* | wc -l) == 0 ]; then
		sudo sh -c 'echo "jeedom ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_jeedom-nopasswd'
	fi
	sudo chown -R "jeedom"."jeedom" /home/jeedom
}

install_ssh () {
	#installation de clés SSH
	#création de clé ssh pour le user www-data (soit jeedom) afin de pouvoir faire des actions sur d'autres serveurs en gardant comme user www-data
	mkdir -p /var/www
	mkdir -p /home/www-data/.ssh
	chown -R www-data:www-data /home/www-data/ /var/www

	apt install -y expect
	cat > ./login_jeedom.expect <<-EOF
	#!/usr/bin/expect -f
	#send jeedom password
	spawn ssh-copy-id -i /home/www-data/.ssh/id_rsa ${argv}
	expect "password:"
	send "${jeedom_password}\n"
	expect eof
	EOF
	chmod a+x ./login_jeedom.expect

	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/' /etc/passwd
	su - www-data

	#se mettre en tant que compte www-data  sudo su;su www-data ou sudo su - www-data
	#s'assurer que la clé privée a comme nom id_rsa et non sshkey

	ssh-keygen -b 2048 -t rsa -f /home/www-data/.ssh/id_rsa -C www-data -q -N ""

	#ssh-copy-id -i /home/www-data/.ssh/id_rsa.pub jeedom@${kodi_ip}


	/home/${default_user}/login_jeedom.expect ${parent_ip}
	/home/${default_user}/login_jeedom.expect jeedom@${kodi_ip}
	#ssh -i /home/www-data/.ssh/id_rsa jeedom@${kodi_ip}
	#sudo su
	#cp /home/${default_user}/.ssh/sshkey* /home/${default_user}/.ssh/known_hosts /var/www/.ssh/
	#chown www-data.www-data /var/www/.ssh/*
	#exit
	exit
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/' /etc/passwd
}

install_ebus () {
	echo "${cyan}Start installation ebus${white}"
	echo "${cyan}Build ebusd server${white}"
	ebus_ip=192.168.31.50
	read -p "Enter ip address of the remote ebus [${ebus_ip}]" ebus_ip
	ebus_ip=${ebus_ip:-192.168.0.50}
	echo "${cyan}ebus ip =${ebus_ip} ${white}"
	cd ~
	sudo apt -y install git autoconf automake g++ make libmosquitto-dev
	git clone https://github.com/john30/ebusd.git
	cd ebusd
	./autogen.sh
	make
	./src/ebusd/ebusd --help
	sudo make install
	git clone https://github.com/john30/ebusd-configuration.git

	if [ -d /etc/ebusd ]; then sudo mv /etc/ebusd /etc/ebusd.old; fi
	sudo ln -s ${PWD}/ebusd-configuration/ebusd-2.1.x/en /etc/ebusd

	if [ $(/usr/bin/ebusd  -c /etc/ebusd  --checkconfig | wc -l) != 3 ]; then
		echo "${red}Error with standard ebusd configuration server${white}"
		/usr/bin/ebusd  -c /etc/ebusd  --checkconfig
		echo "${red}Exit installation ebus${white}"
		return 20
	fi

	git clone https://github.com/minscof/ebusd-configuration.git my-ebusd-configuration

	if [ $(grep -c "ecomode" /etc/ebusd/vaillant/_templates.csv) == 0 ]; then
		echo "Modify ${yellow}_templates.csv${white}"
		sudo sh -c 'echo "ecomode,UCH,0=eco;1=comfort0" >> /etc/ebusd/vaillant/_templates.csv'
	fi

	if [ $(grep -c "0010015384" /etc/ebusd/vaillant/08.bai.csv) == 0 ]; then
		echo "Modify ${yellow}08.bai.csv${white}"
		sudo sed -i "/.*fallbacks.*/i\\[PROD='0010015384'\]\!load,bai\.0010015384\.inc,,," /etc/ebusd/vaillant/08.bai.csv
		#cp my-ebusd-configuration/ebusd-2.1.x/en/vaillant/08.bai.csv ebusd-configuration/ebusd-2.1.x/en/vaillant/08.bai.csv
	fi

	if [ ! -f /etc/ebusd/vaillant/15.e7c.csv ]; then
		echo "Add ${yellow}15.e7c.csv${white}"
		sudo cp my-ebusd-configuration/ebusd-2.1.x/en/vaillant/15.e7c.csv /etc/ebusd/vaillant/15.e7c.csv
	fi

	if [ ! -f /etc/ebusd/vaillant/bai.0010015384.inc ]; then
		echo "Add ${yellow}bai.0010015384.inc${white}"
		sudo cp my-ebusd-configuration/ebusd-2.1.x/en/vaillant/bai.0010015384.inc /etc/ebusd/vaillant/bai.0010015384.inc
	fi

	if [ $(/usr/bin/ebusd  -c /etc/ebusd  --checkconfig | wc -l) != 3 ]; then
		echo "${red}Error with personalized ebusd configuration server${white}"
		/usr/bin/ebusd  -c /etc/ebusd  --checkconfig
		echo "${red}Exit installation ebus${white}"
		return 21
	fi


	sudo sed -i "s#^EBUSD_OPTS.*#EBUSD_OPTS=\x27-d ${ebus_ip}:9999 -l /dev/null -c /etc/ebusd --scanconfig --latency=20000 --mqttport=1883 --mqttjson --accesslevel=\"*\" \x27#" /etc/default/ebusd

	sudo apt-get -y install mosquitto mosquitto-clients
	echo "${cyan}Start mosquitto server${white}"
	sudo systemctl restart mosquitto
	sudo cp contrib/debian/default/ebusd /etc/default/
	sudo cp contrib/debian/systemd/ebusd.service /etc/systemd/system/
	sudo systemctl enable ebusd
	echo "${cyan}Start ebusd server${white}"
	sudo systemctl restart ebusd
	echo "${cyan}End installation ebus${white}"
}

install_audioBT () {
	echo "${cyan}Start configuration bluetooth audio${white}"
	#Bluetooth section

	#pour transformer le rpi en récepteur audio bluetooth
	#https://gist.github.com/mill1000/74c7473ee3b4a5b13f6325e9994ff84c
	# s'assurer que le user est bien dans le groupe bluetooth
	sudo vi /lib/systemd/system/bluealsa.service
	#ajouter ces 2 paramètres bluealsa -p a2dp-source -p a2dp-sink
	#puis
	sudo systemctl daemon-reload
	sudo systemctl stop bluealsa
	sudo systemctl start bluealsa
	bluetootctl
	#puis
	remove yy:yy:yy:yy:yy:yy
	power on
	agent on
	default-agent
	scan on
	#attendre la découverte de l'équipement
	scan off
	trust yy:yy:yy:yy:yy:yy
	pair yy:yy:yy:yy:yy:yy
	\[agent\] Confirm passkey xxxxxx \(yes/no\): yes et du côté de l'équipement valider aussi ce code
	#mettre l'ampli en mode input auto et non coax, pour tester la carte son usb
	aplay -D hw:CARD=Device piano2.wav
	echo "${cyan}End configuration bluetooth audio${white}"
}

install_sshpass () {
	#sshpass pour script manageopenelec
	sudo apt-get install sshpass
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/' /etc/passwd
	sudo su - www-data
	ssh root@ip
	exit
	exit
	sudo sed -i.bak 's/^www-data:x:33:33:www-data:\/var\/www:\/bin\/bash/www-data:x:33:33:www-data:\/var\/www:\/usr\/sbin\/nologin/' /etc/passwd
	#nécessite de faire une connexion en ssh avec le serveur concerné sous l'identité www-data
}

install_cec () {
	echo "${cyan}Start installation hdmiCec${white}"
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
	echo "${cyan}End installation hdmiCec${white}" 
}

install_kodi () {
	echo "${cyan}Start installation kodi${white}"
	sudo apt -y install kodi
	mkdir -p ~/videos/${nas_name}
	dir=/home/${USER}
	sudo ln -s ${dir} /storage
	sudo apt-get -y install autofs
	if [ -f /etc/auto.master ]; then
		if [ $(grep -c ${USER} /etc/auto.master) == 0 ]; then
			sudo sh -c "echo \"/home/${USER}/videos /etc/auto.nfs --ghost,--timeout=60\" >> /etc/auto.master"
		fi
	else
		sudo sh -c "echo \"/home/${USER}/videos /etc/auto.nfs --ghost,--timeout=60\" >> /etc/auto.master"
	fi
	#sudo sh -c "echo \"${nas_name}      -rsize=8192,wsize=8292,timeo=14,intr,rw,uid=1000,gid=1000    ${nas_ip}:${nas_volume}\"  >> /etc/auto.nfs"
	sudo sh -c "echo \"${nas_name} -fstype=nfs,rw   ${nas_ip}:${nas_volume}\"  >> /etc/auto.nfs"
	sudo systemctl restart autofs
	echo "${cyan}End installation kodi${white}"
}

migrate_defaultUser2secureUser () {
# nécessite qu'on soit connecté sous le user root
# Find the file /etc/ssh/sshd_config
# Comment the line #PermitRootLogin without-password
# Add the line PermitRootLogin yes
# Save, exit, restart ssh with systemctl restart ssh
# create passwd for root sudo passwd root
# at the end remove password of root : sudo passwd -l root
# modify ${default_user} by secure_user in sudoers
	usermod --login ${secure_user} --move-home --home /home/${secure_user} ${default_user}
	groupmod --new-name ${secure_user} ${default_user}
	${default_user}=${secure_user}
	sudo usermod -a -G bluetooth ${default_user}
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

security_iptables () {
	echo "${cyan}Create iptables rules${white}"
	#add file for iptables
	sudo sh -c "cat > /etc/iptables.firewall.rules <<-EOF
	*filter

	#  Allow all loopback (lo0) traffic and drop all traffic to 127/8 that doesn t use lo0
	-A INPUT -i lo -j ACCEPT -m comment --comment \"allow loopback traffic lo\"
	-A INPUT -d 127.0.0.0/8 -j REJECT -m comment --comment \"drop all traffic to 127/8 that doesn t use lo\"

	#  Accept all established inbound connections
	-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT -m comment --comment \"established inbound connections\"

	#  Allow all outbound traffic - you can modify this to only allow certain traffic
	-A OUTPUT -j ACCEPT -m comment --comment \"all outbound traffic\"

	#  Allow HTTP and HTTPS connections from anywhere (the normal ports for websites and SSL).
	-A INPUT -p tcp --dport 80 -j ACCEPT -m comment --comment \"web server\"
	-A INPUT -p tcp --dport 443 -j ACCEPT  -m comment --comment \"web server TLS\"

	# Allow  HTTP on port 8080 only from jeedom for kodi & kodiasgui plugin
	-A INPUT -s ${lan_network}/24 -p tcp --dport 8080 -j ACCEPT -m comment --comment \"kodi\"

	# Allow  HTTP on port 8003 only from find (wifi geolocation)
	-A INPUT -s ${lan_network}/24 -p tcp --dport 8003 -j ACCEPT  -m comment --comment \"wigi geolocation find 8003\"

	# Allow  MQTT on port 1883 only from jeedom for ebusd
	-A INPUT -s ${lan_network}/24 -p tcp --dport 1883 -j ACCEPT -m comment --comment \"MQTT 1883\"

	#  Allow SSH connections
	#  The -dport number should be the same port number you set in sshd_config
	#-A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT
	-A INPUT -s ${lan_network}/24 -p tcp -m state --state NEW --dport 22 -j ACCEPT -m comment --comment \"ssh\"

	# Allow  blea antenna
	-A INPUT -s ${lan_network}/24 -p tcp -m tcp --dport 55008 -m comment --comment \"BLEA remote\" -j ACCEPT

	#usbip redirection
	-A INPUT -s ${lan_network}/24 -p tcp -m tcp --dport 3240 -m comment --comment \"USB redirection\" -j ACCEPT
	
	# Allow  pulseaudio on port 4713 only for LAN
	-A INPUT -s ${lan_network}/24 -p tcp -m tcp --dport 4713 -m comment --comment \"pulseaudio\" -j ACCEPT

	# Allow  mDNS on port 5353
	-A INPUT -p udp -m udp --sport 5353 -j ACCEPT -m comment --comment \"mDNS 5353\"
	-A OUTPUT -p udp -m udp --dport 5353 -j ACCEPT -m comment --comment \"mDNS 5353\"

	# Allow DHCP
	-A INPUT -p udp --sport 68 --dport 67 -j ACCEPT -m comment --comment \"dhcp 68 & 67\"

	# Allow  squeezeboz server on port 3483
	-A INPUT -p udp -m udp --dport 3483 -j ACCEPT -m comment --comment \"squeezebox server\"
	-A INPUT -p tcp -m tcp --dport 3483 -j ACCEPT -m comment --comment \"squeezebox server\"
	-A INPUT -s ${lan_network}/24 -p udp -m udp --dport 17784 -j ACCEPT -m comment --comment \"squeezebox server\"

	# Allow  vpn wireguard server on port 51820
	-A INPUT -p udp -m udp --dport 51820 -j ACCEPT -m comment --comment \"vpn wireguard\"

	# drop dropbox sync and add comment to remove log
	-A INPUT -p udp --dport 17500 -j DROP -m comment --comment \"dropbox lan\"

	#  Allow ping
	-A INPUT -p icmp --icmp-type echo-request -j ACCEPT -m comment --comment \"icmp ping\"

	# Allow IGMP (multidiffusion)
	-A INPUT -p igmp -j ACCEPT -m comment --comment \"igmp multidiffusion\"
	
	# Allow spotify peer to peer
	#-A TCP -p tcp --dport 57621 -j ACCEPT -m comment --comment spotify
	-A INPUT -p udp --dport 57621 -j ACCEPT -m comment --comment spotify
	
	# Allow USB redirector
	-A INPUT -p tcp -m tcp --dport 32032 -j ACCEPT -m comment --comment \"USB redirector\"
	
	
	# Discard without logging
	# netbios broadcast
	-A INPUT -s ${lan_network}/24 -p udp -m udp --sport=137 --dport=137 -m comment --comment netbios -j DROP
    -A INPUT -s ${lan_network}/24 -p udp -m udp --sport=138 --dport=138 -m comment --comment netbios -j DROP

	#  Log iptables denied calls
	-A INPUT -m limit --limit 5/min -j LOG --log-prefix \"iptables denied: \" --log-level 7

	#  Drop all other inbound - default deny unless explicitly allowed policy
	#  broadcast port 57621 : spotify connect peer to peer network : https://mrlithium.blogspot.com/2011/10/spotify-and-opting-out-of-spotify-peer.html
	-A INPUT -j DROP
	-A FORWARD -j DROP

	COMMIT
	EOF"

	#add file for logging iptables
	sudo sh -c 'cat > /etc/rsyslog.d/iptables.conf <<-EOF
	:msg, contains, "iptables" -/var/log/iptables.log
	&stop
	EOF'

	echo "${cyan}Activate iptables rules${white}"
	sudo /sbin/iptables-restore < /etc/iptables.firewall.rules
	sudo apt -y install iptables-persistent
	sudo iptables-save >/etc/iptables/rules.v4
	sudo sh -c "echo \"#!/bin/sh\" > /etc/network/if-pre-up.d/firewall"
	sudo sh -c "echo \"/sbin/iptables-restore < /etc/iptables/rules.v4" >> /etc/network/if-pre-up.d/firewall"
	echo "${cyan}End configuration iptables${white}"
}

security_fail2ban () {
	echo "${cyan}Start installation fail2ban${white}"
	sudo apt-get -y install fail2ban
	sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

	#sshd
	if [ $(grep -c 'filter = sshd' /etc/fail2ban/jail.local) == 0 ]; then
		sudo sed -i '/^\[sshd\]/a\enabled = true\nfilter = sshd\nbanaction = iptables-multiport\nbantime = -1\nmaxretry = 3\n' /etc/fail2ban/jail.local
	fi

	#nginx
	if [ $(grep -c 'filter = nginx-badbots' /etc/fail2ban/jail.local) == 0 ]; then
		sudo sh -c 'echo /\[ssh\]/a\enabled = true >> /etc/fail2ban/jail.local'
	fi

	sudo sh -c 'cat > /etc/fail2ban/jail.local <<-EOF

	[nginx-badbots]

	enabled  = true
	port     = http,https
	filter   = nginx-badbots
	logpath  = /var/log/nginx/jeedom.access.log
	maxretry = 2
	EOF'

	sudo cp /etc/fail2ban/filter.d/apache-badbots.conf /etc/fail2ban/filter.d/nginx-badbots.conf

	sudo systemctl restart fail2ban

	echo "${cyan}End installation fail2ban${white}"
}

security_nginx () {

	cat > /home/${secure_user}/getblacklist.sh <<-EOF
	#!/bin/sh
	saveTo=/etc/nginx/deny
	now=$(date);

	#echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/dshield-deny.conf
	#wget -O - http://feeds.dshield.org/block.txt | awk '/^[0-9]/ { print "deny " $1 "/24; # comment=DShield"}' >> $saveTo/dshield-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/spamhaus-deny.conf
	wget -O - http://www.spamhaus.org/drop/drop.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=SpamHaus"}' >> $saveTo/spamhaus-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/spamhaus2-deny.conf
	wget -O - http://www.spamhaus.org/drop/edrop.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=edrop"}' >> $saveTo/spamhaus2-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/malc0de-deny.conf
	wget -O - http://malc0de.com/bl/IP_Blacklist.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=malc0de"}' >> $saveTo/malc0de-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/myipms-deny.conf
	wget -O - https://myip.ms/files/blacklist/general/latest_blacklist.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=myipms"}' >> $saveTo/myipms-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/blocklist-deny.conf
	wget -O - https://lists.blocklist.de/lists/all.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=blocklist"}' >> $saveTo/blocklist-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/zeustracker-deny.conf
	wget -O - https://zeustracker.abuse.ch/blocklist.php?download=ipblocklist | awk '/^[0-9]/ { print "deny " $1 "; # comment=zeustracker"}' >> $saveTo/zeustracker-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/ransomwaretracker-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=ransomwaretracker"}' >> $saveTo/ransomwaretracker-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/TeslaCrypt-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/TC_PS_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=TeslaCrypt"}' >> $saveTo/TeslaCrypt-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/CryptoWall-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/CW_PS_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=CryptoWall"}' >> $saveTo/CryptoWall-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Locky-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/LY_C2_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=Locky"}' >> $saveTo/Locky-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Locky2-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/LY_PS_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=Locky2"}' >> $saveTo/Locky2-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/TorrentLockerC2-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/TL_C2_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=TorrentLockerC2"}' >> $saveTo/TorrentLockerC2-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/TorrentLocker-deny.conf
	wget -O - http://ransomwaretracker.abuse.ch/downloads/TL_PS_IPBL.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=TorrentLocker"}' >> $saveTo/TorrentLocker-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Aattack30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/atlas_attacks_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Aattack30d"}' >> $saveTo/Aattack30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Abotnets30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/atlas_botnets_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Abotnets30d"}' >> $saveTo/Abotnets30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Afastflux30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/atlas_fastflux_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Afastflux30d"}' >> $saveTo/Afastflux30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Aphishing30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/atlas_phishing_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Aphishing30d"}' >> $saveTo/Aphishing30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Ascans30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/atlas_scans_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Ascans30d"}' >> $saveTo/Ascans30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/Biany230d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/bi_any_2_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=Biany230d"}' >> $saveTo/Biany230d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/ciarmy-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/ciarmy.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=ciarmy"}' >> $saveTo/ciarmy-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/asproxc2-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/asprox_c2.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=asproxc2"}' >> $saveTo/asproxc2-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/cleanmxviruses-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cleanmx_viruses.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=cleanmxviruses"}' >> $saveTo/cleanmxviruses-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/cleanmxphishing-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cleanmx_phishing.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=cleanmxphishing"}' >> $saveTo/cleanmxphishing-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/iwspamlist-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/iw_spamlist.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=iwspamlist"}' >> $saveTo/iwspamlist-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/ipmasterlist-deny.conf
	wget -O - http://osint.bambenekconsulting.com/feeds/c2-ipmasterlist.txt | awk '/^[0-9]/ { print "deny " $1 ";"}' | awk -F "," '{gsub("IP"," ",$1);print $1"; # comment=ipmasterlist"}' >> $saveTo/ipmasterlist-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/cybercrime-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cybercrime.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=cybercrime"}' >> $saveTo/cybercrime-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/stopforumspam30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/stopforumspam_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=stopforumspam30d"}' >> $saveTo/stopforumspam30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/torexits30d-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/tor_exits_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=torexits30d"}' >> $saveTo/torexits30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/fireholanon-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_anonymous.netset | awk '/^[0-9]/ { print "deny " $1 "; # comment=fireholanon"}' >> $saveTo/fireholanon-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/firehol_level1-deny.conf
	wget -O - https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset | awk '/^[0-9]/ { print "deny " $1 "; # comment=firehol_level1"}' >> $saveTo/firehol_level1-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/normshield-deny.conf
	wget -O - https://iplists.firehol.org/files/normshield_all_wannacry.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=normshield"}' >> $saveTo/normshield-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/php_spammers_30d-deny.conf
	wget -O - https://iplists.firehol.org/files/php_spammers_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=php_spammers_30d"}' >> $saveTo/php_spammers_30d-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/yakakliker-deny.conf
	wget -O - http://www.yakakliker.org/@api/deki/files/1451/=yakakliker.txt | awk '/^[0-9]/ { print "deny " $1 "; # comment=yakakliker"}' >> $saveTo/yakakliker-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/malwaredomainlist-deny.conf
	wget -O - http://www.malwaredomainlist.com/hostslist/ip.txt | awk '/^[0-9]/ sub("\r$", "") { print "deny " $1 "; # comment=malwaredomainlist"}' >> $saveTo/malwaredomainlist-deny.conf

	echo "# Generated by Yakakliker.org for NGINX" `date` > $saveTo/darklist_de-deny.conf
	wget -O - https://iplists.firehol.org/files/darklist_de.netset | awk '/^[0-9]/ { print "deny " $1 "; # comment=darklist_de"}' >> $saveTo/darklist_de-deny.conf

	echo "# Generated by Yakakliker.org" `date` > $saveTo/cybercrime-deny.conf
	wget -O - https://iplists.firehol.org/files/cybercrime.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=cybercrime"}' >> $saveTo/cybercrime-deny.conf

	echo "# Generated by Yakakliker.org" `date` > $saveTo/tor-deny.conf
	wget -O - https://iplists.firehol.org/files/tor_exits_30d.ipset | awk '/^[0-9]/ { print "deny " $1 "; # comment=tor"}' >> $saveTo/tor-deny.conf
	EOF

	chmod uga+x /home/${secure_user}/getblacklist.sh
	sudo mkdir -p /etc/nginx/deny

	#nginx add allow
	if [ $(grep -c "allow ${lan_network}" /etc/nginx/nginx.conf) == 0 ]; then
		sudo sed -i "/sites-enabled/i\\tallow ${lan_network}/24;" /etc/nginx/nginx.conf
	fi

	#nginx add include /etc/nginx/deny/*.conf;
	if [ $(grep -c 'deny' /etc/nginx/nginx.conf) == 0 ]; then
		sudo sed -i '/sites-enabled/a\\tinclude /etc/nginx/deny/*.conf;' /etc/nginx/nginx.conf
	fi


	#add refresh list in crontab
	sudo su
	(crontab -l 2>/dev/null; echo "30 0 * * * /home/${secure_user}/getblacklist.sh >> /var/log/blacklist.log") | crontab -
	exit

}

install_nginx () {
	echo "${cyan}Start installation nginx${white}"
	#set -x
	sudo apt-get -y install nginx
	#remove listen ipv6
	sudo sed -i '/.*::.*/ d' /etc/nginx/sites-available/default
	#install again
	sudo apt-get -y install nginx

	security_iptables

	if [ ! -f /etc/nginx/dh4096.pem ]; then
		echo "${cyan}Create dh406.pem file, be patient more than 40 minutes ...${white}"
		cd /etc/nginx
		sudo openssl dhparam -out dh4096.pem 4096
		cd ~
	fi

	echo "${cyan}Get letsencrypt certificat${white}"
	sudo apt-get -y install certbot
	if [ ! -f /etc/letsencrypt/live/${webserver_name}/fullchain.pem ]; then
		sudo systemctl stop nginx
		sudo certbot certonly --standalone -d ${webserver_name}
	fi

	sudo sh -c 'cat > /etc/nginx/perfect-forward-secrecy.conf <<-EOF
	##
	# SSL Settings
	##

	ssl_protocols TLSv1.2 TLSv1.3; # Dropping SSLv3, TLSv1 TLSv1.1 ref: POODLE
	ssl_prefer_server_ciphers on;
	ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
	ssl_dhparam dh4096.pem;
	EOF'

	sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.ori
	#configure nginx
	sudo sh -c 'cat > /etc/nginx/nginx.conf <<-EOF
	user www-data;
	worker_processes 2;
	pid /run/nginx.pid;

	events {
	        worker_connections 768;
	        # multi_accept on;
	}

	http {

	        ##
	        # Basic Settings
	        ##

	        sendfile on;
	        tcp_nopush on;
	        tcp_nodelay on;
	        #keepalive_timeout 65;
	        types_hash_max_size 2048;
	        server_tokens off;

	        server_names_hash_bucket_size 64;
	        # server_name_in_redirect off;

	        include /etc/nginx/mime.types;
	        default_type application/octet-stream;

	        ##
	        # Logging Settings
	        ##

	        gzip on;
	        gzip_disable "msie6";

	        # gzip_vary on;
	        # gzip_proxied any;
	        # gzip_comp_level 6;
	        # gzip_buffers 16 8k;
	        # gzip_http_version 1.1;
	        # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	        ##
	        # Virtual Host Configs
	        ##

	        include /etc/nginx/conf.d/*.conf;
	        include /etc/nginx/sites-enabled/*;
	        include /etc/nginx/perfect-forward-secrecy.conf;

	        ##
	        # Harden nginx against DDOS
	        ##

	        client_header_timeout 10;
	        client_body_timeout   10;
	        keepalive_timeout     10 10;
	        send_timeout          10;
	}
	EOF'


	#configure as reverse-proxy
	sudo sh -c 'cat > /etc/nginx/conf.d/proxy.conf <<-EOF
	proxy_redirect          off;
	proxy_set_header        Host            $host;
	proxy_set_header        X-Real-IP       $remote_addr;
	proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
	client_max_body_size    10m;
	client_body_buffer_size 128k;
	client_header_buffer_size 64k;
	proxy_connect_timeout   90;
	proxy_send_timeout      90;
	proxy_read_timeout      90;
	proxy_buffer_size   16k;
	proxy_buffers       32   16k;
	proxy_busy_buffers_size 64k;
	EOF'

	#add jeedom website
	sudo sh -c "cat > /etc/nginx/sites-available/jeedom <<-EOF
	#Jeedom server
	#proxy vers ${jeedom_ip} à la racine
	upstream backend {
			server ${jeedom_ip}:80;
			server ${jeedomSec_ip}:80;
	}

	server {
	        listen 80;
	        server_name ${webserver_name};
	        access_log /var/log/nginx/jeedom.access.log;
	        error_log /var/log/nginx/jeedom.error.log;
	        location / {
	                proxy_pass      http://${jeedom_ip}/;
	        }

	server {
	        listen 443 ssl http2;
	        server_name ${webserver_name};

	        ssl_certificate /etc/letsencrypt/live/${webserver_name}/fullchain.pem;
	        ssl_certificate_key /etc/letsencrypt/live/${webserver_name}/privkey.pem;
	        access_log /var/log/nginx/jeedom.access.log;
	        error_log /var/log/nginx/jeedom.error.log;
	        location / {
	                proxy_pass      http://backend;
	                proxy_set_header X-Real-IP \$remote_addr;
	                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	                proxy_set_header X-Forwarded-Proto \$scheme;
	        }

	}
	EOF"

	sudo ln -s /etc/nginx/sites-available/jeedom /etc/nginx/sites-enabled/jeedom
	sudo rm /etc/nginx/sites-enabled/default

	echo "${cyan}Restart nginx${white}"
	sudo systemctl restart nginx

	echo "${cyan}End installation nginx${white}"
}

install_vpn () {
	echo "${cyan}Start installation pivpn${white}"
	echo "${green}use Wireguard, please...${white}"
	curl -L https://install.pivpn.io | bash
	echo "${cyan}End installation pivpn${white}"
}


install_desktop () {
	echo "${cyan}Start installation graphical environnement (desktop)${white}"
	echo "${green}Start minimal xorg...${white}"
	sudo apt-get -y install --no-install-recommends xserver-xorg
	#add startx instead of session manager like lightdm
	sudo apt-get -y install --no-install-recommends xinit
	echo "${green}Start minimal desktop lxde...${white}"
	sudo apt-get install lxde-core
	
	file="/etc/lightdm/lightdm.conf"
	if [ $(grep -c ${secure_user} ${file}) == 0 ]; then
		#[SeatDefaults] add
		sudo sed -i "s/^s#autologin-user=/autologin-user=${secure_user}/"  ${file}
		sudo sed -i "s/^s#autologin-user-timeout=/autologin-user-timeout=0/"  ${file}
		sudo sed -i "s/^s#autologin-session=/autologin-session=openbox/"  ${file}
		sudo sed -i "s/^s#pam-autologin-service=/pam-service=lightdm-autologin/"  ${file}
	fi
	#start console mode at boot
	sudo systemctl set-default multi-user
	
	echo "${cyan}End installation graphical environnement (desktop)${white}"
}

#parameters
# #1 : version of nodejs, default 12
install_nodejs () {
	version=${1:-12}
	echo "${cyan}Start installation nodejs server version ${version}${white}"
	arch=$(uname -m)
	if [ $arch == "armv6l"]; then
		echo "exit because armv6l"
		exit 1
	fi
	#si armv6 , voir ce post raspberrypi.org/forums/viewtopic.php?t=229881
	
	# install node and npm for rpi1 or rpi zero
	#sudo curl -Lf# "https://unofficial-builds.nodejs.org/download/release/v12.18.3/node-v12.18.3-linux-armv6l.tar.gz" | sudo tar xzf - -C /usr/local --strip-components=1 --no-same-owner
	#install latest v12 version (compatibility with room assistant)
	curl -sL https://deb.nodesource.com/setup_${version}.x | sudo bash -
	sudo apt-get install -y nodejs
	echo "${cyan}End installation nodejs version $(node -v)${white}"
}

#parameters
# #1 : instanceName of room-assistant, default hostname
# #2 : IP address of mqtt server, default 192.168.0.30
# #3 : user for installation, defaut hermes
#
# tips : if error at startup like [ClusterService] Cannot find module '../build/Release/dns_sd_bindings'
# you need to rebuild mdns module (cf. https://github.com/homebridge/homebridge/issues/905#issuecomment-274251797)
# cd /usr/local/lib/node_modules/room-assistant/
# sudo npm install --unsafe-perm mdns
# sudo npm rebuild --unsafe-perm

install_room_assistant () {
	echo "${cyan}Start installation room assistant${white}"
	room_name=${1:-$(hostname)}
	mqtt_ip=${2:-192.168.0.30}
	user=${3:-hermes}
	echo "${cyan}Room = ${room_name}, mqtt_ip = ${mqtt_ip}, user = ${user}${white}"
	mkdir -p /home/${user}/room-assistant/config
	#todo check if node is installed
	sudo apt-get install -y libavahi-compat-libdnssd-dev
	sudo npm i --global --unsafe-perm room-assistant

	sudo setcap cap_net_raw+eip $(eval readlink -f `which node`)
	sudo setcap cap_net_raw+eip $(eval readlink -f `which hcitool`)
	sudo setcap cap_net_admin+eip $(eval readlink -f `which hciconfig`)
	
	sudo sh -c "cat > /etc/systemd/system/room-assistant.service <<-EOF
	[Unit]
	Description=room-assistant service

	[Service]
	ExecStart=/usr/local/bin/room-assistant
	WorkingDirectory=/home/${user}/room-assistant
	Restart=always
	RestartSec=10
	User=${user}

	[Install]
	WantedBy=multi-user.target
	EOF"

	sudo systemctl enable room-assistant.service
	sudo systemctl start room-assistant.service
	
	sh -c "cat > /home/hermes/room-assistant/config/local.yml <<-EOF
	global:
	  integrations:
	    - homeAssistant
	    - bluetoothLowEnergy
	instanceName: ${room_name}
	homeAssistant:
	  mqttUrl: 'mqtt://${mqtt_ip}:1883'
	  mqttOptions:
	    username: room-assistant
	    password: yourpass
	bluetoothLowEnergy:
	  whitelist:
	    - f046000b8b01
	EOF"

	echo "${cyan}End installation room assistant${white}"
}


configure_rdp () {
	sudo apt-get install -y freerdp2-x11
	sudo nano /usr/share/applications/Rdp.desktop
[Desktop Entry]
Type=Application
Name=RDP
Comment=Terminal Windows
Exec=/usr/bin/xfreerdp /microphone:sys:alsa /sound:sys:alsa /usb:id,dev:043e:3007 /clipboard /size:70% /u:Thierry /network:lan /v:192.168.0.33
Terminal=false
Categories=Development;
}

configure_webcam () {
	#créer le fichier /etc/udev/rules.d/51-webcam-permissions.rules avec le contenu
	file="/etc/udev/rules.d/51-webcam-permissions.rules"
	sudo sh -c "echo 'SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\",ATTR{idVendor}==\"043e\" , ATTR{idProduct}==\"3007\", MODE=\"0666\"' >> ${file}"
	sudo sh -c "echo 'SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\",ATTR{idVendor}==\"043e\" , ATTR{idProduct}==\"3008\", MODE=\"0666\"' >> ${file}"

}


install_usb_redirection () {
	sudo apt-get -y install usbip
	sudo sh -c "modprobe usbip-core; modprobe usbip-host"
	sudo sh -c "usbipd -D"
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
#sudo cp /home/jeedom/music/user/prefs.tgz .
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

print_routines () {
	routines=$(declare -f -F | awk '{print $3}')
	echo $routines
}

print_modules () {
	modules=$(declare -f -F | awk '{print $3}' | awk '{split($0,a,"_"); print a[2]}')
	echo $modules
}


if [ ${printModules} == 1 ]; then
	print_modules
	exit 0
fi

if [ ${printRoutines} == 1 ]; then
	print_routines
	exit 0
fi

identify_system

if [ -z "${modules}" ]; then
	modules=$(echo ${role} | tr "+" " ")
fi
echo "${cyan}List of modules to install on this server${white}"
for module in ${modules}
do
	echo "Module=${cyan}${module}${white}"
	routines=$(declare -f -F | awk -v var=${module} '$0~var {print $3}')
	if [ -z "${routines}" ]; then
		echo "Module ${yellow}${module}${red} is not yet immplemented or not found, skip...${white}"
		exit 1
	else
		echo "Module ${yellow}${module}${cyan} is associated to routines ${yellow}${routines}${white}"
	fi
	for routine in ${routines}
	do
		echo "Check configuration of routine ${cyan}${routine}${white} on this server"
		case ${module} in
		dmz)
			echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			;;
		vpn)
			echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			${routine}
			;;
		nginx)
			#echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			${routine}
			;;
		kodi)
			echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			;;
		mqtt)
			echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			;;
		ebus)
			install_ebus
			#echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			;;
		blea)
			echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			;;
		desktop)
			#echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			${routine}
			;;
		iptables)
			#echo "Routine ${yellow}${routine} already configured on this server, skip...${white}"
			${routine}
			;;
		*)
			echo "Routine ${red}${routine} is unknown, skip...${white}"
			;;
		esac
	done
done


echo "${cyan}End configuration of this server${white}"
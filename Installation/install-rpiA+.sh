#!/bin/bash
#
# Automatisation de l'installation du serveur raspberry piA+ de la chambre des parents
#

#set -x

newhost=rpiA+-parents


#Assign existing hostname to $hostn
hostn=$(cat /etc/hostname)

#Display existing hostname
echo "Existing hostname is $hostn"

#Ask for new hostname $newhost
#echo "Enter new hostname: "
#read newhost

#change hostname in /etc/hosts & /etc/hostname
sudo sed -i "s/$hostn/$newhost/g" /etc/hosts
sudo sed -i "s/$hostn/$newhost/g" /etc/hostname

#display new hostname
echo "Your new hostname is $newhost"


 
#Changer adresse mac : à quoi çà sert ?
#sudo nano /boot/cmdline.txt
#dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p7 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait smsc95xx.macaddr=b8:27:eb:ec:91:d0

FILE=/boot/config.txt

#max memory for server
LINE='gpu_mem=16'
grep -qF "$LINE" "$FILE"  

if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi
#sudo echo "gpu_mem=16" >> /boot/config.txt

#max de puissance sur les ports USB
LINE='max_usb_current=1'
if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi
#sudo echo "max_usb_current=1" >> /boot/config.txt

# Disable the ACT LED.
LINE='dtparam=act_led_trigger=none'
if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi
LINE='dtparam=act_led_activelow=off'
if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi

# Disable the PWR LED.
LINE='dtparam=pwr_led_trigger=none'
if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi
LINE='dtparam=pwr_led_activelow=off'
if [ $? -ne 0 ]; then
  sudo echo $LINE >> $FILE
  echo "modify $FILE with $LINE"
fi

#
# Mise à jour du système
#

#sudo apt-get update
#sudo apt-get upgrade


# create new user

function createsshuser () {
  username="$1"
  shift 
  SSH_PUBLIC_KEY="$*"
  
  useradd -m -d /home/${username} -s /bin/bash ${username}
  
  #genrate a random password
  password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  
  echo ${username}:${password} | chpasswd
  echo "password is ${password}"

  # add the user to the sudo group so they can sudo
  	
  usermod -a -G sudo ${username}

  #Editez ensuite le fichier sudoers :   visudo
  #puis modifier le fichier comme suit :
  # User privilege specification
  #  root ALL=(ALL:ALL) ALL
  #   pluginblea ALL=(ALL) NOPASSWD: ALL
  # Allow members of group sudo to execute any command
  #   %sudo ALL=(ALL) NOPASSWD: ALL

  # add the ssh public key
  #su - ${username} -c "umask 022 ; mkdir .ssh ; echo $SSH_PUBLIC_KEY >> .ssh/authorised_keys"
  
  
  #sudo su - ${username};
  #mkdir /home/${username}/.ssh;
  #ssh-keygen -t rsa;
  #exit;
}

username=pluginblea

id -u ${username}

if [ $? -eq 0 ] ; then
    echo "User Exists"
else
    echo "User Not Found"
    createsshuser ${username}
fi


exit

#disk optimize
/etc/systemd/journald.conf
[Journal]
Storage=volatile
RuntimeMaxUse=30M

#reduce logging : create  /etc/rsyslog.d/jeedom.conf
:msg, contains, "www-data" ~
if $programname == "sudo" and $msg contains "session closed for user root" then stop
if $programname == "sudo" and $msg contains "session opened for user root" then stop



#installation de clés SSH : ex pour gérer à distance kodi (user jeedom, ip = 192.168.0.30)
ssh-keygen -t rsa
(enter pour ne pas créer de passphrase)

ssh-keygen -b 2048 -t rsa -f ~/.ssh/sshkey -C jeedom -q -N ""
cd .ssh
ssh-copy-id -i sshkey.pub jeedom@192.168.0.30
ssh jeedom@192.168.0.30
sudo su
cp /home/pi/.ssh/sshkey* /home/pi/.ssh/known_hosts /var/www/.ssh/
chown www-data.www-data /var/www/.ssh/*


#install watchdog to reboot if wlan0 is down
sudo apt-get install watchdog


exit




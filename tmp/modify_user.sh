#!/bin/sh
set -x
. tmp/env.sh
if [ "$USER" = "$newuser" ]
then
#we are connected with the new user
	id -u "temp"
	if [ ($?) ]
	then
		sudo userdel "temp"
		echo "Temporary user $RED temp $NORMAL has been deleted. $GREEN Procedure is completed."
	else
		echo "Default user has already changed.."
		echo "Modify /etc/sudoers.d/* to remove asking for password."
	fi
else
#we are connected with the user to rename or the temp user
	if [ "$USER" = "temp" ]
	then
		#we are connected with the temp user
		sudo -s usermod -l $newuser -d /home/$newuser -m "$olduser"
		echo "$NORMAL Please logoff now and reconnect with the user $GREEN $newuser"
		echo "$NORMAL Then, you can change the password for this user : $GREEN $newuser"
	else
		echo $'\n' >> tmp/env.sh
		echo "olduser=$USER" >> tmp/env.sh
		sudo useradd -m "temp" -G sudo
		echo "temp" | sudo passwd "temp" --stdin
		echo "$NORMAL Please logoff now and reconnect with the user $GREEN temp $NORMAL and password $GREEN temp"
		echo "$NORMAL Then, enter this command again : $GREEN cd /tmp/rpi3 && tmp/modify_user.sh"
	fi
fi
#echo "Choose a password for the new user $GREEN $user"
#sudo passwd $user
#echo "$NORMAL Please logoff now and reconnect with the new user $GREEN $user"
#echo "$NORMAL Then, enter this command : $GREEN sudo deluser pi"
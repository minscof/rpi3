#!/bin/sh
set -x
. tmp/env.sh
if [ "$USER" = "$newuser" ]
then
#we are connected with the new user
	echo "Default user has already changed.."
else
#we are connected with the user to rename or the temp user
	if [ "$USER" = "temp" ]
	then
		#we are connected with the temp user
		exec sudo -s usermod -l $newuser -d /home/$newuser -m "$olduser"
		echo "$NORMAL Please logoff now and reconnect with the user $VERT $newuser"
		echo "$NORMAL Then, you can change the password for this user : $VERT $newuser"
	else
		echo "olduser=$USER" >> tmp/env.sh
		sudo useradd -m "temp" -G sudo
		echo "temp" | passwd "temp" --stdin
		echo "$NORMAL Please logoff now and reconnect with the  user temp and password temp"
		echo "$NORMAL Then, enter this command again : $VERT modify_user.sh"	fi
fi
#echo "Choose a password for the new user $VERT $user"
#sudo passwd $user
#echo "$NORMAL Please logoff now and reconnect with the new user $VERT $user"
#echo "$NORMAL Then, enter this command : $VERT sudo deluser pi"
#! /bin/sh
. tmp/env.sh
cp tmp/home/user/update_motd.sh /home/$USER
sudo sh -c "echo \"sh /home/$USER/update_motd.sh\" >> /etc/profile"
sudo chmod +w /etc/motd
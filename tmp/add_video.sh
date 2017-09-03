#!/bin/sh
mkdir ~/videos
mkdir ~/videos/mars
dir=/home/$USER
sudo ln -s $dir /storage
sudo sh -c "echo \"192.168.0.15:/media/multimedia2/videos /storage/videos/mars nfs user,auto 0 0\" >> /etc/fstab"
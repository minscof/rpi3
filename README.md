# configuration and installation of an rpi3 with reverse proxy

install raspbian
from the console
- modify gpu mem : eg 256 for graphic
- modify keyboard
- activate ssh
- sudo apt-get update && sudo apt-get -y upgrade
- sudo apt-get install -y git
- cd /tmp
- git clone https://github.com/minscof/rpi3.git
- cd rpi3
- chmod -R +x tmp/*.sh
- tmp/modify_user.sh
- tmp/modify_iptables.sh
- tmp/add_video2fstab.sh



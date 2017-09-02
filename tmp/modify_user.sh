#!/bin/sh
. /tmp/env.sh
exec sudo -s
cd /
usermod -l $user -d /home/$user -m pi
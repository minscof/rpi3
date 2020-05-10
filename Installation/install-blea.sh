#!/bin/bash
#
# Automatisation de l'installation de squeeze lite sur un serveur raspberry
#
# http://www.compu-tek.fr/blog/tutoriel-installer-squeezelite-sur-raspbian/
# http://www.geekmag.fr/installer-squeezelite-sur-raspbian/
#

set -x
file="blearpistart"
ipJeedom="192.168.0.9"
apikey="la.clef.api.de.BLEA"
name="nom.antenne.blea"
echo '#!/bin/sh' > ${file}
echo '#/etc/init.d/blearpistart' >> ${file}
echo ' ' >> ${file}
echo '### BEGIN INIT INFO' >> ${file}
echo '# Provides:          Jeedom BLEA Plugin' >> ${file}
echo '# Required-Start:    $remote_fs $syslog' >> ${file}
echo '# Required-Stop:     $remote_fs $syslog' >> ${file}
echo '# Default-Start:     2 3 4 5' >> ${file}
echo '# Default-Stop:      0 1 6' >> ${file}
echo '# Short-Description: Simple script to start a program at boot' >> ${file}
echo '# Description:       A simple script similar to one from www.stuffaboutcode.com which will start / stop a program a boot / shutdown.' >> ${file}
echo '### END INIT INFO' >> ${file}
echo ' ' >> ${file}
echo '# If you want a command to always run, put it here' >> ${file}
echo 'touch /tmp/blea' >> ${file}
echo 'chmod 666 /tmp/blea' >> ${file}
echo ' ' >> ${file}
echo '# Carry out specific functions when asked to by the system' >> ${file}
echo 'case "$1" in' >> ${file}
echo '  start)' >> ${file}
echo '    echo "Starting BLEA"' >> ${file}
echo '    # run application you want to start' >> ${file}
temp='    /usr/bin/python /home/pi/blead/resources/blead/blead.py --loglevel error --device hci0 --socketport 55008 --sockethost "" --callback https://'
temp1=':443/plugins/blea/core/php/jeeBlea.php --apikey '
temp2=' --daemonname "'
temp3='" >> /tmp/blea 2>&1'
temp="$temp$ipJeedom$temp1$apikey$temp2$name$temp3"
echo "${temp}" >> ${file}
echo '    ;;' >> ${file}
echo '  stop)' >> ${file}
echo '    echo "Stopping BLEA"' >> ${file}
echo '    # kill application you want to stop' >> ${file}
echo '    sudo kill `ps -ef | grep blea | grep -v grep | awk "{print $2}"`' >> ${file}
echo '    ;;' >> ${file}
echo '  *)' >> ${file}
echo '    echo "Usage: /etc/init.d/blearpistart {start|stop}"' >> ${file}
echo '    exit 1' >> ${file}
echo '    ;;' >> ${file}
echo 'esac' >> ${file}
echo ' ' >> ${file}
echo 'exit 0' >> ${file}

chmod a+x ${file}
sudo mv ${file} /etc/init.d


file="blearpistart.service"	
echo '[Unit]' >> ${file}
echo 'Description=BlEA service' >> ${file}
echo 'After=hciuart.service' >> ${file}
echo ' ' >> ${file}
echo '[Service]' >> ${file}
echo 'Type=oneshot' >> ${file}
echo 'ExecStart=/etc/init.d/blearpistart start' >> ${file}
echo ' ' >> ${file}
echo '[Install]' >> ${file}
echo 'WantedBy=multi-user.target' >> ${file}
echo ' ' >> ${file}

sudo mv ${file} /etc/systemd/system/

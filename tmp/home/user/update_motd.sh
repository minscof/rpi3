#! /bin/sh

VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[0;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"

upSeconds=`/usr/bin/cut -d. -f1 /proc/uptime`
secs=$(($upSeconds%60))
mins=$(($upSeconds/60%60))
hours=$(($upSeconds/3600%24))
days=$(($upSeconds/86400))
UPTIME=`printf "%d days, %02dh %02dm %02ds " "$days" "$hours" "$mins" "$secs"`

tmp_size=`df -h /tmp | awk '{ a = $2 } END { print a }'`
tmp_used=`df -h /tmp | awk '{ b = $3 } END { print b }'`
tmp=`df /tmp | awk '{ c = $5 } END { print c }'`

root_size=`df -h / | awk '{ a = $2 } END { print a }'`
root_used=`df -h / | awk '{ b = $3 } END { print b }'`
root=`df / | awk '{ c = $5 } END { print c }'`

echo "$VERT
_  ______  _____ _____
 | |/ / __ \|  __ \_   _|
 | ' / |  | | |  | || |
 |  <| |  | | |  | || |
 | . \ |__| | |__| || |_
 |_|\_\____/|_____/_____|




$ROSE------------------------------------------------------------------$BLANC
$VERT Informations :$BLANC
- Hostname      = $JAUNE `hostname -s` $BLANC
- @ IP          = $JAUNE `/sbin/ifconfig | /bin/grep "Bcast:" | /usr/bin/cut -d ":" -f 2 | /usr/bin/cut -d " " -f 1` $BLANC/$JAUNE `wget -q -O - http://icanhazip.com/ | tail`$BLANC
- Date          =  `date`
$ROSE------------------------------------------------------------------$BLANC
$VERT Système : $BLANC
- Version OS    =  `lsb_release -ds`
- Kernel        =  `uname -or`
- Uptime        =  $UPTIME
- Température   =  `vcgencmd measure_temp | sed "s/temp=//"`
$ROSE------------------------------------------------------------------$BLANC
$VERT Charge : $BLANC
- Load Averages =  `cat /proc/loadavg`
- Processus     =  `ps ax | wc -l | tr -d " "`
- Mémoire       =  $((`cat /proc/meminfo | grep MemFree | awk {'print $2'}`/1024))MB (Free) / $((`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`/1024))MB (Total)
$ROSE------------------------------------------------------------------$BLANC
$VERT Disques : $BLANC
- Utilisation de /      = $root ($root_used/$root_size)
- Utilisation de /tmp   = $tmp ($tmp_used/$tmp_size)
$BLANC" > /etc/motd
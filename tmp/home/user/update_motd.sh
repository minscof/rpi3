#! /bin/sh

GREEN="\\033[1;32m"
NORMAL="\\033[0;39m"
RED="\\033[0;31m"
PINK="\\033[1;35m"
BLUE="\\033[1;34m"
WHITE="\\033[0;02m"
LIGHTWHITE="\\033[1;08m"
YELLOW="\\033[1;33m"
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

echo "$GREEN
_  ______  _____ _____
 | |/ / __ \|  __ \_   _|
 | ' / |  | | |  | || |
 |  <| |  | | |  | || |
 | . \ |__| | |__| || |_
 |_|\_\____/|_____/_____|




$PINK------------------------------------------------------------------$WHITE
$GREEN Informations :$WHITE
- Hostname      = $YELLOW `hostname -s` $WHITE
- @ IP          = $YELLOW `/sbin/ifconfig | /bin/grep "Bcast:" | /usr/bin/cut -d ":" -f 2 | /usr/bin/cut -d " " -f 1` $WHITE/$YELLOW `wget -q -O - http://icanhazip.com/ | tail`$WHITE
- Date          =  `date`
$PINK------------------------------------------------------------------$WHITE
$GREEN Système : $WHITE
- Version OS    =  `lsb_release -ds`
- Kernel        =  `uname -or`
- Uptime        =  $UPTIME
- Température   =  `vcgencmd measure_temp | sed "s/temp=//"`
$PINK------------------------------------------------------------------$WHITE
$GREEN Charge : $WHITE
- Load Averages =  `cat /proc/loadavg`
- Processus     =  `ps ax | wc -l | tr -d " "`
- Mémoire       =  $((`cat /proc/meminfo | grep MemFree | awk {'print $2'}`/1024))MB (Free) / $((`cat /proc/meminfo | grep MemTotal | awk {'print $2'}`/1024))MB (Total)
$PINK------------------------------------------------------------------$WHITE
$GREEN Disques : $WHITE
- Utilisation de /      = $root ($root_used/$root_size)
- Utilisation de /tmp   = $tmp ($tmp_used/$tmp_size)
$WHITE" > /etc/motd
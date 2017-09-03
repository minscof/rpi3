#!/bin/sh
set -x
sudo cp etc/iptables /etc/iptables.firewall.rules
sudo /sbin/iptables-restore < /etc/iptables.firewall.rules
sudo sh -c "echo \"#!/bin/sh\" > /etc/network/if-pre-up.d/firewall"
sudo sh -c "echo \"/sbin/iptables-restore < /etc/iptables.firewall.rules\" >> /etc/network/if-pre-up.d/firewall"
sudo cp etc/rsyslog.d/iptables.conf /etc/rsyslog.d/
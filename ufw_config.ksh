#!/usr/bin/ksh
################################################################

################################################################
#### A simple script to securely configure
#### the uncomplicated firewall.
#### Script assumes net tools package is not
#### installed. Script will only allowing
#### dns, ftp, ssh http, and https.
#### This program needs to be run
#### as sudo after script is complete it will
#### drop sudo privileges. Also, if you
#### wish you can disable ping.
#### "sudo vi /etc/ufw/before.rules"
#### -A ufw-before-forward -p icmp --icmp-type echo-request -j Drop
#### Add Above to line 40 then run "sudo ufw reload"
################################################################

################################################################
#### Set Debug Mode
# set -x

################################################################
#### Get interface set dns
iface=$(ip route get 1.1.1.1 | awk -- '{printf $5}')
dns1="1.1.1.1"
dns2="1.0.0.1"

################################################################
#### Config ufw to allow dns, ftp, ssh, http, and https.
function config_ufw {
    ufw enable
    ufw logging low
    ufw logging on
    ufw default deny incoming
    ufw default deny forward
    ufw default deny outgoing
    ufw allow out on $iface to $dns1 proto udp port 53
    ufw allow out on $iface to $dns2 proto udp port 53
    ufw allow out on $iface to $dns1 proto udp port 853
    ufw allow out on $iface to $dns2 proto udp port 853
    ufw allow out on $iface to any proto tcp port 21
    ufw allow out on $iface to any proto tcp port 22
    ufw allow out on $iface to any proto tcp port 80
    ufw allow out on $iface to any proto tcp port 443
    ufw reload
    ufw status verbose
}

################################################################
#### Display Message
function displaymsg {
  print "
Program: ufw_config.ksh
Date: 05/12/2025
Author: William Butler (coldboot@mailfence.com)
License: MIT License.
"
}

################################################################
#### Run Functions

config_ufw
displaymsg

################################################################
#### Exit
exit $?

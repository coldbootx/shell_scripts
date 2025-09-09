#!/usr/bin/ksh93
################################################################
#### A simple debian base full system update script.
#### This will fix any broke or missing dependencies, update package list, upgrade packages,
#### upgrade dependencies, then it will run a full clean up!
#### This program needs to be ran as sudo after script is complete it drops sudo privileges!
################################################################

################################################################
#### Display Message
function displaymsg {
  print "
Program: update.ksh
Date: 04/25/2020
Version: 1.2
Author: William Butler coldboot@yahoo.com
License: GNU GPL (version 3, or any later version).
"
}

################################################################
#### Full System Updat and Clean Up
function update {
  apt-get install -f
  apt-get update -y
  apt-get upgrade -y
  apt-get dist-upgrade -y
  apt-get autoclean
  apt-get autoremove -y
  apt-get clean
}

################################################################
#### Drop Sudo
function drop_sudo {
	sudo -k
}

################################################################
#### Run Functions
update
drop_sudo
displaymsg

################################################################
#### Exit
exit ${?}

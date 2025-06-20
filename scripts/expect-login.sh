#!/usr/bin/expect -f
# expect-login.sh - Use expect to automate the q login process
# This script uses expect to handle the interactive prompts

set timeout 300
set sso_url [lindex $argv 0]
set region [lindex $argv 1]

# Check if arguments are provided
if {$sso_url == "" || $region == ""} {
    puts "Usage: $argv0 <sso-url> <region>"
    exit 1
}

# Start the q login process
spawn q login --license pro

# Handle the interactive prompts
expect "Enter Start URL"
send "$sso_url\r"

expect "Enter Region"
send "$region\r"

# Wait for the verification URL and code
expect {
    -re {Open this URL: (https://[^\r\n]+)} {
        set url $expect_out(1,string)
        puts "Authentication URL: $url"
        
        # Send SNS notification with the URL and code
        set sns_topic $::env(LOGIN_SNS_TOPIC)
        if {$sns_topic != ""} {
            puts "Sending SNS notification to topic: $sns_topic"
            set message "Amazon Q Developer CLI authentication required\nURL: $url"
            exec aws sns publish --topic-arn $sns_topic --message $message
        } else {
            puts "LOGIN_SNS_TOPIC environment variable not set, skipping SNS notification"
        }
        
        # Continue waiting for authentication
        puts "Waiting for authentication to complete..."
    }
    timeout {
        puts "Timed out waiting for authentication URL"
        exit 1
    }
}

# Wait for the "Logged In" message
expect {
    "Logged In" {
        puts "Authentication successful! User is now logged in."
        exit 0
    }
    timeout {
        puts "Timed out waiting for authentication to complete"
        exit 1
    }
}

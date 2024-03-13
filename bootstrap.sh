#!/bin/bash

# Update the system
sudo yum update -y

# Install Docker and git
yum install git -y
yum install docker -y
systemctl enable docker.service
systemctl start docker.service

# Install jq if it's not already installed
if ! command -v jq &> /dev/null; then
    echo "jq could not be found, installing..."
    sudo yum install jq -y
fi

# Get list of secrets containing the word "bot"
secrets_list=$(aws secretsmanager list-secrets | jq -r '.SecretList[] | select(.Name | contains("bot")) | .Name')

# Initialize an associative array to track which bot repos have been pulled
declare -A bot_repos_pulled

# Iterate through the list of secrets
for secret in $secrets_list; do
    IFS='/' read -ra ADDR <<< "$secret"
    bot_type="${ADDR[0]}"
    subreddit_name="${ADDR[1]}"

    # Check if the bot repo has already been pulled
    if [ -z "${bot_repos_pulled[$bot_type]}" ]; then
        # Mark this bot type as pulled
        bot_repos_pulled[$bot_type]=1

        # Clone the git repo
        git_repo_url="https://github.com/mikeacjones/reddit-${bot_type}"
        echo "Cloning $git_repo_url"
        git clone $git_repo_url
        if [ $? -ne 0 ]; then
            echo "Failed to clone $git_repo_url"
            continue
        fi
    fi

    # Navigate to the cloned directory and run bootstrap.sh with the subreddit name
    if [ -d "reddit-${bot_type}" ]; then
        cd "reddit-${bot_type}"
        if [ -f "bootstrap.sh" ]; then
            echo "Running bootstrap.sh for subreddit: $subreddit_name"
            ./bootstrap.sh "$subreddit_name"
            cd ..
        else
            echo "bootstrap.sh does not exist in $git_repo_url"
            cd ..
        fi
    else
        echo "Directory reddit-${bot_type} does not exist."
    fi
done

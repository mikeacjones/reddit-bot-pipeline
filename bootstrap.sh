#!/bin/bash

# Self-hosted Reddit Bot Pipeline Bootstrap Script
# This script discovers bots from local .env files and deploys them
#
# Directory structure expected:
#   bots/{bot_type}/{subreddit_name}.env
#
# Example:
#   bots/reminder-bot/askreddit.env
#   bots/joke-bot/funny.env

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTS_DIR="${SCRIPT_DIR}/bots"
DEPLOY_DIR="${SCRIPT_DIR}/deployed"

# Create deploy directory if it doesn't exist
mkdir -p "$DEPLOY_DIR"

# Check if bots directory exists
if [ ! -d "$BOTS_DIR" ]; then
    echo "Error: bots/ directory not found at $BOTS_DIR"
    echo "Please create the directory and add .env files in the format:"
    echo "  bots/{bot_type}/{subreddit_name}.env"
    exit 1
fi

# Find all .env files in the bots directory
env_files=$(find "$BOTS_DIR" -name "*.env" -type f 2>/dev/null)

if [ -z "$env_files" ]; then
    echo "No .env files found in $BOTS_DIR"
    echo "Please add .env files in the format: bots/{bot_type}/{subreddit_name}.env"
    exit 1
fi

# Initialize an associative array to track which bot repos have been pulled
declare -A bot_repos_pulled

# Track running containers for cleanup
declare -a deployed_containers

echo "=== Reddit Bot Pipeline - Self-Hosted ==="
echo "Discovering bots from: $BOTS_DIR"
echo ""

# Iterate through all .env files
for env_file in $env_files; do
    # Extract bot_type and subreddit_name from path
    # Path format: bots/{bot_type}/{subreddit_name}.env
    relative_path="${env_file#$BOTS_DIR/}"
    bot_type=$(dirname "$relative_path")
    subreddit_name=$(basename "$relative_path" .env)

    echo "Found: $bot_type / $subreddit_name"

    # Check if the bot repo has already been pulled
    if [ -z "${bot_repos_pulled[$bot_type]}" ]; then
        bot_repos_pulled[$bot_type]=1

        git_repo_url="https://github.com/mikeacjones/reddit-${bot_type}"
        bot_dir="${DEPLOY_DIR}/reddit-${bot_type}"

        if [ -d "$bot_dir" ]; then
            echo "  Updating existing repo: $git_repo_url"
            cd "$bot_dir"
            git fetch origin
            git reset --hard origin/main || git reset --hard origin/master
            cd "$SCRIPT_DIR"
        else
            echo "  Cloning: $git_repo_url"
            if ! git clone "$git_repo_url" "$bot_dir"; then
                echo "  Failed to clone $git_repo_url"
                continue
            fi
        fi
    fi

    bot_dir="${DEPLOY_DIR}/reddit-${bot_type}"

    # Navigate to the cloned directory and run bootstrap.sh with the subreddit name
    if [ -d "$bot_dir" ]; then
        # Copy the .env file to the bot directory with appropriate naming
        env_dest="${bot_dir}/${subreddit_name}.env"
        echo "  Copying .env to: $env_dest"
        cp "$env_file" "$env_dest"

        cd "$bot_dir"
        if [ -f "bootstrap.sh" ]; then
            echo "  Running bootstrap.sh for subreddit: $subreddit_name"
            chmod +x bootstrap.sh
            ./bootstrap.sh "$subreddit_name"
        else
            echo "  Warning: bootstrap.sh not found in $bot_dir"
        fi
        cd "$SCRIPT_DIR"
    else
        echo "  Error: Directory $bot_dir does not exist"
    fi

    echo ""
done

echo "=== Deployment Complete ==="

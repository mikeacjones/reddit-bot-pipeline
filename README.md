# Reddit Bot Pipeline - Self-Hosted

A self-hosted deployment pipeline for Reddit bots using GitHub Actions and Docker.

## Architecture

```
GitHub Repository
       │
       ▼ (push to main / manual trigger)
GitHub Actions (self-hosted runner)
       │
       ▼
Your Home Server
       │
       ├── Clones bot repositories
       ├── Copies .env files
       └── Runs Docker containers
```

## Directory Structure

```
reddit-bot-pipeline/
├── bots/                          # Bot configurations (local only)
│   ├── reminder-bot/
│   │   ├── askreddit.env          # Credentials for r/askreddit
│   │   └── funny.env              # Credentials for r/funny
│   └── joke-bot/
│       └── jokes.env              # Credentials for r/jokes
├── deployed/                      # Cloned bot repos (gitignored)
├── bootstrap.sh                   # Main deployment script
└── .github/workflows/deploy.yml   # GitHub Actions workflow
```

## Setup Instructions

### 1. Install Prerequisites on Your Server

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Git
sudo apt-get install git -y  # Debian/Ubuntu
# or
sudo yum install git -y      # RHEL/CentOS/Amazon Linux
```

### 2. Set Up GitHub Actions Self-Hosted Runner

1. Go to your GitHub repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Select **Linux** and your architecture (x64 or ARM64)
4. Follow the installation commands on your server:

```bash
# Create a directory for the runner
mkdir actions-runner && cd actions-runner

# Download the runner (get latest URL from GitHub)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure (use the token from GitHub)
./config.sh --url https://github.com/YOUR_USERNAME/reddit-bot-pipeline --token YOUR_TOKEN

# Install and start as a service
sudo ./svc.sh install
sudo ./svc.sh start
```

### 3. Configure Your Bots

Create `.env` files for each bot/subreddit combination:

```bash
# Create directory for your bot type
mkdir -p bots/reminder-bot

# Create .env file for the subreddit
cat > bots/reminder-bot/askreddit.env << 'EOF'
REDDIT_CLIENT_ID=your_client_id
REDDIT_CLIENT_SECRET=your_client_secret
REDDIT_USERNAME=your_bot_username
REDDIT_PASSWORD=your_bot_password
EOF
```

The naming pattern is:
```
bots/{bot-type}/{subreddit-name}.env
```

This will:
- Clone `https://github.com/mikeacjones/reddit-{bot-type}`
- Pass the subreddit name to the bot's bootstrap script

### 4. Deploy

**Automatic deployment** triggers on:
- Push to `main` branch (when `bots/` or `bootstrap.sh` changes)
- Manual trigger via GitHub Actions UI
- Repository dispatch events

**Manual deployment** on your server:
```bash
./bootstrap.sh
```

## Adding a New Bot

1. Create the bot type directory:
   ```bash
   mkdir -p bots/my-new-bot
   ```

2. Add an `.env` file for each subreddit:
   ```bash
   cp bots/example-bot/subreddit-name.env.example bots/my-new-bot/targetsubreddit.env
   # Edit the file with your credentials
   ```

3. Commit and push (or run `./bootstrap.sh` locally)

## Managing Running Bots

```bash
# View running bot containers
docker ps --filter "name=reddit-"

# View logs for a specific bot
docker logs reddit-reminder-bot-askreddit

# Stop all bots
docker ps -q --filter "name=reddit-" | xargs docker stop

# Restart deployment
./bootstrap.sh
```

## Security Notes

- `.env` files are gitignored and should never be committed
- Keep your `.env` files backed up securely outside of git
- The self-hosted runner should be on a trusted network
- Consider using Docker secrets for production deployments

## Troubleshooting

**Runner not picking up jobs:**
```bash
# Check runner status
sudo ./svc.sh status

# View runner logs
journalctl -u actions.runner.*
```

**Docker permission denied:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Bot not starting:**
```bash
# Check if .env file exists
ls -la bots/{bot-type}/{subreddit}.env

# Check Docker logs
docker logs reddit-{bot-type}-{subreddit}
```

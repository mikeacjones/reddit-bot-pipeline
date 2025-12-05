# Reddit Bot Pipeline - Self-Hosted

A self-hosted deployment pipeline for Reddit bots using GitHub Actions and Docker.

## Architecture

```
GitHub Repository
       │
       ▼ (push to main / manual trigger)
GitHub Actions Runner (Docker container)
       │
       ▼ (via mounted Docker socket)
Your Home Server / NAS
       │
       ├── Clones bot repositories
       ├── Copies .env files
       └── Runs bot Docker containers
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
├── docker-compose.yml             # GitHub Actions runner setup
├── bootstrap.sh                   # Main deployment script
└── .github/workflows/deploy.yml   # GitHub Actions workflow
```

## Quick Start

### 1. Clone the Repository on Your Server

```bash
git clone https://github.com/YOUR_USERNAME/reddit-bot-pipeline.git
cd reddit-bot-pipeline
```

### 2. Set Up the GitHub Actions Runner

The runner runs as a Docker container and can deploy other containers to your host.

#### Get a GitHub Token

You need a Personal Access Token (PAT) with `repo` scope:

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name like "NAS Runner"
4. Select the `repo` scope (full control of private repositories)
5. Generate and copy the token

#### Configure and Start the Runner

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your values
nano .env  # or vim, or your preferred editor
```

Fill in your `.env`:
```
REPO_URL=https://github.com/YOUR_USERNAME/reddit-bot-pipeline
ACCESS_TOKEN=ghp_your_token_here
RUNNER_NAME=nas-runner
```

Start the runner:
```bash
docker compose up -d
```

Verify it's running:
```bash
# Check container status
docker compose logs -f

# You should see "Listening for Jobs" when ready
```

The runner will automatically register with GitHub. You can verify at:
GitHub → Your Repo → Settings → Actions → Runners

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

## Managing Services

### Runner Management

```bash
# View runner logs
docker compose logs -f

# Restart the runner
docker compose restart

# Stop the runner
docker compose down

# Update runner to latest version
docker compose pull && docker compose up -d
```

### Bot Management

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
- The runner container has access to the Docker socket (required for deployments)
- Use this setup only on trusted networks (home/internal)
- Consider using a fine-grained PAT with minimal permissions

## Troubleshooting

**Runner not appearing in GitHub:**
```bash
# Check runner logs
docker compose logs github-runner

# Verify token is correct in .env
# Make sure REPO_URL matches your repository exactly
```

**Runner container keeps restarting:**
```bash
# Check for errors
docker compose logs --tail 50

# Common issues:
# - Invalid token (expired or wrong scope)
# - Wrong REPO_URL
# - Runner name already in use
```

**Bots not deploying:**
```bash
# Check if .env files exist in bots/ directory
ls -la bots/*/

# Run bootstrap manually to see errors
./bootstrap.sh
```

**Docker socket permission denied:**
```bash
# The runner container needs access to /var/run/docker.sock
# On some systems, you may need to adjust permissions:
sudo chmod 666 /var/run/docker.sock

# Or add the container to the docker group (handled automatically by the image)
```

**NAS-specific issues:**

If running on Synology, QNAP, or similar:
- Ensure Docker/Container Manager is installed
- Use the terminal/SSH, not the GUI for docker compose
- Check that the Docker socket path is correct (usually `/var/run/docker.sock`)

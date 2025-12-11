# Slack CLI

A powerful, lightweight command-line interface for Slack built with pure bash. No Node.js or Python dependencies required - just bash, curl, and python3.

## Features

- 📨 **Send messages** to channels or DMs
- 📅 **Schedule messages** for later delivery
- 📖 **Read channel history** and search messages
- 😊 **React** to messages with emojis
- 👥 **Manage channels** (create, archive, invite, leave)
- 📁 **File management** (list, delete)
- 🔍 **Search** across your workspace
- 💬 **Direct messages** support
- 🔐 **Secure token storage** (uses `~/.slack_token` with proper permissions)

## Installation

### Quick Install (One Command)

```bash
curl -fsSL https://raw.githubusercontent.com/nitaiaharoni1/slack-cli/main/install.sh | bash
```

### Using Homebrew

```bash
brew tap nitaiaharoni1/slack-cli
brew install slack-cli
```

That's it! Homebrew automatically handles the `homebrew-` prefix.

After installation, add to your shell config (`~/.zshrc` or `~/.bashrc`):
```bash
source $(brew --prefix)/bin/slack
```

Then reload your shell: `source ~/.zshrc`

### Manual Installation

1. Download the script:
```bash
curl -o slack-cli.sh https://raw.githubusercontent.com/nitaiaharoni1/slack-cli/main/slack-cli.sh
```

2. Make it executable:
```bash
chmod +x slack-cli.sh
```

3. Move to a directory in your PATH:
```bash
mkdir -p ~/.local/bin
mv slack-cli.sh ~/.local/bin/slack-cli.sh
```

4. Add to your shell configuration (`~/.zshrc` or `~/.bashrc`):
```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/.local/bin/slack-cli.sh
```

5. Reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Setup

### 1. Get a Slack Token

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Create a new app or select an existing one
3. Go to **OAuth & Permissions**
4. Under **User Token Scopes**, add the following scopes:
   - `channels:read` - View basic information about public channels
   - `channels:history` - View messages in public channels
   - `channels:write` - Manage public channels
   - `chat:write` - Send messages
   - `im:read` - View direct messages
   - `im:write` - Send direct messages
   - `users:read` - View people in workspace
   - `users:read.email` - View email addresses
   - `reactions:write` - Add reactions
   - `reactions:read` - View reactions
   - `files:read` - View files
   - `files:write` - Delete files
   - `search:read` - Search workspace
   - `bookmarks:read` - View bookmarks
   - (Add more as needed)

5. Install the app to your workspace
6. Copy your **User OAuth Token** (starts with `xoxp-`)

### 2. Store Your Token Securely

```bash
echo 'xoxp-your-token-here' > ~/.slack_token
chmod 600 ~/.slack_token
```

## Usage

### Basic Commands

```bash
# Show your user info
slack me

# List all channels
slack channels

# Send a message
slack send '#general' 'Hello from CLI!'

# Read messages from a channel
slack read '#general' 20

# Send a direct message
slack dm 'user@example.com' 'Hello!'

# Schedule a message
slack schedule '#general' 'in 1 hour' 'Reminder message'

# Add a reaction
slack react '#general' last ':thumbsup:'

# Search messages
slack search 'deployment'
```

### Channel Management

```bash
# Create a channel
slack create-channel 'dev-team'

# Archive a channel
slack archive '#old-channel'

# Invite a user
slack invite '#general' 'user@example.com'

# Leave a channel
slack leave '#channel'
```

### Advanced Features

```bash
# Use channel IDs directly
slack send 'C1234567890' 'Message'

# Schedule DMs
slack schedule 'user@example.com' 'in 1 hour' 'Scheduled DM'

# Remove reactions
slack unreact '#general' last ':thumbsup:'

# Delete scheduled messages
slack delete-scheduled '#general' 'Q1234567890'

# List files
slack files '#general'

# Delete files
slack delete-file 'F1234567890'
```

## Examples

### Quick Note to Self

```bash
slack dm me 'Remember to deploy at 3pm'
```

### Schedule a Standup Reminder

```bash
slack schedule '#team-standup' 'tomorrow 9:00' 'Daily standup starts in 5 minutes!'
```

### React to Last Message

```bash
slack react '#general' last ':white_check_mark:'
```

### Search for Recent Mentions

```bash
slack search '@yourname'
```

## Requirements

- Bash 4.0+
- curl
- python3
- macOS or Linux

## Troubleshooting

### "Channel not found" errors

- Make sure you're using the correct channel name (without `#` prefix is fine)
- Check that your token has the required scopes
- Try using the channel ID directly

### "missing_scope" errors

- Add the required scope in your Slack app settings
- Reinstall the app to your workspace to get a new token with updated scopes

### Token not found

- Ensure `~/.slack_token` exists and has correct permissions (`chmod 600`)
- Or set `SLACK_TOKEN` environment variable

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Created by [Nitai Aharoni](https://github.com/nitaiaharoni)

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/nitaiaharoni/slack-cli/issues) page.


# Installation Guide

## Quick Install (Homebrew)

```bash
brew tap nitaiaharoni1/slack-cli
brew install slack-cli
```

After installation, add to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
source $(brew --prefix)/bin/slack
```

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Manual Installation

1. Download the script:
```bash
curl -o slack-cli.sh https://raw.githubusercontent.com/nitaiaharoni1/slack-cli/main/slack-cli.sh
chmod +x slack-cli.sh
```

2. Move to a directory in your PATH:
```bash
mkdir -p ~/.local/bin
mv slack-cli.sh ~/.local/bin/slack-cli.sh
```

3. Add to your shell config:
```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/.local/bin/slack-cli.sh
```

4. Reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

## Setup Slack Token

1. Get a token from https://api.slack.com/apps
2. Store it securely:
```bash
echo 'xoxp-your-token-here' > ~/.slack_token
chmod 600 ~/.slack_token
```

See [README.md](README.md) for detailed setup instructions.

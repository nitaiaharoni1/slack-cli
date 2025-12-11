#!/bin/bash
# Simple installer for Slack CLI

set -e

echo "🚀 Installing Slack CLI..."

# Install via Homebrew if available
if command -v brew &> /dev/null; then
    echo "📦 Installing via Homebrew..."
    brew tap nitaiaharoni1/slack-cli
    brew install slack-cli
    
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Add to your shell config (~/.zshrc or ~/.bashrc):"
    echo "   source \$(brew --prefix)/bin/slack"
    echo ""
    echo "2. Get a Slack token from https://api.slack.com/apps"
    echo "3. Store it: echo 'xoxp-your-token' > ~/.slack_token && chmod 600 ~/.slack_token"
    echo ""
    echo "Then use: slack help"
else
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi


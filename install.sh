#!/bin/bash
# Simple installer for Slack CLI

set -e

echo "🚀 Installing Slack CLI..."

# Install via Homebrew if available
if command -v brew &> /dev/null; then
    echo "📦 Installing via Homebrew..."
    brew tap nitaiaharoni1/slack-cli
    brew install --formula nitaiaharoni1/slack-cli/slack-cli
    
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Add to your shell config (~/.zshrc or ~/.bashrc):"
    echo "   source \$(brew --prefix)/bin/slack-chat"
    echo ""
    echo "2. Reload your shell: source ~/.zshrc"
    echo "3. Run setup: slack-chat init"
    echo ""
    echo "Note: This installs as 'slack-chat' to coexist with official Slack CLI."
    echo "      Use 'slack-chat' instead of 'slack' to avoid conflicts."
else
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi


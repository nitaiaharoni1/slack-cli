# Homebrew formula for Slack CLI
# This file should be placed in: homebrew-slack-cli/Formula/slack-cli.rb
# Or in your tap: homebrew-slack-cli/slack-cli.rb

class SlackCli < Formula
  desc "Powerful command-line interface for Slack built with pure bash"
  homepage "https://github.com/nitaiaharoni1/slack-cli"
  url "https://github.com/nitaiaharoni1/slack-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "ee71d5c974ccdc72a8cb1808135476ea077d42af8e1253ee0dce459f051e779a"
  license "MIT"
  head "https://github.com/nitaiaharoni1/slack-cli.git", branch: "main"

  depends_on "bash" => :build
  depends_on "curl"
  depends_on "python3"

  def install
    bin.install "slack-cli.sh" => "slack"
    # Make sure the script is executable
    chmod 0755, bin/"slack"
  end

  def caveats
    <<~EOS
      Slack CLI has been installed!

      To get started:
      1. Get a Slack token from https://api.slack.com/apps
      2. Store it securely:
         echo 'xoxp-your-token' > ~/.slack_token
         chmod 600 ~/.slack_token
      3. Add to your shell config (~/.zshrc or ~/.bashrc):
         source #{HOMEBREW_PREFIX}/bin/slack
      4. Reload your shell: source ~/.zshrc

      Then use: slack help
    EOS
  end

  test do
    # Test that the script exists and is executable
    assert_match "Slack CLI", shell_output("#{bin}/slack help 2>&1", 1)
  end
end


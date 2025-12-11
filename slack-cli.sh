#!/bin/bash
# Slack CLI - Unified command interface
# Version: 1.0.0
# Usage: slackchat <action> [arguments]

# Load token from secure file or environment variable
if [ -z "$SLACK_TOKEN" ]; then
    if [ -f ~/.slack_token ]; then
        export SLACK_TOKEN=$(cat ~/.slack_token)
    elif [ -f ~/.slack/credentials.json ]; then
        export SLACK_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.slack/credentials.json')).get('token', ''))" 2>/dev/null || echo "")
    fi
fi

# Check if token is set
_check_token() {
    if [ -z "$SLACK_TOKEN" ]; then
        echo "❌ Error: SLACK_TOKEN not set"
        echo "Store it in: ~/.slack_token"
        return 1
    fi
}

# Get channel ID by name or ID
_get_channel_id() {
    local channel_input="$1"
    
    # If it's already a channel ID (starts with C), return it directly
    if [[ "$channel_input" =~ ^C[A-Z0-9]+$ ]]; then
        echo "$channel_input"
        return 0
    fi
    
    # Remove # prefix if present
    local channel_name=$(echo "$channel_input" | sed 's/^#//')
    
    # First, try to find in channels list (including archived)
    local channel_id=$(curl -s -X GET "https://slack.com/api/conversations.list?types=public_channel,private_channel&exclude_archived=false" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    for ch in data.get('channels', []):
        if ch.get('name') == '$channel_name':
            print(ch.get('id'))
            break
")
    
    # If found, return it
    if [ -n "$channel_id" ]; then
        echo "$channel_id"
        return 0
    fi
    
    # If not found in list, try conversations.info API (for newly created channels)
    channel_id=$(curl -s -X GET "https://slack.com/api/conversations.info?channel=$channel_name" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    ch = data.get('channel', {})
    print(ch.get('id', ''))
")
    
    if [ -n "$channel_id" ]; then
        echo "$channel_id"
        return 0
    fi
    
    # Return empty if not found
    return 1
}

# Main slackchat command
slackchat() {
    local action="${1:-help}"
    shift || true
    
    case "$action" in
        # User info
        me|whoami|info)
            _check_token || return 1
            curl -s -X GET "https://slack.com/api/auth.test" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"👤 User: {data.get('user')} ({data.get('user_id')})\")
    print(f\"🏢 Team: {data.get('team')} ({data.get('team_id')})\")
    print(f\"🌐 URL: {data.get('url')}\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # Setup/Initialize
        init|setup|configure)
            echo "🔧 Slack CLI Setup"
            echo ""
            
            # Check if token already exists
            if [ -f ~/.slack_token ]; then
                echo "✅ Token file found at ~/.slack_token"
                echo ""
                read -p "Do you want to update it? (y/N): " update_token
                if [ "$update_token" != "y" ] && [ "$update_token" != "Y" ]; then
                    echo "Keeping existing token."
                    echo ""
                    echo "Testing current token..."
                    export SLACK_TOKEN=$(cat ~/.slack_token)
                    curl -s -X GET "https://slack.com/api/auth.test" \
                        -H "Authorization: Bearer $SLACK_TOKEN" \
                        2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Token is valid!\")
    print(f\"   User: {data.get('user')}\")
    print(f\"   Team: {data.get('team')}\")
else:
    print(f\"❌ Token is invalid: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
" && echo "" && echo "Setup complete! You can now use: slackchat help"
                    return 0
                fi
            fi
            
            echo "To use Slack CLI, you need a User OAuth Token."
            echo ""
            echo "📋 Steps to get your token:"
            echo ""
            echo "1. Go to: https://api.slack.com/apps"
            echo "2. Create a new app or select an existing one"
            echo "3. Go to 'OAuth & Permissions'"
            echo "4. Under 'User Token Scopes', add these scopes:"
            echo "   - channels:read"
            echo "   - channels:history"
            echo "   - channels:write"
            echo "   - chat:write"
            echo "   - im:read"
            echo "   - im:write"
            echo "   - users:read"
            echo "   - users:read.email"
            echo "   - reactions:write"
            echo "   - reactions:read"
            echo "   - files:read"
            echo "   - files:write"
            echo "   - search:read"
            echo "   - bookmarks:read"
            echo "5. Install the app to your workspace"
            echo "6. Copy your 'User OAuth Token' (starts with xoxp-)"
            echo ""
            read -p "Paste your token here: " user_token
            
            if [ -z "$user_token" ]; then
                echo "❌ No token provided. Setup cancelled."
                return 1
            fi
            
            # Validate token format
            if [[ ! "$user_token" =~ ^xoxp- ]]; then
                echo "❌ Invalid token format. Token should start with 'xoxp-'"
                echo "   Make sure you're using a User OAuth Token, not a Bot Token."
                return 1
            fi
            
            # Store token securely
            echo "$user_token" > ~/.slack_token
            chmod 600 ~/.slack_token
            echo ""
            echo "✅ Token stored securely at ~/.slack_token"
            
            # Test the token
            echo ""
            echo "🧪 Testing token..."
            export SLACK_TOKEN="$user_token"
            curl -s -X GET "https://slack.com/api/auth.test" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Token is valid!\")
    print(f\"   User: {data.get('user')}\")
    print(f\"   Team: {data.get('team')}\")
    print(f\"   URL: {data.get('url')}\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Token validation failed: {error}\")
    if 'invalid_auth' in error.lower():
        print(f\"💡 Make sure you copied the full token correctly\")
    elif 'missing_scope' in error.lower():
        print(f\"💡 Make sure you added all required scopes and reinstalled the app\")
    sys.exit(1)
"
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "🎉 Setup complete!"
                echo ""
                echo "Next steps:"
                echo "  1. Make sure your shell config (~/.zshrc or ~/.bashrc) includes:"
                echo "     source \$(brew --prefix)/bin/slack"
                echo ""
                echo "  2. Reload your shell: source ~/.zshrc"
                echo ""
                echo "  3. Try: slackchat help"
            else
                echo ""
                echo "⚠️  Token stored but validation failed. Please check the error above."
                return 1
            fi
            ;;
        
        # List channels
        channels|list|ls)
            _check_token || return 1
            curl -s -X GET "https://slack.com/api/conversations.list?types=public_channel,private_channel" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    channels = data.get('channels', [])
    print(f'📋 Channels ({len(channels)}):\\n')
    for ch in sorted(channels, key=lambda x: x.get('num_members', 0), reverse=True):
        name = ch.get('name', '')
        is_private = ch.get('is_private', False)
        members = ch.get('num_members', 0)
        prefix = '🔒' if is_private else '#'
        print(f'  {prefix}{name:<30} {members:>4} members')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # Send message
        send|post|msg)
            _check_token || return 1
            local channel="${1}"
            local message="${*:2}"
            
            if [ -z "$channel" ] || [ -z "$message" ]; then
                echo "Usage: slackchat send <channel> <message>"
                echo "Example: slackchat send '#general' 'Hello from CLI!'"
                echo "Example: slackchat send 'C1234567890' 'Hello!'  (channel ID)"
                return 1
            fi
            
            channel_input=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel_input")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '$channel' not found"
                return 1
            fi
            
            # Get channel name for display (if it's not an ID)
            if [[ "$channel_input" =~ ^C[A-Z0-9]+$ ]]; then
                channel_display="$channel_input"
            else
                channel_display="#$channel_input"
            fi
            
            curl -s -X POST https://slack.com/api/chat.postMessage \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"text\": \"$message\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Message sent to $channel_display\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # Schedule message for later
        schedule|schedule-message|send-later|later)
            _check_token || return 1
            local target="${1}"
            local post_at="${2}"
            local message="${*:3}"
            
            if [ -z "$target" ] || [ -z "$post_at" ] || [ -z "$message" ]; then
                echo "Usage: slackchat schedule <channel-or-user> <time> <message>"
                echo ""
                echo "Time formats:"
                echo "  Unix timestamp: slack schedule '#general' 1733947200 'Hello!'"
                echo "  Relative time:  slack schedule '#general' 'in 1 hour' 'Hello!'"
                echo "  Date string:    slack schedule '#general' '2024-12-12 14:30' 'Hello!'"
                echo ""
                echo "Examples:"
                echo "  slack schedule '#general' 'in 30 minutes' 'Reminder: Meeting starts soon'"
                echo "  slack schedule 'user@example.com' 'in 1 hour' 'Scheduled DM'"
                echo "  slack schedule '#general' '2024-12-12 14:30' 'Scheduled announcement'"
                echo "  slack schedule 'nitai.aharoni@clanz.io' 'in 1 minute' 'Test message'"
                return 1
            fi
            
            # Parse time first (needed for both channels and DMs)
            post_at_ts=$(python3 -c "
import sys
from datetime import datetime, timedelta
import re

time_str = '$post_at'

# Check if it's already a Unix timestamp
if time_str.isdigit() and len(time_str) == 10:
    print(time_str)
    sys.exit(0)

# Check for relative time (e.g., 'in 1 hour', 'in 30 minutes')
relative_match = re.match(r'in\s+(\d+)\s+(minute|minutes|hour|hours|day|days)', time_str.lower())
if relative_match:
    amount = int(relative_match.group(1))
    unit = relative_match.group(2).rstrip('s')
    now = datetime.now()
    if unit == 'minute':
        future = now + timedelta(minutes=amount)
    elif unit == 'hour':
        future = now + timedelta(hours=amount)
    elif unit == 'day':
        future = now + timedelta(days=amount)
    print(int(future.timestamp()))
    sys.exit(0)

# Try parsing as date string
try:
    formats = [
        '%Y-%m-%d %H:%M',
        '%Y-%m-%d %H:%M:%S',
        '%Y/%m/%d %H:%M',
        '%m/%d/%Y %H:%M',
        '%d/%m/%Y %H:%M',
    ]
    for fmt in formats:
        try:
            dt = datetime.strptime(time_str, fmt)
            print(int(dt.timestamp()))
            sys.exit(0)
        except ValueError:
            continue
except:
    pass

print('ERROR: Invalid time format', file=sys.stderr)
sys.exit(1)
" 2>&1)
            
            if [ $? -ne 0 ] || [ -z "$post_at_ts" ]; then
                echo "❌ Error: Could not parse time '$post_at'"
                echo "Use Unix timestamp, 'in X minutes/hours/days', or date string"
                return 1
            fi
            
            # Check if time is in the past
            current_ts=$(date +%s)
            if [ "$post_at_ts" -lt "$current_ts" ]; then
                echo "❌ Error: Scheduled time is in the past"
                return 1
            fi
            
            # Check if target is a user (email or user ID) or a channel
            if echo "$target" | grep -q "@" || [ "${target#\#}" = "$target" ]; then
                # It's a user (email or user ID)
                user_id=$(curl -s -X GET "https://slack.com/api/users.list" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    for u in data.get('members', []):
        if u.get('id') == '$target' or u.get('profile', {}).get('email') == '$target':
            print(u.get('id'))
            break
")
                
                if [ -z "$user_id" ]; then
                    echo "❌ User '$target' not found"
                    return 1
                fi
                
                # Open or get DM channel
                channel_id=$(curl -s -X POST https://slack.com/api/conversations.open \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"users\": \"$user_id\"}" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(data.get('channel', {}).get('id', ''))
else:
    error = data.get('error', 'Unknown error')
    print(f'ERROR: {error}', file=sys.stderr)
    print('')
")
                
                if [ -z "$channel_id" ]; then
                    echo "❌ Could not open DM channel"
                    echo "💡 Make sure your token has 'im:write' scope"
                    return 1
                fi
                
                target_display="$target"
            else
                # It's a channel
                channel=$(echo "$target" | sed 's/^#//')
                channel_id=$(_get_channel_id "$channel")
                
                if [ -z "$channel_id" ]; then
                    echo "❌ Channel '#$channel' not found"
                    return 1
                fi
                
                target_display="#$channel"
            fi
            
            curl -s -X POST https://slack.com/api/chat.scheduleMessage \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"text\": \"$message\", \"post_at\": $post_at_ts}" \
                2>/dev/null | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
if data.get('ok'):
    scheduled_message = data.get('scheduled_message_id', '')
    post_at = data.get('post_at', 0)
    post_time = datetime.fromtimestamp(post_at).strftime('%Y-%m-%d %H:%M:%S')
    print(f\"✅ Message scheduled for $target_display\")
    print(f\"   Scheduled ID: {scheduled_message}\")
    print(f\"   Will post at: {post_time}\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'invalid_time' in error.lower():
        print(\"💡 Tip: Scheduled time must be at least 1 minute in the future\")
    sys.exit(1)
"
            ;;
        
        # Read messages
        read|messages|msgs)
            _check_token || return 1
            local channel="${1}"
            local limit="${2:-10}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat read <channel> [limit]"
                echo "Example: slackchat read '#general' 20"
                echo "Example: slackchat read general 20  (auto-detects #)"
                return 1
            fi
            
            # Auto-detect if # is missing
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            # Get user list for name resolution
            users_json=$(curl -s -X GET "https://slack.com/api/users.list" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null)
            
            curl -s -X GET "https://slack.com/api/conversations.history?channel=$channel_id&limit=$limit" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
from datetime import datetime

users_data = json.loads('''$users_json''')
users_map = {}
if users_data.get('ok'):
    for u in users_data.get('members', []):
        users_map[u.get('id')] = u.get('real_name') or u.get('name', u.get('id'))

data = json.load(sys.stdin)
if data.get('ok'):
    messages = data.get('messages', [])
    print(f'💬 Last {len(messages)} messages in #$channel:\\n')
    for msg in reversed(messages):
        user_id = msg.get('user', 'Unknown')
        user_name = users_map.get(user_id, user_id)
        text = msg.get('text', '')
        ts = float(msg.get('ts', 0))
        time = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
        print(f'[{time}] <{user_name}> {text}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # Search messages
        search|find)
            _check_token || return 1
            local query="${*}"
            
            if [ -z "$query" ]; then
                echo "Usage: slackchat search <query>"
                echo "Example: slackchat search 'deployment'"
                return 1
            fi
            
            curl -s -X GET "https://slack.com/api/search.messages?query=${query// /%20}" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
if data.get('ok'):
    matches = data.get('messages', {}).get('matches', [])
    print(f'🔍 Found {len(matches)} results for \"$query\":\\n')
    for msg in matches[:20]:
        user = msg.get('username', 'Unknown')
        text = msg.get('text', '')
        channel = msg.get('channel', {}).get('name', 'unknown')
        ts = float(msg.get('ts', 0))
        time = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
        print(f'[{time}] #$channel <$user>')
        print(f'  {text[:100]}...' if len(text) > 100 else f'  {text}')
        print()
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # Add reaction
        react|emoji)
            _check_token || return 1
            local channel="${1}"
            local timestamp="${2}"
            local emoji="${3}"
            
            if [ -z "$channel" ] || [ -z "$timestamp" ] || [ -z "$emoji" ]; then
                echo "Usage: slackchat react <channel> <timestamp|last|index> <emoji>"
                echo "Examples:"
                echo "  slack react '#general' '1234567890.123456' ':+1:'"
                echo "  slack react '#general' last ':thumbsup:'"
                echo "  slack react '#general' 1 ':thumbsup:'  (react to 1st most recent)"
                echo "  slack react '#general' last ':thumbsup:'"
                echo "  slack react '#general' 1 ':thumbsup:'  (react to 1st most recent message)"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            # Handle "last" shortcut or numeric index
            if [ "$timestamp" = "last" ] || [[ "$timestamp" =~ ^[0-9]+$ ]]; then
                # Get the most recent message(s)
                local index=${timestamp:-1}
                if [ "$timestamp" = "last" ]; then
                    index=1
                fi
                
                timestamp=$(curl -s -X GET "https://slack.com/api/conversations.history?channel=$channel_id&limit=$index" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    messages = data.get('messages', [])
    if len(messages) >= $index:
        print(messages[$index - 1].get('ts', ''))
    else:
        print('')
else:
    print('')
")
                
                if [ -z "$timestamp" ]; then
                    echo "❌ Could not find message"
                    return 1
                fi
            fi
            
            # Remove colons if present
            emoji=$(echo "$emoji" | sed 's/^://' | sed 's/:$//')
            
            curl -s -X POST https://slack.com/api/reactions.add \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"timestamp\": \"$timestamp\", \"name\": \"$emoji\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Added :$emoji: reaction\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # Set status/presence
        status|presence)
            _check_token || return 1
            local presence="${1:-auto}"
            
            if [ "$presence" != "auto" ] && [ "$presence" != "away" ]; then
                echo "Usage: slackchat status [auto|away]"
                echo "Example: slackchat status away"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/users.setPresence \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"presence\": \"$presence\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Status set to: $presence\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # List users
        users|members)
            _check_token || return 1
            curl -s -X GET "https://slack.com/api/users.list" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    members = data.get('members', [])
    print(f'👥 Users ({len(members)}):\\n')
    for user in sorted(members, key=lambda x: x.get('real_name', x.get('name', ''))):
        name = user.get('real_name') or user.get('name', 'Unknown')
        email = user.get('profile', {}).get('email', '')
        status = user.get('presence', 'unknown')
        status_icon = '🟢' if status == 'active' else '⚪'
        print(f'  {status_icon} {name:<30} {email}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # Get channel info
        channel|info)
            _check_token || return 1
            local channel="${1}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat channel <channel-name>"
                echo "Example: slackchat channel '#general'"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            
            curl -s -X GET "https://slack.com/api/conversations.info?channel=$channel" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    ch = data.get('channel', {})
    print(f\"� channel: #{ch.get('name')}\")
    print(f\"   ID: {ch.get('id')}\")
    print(f\"   Members: {ch.get('num_members', 0)}\")
    print(f\"   Private: {'Yes' if ch.get('is_private') else 'No'}\")
    print(f\"   Topic: {ch.get('topic', {}).get('value', 'None')}\")
    print(f\"   Purpose: {ch.get('purpose', {}).get('value', 'None')}\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
"
            ;;
        
        # Help
        help|--help|-h)
            cat << EOF
Slack CLI - Unified command interface

USAGE:
  slack <action> [arguments]

ACTIONS:
  init, setup, configure     Initial setup and token configuration
  dm, direct, message        Send direct message
  dms, directs               List direct messages
  read-dm, dm-read           Read direct messages
  files, file-list           List files (optionally in channel)
  bookmarks, bookmark        List bookmarks in channel
  user, profile              Show user profile
  create-channel, mkchannel  Create new channel
  archive, delete-channel    Archive/delete channel
  unarchive, restore-channel Unarchive channel
  leave, part                Leave a channel
  invite, inv                Invite user to channel
  me, whoami, info          Show your user information
  channels, list, ls         List all channels
  send, post, msg           Send a message to a channel
  schedule, send-later      Schedule a message for later
  delete-scheduled, unschedule Delete scheduled message
  read, messages, msgs       Read messages from a channel
  search, find              Search messages in workspace
  react, emoji              Add emoji reaction to a message
  unreact, remove-reaction   Remove emoji reaction
  status, presence          Set your presence (auto/away)
  users, members            List workspace users
  channel, info             Get channel information
  delete-file, rmfile       Delete a file
  help                      Show this help message

EXAMPLES:
  slack init                 Run initial setup
  slack setup                Configure your Slack token
  slack dm user@example.com 'Hello!'
  slack dm me 'Note to self'
  slack dms
  slack read-dm user@example.com
  slack read-dm me
  slack files
  slack files '#general'
  slack bookmarks '#general'
  slack user user@example.com
  slack create-channel 'dev-team'
  slack invite '#general' user@example.com
  slack me
  slack channels
  slack send '#general' 'Hello from CLI!'
  slack schedule '#general' 'in 1 hour' 'Reminder message'
  slack schedule 'user@example.com' 'in 1 hour' 'Scheduled DM'
  slack schedule '#general' '2024-12-12 14:30' 'Scheduled announcement'
  slack read '#general' 20
  slack read general 20  (auto-detects #)
  slack search 'deployment'
  slack react '#general' last ':thumbsup:'
  slack react '#general' 1 ':thumbsup:'  (react to 1st most recent)
  slack unreact '#general' last ':thumbsup:'
  slack status away
  slack users
  slack channel '#general'
  slack archive '#old-channel'
  slack unarchive '#old-channel'
  slack leave '#channel'
  slack delete-scheduled '#general' 'Q1234567890'
  slack delete-file 'F1234567890'

TOKEN:
  Token is automatically loaded from ~/.slack_token
  No need to export SLACK_TOKEN manually

For more details: slackchat help <action>
EOF
            ;;
        
        # Direct Messages
        dm|direct|message)
            _check_token || return 1
            local user="${1}"
            local message="${*:2}"
            
            if [ -z "$user" ] || [ -z "$message" ]; then
                echo "Usage: slackchat dm <user-email-or-id|me> <message>"
                echo "Example: slackchat dm 'user@example.com' 'Hello!'"
                echo "Example: slackchat dm me 'Note to self'"
                return 1
            fi
            
            # Handle "me" or "self" shortcut
            if [ "$user" = "me" ] || [ "$user" = "self" ]; then
                user_id=$(curl -s -X GET "https://slack.com/api/auth.test" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(data.get('user_id', ''))
")
            else
                # Get user ID if email provided
                user_id=$(curl -s -X GET "https://slack.com/api/users.list" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    for u in data.get('members', []):
        if u.get('id') == '$user' or u.get('profile', {}).get('email') == '$user':
            print(u.get('id'))
            break
")
            fi
            
            if [ -z "$user_id" ]; then
                echo "❌ User '$user' not found"
                return 1
            fi
            
            # Open or get DM channel
            channel_id=$(curl -s -X POST https://slack.com/api/conversations.open \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"users\": \"$user_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(data.get('channel', {}).get('id', ''))
else:
    error = data.get('error', 'Unknown error')
    print(f'ERROR: {error}', file=sys.stderr)
    print('')
")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Could not open DM channel (check error above)"
                echo "💡 Make sure your token has 'im:write' scope"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/chat.postMessage \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"text\": \"$message\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ DM sent to $user\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # List DMs
        dms|directs)
            _check_token || return 1
            curl -s -X GET "https://slack.com/api/conversations.list?types=im" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    dms = data.get('channels', [])
    print(f'💬 Direct Messages ({len(dms)}):\\n')
    for dm in dms:
        user_id = dm.get('user', '')
        unread = dm.get('unread_count', 0)
        unread_str = f' ({unread} unread)' if unread > 0 else ''
        print(f'  👤 {user_id}{unread_str}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # Read DM
        read-dm|dm-read)
            _check_token || return 1
            local user="${1}"
            local limit="${2:-10}"
            
            if [ -z "$user" ]; then
                echo "Usage: slackchat read-dm <user-email-or-id|me> [limit]"
                echo "Example: slackchat read-dm 'user@example.com' 20"
                echo "Example: slackchat read-dm me 20"
                return 1
            fi
            
            # Handle "me" or "self" shortcut
            if [ "$user" = "me" ] || [ "$user" = "self" ]; then
                user_id=$(curl -s -X GET "https://slack.com/api/auth.test" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(data.get('user_id', ''))
")
            else
                # Get user ID
                user_id=$(curl -s -X GET "https://slack.com/api/users.list" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    for u in data.get('members', []):
        if u.get('id') == '$user' or u.get('profile', {}).get('email') == '$user':
            print(u.get('id'))
            break
")
            fi
            
            if [ -z "$user_id" ]; then
                echo "❌ User '$user' not found"
                return 1
            fi
            
            # Get user list for name resolution
            users_json=$(curl -s -X GET "https://slack.com/api/users.list" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null)
            
            # Get DM channel
            channel_id=$(curl -s -X POST https://slack.com/api/conversations.open \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"users\": \"$user_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(data.get('channel', {}).get('id', ''))
else:
    error = data.get('error', 'Unknown error')
    print(f'ERROR: {error}', file=sys.stderr)
    print('')
")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Could not open DM channel (check error above)"
                echo "💡 Make sure your token has 'im:read' scope"
                return 1
            fi
            
            curl -s -X GET "https://slack.com/api/conversations.history?channel=$channel_id&limit=$limit" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
from datetime import datetime

users_data = json.loads('''$users_json''')
users_map = {}
if users_data.get('ok'):
    for u in users_data.get('members', []):
        users_map[u.get('id')] = u.get('real_name') or u.get('name', u.get('id'))

data = json.load(sys.stdin)
if data.get('ok'):
    messages = data.get('messages', [])
    print(f'💬 Last {len(messages)} messages with $user:\\n')
    for msg in reversed(messages):
        user_id_msg = msg.get('user', 'Unknown')
        user_name = users_map.get(user_id_msg, user_id_msg)
        text = msg.get('text', '')
        ts = float(msg.get('ts', 0))
        time = datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
        print(f'[{time}] <{user_name}> {text}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # List files
        files|file-list)
            _check_token || return 1
            local channel="${1}"
            local limit="${2:-20}"
            
            if [ -z "$channel" ]; then
                # List all files
                curl -s -X GET "https://slack.com/api/files.list?count=$limit" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
if data.get('ok'):
    files = data.get('files', [])
    print(f'📁 Files ({len(files)}):\\n')
    for f in files:
        name = f.get('name', 'Unknown')
        size = f.get('size', 0)
        size_kb = size / 1024
        user = f.get('user', 'Unknown')
        ts = float(f.get('created', 0))
        time = datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
        url = f.get('url_private', '')
        print(f'  📄 {name:<40} {size_kb:.1f}KB  {time}  by {user}')
        if url:
            print(f'      {url}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            else
                # List files in channel
                channel=$(echo "$channel" | sed 's/^#//')
                channel_id=$(_get_channel_id "$channel")
                
                if [ -z "$channel_id" ]; then
                    echo "❌ Channel '#$channel' not found"
                    return 1
                fi
                
                curl -s -X GET "https://slack.com/api/files.list?channel=$channel_id&count=$limit" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
if data.get('ok'):
    files = data.get('files', [])
    print(f'📁 Files in #$channel ({len(files)}):\\n')
    for f in files:
        name = f.get('name', 'Unknown')
        size = f.get('size', 0)
        size_kb = size / 1024
        user = f.get('user', 'Unknown')
        ts = float(f.get('created', 0))
        time = datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
        url = f.get('url_private', '')
        print(f'  📄 {name:<40} {size_kb:.1f}KB  {time}  by {user}')
        if url:
            print(f'      {url}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            fi
            ;;
        
        # List bookmarks
        bookmarks|bookmark)
            _check_token || return 1
            local channel="${1}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat bookmarks <channel>"
                echo "Example: slackchat bookmarks '#general'"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            curl -s -X GET "https://slack.com/api/bookmarks.list?channel_id=$channel_id" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    bookmarks = data.get('bookmarks', [])
    print(f'🔖 Bookmarks in #$channel ({len(bookmarks)}):\\n')
    for bm in bookmarks:
        title = bm.get('title', 'Untitled')
        link = bm.get('link', '')
        emoji = bm.get('emoji', '')
        print(f'  {emoji} {title}')
        if link:
            print(f'      {link}')
else:
    print(f'❌ Error: {data.get(\"error\", \"Unknown error\")}')
"
            ;;
        
        # User profile
        user|profile)
            _check_token || return 1
            local user="${1}"
            
            if [ -z "$user" ]; then
                echo "Usage: slackchat user <user-email-or-id>"
                echo "Example: slackchat user 'user@example.com'"
                return 1
            fi
            
            curl -s -X GET "https://slack.com/api/users.list" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    found = False
    for u in data.get('members', []):
        if u.get('id') == '$user' or u.get('profile', {}).get('email') == '$user':
            found = True
            profile = u.get('profile', {})
            print(f\"👤 User: {u.get('real_name') or u.get('name', 'Unknown')}\")
            print(f\"   ID: {u.get('id')}\")
            print(f\"   Email: {profile.get('email', 'N/A')}\")
            print(f\"   Title: {profile.get('title', 'N/A')}\")
            print(f\"   Phone: {profile.get('phone', 'N/A')}\")
            print(f\"   Status: {profile.get('status_text', 'N/A')}\")
            print(f\"   Presence: {u.get('presence', 'unknown')}\")
            print(f\"   Timezone: {u.get('tz', 'N/A')}\")
            break
    if not found:
        print(f\"❌ User '$user' not found\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
"
            ;;
        
        # Create channel
        create-channel|mkchannel|mkch)
            _check_token || return 1
            local channel_name="${1}"
            local is_private="${2:-false}"
            
            if [ -z "$channel_name" ]; then
                echo "Usage: slackchat create-channel <name> [private]"
                echo "Example: slackchat create-channel 'dev-team'"
                echo "Example: slackchat create-channel 'secret-stuff' private"
                return 1
            fi
            
            channel_name=$(echo "$channel_name" | sed 's/^#//')
            
            if [ "$is_private" = "private" ]; then
                endpoint="conversations.create"
                data="{\"name\": \"$channel_name\", \"is_private\": true}"
            else
                endpoint="conversations.create"
                data="{\"name\": \"$channel_name\"}"
            fi
            
            curl -s -X POST "https://slack.com/api/$endpoint" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$data" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    ch = data.get('channel', {})
    prefix = '🔒' if ch.get('is_private') else '#'
    print(f\"✅ Created channel: {prefix}{ch.get('name')}\")
    print(f\"   ID: {ch.get('id')}\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # Invite user to channel
        invite|inv)
            _check_token || return 1
            local channel="${1}"
            local user="${2}"
            
            if [ -z "$channel" ] || [ -z "$user" ]; then
                echo "Usage: slackchat invite <channel> <user-email-or-id>"
                echo "Example: slackchat invite '#general' 'user@example.com'"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            # Get user ID
            user_id=$(curl -s -X GET "https://slack.com/api/users.list" \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    for u in data.get('members', []):
        if u.get('id') == '$user' or u.get('profile', {}).get('email') == '$user':
            print(u.get('id'))
            break
")
            
            if [ -z "$user_id" ]; then
                echo "❌ User '$user' not found"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/conversations.invite \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"users\": \"$user_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Invited $user to #$channel\")
else:
    print(f\"❌ Error: {data.get('error', 'Unknown error')}\")
    sys.exit(1)
"
            ;;
        
        # Archive/delete channel
        archive|delete-channel|rmchannel|rmch)
            _check_token || return 1
            local channel="${1}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat archive <channel>"
                echo "Example: slackchat archive '#general'"
                echo "Example: slackchat archive general  (auto-detects #)"
                echo ""
                echo "Note: This archives the channel (hides it from channel list)"
                echo "      Slack doesn't support permanent deletion via API"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/conversations.archive \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Channel '#$channel' archived successfully\")
    print(f\"   Note: Channel is hidden but can be unarchived if needed\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'already_archived' in error.lower():
        print(f\"💡 Channel '#$channel' is already archived\")
    elif 'cant_archive_general' in error.lower():
        print(f\"💡 Cannot archive the #general channel\")
    elif 'not_authorized' in error.lower() or 'missing_scope' in error.lower():
        print(f\"💡 Make sure your token has 'channels:write' scope\")
    sys.exit(1)
"
            ;;
        
        # Unarchive channel
        unarchive|restore-channel)
            _check_token || return 1
            local channel="${1}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat unarchive <channel>"
                echo "Example: slackchat unarchive '#general'"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/conversations.unarchive \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Channel '#$channel' unarchived successfully\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'not_archived' in error.lower():
        print(f\"💡 Channel '#$channel' is not archived\")
    sys.exit(1)
"
            ;;
        
        # Delete scheduled message
        delete-scheduled|unschedule|cancel-scheduled)
            _check_token || return 1
            local channel="${1}"
            local scheduled_message_id="${2}"
            
            if [ -z "$channel" ] || [ -z "$scheduled_message_id" ]; then
                echo "Usage: slackchat delete-scheduled <channel> <scheduled-message-id>"
                echo "Example: slackchat delete-scheduled '#general' 'Q1234567890'"
                echo ""
                echo "To find scheduled message IDs, check the output when scheduling"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/chat.deleteScheduledMessage \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"scheduled_message_id\": \"$scheduled_message_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Scheduled message deleted from #$channel\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'invalid_scheduled_message_id' in error.lower():
        print(f\"💡 Scheduled message ID not found or invalid\")
    sys.exit(1)
"
            ;;
        
        # Remove reaction
        unreact|remove-reaction|remove-emoji)
            _check_token || return 1
            local channel="${1}"
            local timestamp="${2}"
            local emoji="${3}"
            
            if [ -z "$channel" ] || [ -z "$timestamp" ] || [ -z "$emoji" ]; then
                echo "Usage: slackchat unreact <channel> <timestamp|last|index> <emoji>"
                echo "Examples:"
                echo "  slack unreact '#general' '1234567890.123456' ':+1:'"
                echo "  slack unreact '#general' last ':thumbsup:'"
                echo "  slack unreact '#general' 1 ':thumbsup:'  (remove from 1st most recent)"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            # Handle "last" shortcut or numeric index
            if [ "$timestamp" = "last" ] || [[ "$timestamp" =~ ^[0-9]+$ ]]; then
                local index=${timestamp:-1}
                if [ "$timestamp" = "last" ]; then
                    index=1
                fi
                
                timestamp=$(curl -s -X GET "https://slack.com/api/conversations.history?channel=$channel_id&limit=$index" \
                    -H "Authorization: Bearer $SLACK_TOKEN" \
                    2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    messages = data.get('messages', [])
    if len(messages) >= $index:
        print(messages[$index - 1].get('ts', ''))
    else:
        print('')
else:
    print('')
")
                
                if [ -z "$timestamp" ]; then
                    echo "❌ Could not find message"
                    return 1
                fi
            fi
            
            # Remove colons if present
            emoji=$(echo "$emoji" | sed 's/^://' | sed 's/:$//')
            
            curl -s -X POST https://slack.com/api/reactions.remove \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\", \"timestamp\": \"$timestamp\", \"name\": \"$emoji\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Removed :$emoji: reaction\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'no_reaction' in error.lower():
        print(f\"💡 No :$emoji: reaction found on this message\")
    sys.exit(1)
"
            ;;
        
        # Delete file
        delete-file|rmfile|rm)
            _check_token || return 1
            local file_id="${1}"
            
            if [ -z "$file_id" ]; then
                echo "Usage: slackchat delete-file <file-id>"
                echo "Example: slackchat delete-file 'F1234567890'"
                echo ""
                echo "To find file IDs, use: slack files"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/files.delete \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"file\": \"$file_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ File deleted successfully\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'file_not_found' in error.lower() or 'file_deleted' in error.lower():
        print(f\"💡 File not found or already deleted\")
    elif 'not_authorized' in error.lower() or 'missing_scope' in error.lower():
        print(f\"💡 Make sure your token has 'files:write' scope\")
    sys.exit(1)
"
            ;;
        
        # Leave channel
        leave|part)
            _check_token || return 1
            local channel="${1}"
            
            if [ -z "$channel" ]; then
                echo "Usage: slackchat leave <channel>"
                echo "Example: slackchat leave '#general'"
                echo "Example: slackchat leave general  (auto-detects #)"
                return 1
            fi
            
            channel=$(echo "$channel" | sed 's/^#//')
            channel_id=$(_get_channel_id "$channel")
            
            if [ -z "$channel_id" ]; then
                echo "❌ Channel '#$channel' not found"
                return 1
            fi
            
            curl -s -X POST https://slack.com/api/conversations.leave \
                -H "Authorization: Bearer $SLACK_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"channel\": \"$channel_id\"}" \
                2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('ok'):
    print(f\"✅ Left channel '#$channel'\")
else:
    error = data.get('error', 'Unknown error')
    print(f\"❌ Error: {error}\")
    if 'cant_leave_general' in error.lower():
        print(f\"💡 Cannot leave the #general channel\")
    elif 'not_in_channel' in error.lower():
        print(f\"💡 You are not a member of '#$channel'\")
    sys.exit(1)
"
            ;;
        
        *)
            echo "Unknown action: $action"
            echo "Run 'slackchat help' for available commands"
            return 1
            ;;
    esac
}

# Export the function
export -f slackchat

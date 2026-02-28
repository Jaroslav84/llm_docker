#!/bin/bash

# Strip iTerm2-specific environment variables to prevent interference
unset ITERM2_SHELL_INTEGRATION_INSTALLED
unset ITERM2_SHELL_INTEGRATION_ENABLED
unset ITERM2_SHELL_INTEGRATION_PREVIOUS_PROMPT
unset ITERM2_PREV_PS1
unset ITERM2_SHELL_PREV_PS2

# Ensure proper terminal setup for mouse reporting and scrolling
# Set TERMINFO path for ncurses-term package
export TERMINFO=/usr/share/terminfo
export TERMINFO_DIRS=/usr/share/terminfo

# Set TERM if not already set (fallback to xterm-256color)
export TERM=${TERM:-xterm-256color}

# Ensure terminal size is set
if [ -z "$COLUMNS" ] || [ -z "$LINES" ]; then
    # Try to get terminal size from stty if available
    if command -v stty > /dev/null 2>&1; then
        TERM_SIZE=$(stty size 2>/dev/null || echo "24 80")
        LINES=${LINES:-$(echo $TERM_SIZE | cut -d' ' -f1)}
        COLUMNS=${COLUMNS:-$(echo $TERM_SIZE | cut -d' ' -f2)}
        export LINES COLUMNS
    fi
fi

# Handle internet access restriction if INTERNET_ACCESS=false
if [ "${INTERNET_ACCESS:-true}" = "false" ]; then
    echo "Internet access disabled - blocking internet but allowing LAN access..."
    
    # Check if we're in host network mode (would affect host system)
    # In host mode, container shares host network namespace, so iptables affects host
    if [ -f /proc/self/ns/net ] && [ -e /proc/1/ns/net ]; then
        HOST_NS=$(readlink /proc/1/ns/net 2>/dev/null || echo "")
        SELF_NS=$(readlink /proc/self/ns/net 2>/dev/null || echo "")
        if [ "$HOST_NS" = "$SELF_NS" ] && [ -n "$HOST_NS" ]; then
            echo "Warning: Running in host network mode. Internet blocking will affect the host system."
            echo "For container-only blocking, use bridge network mode in docker-compose.yml"
        fi
    fi
    
    # Check if iptables is available
    if command -v iptables > /dev/null 2>&1; then
        # Flush existing OUTPUT rules (if any) - be careful in host mode!
        iptables -F OUTPUT 2>/dev/null || true
        
        # Allow private IP ranges (LAN) - these are local network addresses
        iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -d 169.254.0.0/16 -j ACCEPT 2>/dev/null || true  # Link-local
        
        # Allow established connections
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
        
        # Block all other outbound traffic (internet)
        iptables -A OUTPUT -j DROP 2>/dev/null || true
        
        echo "Internet access blocked. LAN access (10.x.x.x, 172.16-31.x.x, 192.168.x.x) allowed."
    else
        echo "Warning: iptables not available. Cannot block internet access."
        echo "Note: Internet blocking requires bridge network mode (not host mode) to work properly."
    fi
fi

# Determine which tool to run (default to opencode for backward compatibility)
TOOL=${TOOL:-opencode}

if [ "$TOOL" = "opencode" ]; then
    # Apply OpenCode config file if it exists
    if [ -f /tmp/opencode.config.jsonc ]; then
        echo "Applying OpenCode configuration..."
        mkdir -p /root/.config/opencode
        cp /tmp/opencode.config.jsonc /root/.config/opencode/config.json
        echo "Configuration applied to /root/.config/opencode/config.json"
    fi

    # API keys are read from environment variables (OPENAI_API_KEY, ZAI_API_KEY)
    # These are automatically loaded from .env file via docker-compose.yml

    # Run OpenCode
    if [ $# -gt 0 ]; then
        echo "Starting OpenCode with arguments: $@"
    else
        echo "Starting OpenCode..."
    fi
    opencode "$@"
    exit $?

elif [ "$TOOL" = "claude" ]; then
    # Handle Claude data persistence
    # If /root_claude exists (from docker-compose.yml mount), symlink it to /root
    # This allows Claude Code to use /root while keeping data separate from OpenCode
    if [ -d "/root_claude" ] && [ ! -L "/root_claude" ]; then
        # Backup existing /root if it exists and isn't already a symlink
        if [ -d "/root" ] && [ ! -L "/root" ] && [ "$(ls -A /root 2>/dev/null)" ]; then
            echo "Warning: /root contains data. Moving to /root_backup..."
            mv /root /root_backup 2>/dev/null || true
        fi
        # Create symlink from /root_claude to /root
        if [ ! -e "/root" ]; then
            ln -sf /root_claude /root
            echo "Linked /root_claude to /root for Claude Code"
        fi
    fi
    
    # Ensure Claude config directory exists
    mkdir -p /root/.config/claude 2>/dev/null || true
    mkdir -p /root/.claude 2>/dev/null || true

    # Check if we should be verbose (default: quiet, only show errors)
    # Set VERBOSE=true or NODE_ENV=development to enable verbose output
    VERBOSE=${VERBOSE:-false}
    if [ "${NODE_ENV:-production}" = "development" ]; then
        VERBOSE=true
    fi

    # Ensure ANTHROPIC_API_KEY is exported (in case it wasn't already)
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        export ANTHROPIC_API_KEY
        
        if [ "$VERBOSE" = "true" ]; then
            echo "ANTHROPIC_API_KEY is set (length: ${#ANTHROPIC_API_KEY} chars)"
            echo "Configuring Claude Code to use API key authentication..."
        fi
        
        # Remove OAuth token cache if it exists
        rm -f /root/.config/claude/token.json 2>/dev/null || true
        rm -f /root/.config/claude/auth.json 2>/dev/null || true
        rm -rf /root/.config/claude/oauth 2>/dev/null || true
        
        # Create settings.json to skip OAuth wizard
        cat > /root/.claude/settings.json <<EOF
{
  "hasCompletedOnboarding": true,
  "hasTrustDialogAccepted": true,
  "hasCompletedProjectOnboarding": true
}
EOF
        
        # Also create .claude.json for older compatibility
        cat > /root/.claude.json <<EOF
{
  "hasCompletedOnboarding": true,
  "hasTrustDialogAccepted": true,
  "hasCompletedProjectOnboarding": true
}
EOF
        
        if [ "$VERBOSE" = "true" ]; then
            echo "Claude Code configured to use API key authentication"
        fi
    else
        # Always show warnings/errors
        echo "Warning: ANTHROPIC_API_KEY not set. Claude Code will use OAuth authentication."
    fi

    # API keys are read from environment variables (ANTHROPIC_API_KEY)
    # These are automatically loaded from .env file via docker-compose.yml or docker run

    # Run Claude Code (suppress startup message unless verbose)
    if [ "$VERBOSE" = "true" ]; then
        if [ $# -gt 0 ]; then
            echo "Starting Claude Code with arguments: $@"
        else
            echo "Starting Claude Code..."
        fi
    fi
    claude "$@"
    exit $?

else
    echo "Error: Unknown TOOL value: $TOOL. Valid values are 'opencode' or 'claude'."
    exit 1
fi


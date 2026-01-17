#!/bin/bash

# ==========================================
# Auto Start Script (Daemon Mode)
# - Connects/Reconnects VPN
# - Updates IP/Port via vpn_manager.py
# - Restarts Backend if it crashes
# ==========================================

# NOTE: Run this script as a REGULAR USER (not root/sudo)!
# The Official ProtonVPN App uses your desktop session (DBus).
if [ "$EUID" -eq 0 ]; then
   echo "⚠️  Please run as your normal user (./auto_start.sh)"
   echo "   Running as root causes DBus errors with the official app."
   echo "   Use 'exit' to logout of sudo if needed, then run it."
   exit 1
fi

echo "� Starting Autonomous Server System..."

# Define Paths
PYTHON_BIN="./venv/bin/python"

# System VPN Command
PROTON_CMD="protonvpn"

echo "Using Proton Command: $PROTON_CMD"

while true; do
    echo "------------------------------------------------"
    date
    
    # 1. CHECK VPN CONNECTIVITY
    # Check for 'proton0' or 'tun0' interface or check public IP?
    # The new CLI doesn't have a 'status' command.
    # We'll check if the proton interface exists.
    STATUS=$(ip -o link show | grep -iE "proton|tun")
    
    if [ -z "$STATUS" ]; then
        echo "❌ VPN Disconnected. Attempting to connect..."
        
        # Attempt connection (Blocking)
        # Official CLI v0.1.3 uses just 'connect' (defaults to fastest)
        $PROTON_CMD connect
        
        if [ $? -eq 0 ]; then
            echo "✅ VPN Connected!"
            sleep 10 # Allow network to stabilize
        else
            echo "❌ VPN Connection Failed. Retrying in 10s..."
            sleep 10
            continue
        fi
    else
        echo "✅ VPN Status: Connected"
    fi
    
    # 2. UPDATE CONFIGURATION (IP/Port/DuckDNS)
    # run with --no-input to skip manual prompts
    # We run this as the invoking user (SUDO_USER) if possible, OR as root.
    # Running as root for vpn_manager is fine.
    
    echo "�️  Checking Network Configuration..."
    $PYTHON_BIN vpn_manager.py --no-input
    
    # 3. BACKEND MANAGEMENT
    # The user wants to run the backend manually.
    # We will NOT start it here, but we can check if it's running for info.
    
    if pgrep -f "python main.py" > /dev/null; then
        echo "✅ Backend is RUNNING (Managed manually)"
    else
        echo "⚠️  Backend is STOPPED. Run './venv/bin/python main.py' to start it."
    fi
    # 4. SLEEP
    # Wait before next check loop
    echo "💤 Sleeping for 60 seconds..."
    sleep 60
done

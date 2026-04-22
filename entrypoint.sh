#!/bin/bash
set -e

# Default directories
CONFIG_DIR="/etc/asterisk"
SAMPLE_DIR="/var/lib/asterisk/sample-config"
LOG_DIR="/var/log/asterisk"
SPOOL_DIR="/var/spool/asterisk"
MOH_DIR="/var/lib/asterisk/moh"
SOUNDS_DIR="/var/lib/asterisk/sounds"

# Check if the config directory is empty (common on first mount)
if [ -z "$(ls -A $CONFIG_DIR)" ]; then
    echo "Initializing configuration directory with samples..."
    cp -rv $SAMPLE_DIR/* $CONFIG_DIR/
fi

# Ensure MOH directory exists and has default files
echo "Ensuring MOH directory exists..."
mkdir -p $MOH_DIR
chown -R asterisk:asterisk $MOH_DIR

# Check if MOH files exist, if not, create a default one from sounds
if [ -z "$(ls -A $MOH_DIR 2>/dev/null)" ]; then
    echo "WARNING: No MOH files found. Attempting to create default..."
    # Copy any sound file as fallback MOH
    if [ -f "$SOUNDS_DIR/en/hello-world.gsm" ]; then
        cp "$SOUNDS_DIR/en/hello-world.gsm" "$MOH_DIR/default"
        echo "Created default MOH from hello-world.gsm"
    elif [ -f "$SOUNDS_DIR/en/vm-intro.gsm" ]; then
        cp "$SOUNDS_DIR/en/vm-intro.gsm" "$MOH_DIR/default"
        echo "Created default MOH from vm-intro.gsm"
    else
        echo "CRITICAL: No sound files found at all in $SOUNDS_DIR"
        ls -la $SOUNDS_DIR/ || echo "Sound directory missing or empty"
    fi
fi

# Ensure correct ownership at runtime
echo "Ensuring file permissions..."
chown -R asterisk:asterisk $CONFIG_DIR $LOG_DIR $SPOOL_DIR /var/lib/asterisk /var/run/asterisk 2>/dev/null || true

# Ensure shared library cache is up to date
ldconfig

# For network_mode: host, we need to ensure RTP ports are accessible
echo "Checking network configuration..."
if [ -f /proc/sys/net/ipv4/ip_local_port_range ]; then
    echo "System RTP port range: $(cat /proc/sys/net/ipv4/ip_local_port_range)"
fi

# Start Asterisk
# Note: For host network mode, you might need to run as root for certain operations
# But Asterisk will drop privileges after binding to ports
echo "Starting Asterisk..."

# Check if we need to run as root for host network
if [ "$(id -u)" = "0" ]; then
    echo "Running as root (required for host network mode)"
    # Run as root but let Asterisk drop to asterisk user after binding
    exec asterisk -f -vvv -c
else
    echo "Running as user 'asterisk'"
    exec asterisk -f -vvv -c -U asterisk -G asterisk
fi

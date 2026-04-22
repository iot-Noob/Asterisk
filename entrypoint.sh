#!/bin/bash
set -e

# Default directories
CONFIG_DIR="/etc/asterisk"
SAMPLE_DIR="/var/lib/asterisk/sample-config"
LOG_DIR="/var/log/asterisk"
SPOOL_DIR="/var/spool/asterisk"

# Check if the config directory is empty (common on first mount)
if [ -z "$(ls -A $CONFIG_DIR)" ]; then
    echo "Initializing configuration directory with samples..."
    cp -rv $SAMPLE_DIR/* $CONFIG_DIR/
fi

# Ensure correct ownership at runtime (important for volume mounts)
echo "Ensuring file permissions..."
chown -R asterisk:asterisk $CONFIG_DIR $LOG_DIR $SPOOL_DIR /var/lib/asterisk /var/run/asterisk

# Ensure shared library cache is up to date
ldconfig

# Hand over to Asterisk
echo "Starting Asterisk as user 'asterisk'..."
exec asterisk -f -vvv -c -U asterisk -G asterisk

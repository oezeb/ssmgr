#!/bin/bash

CONFIG="$PWD/ssmgr.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
else
    echo "Configuration file not found: $CONFIG"
    exit 1
fi

echo "==== $(date) ====" >> "$LOG_FILE"

while IFS=',' read -r port user; do
    bytes=$(iptables -L $CHAIN_NAME -v -x -n | grep ":$port" | awk '{sum+=$2} END {print sum}')
    mb=$((bytes / 1024 / 1024))

    echo "$user on port $port used ${mb}MB" >> "$LOG_FILE"

    if (( mb > LIMIT_MB )); then
        echo "$user (port $port) exceeds $LIMIT_MB MB — blocking..." >> "$LOG_FILE"
        iptables -C INPUT -p tcp --dport $port -j REJECT 2>/dev/null || \
            iptables -A INPUT -p tcp --dport $port -j REJECT
    fi
done < "$USER_FILE"

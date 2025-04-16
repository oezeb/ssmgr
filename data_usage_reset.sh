#!/bin/bash

CONFIG="$PWD/ssmgr.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
else
    echo "Configuration file not found: $CONFIG"
    exit 1
fi

iptables -F $CHAIN_NAME

while IFS=',' read -r port user; do
    iptables -D INPUT -p tcp --dport $port -j REJECT 2>/dev/null
done < "$USER_FILE"

echo "Shadowsocks usage reset at $(date)" >> /var/log/data_usage.log

#!/bin/bash

CONFIG="$PWD/ssmgr.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
else
    echo "Configuration file not found: $CONFIG"
    exit 1
fi

mkdir -p "$CONFIG_DIR" "$PID_DIR" "$LOG_DIR"
touch "$USER_FILE"

ensure_chain_exists() {
    iptables -L $CHAIN_NAME -n &>/dev/null || iptables -N $CHAIN_NAME
}

gen_password() {
    head -c 12 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16
}

ss_stop() {
    local port=$1
    local pidfile="$PID_DIR/$port.pid"

    if [[ -f "$pidfile" ]]; then
        kill "$(cat $pidfile)" 2>/dev/null
        rm -f "$pidfile"
        echo "Stopped ss-server on port $port"
    fi
}

ss_restart() {
    local port=$1
    local config="$CONFIG_DIR/$port.json"
    local pidfile="$PID_DIR/$port.pid"

    ss_stop "$port"
    echo "Starting Shadowsocks on port $port"
    nohup $SS_BIN --fast-open --no-delay -c "$config" -f "$pidfile" > "$LOG_DIR/$port.log" 2>&1 &
}

ss_start() {
    local port=$1
    local password=$2
    local config="$CONFIG_DIR/$port.json"
    local pidfile="$PID_DIR/$port.pid"

    cat > "$config" <<EOF
{
    "server": "0.0.0.0",
    "server_port": $port,
    "password": "$password",
    "timeout": 300,
    "method":"chacha20-ietf-poly1305",
    "plugin":"obfs-server",
    "plugin_opts":"obfs=tls"
}
EOF

    ss_restart "$port"
}

ss_status() {
    local port=$1
    local pidfile="$PID_DIR/$port.pid"

    if [[ -f "$pidfile" ]]; then
        local pid=$(cat "$pidfile")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "\033[0;32mss-server running on port $port (PID $pid)\033[0m"
            return
        else
            echo -e "\033[0;31mss-server on port $port has stale PID file (not running)\033[0m"
            return 1
        fi
    else
        echo -e "\033[0;31mss-server not running on port $port\033[0m"
        return 1
    fi
}

add_user() {
    ensure_chain_exists

    local port=$1
    local user=$2
    local password=$3

    if [[ -z "$port" || -z "$user" ]]; then
        echo "Usage: $0 add <port> <username> [password]"
        return 1
    fi

    if grep -q "^$port," "$USER_FILE"; then
        echo "Port $port already assigned. Remove it first."
        return
    fi

    [[ -z "$password" ]] && password=$(gen_password)

    echo "$port,$user,$password" >> "$USER_FILE"
    echo "Added user $user with password $password on port $port"

    iptables -C INPUT  -p tcp --dport $port -j $CHAIN_NAME 2>/dev/null || iptables -A INPUT  -p tcp --dport $port -j $CHAIN_NAME
    iptables -C OUTPUT -p tcp --sport $port -j $CHAIN_NAME 2>/dev/null || iptables -A OUTPUT -p tcp --sport $port -j $CHAIN_NAME

    ss_start "$port" "$password"
}

remove_user() {
    ensure_chain_exists

    local port=$1
    
    if [[ -z "$port" ]]; then
        echo "Usage: $0 remove <port>"
        return 1
    fi

    ss_stop "$port"
    sed -i "/^$port,/d" "$USER_FILE"

    iptables -D INPUT  -p tcp --dport $port -j $CHAIN_NAME 2>/dev/null
    iptables -D OUTPUT -p tcp --sport $port -j $CHAIN_NAME 2>/dev/null
    iptables -D INPUT  -p tcp --dport $port -j REJECT 2>/dev/null

    rm -f "$CONFIG_DIR/$port.json"
    echo "Removed user on port $port"
}

update_iptables() {
    ensure_chain_exists

    for port in $(awk -F',' '{print $1}' "$USER_FILE"); do
        iptables -D INPUT  -p tcp --dport $port -j $CHAIN_NAME 2>/dev/null
        iptables -D OUTPUT -p tcp --sport $port -j $CHAIN_NAME 2>/dev/null
    done

    while IFS=',' read -r port user password; do
        iptables -C INPUT  -p tcp --dport $port -j $CHAIN_NAME 2>/dev/null || \
            iptables -A INPUT  -p tcp --dport $port -j $CHAIN_NAME
        iptables -C OUTPUT -p tcp --sport $port -j $CHAIN_NAME 2>/dev/null || \
            iptables -A OUTPUT -p tcp --sport $port -j $CHAIN_NAME
    done < "$USER_FILE"

    echo "iptables updated"
}

list_users() {
    echo -e "PORT\tUSER\t\tPASSWORD\t\tUSAGE (MB)"
    echo "------------------------------------------------------------"

    while IFS=',' read -r port user password; do
        # Sum inbound + outbound bytes for this port from SS_TRAFFIC chain
        bytes=$(iptables -L $CHAIN_NAME -v -x -n | grep ":$port" | awk '{sum+=$2} END {print sum}')
        mb=$((bytes / 1024 / 1024))
        printf "%-6s\t%-10s\t%-16s\t%6s MB\n" "$port" "$user" "$password" "$mb"
    done < "$USER_FILE"
}

print_help() {
    echo "Usage:"
    echo "  $0 add <port> <username> [password]    # Add user (gen password if missing)"
    echo "  $0 remove <port>                       # Remove user"
    echo "  $0 update                              # Re-sync iptables"
    echo "  $0 list                                # Show users"
    echo "  $0 server <port> <status|stop|restart> # manage server"
}

case "$1" in
    add) add_user "$2" "$3" "$4" ;;
    remove) remove_user "$2" ;;
    update) update_iptables ;;
    list) list_users ;;
    server)
    case "$3" in
        status) ss_status "$2" ;;
        stop) ss_stop "$2" ;;
        restart) ss_restart "$2" ;;
        *)
            echo "Usage: $0 server <port> <status|stop|restart>"
            ;;
    esac
    ;;
    *) print_help ;;
esac

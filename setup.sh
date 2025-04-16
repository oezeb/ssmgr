#!/bin/bash

apt-get update && apt-get install -y shadowsocks-libev simple-obfs iptables

chmod +x ./ssmgr.sh
chmod +x ./ssmgr.conf
chmod +x ./data_usage_limit.sh
chmod +x ./data_usage_reset.sh
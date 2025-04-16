From ubuntu:24.04

WORKDIR ssmgr

COPY ./ssmgr.sh /ssmgr/ssmgr.sh
COPY ./ssmgr.conf /ssmgr/ssmgr.conf
COPY ./data_usage_limit.sh /ssmgr/data_usage_limit.sh
COPY ./data_usage_reset.sh /ssmgr/data_usage_reset.sh

RUN apt-get update && apt-get install -y shadowsocks-libev simple-obfs iptables

RUN chmod +x /ssmgr/ssmgr.sh
RUN chmod +x /ssmgr/ssmgr.conf
RUN chmod +x /ssmgr/data_usage_limit.sh
RUN chmod +x /ssmgr/data_usage_reset.sh

# docker build -t ssmgr .
# docker run -it --rm ssmgr
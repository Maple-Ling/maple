#!/bin/bash

==========================================

PT Seedbox 一键优化脚本 (简化版可用)

支持：

- 内存分级优化 (<=1G / 1-4G / >4G)

- 系统网络优化 (BT专用)

- 磁盘检测与路径选择

- 安装 qBittorrent (Docker / nox)

==========================================

set -e

---------- 工具函数 ----------

function green(){ echo -e "\033[32m$1\033[0m"; } function red(){ echo -e "\033[31m$1\033[0m"; } function yellow(){ echo -e "\033[33m$1\033[0m"; }

---------- 获取内存 ----------

mem_total=$(free -m | awk '/Mem:/ {print $2}')

if [ "$mem_total" -le 1024 ]; then profile="low" elif [ "$mem_total" -le 4096 ]; then profile="mid" else profile="high" fi

green "检测到内存: ${mem_total}MB -> 使用配置: ${profile}"

---------- 系统优化 ----------

function apply_sysctl(){ cat > /etc/sysctl.d/99-pt.conf <<EOF net.core.default_qdisc=fq net.ipv4.tcp_congestion_control=bbr

通用

net.core.somaxconn=8192 net.core.netdev_max_backlog=16384

BT核心

net.ipv4.ip_local_port_range=10000 65535 net.ipv4.tcp_fin_timeout=10 net.ipv4.tcp_tw_reuse=1 net.ipv4.tcp_max_tw_buckets=262144 net.ipv4.tcp_max_orphans=65536

conntrack

net.netfilter.nf_conntrack_max=1048576 net.netfilter.nf_conntrack_tcp_timeout_established=1200 EOF

if [ "$profile" == "low" ]; then

cat >> /etc/sysctl.d/99-pt.conf <<EOF net.core.rmem_max=8388608 net.core.wmem_max=8388608 EOF

elif [ "$profile" == "mid" ]; then

cat >> /etc/sysctl.d/99-pt.conf <<EOF net.core.rmem_max=16777216 net.core.wmem_max=16777216 EOF

else

cat >> /etc/sysctl.d/99-pt.conf <<EOF net.core.rmem_max=33554432 net.core.wmem_max=33554432 EOF fi

sysctl --system
green "系统参数优化完成"

}

---------- 磁盘检测 ----------

function choose_disk(){ disks=$(lsblk -dpno NAME,SIZE | grep -v loop) echo "可用磁盘:" echo "$disks" read -p "输入要使用的磁盘路径 (如 /dev/vda): " disk

mountpoint="/pt"
mkdir -p $mountpoint

if ! mount | grep -q $mountpoint; then
    mount $disk $mountpoint || true
fi

green "使用路径: $mountpoint"

}

---------- 安装 Docker ----------

function install_docker(){ if ! command -v docker &> /dev/null; then curl -fsSL https://get.docker.com | bash systemctl enable docker systemctl start docker green "Docker 安装完成" fi }

---------- 安装 qB (Docker) ----------

function install_qb_docker(){ install_docker

docker run -d \
--name qbittorrent \
-p 8080:8080 \
-p 6881:6881 \
-p 6881:6881/udp \
-v /pt:/downloads \
-v /root/qb:/config \
linuxserver/qbittorrent

green "qBittorrent Docker 安装完成"

}

---------- 安装 qB nox ----------

function install_qb_nox(){ apt update apt install -y qbittorrent-nox

useradd -m qb || true

cat > /etc/systemd/system/qbittorrent.service <<EOF

[Unit] Description=qBittorrent After=network.target

[Service] User=root ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080 Restart=always

[Install] WantedBy=multi-user.target EOF

systemctl daemon-reexec
systemctl enable qbittorrent
systemctl start qbittorrent

green "qBittorrent nox 安装完成"

}

---------- qB 配置优化 ----------

function optimize_qb(){ conf="/root/.config/qBittorrent/qBittorrent.conf" mkdir -p $(dirname $conf)

cat > $conf <<EOF [Preferences] Connection\GlobalDLLimitAlt=0 Connection\GlobalUPLimitAlt=0 Connection\MaxConnections=2000 Connection\MaxConnectionsPerTorrent=300 Connection\MaxUploads=200 Connection\MaxUploadsPerTorrent=50 Downloads\SavePath=/pt/ EOF

green "qB 参数优化完成"

}

---------- 主流程 ----------

apply_sysctl choose_disk

echo "选择安装方式:" echo "1. Docker版 qB" echo "2. nox版 (低内存推荐)" read -p "输入选项: " opt

if [ "$opt" == "1" ]; then install_qb_docker else install_qb_nox fi

optimize_qb

green "全部完成 ✔"
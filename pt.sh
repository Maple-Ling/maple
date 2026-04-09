#!/bin/bash

# ==========================================
# PT Seedbox 一键优化脚本
# 支持：
# - 内存分级优化
# - sysctl (BT优化)
# - 磁盘选择
# - qBittorrent (Docker / nox)
# ==========================================

set -e

# ---------- 颜色 ----------
green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

# ---------- 检查root ----------
if [ "$EUID" -ne 0 ]; then
    red "请使用 root 运行"
    exit 1
fi

# ---------- 获取内存 ----------
mem_total=$(free -m | awk '/Mem:/ {print $2}')

if [ "$mem_total" -le 1024 ]; then
    profile="low"
elif [ "$mem_total" -le 4096 ]; then
    profile="mid"
else
    profile="high"
fi

green "检测到内存: ${mem_total}MB -> 使用配置: ${profile}"

# ---------- 系统优化 ----------
apply_sysctl(){
    green "开始系统优化..."

cat > /etc/sysctl.d/99-pt.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

net.core.somaxconn=8192
net.core.netdev_max_backlog=16384

net.ipv4.ip_local_port_range=10000 65535
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_max_orphans=65536

net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_tcp_timeout_established=1200
EOF

    if [ "$profile" == "low" ]; then
cat >> /etc/sysctl.d/99-pt.conf <<EOF
net.core.rmem_max=8388608
net.core.wmem_max=8388608
EOF

    elif [ "$profile" == "mid" ]; then
cat >> /etc/sysctl.d/99-pt.conf <<EOF
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF

    else
cat >> /etc/sysctl.d/99-pt.conf <<EOF
net.core.rmem_max=33554432
net.core.wmem_max=33554432
EOF
    fi

    sysctl --system || red "sysctl 应用失败"
    green "系统优化完成"
}

# ---------- 磁盘选择 ----------
choose_disk(){
    green "检测磁盘..."

    lsblk -dpno NAME,SIZE | grep -v loop

    read -p "输入磁盘 (如 /dev/vda)，直接回车使用默认路径: " disk

    if [ -z "$disk" ]; then
        mkdir -p /pt
        path="/pt"
    else
        mkdir -p /pt
        mount "$disk" /pt 2>/dev/null || yellow "挂载失败，使用默认目录"
        path="/pt"
    fi

    green "使用路径: $path"
}

# ---------- 安装 Docker ----------
install_docker(){
    if ! command -v docker &>/dev/null; then
        green "安装 Docker..."
        curl -fsSL https://get.docker.com | bash || {
            red "Docker 安装失败"
            return
        }
        systemctl enable docker
        systemctl start docker
    else
        yellow "Docker 已安装"
    fi
}

# ---------- Docker版 qB ----------
install_qb_docker(){
    install_docker

    docker rm -f qbittorrent 2>/dev/null || true

    docker run -d \
        --name qbittorrent \
        -p 8080:8080 \
        -p 6881:6881 \
        -p 6881:6881/udp \
        -v /pt:/downloads \
        -v /root/qb:/config \
        linuxserver/qbittorrent || red "Docker qB 启动失败"

    green "Docker qB 安装完成"
}

# ---------- nox版 ----------
install_qb_nox(){
    green "安装 qBittorrent-nox..."

    apt update
    apt install -y qbittorrent-nox || {
        red "安装失败"
        return
    }

cat > /etc/systemd/system/qbittorrent.service <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl enable qbittorrent
    systemctl restart qbittorrent

    green "nox 启动完成"
}

# ---------- qB 优化 ----------
optimize_qb(){
    green "写入 qB 配置..."

    conf="/root/.config/qBittorrent/qBittorrent.conf"
    mkdir -p $(dirname "$conf")

    if [ "$profile" == "low" ]; then
        max_conn=800
    elif [ "$profile" == "mid" ]; then
        max_conn=1500
    else
        max_conn=3000
    fi

cat > "$conf" <<EOF
[Preferences]
Connection\\GlobalDLLimitAlt=0
Connection\\GlobalUPLimitAlt=0
Connection\\MaxConnections=$max_conn
Connection\\MaxConnectionsPerTorrent=300
Connection\\MaxUploads=200
Connection\\MaxUploadsPerTorrent=50
Downloads\\SavePath=/pt/
EOF

    green "qB 优化完成"
}

# ---------- 主流程 ----------
apply_sysctl
choose_disk

echo "选择安装方式:"
echo "1. Docker 版 qB"
echo "2. nox 版 (低内存推荐)"
read -p "输入选项: " opt

if [ "$opt" == "1" ]; then
    install_qb_docker
else
    install_qb_nox
fi

optimize_qb

green "全部完成 ✔"
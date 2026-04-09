#!/bin/bash

# ==========================================
# PT Seedbox 一键优化脚本（完整版）
# 特性：
# - 菜单控制（不会自动执行）
# - 环境检测
# - sysctl冲突检测
# - 内存分级优化
# - 磁盘选择
# - qB 安装 + 优化
# ==========================================

# ========= 基础函数 =========

pause(){
    read -p "按回车继续..." temp
}

get_mem_level(){
    mem=$(free -m | awk '/Mem:/ {print $2}')
    if [ "$mem" -le 1024 ]; then
        level="low"
    elif [ "$mem" -le 4096 ]; then
        level="mid"
    else
        level="high"
    fi
    echo "检测内存: ${mem}MB -> 等级: $level"
}

check_sysctl_conflict(){
    echo "检测 sysctl 冲突..."
    ls /etc/sysctl.d/
    echo "⚠️ 如果存在多个优化文件，可能互相覆盖"
}

# ========= 系统优化 =========

apply_sysctl(){
    get_mem_level

    echo "写入 PT 优化配置..."

    cat > /etc/sysctl.d/99-pt.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.ipv4.tcp_rmem=4096 87380 8388608
net.ipv4.tcp_wmem=4096 65536 8388608

net.core.somaxconn=8192
net.core.netdev_max_backlog=16384

net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_tw_reuse=1

net.ipv4.ip_local_port_range=10000 65535

fs.file-max=1048576
EOF

    sysctl --system
    echo "✅ 系统优化完成"
}

# ========= 磁盘 =========

choose_disk(){
    echo "可用磁盘："
    lsblk -dpno NAME,SIZE

    read -p "输入磁盘 (如 /dev/vda): " disk

    if [ -z "$disk" ]; then
        echo "未输入，跳过"
        return
    fi

    mkdir -p /data
    mount $disk /data

    echo "✅ 已挂载到 /data"
}

# ========= qB 安装 =========

install_qb_docker(){
    echo "安装 Docker + qBittorrent..."

    apt update
    apt install -y docker.io

    docker run -d \
        --name qbittorrent \
        -e PUID=0 \
        -e PGID=0 \
        -e WEBUI_PORT=8080 \
        -p 8080:8080 \
        -p 6881:6881 \
        -p 6881:6881/udp \
        -v /data:/data \
        --restart unless-stopped \
        linuxserver/qbittorrent

    echo "✅ Docker qB 安装完成"
}

install_qb_nox(){
    echo "安装 qbittorrent-nox..."

    apt update
    apt install -y qbittorrent-nox

    qbittorrent-nox --daemon

    echo "✅ qB nox 已启动 (默认8080)"
}

# ========= qB 优化 =========

optimize_qb(){
    conf="/root/.config/qBittorrent/qBittorrent.conf"

    mkdir -p /root/.config/qBittorrent/

    cat > $conf <<EOF
[Preferences]
Connection\GlobalDLLimitAlt=0
Connection\GlobalUPLimitAlt=0
Connection\MaxConnections=1000
Connection\MaxConnectionsPerTorrent=200
Connection\MaxUploads=50
Connection\MaxUploadsPerTorrent=20
Connection\PortRangeMin=6881
Downloads\DiskWriteCacheSize=64
Downloads\PreAllocation=false
Queueing\QueueingEnabled=false
EOF

    echo "✅ qB 优化完成"
}

# ========= 一键 =========

run_all(){
    apply_sysctl
    choose_disk
    install_qb_docker
    optimize_qb
}

# ========= 主菜单 =========

main_menu(){
    clear
    echo "=============================="
    echo "   PT 刷流一键工具（完整版）"
    echo "=============================="
    echo "1. 环境检测"
    echo "2. 系统优化"
    echo "3. 磁盘挂载"
    echo "4. 安装 qB (Docker)"
    echo "5. 安装 qB (nox)"
    echo "6. qB 优化"
    echo "7. 一键全部执行"
    echo "0. 退出"
    echo "=============================="

    read -p "请选择: " num

    case "$num" in
        1)
            get_mem_level
            check_sysctl_conflict
            ;;
        2) apply_sysctl ;;
        3) choose_disk ;;
        4) install_qb_docker ;;
        5) install_qb_nox ;;
        6) optimize_qb ;;
        7) run_all ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac

    pause
    main_menu
}

main_menu
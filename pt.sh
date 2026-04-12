#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

# 颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

clear
echo "======================================"
echo " Linux 终极性能优化（智能完整版）"
echo "======================================"
echo "1. PT刷流（极限并发）"
echo "2. VLESS节点（极低延迟）"
echo "0. 退出"
echo "======================================"
read -p "请选择: " choice

# 🔍 自动选择最佳拥塞算法（不会降级）
set_best_cc() {
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    current=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)

    echo ""
    echo -e "${YELLOW}🔍 检测拥塞控制算法...${NC}"
    echo "   可用算法: $avail"
    echo "   当前算法: $current"

    if echo "$avail" | grep -q "bbr3"; then
        best="bbr3"
    elif echo "$avail" | grep -q "bbr2"; then
        best="bbr2"
    elif echo "$avail" | grep -q "bbrplus"; then
        best="bbrplus"
    elif echo "$avail" | grep -q "bbr"; then
        best="bbr"
    else
        best="cubic"
    fi

    echo -e "👉 选择算法: ${GREEN}$best${NC}"
    sysctl -w net.ipv4.tcp_congestion_control=$best >/dev/null 2>&1
}

# 🚀 PT参数
apply_pt() {
cat > $CONFIG_FILE <<EOF
# 队列 + BBR
net.core.default_qdisc=fq

# 队列优化
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535

# 端口
net.ipv4.ip_local_port_range=10000 65535

# 内存
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728

# TIME_WAIT
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=8

# conntrack（核心）
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

# BBR增强
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

# 文件
fs.file-max=4194304

# VM
vm.swappiness=5
vm.dirty_background_ratio=5
vm.dirty_ratio=20

# IPv6
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
EOF
}

# 🚀 VLESS参数
apply_vless() {
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq

net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_max_syn_backlog=20000

net.core.rmem_max=67108864
net.core.wmem_max=67108864

net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_notsent_lowat=16384

fs.file-max=1048576
vm.swappiness=10

# IPv6
net.ipv6.conf.all.disable_ipv6=0
EOF
}

# ⚙️ 可视化应用
apply_sysctl_verbose() {
    echo ""
    echo "⚙️ 应用系统参数..."
    echo "--------------------------------"

    while read line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

        key=$(echo $line | cut -d= -f1)
        val=$(echo $line | cut -d= -f2-)

        printf "👉 %-40s = %-15s" "$key" "$val"

        if sysctl -w "$key=$val" >/dev/null 2>&1; then
            echo -e " ${GREEN}✔${NC}"
        else
            echo -e " ${RED}✘${NC}"
        fi
    done < $CONFIG_FILE

    echo "--------------------------------"
}

# 🔥 文件句柄优化
optimize_limits() {
    echo ""
    echo "🔧 优化文件句柄..."

    if ! grep -q "1048576" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
EOF
        echo -e "${GREEN}✔ 已写入 limits.conf${NC}"
    else
        echo -e "${YELLOW}✔ 已存在，跳过${NC}"
    fi
}

# 🚀 NIC优化
nic_tune() {
    echo ""
    echo "🚀 网卡队列优化..."

    for i in /sys/class/net/*/queues/rx-*; do
        echo 4096 > $i/rps_flow_cnt 2>/dev/null
    done

    echo -e "${GREEN}✔ 已优化 RPS${NC}"
}

# 🔍 最终检查
final_check() {
    echo ""
    echo "🔍 最终状态："
    echo "--------------------------------"
    echo "拥塞算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo "backlog: $(sysctl -n net.core.netdev_max_backlog)"
    echo "文件句柄: $(sysctl -n fs.file-max)"
    echo "--------------------------------"
}

# 🚀 主流程
case $choice in
1)
    apply_pt
    set_best_cc
    apply_sysctl_verbose
    optimize_limits
    nic_tune
    final_check
    ;;
2)
    apply_vless
    set_best_cc
    apply_sysctl_verbose
    optimize_limits
    final_check
    ;;
0)
    exit 0
    ;;
*)
    echo "输入错误"
    ;;
esac

echo ""
echo -e "${GREEN}✔ 优化完成（建议重启）${NC}"
#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

clear
echo "======================================"
echo " Linux 终极性能优化（真·完整版）"
echo "======================================"
echo "1. PT刷流（极限并发）"
echo "2. VLESS节点（极低延迟）"
echo "0. 退出"
echo "======================================"
read -p "请选择: " choice

# 🔍 BBR检测
enable_bbr() {
    modprobe tcp_bbr 2>/dev/null
}

# 🚀 PT终极参数
apply_pt() {
cat > $CONFIG_FILE <<EOF
# 队列
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# backlog & 队列
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

# TIME_WAIT优化
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=8

# conntrack（关键）
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

# 文件句柄
fs.file-max=4194304

# VM
vm.swappiness=5
vm.dirty_background_ratio=5
vm.dirty_ratio=20

# BBR增强
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

# IPv6（重点）
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.route.max_size=16384
net.ipv6.ip6frag_high_thresh=67108864

EOF
}

# 🚀 VLESS优化
apply_vless() {
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

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

# ⚙️ 应用
apply_sysctl() {
    sysctl --system > /dev/null
}

# 🔥 ulimit强化
optimize_limits() {
cat >> /etc/security/limits.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
EOF
}

# 🚀 NIC优化（自动）
nic_tune() {
    for i in /sys/class/net/*/queues/rx-*; do
        echo 4096 > $i/rps_flow_cnt 2>/dev/null
    done
}

# 🚀 主流程
case $choice in
1)
    enable_bbr
    apply_pt
    apply_sysctl
    optimize_limits
    nic_tune
    ;;
2)
    enable_bbr
    apply_vless
    apply_sysctl
    optimize_limits
    ;;
0)
    exit
    ;;
*)
    echo "错误"
    ;;
esac

echo "✔ 完成（建议重启）"
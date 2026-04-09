#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

clear
echo "======================================"
echo "   Linux 终极优化面板（完整版）"
echo "======================================"
echo "1. PT刷流优化（高并发）"
echo "2. VLESS节点优化（低延迟）"
echo "0. 退出"
echo "======================================"
read -p "请选择: " choice

# 🚨 深度清理
deep_clean() {
    echo ""
    echo "🚨 [1/5] 开始深度清理..."

    rm -f /etc/sysctl.d/*.conf
    echo "   ✔ 已删除 /etc/sysctl.d/*"

    echo "" > /etc/sysctl.conf
    echo "   ✔ 已清空 /etc/sysctl.conf"

    echo "✔ 清理完成"
}

# 🔍 检测BBR
detect_bbr() {
    echo ""
    echo "🔍 [2/5] 检测BBR支持..."

    modprobe tcp_bbr 2>/dev/null

    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)

    echo "   可用算法: $avail"

    if echo "$avail" | grep -q "bbr"; then
        echo "✔ 支持 BBR"
    else
        echo "❌ 不支持 BBR（将跳过）"
    fi
}

# ⚙️ PT参数
apply_pt() {
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=50000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_max_tw_buckets=200000
net.ipv4.ip_local_port_range=10000 65535
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
fs.file-max=2097152
vm.swappiness=10
vm.dirty_background_bytes=67108864
vm.dirty_bytes=536870912
EOF
}

# ⚙️ VLESS参数
apply_vless() {
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_max_syn_backlog=20000
net.ipv4.ip_local_port_range=10000 65535
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 65536 33554432
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
fs.file-max=1048576
vm.swappiness=20
EOF
}

# ⚙️ 逐条应用（核心过程显示）
apply_sysctl_verbose() {
    echo ""
    echo "⚙️ [3/5] 正在应用参数..."

    while read line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

        key=$(echo $line | cut -d= -f1)
        val=$(echo $line | cut -d= -f2-)

        echo "   👉 $key = $val"
        sysctl -w "$key=$val" > /dev/null
    done < $CONFIG_FILE

    echo "✔ 参数应用完成"
}

# 📊 对比
compare_before_after() {
    echo ""
    echo "📊 [4/5] 优化结果对比"

    echo "   backlog: $(sysctl -n net.core.netdev_max_backlog)"
    echo "   somaxconn: $(sysctl -n net.core.somaxconn)"
    echo "   file-max: $(sysctl -n fs.file-max)"
}

# 🔍 最终检查
final_check() {
    echo ""
    echo "🔍 [5/5] 最终状态检查"

    algo=$(sysctl -n net.ipv4.tcp_congestion_control)
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control)

    echo "   当前算法: $algo"
    echo "   可用算法: $avail"

    if [[ "$algo" == "bbr" ]]; then
        echo "✔ BBR 正常"
    else
        echo "❌ BBR 未生效"
    fi

    echo "================================"
}

# 🚀 主流程
case $choice in
1)
    deep_clean
    detect_bbr
    apply_pt
    apply_sysctl_verbose
    compare_before_after
    final_check
    ;;
2)
    deep_clean
    detect_bbr
    apply_vless
    apply_sysctl_verbose
    compare_before_after
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
echo "✔ 全部完成（可视化优化版）"
echo "⚠️ 建议重启系统"
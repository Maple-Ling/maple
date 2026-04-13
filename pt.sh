#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"
QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

# 颜色
G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"

# =============================
# 主菜单
# =============================
main_menu() {
clear
echo "======================================"
echo " Linux 终极性能优化面板（全能版）"
echo "======================================"
echo "1. PT刷流优化"
echo "2. VLESS节点优化"
echo "3. qBittorrent 管理"
echo "0. 退出"
echo "======================================"
read -p "请选择: " choice

case $choice in
1) apply_pt ;;
2) apply_vless ;;
3) qb_menu ;;
0) exit ;;
*) echo "输入错误"; sleep 1 ;;
esac
}

# =============================
# BBR智能选择
# =============================
set_best_cc() {
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)

if echo "$avail" | grep -q "bbr3"; then algo="bbr3"
elif echo "$avail" | grep -q "bbr2"; then algo="bbr2"
elif echo "$avail" | grep -q "bbrplus"; then algo="bbrplus"
elif echo "$avail" | grep -q "bbr"; then algo="bbr"
else algo="cubic"
fi

echo -e "👉 拥塞算法: ${G}$algo${N}"
sysctl -w net.ipv4.tcp_congestion_control=$algo >/dev/null
}

# =============================
# PT优化
# =============================
apply_pt() {
echo "🚀 PT优化中..."

cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_local_port_range=10000 65535
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=8
net.netfilter.nf_conntrack_max=1048576
fs.file-max=4194304
net.ipv6.conf.all.disable_ipv6=0
EOF

set_best_cc
apply_sysctl
}

# =============================
# VLESS优化
# =============================
apply_vless() {
echo "🚀 VLESS优化中..."

cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_max_syn_backlog=20000
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv6.conf.all.disable_ipv6=0
EOF

set_best_cc
apply_sysctl
}

# =============================
# sysctl应用（可视化）
# =============================
apply_sysctl() {
echo "⚙️ 应用参数..."

while read line; do
[[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

key=$(echo $line | cut -d= -f1)
val=$(echo $line | cut -d= -f2-)

printf "👉 %-35s = %-10s" "$key" "$val"

if sysctl -w "$key=$val" >/dev/null 2>&1; then
echo -e " ${G}✔${N}"
else
echo -e " ${R}✘${N}"
fi
done < $CONFIG_FILE
}

# =============================
# 内存识别
# =============================
detect_ram() {
ram=$(free -m | awk '/Mem:/ {print $2}')

if [ $ram -le 1024 ]; then level="low"
elif [ $ram -le 2048 ]; then level="midlow"
elif [ $ram -le 4096 ]; then level="midhigh"
else level="high"
fi

echo "👉 内存: ${ram}MB → 等级: $level"
}

# =============================
# qB优化
# =============================
qb_optimize() {
detect_ram

mkdir -p /pt/qBittorrent/config

case $level in
low)
cat > /pt/qBittorrent/config/qBittorrent.conf <<EOF
[Preferences]
Connection\MaxConnections=800
Session\DiskCacheSize=512
Session\AsyncIOThreadsCount=4
EOF
;;
midlow)
cat > /pt/qBittorrent/config/qBittorrent.conf <<EOF
[Preferences]
Connection\MaxConnections=1500
Session\DiskCacheSize=1024
Session\AsyncIOThreadsCount=8
EOF
;;
midhigh)
cat > /pt/qBittorrent/config/qBittorrent.conf <<EOF
[Preferences]
Connection\MaxConnections=3000
Session\DiskCacheSize=2048
Session\AsyncIOThreadsCount=16
EOF
;;
high)
cat > /pt/qBittorrent/config/qBittorrent.conf <<EOF
[Preferences]
Connection\MaxConnections=5000
Session\DiskCacheSize=4096
Session\AsyncIOThreadsCount=32
EOF
;;
esac

echo -e "${G}✔ qB配置已按机器自动优化${N}"
}

# =============================
# qB菜单
# =============================
qb_menu() {
clear
echo "===== qB管理 ====="
echo "1. 安装"
echo "2. 卸载"
echo "3. 启动"
echo "4. 停止"
echo "5. 重启"
echo "0. 返回"
read -p "选择: " q

case $q in
1) qb_install ;;
2) qb_uninstall ;;
3) systemctl start qbittorrent-nox ;;
4) systemctl stop qbittorrent-nox ;;
5) systemctl restart qbittorrent-nox ;;
0) main_menu ;;
esac
}

# =============================
# 安装
# =============================
qb_install() {
mkdir -p $QB_PATH
wget -O $QB_BIN "你的下载链接"
chmod +x $QB_BIN

cat > $QB_SERVICE <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
ExecStart=$QB_BIN --profile=$QB_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent-nox

qb_optimize

echo -e "${G}✔ 安装完成${N}"
}

# =============================
# 卸载
# =============================
qb_uninstall() {
systemctl stop qbittorrent-nox 2>/dev/null
systemctl disable qbittorrent-nox 2>/dev/null
rm -f $QB_SERVICE
rm -f $QB_BIN
systemctl daemon-reload
echo "✔ 已卸载"
}

# =============================
# 启动
# =============================
main_menu
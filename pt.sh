#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"
QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

# 颜色
G="\033[1;32m"
R="\033[1;31m"
Y="\033[1;33m"
B="\033[1;36m"
N="\033[0m"

line(){ echo -e "${B}--------------------------------------${N}"; }
pause(){ read -p "按回车继续..."; }

# =============================
# 主菜单
# =============================
main_menu() {
clear
echo -e "${B}"
echo "======================================"
echo " Linux 优化 + qB 管理面板（完整版）"
echo "======================================"
echo -e "${N}"
echo " 1. 🚀 PT刷流优化"
echo " 2. ⚡ VLESS优化"
echo " 3. 📦 qBittorrent 管理"
echo " 0. ❌ 退出"
line
read -p "请选择: " choice

case $choice in
1) apply_pt ;;
2) apply_vless ;;
3) qb_menu ;;
0) exit ;;
*) echo -e "${R}输入错误${N}"; sleep 1 ;;
esac

pause
main_menu
}

# =============================
# BBR自动选择
# =============================
set_best_cc(){
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
for algo in bbr3 bbr2 bbrplus bbr; do
    if echo "$avail" | grep -q "$algo"; then
        sysctl -w net.ipv4.tcp_congestion_control=$algo >/dev/null
        echo -e "👉 拥塞算法: ${G}$algo${N}"
        return
    fi
done
echo "👉 使用默认 cubic"
}

# =============================
# sysctl 应用
# =============================
apply_sysctl(){
line
echo "⚙️ 应用系统参数..."
while read line; do
[[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
key=${line%%=*}
val=${line#*=}
printf "👉 %-30s = %-10s" "$key" "$val"
sysctl -w "$key=$val" >/dev/null 2>&1 && echo -e " ${G}✔${N}" || echo -e " ${R}✘${N}"
done < $CONFIG_FILE
}

# =============================
# PT优化
# =============================
apply_pt(){
echo -e "${G}🚀 PT优化${N}"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_local_port_range=10000 65535
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=8
net.netfilter.nf_conntrack_max=1048576
fs.file-max=4194304
EOF
set_best_cc
apply_sysctl
}

# =============================
# VLESS优化
# =============================
apply_vless(){
echo -e "${G}⚡ VLESS优化${N}"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_max_syn_backlog=20000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF
set_best_cc
apply_sysctl
}

# =============================
# qB优化（核心）
# =============================
qb_optimize(){

echo "⚙️ 应用 qB 专项优化..."

systemctl stop qbittorrent-nox 2>/dev/null

mkdir -p /pt/downloads
mkdir -p /pt/qBittorrent/config

CONF="/pt/qBittorrent/config/qBittorrent.conf"

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

if [ $RAM -le 1024 ]; then level=low
elif [ $RAM -le 2048 ]; then level=midlow
elif [ $RAM -le 4096 ]; then level=midhigh
else level=high
fi

echo "👉 ${RAM}MB / ${CPU}核 → $level"

case $level in
low)
max=800 per=100 up=50 up_t=10 cache=256 write=64 ;;
midlow)
max=2000 per=300 up=100 up_t=20 cache=1024 write=256 ;;
midhigh)
max=3500 per=500 up=200 up_t=40 cache=2048 write=512 ;;
high)
max=5000 per=800 up=300 up_t=60 cache=4096 write=1024 ;;
esac

aio=$((CPU*2))

cat > $CONF <<EOF
[Preferences]
General\\Locale=zh
Downloads\\SavePath=/pt/downloads

Connection\\PortRangeMin=57777
Connection\\MaxConnections=$max
Connection\\MaxConnectionsPerTorrent=$per
Connection\\MaxUploads=$up
Connection\\MaxUploadsPerTorrent=$up_t
Connection\\UPnP=false

Queueing\\QueueingEnabled=false

Bittorrent\\DHT=false
Bittorrent\\PeX=false
Bittorrent\\LSD=false
Advanced\\AnonymousMode=true

WebUI\\Address=*
WebUI\\Port=8080
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
WebUI\\HostHeaderValidation=false

Session\\AsyncIOThreadsCount=$aio
Session\\DiskCacheSize=$cache
Downloads\\DiskWriteCacheSize=$write

Session\\SendBufferWatermark=2048
Session\\SendBufferLowWatermark=1024
EOF

systemctl start qbittorrent-nox
echo -e "${G}✔ qB优化完成${N}"
}

# =============================
# qB安装
# =============================
qb_install(){
echo "🚀 安装 qB..."

mkdir -p $QB_PATH

wget -O $QB_BIN https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox

[ ! -s "$QB_BIN" ] && echo -e "${R}下载失败${N}" && return

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

# 自动初始化
echo "y" | $QB_BIN --profile=$QB_PATH >/dev/null 2>&1

qb_optimize

echo -e "${G}✔ 安装完成${N}"
}

# =============================
# qB菜单
# =============================
qb_menu(){
clear
echo "=========== qB 管理 ==========="
echo "1. 安装（自动优化）"
echo "2. 卸载"
echo "3. 启动"
echo "4. 停止"
echo "5. 重启"
echo "0. 返回"
line
read -p "选择: " q

case $q in
1) qb_install ;;
2) systemctl disable qbittorrent-nox; rm -f $QB_BIN $QB_SERVICE ;;
3) systemctl start qbittorrent-nox ;;
4) systemctl stop qbittorrent-nox ;;
5) systemctl restart qbittorrent-nox ;;
0) return ;;
esac
}

main_menu
#!/bin/bash

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"
QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

G="\033[1;32m"; R="\033[1;31m"; Y="\033[1;33m"; B="\033[1;36m"; N="\033[0m"

line(){ echo -e "${B}--------------------------------------${N}"; }
pause(){ read -p "按回车继续..."; }

# =============================
# 主菜单
# =============================
main_menu(){
clear
echo -e "${B}"
echo "======================================"
echo " Linux 优化 + qB 管理（终极稳定版）"
echo "======================================"
echo -e "${N}"
echo " 1. 🚀 PT优化"
echo " 2. ⚡ VLESS优化"
echo " 3. 📦 qB管理"
echo " 0. ❌ 退出"
line
read -p "请选择: " c

case $c in
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
# BBR
# =============================
set_cc(){
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
for i in bbr3 bbr2 bbrplus bbr; do
echo "$avail" | grep -q "$i" && sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null && echo "👉 $i" && return
done
echo "👉 cubic"
}

apply_sysctl(){
while read l; do
[[ "$l" =~ ^#.*$ || -z "$l" ]] && continue
k=${l%%=*}; v=${l#*=}
sysctl -w "$k=$v" >/dev/null 2>&1
done < $CONFIG_FILE
}

apply_pt(){
echo "🚀 PT优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
fs.file-max=4194304
EOF
set_cc
apply_sysctl
}

apply_vless(){
echo "⚡ VLESS优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_fastopen=3
EOF
set_cc
apply_sysctl
}

# =============================
# qB 控制（彻底修复）
# =============================
qb_stop(){
echo "🛑 停止 qB"
systemctl stop qbittorrent-nox 2>/dev/null
pkill -9 qbittorrent-nox 2>/dev/null
sleep 1
pgrep qbittorrent-nox >/dev/null && echo -e "${R}未完全停止${N}" || echo -e "${G}已停止${N}"
}

qb_start(){
systemctl start qbittorrent-nox
sleep 2
pgrep qbittorrent-nox >/dev/null && echo -e "${G}已启动${N}" || echo -e "${R}启动失败${N}"
}

qb_restart(){
qb_stop
qb_start
}

# =============================
# qB 优化（最终稳定版）
# =============================
qb_optimize(){

echo "⚙️ 应用优化"

qb_stop

mkdir -p /pt/downloads
mkdir -p /pt/qBittorrent

CONF="/pt/qBittorrent/qBittorrent.conf"

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

if [ $RAM -le 1024 ]; then level=low
elif [ $RAM -le 2048 ]; then level=midlow
elif [ $RAM -le 4096 ]; then level=midhigh
else level=high
fi

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

qb_start
echo -e "${G}优化完成${N}"
}

# =============================
# 安装（完全修复）
# =============================
qb_install(){
echo "🚀 安装 qB"

mkdir -p $QB_PATH

wget -O $QB_BIN https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox

[ ! -s "$QB_BIN" ] && echo -e "${R}下载失败${N}" && return

chmod +x $QB_BIN

cat > $QB_SERVICE <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
Type=simple
ExecStart=$QB_BIN --profile=$QB_PATH
Restart=always
KillMode=control-group
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent-nox

# 初始化（自动同意协议）
echo "y" | $QB_BIN --profile=$QB_PATH >/dev/null 2>&1

qb_optimize

echo -e "${G}安装完成${N}"
}

# =============================
# 卸载（彻底）
# =============================
qb_uninstall(){
qb_stop
systemctl disable qbittorrent-nox 2>/dev/null
rm -f $QB_SERVICE
rm -f $QB_BIN
systemctl daemon-reload
echo "✔ 已卸载（数据保留）"
}

# =============================
# 菜单
# =============================
qb_menu(){
clear
echo "=========== qB 管理 ==========="
echo "1. 安装+优化"
echo "2. 卸载"
echo "3. 启动"
echo "4. 停止"
echo "5. 重启"
echo "6. 重新优化配置"
echo "0. 返回"
line
read -p "选择: " q

case $q in
1) qb_install ;;
2) qb_uninstall ;;
3) qb_start ;;
4) qb_stop ;;
5) qb_restart ;;
6) qb_optimize ;;
0) return ;;
esac
}

main_menu
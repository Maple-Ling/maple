#!/bin/bash

QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_CONF_DIR="/pt/qBittorrent/config"
QB_CONF="$QB_CONF_DIR/qBittorrent.conf"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

G="\033[1;32m"; R="\033[1;31m"; Y="\033[1;33m"; B="\033[1;36m"; N="\033[0m"

line(){ echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"; }

pause(){ read -p "按回车继续..."; }

# ======================
# UI
# ======================

main_menu(){
clear
echo -e "${B}"
echo "╔══════════════════════════════╗"
echo "║   🚀 Linux + qB 管理面板    ║"
echo "╚══════════════════════════════╝"
echo -e "${N}"
line
echo " 1. 🚀 PT优化"
echo " 2. ⚡ VLESS优化"
echo " 3. 📦 qB管理"
echo " 0. ❌ 退出"
line
read -p "选择: " c

case $c in
1) pt_opt ;;
2) vless_opt ;;
3) qb_menu ;;
0) exit ;;
esac

pause
main_menu
}

# ======================
# qB控制
# ======================

qb_stop(){
echo "🛑 停止 qB"
systemctl stop qbittorrent-nox 2>/dev/null
pkill -9 qbittorrent-nox 2>/dev/null
sleep 1
}

qb_start(){
systemctl start qbittorrent-nox
sleep 2
pgrep qbittorrent-nox >/dev/null && echo "✔ 已启动" || echo "❌ 启动失败"
}

qb_restart(){
qb_stop
qb_start
}

# ======================
# qB优化（终极版）
# ======================

qb_optimize(){

qb_stop

mkdir -p /pt/downloads
mkdir -p $QB_CONF_DIR

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

# ===== 内存档位 =====
if [ $RAM -le 1024 ]; then mem_conn=800; cache=256; write=64
elif [ $RAM -le 2048 ]; then mem_conn=1500; cache=1024; write=256
elif [ $RAM -le 3072 ]; then mem_conn=2200; cache=1536; write=384
elif [ $RAM -le 4096 ]; then mem_conn=3000; cache=2048; write=512
else mem_conn=5000; cache=4096; write=1024
fi

# ===== CPU限制 =====
if [ $CPU -eq 1 ]; then cpu_conn=1200; up=50; per_up=10; buf=1024; buf_low=512
elif [ $CPU -eq 2 ]; then cpu_conn=2500; up=100; per_up=20; buf=2048; buf_low=1024
elif [ $CPU -le 4 ]; then cpu_conn=4000; up=200; per_up=40; buf=4096; buf_low=2048
else cpu_conn=8000; up=300; per_up=60; buf=8192; buf_low=4096
fi

# ===== 最终连接 =====
max_conn=$(( mem_conn < cpu_conn ? mem_conn : cpu_conn ))
per_conn=$(( max_conn / 6 ))

aio=$((CPU*2))

# ===== 输出 =====
echo "================================"
echo "👉 内存: ${RAM}MB"
echo "👉 CPU: ${CPU}核"
echo "--------------------------------"
echo "👉 全局连接: $max_conn"
echo "👉 单种连接: $per_conn"
echo "👉 上传槽: $up / $per_up"
echo "👉 磁盘缓存: ${cache}MB"
echo "👉 写缓存: ${write}MB"
echo "👉 AIO线程: $aio"
echo "👉 发送缓冲: $buf / $buf_low"
echo "================================"

cat > $QB_CONF <<EOF
[Preferences]
General\\Locale=zh
Downloads\\SavePath=/pt/downloads

Connection\\PortRangeMin=57777
Connection\\MaxConnections=$max_conn
Connection\\MaxConnectionsPerTorrent=$per_conn
Connection\\MaxUploads=$up
Connection\\MaxUploadsPerTorrent=$per_up
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

Session\\DiskCacheSize=$cache
Downloads\\DiskWriteCacheSize=$write

[BitTorrent]
Session\\AsyncIOThreadsCount=$aio

[Session]
Session\\SendBufferWatermark=$buf
Session\\SendBufferLowWatermark=$buf_low
EOF

qb_start
echo "✔ 优化完成"
}

# ======================
# 安装
# ======================

qb_install(){

mkdir -p $QB_PATH

wget -O $QB_BIN https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox

chmod +x $QB_BIN

cat > $QB_SERVICE <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
Type=simple
ExecStart=$QB_BIN --profile=/pt
Restart=always
KillMode=control-group
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent-nox

echo "y" | $QB_BIN --profile=/pt >/dev/null 2>&1 &
sleep 3
pkill qbittorrent-nox

qb_optimize

echo "✔ 安装完成"
}

# ======================
# 卸载
# ======================

qb_uninstall(){
qb_stop
systemctl disable qbittorrent-nox 2>/dev/null
rm -f $QB_SERVICE $QB_BIN
systemctl daemon-reload
echo "✔ 已卸载"
}

# ======================
# 菜单
# ======================

qb_menu(){
clear
echo "╔════════ qB 管理 ════════╗"
echo "1. 安装+优化"
echo "2. 卸载"
echo "3. 启动"
echo "4. 停止"
echo "5. 重启"
echo "6. 重新优化"
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
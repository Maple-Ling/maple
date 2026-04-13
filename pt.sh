#!/bin/bash

QB_URL="http://127.0.0.1:8080"
QB_USER="admin"
QB_PASS="adminadmin"
COOKIE="/tmp/qb_cookie.txt"

QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

# ===== UI =====
c1="\033[1;36m"; c2="\033[1;32m"; c3="\033[1;33m"; c4="\033[1;31m"; n="\033[0m"

box(){
echo -e "${c1}╔════════════════════════════════╗${n}"
printf "${c1}║ %-30s ║${n}\n" "$1"
echo -e "${c1}╚════════════════════════════════╝${n}"
}

line(){ echo -e "${c1}══════════════════════════════════${n}"; }
pause(){ read -p "按回车继续..."; }

# ===== BBR自动 =====
set_cc(){
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control)
for i in bbr3 bbr2 bbrplus bbr
do
echo $avail | grep -q $i && sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null && echo "👉 使用 $i" && return
done
echo "👉 使用 cubic"
}

apply_sysctl(){
while read l
do
[[ "$l" =~ ^#.*$ || -z "$l" ]] && continue
sysctl -w "$l" >/dev/null
done < $CONFIG_FILE
}

# ===== PT优化 =====
pt_opt(){
box "🚀 PT刷流优化"

cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_local_port_range=10000 65535
fs.file-max=4194304
vm.swappiness=10
EOF

set_cc
apply_sysctl

echo -e "${c2}✔ PT优化完成${n}"
}

# ===== VLESS优化 =====
vless_opt(){
box "⚡ VLESS节点优化"

cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF

set_cc
apply_sysctl

echo -e "${c2}✔ VLESS优化完成${n}"
}

# ===== qB 控制 =====
qb_stop(){
echo -e "${c3}停止 qB${n}"
systemctl stop qbittorrent-nox 2>/dev/null
pkill -9 qbittorrent-nox 2>/dev/null
sleep 2
}

qb_start(){
echo -e "${c3}启动 qB${n}"
systemctl start qbittorrent-nox
sleep 3
}

qb_login(){
curl -s -c $COOKIE \
--data "username=$QB_USER&password=$QB_PASS" \
$QB_URL/api/v2/auth/login > /dev/null
}

# ===== 核心优化（安全模型版）=====
qb_optimize(){

qb_start
qb_login

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

# ===== 内存安全模型 =====
qb_mem=$((RAM * 70 / 100))

cache=$((qb_mem * 40 / 100))
[ $cache -gt 1024 ] && cache=1024
[ $cache -lt 128 ] && cache=128

write=$((cache / 4))

# ===== CPU模型 =====
aio=$((CPU * 4))
[ $aio -lt 8 ] && aio=8
[ $aio -gt 32 ] && aio=32

# ===== 连接模型（核心）=====
mem_conn=$((qb_mem / 2))
cpu_conn=$((CPU * 800))

max_conn=$(( mem_conn < cpu_conn ? mem_conn : cpu_conn ))
max_conn=$((max_conn * 80 / 100))

per_conn=$((max_conn / 8))

# ===== 上传 =====
upload=$((CPU * 20))
upload_t=$((CPU * 5))

# ===== 缓冲 =====
buf=$((CPU * 512))
[ $buf -lt 512 ] && buf=512
buf_low=$((buf / 2))

mkdir -p /pt/downloads

line
echo -e "${c2}内存:${RAM}MB CPU:${CPU}${n}"
echo "连接: $max_conn / $per_conn"
echo "上传: $upload / $upload_t"
echo "缓存: $cache / $write"
echo "缓冲: $buf / $buf_low"
echo "AIO: $aio"
line

# ===== API写入（绝对生效）=====
curl -s -b $COOKIE \
--data-urlencode "json={
\"locale\":\"zh\",
\"save_path\":\"/pt/downloads\",
\"max_connec\":$max_conn,
\"max_connec_per_torrent\":$per_conn,
\"max_uploads\":$upload,
\"max_uploads_per_torrent\":$upload_t,
\"listen_port\":57777,
\"upnp\":false,
\"enable_dht\":false,
\"enable_pex\":false,
\"enable_lsd\":false,
\"anonymous_mode\":true,
\"queueing_enabled\":false,
\"disk_cache\":$cache,
\"disk_cache_ttl\":60,
\"send_buffer_watermark\":$buf,
\"send_buffer_low_watermark\":$buf_low,
\"async_io_threads\":$aio,
\"web_ui_csrf_protection_enabled\":false,
\"web_ui_clickjacking_protection_enabled\":false,
\"auto_tmm_enabled\":true
}" \
$QB_URL/api/v2/app/setPreferences > /dev/null

echo -e "${c2}✔ qB优化完成（安全压榨模式）${n}"
}

# ===== 安装 =====
qb_install(){
box "📦 安装 qB"

mkdir -p $QB_PATH

wget -O $QB_BIN https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox

chmod +x $QB_BIN

cat > $QB_SERVICE <<EOF
[Unit]
Description=qBittorrent
After=network.target

[Service]
ExecStart=$QB_BIN --profile=/pt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent-nox

echo "y" | $QB_BIN --profile=/pt >/dev/null 2>&1 &
sleep 3
pkill qbittorrent-nox

qb_optimize

echo -e "${c2}✔ 安装完成${n}"
}

qb_uninstall(){
qb_stop
systemctl disable qbittorrent-nox
rm -f $QB_BIN $QB_SERVICE
systemctl daemon-reload
echo -e "${c2}✔ 已卸载${n}"
}

# ===== qB菜单 =====
qb_menu(){
clear
box "📦 qB管理"

echo "1. 安装 + 优化"
echo "2. 重新优化"
echo "3. 启动"
echo "4. 停止"
echo "5. 卸载"
echo "0. 返回"
line

read -p "选择: " n

case $n in
1) qb_install ;;
2) qb_optimize ;;
3) qb_start ;;
4) qb_stop ;;
5) qb_uninstall ;;
0) return ;;
esac

pause
qb_menu
}

# ===== 主菜单 =====
main_menu(){
clear
box "🚀 Linux终极控制面板"

echo "1. 🚀 PT刷流优化"
echo "2. ⚡ VLESS优化"
echo "3. 📦 qB管理"
echo "0. ❌ 退出"
line

read -p "选择: " n

case $n in
1) pt_opt ;;
2) vless_opt ;;
3) qb_menu ;;
0) exit ;;
esac

pause
main_menu
}

main_menu
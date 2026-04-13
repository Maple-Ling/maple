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

c1="\033[1;36m"
c2="\033[1;32m"
c3="\033[1;33m"
c4="\033[1;31m"
n="\033[0m"

box(){
echo -e "${c1}╔════════════════════════════════╗${n}"
echo -e "${c1}║        $1        ║${n}"
echo -e "${c1}╚════════════════════════════════╝${n}"
}

line(){
echo -e "${c1}══════════════════════════════════${n}"
}

pause(){
read -p "按回车继续..."
}

# ===== 系统优化 =====

set_cc(){
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control)
for i in bbr3 bbr2 bbrplus bbr
do
echo $avail | grep -q $i && sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null && return
done
}

apply_sysctl(){
while read l
do
[[ "$l" =~ ^#.*$ || -z "$l" ]] && continue
k=${l%%=*}; v=${l#*=}
sysctl -w "$k=$v" >/dev/null
done < $CONFIG_FILE
}

pt_opt(){
box "🚀 PT刷流优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=100000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
fs.file-max=4194304
EOF
set_cc
apply_sysctl
echo -e "${c2}✔ 完成${n}"
}

vless_opt(){
box "⚡ VLESS优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_fastopen=3
EOF
set_cc
apply_sysctl
echo -e "${c2}✔ 完成${n}"
}

# ===== qB 控制 =====

qb_stop(){
echo -e "${c3}停止 qB...${n}"
systemctl stop qbittorrent-nox 2>/dev/null
pkill -9 qbittorrent-nox 2>/dev/null
sleep 2
}

qb_start(){
echo -e "${c3}启动 qB...${n}"
systemctl start qbittorrent-nox
sleep 3
}

qb_login(){
curl -s -c $COOKIE \
--data "username=$QB_USER&password=$QB_PASS" \
$QB_URL/api/v2/auth/login > /dev/null
}

# ===== 核心优化（API）=====

qb_optimize(){

qb_start
qb_login

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

mem_limit=$(awk "BEGIN{printf \"%d\", $RAM*0.6}")
cpu_limit=$((CPU*1200))

max_conn=$(( mem_limit < cpu_limit ? mem_limit : cpu_limit ))
per_conn=$((max_conn/8))

upload=$((CPU*25))
upload_t=$((CPU*5))

cache=$(awk "BEGIN{printf \"%d\", $RAM*0.5}")
write=$(awk "BEGIN{printf \"%d\", $RAM*0.15}")

buf=$((CPU*1024))
buf_low=$((buf/2))

aio=$((CPU*2))

mkdir -p /pt/downloads

line
echo -e "${c2}内存:${RAM}MB CPU:${CPU}${n}"
echo -e "连接: $max_conn / $per_conn"
echo -e "上传: $upload / $upload_t"
echo -e "缓存: $cache / $write"
echo -e "缓冲: $buf / $buf_low"
line

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
\"send_buffer_watermark\":$buf,
\"send_buffer_low_watermark\":$buf_low,
\"async_io_threads\":$aio,
\"web_ui_csrf_protection_enabled\":false,
\"web_ui_clickjacking_protection_enabled\":false,
\"auto_tmm_enabled\":true
}" \
$QB_URL/api/v2/app/setPreferences > /dev/null

echo -e "${c2}✔ 优化完成${n}"
}

# ===== 安装 =====

qb_install(){
box "📦 安装 qBittorrent"

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
box "📦 qB 管理"

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
box "🚀 Linux 终极控制面板"

echo "1. 🚀 PT优化"
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
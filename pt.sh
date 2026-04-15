#!/bin/bash

QB_URL="http://127.0.0.1:8080"
QB_USER="admin"
QB_PASS="adminadmin"
COOKIE="/tmp/qb_cookie.txt"

QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_CONF="/pt/qBittorrent/config/qBittorrent.conf"
QB_SERVICE="/etc/systemd/system/qbittorrent-nox.service"

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

# ===== UI =====
c1="\033[1;36m"; c2="\033[1;32m"; c3="\033[1;33m"; c4="\033[1;31m"; n="\033[0m"

gen_qb_password() {
python3 - <<EOF
import os, base64, hashlib

password = "$1".encode()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha512', password, salt, 100000, dklen=64)

print(f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(dk).decode()})')
EOF
}

box(){
echo -e "${c1}╔════════════════════════════════╗${n}"
printf "${c1}║ %-30s ║${n}\n" "$1"
echo -e "${c1}╚════════════════════════════════╝${n}"
}
line(){ echo -e "${c1}══════════════════════════════════${n}"; }
pause(){ read -p "按回车继续..."; }

# ===== BBR =====
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
echo -e "${c2}✔ 完成${n}"
}

# ===== VLESS优化 =====
vless_opt(){
box "⚡ VLESS优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF
set_cc
apply_sysctl
echo -e "${c2}✔ 完成${n}"
}

# ===== qB控制 =====
qb_stop(){
systemctl stop qbittorrent-nox 2>/dev/null
pkill -9 qbittorrent-nox 2>/dev/null
sleep 2
}

qb_start(){
systemctl start qbittorrent-nox
sleep 6
}

qb_login(){
curl -s -c $COOKIE \
--data "username=$QB_USER&password=$QB_PASS" \
$QB_URL/api/v2/auth/login > /dev/null
}

# ===== 核心优化 =====
qb_optimize(){

qb_stop

mkdir -p /pt/qBittorrent/config

# 🔥 写死基础配置（关键）
cat > $QB_CONF <<EOF
[Preferences]
General\\Locale=zh
Downloads\\SavePath=/pt/downloads

Connection\\PortRangeMin=57777
Connection\\UPnP=false

Queueing\\QueueingEnabled=false

Bittorrent\\DHT=false
Bittorrent\\PeX=false
Bittorrent\\LSD=false
Bittorrent\\ValidateHTTPSTrackerCertificate=false
Advanced\\AnonymousMode=true
Advanced\\trackerPort=-1

Session\\DisableAutoTMMByDefault=false

WebUI\\Address=*
WebUI\\Port=8080
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
WebUI\\HostHeaderValidation=false
EOF

qb_start
qb_login

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

# ===== 融合计算 =====
if [ $RAM -le 1024 ]; then cache=128
elif [ $RAM -le 2048 ]; then cache=256
elif [ $RAM -le 4096 ]; then cache=512
else cache=1024; fi

write=$((cache/4))

if [ $CPU -le 1 ]; then aio=4
elif [ $CPU -le 2 ]; then aio=8
elif [ $CPU -le 4 ]; then aio=16
else aio=32; fi

qb_mem=$((RAM*70/100))
mem_conn=$((qb_mem/2))
cpu_conn=$((CPU*800))
max_conn=$(( mem_conn < cpu_conn ? mem_conn : cpu_conn ))
max_conn=$((max_conn*80/100))
per_conn=$((max_conn/8))

upload=$((CPU*20))
upload_t=$((CPU*5))

if [ $CPU -le 1 ]; then buf=2048
elif [ $CPU -le 2 ]; then buf=4096
else buf=8192; fi

buf_low=$((buf/2))

mkdir -p /pt/downloads

line
echo -e "${c2}内存:${RAM}MB CPU:${CPU}${n}"
echo "连接: $max_conn / $per_conn"
echo "上传: $upload / $upload_t"
echo "缓存: $cache / $write"
echo "缓冲: $buf / $buf_low"
echo "AIO: $aio"
line

# 🔥 写性能参数
curl -s -b $COOKIE --data-urlencode "json={
\"max_connec\":$max_conn,
\"max_connec_per_torrent\":$per_conn,
\"max_uploads\":$upload,
\"max_uploads_per_torrent\":$upload_t,
\"disk_cache\":$cache,
\"send_buffer_watermark\":$buf,
\"send_buffer_low_watermark\":$buf_low,
\"async_io_threads\":$aio,
\"auto_tmm_enabled\":true,
\"enable_dht\":false,
\"enable_pex\":false,
\"enable_lsd\":false,
\"web_ui_host_header_validation\":false,
\"validate_https_tracker_certificate\":false
}" $QB_URL/api/v2/app/setPreferences >/dev/null

sleep 3

# 🔥 再锁一次（绝杀）
curl -s -b $COOKIE --data-urlencode "json={
\"enable_dht\":false,
\"enable_pex\":false,
\"enable_lsd\":false
}" $QB_URL/api/v2/app/setPreferences >/dev/null

echo -e "${c2}✔ 优化完成（最终版）${n}"
}

# ===== 种子备份 =====
qb_backup(){
box "📦 备份种子"

SRC="/pt/qBittorrent/data/BT_backup"
DST="/pt/BT_backup"

if [ ! -d "$SRC" ]; then
    echo -e "${c4}❌ 源目录不存在: $SRC${n}"
    return
fi

rm -rf "$DST"
cp -r "$SRC" "$DST"

echo -e "${c2}✔ 备份完成 -> /pt/BT_backup${n}"
}

# ===== 种子恢复 =====
qb_restore(){
box "♻️ 恢复种子"

SRC="/pt/BT_backup"
DST="/pt/qBittorrent/data/BT_backup"

if [ ! -d "$SRC" ]; then
    echo -e "${c4}❌ 备份不存在: /pt/BT_backup${n}"
    return
fi

qb_stop

mkdir -p "/pt/qBittorrent/data"
rm -rf "$DST"
cp -r "$SRC" "$DST"

echo -e "${c2}✔ 恢复完成${n}"
}

qb_install(){
box "📦 安装 qB"
mkdir -p $QB_PATH

ARCH=$(uname -m)

echo "👉 当前架构: $ARCH"

# ===== 自动选择下载 =====
if [[ "$ARCH" == "x86_64" ]]; then
    QB_URL_DL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/x86_64-qbittorrent-nox"

elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    QB_URL_DL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.3.9_v1.2.15/aarch64-qbittorrent-nox"

elif [[ "$ARCH" == arm* ]]; then
    echo -e "${c4}❌ 不支持的ARM架构: $ARCH${n}"
    echo "👉 建议使用 aarch64 VPS"
    return

else
    echo -e "${c4}❌ 未知架构: $ARCH${n}"
    return
fi

echo "👉 下载: $QB_URL_DL"

wget -O $QB_BIN $QB_URL_DL

# ===== 权限 =====
chmod +x $QB_BIN

# ===== 校验 =====
file $QB_BIN

# ===== systemd =====
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

# ===== 首次初始化 =====
echo "y" | $QB_BIN --profile=/pt >/dev/null 2>&1 &
sleep 3
pkill qbittorrent-nox

qb_optimize

# ===== 隐式修复（模拟手动操作）=====
qb_stop >/dev/null 2>&1

echo
echo -e "${c3}👉 请输入 WebUI 账号（默认 admin）:${n}"
start_time=$(date +%s)
read input_user

echo -e "${c3}👉 请输入 WebUI 密码（默认 adminadmin）:${n}"
read input_pass

end_time=$(date +%s)
elapsed=$((end_time - start_time))

# 默认值
[ -z "$input_user" ] && input_user="admin"
[ -z "$input_pass" ] && input_pass="adminadmin"

# ===== 生成PBKDF2密码 =====
HASH=$(gen_qb_password "$input_pass")

# ===== 写入配置（关键！）=====
sed -i '/WebUI\\Username/d' $QB_CONF
sed -i '/WebUI\\Password_PBKDF2/d' $QB_CONF

cat >> $QB_CONF <<EOF
WebUI\\Username=$input_user
WebUI\\Password_PBKDF2="$HASH"
EOF

# ===== 时间控制 =====
if [ $elapsed -lt 10 ]; then
    wait_time=$((10 - elapsed))
    echo -e "${c3}👉 等待 ${wait_time}s 初始化...${n}"
    sleep $wait_time
fi

qb_start >/dev/null 2>&1

echo -e "${c2}✔ 安装完成${n}"
}

qb_uninstall(){
qb_stop
systemctl disable qbittorrent-nox
rm -f $QB_BIN $QB_SERVICE
rm -rf /pt/qBittorrent
systemctl daemon-reload
echo -e "${c2}✔ 已彻底卸载${n}"
}

# ===== 菜单 =====
qb_menu(){
clear
box "📦 qB管理"
echo "1. 安装 + 优化"
echo "2. 重新优化"
echo "3. 启动"
echo "4. 停止"
echo "5. 备份种子"
echo "6. 恢复种子"
echo "7. 卸载"
echo "0. 返回"
line
read -p "选择: " n
case $n in
1) qb_install ;;
2) qb_optimize ;;
3) qb_start ;;
4) qb_stop ;;
5) qb_backup ;;
6) qb_restore ;;
7) qb_uninstall ;;
0) return ;;
esac
pause
qb_menu
}

main_menu(){
clear
box "🚀 Linux终极控制面板"
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
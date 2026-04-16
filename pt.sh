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

# ===== UI优化 =====
# 简化颜色，只保留必要的几种
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'  # 重置颜色

gen_qb_password() {
python3 - <<EOF
import os, base64, hashlib

password = "$1".encode()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha512', password, salt, 100000, dklen=64)

print(f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(dk).decode()})')
EOF
}

# 简洁的标题函数
print_title() {
    echo
    echo "========================================"
    echo -e "${BLUE}$1${NC}"
    echo "========================================"
    echo
}

# 简洁的分隔线
print_line() {
    echo "----------------------------------------"
}

# 成功提示
print_ok() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# 错误提示
print_err() {
    echo -e "${RED}[✗]${NC} $1"
}

# 警告提示
print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# 暂停函数
pause() { 
    echo
    echo -n "按回车键继续..."
    read
}

# ===== BBR =====
set_cc(){
avail=$(sysctl -n net.ipv4.tcp_available_congestion_control)
for i in bbr3 bbr2 bbrplus bbr
do
echo $avail | grep -q $i && sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null && echo "使用 $i" && return
done
echo "使用 cubic"
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
clear
print_title "PT刷流优化"
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
print_ok "PT刷流优化完成"
pause
}

# ===== VLESS优化 =====
vless_opt(){
clear
print_title "VLESS优化"
cat > $CONFIG_FILE <<EOF
net.core.default_qdisc=fq
net.core.netdev_max_backlog=20000
net.core.somaxconn=20000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
EOF
set_cc
apply_sysctl
print_ok "VLESS优化完成"
pause
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

# 添加重启功能
qb_restart(){
    print_warn "正在重启 qBittorrent..."
    qb_stop
    qb_start
    print_ok "qBittorrent 已重启"
}

qb_login(){
curl -s -c $COOKIE \
--data "username=$QB_USER&password=$QB_PASS" \
$QB_URL/api/v2/auth/login > /dev/null
}

# ===== 核心优化 =====
qb_optimize(){
clear
print_title "qBittorrent 性能优化"

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

print_line
echo -e "${GREEN}内存:${RAM}MB CPU:${CPU}${NC}"
echo "连接: $max_conn / $per_conn"
echo "上传: $upload / $upload_t"
echo "缓存: $cache / $write"
echo "缓冲: $buf / $buf_low"
echo "AIO: $aio"
print_line

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

print_ok "优化完成（最终版）"
pause
}

# ===== 种子备份 =====
qb_backup(){
clear
print_title "备份种子"

SRC="/pt/qBittorrent/data/BT_backup"
DST="/pt/BT_backup"

if [ ! -d "$SRC" ]; then
    print_err "源目录不存在: $SRC"
    pause
    return
fi

rm -rf "$DST"
cp -r "$SRC" "$DST"

print_ok "备份完成 -> /pt/BT_backup"
pause
}

# ===== 种子恢复 =====
qb_restore(){
clear
print_title "恢复种子"

SRC="/pt/BT_backup"
DST="/pt/qBittorrent/data/BT_backup"

if [ ! -d "$SRC" ]; then
    print_err "备份不存在: /pt/BT_backup"
    pause
    return
fi

qb_stop

mkdir -p "/pt/qBittorrent/data"
rm -rf "$DST"
cp -r "$SRC" "$DST"

print_ok "恢复完成"
pause
}

qb_install(){
clear
print_title "安装 qBittorrent"
mkdir -p $QB_PATH

ARCH=$(uname -m)

echo -e "${CYAN}当前架构: $ARCH${NC}"

# ===== 自动选择下载 =====
if [[ "$ARCH" == "x86_64" ]]; then
    QB_URL_DL="https://github.com/userdocs/qbittorrent-nox-static-legacy/releases/download/release-4.3.9_v1.2.20/x86_64-qbittorrent-nox"

elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    QB_URL_DL="https://github.com/userdocs/qbittorrent-nox-static-legacy/releases/download/release-4.3.9_v1.2.20/aarch64-qbittorrent-nox"

elif [[ "$ARCH" == arm* ]]; then
    print_err "不支持的ARM架构: $ARCH"
    echo "建议使用 aarch64 VPS"
    pause
    return

else
    print_err "未知架构: $ARCH"
    pause
    return
fi

echo "下载: $QB_URL_DL"

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
echo -e "${YELLOW}请输入 WebUI 账号（默认 admin）:${NC}"
start_time=$(date +%s)
read input_user

echo -e "${YELLOW}请输入 WebUI 密码（默认 adminadmin）:${NC}"
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
    echo -e "${YELLOW}等待 ${wait_time}s 初始化...${NC}"
    sleep $wait_time
fi

qb_start >/dev/null 2>&1

print_ok "安装完成"
pause
}

qb_uninstall(){
clear
print_title "卸载 qBittorrent"

echo -e "${RED}警告：此操作将永久删除 qBittorrent 及其配置！${NC}"
echo -n "确认要卸载吗？(y/N): "
read confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    qb_stop
    systemctl disable qbittorrent-nox
    rm -f $QB_BIN $QB_SERVICE
    rm -rf /pt/qBittorrent
    systemctl daemon-reload
    print_ok "已彻底卸载"
else
    echo "卸载已取消"
fi
pause
}

# ===== 科技感猫图案 =====
print_tech_cat() {
    echo
    echo -e "${CYAN}    ___   ___  ___  ___  ___  ___  ___  ___"
    echo "   /   \ /   \/   \/   \/   \/   \/   \/   \\"
    echo "  |  T  |  E  |  C  |  H  |  C  |  A  |  T  |"
    echo "   \___/\___/\___/\___/\___/\___/\___/\___/"
    echo
    echo -e "        /\_/\           |\___/|"
    echo -e "       ( ${GREEN}o${CYAN}.${GREEN}o${CYAN} )          |     |"
    echo -e "        > ${YELLOW}^${CYAN} <           /       \\"
    echo -e "         ${BLUE}=================${CYAN}"
    echo -e "${NC}"
}

# ===== 菜单 =====
qb_menu(){
while true; do
    clear
    print_tech_cat
    print_title "qBittorrent 管理"
    
    echo "1. 安装 + 优化"
    echo "2. 重新优化"
    echo "3. 启动"
    echo "4. 停止"
    echo "5. 重启"
    echo "6. 备份种子"
    echo "7. 恢复种子"
    echo "8. 卸载"
    echo "0. 返回主菜单"
    print_line
    
    read -p "请选择 (0-8): " choice
    
    case $choice in
        1) qb_install ;;
        2) qb_optimize ;;
        3) 
            qb_start
            print_ok "qBittorrent 已启动"
            pause
            ;;
        4) 
            qb_stop
            print_ok "qBittorrent 已停止"
            pause
            ;;
        5) qb_restart; pause ;;
        6) qb_backup ;;
        7) qb_restore ;;
        8) qb_uninstall ;;
        0) break ;;
        *) 
            print_err "无效选择，请重新输入"
            sleep 1
            ;;
    esac
done
}

main_menu(){
while true; do
    clear
    print_tech_cat
    print_title "Linux 控制面板"
    
    echo "1. PT刷流优化"
    echo "2. VLESS优化"
    echo "3. qBittorrent 管理"
    echo "0. 退出"
    print_line
    
    read -p "请选择 (0-3): " choice
    
    case $choice in
        1) pt_opt ;;
        2) vless_opt ;;
        3) qb_menu ;;
        0) 
            clear
            echo
            echo "感谢使用！"
            echo
            exit 0
            ;;
        *) 
            print_err "无效选择，请重新输入"
            sleep 1
            ;;
    esac
done
}

main_menu

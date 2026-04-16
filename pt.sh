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

# 信息提示
print_info() {
    echo -e "${CYAN}[i]${NC} $1"
}

# 暂停函数
pause() { 
    echo
    echo -n "按回车键继续..."
    read
}

# ===== 系统优化辅助函数 =====
set_cc(){
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    for i in bbr3 bbr2 bbrplus bbr
    do
        echo $avail | grep -q $i && sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null 2>&1 && print_ok "使用 TCP 算法: $i" && return
    done
    print_warn "使用默认算法: cubic"
}

apply_sysctl(){
    while read l
    do
        [[ "$l" =~ ^#.*$ || -z "$l" ]] && continue
        sysctl -w "$l" >/dev/null 2>&1
    done < $CONFIG_FILE
    sysctl -p $CONFIG_FILE >/dev/null 2>&1
}

# ===== 安装TCP算法 =====
install_tcp_algo() {
    clear
    print_title "安装TCP拥塞控制算法"
    
    # 显示内存信息
    RAM=$(free -m | awk '/Mem:/ {print $2}')
    echo -e "${CYAN}当前系统内存: ${RAM}MB${NC}"
    print_line
    
    echo -e "${YELLOW}=== 算法内存需求说明 ===${NC}"
    echo "1. BBR (Linux内核原生) - 内存需求: 最低，稳定性最高"
    echo "2. BBRx (优化版) - 内存需求: 中等，性能较好"
    echo "3. BBRv3 (最新版) - 内存需求: 较高，弱网表现最佳"
    echo "4. 返回主菜单"
    print_line
    
    # 根据内存给出推荐
    if [ $RAM -lt 1024 ]; then
        echo -e "${GREEN}推荐: 内存小于1GB，建议使用原生BBR${NC}"
    elif [ $RAM -lt 4096 ]; then
        echo -e "${GREEN}推荐: 内存1-4GB，建议使用BBRx${NC}"
    else
        echo -e "${GREEN}推荐: 内存大于4GB，建议使用BBRv3${NC}"
    fi
    print_line
    
    read -p "请选择(1-4): " choice
    
    case $choice in
        1)
            print_info "正在安装BBR (Linux内核原生)..."
            KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
            if [ $(echo "$KERNEL_VERSION >= 4.9" | bc) -eq 1 ]; then
                echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                sysctl -p $CONFIG_FILE
                print_ok "BBR已启用 (内存需求: 最低)"
            else
                print_err "内核版本需要4.9以上，当前版本: $(uname -r)"
            fi
            ;;
        2)
            # 检查内存
            if [ $RAM -lt 1024 ]; then
                echo -e "${YELLOW}警告: 内存小于1GB，BBRx可能占用较多内存${NC}"
                read -p "是否继续安装？(y/N): " confirm
                [[ ! $confirm =~ ^[Yy]$ ]] && return
            fi
            print_info "正在安装BBRx (优化版)..."
            wget -O /tmp/bbrx.sh https://raw.githubusercontent.com/tcp-nanqinlang/general/master/General/CentOS/bash/tcp_nanqinlang-1.3.2.sh
            if [ $? -eq 0 ]; then
                chmod +x /tmp/bbrx.sh
                bash /tmp/bbrx.sh
                if [ $? -eq 0 ]; then
                    echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                    echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                    sysctl -p $CONFIG_FILE
                    print_ok "BBRx安装完成 (内存需求: 中等)"
                else
                    print_err "BBRx安装失败，启用原生BBR"
                    echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                    echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                    sysctl -p $CONFIG_FILE
                fi
            else
                print_err "下载BBRx脚本失败，启用原生BBR"
                echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                sysctl -p $CONFIG_FILE
            fi
            ;;
        3)
            # 检查内存
            if [ $RAM -lt 2048 ]; then
                echo -e "${YELLOW}警告: 内存小于2GB，BBRv3可能占用较多内存${NC}"
                read -p "是否继续安装？(y/N): " confirm
                [[ ! $confirm =~ ^[Yy]$ ]] && return
            fi
            print_info "正在安装BBRv3 (最新版)..."
            wget -O /tmp/bbrv3.sh https://raw.githubusercontent.com/google/bbr/master/v3alpha/bbr.sh
            if [ $? -eq 0 ]; then
                chmod +x /tmp/bbrv3.sh
                bash /tmp/bbrv3.sh
                if [ $? -eq 0 ]; then
                    echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                    echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                    sysctl -p $CONFIG_FILE
                    print_ok "BBRv3安装完成 (内存需求: 较高)"
                else
                    print_err "BBRv3安装失败，启用原生BBR"
                    echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                    echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                    sysctl -p $CONFIG_FILE
                fi
            else
                print_err "下载BBRv3脚本失败，启用原生BBR"
                echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
                echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
                sysctl -p $CONFIG_FILE
            fi
            ;;
        4)
            return
            ;;
        *)
            print_err "无效选择"
            ;;
    esac
    
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    echo
    print_info "当前TCP拥塞控制算法: $CURRENT_CC"
    
    pause
}

# ===== 查看当前优化状态 =====
view_optimization() {
    clear
    print_title "当前优化状态"
    
    echo -e "${GREEN}=== TCP拥塞控制算法 ===${NC}"
    sysctl net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知"
    
    echo -e "\n${GREEN}=== IPv4网络核心参数 ===${NC}"
    sysctl net.core.rmem_max net.core.wmem_max net.core.netdev_max_backlog net.core.somaxconn 2>/dev/null
    
    echo -e "\n${GREEN}=== IPv6优化状态 ===${NC}"
    sysctl net.ipv6.conf.all.accept_ra net.ipv6.conf.all.accept_redirects 2>/dev/null || echo "IPv6未配置"
    
    echo -e "\n${GREEN}=== 文件描述符限制 ===${NC}"
    ulimit -n
    
    pause
}

# ===== PT优化 =====
pt_opt(){
    clear
    print_title "PT刷流优化"
    cat > $CONFIG_FILE <<EOF
# 网络核心参数
net.core.rmem_default = 8388608
net.core.rmem_max = 134217728
net.core.wmem_default = 8388608
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 10000 65535
fs.file-max = 4194304
vm.swappiness = 10

# TCP参数优化
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_app_win = 31
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_limit_output_bytes = 262144
net.ipv4.tcp_notsent_lowat = 4294967295
net.ipv4.tcp_workaround_signed_windows = 0
net.ipv4.tcp_fastopen_key = a1b2c3d4-0000111122223333
net.ipv4.tcp_fastopen_blackhole_timeout_sec = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_tso_win_divisor = 3

# 网络设备参数
net.core.default_qdisc = fq

# 连接跟踪
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 432000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120

# 虚拟内存参数
vm.dirty_ratio = 60
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 12000
vm.dirty_writeback_centisecs = 1500
vm.vfs_cache_pressure = 50
vm.overcommit_memory = 1
vm.overcommit_ratio = 100
vm.min_free_kbytes = 65536
vm.zone_reclaim_mode = 0
vm.max_map_count = 262144
vm.admin_reserve_kbytes = 8192
vm.user_reserve_kbytes = 8192

# ===== IPv6优化参数 =====
# 安全设置
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.forwarding = 0

# 邻居表优化
net.ipv6.neigh.default.gc_thresh1 = 1024
net.ipv6.neigh.default.gc_thresh2 = 2048
net.ipv6.neigh.default.gc_thresh3 = 4096

# TCP参数优化
net.ipv6.tcp_mtu_probing = 1
net.ipv6.tcp_congestion_control = bbr
net.ipv6.tcp_slow_start_after_idle = 0
net.ipv6.tcp_notsent_lowat = 4294967295
net.ipv6.tcp_rmem = 4096 87380 134217728
net.ipv6.tcp_wmem = 4096 65536 134217728
EOF
    set_cc
    apply_sysctl
    print_ok "PT刷流优化完成 (包含IPv6优化)"
    pause
}

# ===== VLESS优化 =====
vless_opt(){
    clear
    print_title "VLESS优化"
    cat > $CONFIG_FILE <<EOF
# 网络核心参数
net.core.rmem_default = 8388608
net.core.rmem_max = 134217728
net.core.wmem_default = 8388608
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 20000
net.core.somaxconn = 20000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

# TCP参数优化
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mem = 786432 1048576 1572864
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_app_win = 31
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_limit_output_bytes = 262144
net.ipv4.tcp_notsent_lowat = 4294967295
net.ipv4.tcp_workaround_signed_windows = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_tso_win_divisor = 3

# 端口范围
net.ipv4.ip_local_port_range = 10000 65535

# 网络设备参数
net.core.default_qdisc = fq

# 连接跟踪
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 432000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120

# 虚拟内存参数
vm.swappiness = 10
vm.dirty_ratio = 30
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.vfs_cache_pressure = 50
vm.overcommit_memory = 1
vm.overcommit_ratio = 100
vm.min_free_kbytes = 65536
vm.zone_reclaim_mode = 0
vm.max_map_count = 262144

# ===== IPv6优化参数 =====
# 安全设置
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.forwarding = 0

# TCP参数优化
net.ipv6.tcp_mtu_probing = 1
net.ipv6.tcp_congestion_control = bbr
net.ipv6.tcp_slow_start_after_idle = 0
net.ipv6.tcp_notsent_lowat = 4294967295
net.ipv6.tcp_rmem = 4096 87380 134217728
net.ipv6.tcp_wmem = 4096 65536 134217728
EOF
    set_cc
    apply_sysctl
    print_ok "VLESS优化完成 (包含IPv6优化)"
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
Connection\\PortRangeMax=57777
Connection\\UPnP=false
Connection\\UseUPnP=false
Connection\\Protocol=TCP

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
    
    # 单个种子连接数最低100
    [ $per_conn -lt 100 ] && per_conn=100

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
    \"web_ui_clickjacking_protection\":false,
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
    echo -e "${YELLOW}================ 配置 qBittorrent ================${NC}"
    echo
    
    # === 端口设置（从函数开头移动到此）===
    echo -e "${YELLOW}设置端口:${NC}"
    read -p "WebUI端口 (默认: 8080): " WEB_PORT
    [ -z "$WEB_PORT" ] && WEB_PORT="8080"
    
    read -p "监听端口 (默认: 57777): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT="57777"
    
    QB_WEB_PORT=$WEB_PORT
    QB_LISTEN_PORT=$LISTEN_PORT
    QB_URL="http://127.0.0.1:$QB_WEB_PORT"
    
    echo
    
    # === 用户名密码设置（原位置保留）===
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

# ===== 简洁标题 =====
print_simple_title() {
    echo
    echo "========================================"
    echo "        无界刷流优化工具"
    echo "========================================"
    echo
}

# ===== 菜单 =====
qb_menu(){
    while true; do
        clear
        print_simple_title
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
        print_simple_title
        
        echo "1. PT刷流优化"
        echo "2. VLESS优化"
        echo "3. 查看当前优化状态"
        echo "4. 安装TCP拥塞控制算法"
        echo "5. qBittorrent 管理"
        echo "0. 退出"
        print_line
        
        read -p "请选择 (0-5): " choice
        
        case $choice in
            1) pt_opt ;;
            2) vless_opt ;;
            3) view_optimization ;;
            4) install_tcp_algo ;;
            5) qb_menu ;;
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

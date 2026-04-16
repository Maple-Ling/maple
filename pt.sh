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

# ===== 系统调优检测和安装 =====
check_and_install_tuning() {
    print_info "检查系统调优状态..."
    
    # 检查是否已应用系统调优（通过检查sysctl参数）
    if [ -f /etc/sysctl.conf ] && grep -q "net.core.default_qdisc = fq" /etc/sysctl.conf; then
        print_ok "系统调优已应用"
    else
        print_info "系统调优未应用，开始安装..."
        
        # 下载并运行jerry048的调优脚本
        bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -t
        
        if [ $? -eq 0 ]; then
            print_ok "系统调优安装完成"
        else
            print_err "系统调优安装失败"
        fi
    fi
}

# ===== 调用jerry048脚本安装TCP算法 =====
install_by_jerry048() {
    local algo=$1  # "bbrx" 或 "bbrv3"
    
    print_info "使用jerry048脚本安装 $algo..."
    
    # 下载并运行jerry048的tune.sh脚本
    if [[ "$algo" == "bbrx" ]]; then
        bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -x
    elif [[ "$algo" == "bbrv3" ]]; then
        bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -3
    else
        print_err "不支持的算法: $algo"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        print_ok "$algo 安装完成"
        return 0
    else
        print_err "$algo 安装失败"
        return 1
    fi
}

# 启用原生BBR
enable_native_bbr() {
    print_info "启用 Linux 内核原生 BBR..."
    
    # 提取内核主版本和次版本
    KERNEL_MAJOR=$(uname -r | cut -d. -f1)
    KERNEL_MINOR=$(uname -r | cut -d. -f2)
    
    # 转换为整数比较：4.9 = 4009
    KERNEL_VERSION_INT=$((KERNEL_MAJOR * 1000 + KERNEL_MINOR))
    
    if [[ $KERNEL_VERSION_INT -ge 4009 ]]; then
        echo "net.core.default_qdisc=fq" >> $CONFIG_FILE
        echo "net.ipv4.tcp_congestion_control=bbr" >> $CONFIG_FILE
        sysctl -p $CONFIG_FILE >/dev/null 2>&1
        print_ok "原生 BBR 已启用 (内核版本: $(uname -r), 内存需求: 最低)"
    else
        print_err "内核版本 ($(uname -r)) 过低，无法启用原生 BBR，将使用系统默认算法。"
    fi
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
            enable_native_bbr
            ;;
        2)
            # 检查内存
            if [ $RAM -lt 1024 ]; then
                echo -e "${YELLOW}警告: 内存小于1GB，BBRx可能占用较多内存${NC}"
                read -p "是否继续安装？(y/N): " confirm
                [[ ! $confirm =~ ^[Yy]$ ]] && return
            fi
            install_by_jerry048 "bbrx"
            ;;
        3)
            # 检查内存
            if [ $RAM -lt 2048 ]; then
                echo -e "${YELLOW}警告: 内存小于2GB，BBRv3可能占用较多内存${NC}"
                read -p "是否继续安装？(y/N): " confirm
                [[ ! $confirm =~ ^[Yy]$ ]] && return
            fi
            install_by_jerry048 "bbrv3"
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

enable_bbr_fq() {
    print_info "启用 BBR + fq（稳定抢种版）..."

    # 写入配置
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf

    sysctl -p >/dev/null 2>&1

    CC=$(sysctl -n net.ipv4.tcp_congestion_control)
    QDISC=$(sysctl -n net.core.default_qdisc)

    print_ok "当前算法: $CC | 队列: $QDISC"
}

# ===== 查看当前优化状态 =====
view_optimization() {
    clear
    print_title "当前优化状态"
    
    # 系统基本信息
    echo -e "${GREEN}=== 系统基本信息 ===${NC}"
    echo "主机名: $(hostname)"
    echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    
    # CPU信息
    echo -e "\n${GREEN}=== CPU信息 ===${NC}"
    echo "CPU型号: $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//')"
    echo "CPU核心数: $(nproc)"
    echo "CPU频率: $(lscpu | grep "CPU MHz" | cut -d: -f2 | sed 's/^[ \t]*//') MHz"
    echo "CPU缓存:"
    lscpu | grep -E "L[123] cache" | while read line; do
        echo "  $line"
    done
    
    # 内存信息
    echo -e "\n${GREEN}=== 内存信息 ===${NC}"
    free -h | while read line; do
        echo "  $line"
    done
    
    # TCP拥塞控制算法
    echo -e "\n${GREEN}=== TCP拥塞控制算法 ===${NC}"
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    echo "当前算法: $CURRENT_CC"
    echo "可用算法: $(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "未知")"
    
    # IPv4网络核心参数
    echo -e "\n${GREEN}=== IPv4网络核心参数 ===${NC}"
    sysctl net.core.rmem_max net.core.wmem_max net.core.netdev_max_backlog net.core.somaxconn 2>/dev/null
    
    # IPv6优化状态
    echo -e "\n${GREEN}=== IPv6优化状态 ===${NC}"
    sysctl net.ipv6.conf.all.accept_ra net.ipv6.conf.all.accept_redirects 2>/dev/null || echo "IPv6未配置"
    
    # 文件描述符限制
    echo -e "\n${GREEN}=== 文件描述符限制 ===${NC}"
    ulimit -n
    
    # 磁盘信息
    echo -e "\n${GREEN}=== 磁盘使用情况 ===${NC}"
    df -h /pt 2>/dev/null || df -h / 2>/dev/null
    
    # 系统负载
    echo -e "\n${GREEN}=== 系统负载 ===${NC}"
    uptime
    
    pause
}

# ===== PT优化 =====
pt_opt(){
    clear
    print_title "PT刷流优化"
    
    # 第一步：检测系统调优并安装TCP算法
    enable_bbr_fq
    
    # 第二步：应用PT刷流优化配置
  CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)

if [[ "$CC" == "bbr2" ]]; then
    TCP_LIMIT=4194304
else
    TCP_LIMIT=1048576
fi

cat > $CONFIG_FILE <<EOF
# ===== 核心 =====
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ===== buffer =====
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# ===== 并发 =====
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384

# ===== 抢种强化（重点）=====
net.ipv4.tcp_notsent_lowat = 8192
net.ipv4.tcp_limit_output_bytes = 4194304
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_slow_start_after_idle = 0

# ===== TCP基础 =====
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# ===== 连接跟踪 =====
net.netfilter.nf_conntrack_max = 2097152

# ===== IPv6优化 =====
net.ipv6.route.max_size = 2147483647

net.ipv6.neigh.default.gc_thresh1 = 4096
net.ipv6.neigh.default.gc_thresh2 = 8192
net.ipv6.neigh.default.gc_thresh3 = 16384

net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.conf.all.forwarding = 1

# ===== IPv6 TCP =====
net.ipv6.tcp_mtu_probing = 1
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
    
    # 第一步：检测系统调优并安装TCP算法
    enable_bbr_fq
    
    # 第二步：应用VLESS优化配置
CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)

if [[ "$CC" == "bbr2" ]]; then
    TCP_LIMIT=4194304
else
    TCP_LIMIT=1048576
fi

cat > $CONFIG_FILE <<EOF
# ===== 核心 =====
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ===== buffer =====
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# ===== 并发 =====
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384

# ===== 抢种强化（重点）=====
net.ipv4.tcp_notsent_lowat = 8192
net.ipv4.tcp_limit_output_bytes = 4194304
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_slow_start_after_idle = 0

# ===== TCP基础 =====
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# ===== 连接跟踪 =====
net.netfilter.nf_conntrack_max = 2097152

# ===== IPv6优化 =====
net.ipv6.route.max_size = 2147483647

net.ipv6.neigh.default.gc_thresh1 = 4096
net.ipv6.neigh.default.gc_thresh2 = 8192
net.ipv6.neigh.default.gc_thresh3 = 16384

net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.conf.all.forwarding = 1

# ===== IPv6 TCP =====
net.ipv6.tcp_mtu_probing = 1
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
    
    # 计算RAM的GB数（向上取整）
    RAM_GB=$(( (RAM + 1023) / 1024 ))

    # ===== 连接数计算 =====
    # 1c1g: 500/100, 2c4g: 2000/200, 4c4g以上: -1/-1
    if [[ $CPU -eq 1 ]] && [[ $RAM_GB -eq 1 ]]; then
        max_conn=500
        per_conn=100
    elif [[ $CPU -eq 2 ]] && [[ $RAM_GB -eq 4 ]]; then
        max_conn=2000
        per_conn=200
    elif [[ $CPU -ge 4 ]] && [[ $RAM_GB -ge 4 ]]; then
        max_conn=-1
        per_conn=-1
    else
        # 其他配置的插值计算
        # 基于CPU和RAM的线性插值
        cpu_weight=$((CPU * 100))
        ram_weight=$((RAM_GB * 25))
        
        # 计算相对于1c1g的增量
        base_increase=$(( (cpu_weight + ram_weight) / 2 ))
        per_increase=$(( (cpu_weight + ram_weight) / 20 ))
        
        # 计算最终值
        max_conn=$((500 + base_increase))
        per_conn=$((100 + per_increase))
        
        # 限制不超过2c4g的值
        [ $max_conn -gt 2000 ] && max_conn=2000
        [ $per_conn -gt 200 ] && per_conn=200
    fi

    # ===== 磁盘缓存计算 =====
    # 物理内存的1/8
    cache=$((RAM/8))
    # 设置最小缓存为32MB
    [ $cache -lt 32 ] && cache=32
    write=$((cache/4))

    # ===== 发送缓冲计算 =====
    # 1c1g: 2048/512, 4c4g以上: 10240/3072
    if [[ $CPU -eq 1 ]] && [[ $RAM_GB -eq 1 ]]; then
        buf=2048
        buf_low=512
    elif [[ $CPU -ge 4 ]] && [[ $RAM_GB -ge 4 ]]; then
        buf=10240
        buf_low=3072
    else
        # 其他配置的线性插值
        # 基于CPU核心数的插值
        if [ $CPU -eq 1 ]; then
            buf=2048
            buf_low=512
        elif [ $CPU -eq 2 ]; then
            buf=4096
            buf_low=1024
        elif [ $CPU -eq 3 ]; then
            buf=6144
            buf_low=1792
        else
            # CPU>=4但RAM<4G的情况
            buf=8192
            buf_low=2048
        fi
    fi

    # ===== 上传槽计算 =====
    # 根据您的需求，设置为-1表示无限
    upload=-1
    upload_t=-1

    # ===== AIO线程计算 =====
    if [ $CPU -le 1 ]; then aio=4
    elif [ $CPU -le 2 ]; then aio=8
    elif [ $CPU -le 4 ]; then aio=16
    else aio=32; fi

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
        echo "2. 启动"
        echo "3. 停止"
        echo "4. 重启"
        echo "5. 备份种子"
        echo "6. 恢复种子"
        echo "7. 卸载"
        echo "0. 返回主菜单"
        print_line
        
        read -p "请选择 (0-8): " choice
        
        case $choice in
            1) qb_install ;;
            2) 
                qb_start
                print_ok "qBittorrent 已启动"
                pause
                ;;
            3) 
                qb_stop
                print_ok "qBittorrent 已停止"
                pause
                ;;
            4) qb_restart; pause ;;
            5) qb_backup ;;
            6) qb_restore ;;
            7) qb_uninstall ;;
            0) break ;;
            *) 
                print_err "无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
#                             脚本目录管理
# =============================================================================
run_yuju_toolbox() {
    clear
    print_title "运行 yuju 工具箱"
    echo -e "${CYAN}正在下载并运行 yuju 工具箱...${NC}"
    
    # 创建临时目录
    local temp_dir="/tmp/yuju_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载并运行
    curl -sS -O https://raw.githubusercontent.com/yuju520/YujuToolBox/main/yuju.sh
    chmod +x yuju.sh
    ./yuju.sh
    
    cd - >/dev/null
    pause
}

run_kejilion_toolbox() {
    clear
    print_title "运行 科技lion 工具箱"
    echo -e "${CYAN}正在下载并运行 科技lion 工具箱...${NC}"
    
    # 创建临时目录
    local temp_dir="/tmp/kejilion_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载并运行
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh
    chmod +x kejilion.sh
    ./kejilion.sh
    
    cd - >/dev/null
    pause
}

script_directory_menu() {
    while true; do
        clear
        print_simple_title
        print_title "脚本目录"
        
        echo "1. yuju 工具箱"
        echo "   一款多功能 Linux 工具箱，包含系统优化、测试、工具下载等功能"
        echo
        echo "2. 科技lion 工具箱"
        echo "   强大的服务器管理工具箱，包含 Docker 管理、网站部署、系统优化等"
        echo
        echo "0. 返回主菜单"
        print_line
        
        read -p "请选择 (0-2): " choice
        
        case $choice in
            1) run_yuju_toolbox ;;
            2) run_kejilion_toolbox ;;
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
        echo "6. 脚本目录"  # 新增选项
        echo "0. 退出"
        print_line
        
        read -p "请选择 (0-6): " choice
        
        case $choice in
            1) pt_opt ;;
            2) vless_opt ;;
            3) view_optimization ;;
            4) install_tcp_algo ;;
            5) qb_menu ;;
            6) script_directory_menu ;;  # 新增功能
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

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
BBR_CONFIG_FILE="/etc/sysctl.d/99-bbr3-dualstack.conf"
SYSCTL_MAIN_FILE="/etc/sysctl.conf"
TUNE_FLAG="/var/run/tune_sys_optimized"

# ===== UI优化 =====
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

# ===== 简洁的标题函数 =====
print_title() {
    echo
    echo "========================================"
    echo -e "${BLUE}$1${NC}"
    echo "========================================"
    echo
}
print_line() { echo "----------------------------------------"; }
print_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
print_err() { echo -e "${RED}[✗]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }
pause() { echo; echo -n "按回车键继续..."; read; }

# ===== 检测当前TCP拥塞控制算法 =====
detect_current_cc() {
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "cubic")
    CURRENT_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "fq_codel")
    echo -e "${CYAN}当前TCP算法: $CURRENT_CC${NC}"
    echo -e "${CYAN}当前队列算法: $CURRENT_QDISC${NC}"
    if [[ "$CURRENT_CC" == "bbr" || "$CURRENT_CC" == "bbr2" || "$CURRENT_CC" == "bbr3" || "$CURRENT_CC" == "bbrx" ]]; then
        echo -e "${GREEN}✅ 已启用BBR系列算法${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ 未启用BBR系列算法${NC}"
        return 1
    fi
}

# ===== 检测是否安装了BBRx所需内核 =====
detect_bbrx_kernel() {
    # 检测BBRx模块是否已加载
    if lsmod | grep -q bbrx || sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbrx; then
        echo -e "${GREEN}✅ 已安装BBRx内核模块${NC}"
        return 0
    fi
    
    # 检测是否安装了较新的内核（BBRx通常需要较新内核）
    local current_kernel=$(uname -r | cut -d'-' -f1)
    local current_major=$(echo $current_kernel | cut -d'.' -f1)
    local current_minor=$(echo $current_kernel | cut -d'.' -f2)
    
    # 假设4.9+内核支持BBRx，但建议5.4+
    if [ $current_major -ge 5 ] || ([ $current_major -eq 4 ] && [ $current_minor -ge 9 ]); then
        echo -e "${YELLOW}⚠️ 内核版本支持BBRx，但模块未加载${NC}"
        return 1
    else
        echo -e "${RED}❌ 内核版本过低，需要4.9+内核${NC}"
        return 2
    fi
}

# ===== 检测系统调优脚本是否已运行 =====
detect_tune_applied() {
    # 检测标志文件是否存在
    if [ -f "$TUNE_FLAG" ]; then
        echo -e "${GREEN}✅ 系统调优脚本 (tune.sh -t) 已运行${NC}"
        return 0
    fi
    
    # 检查tune.sh是否设置了关键参数
    if sysctl -n net.core.default_qdisc 2>/dev/null | grep -q "fq" && \
       sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        echo -e "${GREEN}✅ 系统调优已应用 (检测到BBR+fq)${NC}"
        touch "$TUNE_FLAG"  # 创建标志文件
        return 0
    else
        echo -e "${YELLOW}⚠️ 系统调优未运行${NC}"
        return 1
    fi
}

# ===== 运行系统调优脚本 (tune.sh -t) =====
run_system_tune() {
    print_info "正在运行系统调优脚本 (tune.sh -t)..."
    
    # 检查是否已运行
    detect_tune_applied
    if [ $? -eq 0 ]; then
        print_ok "系统调优已应用，跳过"
        return 0
    fi
    
    # 下载并运行tune.sh -t
    echo -e "${YELLOW}[!] 正在下载并运行系统调优脚本，这可能需要几分钟...${NC}"
    
    if bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -t; then
        print_ok "系统调优脚本执行成功"
        touch "$TUNE_FLAG"  # 创建标志文件
        return 0
    else
        print_err "系统调优脚本执行失败"
        return 1
    fi
}

# ===== 系统优化辅助函数 =====
set_cc(){
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    for i in bbrx bbr3 bbr2 bbrplus bbr
    do
        if echo $avail | grep -q $i; then
            sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null 2>&1
            print_ok "使用 TCP 算法: $i"
            return
        fi
    done
    
    # 如果没有找到任何BBR算法，尝试安装内核
    print_warn "未找到BBR系列算法，将尝试安装优化内核..."
    auto_install_bbrx
    
    # 重新检测
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    for i in bbrx bbr3 bbr2 bbr
    do
        if echo $avail | grep -q $i; then
            sysctl -w net.ipv4.tcp_congestion_control=$i >/dev/null 2>&1
            print_ok "使用 TCP 算法: $i"
            return
        fi
    done
    
    print_err "无法启用BBR，使用系统默认算法"
}

apply_sysctl(){
    print_info "应用系统优化参数..."
    sysctl --system >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_ok "系统参数已应用"
    else
        print_err "应用系统参数失败"
    fi
}

# ===== 检测内核是否为最新 =====
check_kernel_update() {
    print_info "检测内核更新..."
    
    if [[ -f /etc/debian_version ]] || grep -qi "ubuntu" /etc/os-release; then
        # Debian/Ubuntu系统
        apt update >/dev/null 2>&1
        kernel_updates=$(apt list --upgradable 2>/dev/null | grep -E "linux-image|linux-headers" | wc -l)
        
        if [ $kernel_updates -gt 0 ]; then
            echo -e "${YELLOW}⚠️ 检测到内核更新可用${NC}"
            apt list --upgradable 2>/dev/null | grep -E "linux-image|linux-headers"
            
            read -p "是否更新内核？(y/N，默认N): " update_kernel
            if [[ $update_kernel =~ ^[Yy]$ ]]; then
                print_info "正在更新内核..."
                apt upgrade -y linux-image-* linux-headers-*
                if [ $? -eq 0 ]; then
                    print_ok "内核更新完成"
                    echo -e "${YELLOW}[!] 需要重启系统以应用新内核${NC}"
                    read -p "是否现在重启？(y/N，默认N): " reboot_now
                    if [[ $reboot_now =~ ^[Yy]$ ]]; then
                        reboot
                    fi
                else
                    print_err "内核更新失败"
                fi
            else
                print_warn "跳过内核更新"
            fi
        else
            print_ok "内核已是最新版本"
        fi
    elif [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
        # CentOS/RHEL系统
        kernel_updates=$(yum check-update 2>/dev/null | grep -E "^kernel|^kernel-" | wc -l)
        
        if [ $kernel_updates -gt 0 ]; then
            echo -e "${YELLOW}⚠️ 检测到内核更新可用${NC}"
            yum check-update 2>/dev/null | grep -E "^kernel|^kernel-"
            
            read -p "是否更新内核？(y/N，默认N): " update_kernel
            if [[ $update_kernel =~ ^[Yy]$ ]]; then
                print_info "正在更新内核..."
                yum update -y kernel kernel-*
                if [ $? -eq 0 ]; then
                    print_ok "内核更新完成"
                    echo -e "${YELLOW}[!] 需要重启系统以应用新内核${NC}"
                    read -p "是否现在重启？(y/N，默认N): " reboot_now
                    if [[ $reboot_now =~ ^[Yy]$ ]]; then
                        reboot
                    fi
                else
                    print_err "内核更新失败"
                fi
            else
                print_warn "跳过内核更新"
            fi
        else
            print_ok "内核已是最新版本"
        fi
    else
        print_warn "不支持的系统类型，跳过内核更新检测"
    fi
}

# ===== BBRx 安装函数 =====
auto_install_bbrx() {
    # 检测是否已经安装了bbrx
    if detect_bbrx_kernel; then
        print_ok "BBRx 已安装"
        return
    fi

    # 在安装BBRx前检测内核更新
    check_kernel_update
    
    print_info "检测到未安装 BBRx 优化内核，正在自动安装..."
    
    # 检查是否支持虚拟化环境
    local virt_tech=$(systemd-detect-virt 2>/dev/null || echo "none")
    if [[ "$virt_tech" == "lxc" || "$virt_tech" == "LXC" ]]; then
        print_err "LXC容器不支持BBRx安装"
        return 1
    fi

    # 检查操作系统类型
    if [[ -f /etc/debian_version ]] || grep -qi "ubuntu" /etc/os-release; then
        print_info "正在安装 BBRx (适用于Debian/Ubuntu)..."
        echo -e "${YELLOW}[!] 正在下载并运行BBRx安装脚本，这可能需要几分钟...${NC}"
        
        if bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Tune/main/tune.sh) -x; then
            print_ok "BBRx 安装完成"
            echo -e "${YELLOW}[!] 注意：需要重启系统才能生效，请执行: reboot${NC}"
            return 0
        else
            print_err "BBRx 安装失败"
            return 1
        fi
    elif [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
        print_err "CentOS/RHEL系统暂不支持自动安装BBRx"
        echo -e "${YELLOW}[!] 请手动安装较新内核后重试${NC}"
        return 1
    else
        print_err "不支持的操作系统"
        return 1
    fi
}

# ===== PT优化 (高并发、大吞吐、抢种) =====
pt_opt(){
    clear
    print_title "PT刷流优化"
    
    # 显示当前状态
    echo -e "${CYAN}[*] 检测当前系统状态...${NC}"
    detect_current_cc
    detect_tune_applied
    detect_bbrx_kernel
    
    # 询问用户是否继续
    echo
    echo -e "${YELLOW}[!] 即将执行以下操作:${NC}"
    echo "1. 运行系统调优 (tune.sh -t)"
    echo "2. 应用PT刷流专用优化"
    echo "3. 检测并安装BBRx内核（如需）"
    echo
    read -p "是否继续？(y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warn "操作已取消"
        pause
        return
    fi
    
    # 第一步：运行系统调优
    run_system_tune
    
    # 第二步：应用PT专用优化
    print_info "应用PT刷流专用优化..."
    
    cat > "$CONFIG_FILE" <<EOF
# ===== PT刷流优化配置 =====
# 目标：高并发、大吞吐、抢种性能
# 注意：此配置在系统调优基础上叠加

# ===== 大缓冲区 (应对大量连接) =====
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# ===== 高并发连接 =====
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 16384

# ===== 抢种强化 (降低延迟，快速发包) =====
net.ipv4.tcp_notsent_lowat = 8192
net.ipv4.tcp_limit_output_bytes = 4194304
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_slow_start_after_idle = 0

# ===== TCP基础优化 =====
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# ===== 连接跟踪表大小 (应对大量连接) =====
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
net.ipv6.tcp_mtu_probing = 1
EOF
    
    set_cc
    apply_sysctl
    
    # 第三步：检测并安装BBRx内核
    auto_install_bbrx
    
    # 显示最终状态
    echo
    echo -e "${CYAN}[*] 优化完成，最终状态:${NC}"
    detect_current_cc
    detect_tune_applied
    detect_bbrx_kernel
    
    print_ok "PT刷流优化完成"
    echo -e "${YELLOW}[!] 提示：如果安装了新内核，需要重启系统${NC}"
    pause
}

# ===== VLESS优化 (稳定、低延迟) =====
vless_opt(){
    clear
    print_title "VLESS节点优化"
    
    # 显示当前状态
    echo -e "${CYAN}[*] 检测当前系统状态...${NC}"
    detect_current_cc
    detect_tune_applied
    detect_bbrx_kernel
    
    # 询问用户是否继续
    echo
    echo -e "${YELLOW}[!] 即将执行以下操作:${NC}"
    echo "1. 运行系统调优 (tune.sh -t)"
    echo "2. 应用VLESS节点专用优化"
    echo "3. 检测并安装BBRx内核（如需）"
    echo
    read -p "是否继续？(y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warn "操作已取消"
        pause
        return
    fi
    
    # 第一步：运行系统调优
    run_system_tune
    
    # 第二步：应用VLESS专用优化
    print_info "应用VLESS节点专用优化..."
    
    cat > "$CONFIG_FILE" <<EOF
# ===== VLESS节点优化配置 =====
# 目标：稳定、低延迟、公平共享带宽
# 注意：此配置在系统调优基础上叠加

# ===== 均衡缓冲区 (避免单连接占用过多内存) =====
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432

# ===== 适中并发连接 =====
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192

# ===== 延迟优化 (启用TCP早期重传与快速恢复) =====
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 1
net.ipv4.tcp_slow_start_after_idle = 0

# ===== TCP基础优化 =====
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# ===== 启用ECN (显式拥塞通知，与BBR协作更好) =====
net.ipv4.tcp_ecn = 1

# ===== 连接跟踪表大小 =====
net.netfilter.nf_conntrack_max = 524288

# ===== IPv6优化 =====
net.ipv6.route.max_size = 524288
net.ipv6.neigh.default.gc_thresh1 = 2048
net.ipv6.neigh.default.gc_thresh2 = 4096
net.ipv6.neigh.default.gc_thresh3 = 8192
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.conf.all.forwarding = 1
net.ipv6.tcp_mtu_probing = 1
EOF
    
    set_cc
    apply_sysctl
    
    # 第三步：检测并安装BBRx内核
    auto_install_bbrx
    
    # 显示最终状态
    echo
    echo -e "${CYAN}[*] 优化完成，最终状态:${NC}"
    detect_current_cc
    detect_tune_applied
    detect_bbrx_kernel
    
    print_ok "VLESS节点优化完成"
    echo -e "${YELLOW}[!] 提示：如果安装了新内核，需要重启系统${NC}"
    pause
}

# ===== 查看当前优化状态 =====
view_optimization() {
    clear
    print_title "当前优化状态"
    
    echo -e "${GREEN}=== 系统基本信息 ===${NC}"
    echo "主机名: $(hostname)"
    echo "操作系统: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo "未知")"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    
    # 检测当前TCP算法
    detect_current_cc
    
    # 检测系统调优状态
    detect_tune_applied
    
    # 检测BBRx内核状态
    detect_bbrx_kernel
    
    # TCP拥塞控制算法
    echo -e "\n${GREEN}=== TCP拥塞控制算法 ===${NC}"
    CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    echo "当前算法: $CURRENT_CC"
    echo "可用算法: $(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "未知")"
    
    # 队列算法
    echo -e "\n${GREEN}=== 队列算法 ===${NC}"
    CURRENT_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    echo "当前队列: $CURRENT_QDISC"
    
    # IPv4网络核心参数
    echo -e "\n${GREEN}=== IPv4网络核心参数 ===${NC}"
    sysctl net.core.rmem_max net.core.wmem_max net.core.netdev_max_backlog net.core.somaxconn 2>/dev/null || echo "参数不可用"
    
    # IPv6优化状态
    echo -e "\n${GREEN}=== IPv6优化状态 ===${NC}"
    sysctl net.ipv6.conf.all.accept_ra net.ipv6.conf.all.accept_redirects 2>/dev/null || echo "IPv6未配置"
    
    # 文件描述符限制
    echo -e "\n${GREEN}=== 文件描述符限制 ===${NC}"
    ulimit -n
    
    # 系统负载
    echo -e "\n${GREEN}=== 系统负载 ===${NC}"
    uptime
    
    # 显示优化配置文件状态
    echo -e "\n${GREEN}=== 优化配置文件状态 ===${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo "配置文件: $CONFIG_FILE (存在)"
        echo -e "${CYAN}最后修改时间: $(stat -c %y "$CONFIG_FILE" 2>/dev/null || echo "未知")${NC}"
    else
        echo "配置文件: $CONFIG_FILE (不存在)"
    fi
    
    if [ -f "$TUNE_FLAG" ]; then
        echo "系统调优标志: 已运行 (tune.sh -t)"
    else
        echo "系统调优标志: 未运行"
    fi
    
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
qb_restart(){
    print_warn "正在重启 qBittorrent..."
    qb_stop
    qb_start
    print_ok "qBittorrent 已重启"
}
qb_login(){
    curl -s -c $COOKIE --data "username=$QB_USER&password=$QB_PASS" $QB_URL/api/v2/auth/login > /dev/null
}

# ===== 核心优化 =====
qb_optimize(){
    clear
    print_title "qBittorrent 性能优化"

    qb_stop
    mkdir -p /pt/qBittorrent/config

    # ==============================
    # ⚙️ 生成基础配置文件
    # ==============================
    cat > $QB_CONF <<EOF
[Preferences]
General\\Locale=zh
Downloads\\SavePath=/pt/downloads
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
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
WebUI\\HostHeaderValidation=false
EOF

    qb_start
    qb_login

    # ==============================
    # 📊 获取系统信息
    # ==============================
    RAM=$(free -m | awk '/Mem:/ {print $2}')
    CPU=$(nproc)
    RAM_GB=$(( (RAM + 1023) / 1024 ))

    # ==============================
    # 🔢 连接数与上传槽（基于 min(CPU, 内存GB) 的正确公式）
    # 根据基准点推导：
    # 1c2g -> [500, 50, 100, 10]   (min=1)
    # 2c4g -> [1000, 100, 200, 20] (min=2)
    # 4c8g -> [2000, 200, 400, 40] (min=4)
    # 计算公式：参数 = min(CPU, 内存GB) * 系数
    # 系数分别为：500, 50, 100, 10
    # ==============================
    # 1. 计算基准值：取CPU和内存GB的较小者
    if [ $CPU -lt $RAM_GB ]; then
        BASE_VALUE=$CPU
    else
        BASE_VALUE=$RAM_GB
    fi

    # 2. 定义基准系数
    COEFF_MAX_CONN=500
    COEFF_PER_CONN=50
    COEFF_UPLOAD=100
    COEFF_UPLOAD_T=10

    # 3. 计算最终参数
    max_conn=$((BASE_VALUE * COEFF_MAX_CONN))
    per_conn=$((BASE_VALUE * COEFF_PER_CONN))
    upload=$((BASE_VALUE * COEFF_UPLOAD))
    upload_t=$((BASE_VALUE * COEFF_UPLOAD_T))

    # ==============================
    # 💾 磁盘缓存（保持原逻辑）
    # ==============================
    cache=$((RAM/8))
    [ $cache -lt 32 ] && cache=32
    write=$((cache/4))

    # ==============================
    # 💽 async IO（恢复原脚本阶梯式逻辑）
    # ==============================
    if [ $CPU -le 1 ]; then
        aio=4
    elif [ $CPU -le 2 ]; then
        aio=8
    elif [ $CPU -le 4 ]; then
        aio=16
    else
        aio=32
    fi
    
    # ==============================
    # 📡 send buffer（设置合理上限）
    # ==============================
    # 建议系数（单位：KB）- 已从原4096/1024调低
    BUF_PER_CPU=2048
    BUF_LOW_PER_CPU=512
    
    # 计算基础值
    buf_base=$((BUF_PER_CPU * CPU))
    buf_low_base=$((BUF_LOW_PER_CPU * CPU))
    
    # 设置安全上限（避免内存过载）
    # 高水位线不超过12MB，低水位线不超过3MB
    BUF_MAX=12288    # 12 * 1024 KB
    BUF_LOW_MAX=3072 # 3 * 1024 KB
    
    # 应用上限
    if [ $buf_base -gt $BUF_MAX ]; then
        buf=$BUF_MAX
    else
        buf=$buf_base
    fi
    
    if [ $buf_low_base -gt $BUF_LOW_MAX ]; then
        buf_low=$BUF_LOW_MAX
    else
        buf_low=$buf_low_base
    fi

    mkdir -p /pt/downloads

    print_line
    echo -e "${GREEN}内存:${RAM}MB CPU:${CPU}${NC}"
    echo "连接: $max_conn / $per_conn"
    echo "上传: $upload / $upload_t"
    echo "缓存: $cache / $write"
    echo "缓冲: $buf / $buf_low"
    echo "AIO: $aio"
    print_line

    # ==============================
    # 🚀 写入 qB 配置
    # ==============================
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

    curl -s -b $COOKIE --data-urlencode "json={
    \"enable_dht\":false,
    \"enable_pex\":false,
    \"enable_lsd\":false
    }" $QB_URL/api/v2/app/setPreferences >/dev/null

    print_ok "优化完成（最终修正版）"
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
    if [[ "$ARCH" == "x86_64" ]]; then
    # x86_64 架构，使用 qBittorrent-4.3.9 + libtorrent-v1.2.20 组合
    QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    # ARM64 架构，需要对应目录
    QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
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
    chmod +x $QB_BIN
    file $QB_BIN
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
    qb_stop >/dev/null 2>&1
    echo
    echo -e "${YELLOW}================ 配置 qBittorrent ================${NC}"
    echo
    echo -e "${YELLOW}设置端口:${NC}"
    read -p "WebUI端口 (默认: 8080): " WEB_PORT
    [ -z "$WEB_PORT" ] && WEB_PORT="8080"
    read -p "监听端口 (默认: 57777): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT="57777"
    QB_WEB_PORT=$WEB_PORT
    QB_LISTEN_PORT=$LISTEN_PORT
    QB_URL="http://127.0.0.1:$QB_WEB_PORT"
    echo
    echo -e "${YELLOW}请输入 WebUI 账号（默认 admin）:${NC}"
    start_time=$(date +%s)
    read input_user
    echo -e "${YELLOW}请输入 WebUI 密码（默认 adminadmin）:${NC}"
    read input_pass
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    [ -z "$input_user" ] && input_user="admin"
    [ -z "$input_pass" ] && input_pass="adminadmin"
    HASH=$(gen_qb_password "$input_pass")
    # 更新配置文件中的端口和认证信息
    sed -i '/Connection\\PortRangeMin/d' $QB_CONF
    sed -i '/Connection\\PortRangeMax/d' $QB_CONF
    sed -i '/WebUI\\Port/d' $QB_CONF
    sed -i '/WebUI\\Username/d' $QB_CONF
    sed -i '/WebUI\\Password_PBKDF2/d' $QB_CONF

    cat >> $QB_CONF <<EOF
Connection\\PortRangeMin=$QB_LISTEN_PORT
Connection\\PortRangeMax=$QB_LISTEN_PORT
WebUI\\Port=$QB_WEB_PORT
WebUI\\Username=$input_user
WebUI\\Password_PBKDF2="$HASH"
EOF

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

# ===== qBittorrent 管理菜单 =====
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
            2) qb_start; print_ok "qBittorrent 已启动"; pause ;;
            3) qb_stop; print_ok "qBittorrent 已停止"; pause ;;
            4) qb_restart; pause ;;
            5) qb_backup ;;
            6) qb_restore ;;
            7) qb_uninstall ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 脚本目录管理 =====
run_yuju_toolbox() {
    clear
    print_title "运行 yuju 工具箱"
    echo -e "${CYAN}正在下载并运行 yuju 工具箱...${NC}"
    local temp_dir="/tmp/yuju_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
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
    local temp_dir="/tmp/kejilion_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh
    chmod +x kejilion.sh
    ./kejilion.sh
    cd - >/dev/null
    pause
}
run_ipsentinel_toolbox() {
    clear
    print_title "运行 哨兵洗白ip养护"
    echo -e "${CYAN}正在下载并运行 哨兵洗白ip养护...${NC}"
    local temp_dir="/tmp/install_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    curl -sS -O https://raw.githubusercontent.com/hotyue/IP-Sentinel/main/core/install.sh
    chmod +x install.sh
    ./install.sh
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
        echo "3. 哨兵洗白ip养护"
        echo "   强大的洗白ip工具"
        echo
        echo "0. 返回主菜单"
        print_line
        read -p "请选择 (0-3): " choice
        case $choice in
            1) run_yuju_toolbox ;;
            2) run_kejilion_toolbox ;;
            3) run_ipsentinel_toolbox ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 主菜单 =====
main_menu(){
    while true; do
        clear
        print_simple_title
        echo "1. PT刷流优化 (高并发/大吞吐)"
        echo "2. VLESS节点优化 (稳定/低延迟)"
        echo "3. 查看当前优化状态"
        echo "4. qBittorrent 管理"
        echo "5. 脚本目录"
        echo "0. 退出"
        print_line
        read -p "请选择 (0-6): " choice
        case $choice in
            1) pt_opt ;;
            2) vless_opt ;;
            3) view_optimization ;;
            4) qb_menu ;;
            5) script_directory_menu ;;
            0) clear; echo; echo "感谢使用！"; echo; exit 0 ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 脚本入口 =====
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 此脚本必须以 root 权限运行${NC}"
    echo "请使用: sudo bash $0"
    exit 1
fi
main_menu

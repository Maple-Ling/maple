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

# ============================================================
#  +----  UI 引擎 v3 -- 炫酷 | 居中 | 响应式自适应宽度  ----+
# ============================================================

# --- 颜色定义 ---
R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[34m'; C='\033[36m'; M='\033[35m'; W='\033[37m'; K='\033[0m'
RB='\033[41m'; GB='\033[42m'; YB='\033[43m'; BB='\033[44m'; CB='\033[46m'; MB='\033[45m'; WB='\033[47m'
BR='\033[1;31m'; BG='\033[1;32m'; BY='\033[1;33m'; BBM='\033[1;34m'; BC='\033[1;36m'; BM='\033[1;35m'; BW='\033[1;37m'
DIM='\033[2m'; ND='\033[0m'

# 动态获取终端宽度 (每次调用重新检测，实现自适应放大缩小)
get_w() {
    local w=$(tput cols 2>/dev/null)
    [ -z "$w" ] && w=${COLUMNS:-80}
    [ "$w" -lt 60 ] && w=60
    echo "$w"
}

# 计算字符串的视觉宽度 (完美处理中文、全角字符和 Emoji 的对齐偏移)
get_vis_len() {
    local s=$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')
    local chars=$(echo -n "$s" | wc -m 2>/dev/null || echo ${#s})
    local bytes=$(echo -n "$s" | wc -c 2>/dev/null || echo ${#s})
    local extra=$(( (bytes - chars) / 2 ))
    echo $(( chars + extra ))
}

# 响应式水平分割线
panel() {
    local color="${1:-$C}"
    local w=$(get_w)
    local line_w=$(( w * 8 / 10 ))
    local pad=$(( (w - line_w) / 2 ))
    local line=$(printf "%*s" "$line_w" "" | tr ' ' '-')
    printf "%${pad}s" ""
    echo -e "${color}${line}${K}"
}

# 系统信息条 (居中)
sysinfo_bar() {
    local cpu=$(nproc 2>/dev/null || echo "?")
    local mem=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}' || echo "?")
    local mem_gb=$((mem / 1024))
    [ "$mem_gb" -lt 1 ] && mem_gb="${mem}MB" || mem_gb="${mem_gb}GB"
    local os=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 | cut -d' ' -f1 || echo "Linux")
    local ver=$(cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'"' -f2 || echo "")
    
    local info_str="—— ${os} ${ver}  |  ${cpu}核  |  ${mem_gb} ——"
    local w=$(get_w)
    local len=$(get_vis_len "$info_str")
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${DIM}${info_str}${K}"
}

# 主界面 Banner (动态居中)
show_banner() {
    clear
    local w=$(get_w)
    echo
    local logo=(
        "██╗    ██╗██╗   ██╗    ██╗██╗███████╗"
        "██║    ██║██║   ██║    ██║██║██╔════╝"
        "██║ █╗ ██║██║   ██║    ██║██║█████╗  "
        "██║███╗██║██║   ██║██   ██║██║██╔══╝  "
        "╚███╔███╔╝╚██████╔╝╚█████╔╝██║███████╗"
        " ╚══╝╚══╝  ╚═════╝  ╚════╝ ╚═╝╚══════╝"
    )
    for line in "${logo[@]}"; do
        local len=${#line}
        local pad=$(( (w - len) / 2 ))
        [ "$pad" -lt 0 ] && pad=0
        printf "%${pad}s" ""
        echo -e "${BM}${line}${K}"
    done
    echo
    
    local title_str="无界刷流优化工具箱 v3.0  |  PT · VLESS · qB · Vertex"
    local t_len=$(get_vis_len "$title_str")
    local t_pad=$(( (w - t_len) / 2 ))
    [ "$t_pad" -lt 0 ] && t_pad=0
    printf "%${t_pad}s" ""
    echo -e "${BG}无界刷流优化工具箱 v3.0${K}  ${DIM}|  PT · VLESS · qB · Vertex${K}"
    echo
    sysinfo_bar
    echo
}

# 子菜单横向居中半包围框
show_submenu_banner() {
    clear
    local title="$1"
    local sub="WU JIE TOOLBOX v3.0"
    local color="${2:-$BC}"
    local w=$(get_w)
    
    local box_w=60
    local pad_left=$(( (w - box_w) / 2 ))
    local sp=$(printf "%${pad_left}s" "")

    echo
    local top_bar=$(printf "%*s" $((box_w - 2)) "" | tr ' ' '-')
    echo -e "${sp}${color}┌${top_bar}┐${K}"

    local t_len=$(get_vis_len "$title")
    local t_pad=$(( (box_w - 2 - t_len) / 2 ))
    local t_sp1=$(printf "%*s" "$t_pad" "")
    local t_sp2=$(printf "%*s" $((box_w - 2 - t_len - t_pad)) "")
    echo -e "${sp}${color}│${t_sp1}${BR}${title}${color}${t_sp2}│${K}"

    local s_len=$(get_vis_len "$sub")
    local s_pad=$(( (box_w - 2 - s_len) / 2 ))
    local s_sp1=$(printf "%*s" "$s_pad" "")
    local s_sp2=$(printf "%*s" $((box_w - 2 - s_len - s_pad)) "")
    echo -e "${sp}${color}│${s_sp1}${DIM}${sub}${K}${color}${s_sp2}│${K}"

    local bot_bar=$(printf "%*s" $((box_w - 2)) "" | tr ' ' '-')
    echo -e "${sp}${color}└${bot_bar}┘${K}"
    echo
    sysinfo_bar
    echo
}

# 主菜单与子菜单的居中行渲染
mrow() {
    local num="$1"
    local icon="$2"
    local name="$3"
    local desc="$4"
    local num_color="${5:-$W}"
    local desc_color="${DIM}"
    local w=$(get_w)
    
    local container_w=56 
    
    local left_str="[ ${num} ] ${icon}  ${name}"
    local left_len=$(get_vis_len "${left_str}")
    
    local right_str="${desc}"
    local right_len=$(get_vis_len "$right_str")

    local spaces_needed=$(( container_w - left_len - right_len ))
    [ "$spaces_needed" -lt 2 ] && spaces_needed=2

    local space_pad=$(printf "%${spaces_needed}s" "")

    local global_pad=$(( (w - container_w) / 2 ))
    [ "$global_pad" -lt 0 ] && global_pad=0
    local global_sp=$(printf "%${global_pad}s" "")

    local colored_left="${num_color}[ ${num} ]${K} ${icon} ${num_color}${name}${K}"
    local colored_right="${desc_color}${desc}${K}"

    echo -e "${global_sp}${colored_left}${space_pad}${colored_right}"
    echo 
}

mrow2() {
    local num="$1"
    local icon="$2"
    local name="$3"
    local num_color="${4:-$W}"
    local w=$(get_w)
    local container_w=56

    local left_str="[ ${num} ] ${icon}  ${name}"
    local global_pad=$(( (w - container_w) / 2 ))
    [ "$global_pad" -lt 0 ] && global_pad=0
    local global_sp=$(printf "%${global_pad}s" "")

    local colored_left="${num_color}[ ${num} ]${K} ${icon} ${num_color}${name}${K}"
    echo -e "${global_sp}${colored_left}"
    echo
}

# 居中底部提示符并读取输入
centered_read() {
    local text="$1"
    local color="${2:-$BC}"
    local varname="$3"
    local w=$(get_w)

    local prompt_str="▸ ${text}: "
    local len=$(get_vis_len "$prompt_str")
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0

    printf "%${pad}s" ""
    echo -en "${color}${prompt_str}${K}"
    read -r "$varname"
}

# 居中日志信息打印
msg_box() {
    local color="$1"
    local prefix="$2"
    local text="$3"
    local w=$(get_w)
    local str=" ${prefix}  ${text} "
    local len=$(get_vis_len "$str")
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${color}${str}${K}"
}

ok_info()   { msg_box "$BG" " [OK] " "$1"; }
err_info()  { msg_box "$BR" " [!!] " "$1"; }
warn_info() { msg_box "$BY" " [!!] " "$1"; }
info_info() { msg_box "$BC" " [>]  " "$1"; }
step_info() { msg_box "$DIM" "  |   " "$1"; }

# 兼容保留旧函数
print_title()  { echo; msg_box "$BG" ">>>" "$1"; echo; }
print_line()   { echo; panel "$DIM"; echo; }
print_ok()     { ok_info "$1"; }
print_err()    { err_info "$1"; }
print_warn()   { warn_info "$1"; }
print_info()   { info_info "$1"; }

ok()    { ok_info "$1"; }
err()   { err_info "$1"; }
warn()  { warn_info "$1"; }
info()  { info_info "$1"; }
step()  { step_info "$1"; }

wait_key() {
    echo
    local w=$(get_w)
    local str="--- 按回车键继续 ---"
    local len=$(get_vis_len "$str")
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${BY}${str}${K}"
    echo
    read -r
}

cntr() {
    local text="$1" color="${2:-$BW}"
    local w=$(get_w)
    local len=$(get_vis_len "$text")
    local pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${color}${text}${K}"
}

card() {
    local title="$1" color="${2:-$BG}" sub="${3:-}"
    echo; show_submenu_banner "$title" "$color"
}

sysinfo() { sysinfo_bar; }
banner()  { show_banner; }
hr()      { panel "${1:-$C}"; }

gen_qb_password() {
python3 - <<EOF
import os, base64, hashlib
password = "$1".encode()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha512', password, salt, 100000, dklen=64)
print(f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(dk).decode()})')
EOF
}

setup_shortcut() {
    local script_path="/root/wujie.sh"
    local bin_path="/usr/local/bin/wj"
    if [ -L "$bin_path" ] && [ "$(readlink "$bin_path")" == "$script_path" ]; then
        return
    fi
    rm -f "$bin_path"
    ln -s "$script_path" "$bin_path"
    chmod +x "$bin_path"
    print_ok "快捷键 'wj' 已全自动配置"
}

get_conntrack() {
    local mem=$(free -m | awk '/Mem:/ {print $2}')
    if [ $mem -le 1024 ]; then echo 262144
    elif [ $mem -le 2048 ]; then echo 524288
    elif [ $mem -le 4096 ]; then echo 1048576
    else echo 2097152; fi
}

apply_sysctl(){
    step "应用系统优化参数..."
    sysctl --system >/dev/null 2>&1
    if [ $? -eq 0 ]; then ok "系统参数已应用"
    else err "应用系统参数失败"; fi
}

# ============================================================
#  [*] PT刷流优化 - 高并发 / 大吞吐 / 抢连接
# ============================================================
pt_opt() {
    clear
    show_submenu_banner "PT 刷流优化" "$BG"
    step "优化目标: 抢种速度最大化 | 高并发连接 | 大吞吐带宽"
    info "写入 PT 专用 sysctl 参数..."

    CONNTRACK=$(get_conntrack)

cat > "$CONFIG_FILE" <<SYSEOF
# ============================================================
#  PT 刷流优化 - 高并发 / 大吞吐 / 抢连接
#  核心: 连接数最大化 + 收发缓冲区拉满 + 抢种加速
# ============================================================
fs.file-max = 2097152
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 524288
net.core.wmem_default = 524288
net.ipv4.tcp_rmem = 4096 131072 268435456
net.ipv4.tcp_wmem = 4096 131072 268435456
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_challenge_ack_limit = 1000000
net.ipv4.tcp_window_scaling = 1
net.netfilter.nf_conntrack_max = ${CONNTRACK}
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.swappiness = 5
vm.dirty_expire_centisecs = 300
vm.dirty_writeback_centisecs = 100
net.ipv6.route.max_size = 2147483647
net.ipv6.neigh.default.gc_thresh1 = 8192
net.ipv6.neigh.default.gc_thresh2 = 16384
net.ipv6.neigh.default.gc_thresh3 = 32768
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.default.accept_ra = 1
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.tcp_mtu_probing = 1
SYSEOF

    apply_sysctl
    echo
    ok "系统参数已写入 $CONFIG_FILE"
    ok "TCP缓冲区: 256MB | conntrack: $(numfmt --to=iec $CONNTRACK)"
    ok "抢种加速: 已启用 | BBR拥塞控制: 已启用"
    wait_key
}

# ============================================================
#  [~] VLESS/Reality/Hysteria2 优化 - 低延迟 / 大带宽
# ============================================================
vless_opt() {
    clear
    show_submenu_banner "VLESS 节点优化" "$BC"
    step "优化目标: 低延迟稳定 | UDP优化 | 跑满10G/100G带宽"
    info "写入 VLESS 专用 sysctl 参数..."

    CONNTRACK=$(get_conntrack)

cat > "$CONFIG_FILE" <<SYSEOF
# ============================================================
#  VLESS/Reality/Hysteria2 优化 - 低延迟 / 大带宽
#  适用: Xray | sing-box | Reality | Hysteria2
#  核心: 延迟最小化 + UDP优化 + 带宽最大化
# ============================================================
fs.file-max = 2097152
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 524288
net.core.wmem_default = 524288
net.ipv4.tcp_rmem = 4096 262144 268435456
net.ipv4.tcp_wmem = 4096 131072 268435456
net.ipv4.udp_rmem_min = 65536
net.ipv4.udp_wmem_min = 65536
net.core.rmem_default = 524288
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq_codel
net.ipv4.tcp_challenge_ack_limit = 1000000
net.ipv4.tcp_window_scaling = 1
net.netfilter.nf_conntrack_max = ${CONNTRACK}
vm.swappiness = 5
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.dirty_expire_centisecs = 300
vm.dirty_writeback_centisecs = 100
net.ipv6.route.max_size = 2147483647
net.ipv6.neigh.default.gc_thresh1 = 8192
net.ipv6.neigh.default.gc_thresh2 = 16384
net.ipv6.neigh.default.gc_thresh3 = 32768
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.default.accept_ra = 1
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.tcp_mtu_probing = 1
SYSEOF

    apply_sysctl
    echo
    ok "系统参数已写入 $CONFIG_FILE"
    ok "UDP缓冲区: 已优化 | BBR拥塞控制: 已启用"
    ok "低延迟: 已优化 | fq_codel队列: 已启用"
    wait_key
}

# ===== qB 控制函数 =====
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
    warn "正在重启 qBittorrent..."
    qb_stop; qb_start
    ok "qBittorrent 已重启"
}
qb_login(){
    curl -s -c $COOKIE --data "username=$QB_USER&password=$QB_PASS" $QB_URL/api/v2/auth/login > /dev/null
}

# ============================================================
#  qBittorrent 核心优化
# ============================================================
qb_optimize() {
    clear
    show_submenu_banner "qBittorrent 性能优化" "$BM"

    local CPU=$(nproc)
    local RAM=$(free -m | awk '/Mem:/ {print $2}')
    local MEM_GB=$((RAM / 1024))
    [ "$MEM_GB" -eq 0 ] && MEM_GB=1
    local RAM_UNIT=$(((RAM + 127) / 256))
    [ "$RAM_UNIT" -lt 1 ] && RAM_UNIT=1

    max_conn=$(( CPU * 250 + RAM_UNIT * 150 ))
    per_conn=$(( CPU * 50 + RAM_UNIT * 10 ))
    upload=$(( CPU * 30 + RAM_UNIT * 5 ))
    upload_t=$(( CPU * 10 + RAM_UNIT * 2 ))
    cache=$(( RAM_UNIT * 16 ))
    [ "$cache" -lt 16 ] && cache=16; [ "$cache" -gt 512 ] && cache=512
    buf_base=$(( CPU * 1536 + RAM_UNIT * 384 ))
    buf=$(( buf_base > 8192 ? 8192 : buf_base )); [ "$buf" -lt 512 ] && buf=512
    buf_low_base=$(( CPU * 512 + RAM_UNIT * 128 ))
    buf_low=$(( buf_low_base > 2048 ? 2048 : buf_low_base )); [ "$buf_low" -lt 256 ] && buf_low=256
    if [ "$CPU" -le 1 ]; then aio=4
    elif [ "$CPU" -le 2 ]; then aio=8
    elif [ "$CPU" -le 3 ]; then aio=12
    elif [ "$CPU" -le 4 ]; then aio=16
    elif [ "$CPU" -le 6 ]; then aio=20
    else aio=24; fi
    [ "$max_conn" -gt 4000 ] && max_conn=4000
    [ "$per_conn" -gt 200 ] && per_conn=200
    [ "$upload" -gt 200 ] && upload=200
    [ "$upload_t" -gt 30 ] && upload_t=30

    local ram_label="${RAM}MB"
    [ "$MEM_GB" -ge 1 ] && ram_label="${MEM_GB}GB"

    echo
    step "CPU: ${CPU}核  |  内存: ${ram_label}"
    step "-------------------------------"
    ok "总连接数:     ${max_conn}  (单种: ${per_conn})"
    ok "总上传数:     ${upload}  (单种: ${upload_t})"
    ok "磁盘缓存:     ${cache}MB"
    ok "Send Buffer:  ${buf}KB / ${buf_low}KB"
    ok "Async IO:     ${aio} threads"
    echo

    qb_stop
    mkdir -p /pt/qBittorrent/config; mkdir -p /pt/downloads

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
Advanced\\AnonymousMode=false
Advanced\\trackerPort=-1
Session\\DisableAutoTMMByDefault=false
WebUI\\Address=*
WebUI\\CSRFProtection=false
WebUI\\ClickjackingProtection=false
WebUI\\HostHeaderValidation=false
EOF

    qb_start; qb_login

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

    qb_stop >/dev/null 2>&1
    qb_start
    echo
    ok "qBittorrent 优化完成"
    wait_key
}

# ===== 种子备份 / 恢复 =====
qb_backup(){
    clear
    print_title "备份种子"
    SRC="/pt/qBittorrent/data/BT_backup"
    DST="/pt/BT_backup"
    if [ ! -d "$SRC" ]; then print_err "源目录不存在: $SRC"; wait_key; return; fi
    rm -rf "$DST"; cp -r "$SRC" "$DST"
    print_ok "备份完成 -> /pt/BT_backup"
    wait_key
}
qb_restore(){
    clear
    print_title "恢复种子"
    SRC="/pt/BT_backup"; DST="/pt/qBittorrent/data/BT_backup"
    if [ ! -d "$SRC" ]; then print_err "备份不存在: /pt/BT_backup"; wait_key; return; fi
    qb_stop; mkdir -p "/pt/qBittorrent/data"; rm -rf "$DST"; cp -r "$SRC" "$DST"
    print_ok "恢复完成"
    wait_key
}

qb_install(){
    clear
    print_title "安装 qBittorrent"
    mkdir -p $QB_PATH
    ARCH=$(uname -m)
    info "当前架构: $ARCH"
    if [[ "$ARCH" == "x86_64" ]]; then
    QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
    elif [[ "$ARCH" == arm* ]]; then
        print_err "不支持的ARM架构: $ARCH"; wait_key; return
    else
        print_err "未知架构: $ARCH"; wait_key; return
    fi
    info "下载: $QB_URL_DL"
    wget -q -O $QB_BIN $QB_URL_DL
    chmod +x $QB_BIN
    
    cat > $QB_SERVICE <<EOF
[Unit]
Description=qBittorrent
After=network.target
[Service]
ExecStart=$QB_BIN --profile=/pt
Restart=always
LimitNOFILE=1048576
LimitNPROC=65535
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
    
    print_line
    info "设置 WebUI 端口:"
    read -p "    输入 WebUI 端口 (默认: 8080): " WEB_PORT
    [ -z "$WEB_PORT" ] && WEB_PORT="8080"
    
    read -p "    输入监听端口 (默认: 57777): " LISTEN_PORT
    [ -z "$LISTEN_PORT" ] && LISTEN_PORT="57777"
    
    QB_WEB_PORT=$WEB_PORT
    QB_LISTEN_PORT=$LISTEN_PORT
    QB_URL="http://127.0.0.1:$QB_WEB_PORT"
    echo
    
    start_time=$(date +%s)
    read -p "    请输入 WebUI 账号（默认 admin）: " input_user
    read -p "    请输入 WebUI 密码（默认 adminadmin）: " input_pass
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    [ -z "$input_user" ] && input_user="admin"
    [ -z "$input_pass" ] && input_pass="adminadmin"
    HASH=$(gen_qb_password "$input_pass")
    
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
        info "等待 ${wait_time}s 初始化..."
        sleep $wait_time
    fi
    qb_start >/dev/null 2>&1
    print_ok "安装完成"
    wait_key
}

qb_uninstall(){
    clear
    print_title "卸载 qBittorrent"
    warn "警告：此操作将永久删除 qBittorrent 及其配置！"
    echo
    read -p "    确认要卸载吗？(y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        qb_stop
        systemctl disable qbittorrent-nox
        rm -f $QB_BIN $QB_SERVICE
        rm -rf /pt/qBittorrent
        systemctl daemon-reload
        print_ok "已彻底卸载"
    else
        info "卸载已取消"
    fi
    wait_key
}

# ============================================================
#  Vertex 管理
# ============================================================
vertex_install() {
    clear
    print_title "Vertex 安装"

    print_info "检测Docker环境..."
    if command -v docker &> /dev/null; then
        print_ok "Docker 已安装，版本: $(docker --version)"
    else
        print_warn "Docker 未安装，正在安装..."
        if [ -f /etc/debian_version ] || grep -qi "ubuntu" /etc/os-release; then
            apt-get update
            apt-get install -y ca-certificates curl gnupg
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        else
            print_err "不支持的操作系统，请手动安装Docker"; return 1
        fi
        systemctl start docker; systemctl enable docker
        print_ok "Docker 安装完成"
    fi

    print_line
    info "设置Vertex访问端口"
    read -p "    请输入Vertex Web界面端口 (默认: 3000): " VERTEX_PORT
    VERTEX_PORT=${VERTEX_PORT:-3000}

    if netstat -tuln 2>/dev/null | grep -q ":$VERTEX_PORT "; then
        print_warn "端口 $VERTEX_PORT 已被占用"
        read -p "    请输入新的端口号: " VERTEX_PORT
    fi

    print_info "检查unzip是否安装..."
    if ! command -v unzip &> /dev/null; then
        print_warn "unzip未安装，正在安装..."
        if command -v apt-get &> /dev/null; then apt-get install -y unzip
        elif command -v yum &> /dev/null; then yum install -y unzip
        elif command -v apk &> /dev/null; then apk add --no-cache unzip
        fi
        print_ok "unzip 安装完成"
    fi

    print_info "下载 Vertex 安装包..."
    VERTEX_TMP="/tmp/vertex_install"
    mkdir -p "$VERTEX_TMP"
    cd "$VERTEX_TMP"
    wget -q -O vertex.zip "https://github.com/vortex-ai/vertex-ai/releases/latest/download/vertex-linux-amd64.zip" 2>/dev/null || \
    wget -q -O vertex.zip "https://github.com/vortex-ai/vertex-ai/releases/download/v1.0.0/vertex-linux-amd64.zip"

    if [ -f vertex.zip ]; then
        unzip -o vertex.zip -d "$VERTEX_TMP" > /dev/null 2>&1
        print_ok "Vertex 安装文件提取完成"
    else
        print_err "下载 Vertex 失败，请检查网络"
        wait_key; cd - >/dev/null; return 1
    fi

    VERTEX_DATA_DIR="/root/vertex_data"
    mkdir -p "$VERTEX_DATA_DIR"

    VERTEX_TMP_BIN=$(find "$VERTEX_TMP" -name "vertex" -o -name "vertex-linux-amd64" 2>/dev/null | head -1)
    if [ -n "$VERTEX_TMP_BIN" ]; then
        cp "$VERTEX_TMP_BIN" /usr/local/bin/vertex
        chmod +x /usr/local/bin/vertex
    fi

    cat > /etc/systemd/system/vertex.service <<EOF
[Unit]
Description=Vertex AI Container Manager
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
ExecStartPre=/usr/local/bin/dockerd-entrypoint.sh
ExecStart=/usr/local/bin/vertex
WorkingDirectory=/root/vertex_data
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
Environment="GOOS=linux"
Environment="GOARCH=amd64"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vertex
    systemctl start vertex
    sleep 3

    if systemctl is-active --quiet vertex; then
        print_ok "Vertex 服务已启动"
    else
        print_err "Vertex 服务启动失败，请检查日志"
        journalctl -u vertex --no-pager -n 20
        wait_key; cd - >/dev/null; return 1
    fi

    ip_addr=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "你的服务器IP")
    echo
    print_ok "Vertex 安装完成！"
    echo
    cntr "访问地址: http://${ip_addr}:${VERTEX_PORT}" "$BY"
    cntr "管理面板: /usr/local/bin/vertex" "$BY"
    cntr "服务状态: systemctl status vertex" "$BY"
    wait_key
    cd - >/dev/null
}

vertex_uninstall(){
    clear
    print_title "删除 Vertex"

    info "是否删除Vertex数据目录？"
    read -p "    确认删除数据目录 $VERTEX_DATA_DIR 吗？(y/N): " delete_data

    if [[ $delete_data =~ ^[Yy]$ ]]; then
        print_info "删除Vertex数据目录..."
        if [ -d "$VERTEX_DATA_DIR" ]; then rm -rf "$VERTEX_DATA_DIR"; print_ok "数据目录已删除"
        else print_warn "数据目录不存在"; fi
    else
        print_info "已跳过删除数据目录"
    fi

    echo
    info "是否卸载Docker环境？"
    echo "    1. 是，卸载Docker及所有相关组件"
    echo "    2. 否，保留Docker环境"
    read -p "    请选择 (1/2，默认2): " docker_choice

    if [[ "$docker_choice" == "1" ]]; then
        print_info "开始卸载Docker..."
        if command -v apt-get &> /dev/null; then
            apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            apt-get autoremove -y
            print_ok "Docker已卸载 (APT)"
        elif command -v yum &> /dev/null; then
            yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            print_ok "Docker已卸载 (YUM)"
        else
            print_warn "无法自动卸载Docker，请手动操作"
        fi
    else
        print_info "Docker环境已保留。"
    fi

    print_ok "Vertex 删除完成！"
    wait_key
}

# ===== Vertex 管理菜单 =====
vertex_menu() {
    while true; do
        clear
        show_submenu_banner "Vertex 管理" "$BM"
        mrow "1" "📦" "安装 Vertex"          ""  "$BC"
        mrow "2" "🗑️" "删除 Vertex"          "(可选卸载Docker)"  "$BR"
        mrow2 "0" "◀️" "返回主菜单"           "$W"
        panel "$C"
        centered_read "请选择 (0-2)" "$BC" choice
        case $choice in
            1) vertex_install ;;
            2) vertex_uninstall ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 脚本自动更新 =====
update_script() {
    clear
    print_title "检查脚本更新"
    info "正在检测远程版本..."

    local remote_url="https://raw.githubusercontent.com/Maple-Ling/maple/main/wujie.sh"
    local local_path="/root/wujie.sh"
    local temp_path="/tmp/wujie_update.sh"

    if ! curl -sL "$remote_url" -o "$temp_path"; then
        print_err "下载失败，请检查网络连接。"
        sleep 2; return
    fi

    local local_md5=$(md5sum "$local_path" 2>/dev/null | awk '{print $1}')
    local remote_md5=$(md5sum "$temp_path" | awk '{print $1}')

    if [[ "$local_md5" == "$remote_md5" ]]; then
        ok "当前已是最新版本，无需更新。"
        rm -f "$temp_path"; sleep 2
    else
        warn "检测到新版本，正在自动更新并重启..."
        mv -f "$temp_path" "$local_path"
        chmod +x "$local_path"
        ok "更新成功！正在重新载入脚本..."
        sleep 1
        exec "$local_path"
    fi
}

# ============================================================
#  qBittorrent 管理菜单
# ============================================================
qb_menu(){
    while true; do
        clear
        show_submenu_banner "qBittorrent 管理" "$BM"
        mrow "1" "⚙️"  "安装 + 优化"          "自动适配硬件"       "$BG"
        mrow "2" "▶️"  "启动"                 "systemctl start"    "$BG"
        mrow "3" "⏹️"  "停止"                 "systemctl stop"     "$BR"
        mrow "4" "🔄"  "重启"                 "restart"            "$BC"
        mrow "5" "💾"  "备份种子"             "BT_backup"          "$BY"
        mrow "6" "📂"  "恢复种子"             "从备份恢复"         "$BY"
        mrow "7" "❌"  "卸载"                 "彻底删除"           "$BR"
        mrow2 "0" "◀️" "返回主菜单"            "$W"
        panel "$C"
        centered_read "请选择 (0-7)" "$BC" choice
        case $choice in
            1) qb_install ;;
            2) qb_start; print_ok "qBittorrent 已启动"; wait_key ;;
            3) qb_stop; print_ok "qBittorrent 已停止"; wait_key ;;
            4) qb_restart; wait_key ;;
            5) qb_backup ;;
            6) qb_restore ;;
            7) qb_uninstall ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  脚本目录 - 子脚本
# ============================================================
run_yuju_toolbox() {
    clear; print_title "运行 yuju 工具箱"
    info "正在下载并运行 yuju 工具箱..."
    local temp_dir="/tmp/yuju_install"; mkdir -p "$temp_dir"; cd "$temp_dir"
    curl -sS -O https://raw.githubusercontent.com/yuju520/YujuToolBox/main/yuju.sh
    chmod +x yuju.sh; ./yuju.sh; cd - >/dev/null; wait_key
}
run_kejilion_toolbox() {
    clear; print_title "运行 科技lion 工具箱"
    info "正在下载并运行 科技lion 工具箱..."
    local temp_dir="/tmp/kejilion_install"; mkdir -p "$temp_dir"; cd "$temp_dir"
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh
    chmod +x kejilion.sh; ./kejilion.sh; cd - >/dev/null; wait_key
}
run_ipsentinel_toolbox() {
    clear; print_title "运行 哨兵洗白ip养护"
    info "正在下载并运行 哨兵洗白ip养护..."
    local temp_dir="/tmp/install_install"; mkdir -p "$temp_dir"; cd "$temp_dir"
    curl -sS -O https://raw.githubusercontent.com/hotyue/IP-Sentinel/main/core/install.sh
    chmod +x install.sh; ./install.sh; cd - >/dev/null; wait_key
}

run_reinstall_interactive() {
    clear
    print_title "LeitboGi0ro 全能系统重装 (DD)"
    echo "请选择要安装的系统大类:"
    echo "1. Debian (7-13)"
    echo "2. Ubuntu (20.04, 22.04, 24.04)"
    echo "3. CentOS (7, 8, 9-stream)"
    echo "4. Alpine (3.16-3.18, edge)"
    echo "5. Windows (10, 11, 2012, 2016, 2019, 2022)"
    echo "6. Kali (rolling, dev, experimental)"
    read -p "请输入序号 (1-6, 默认1): " sys_num
    case $sys_num in
        2) os_type="ubuntu" ;; 3) os_type="centos" ;; 4) os_type="alpine" ;;
        5) os_type="windows" ;; 6) os_type="kali" ;; *) os_type="debian" ;;
    esac
    echo -e "\n${BY}提示: 直接回车将使用推荐版本${K}"
    case $os_type in
        debian)  default_ver="12";  read -p "请输入 Debian 版本 (7-13, 默认 $default_ver): " input_ver ;;
        ubuntu)  default_ver="22.04"; read -p "请输入 Ubuntu 版本 (20.04/22.04/24.04, 默认 $default_ver): " input_ver ;;
        centos)  default_ver="9-stream"; read -p "请输入 CentOS 版本 (7/8/9-stream, 默认 $default_ver): " input_ver ;;
        alpine)  default_ver="edge"; read -p "请输入 Alpine 版本 (3.16-3.18/edge, 默认 $default_ver): " input_ver ;;
        windows) default_ver="2022"; read -p "请输入 Windows 版本 (10/11/2012-2022, 默认 $default_ver): " input_ver ;;
        kali)    default_ver="rolling"; read -p "请输入 Kali 版本 (rolling/dev/experimental, 默认 $default_ver): " input_ver ;;
        *)       os_ver="12" ;;
    esac
    os_ver=${input_ver:-$default_ver}

    local lang_param=""
    if [[ "$os_type" == "windows" ]]; then
        default_port="3389"; default_pwd="Teddysun.com"
        user_name="Administrator"; conn_type="RDP (远程桌面)"
        echo -e "\n请设置 Windows 语言 (cn: 简体中文, en: 英文, jp: 日文)"
        read -p "请输入语言代码 (默认 cn): " win_lang
        win_lang=${win_lang:-cn}; lang_param="-lang $win_lang"
    else
        default_port="22"; default_pwd="LeitboGi0ro"
        user_name="root"; conn_type="SSH"
    fi

    echo ""
    read -p "请输入 $conn_type 端口 (默认 $default_port): " ssh_port
    ssh_port=${ssh_port:-$default_port}
    read -p "请输入新密码 (默认 $default_pwd): " ssh_pwd
    ssh_pwd=${ssh_pwd:-$default_pwd}

    echo -e "\n--- 待执行配置 ---"
    echo -e "安装系统: ${BC}$os_type $os_ver${K}"
    [[ "$os_type" == "windows" ]] && echo -e "系统语言: ${BC}$win_lang${K}"
    echo -e "登录用户: ${BG}$user_name${K}"
    echo -e "连接端口: ${BC}$ssh_port${K}"
    echo -e "系统密码: ${BC}$ssh_pwd${K}"
    print_line
    read -p "确认无误并开始重装吗？(y/N): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && return

    info "正在检查环境并下载脚本..."
    if command -v apt-get &> /dev/null; then apt-get update && apt-get install wget curl -y
    elif command -v yum &> /dev/null; then yum install wget curl -y
    fi

    wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh'
    chmod a+x InstallNET.sh
    ok "脚本启动成功。请等待系统断开并开始 DD 安装。"
    sleep 3
    echo -e "${BY}====== 开始执行DD系统重装配置 ======${K}"
    echo -e "${BC}以下将显示DD配置脚本的输出：${K}"
    print_line
    bash InstallNET.sh -${os_type} "${os_ver}" -port "${ssh_port}" -pwd "${ssh_pwd}" ${lang_param}

    print_line; echo
    echo "========================================"
    echo -e "${BG} DD 配置脚本已执行完毕 ${K}"
    echo "========================================"
    echo
    echo -e "${BY}重要提示：${K}"
    echo -e "1. 请仔细检查上方输出，确认配置信息无误。"
    echo -e "2. 如果配置成功，通常需要 ${BC}重启系统${K} 以启动真正的DD安装流程。"
    echo -e "3. 如果看到错误信息，请根据提示解决后再试。"
    echo
    echo -e "按下 ${BG}回车键${K} 将完全退出本优化脚本，之后您可以自行执行 'reboot' 重启。"
    echo -e "（此举是为了避免自动跳回主菜单，覆盖上面的重要信息）"
    echo
    read -p "按回车键退出..." </dev/tty
    exit 0
}

run_warp_go() {
    clear; print_title "运行 WARP-GO"
    info "正在下载并运行 WARP-GO 脚本..."
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh; wait_key
}
run_3x_ui() {
    clear; print_title "运行 3x-ui (v2.3.11)"
    info "正在通过 curl 安装 3x-ui..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) v2.3.11; wait_key
}
run_vaxilu_xui() {
    clear; print_title "运行 官方 x-ui"
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh); wait_key
}
run_franz_xui() {
    clear; print_title "运行 FranzKafkaYu 版 x-ui"
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/956bf85bbac978d56c0e319c5fac2d6db7df9564/install.sh); wait_key
}
run_alpine_xui() {
    clear; print_title "运行 Alpine x-ui"
    info "正在安装依赖并启动脚本..."
    apk add curl && apk add bash && bash <(curl -Ls https://raw.githubusercontent.com/Lynn-Becky/Alpine-x-ui/main/alpine-xui.sh); wait_key
}
run_hy2_full() {
    clear; print_title "安装 Hysteria2"
    info "正在下载安装脚本..."
    wget -N --no-check-certificate https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh && bash hysteria.sh
    info "正在配置自启动并启动服务..."
    systemctl enable hysteria-server.service; systemctl start hysteria-server.service
    ok "Hysteria2 已完成安装并启动。"; wait_key
}
run_fscarmen_singbox() {
    clear; print_title "运行 fscarmen 版 sing-box"
    bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh); wait_key
}
run_233boy_singbox() {
    clear; print_title "运行 233boy 版 sing-box"
    bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh); wait_key
}
run_sublinkx_install() {
    clear; print_title "安装 sublinkX"
    info "正在下载并运行 sublinkX 安装脚本..."
    curl -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" https://raw.githubusercontent.com/gooaclok819/sublinkX/main/install.sh | sudo bash; wait_key
}

# ============================================================
#  脚本目录菜单
# ============================================================
script_directory_menu() {
    while true; do
        clear
        show_submenu_banner "脚本目录" "$BG"
        mrow "1" "🧰" "yuju 工具箱"            "多功能运维"         "$BG"
        mrow "2" "🦁" "科技lion 工具箱"         "Lion 全家桶"        "$BR"
        mrow "3" "🛡️" "哨兵洗白ip养护"          "IP保护"             "$BC"
        mrow "4" "💿" "系统重装"                "Debian/Win/Alpine等" "$BM"
        mrow "5" "🔗" "节点管理"                "x-ui/sb/Hy2/WARP"   "$BG"
        mrow "6" "🔄" "sublinkX 安装"           "订阅转换"           "$BY"
        mrow2 "0" "◀️" "返回主菜单"              "$W"
        panel "$C"
        centered_read "请选择 (0-6)" "$BG" choice
        case $choice in
            1) run_yuju_toolbox ;;
            2) run_kejilion_toolbox ;;
            3) run_ipsentinel_toolbox ;;
            4) run_reinstall_interactive ;;
            5) node_management_menu ;;
            6) run_sublinkx_install ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  节点管理菜单
# ============================================================
node_management_menu() {
    while true; do
        clear
        show_submenu_banner "节点管理" "$BG"
        mrow "1" "🚀" "WARP-GO 脚本"           "F大"                "$BC"
        mrow "2" "⚙️" "3x-ui 面板"             "v2.3.11"            "$BM"
        mrow "3" "⚙️" "官方 x-ui"               "vaxilu"             "$BG"
        mrow "4" "⚙️" "FranzKafkaYu 版 x-ui"    "社区版"             "$BG"
        mrow "5" "⚙️" "Alpine 版 x-ui"          "轻量系统专用"       "$BC"
        mrow "6" "⚡" "Hysteria2 一键安装"      "含自启"             "$BG"
        mrow "7" "📦" "sing-box (F大)"          "sing-box 一键"      "$BY"
        mrow "8" "📦" "sing-box (233boy)"       "默认安装VLESS"      "$BY"
        mrow2 "0" "◀️" "返回上级菜单"            "$W"
        panel "$C"
        centered_read "请选择 (0-8)" "$BG" choice
        case $choice in
            1) run_warp_go ;;
            2) run_3x_ui ;;
            3) run_vaxilu_xui ;;
            4) run_franz_xui ;;
            5) run_alpine_xui ;;
            6) run_hy2_full ;;
            7) run_fscarmen_singbox ;;
            8) run_233boy_singbox ;;
            0) break ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  主菜单
# ============================================================
Main_menu(){
    while true; do
        clear
        show_banner
        mrow "1" "🚀" "PT刷流优化"             "高并发 / 大吞吐"    "$BG"
        mrow "2" "🌐" "VLESS节点优化"           "稳定 / 低延迟"      "$BC"
        mrow "3" "⚙️" "qBittorrent 管理"        "安装 / 优化 / 备份"  "$BM"
        mrow "4" "📦" "Vertex 管理"             "安装 / 删除"        "$BY"
        mrow "5" "📁" "脚本目录"                "工具箱 / 重装 / 节点" "$BG"
        mrow "6" "🔄" "检查脚本更新"            "自动更新"           "$BC"
        mrow2 "0" "❌" "退出"                  "$W"
        panel "$C"
        centered_read "请选择 (0-6)" "$BG" choice
        case $choice in
            1) pt_opt ;;
            2) vless_opt ;;
            3) qb_menu ;;
            4) vertex_menu ;;
            5) script_directory_menu ;;
            6) update_script ;;
            0) clear; echo; cntr "  感谢使用！" "$BG"; echo; exit 0 ;;
            *) print_err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 脚本入口 =====
if [[ $EUID -ne 0 ]]; then
    echo -e "${BR}错误: 此脚本必须以 root 权限运行${K}"
    echo "请使用: sudo bash $0"
    exit 1
fi

setup_shortcut >/dev/null 2>&1
Main_menu
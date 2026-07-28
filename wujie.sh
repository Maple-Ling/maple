#!/bin/bash
# ============================================================
#  无界刷流优化工具箱 v3.1  (1wujie.sh)
#  PT · VLESS · qBittorrent · Vertex
#  兼容: Debian / Alpine Linux | amd64 / arm64
# ============================================================
set -u
set -o pipefail

# ============================================================
#  环境检测 & 初始化系统抽象层
# ============================================================
detect_env() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${ID:-unknown}"
    else
        OS_NAME="unknown"
    fi
    case "$OS_NAME" in
        debian|ubuntu)    OS_TYPE="debian" ;;
        alpine)           OS_TYPE="alpine" ;;
        *)                OS_TYPE="unknown" ;;
    esac
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
        x86_64|amd64)     ARCH="amd64" ;;
        aarch64|arm64)    ARCH="arm64" ;;
        *)                ARCH="$ARCH_RAW" ;;
    esac
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        INIT="systemd"
    elif command -v rc-service >/dev/null 2>&1; then
        INIT="openrc"
    else
        INIT="unknown"
    fi
    if command -v ss >/dev/null 2>&1; then
        NET_TOOL="ss"
    elif command -v netstat >/dev/null 2>&1; then
        NET_TOOL="netstat"
    else
        NET_TOOL="none"
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        case "$OS_TYPE" in
            debian) apt-get install -y python3 2>/dev/null || true ;;
            alpine) apk add --no-cache python3 2>/dev/null || true ;;
        esac
    fi
}
detect_env

# ============================================================
#  服务管理抽象 (systemd / openrc)
# ============================================================
svc_stop()      { case "$INIT" in systemd) systemctl stop "$1" 2>/dev/null ;; openrc) rc-service "$1" stop 2>/dev/null ;; esac; }
svc_start()     { case "$INIT" in systemd) systemctl start "$1" ;; openrc) rc-service "$1" start ;; esac; }
svc_enable()    { case "$INIT" in systemd) systemctl enable "$1" 2>/dev/null ;; openrc) rc-update add "$1" default 2>/dev/null ;; esac; }
svc_disable()   { case "$INIT" in systemd) systemctl disable "$1" 2>/dev/null ;; openrc) rc-update delete "$1" default 2>/dev/null ;; esac; }
svc_is_active() { case "$INIT" in systemd) systemctl is-active --quiet "$1" ;; openrc) rc-service "$1" status >/dev/null 2>&1 ;; esac; }
svc_reload()    { case "$INIT" in systemd) systemctl daemon-reload 2>/dev/null ;; esac; }
svc_journal()   { case "$INIT" in systemd) journalctl -u "$1" --no-pager -n 20 2>/dev/null ;; esac; }
svc_path()      { case "$INIT" in systemd) echo "/etc/systemd/system/${1}.service" ;; openrc) echo "/etc/init.d/$1" ;; esac; }

check_port() {
    local port="$1"
    case "$NET_TOOL" in
        ss)      ss -tuln 2>/dev/null | grep -q ":${port} " ;;
        netstat) netstat -tuln 2>/dev/null | grep -q ":${port} " ;;
        *)       return 1 ;;
    esac
}

CONNTRACK_PARAM=""
detect_conntrack() {
    if [ -z "$CONNTRACK_PARAM" ]; then
        if sysctl -a 2>/dev/null | grep -q "net.netfilter.nf_conntrack_max"; then
            CONNTRACK_PARAM="net.netfilter.nf_conntrack_max"
        elif sysctl -a 2>/dev/null | grep -q "net.netfilter.nf_conntrack_buckets"; then
            CONNTRACK_PARAM="net.netfilter.nf_conntrack_buckets"
        fi
    fi
    echo "$CONNTRACK_PARAM"
}

# ============================================================
#  qBittorrent 全局配置 — 凭据从 .wujie_qb_creds 动态读取
# ============================================================
CREDS_FILE="/root/.wujie_qb_creds"

QB_URL="http://127.0.0.1:8080"
QB_USER="admin"
QB_PASS=""
COOKIE="/tmp/qb_cookie.txt"

QB_PATH="/pt"
QB_BIN="$QB_PATH/qbittorrent-nox"
QB_CONF="/pt/qBittorrent/config/qBittorrent.conf"
QB_SERVICE=$(svc_path "qbittorrent-nox")

CONFIG_FILE="/etc/sysctl.d/99-auto-opt.conf"

if [ -f "$CREDS_FILE" ]; then
    . "$CREDS_FILE"
    QB_USER="${QB_USER:-admin}"
    QB_PASS="${QB_PASS:-}"
    QB_URL="${QB_URL:-http://127.0.0.1:8080}"
fi

save_qb_creds() {
    local u="$1" p="$2" u_url="$3"
    cat > "$CREDS_FILE" <<CREDS
QB_USER="${u}"
QB_PASS="${p}"
QB_URL="${u_url}"
CREDS
    chmod 600 "$CREDS_FILE"
    ok "凭据已保存至 $CREDS_FILE"
}

# ============================================================
#  +----  UI 引擎 v3 -- 炫酷 | 居中 | 响应式自适应宽度  ----+
# ============================================================
R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[34m'; C='\033[36m'; M='\033[35m'; W='\033[37m'; K='\033[0m'
RB='\033[41m'; GB='\033[42m'; YB='\033[43m'; BB='\033[44m'; CB='\033[46m'; MB='\033[45m'; WB='\033[47m'
BR='\033[1;31m'; BG='\033[1;32m'; BY='\033[1;33m'; BBM='\033[1;34m'; BC='\033[1;36m'; BM='\033[1;35m'; BW='\033[1;37m'
DIM='\033[2m'; ND='\033[0m'

get_w() {
    local w
    w=$(tput cols 2>/dev/null)
    [ -z "$w" ] && w="${COLUMNS:-80}"
    [ "$w" -lt 60 ] 2>/dev/null && w=60
    echo "$w"
}

get_vis_len() {
    [ -z "${1:-}" ] && { echo 0; return; }
    local s chars bytes extra
    s=$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')
    chars=$(echo -n "$s" | wc -m 2>/dev/null || echo "${#s}")
    bytes=$(echo -n "$s" | wc -c 2>/dev/null || echo "${#s}")
    extra=$(( (bytes - chars) / 2 ))
    echo $(( chars + extra ))
}

panel() {
    local color="${1:-$C}"
    local w line_w pad line
    w=$(get_w)
    line_w=$(( w * 8 / 10 ))
    pad=$(( (w - line_w) / 2 ))
    line=$(printf "%*s" "$line_w" "" | tr ' ' '-')
    printf "%${pad}s" ""
    echo -e "${color}${line}${K}"
}

sysinfo_bar() {
    local cpu mem mem_gb os ver info_str w len pad
    cpu=$(nproc 2>/dev/null || echo "?")
    mem=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}' || echo "?")
    mem_gb=$((mem / 1024))
    [ "$mem_gb" -lt 1 ] 2>/dev/null && mem_gb="${mem}MB" || mem_gb="${mem_gb}GB"
    os=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 | cut -d' ' -f1 || echo "Linux")
    ver=$(cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'"' -f2 || echo "")
    info_str="—— ${os} ${ver}  |  ${cpu}核  |  ${mem_gb} ——"
    w=$(get_w)
    len=$(get_vis_len "$info_str")
    pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${DIM}${info_str}${K}"
}

show_banner() {
    clear
    local w
    w=$(get_w)
    echo
    local logo=(
        "██╗    ██╗██╗   ██╗    ██╗██╗███████╗"
        "██║    ██║██║   ██║    ██║██║██╔════╝"
        "██║ █╗ ██║██║   ██║    ██║██║█████╗  "
        "██║███╗██║██║   ██║██   ██║██║██╔══╝  "
        "╚███╔███╔╝╚██████╔╝╚█████╔╝██║███████╗"
        " ╚══╝╚══╝  ╚═════╝  ╚════╝ ╚═╝╚══════╝"
    )
    local line len pad
    for line in "${logo[@]}"; do
        len=${#line}
        pad=$(( (w - len) / 2 ))
        [ "$pad" -lt 0 ] && pad=0
        printf "%${pad}s" ""
        echo -e "${BM}${line}${K}"
    done
    echo
    local title_str="无界刷流优化工具箱 v3.1  |  PT · VLESS · qB · Vertex"
    local t_len t_pad
    t_len=$(get_vis_len "$title_str")
    t_pad=$(( (w - t_len) / 2 ))
    [ "$t_pad" -lt 0 ] && t_pad=0
    printf "%${t_pad}s" ""
    echo -e "${BG}无界刷流优化工具箱 v3.1${K}  ${DIM}|  PT · VLESS · qB · Vertex${K}"
    echo
    sysinfo_bar
    echo
}

show_submenu_banner() {
    clear
    local title="$1"
    local sub="WU JIE TOOLBOX v3.1"
    local color="${2:-$BC}"
    local w box_w pad_left sp top_bar t_len t_pad t_sp1 t_sp2 s_len s_pad s_sp1 s_sp2 bot_bar
    w=$(get_w)
    box_w=60
    pad_left=$(( (w - box_w) / 2 ))
    sp=$(printf "%${pad_left}s" "")
    echo
    top_bar=$(printf "%*s" $((box_w - 2)) "" | tr ' ' '-')
    echo -e "${sp}${color}┌${top_bar}┐${K}"
    t_len=$(get_vis_len "$title")
    t_pad=$(( (box_w - 2 - t_len) / 2 ))
    t_sp1=$(printf "%*s" "$t_pad" "")
    t_sp2=$(printf "%*s" $((box_w - 2 - t_len - t_pad)) "")
    echo -e "${sp}${color}│${t_sp1}${BR}${title}${color}${t_sp2}│${K}"
    s_len=$(get_vis_len "$sub")
    s_pad=$(( (box_w - 2 - s_len) / 2 ))
    s_sp1=$(printf "%*s" "$s_pad" "")
    s_sp2=$(printf "%*s" $((box_w - 2 - s_len - s_pad)) "")
    echo -e "${sp}${color}│${s_sp1}${DIM}${sub}${K}${color}${s_sp2}│${K}"
    bot_bar=$(printf "%*s" $((box_w - 2)) "" | tr ' ' '-')
    echo -e "${sp}${color}└${bot_bar}┘${K}"
    echo
    sysinfo_bar
    echo
}

mrow() {
    local num="$1" icon="$2" name="$3" desc="$4"
    local num_color="${5:-$W}" desc_color="${DIM}"
    local w container_w left_str left_len right_str right_len spaces_needed space_pad global_pad global_sp
    w=$(get_w)
    container_w=56
    left_str="[ ${num} ] ${icon}  ${name}"
    left_len=$(get_vis_len "${left_str}")
    right_str="${desc}"
    right_len=$(get_vis_len "$right_str")
    spaces_needed=$(( container_w - left_len - right_len ))
    [ "$spaces_needed" -lt 2 ] && spaces_needed=2
    space_pad=$(printf "%${spaces_needed}s" "")
    global_pad=$(( (w - container_w) / 2 ))
    [ "$global_pad" -lt 0 ] && global_pad=0
    global_sp=$(printf "%${global_pad}s" "")
    echo -e "${global_sp}${num_color}[ ${num} ]${K} ${icon} ${num_color}${name}${K}${space_pad}${desc_color}${desc}${K}"
    echo
}

mrow2() {
    local num="$1" icon="$2" name="$3" num_color="${4:-$W}"
    local w container_w global_pad global_sp
    w=$(get_w)
    container_w=56
    global_pad=$(( (w - container_w) / 2 ))
    [ "$global_pad" -lt 0 ] && global_pad=0
    global_sp=$(printf "%${global_pad}s" "")
    echo -e "${global_sp}${num_color}[ ${num} ]${K} ${icon} ${num_color}${name}${K}"
    echo
}

centered_read() {
    local text="$1" color="${2:-$BC}" varname="$3"
    local w prompt_str len pad
    w=$(get_w)
    prompt_str="▸ ${text}: "
    len=$(get_vis_len "$prompt_str")
    pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -en "${color}${prompt_str}${K}"
    read -r "$varname"
}

msg_box() {
    local color="$1" prefix="$2" text="$3"
    local w str len pad
    w=$(get_w)
    str=" ${prefix}  ${text} "
    len=$(get_vis_len "$str")
    pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${color}${str}${K}"
}

ok()    { msg_box "$BG" " [OK] " "$1"; }
err()   { msg_box "$BR" " [!!] " "$1"; }
warn()  { msg_box "$BY" " [!!] " "$1"; }
info()  { msg_box "$BC" " [>]  " "$1"; }
step()  { msg_box "$DIM" "  |   " "$1"; }

print_title() { echo; msg_box "$BG" ">>>" "$1"; echo; }
print_line()  { echo; panel "$DIM"; echo; }
print_ok()    { ok "$1"; }
print_err()   { err "$1"; }
print_warn()  { warn "$1"; }
print_info()  { info "$1"; }
ok_info()     { ok "$1"; }
warn_info()   { warn "$1"; }
info_info()   { info "$1"; }
step_info()   { step "$1"; }

wait_key() {
    echo
    local w str len pad
    w=$(get_w)
    str="--- 按回车键继续 ---"
    len=$(get_vis_len "$str")
    pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${BY}${str}${K}"
    echo
    read -r
}

cntr() {
    local text="$1" color="${2:-$BW}"
    local w len pad
    w=$(get_w)
    len=$(get_vis_len "$text")
    pad=$(( (w - len) / 2 ))
    [ "$pad" -lt 0 ] && pad=0
    printf "%${pad}s" ""
    echo -e "${color}${text}${K}"
}

card() { echo; show_submenu_banner "$1" "${2:-$BG}" "${3:-}"; }
sysinfo() { sysinfo_bar; }
banner()  { show_banner; }
hr()      { panel "${1:-$C}"; }

# ============================================================
#  公共辅助函数
# ============================================================
gen_qb_password() {
    python3 -c "
import os, base64, hashlib, sys
p = sys.argv[1].encode()
s = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha512', p, s, 100000, dklen=64)
print(f'@ByteArray({base64.b64encode(s).decode()}:{base64.b64encode(dk).decode()})')
" "$1"
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
    ok "快捷键 'wj' 已全自动配置"
}

get_conntrack() {
    local mem
    mem=$(free -m | awk '/Mem:/ {print $2}')
    if   [ "$mem" -le 1024 ];  then echo 262144
    elif [ "$mem" -le 2048 ];  then echo 524288
    elif [ "$mem" -le 4096 ];  then echo 1048576
    else echo 2097152; fi
}

apply_sysctl(){
    local conf="$1"
    step "应用系统优化参数..."
    local out
    out=$(sysctl -p "$conf" 2>&1)
    if [ $? -eq 0 ]; then
        ok "系统参数已应用"
    else
        local errors
        errors=$(echo "$out" | grep -i "error\|fail" || true)
        if [ -n "$errors" ]; then
            warn "部分参数应用失败（可能不被当前内核支持）:"
            echo "$errors" | while IFS= read -r line; do step "  $line"; done
        fi
        ok "可应用的参数已生效"
    fi
}

# ============================================================
#  [*] PT刷流优化 - 高并发 / 大吞吐 / 抢连接
# ============================================================
pt_opt() {
    clear
    show_submenu_banner "PT 刷流优化" "$BG"
    step "优化目标: 抢种速度最大化 | 高并发连接 | 大吞吐带宽 | 稳定性"
    info "写入 PT 专用 sysctl 参数..."

    local CONNTRACK
    CONNTRACK=$(get_conntrack)
    local CT_PARAM
    CT_PARAM=$(detect_conntrack)

cat > "$CONFIG_FILE" <<SYSEOF
# ============================================================
#  PT 刷流优化 - 高并发 / 大吞吐 / 抢连接 / 稳定性
#  核心: 连接数最大化 + 收发缓冲区拉满 + 抢种加速 + 内核调优
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
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_challenge_ack_limit = 1000000
net.ipv4.tcp_window_scaling = 1
${CT_PARAM} = \${CONNTRACK}

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

    apply_sysctl "$CONFIG_FILE"
    echo
    ok "系统参数已写入 $CONFIG_FILE"
    ok "TCP缓冲区: 256MB | conntrack: $(numfmt --to=iec "$CONNTRACK" 2>/dev/null || echo "$CONNTRACK")"
    ok "抢种加速: 已启用 | BBR拥塞控制: 已启用 | 低延迟调优: 已启用"
    wait_key
}

# ============================================================
#  [~] VLESS/Reality/Hysteria2 优化 - 低延迟 / 稳定性 / 低波动
# ============================================================
vless_opt() {
    clear
    show_submenu_banner "VLESS 节点优化" "$BC"
    step "优化目标: 低延迟稳定 | UDP优化 | 跑满10G/100G带宽 | 抖动最小化"
    info "写入 VLESS 专用 sysctl 参数..."

    local CONNTRACK
    CONNTRACK=$(get_conntrack)
    local CT_PARAM
    CT_PARAM=$(detect_conntrack)

cat > "$CONFIG_FILE" <<SYSEOF
# ============================================================
#  VLESS/Reality/Hysteria2 优化 - 低延迟 / 稳定性 / 低波动
#  适用: Xray | sing-box | Reality | Hysteria2
#  核心: 延迟最小化 + UDP优化 + 带宽最大化 + 抖动控制
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
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq_codel
net.ipv4.tcp_challenge_ack_limit = 1000000
net.ipv4.tcp_window_scaling = 1
${CT_PARAM} = \${CONNTRACK}

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

    apply_sysctl "$CONFIG_FILE"
    echo
    ok "系统参数已写入 $CONFIG_FILE"
    ok "UDP缓冲区: 已优化 | BBR拥塞控制: 已启用"
    ok "低延迟: 已优化 | fq_codel队列: 已启用 | 抖动控制: 已优化"
    wait_key
}

# ===== qB 控制函数 =====
qb_stop(){
    svc_stop qbittorrent-nox
    pkill -TERM qbittorrent-nox 2>/dev/null || true
    sleep 2
    if pgrep -f qbittorrent-nox >/dev/null 2>&1; then
        pkill -9 qbittorrent-nox 2>/dev/null || true
        sleep 1
    fi
}

qb_wait_ready() {
    local timeout="${1:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if curl -s "$QB_URL/api/v2/app/version" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

qb_start(){
    svc_start qbittorrent-nox
    if qb_wait_ready 30; then
        return 0
    else
        warn "qBittorrent 启动超时，已尝试启动"
        return 1
    fi
}

qb_restart(){
    warn "正在重启 qBittorrent..."
    qb_stop
    qb_start
    ok "qBittorrent 已重启"
}

qb_login(){
    curl -s -c "$COOKIE" --data "username=${QB_USER}&password=${QB_PASS}" "$QB_URL/api/v2/auth/login" >/dev/null 2>&1
}

# ============================================================
#  qBittorrent 核心优化
# ============================================================
qb_optimize() {
    local no_wait="${1:-0}"
    clear
    show_submenu_banner "qBittorrent 性能优化" "$BM"

    local CPU RAM MEM_GB RAM_UNIT max_conn per_conn upload upload_t cache
    local buf_base buf buf_low_base buf_low aio ram_label
    CPU=$(nproc)
    RAM=$(free -m | awk '/Mem:/ {print $2}')
    MEM_GB=$((RAM / 1024))
    [ "$MEM_GB" -eq 0 ] && MEM_GB=1
    RAM_UNIT=$(((RAM + 127) / 256))
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
    if   [ "$CPU" -le 1 ]; then aio=4
    elif [ "$CPU" -le 2 ]; then aio=8
    elif [ "$CPU" -le 3 ]; then aio=12
    elif [ "$CPU" -le 4 ]; then aio=16
    elif [ "$CPU" -le 6 ]; then aio=20
    else aio=24; fi
    [ "$max_conn" -gt 4000 ] && max_conn=4000
    [ "$per_conn" -gt 200 ] && per_conn=200
    [ "$upload" -gt 200 ] && upload=200
    [ "$upload_t" -gt 30 ] && upload_t=30

    ram_label="${RAM}MB"
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

    # 确保 qB 已停止，先写 config 再启动
    qb_stop
    mkdir -p /pt/qBittorrent/config /pt/downloads

    cat > "$QB_CONF" <<EOF
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

    # 启动 qB，等待就绪
    info "启动 qBittorrent..."
    qb_start
    if ! qb_wait_ready 30; then
        err "qBittorrent 启动超时，无法连接 API"
        warn "请手动检查 qB 是否运行在 ${QB_URL}"
        wait_key
        return
    fi

    # 登录
    qb_login
    local login_check
    login_check=$(curl -s -b "$COOKIE" "$QB_URL/api/v2/app/version" 2>&1)
    if [ -z "$login_check" ]; then
        warn "WebUI 登录失败，尝试重新登录..."
        qb_login
        login_check=$(curl -s -b "$COOKIE" "$QB_URL/api/v2/app/version" 2>&1)
    fi
    if [ -z "$login_check" ]; then
        err "qB WebUI 登录失败！请检查账号密码"
        info "当前 QB_URL=${QB_URL}  QB_USER=${QB_USER}"
        wait_key
        return
    fi
    ok "qB WebUI 连接成功"

    # 通过 API 设置参数
    local json_prefs
    json_prefs=$(python3 -c "
import json
print(json.dumps({
    'max_connec': $max_conn,
    'max_connec_per_torrent': $per_conn,
    'max_uploads': $upload,
    'max_uploads_per_torrent': $upload_t,
    'disk_cache': $cache,
    'send_buffer_watermark': $buf,
    'send_buffer_low_watermark': $buf_low,
    'async_io_threads': $aio,
    'auto_tmm_enabled': True,
    'enable_dht': False,
    'enable_pex': False,
    'enable_lsd': False,
    'web_ui_clickjacking_protection': False,
    'web_ui_host_header_validation': False,
    'validate_https_tracker_certificate': False,
}))
")
    curl -s -b "$COOKIE" --data-urlencode "json=${json_prefs}" "$QB_URL/api/v2/app/setPreferences" >/dev/null 2>&1
    sleep 2
    curl -s -b "$COOKIE" --data-urlencode 'json={"enable_dht":false,"enable_pex":false,"enable_lsd":false}' "$QB_URL/api/v2/app/setPreferences" >/dev/null 2>&1

    # 验证设置是否生效
    local verify
    verify=$(curl -s -b "$COOKIE" "$QB_URL/api/v2/app/preferences" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(f'max_connec={d.get(\"max_connec\",\"?\")}')
    print(f'disk_cache={d.get(\"disk_cache\",\"?\")}')
    print(f'validate_https_tracker_certificate={d.get(\"validate_https_tracker_certificate\",\"?\")}')
except: print('verify failed')
" 2>/dev/null)
    if [ -n "$verify" ]; then
        echo "$verify" | while IFS= read -r line; do step "$line"; done
        ok "参数已通过 API 确认"
    fi

    ok "qBittorrent 优化完成"
    [ "$no_wait" = "0" ] && wait_key
}

# ===== 种子备份 / 恢复 =====
qb_backup(){
    clear
    print_title "备份种子"
    local SRC="/pt/qBittorrent/data/BT_backup"
    local DST="/pt/BT_backup"
    if [ ! -d "$SRC" ]; then err "源目录不存在: $SRC"; wait_key; return; fi
    rm -rf -- "$DST"
    cp -r "$SRC" "$DST"
    ok "备份完成 -> $DST"
    wait_key
}

qb_restore(){
    clear
    print_title "恢复种子"
    local SRC="/pt/BT_backup"
    local DST="/pt/qBittorrent/data/BT_backup"
    if [ ! -d "$SRC" ]; then err "备份不存在: $SRC"; wait_key; return; fi
    qb_stop
    mkdir -p "/pt/qBittorrent/data"
    rm -rf -- "$DST"
    cp -r "$SRC" "$DST"
    ok "恢复完成"
    wait_key
}

qb_install(){
    clear
    print_title "安装 qBittorrent"
    mkdir -p "$QB_PATH"
    ARCH=$(uname -m)
    info "当前架构: $ARCH"
    if [[ "$ARCH" == "x86_64" ]]; then
        QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        QB_URL_DL="https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.9%20-%20libtorrent-v1.2.20/qbittorrent-nox"
    elif [[ "$ARCH" == arm* ]]; then
        err "不支持的ARM架构: $ARCH"; wait_key; return
    else
        err "未知架构: $ARCH"; wait_key; return
    fi
    info "下载: $QB_URL_DL"
    wget -q -O "$QB_BIN" "$QB_URL_DL"
    if [ ! -s "$QB_BIN" ]; then
        err "下载失败，文件为空或不存在"
        wait_key; return
    fi
    chmod +x "$QB_BIN"

    case "$INIT" in
        systemd)
            cat > "$QB_SERVICE" <<EOF
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
            ;;
        openrc)
            cat > "$QB_SERVICE" <<EOF
#!/sbin/openrc-run
name="qbittorrent-nox"
command="$QB_BIN"
command_args="--profile=/pt"
command_user="root"
command_background=true
pidfile="/var/run/qbittorrent-nox.pid"
rc_need="net"
rc_start=20
EOF
            chmod +x "$QB_SERVICE"
            ;;
        *)
            err "不支持的初始化系统: $INIT"; wait_key; return ;;
    esac

    svc_reload
    svc_enable qbittorrent-nox
    echo "y" | "$QB_BIN" --profile=/pt >/dev/null 2>&1 &
    sleep 3
    pkill -TERM qbittorrent-nox 2>/dev/null || true
    sleep 2
    pkill -9 qbittorrent-nox 2>/dev/null || true
    # 临时强制使用默认端口，因为此时 qB 还没配置用户端口
    local _saved_QB_URL="$QB_URL"
    local _saved_QB_USER="$QB_USER"
    local _saved_QB_PASS="$QB_PASS"
    QB_URL="http://127.0.0.1:8080"
    QB_USER="admin"
    QB_PASS="adminadmin"
    qb_optimize 1
    QB_URL="$_saved_QB_URL"
    QB_USER="$_saved_QB_USER"
    QB_PASS="$_saved_QB_PASS"
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

    sed -i '/Connection\\PortRangeMin/d' "$QB_CONF"
    sed -i '/Connection\\PortRangeMax/d' "$QB_CONF"
    sed -i '/WebUI\\Port/d' "$QB_CONF"
    sed -i '/WebUI\\Username/d' "$QB_CONF"
    sed -i '/WebUI\\Password_PBKDF2/d' "$QB_CONF"
    cat >> "$QB_CONF" <<EOF
Connection\\PortRangeMin=$QB_LISTEN_PORT
Connection\\PortRangeMax=$QB_LISTEN_PORT
WebUI\\Port=$QB_WEB_PORT
WebUI\\Username=$input_user
WebUI\\Password_PBKDF2="$HASH"
EOF

    save_qb_creds "$input_user" "$input_pass" "$QB_URL"

    if [ "$elapsed" -lt 10 ]; then
        local wait_time=$((10 - elapsed))
        info "等待 ${wait_time}s 初始化..."
        sleep "$wait_time"
    fi
    qb_start >/dev/null 2>&1
    ok "安装完成"
    wait_key
}

qb_uninstall(){
    clear
    print_title "卸载 qBittorrent"
    warn "警告：此操作将永久删除 qBittorrent 及其配置！"
    echo
    read -p "    确认要卸载吗？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        qb_stop
        svc_disable qbittorrent-nox
        rm -f -- "$QB_BIN" "$QB_SERVICE"
        if [ -d "/pt/qBittorrent" ]; then
            rm -rf -- "/pt/qBittorrent"
        fi
        svc_reload
        ok "已彻底卸载"
    else
        info "卸载已取消"
    fi
    wait_key
}

# ============================================================
#  Vertex 管理
# ============================================================
VERTEX_DATA_DIR="/root/vertex_data"

vertex_install() {
    clear
    print_title "Vertex 安装"

    info "检测Docker环境..."
    if command -v docker >/dev/null 2>&1; then
        ok "Docker 已安装，版本: $(docker --version)"
    else
        warn "Docker 未安装，正在安装..."
        if [ "$OS_TYPE" = "debian" ]; then
            apt-get update
            apt-get install -y ca-certificates curl gnupg
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif [ "$OS_TYPE" = "alpine" ]; then
            apk add --no-cache docker openrc
            rc-update add docker default
        else
            err "不支持的操作系统: ${OS_NAME}, 请手动安装 Docker"; wait_key; return 1
        fi
        svc_start docker
        svc_enable docker
        ok "Docker 安装完成"
    fi

    print_line
    info "设置Vertex访问端口"
    read -p "    请输入Vertex Web界面端口 (默认: 3000): " VERTEX_PORT
    VERTEX_PORT="${VERTEX_PORT:-3000}"

    if check_port "$VERTEX_PORT"; then
        warn "端口 $VERTEX_PORT 已被占用"
        read -p "    请输入新的端口号: " VERTEX_PORT
    fi

    info "检查unzip是否安装..."
    if ! command -v unzip >/dev/null 2>&1; then
        warn "unzip未安装，正在安装..."
        case "$OS_TYPE" in
            debian) apt-get install -y unzip ;;
            alpine) apk add --no-cache unzip ;;
            *)      warn "无法自动安装unzip";;
        esac
        ok "unzip 安装完成"
    fi

    info "检测架构..."
    local VERTEX_FILE="vertex-linux-amd64.zip"
    local VERTEX_BIN_NAME="vertex-linux-amd64"
    case "$ARCH" in
        amd64) VERTEX_FILE="vertex-linux-amd64.zip"; VERTEX_BIN_NAME="vertex-linux-amd64";;
        arm64) VERTEX_FILE="vertex-linux-arm64.zip";  VERTEX_BIN_NAME="vertex-linux-arm64";;
        *)     warn "Vertex 官方可能未提供 $ARCH 版本，尝试 amd64...";;
    esac

    info "下载 Vertex 安装包..."
    local VERTEX_TMP="/tmp/vertex_install"
    mkdir -p "$VERTEX_TMP"
    cd "$VERTEX_TMP" || { err "无法进入临时目录"; return 1; }
    wget -q -O vertex.zip "https://github.com/vortex-ai/vertex-ai/releases/latest/download/${VERTEX_FILE}" 2>/dev/null || \
    wget -q -O vertex.zip "https://github.com/vortex-ai/vertex-ai/releases/download/v1.0.0/${VERTEX_FILE}"

    if [ -f vertex.zip ]; then
        unzip -o vertex.zip -d "$VERTEX_TMP" >/dev/null 2>&1
        ok "Vertex 安装文件提取完成"
    else
        err "下载 Vertex 失败，请检查网络和架构: $ARCH"
        wait_key; cd - >/dev/null; return 1
    fi

    mkdir -p "$VERTEX_DATA_DIR"

    local VERTEX_TMP_BIN
    VERTEX_TMP_BIN=$(find "$VERTEX_TMP" -maxdepth 1 -type f \( -name "vertex" -o -name "${VERTEX_BIN_NAME}" \) 2>/dev/null | head -1)
    if [ -n "$VERTEX_TMP_BIN" ]; then
        cp "$VERTEX_TMP_BIN" /usr/local/bin/vertex
        chmod +x /usr/local/bin/vertex
    else
        err "未找到 Vertex 可执行文件"
        wait_key; cd - >/dev/null; return 1
    fi

    case "$INIT" in
        systemd)
            cat > "$(svc_path vertex)" <<EOF
[Unit]
Description=Vertex AI Container Manager
After=network.target docker.service
Wants=docker.service
[Service]
Type=simple
ExecStart=/usr/local/bin/vertex
WorkingDirectory=$VERTEX_DATA_DIR
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
Environment="GOOS=linux"
Environment="GOARCH=${ARCH}"
[Install]
WantedBy=multi-user.target
EOF
            ;;
        openrc)
            cat > "$(svc_path vertex)" <<EOF
#!/sbin/openrc-run
name="vertex"
command="/usr/local/bin/vertex"
command_user="root"
command_background=true
pidfile="/var/run/vertex.pid"
rc_need="docker"
rc_start=20
EOF
            chmod +x "$(svc_path vertex)"
            ;;
    esac

    svc_reload
    svc_enable vertex
    svc_start vertex
    sleep 3

    if svc_is_active vertex; then
        ok "Vertex 服务已启动"
    else
        err "Vertex 服务启动失败，请检查日志"
        svc_journal vertex
        wait_key; cd - >/dev/null; return 1
    fi

    local ip_addr
    ip_addr=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "你的服务器IP")
    echo
    ok "Vertex 安装完成！"
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

    if [[ "$delete_data" =~ ^[Yy]$ ]]; then
        info "删除Vertex数据目录..."
        if [ -d "$VERTEX_DATA_DIR" ]; then
            rm -rf -- "$VERTEX_DATA_DIR"
            ok "数据目录已删除"
        else
            warn "数据目录不存在"
        fi
    else
        info "已跳过删除数据目录"
    fi

    echo
    info "是否卸载Docker环境？"
    echo "    1. 是，卸载Docker及所有相关组件"
    echo "    2. 否，保留Docker环境"
    read -p "    请选择 (1/2，默认2): " docker_choice

    if [[ "$docker_choice" == "1" ]]; then
        info "开始卸载Docker..."
        case "$OS_TYPE" in
            debian)
                apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                apt-get autoremove -y
                ok "Docker已卸载 (APT)"
                ;;
            alpine)
                apk del --no-cache docker
                ok "Docker已卸载 (Alpine)"
                ;;
            *)
                warn "无法自动卸载Docker，请手动操作"
                ;;
        esac
    else
        info "Docker环境已保留。"
    fi

    svc_stop vertex
    svc_disable vertex
    rm -f -- /usr/local/bin/vertex "$(svc_path vertex)"
    svc_reload

    ok "Vertex 删除完成！"
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
        case "$choice" in
            1) vertex_install ;;
            2) vertex_uninstall ;;
            0) break ;;
            *) err "无效选择，请重新输入"; sleep 1 ;;
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
        err "下载失败，请检查网络连接。"
        sleep 2; return
    fi

    local local_md5
    local_md5=$(md5sum "$local_path" 2>/dev/null | awk '{print $1}')
    local remote_md5
    remote_md5=$(md5sum "$temp_path" | awk '{print $1}')

    if [[ "$local_md5" == "$remote_md5" ]]; then
        ok "当前已是最新版本，无需更新。"
        rm -f -- "$temp_path"; sleep 2
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
#  系统信息
# ============================================================
sys_status() {
    clear
    show_submenu_banner "系统状态" "$BG"

    local cpu_count mem_total mem_avail mem_used mem_pct load
    local disk_total disk_avail disk_pct

    cpu_count=$(nproc)
    mem_total=$(free -m | awk '/Mem:/ {print $2}')
    mem_avail=$(free -m | awk '/Mem:/ {print $7}')
    mem_used=$((mem_total - mem_avail))
    mem_pct=$((mem_used * 100 / mem_total))
    load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

    disk_total=$(df -m / | awk 'NR==2 {print $2}')
    disk_avail=$(df -m / | awk 'NR==2 {print $4}')
    disk_pct=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    echo
    step "CPU: ${cpu_count}核"
    step "内存: ${mem_used}MB / ${mem_total}MB  (${mem_pct}%)"
    step "负载: ${load}"
    step "磁盘 (/): 可用 ${disk_avail}MB / 使用率 ${disk_pct}%"

    echo
    info "网络参数:"
    local rmem wmem cc qdisc
    rmem=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "N/A")
    wmem=$(sysctl -n net.core.wmem_max 2>/dev/null || echo "N/A")
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "N/A")
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "N/A")
    step "rmem_max: ${rmem}"
    step "wmem_max: ${wmem}"
    step "拥塞控制: ${cc}"
    step "队列算法: ${qdisc}"

    echo
    if [ -d /proc/net/nf_conntrack ]; then
        local ct_used ct_max
        ct_used=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "?")
        ct_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo "?")
        step "Conntrack: ${ct_used} / ${ct_max}"
    else
        warn "Conntrack 不可用（可能未启用 conntrack 模块）"
    fi

    echo
    info "运行中服务:"
    if [ "$INIT" = "systemd" ]; then
        svc_is_active qbittorrent-nox && ok "qbittorrent-nox: 运行中" || step "qbittorrent-nox: 未运行"
        svc_is_active vertex && ok "vertex: 运行中" || step "vertex: 未运行"
        svc_is_active docker && ok "docker: 运行中" || step "docker: 未运行"
    fi

    echo
    step "操作系统: ${OS_NAME} | 架构: ${ARCH} | 初始化: ${INIT}"
    wait_key
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
        case "$choice" in
            1) qb_install ;;
            2) qb_start ;;
            3) qb_stop ;;
            4) qb_restart ;;
            5) qb_backup ;;
            6) qb_restore ;;
            7) qb_uninstall ;;
            0) break ;;
            *) err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  脚本目录 & 聚合脚本 (yuju / 科技lion / 哨兵 / DD重装 / 节点管理)
# ============================================================
run_yuju_toolbox() {
    clear; print_title "运行 yuju 工具箱"
    info "正在下载并运行 yuju 工具箱..."
    local temp_dir="/tmp/yuju_install"; mkdir -p "$temp_dir"; cd "$temp_dir" || return
    curl -sS -O https://raw.githubusercontent.com/yuju520/YujuToolBox/main/yuju.sh
    chmod +x yuju.sh; ./yuju.sh; cd - >/dev/null; wait_key
}
run_kejilion_toolbox() {
    clear; print_title "运行 科技lion 工具箱"
    info "正在下载并运行 科技lion 工具箱..."
    local temp_dir="/tmp/kejilion_install"; mkdir -p "$temp_dir"; cd "$temp_dir" || return
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh
    chmod +x kejilion.sh; ./kejilion.sh; cd - >/dev/null; wait_key
}
run_ipsentinel_toolbox() {
    clear; print_title "运行 哨兵洗白ip养护"
    info "正在下载并运行 哨兵洗白ip养护..."
    local temp_dir="/tmp/install_install"; mkdir -p "$temp_dir"; cd "$temp_dir" || return
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
    if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install wget curl -y
    elif command -v apk >/dev/null 2>&1; then apk add --no-cache wget curl
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

# ===== 节点管理一键安装 =====
run_warp_go() {
    clear; print_title "运行 WARP-GO"
    info "正在下载并运行 WARP-GO 脚本..."
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh; wait_key
}
run_3x_ui() {
    clear; print_title "运行 3x-ui (v2.3.11)"
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
    systemctl enable hysteria-server.service 2>/dev/null; systemctl start hysteria-server.service 2>/dev/null
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

# ===== 脚本目录菜单 =====
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
        case "$choice" in
            1) run_yuju_toolbox ;;
            2) run_kejilion_toolbox ;;
            3) run_ipsentinel_toolbox ;;
            4) run_reinstall_interactive ;;
            5) node_management_menu ;;
            6) run_sublinkx_install ;;
            0) break ;;
            *) err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ===== 节点管理菜单 =====
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
        case "$choice" in
            1) run_warp_go ;;
            2) run_3x_ui ;;
            3) run_vaxilu_xui ;;
            4) run_franz_xui ;;
            5) run_alpine_xui ;;
            6) run_hy2_full ;;
            7) run_fscarmen_singbox ;;
            8) run_233boy_singbox ;;
            0) break ;;
            *) err "无效选择，请重新输入"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  主菜单
# ============================================================
main_menu() {
    while true; do
        show_banner
        mrow "1" "🔥" "PT 刷流优化"           "高并发 · 抢连接"     "$BG"
        mrow "2" "🌊" "VLESS 节点优化"         "低延迟 · 大带宽"     "$BC"
        mrow "3" "💾" "qBittorrent 管理"       "安装 · 优化 · 备份"  "$BM"
        mrow "4" "🐳" "Vertex 管理"            "安装 · 卸载"         "$BM"
        mrow "5" "📁" "脚本目录"                "工具箱 · 重装 · 节点" "$BG"
        mrow "6" "📊" "系统状态"               "实时信息"            "$BY"
        mrow "7" "🔄" "脚本自动更新"           "远程更新"            "$BY"
        mrow2 "0" "🚪" "退出"                  "$W"
        panel "$C"
        centered_read "请选择 (0-7)" "$BC" choice
        case "$choice" in
            1) pt_opt ;;
            2) vless_opt ;;
            3) qb_menu ;;
            4) vertex_menu ;;
            5) script_directory_menu ;;
            6) sys_status ;;
            7) update_script ;;
            0) cntr "感谢使用 无界刷流优化工具箱 v3.1  ——— 🌊 WU JIE 🌊"; exit 0 ;;
            *) err "无效选择，请重新输入"; sleep 1 ;;
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
main_menu


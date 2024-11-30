#!/bin/bash
export LANG=en_US.UTF-8
# 定义颜色
re='\e[0m'
red='\e[1;91m'
white='\e[1;97m'
green='\e[1;32m'
yellow='\e[1;33m'
purple='\e[1;35m'
skyblue='\e[1;96m'

# 工具箱名称
TOOLBOX_NAME="Maple工具箱"
VPS_TOOLS_URL="https://raw.githubusercontent.com/Maple-Ling/maple/main/vps_tools/vps_tools.sh"
VPS_TOOLS_FILE="vps_tools.sh"

# 添加快捷键到 .bashrc（仅执行一次）
setup_alias() {
    local alias_command="alias m='${BASH_SOURCE[0]}'"
    if ! grep -Fxq "$alias_command" ~/.bashrc; then
        echo "$alias_command" >> ~/.bashrc
        echo -e "${PINK}快捷键 'm' 已添加，重新登录后即可使用。${NC}"
    fi
}

# 下载并检查文件是否已存在
download_or_replace_script() {
    echo -e "${PINK}正在检查脚本文件...${NC}"

    if [ -f "$VPS_TOOLS_FILE" ]; then
        echo -e "${PINK}文件已存在，正在替换脚本...${NC}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    else
        echo -e "${PINK}文件不存在，正在下载脚本...${NC}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    fi
}

# 主菜单
show_menu() {
    clear
    echo -e "${LIGHT_BLUE}${TOOLBOX_NAME}${NC}"

    # 输出左侧菜单与右侧菜单对齐
    printf "%-45s %-45s\n" "左侧菜单:" "右侧菜单:"
    printf "%-45s %-45s\n" "1  节点搭建" "2  WARP 工具"
    printf "%-45s\n" "0  退出工具箱"

    echo

    read -p "请输入选项: " choice
    case $choice in
        1) node_setup_tools ;;
        2) warp_tools ;;
        0) show_menu ;;
        99) exit 0 ;;
        *) echo "无效选项，请重试。"; sleep 1; show_menu ;;
    esac
}

# 节点搭建工具
node_setup_tools() {
    clear
    echo -e "${PINK}节点搭建工具:${NC}"
    echo "  1  Hysteria2 安装脚本"
    echo "  2  Sing-box 安装脚本"
    echo "  0  返回上一级"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1) download_and_run "https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh" ;;
        2) download_and_run "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" ;;
        0) show_menu ;;
        *) echo "无效选项，请重试。"; sleep 1; node_setup_tools ;;
    esac
}

# WARP 工具
warp_tools() {
    clear
    echo -e "${PINK}WARP 工具:${NC}"
    echo "  1  WARP 安装脚本"
    echo "  0  返回上一级"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1) download_and_run "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" ;;
        0) show_menu ;;
        *) echo "无效选项，请重试。"; sleep 1; warp_tools ;;
    esac
}

# 通用下载并运行函数
download_and_run() {
    local url=$1
    local filename=$(basename "$url")
    echo -e "${PINK}正在下载并运行脚本...${NC}"
    wget -q --no-check-certificate -O "$filename" "$url" && bash "$filename" || echo -e "${PINK}脚本执行失败！${NC}"
    rm -f "$filename"
    sleep 2
}

# 初始化并显示菜单
setup_alias
download_or_replace_script
show_menu
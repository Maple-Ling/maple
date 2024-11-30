#!/bin/bash
export LANG=en_US.UTF-8
# 定义颜色
re='\e[0m'           # 重置颜色
red='\e[1;91m'        # 红色
white='\e[1;97m'      # 白色
green='\e[1;32m'      # 绿色
yellow='\e[1;33m'     # 黄色
purple='\e[1;35m'     # 紫色
skyblue='\e[1;96m'    # 天蓝色
orange='\e[38;5;214m' # 橙色
pink='\e[1;35m'       # 粉红色

# 工具箱名称
TOOLBOX_NAME="Maple工具箱"
VPS_TOOLS_URL="https://raw.githubusercontent.com/Maple-Ling/maple/main/vps_tools/vps_tools.sh"
VPS_TOOLS_FILE="vps_tools.sh"

# 检测是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${red}警告: 当前不在 root 权限下运行，某些功能可能无法正常工作。${re}"
    fi
}

# 添加快捷键到 .bashrc（仅执行一次）
setup_alias() {
    local alias_command="alias m='${BASH_SOURCE[0]}'"
    if ! grep -Fxq "$alias_command" ~/.bashrc; then
        echo "$alias_command" >> ~/.bashrc
        echo -e "${pink}快捷键 'm' 已添加，重新登录后即可使用。${re}"
    fi
}

# 下载并检查文件是否已存在
download_or_replace_script() {
    echo -e "${pink}正在检查脚本文件...${re}"

    if [ -f "$VPS_TOOLS_FILE" ]; then
        echo -e "${pink}文件已存在，正在替换脚本...${re}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    else
        echo -e "${pink}文件不存在，正在下载脚本...${re}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    fi
}

# 主菜单
show_menu() {
    clear
    # 居中显示“Maple工具箱”
    printf "\n\n\n"
    echo -e "${pink}                         ${TOOLBOX_NAME}                         ${re}"
    echo -e "${pink}-------------------------------------------------------------${re}"

    # 输出左侧菜单与右侧菜单对齐
    printf "%-45s %-45s\n" "${orange}1  节点搭建${re}" "${orange}2  WARP 工具${re}"
    printf "%-45s\n" "${orange}0  退出工具箱${re}"

    echo

    read -p "请输入选项: " choice
    case $choice in
        1) node_setup_tools ;;
        2) warp_tools ;;
        0) exit 0 ;;
        *) echo -e "${red}无效选项，请重试。${re}"; sleep 1; show_menu ;;
    esac
}

# 节点搭建工具
node_setup_tools() {
    clear
    echo -e "${pink}节点搭建工具:${re}"
    echo "  ${orange}1  Hysteria2 安装脚本${re}"
    echo "  ${orange}2  Sing-box 安装脚本${re}"
    echo "  ${orange}0  返回上一级${re}"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1) download_and_run "https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh" ;;
        2) download_and_run "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" ;;
        0) show_menu ;;
        *) echo -e "${red}无效选项，请重试。${re}"; sleep 1; node_setup_tools ;;
    esac
}

# WARP 工具
warp_tools() {
    clear
    echo -e "${pink}WARP 工具:${re}"
    echo "  ${orange}1  WARP 安装脚本${re}"
    echo "  ${orange}0  返回上一级${re}"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1) download_and_run "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" ;;
        0) show_menu ;;
        *) echo -e "${red}无效选项，请重试。${re}"; sleep 1; warp_tools ;;
    esac
}

# 通用下载并运行函数
download_and_run() {
    local url=$1
    local filename=$(basename "$url")
    echo -e "${pink}正在下载并运行脚本...${re}"
    wget -q --no-check-certificate -O "$filename" "$url" && bash "$filename" || echo -e "${pink}脚本执行失败！${re}"
    rm -f "$filename"
    sleep 2
}

# 初始化并显示菜单
check_root
setup_alias
download_or_replace_script
show_menu
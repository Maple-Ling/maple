#!/bin/bash
export LANG=en_US.UTF-8

# 工具箱名称
TOOLBOX_NAME="Maple工具箱"
VPS_TOOLS_URL="https://raw.githubusercontent.com/Maple-Ling/maple/main/vps_tools/vps_tools.sh"
VPS_TOOLS_FILE="vps_tools.sh"

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "当前不是 root 用户，请使用 root 权限运行此脚本。"
    fi
}

# 添加快捷键到 .bashrc（仅执行一次）
setup_alias() {
    local alias_command="alias m='${BASH_SOURCE[0]}'"
    if ! grep -Fxq "$alias_command" ~/.bashrc; then
        echo "$alias_command" >> ~/.bashrc
        echo -e "快捷键 'm' 已添加到 .bashrc，请手动执行 'source ~/.bashrc' 或重新打开终端使其生效。"
        # 自动执行 source ~/.bashrc 来在当前终端会话中生效
        source ~/.bashrc
    else
        echo -e "快捷键 'm' 已存在，无需重复添加。"
    fi
}

# 下载并检查文件是否已存在
download_or_replace_script() {
    echo -e "正在检查脚本文件..."

    if [ -f "$VPS_TOOLS_FILE" ]; then
        echo -e "文件已存在，正在替换脚本..."
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    else
        echo -e "文件不存在，正在下载脚本..."
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    fi
}

# 主菜单
show_menu() {
    clear
    echo -e "\e[1;35m            Maple工具箱            \e[0m"
    echo "-------------------------------------------------------------"
    echo "1  节点搭建"
    echo "2  WARP 工具"
    echo "0  退出工具箱"
    echo

    read -p "请输入选项: " choice
    case $choice in
        1) node_setup_tools ;;
        2) warp_tools ;;
        0) exit 0 ;;
        *) echo "无效选项，请重试。"; sleep 1; show_menu ;;
    esac
}

# 节点搭建工具
node_setup_tools() {
    clear
    echo -e "节点搭建工具:"
    echo "1  Hysteria2 安装脚本"
    echo "2  Sing-box 安装脚本"
    echo "0  返回上一级"

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
    echo -e "WARP 工具:"
    echo "1  WARP 安装脚本"
    echo "0  返回上一级"

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
    echo -e "正在下载并运行脚本..."
    wget -q --no-check-certificate -O "$filename" "$url" && bash "$filename" || echo -e "脚本执行失败！"
    rm -f "$filename"
    sleep 2
}

# 初始化并显示菜单
check_root
setup_alias
download_or_replace_script
show_menu
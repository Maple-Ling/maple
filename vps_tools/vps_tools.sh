#!/bin/bash

# 定义颜色代码
LIGHT_BLUE='\033[1;34m'  # 浅蓝色
PINK='\033[1;35m'        # 粉色
NC='\033[0m'             # 无颜色

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

# 下载并执行最新的 vps_tools.sh 脚本
update_script() {
    echo -e "${PINK}正在更新脚本文件...${NC}"
    wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    echo -e "${PINK}脚本更新完成。${NC}"
    # 执行更新后的脚本
    ./$VPS_TOOLS_FILE
}

# 主菜单
show_menu() {
    clear
    echo -e "${LIGHT_BLUE}${TOOLBOX_NAME}${NC}"

    # 输出左侧菜单与右侧菜单对齐
    printf "%-42s %-42s\n" "左侧菜单:" "右侧菜单:"
    printf "%-42s %-42s\n" "$(printf "(%-3d)" 1) 节点搭建" "$(printf "(%-3d)" 2) WARP 工具"
    printf "%-42s %-39s\n" "$(printf "(%-3d)" 0) 返回上一级" "$(printf "(%-3d)" 99) 退出工具箱"
    printf "%-42s %-39s\n" "$(printf "(%-3d)" 88) 更新脚本" ""

    echo

    read -p "请输入选项: " choice
    case $choice in
        1) node_setup_tools ;;
        2) warp_tools ;;
        0) show_menu ;;
        99) exit 0 ;;
        88) update_script ;;
        *) echo "无效选项，请重试。"; sleep 1; show_menu ;;
    esac
}

# 节点搭建工具
node_setup_tools() {
    clear
    echo -e "${PINK}节点搭建工具:${NC}"
    echo "  $(printf "(%-3d)" 1) Hysteria2 安装脚本"
    echo "  $(printf "(%-3d)" 2) Sing-box 安装脚本"
    echo "  $(printf "(%-3d)" 0) 返回上一级"

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
    echo "  $(printf "(%-3d)" 1) WARP 安装脚本"
    echo "  $(printf "(%-3d)" 0) 返回上一级"

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
show_menu
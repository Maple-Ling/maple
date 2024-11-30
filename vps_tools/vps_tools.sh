#!/bin/bash

# 定义颜色代码
PINK='\033[1;35m'  # 粉色
NC='\033[0m'       # 无颜色

# 工具箱名称
TOOLBOX_NAME="Maple工具箱"

# 菜单选项左右分布实现的宽度
MENU_WIDTH=$(tput cols)
LINE="==================================================="

# 定义工具路径和下载链接
SCRIPT_PATH="$(realpath $0)"
HYSTERIA_URL="https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh"
WARP_URL="https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh"

# 添加别名到用户的 .bashrc 文件
if ! grep -q "alias m='${SCRIPT_PATH}'" ~/.bashrc; then
    echo "alias m='${SCRIPT_PATH}'" >> ~/.bashrc
    echo -e "${PINK}别名已添加为 'm'，请重新打开终端或运行 'source ~/.bashrc' 使其生效。${NC}"
fi

# 显示菜单并处理选项
show_menu() {
    clear
    printf "%s\n" "$LINE"
    printf "%s\n" "${PINK}${TOOLBOX_NAME}${NC}"
    printf "%s\n" "$LINE"

    printf "%-${MENU_WIDTH}s\n" "左侧菜单:" | sed 's/ /-/g'
    printf "  (1) 节点搭建\n"
    printf "%-${MENU_WIDTH}s\n" "右侧菜单:" | sed 's/ /-/g'
    printf "  (2) WARP 工具\n"

    printf "\n${LINE}\n"
    echo "  (0) 返回上一级"
    echo "  (99) 退出工具箱"
    printf "${LINE}\n"

    read -p "请输入选项: " choice
    case $choice in
        1) node_setup_tools ;;
        2) warp_tools ;;
        0) return ;;
        99) echo -e "${PINK}退出工具箱${NC}"; exit 0 ;;
        *) echo "无效选项，请重试。"; sleep 2; show_menu ;;
    esac
}

# 节点搭建工具函数
node_setup_tools() {
    clear
    echo -e "${PINK}节点搭建工具:${NC}"
    echo "1) Hysteria2 安装脚本"
    echo "2) Sing-box 安装脚本"
    echo "(0) 返回上一级"
    echo "(99) 退出工具箱"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1)
            echo -e "${PINK}正在下载并运行 Hysteria2 安装脚本...${NC}"
            wget -N --no-check-certificate -O hysteria.sh "${HYSTERIA_URL}" \
                && bash hysteria.sh || echo -e "${PINK}Hysteria2 安装失败！${NC}"
            ;;
        2)
            echo -e "${PINK}正在下载并运行 Sing-box 安装脚本...${NC}"
            bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) \
                || echo -e "${PINK}Sing-box 安装失败！${NC}"
            ;;
        0) show_menu ;;
        99) echo -e "${PINK}退出工具箱${NC}"; exit 0 ;;
        *) echo "无效选项，请重试。"; sleep 2; node_setup_tools ;;
    esac
}

# WARP 工具函数
warp_tools() {
    clear
    echo -e "${PINK}WARP 工具:${NC}"
    echo "1) WARP 安装脚本"
    echo "(0) 返回上一级"
    echo "(99) 退出工具箱"

    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1)
            echo -e "${PINK}正在下载并运行 WARP 安装脚本...${NC}"
            wget -N -O menu.sh "${WARP_URL}" && bash menu.sh \
                || echo -e "${PINK}WARP 安装失败！${NC}"
            ;;
        0) show_menu ;;
        99) echo -e "${PINK}退出工具箱${NC}"; exit 0 ;;
        *) echo "无效选项，请重试。"; sleep 2; warp_tools ;;
    esac
}

# 调用主菜单
show_menu
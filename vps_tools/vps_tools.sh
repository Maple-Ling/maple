#!/bin/bash

# 定义颜色代码
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 添加别名到用户的 .bashrc 文件中，避免重复添加
if ! grep -q "alias m='${BASH_SOURCE[0]}'" ~/.bashrc; then
    echo "alias m='${BASH_SOURCE[0]}'" >> ~/.bashrc
fi
source ~/.bashrc

# 创建 systemd 服务来管理脚本
cat <<EOF | sudo tee /etc/systemd/system/maple.service
[Unit]
Description=Maple工具箱
After=network.target

[Service]
Type=simple
ExecStart=${BASH_SOURCE[0]}
ExecStop=/bin/kill -15 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

# 使服务生效并启动
sudo systemctl daemon-reload
sudo systemctl enable maple.service
sudo systemctl start maple.service

echo -e "${GREEN}Maple工具箱${NC}"
echo ""

# 菜单函数和其他函数

menu() {
    echo -e "${NC}请选择一个分类:${NC}"
    echo "(1) ${GREEN}节点搭建${NC}"
    echo "(2) ${GREEN}WARP工具${NC}"
    echo "(0) 返回"
    echo "(99) 退出工具箱"

    read -p "请输入选项: " choice
    case $choice in
        1)
            node_setup_tools
            ;;
        2)
            warp_tools
            ;;
        0)
            return
            ;;
        99)
            echo -e "${RED}退出工具箱${NC}"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入！"
            sleep 2
            menu
            ;;
    esac
}

node_setup_tools() {
    echo "节点搭建工具:"
    echo "1) Hysteria2 安装脚本"
    echo "2) Sing-box 安装脚本"
    echo "(0) 返回上一级"
    echo "(99) 退出工具箱"
    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1)
            echo -e "${GREEN}正在下载并运行 Hysteria2 安装脚本...${NC}"
            wget -N --no-check-certificate -O hysteria.sh https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh && bash hysteria.sh
            ;;
        2)
            echo -e "${GREEN}正在下载并运行 Sing-box 安装脚本...${NC}"
            bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
            ;;
        0)
            menu
            ;;
        99)
            echo -e "${RED}退出工具箱${NC}"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入！"
            sleep 2
            node_setup_tools
            ;;
    esac
}

warp_tools() {
    echo "WARP工具:"
    echo "1) WARP 安装脚本"
    echo "(0) 返回上一级"
    echo "(99) 退出工具箱"
    read -p "请输入选项: " tool_choice
    case $tool_choice in
        1)
            echo -e "${GREEN}正在下载并运行 WARP 安装脚本...${NC}"
            wget -N -O menu.sh https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [license/url/token]
            ;;
        0)
            menu
            ;;
        99)
            echo -e "${RED}退出工具箱${NC}"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入！"
            sleep 2
            warp_tools
            ;;
    esac
}

menu

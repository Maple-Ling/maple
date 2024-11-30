#!/bin/bash

SCRIPT_DIR="./scripts"

# 显示可用脚本
echo "欢迎使用工具箱！以下是可用的脚本："
echo "------------------------------------"
options=("SSH Tool" "Kejilion Script" "退出")
PS3="请输入要执行的脚本编号: "

select opt in "${options[@]}"; do
    case $REPLY in
        1)
            echo "执行 SSH Tool 脚本..."
            bash "$SCRIPT_DIR/ssh_tool.sh"
            break
            ;;
        2)
            echo "执行 Kejilion 脚本..."
            bash "$SCRIPT_DIR/kejilion.sh"
            break
            ;;
        3)
            echo "退出工具箱！"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入！"
            ;;
    esac
done
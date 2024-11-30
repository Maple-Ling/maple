#!/bin/bash

# 定义脚本名称和对应的URL
declare -A scripts=(
    ["SSH Tool"]="https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh"
    ["Kejilion Script"]="https://kejilion.pro/kejilion.sh"
)

# 显示可用脚本
echo "欢迎使用工具箱！以下是可用的脚本："
echo "------------------------------------"
i=1
for name in "${!scripts[@]}"; do
    echo "$i. $name"
    i=$((i + 1))
done
echo "$i. 退出"
echo "------------------------------------"

# 选择脚本
read -p "请输入要执行的脚本编号: " choice

# 执行脚本
i=1
for name in "${!scripts[@]}"; do
    if [[ "$choice" -eq "$i" ]]; then
        echo "正在执行 $name ..."
        curl -fsSL "${scripts[$name]}" | bash
        exit 0
    fi
    i=$((i + 1))
done

if [[ "$choice" -eq "$i" ]]; then
    echo "已退出工具箱！"
else
    echo "无效的选择，请重新运行！"
fi
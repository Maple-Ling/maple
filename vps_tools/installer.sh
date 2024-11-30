#!/bin/bash

# 定义脚本名称和对应的下载链接
declare -A scripts=(
    ["SSH Tool"]="https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh"
    ["Kejilion Script"]="https://kejilion.pro/kejilion.sh"
)

# 欢迎提示
echo "欢迎使用工具箱！以下是可用的脚本："
echo "------------------------------------"

# 显示脚本列表
i=1
for name in "${!scripts[@]}"; do
    echo "$i. $name"
    i=$((i + 1))
done
echo "$i. 退出"  # 提供退出选项
echo "------------------------------------"

# 让用户选择脚本编号
read -p "请输入要运行的脚本编号: " choice

# 判断用户选择并执行对应脚本
i=1
for name in "${!scripts[@]}"; do
    if [[ "$choice" -eq "$i" ]]; then
        echo "正在运行 $name ..."
        # 下载并运行脚本
        curl -fsSL "${scripts[$name]}" -o temp_script.sh || {
            echo "下载失败，请检查网络或脚本地址！"
            exit 1
        }
        chmod +x temp_script.sh  # 给脚本执行权限
        ./temp_script.sh         # 运行脚本
        rm -f temp_script.sh     # 删除临时脚本
        exit 0
    fi
    i=$((i + 1))
done

# 退出工具箱
if [[ "$choice" -eq "$i" ]]; then
    echo "已退出工具箱！"
else
    echo "无效的选择，请重新运行！"
fi
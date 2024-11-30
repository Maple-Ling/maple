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

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && echo -e "${red}注意: 请在root用户下运行脚本${re}" && sleep 1 && exit 1

# 创建快捷指令
add_alias() {
    config_file=$1
    alias_names=("k" "K")
    [ ! -f "$config_file" ] || touch "$config_file"
    for alias_name in "${alias_names[@]}"; do
        if ! grep -q "alias $alias_name=" "$config_file"; then 
            echo "Adding alias $alias_name to $config_file"
            echo "alias $alias_name='cd ~ && ./ssh_tool.sh'" >> "$config_file"
        fi
    done
    . "$config_file"
}
config_files=("/root/.bashrc" "/root/.profile" "/root/.bash_profile")
for config_file in "${config_files[@]}"; do
    add_alias "$config_file"
done

# 获取当前服务器ipv4和ipv6
ip_address() {
    ipv4_address=$(curl -s ipv4.ip.sb)
    ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

# 安装依赖包
install() {
    if [ $# -eq 0 ]; then
        echo -e "${red}未提供软件包参数!${re}"
        return 1
    fi

    for package in "$@"; do
        if command -v "$package" &>/dev/null; then
            echo -e "${green}${package}已经安装了！${re}"
            continue
        fi
        echo -e "${yellow}正在安装 ${package}...${re}"
        if command -v apt &>/dev/null; then
            apt install -y "$package"
        elif command -v dnf &>/dev/null; then
            dnf install -y "$package"
        elif command -v yum &>/dev/null; then
            yum install -y "$package"
        elif command -v apk &>/dev/null; then
            apk add "$package"
        else
            echo -e"${red}暂不支持你的系统!${re}"
            return 1
        fi
    done

    return 0
}

# 安装nodejs
install_nodejs(){
    if command -v node &>/dev/null; then
        # 获取当前已安装nodejs版本
        installed_version=$(node --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${green}系统中已经安装Nodejs,版本:${red}${installed_version}${re}"
    else
        echo -e "${yellow}系统中未安装nodejs，正在为你安装...${re}"

        # 根据对应系统安装nodejs
        if command -v apt &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && install nodejs
        elif command -v dnf &>/dev/null; then
            dnf install -y nodejs npm
        elif command -v yum &>/dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_21.x | sudo bash - && install nodejs
        elif command -v apk &>/dev/null; then
            apk add nodejs npm
        else
            echo -e "${red}暂不支持你的系统!${re}"
            return 1
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${green}nodejs安装成功!${re}"
            sleep 2
        else
            echo -e "${red}nodejs安装失败，尝试再次安装...${re}"
            install nodejs npm
            sleep 2
        fi
    fi 
}

# 安装java
install_java() {
    if command -v java &>/dev/null; then
        # 检查安装版本
        installed_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        echo -e "${green}系统已经安装Java${yellow}${installed_version}${re}"     
    else
        echo -e "${yellow}系统中未安装Java，正在为你安装...${re}"

        if command -v apt &>/dev/null; then
            apt install -y openjdk-17-jdk
        elif command -v yum &>/dev/null; then
            yum install -y java-17-openjdk
        elif command -v dnf &>/dev/null; then
            dnf install -y java-17-openjdk
        elif command -v apk &>/dev/null; then
            apk add openjdk17
        else
            echo -e "${red}暂不支持你的系统！${re}"
            exit 1
        fi
        echo -e "${green}Java安装成功${re}"
        sleep 2
    fi   
}

# 卸载依赖包
remove() {
    if [ $# -eq 0 ]; then
        echo -e "${red}未提供软件包参数!${re}"
        return 1
    fi

    for package in "$@"; do
        if command -v apt &>/dev/null; then
            apt remove -y "$package" && apt autoremove -y
        elif command -v dnf &>/dev/null; then
            dnf remove -y "$package" && dnf autoremove -y
        elif command -v yum &>/dev/null; then
            yum remove -y "$package" && yum autoremove -y
        elif command -v apk &>/dev/null; then
            apk del "$package"
        else
            echo -e "${red}暂不支持你的系统!${re}"
            return 1
        fi
    done

    return 0
}

# 初始安装依赖包
install_dependency() {
      clear
      install wget socat unzip tar
}

# 等待用户返回
break_end() {
    echo -e "${green}执行完成${re}"
    echo -e "${yellow}按任意键返回...${re}"
    read -n 1 -s -r -p ""
    echo ""
    clear
}
# 返回主菜单
main_menu() {
    cd ~
    ./ssh_tool.sh
    exit
}
# 工具箱名称
TOOLBOX_NAME="Maple工具箱"
VPS_TOOLS_URL="https://raw.githubusercontent.com/Maple-Ling/maple/main/vps_tools/vps_tools.sh"
VPS_TOOLS_FILE="vps_tools.sh"


# 下载并检查文件是否已存在
download_or_replace_script() {
    echo -e "${skyblue}正在检查脚本文件...${re}"

    if [ -f "$VPS_TOOLS_FILE" ]; then
        echo -e "${skyblue}文件已存在，正在替换脚本...${re}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    else
        echo -e "${skyblue}文件不存在，正在下载脚本...${re}"
        wget -q -O "$VPS_TOOLS_FILE" "$VPS_TOOLS_URL" && chmod +x "$VPS_TOOLS_FILE"
    fi
}

# 主菜单
show_menu() {
    clear
    echo -e "${skyblue}${TOOLBOX_NAME}${re}"

    # 输出菜单
    echo "左侧菜单:                               右侧菜单:"
    echo "1  节点搭建                              2  WARP 工具"
    echo "0  返回上一级"
    echo "99  退出工具箱"

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
    echo -e "${skyblue}节点搭建工具:${re}"
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
    echo -e "${skyblue}WARP 工具:${re}"
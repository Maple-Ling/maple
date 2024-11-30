#!/bin/bash
sh_v="3.4.9"


gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'



canshu="default"
permission_granted="false"
ENABLE_STATS="true"


quanju_canshu() {
if [ "$canshu" = "CN" ]; then
	zhushi=0
	gh_proxy="https://gh.kejilion.pro/"
elif [ "$canshu" = "V6" ]; then
	zhushi=1
	gh_proxy="https://gh.kejilion.pro/"
else
	zhushi=1  # 0 琛ㄧず鎵ц锛�1 琛ㄧず涓嶆墽琛�
	gh_proxy=""
fi

}
quanju_canshu



# 瀹氫箟涓€涓嚱鏁版潵鎵ц鍛戒护
run_command() {
	if [ "$zhushi" -eq 0 ]; then
		"$@"
	fi
}


canshu_v6() {
	if grep -q '^canshu="V6"' /usr/local/bin/k > /dev/null 2>&1; then
		sed -i 's/^canshu="default"/canshu="V6"/' ~/kejilion.sh
		sed -i 's/^canshu="default"/canshu="V6"/' /usr/local/bin/k
	fi
}


CheckFirstRun_true() {
	if grep -q '^permission_granted="true"' /usr/local/bin/k > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k
	fi
}



# 鏀堕泦鍔熻兘鍩嬬偣淇℃伅鐨勫嚱鏁帮紝璁板綍褰撳墠鑴氭湰鐗堟湰鍙凤紝浣跨敤鏃堕棿锛岀郴缁熺増鏈紝CPU鏋舵瀯锛屾満鍣ㄦ墍鍦ㄥ浗瀹跺拰鐢ㄦ埛浣跨敤鐨勫姛鑳藉悕绉帮紝缁濆涓嶆秹鍙婁换浣曟晱鎰熶俊鎭紝璇锋斁蹇冿紒璇风浉淇℃垜锛�
# 涓轰粈涔堣璁捐杩欎釜鍔熻兘锛岀洰鐨勬洿濂界殑浜嗚В鐢ㄦ埛鍠滄浣跨敤鐨勫姛鑳斤紝杩涗竴姝ヤ紭鍖栧姛鑳芥帹鍑烘洿澶氱鍚堢敤鎴烽渶姹傜殑鍔熻兘銆�
# 鍏ㄦ枃鍙悳鎼� send_stats 鍑芥暟璋冪敤浣嶇疆锛岄€忔槑寮€婧愶紝濡傛湁椤捐檻鍙嫆缁濅娇鐢ㄣ€�



send_stats() {

	if [ "$ENABLE_STATS" == "false" ]; then
		return
	fi

	local country=$(curl -s ipinfo.io/country)
	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
	local cpu_arch=$(uname -m)
	curl -s -X POST "https://api.kejilion.pro/api/log" \
		 -H "Content-Type: application/json" \
		 -d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$sh_v\"}" &>/dev/null &
}


yinsiyuanquan2() {

if grep -q '^ENABLE_STATS="false"' /usr/local/bin/k > /dev/null 2>&1; then
	sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/kejilion.sh
	sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' /usr/local/bin/k
fi

}



canshu_v6
CheckFirstRun_true
yinsiyuanquan2

cp -f ./kejilion.sh ~/kejilion.sh > /dev/null 2>&1
cp -f ~/kejilion.sh /usr/local/bin/k > /dev/null 2>&1



CheckFirstRun_false() {
	if grep -q '^permission_granted="false"' /usr/local/bin/k > /dev/null 2>&1; then
		UserLicenseAgreement
	fi
}

# 鎻愮ず鐢ㄦ埛鍚屾剰鏉℃
UserLicenseAgreement() {
	clear
	echo -e "${gl_kjlan}娆㈣繋浣跨敤绉戞妧lion鑴氭湰宸ュ叿绠�${gl_bai}"
	echo "棣栨浣跨敤鑴氭湰锛岃鍏堥槄璇诲苟鍚屾剰鐢ㄦ埛璁稿彲鍗忚銆�"
	echo "鐢ㄦ埛璁稿彲鍗忚: https://blog.kejilion.pro/user-license-agreement/"
	echo -e "----------------------"
	read -r -p "鏄惁鍚屾剰浠ヤ笂鏉℃锛�(y/n): " user_input


	if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
		send_stats "璁稿彲鍚屾剰"
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k
	else
		send_stats "璁稿彲鎷掔粷"
		clear
		exit
	fi
}

CheckFirstRun_false





ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}



install() {
	if [ $# -eq 0 ]; then
		echo "鏈彁渚涜蒋浠跺寘鍙傛暟!"
		return
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			echo -e "${gl_huang}姝ｅ湪瀹夎 $package...${gl_bai}"
			if command -v dnf &>/dev/null; then
				dnf -y update
				dnf install -y epel-release
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y update
				yum install -y epel-release
				yum -y install "$package"
			elif command -v apt &>/dev/null; then
				apt update -y
				apt install -y "$package"
			elif command -v apk &>/dev/null; then
				apk update
				apk add "$package"
			elif command -v pacman &>/dev/null; then
				pacman -Syu --noconfirm
				pacman -S --noconfirm "$package"
			elif command -v zypper &>/dev/null; then
				zypper refresh
				zypper install -y "$package"
			elif command -v opkg &>/dev/null; then
				opkg update
				opkg install "$package"
			else
				echo "鏈煡鐨勫寘绠＄悊鍣�!"
				return
			fi
		else
			echo -e "${gl_lv}$package 宸茬粡瀹夎${gl_bai}"
		fi
	done

	return
}


install_dependency() {
	  install wget unzip tar
}


remove() {
	if [ $# -eq 0 ]; then
		echo "鏈彁渚涜蒋浠跺寘鍙傛暟!"
		return
	fi

	for package in "$@"; do
		echo -e "${gl_huang}姝ｅ湪鍗歌浇 $package...${gl_bai}"
		if command -v dnf &>/dev/null; then
			dnf remove -y "${package}"*
		elif command -v yum &>/dev/null; then
			yum remove -y "${package}"*
		elif command -v apt &>/dev/null; then
			apt purge -y "${package}"*
		elif command -v apk &>/dev/null; then
			apk del "${package}*"
		elif command -v pacman &>/dev/null; then
			pacman -Rns --noconfirm "${package}"
		elif command -v zypper &>/dev/null; then
			zypper remove -y "${package}"
		elif command -v opkg &>/dev/null; then
			opkg remove "${package}"
		else
			echo "鏈煡鐨勫寘绠＄悊鍣�!"
			return
		fi
	done

	return
}


# 閫氱敤 systemctl 鍑芥暟锛岄€傜敤浜庡悇绉嶅彂琛岀増
systemctl() {
	local COMMAND="$1"
	local SERVICE_NAME="$2"

	if command -v apk &>/dev/null; then
		service "$SERVICE_NAME" "$COMMAND"
	else
		/bin/systemctl "$COMMAND" "$SERVICE_NAME"
	fi
}


# 閲嶅惎鏈嶅姟
restart() {
	systemctl restart "$1"
	if [ $? -eq 0 ]; then
		echo "$1 鏈嶅姟宸查噸鍚€�"
	else
		echo "閿欒锛氶噸鍚� $1 鏈嶅姟澶辫触銆�"
	fi
}

# 鍚姩鏈嶅姟
start() {
	systemctl start "$1"
	if [ $? -eq 0 ]; then
		echo "$1 鏈嶅姟宸插惎鍔ㄣ€�"
	else
		echo "閿欒锛氬惎鍔� $1 鏈嶅姟澶辫触銆�"
	fi
}

# 鍋滄鏈嶅姟
stop() {
	systemctl stop "$1"
	if [ $? -eq 0 ]; then
		echo "$1 鏈嶅姟宸插仠姝€€�"
	else
		echo "閿欒锛氬仠姝� $1 鏈嶅姟澶辫触銆�"
	fi
}

# 鏌ョ湅鏈嶅姟鐘舵€�
status() {
	systemctl status "$1"
	if [ $? -eq 0 ]; then
		echo "$1 鏈嶅姟鐘舵€佸凡鏄剧ず銆�"
	else
		echo "閿欒锛氭棤娉曟樉绀� $1 鏈嶅姟鐘舵€併€�"
	fi
}


enable() {
	local SERVICE_NAME="$1"
	if command -v apk &>/dev/null; then
		rc-update add "$SERVICE_NAME" default
	else
	   /bin/systemctl enable "$SERVICE_NAME"
	fi

	echo "$SERVICE_NAME 宸茶缃负寮€鏈鸿嚜鍚€�"
}



break_end() {
	  echo -e "${gl_lv}鎿嶄綔瀹屾垚${gl_bai}"
	  echo "鎸変换鎰忛敭缁х画..."
	  read -n 1 -s -r -p ""
	  echo ""
	  clear
}

kejilion() {
			cd ~
			kejilion_sh
}




check_port() {
	install lsof

	stop_containers_or_kill_process() {
		local port=$1
		local containers=$(docker ps --filter "publish=$port" --format "{{.ID}}" 2>/dev/null)

		if [ -n "$containers" ]; then
			docker stop $containers
		else
			for pid in $(lsof -t -i:$port); do
				kill -9 $pid
			done
		fi
	}

	stop_containers_or_kill_process 80
	stop_containers_or_kill_process 443
}


install_add_docker_cn() {

local country=$(curl -s ipinfo.io/country)
if [ "$country" = "CN" ]; then
	cat > /etc/docker/daemon.json << EOF
{
	"registry-mirrors": ["https://docker.kejilion.pro"]
}
EOF

fi


enable docker
start docker
restart docker

}


install_add_docker_guanfang() {
local country=$(curl -s ipinfo.io/country)
if [ "$country" = "CN" ]; then
	cd ~
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/docker/main/install && chmod +x install
	sh install --mirror Aliyun
	rm -f install
else
	curl -fsSL https://get.docker.com | sh
fi
install_add_docker_cn


}



install_add_docker() {
	echo -e "${gl_huang}姝ｅ湪瀹夎docker鐜...${gl_bai}"
	if  [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
		install_add_docker_guanfang
	elif command -v dnf &>/dev/null; then
		dnf update -y
		dnf install -y yum-utils device-mapper-persistent-data lvm2
		rm -f /etc/yum.repos.d/docker*.repo > /dev/null
		country=$(curl -s ipinfo.io/country)
		arch=$(uname -m)
		if [ "$country" = "CN" ]; then
			curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo > /dev/null
		else
			yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
		fi
		dnf install -y docker-ce docker-ce-cli containerd.io
		install_add_docker_cn

	elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
		apt update
		apt upgrade -y
		apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
		rm -f /usr/share/keyrings/docker-archive-keyring.gpg
		local country=$(curl -s ipinfo.io/country)
		local arch=$(uname -m)
		if [ "$country" = "CN" ]; then
			if [ "$arch" = "x86_64" ]; then
				sed -i '/^deb \[arch=amd64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			elif [ "$arch" = "aarch64" ]; then
				sed -i '/^deb \[arch=arm64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			fi
		else
			if [ "$arch" = "x86_64" ]; then
				sed -i '/^deb \[arch=amd64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			elif [ "$arch" = "aarch64" ]; then
				sed -i '/^deb \[arch=arm64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list > /dev/null
				mkdir -p /etc/apt/keyrings
				curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
				echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
			fi
		fi
		apt update
		apt install -y docker-ce docker-ce-cli containerd.io
		install_add_docker_cn


	elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
		install_add_docker_guanfang
	else
		install docker docker-compose
		install_add_docker_cn

	fi
	sleep 2
}


install_docker() {
	if ! command -v docker &>/dev/null; then
		install_add_docker
	else
		echo -e "${gl_lv}Docker鐜宸茬粡瀹夎${gl_bai}"
	fi
}


docker_ps() {
while true; do
	clear
	send_stats "Docker瀹瑰櫒绠＄悊"
	echo "Docker瀹瑰櫒鍒楄〃"
	docker ps -a
	echo ""
	echo "瀹瑰櫒鎿嶄綔"
	echo "------------------------"
	echo "1. 鍒涘缓鏂扮殑瀹瑰櫒"
	echo "------------------------"
	echo "2. 鍚姩鎸囧畾瀹瑰櫒             6. 鍚姩鎵€鏈夊鍣�"
	echo "3. 鍋滄鎸囧畾瀹瑰櫒             7. 鍋滄鎵€鏈夊鍣�"
	echo "4. 鍒犻櫎鎸囧畾瀹瑰櫒             8. 鍒犻櫎鎵€鏈夊鍣�"
	echo "5. 閲嶅惎鎸囧畾瀹瑰櫒             9. 閲嶅惎鎵€鏈夊鍣�"
	echo "------------------------"
	echo "11. 杩涘叆鎸囧畾瀹瑰櫒           12. 鏌ョ湅瀹瑰櫒鏃ュ織"
	echo "13. 鏌ョ湅瀹瑰櫒缃戠粶           14. 鏌ョ湅瀹瑰櫒鍗犵敤"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾ч€夊崟"
	echo "------------------------"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
	case $sub_choice in
		1)
			send_stats "鏂板缓瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ垱寤哄懡浠�: " dockername
			$dockername
			;;
		2)
			send_stats "鍚姩鎸囧畾瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕锛堝涓鍣ㄥ悕璇风敤绌烘牸鍒嗛殧锛�: " dockername
			docker start $dockername
			;;
		3)
			send_stats "鍋滄鎸囧畾瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕锛堝涓鍣ㄥ悕璇风敤绌烘牸鍒嗛殧锛�: " dockername
			docker stop $dockername
			;;
		4)
			send_stats "鍒犻櫎鎸囧畾瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕锛堝涓鍣ㄥ悕璇风敤绌烘牸鍒嗛殧锛�: " dockername
			docker rm -f $dockername
			;;
		5)
			send_stats "閲嶅惎鎸囧畾瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕锛堝涓鍣ㄥ悕璇风敤绌烘牸鍒嗛殧锛�: " dockername
			docker restart $dockername
			;;
		6)
			send_stats "鍚姩鎵€鏈夊鍣�"
			docker start $(docker ps -a -q)
			;;
		7)
			send_stats "鍋滄鎵€鏈夊鍣�"
			docker stop $(docker ps -q)
			;;
		8)
			send_stats "鍒犻櫎鎵€鏈夊鍣�"
			read -e -p "$(echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}纭畾鍒犻櫎鎵€鏈夊鍣ㄥ悧锛�(Y/N): ")" choice
			case "$choice" in
			  [Yy])
				docker rm -f $(docker ps -a -q)
				;;
			  [Nn])
				;;
			  *)
				echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				;;
			esac
			;;
		9)
			send_stats "閲嶅惎鎵€鏈夊鍣�"
			docker restart $(docker ps -q)
			;;
		11)
			send_stats "杩涘叆瀹瑰櫒"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕: " dockername
			docker exec -it $dockername /bin/sh
			break_end
			;;
		12)
			send_stats "鏌ョ湅瀹瑰櫒鏃ュ織"
			read -e -p "璇疯緭鍏ュ鍣ㄥ悕: " dockername
			docker logs $dockername
			break_end
			;;
		13)
			send_stats "鏌ョ湅瀹瑰櫒缃戠粶"
			echo ""
			container_ids=$(docker ps -q)
			echo "------------------------------------------------------------"
			printf "%-25s %-25s %-25s\n" "瀹瑰櫒鍚嶇О" "缃戠粶鍚嶇О" "IP鍦板潃"
			for container_id in $container_ids; do
				local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
				local container_name=$(echo "$container_info" | awk '{print $1}')
				local network_info=$(echo "$container_info" | cut -d' ' -f2-)
				while IFS= read -r line; do
					local network_name=$(echo "$line" | awk '{print $1}')
					local ip_address=$(echo "$line" | awk '{print $2}')
					printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
				done <<< "$network_info"
			done
			break_end
			;;
		14)
			send_stats "鏌ョ湅瀹瑰櫒鍗犵敤"
			docker stats --no-stream
			break_end
			;;
		0)
			break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
			;;
		*)
			break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
			;;
	esac
done
}


docker_image() {
while true; do
	clear
	send_stats "Docker闀滃儚绠＄悊"
	echo "Docker闀滃儚鍒楄〃"
	docker image ls
	echo ""
	echo "闀滃儚鎿嶄綔"
	echo "------------------------"
	echo "1. 鑾峰彇鎸囧畾闀滃儚             3. 鍒犻櫎鎸囧畾闀滃儚"
	echo "2. 鏇存柊鎸囧畾闀滃儚             4. 鍒犻櫎鎵€鏈夐暅鍍�"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾ч€夊崟"
	echo "------------------------"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
	case $sub_choice in
		1)
			send_stats "鎷夊彇闀滃儚"
			read -e -p "璇疯緭鍏ラ暅鍍忓悕锛堝涓暅鍍忓悕璇风敤绌烘牸鍒嗛殧锛�: " imagenames
			for name in $imagenames; do
				echo -e "${gl_huang}姝ｅ湪鑾峰彇闀滃儚: $name${gl_bai}"
				docker pull $name
			done
			;;
		2)
			send_stats "鏇存柊闀滃儚"
			read -e -p "璇疯緭鍏ラ暅鍍忓悕锛堝涓暅鍍忓悕璇风敤绌烘牸鍒嗛殧锛�: " imagenames
			for name in $imagenames; do
				echo -e "${gl_huang}姝ｅ湪鏇存柊闀滃儚: $name${gl_bai}"
				docker pull $name
			done
			;;
		3)
			send_stats "鍒犻櫎闀滃儚"
			read -e -p "璇疯緭鍏ラ暅鍍忓悕锛堝涓暅鍍忓悕璇风敤绌烘牸鍒嗛殧锛�: " imagenames
			for name in $imagenames; do
				docker rmi -f $name
			done
			;;
		4)
			send_stats "鍒犻櫎鎵€鏈夐暅鍍�"
			read -e -p "$(echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}纭畾鍒犻櫎鎵€鏈夐暅鍍忓悧锛�(Y/N): ")" choice
			case "$choice" in
			  [Yy])
				docker rmi -f $(docker images -q)
				;;
			  [Nn])
				;;
			  *)
				echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				;;
			esac
			;;
		0)
			break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
			;;
		*)
			break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
			;;
	esac
done


}





check_crontab_installed() {
	if command -v crontab >/dev/null 2>&1; then
		echo -e "${gl_lv}crontab 宸茬粡瀹夎${gl_bai}"
		return
	else
		install_crontab
		return
	fi
}



install_crontab() {

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian|kali)
				apt update
				apt install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			centos|rhel|almalinux|rocky|fedora)
				yum install -y cronie
				systemctl enable crond
				systemctl start crond
				;;
			alpine)
				apk add --no-cache cronie
				rc-update add crond
				rc-service crond start
				;;
			arch|manjaro)
				pacman -S --noconfirm cronie
				systemctl enable cronie
				systemctl start cronie
				;;
			opensuse|suse|opensuse-tumbleweed)
				zypper install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			openwrt|lede)
				opkg update
				opkg install cron
				/etc/init.d/cron enable
				/etc/init.d/cron start
				;;
			*)
				echo "涓嶆敮鎸佺殑鍙戣鐗�: $ID"
				return
				;;
		esac
	else
		echo "鏃犳硶纭畾鎿嶄綔绯荤粺銆�"
		return
	fi

	echo -e "${gl_lv}crontab 宸插畨瑁呬笖 cron 鏈嶅姟姝ｅ湪杩愯銆�${gl_bai}"
}



docker_ipv6_on() {
	root_use
	install jq

	local CONFIG_FILE="/etc/docker/daemon.json"
	local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'

	# 妫€鏌ラ厤缃枃浠舵槸鍚﹀瓨鍦紝濡傛灉涓嶅瓨鍦ㄥ垯鍒涘缓鏂囦欢骞跺啓鍏ラ粯璁よ缃�
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "$REQUIRED_IPV6_CONFIG" | jq . > "$CONFIG_FILE"
		restart docker
	else
		# 浣跨敤jq澶勭悊閰嶇疆鏂囦欢鐨勬洿鏂�
		local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

		# 妫€鏌ュ綋鍓嶉厤缃槸鍚﹀凡缁忔湁 ipv6 璁剧疆
		local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')

		# 鏇存柊閰嶇疆锛屽紑鍚� IPv6
		if [[ "$CURRENT_IPV6" == "false" ]]; then
			UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
		else
			UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
		fi

		# 瀵规瘮鍘熷閰嶇疆涓庢柊閰嶇疆
		if [[ "$ORIGINAL_CONFIG" == "$UPDATED_CONFIG" ]]; then
			echo -e "${gl_huang}褰撳墠宸插紑鍚痠pv6璁块棶${gl_bai}"
		else
			echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
			restart docker
		fi
	fi
}


docker_ipv6_off() {
	root_use
	install jq

	local CONFIG_FILE="/etc/docker/daemon.json"

	# 妫€鏌ラ厤缃枃浠舵槸鍚﹀瓨鍦�
	if [ ! -f "$CONFIG_FILE" ]; then
		echo -e "${gl_hong}閰嶇疆鏂囦欢涓嶅瓨鍦�${gl_bai}"
		return
	fi

	# 璇诲彇褰撳墠閰嶇疆
	local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

	# 浣跨敤jq澶勭悊閰嶇疆鏂囦欢鐨勬洿鏂�
	local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')

	# 妫€鏌ュ綋鍓嶇殑 ipv6 鐘舵€�
	local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')

	# 瀵规瘮鍘熷閰嶇疆涓庢柊閰嶇疆
	if [[ "$CURRENT_IPV6" == "false" ]]; then
		echo -e "${gl_huang}褰撳墠宸插叧闂璱pv6璁块棶${gl_bai}"
	else
		echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
		restart docker
		echo -e "${gl_huang}宸叉垚鍔熷叧闂璱pv6璁块棶${gl_bai}"
	fi
}




iptables_open() {
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	ip6tables -P INPUT ACCEPT
	ip6tables -P FORWARD ACCEPT
	ip6tables -P OUTPUT ACCEPT
	ip6tables -F

}



add_swap() {
	local new_swap=$1  # 鑾峰彇浼犲叆鐨勫弬鏁�

	# 鑾峰彇褰撳墠绯荤粺涓墍鏈夌殑 swap 鍒嗗尯
	local swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

	# 閬嶅巻骞跺垹闄ゆ墍鏈夌殑 swap 鍒嗗尯
	for partition in $swap_partitions; do
		swapoff "$partition"
		wipefs -a "$partition"
		mkswap -f "$partition"
	done

	# 纭繚 /swapfile 涓嶅啀琚娇鐢�
	swapoff /swapfile

	# 鍒犻櫎鏃х殑 /swapfile
	rm -f /swapfile

	# 鍒涘缓鏂扮殑 swap 鍒嗗尯
	fallocate -l ${new_swap}M /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile

	sed -i '/\/swapfile/d' /etc/fstab
	echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

	if [ -f /etc/alpine-release ]; then
		echo "nohup swapon /swapfile" > /etc/local.d/swap.start
		chmod +x /etc/local.d/swap.start
		rc-update add local
	fi

	echo -e "铏氭嫙鍐呭瓨澶у皬宸茶皟鏁翠负${gl_huang}${new_swap}${gl_bai}MB"
}




check_swap() {

local swap_total=$(free -m | awk 'NR==3{print $2}')

# 鍒ゆ柇鏄惁闇€瑕佸垱寤鸿櫄鎷熷唴瀛�
[ "$swap_total" -gt 0 ] || add_swap 1024


}









ldnmp_v() {

	  # 鑾峰彇nginx鐗堟湰
	  local nginx_version=$(docker exec nginx nginx -v 2>&1)
	  local nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "nginx : ${gl_huang}v$nginx_version${gl_bai}"

	  # 鑾峰彇mysql鐗堟湰
	  local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  local mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
	  echo -n -e "            mysql : ${gl_huang}v$mysql_version${gl_bai}"

	  # 鑾峰彇php鐗堟湰
	  local php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
	  echo -n -e "            php : ${gl_huang}v$php_version${gl_bai}"

	  # 鑾峰彇redis鐗堟湰
	  local redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
	  echo -e "            redis : ${gl_huang}v$redis_version${gl_bai}"

	  echo "------------------------"
	  echo ""

}



install_ldnmp_conf() {

  # 鍒涘缓蹇呰鐨勭洰褰曞拰鏂囦欢
  cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml
  wget -O /home/web/nginx.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf
  wget -O /home/web/conf.d/default.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/default10.conf

  default_server_ssl

  # 涓嬭浇 docker-compose.yml 鏂囦欢骞惰繘琛屾浛鎹�
  wget -O /home/web/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml
  dbrootpasswd=$(openssl rand -base64 16) ; dbuse=$(openssl rand -hex 4) ; dbusepasswd=$(openssl rand -base64 8)

  # 鍦� docker-compose.yml 鏂囦欢涓繘琛屾浛鎹�
  sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
  sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml

}





install_ldnmp() {

	  check_swap

	  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml

	  if ! grep -q "healthcheck" /home/web/docker-compose.yml; then
		wget -O /home/web/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml
	  	dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')
	  	dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')
	  	dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose1.yml | tr -d '[:space:]')

  		sed -i "s#webroot#$dbrootpasswd#g" /home/web/docker-compose.yml
  		sed -i "s#kejilionYYDS#$dbusepasswd#g" /home/web/docker-compose.yml
  		sed -i "s#kejilion#$dbuse#g" /home/web/docker-compose.yml
	  fi

	  if grep -q "kjlion/nginx:alpine" /home/web/docker-compose1.yml; then
	  	sed -i 's|kjlion/nginx:alpine|nginx:alpine|g' /home/web/docker-compose.yml  > /dev/null 2>&1
		sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml  > /dev/null 2>&1
	  fi

	  cd /home/web && docker compose up -d
	  sleep 1
  	  crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
  	  (crontab -l 2>/dev/null; echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf') | crontab -
	  restart_ldnmp

	  clear
	  echo "LDNMP鐜瀹夎瀹屾瘯"
	  echo "------------------------"
	  ldnmp_v

}


install_certbot() {

	cd ~
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
	chmod +x auto_cert_renewal.sh

	check_crontab_installed
	local cron_job="0 0 * * * ~/auto_cert_renewal.sh"

	local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

	if [ -z "$existing_cron" ]; then
		(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
		echo "缁浠诲姟宸叉坊鍔�"
	fi
}


install_ssltls() {
	  docker stop nginx > /dev/null 2>&1
	  iptables_open > /dev/null 2>&1
	  check_port > /dev/null 2>&1
	  cd ~

	  local file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
	  if [ ! -f "$file_path" ]; then
		 	local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
	  		local ipv6_pattern='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))))$'
			if [[ ($yuming =~ $ipv4_pattern || $yuming =~ $ipv6_pattern) ]]; then
				mkdir -p /etc/letsencrypt/live/$yuming/
				if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
					openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/letsencrypt/live/$yuming/privkey.pem -out /etc/letsencrypt/live/$yuming/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
				else
					openssl genpkey -algorithm Ed25519 -out /etc/letsencrypt/live/$yuming/privkey.pem
					openssl req -x509 -key /etc/letsencrypt/live/$yuming/privkey.pem -out /etc/letsencrypt/live/$yuming/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
				fi
			else
				docker run -it --rm -p 80:80 -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot certonly --standalone -d "$yuming" --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
			fi
	  fi

	  cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/web/certs/${yuming}_cert.pem > /dev/null 2>&1
	  cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem > /dev/null 2>&1

	  docker start nginx > /dev/null 2>&1
}



install_ssltls_text() {
	echo -e "${gl_huang}$yuming 鍏挜淇℃伅${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/fullchain.pem
	echo ""
	echo -e "${gl_huang}$yuming 绉侀挜淇℃伅${gl_bai}"
	cat /etc/letsencrypt/live/$yuming/privkey.pem
	echo ""
	echo -e "${gl_huang}璇佷功瀛樻斁璺緞${gl_bai}"
	echo "鍏挜: /etc/letsencrypt/live/$yuming/fullchain.pem"
	echo "绉侀挜: /etc/letsencrypt/live/$yuming/privkey.pem"
	echo ""
}





add_ssl() {

yuming="${1:-}"
if [ -z "$yuming" ]; then
	add_yuming
fi
install_docker
install_certbot
docker run -it --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name "$yuming" -n 2>/dev/null
install_ssltls
certs_status
install_ssltls_text
ssl_ps
}


ssl_ps() {
	echo -e "${gl_huang}宸茬敵璇风殑璇佷功鍒版湡鎯呭喌${gl_bai}"
	echo "绔欑偣淇℃伅                      璇佷功鍒版湡鏃堕棿"
	echo "------------------------"
	for cert_dir in /etc/letsencrypt/live/*; do
	  local cert_file="$cert_dir/fullchain.pem"
	  if [ -f "$cert_file" ]; then
		local domain=$(basename "$cert_dir")
		local expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
		local formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
		printf "%-30s%s\n" "$domain" "$formatted_date"
	  fi
	done
	echo ""
}




default_server_ssl() {
install openssl

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
else
	openssl genpkey -algorithm Ed25519 -out /home/web/certs/default_server.key
	openssl req -x509 -key /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
fi

openssl rand -out /home/web/certs/ticket12.key 48
openssl rand -out /home/web/certs/ticket13.key 80

}


certs_status() {

	sleep 1

	local file_path="/etc/letsencrypt/live/$yuming/fullchain.pem"
	if [ -f "$file_path" ]; then
		send_stats "鍩熷悕璇佷功鐢宠鎴愬姛"
	else
		send_stats "鍩熷悕璇佷功鐢宠澶辫触"
		echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}妫€娴嬪埌鍩熷悕璇佷功鐢宠澶辫触锛岃妫€娴嬪煙鍚嶆槸鍚︽纭В鏋愭垨鏇存崲鍩熷悕閲嶆柊灏濊瘯锛�"
		break_end
		clear
		echo "璇峰啀娆″皾璇�"
		add_yuming
		repeat_add_yuming
		install_ssltls
		certs_status
	fi

}


repeat_add_yuming() {
if [ -e /home/web/conf.d/$yuming.conf ]; then
  send_stats "鍩熷悕閲嶅浣跨敤"
  web_del "${yuming}" > /dev/null 2>&1
fi

}


add_yuming() {
	  ip_address
	  echo -e "鍏堝皢鍩熷悕瑙ｆ瀽鍒版湰鏈篒P: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨処P鎴栬€呰В鏋愯繃鐨勫煙鍚�: " yuming
}


add_db() {
	  dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
	  dbname="${dbname}"

	  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	  docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

reverse_proxy() {
	  ip_address
	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/0.0.0.0/$ipv4_address/g" /home/web/conf.d/$yuming.conf
	  sed -i "s|0000|$duankou|g" /home/web/conf.d/$yuming.conf
	  nginx_http_on
	  docker restart nginx
}


restart_redis() {
  docker exec redis redis-cli FLUSHALL > /dev/null 2>&1
  docker exec -it redis redis-cli CONFIG SET maxmemory 512mb > /dev/null 2>&1
  docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null 2>&1
  docker exec -it redis redis-cli CONFIG SET save "" > /dev/null 2>&1
  docker exec -it redis redis-cli CONFIG SET appendonly no > /dev/null 2>&1
}



restart_ldnmp() {
	  restart_redis
	  docker exec nginx chown -R nginx:nginx /var/www/html > /dev/null 2>&1
	  docker exec nginx mkdir -p /var/cache/nginx/proxy > /dev/null 2>&1
	  docker exec nginx mkdir -p /var/cache/nginx/fastcgi > /dev/null 2>&1
	  docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy > /dev/null 2>&1
	  docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi > /dev/null 2>&1
	  docker exec php chown -R www-data:www-data /var/www/html > /dev/null 2>&1
	  docker exec php74 chown -R www-data:www-data /var/www/html > /dev/null 2>&1
	  cd /home/web && docker compose restart nginx php php74

}

nginx_upgrade() {

  local ldnmp_pods="nginx"
  cd /home/web/
  docker rm -f $ldnmp_pods > /dev/null 2>&1
  docker images --filter=reference="kjlion/${ldnmp_pods}*" -q | xargs docker rmi > /dev/null 2>&1
  docker images --filter=reference="${ldnmp_pods}*" -q | xargs docker rmi > /dev/null 2>&1
  docker compose up -d --force-recreate $ldnmp_pods
  crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
  (crontab -l 2>/dev/null; echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf') | crontab -
  docker exec nginx chown -R nginx:nginx /var/www/html
  docker exec nginx mkdir -p /var/cache/nginx/proxy
  docker exec nginx mkdir -p /var/cache/nginx/fastcgi
  docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy
  docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi
  docker restart $ldnmp_pods > /dev/null 2>&1

  send_stats "鏇存柊$ldnmp_pods"
  echo "鏇存柊${ldnmp_pods}瀹屾垚"

}

phpmyadmin_upgrade() {
  local ldnmp_pods="phpmyadmin"
  local local docker_port=8877
  local dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
  local dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')

  cd /home/web/
  docker rm -f $ldnmp_pods > /dev/null 2>&1
  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
  curl -sS -O https://raw.githubusercontent.com/kejilion/docker/refs/heads/main/docker-compose.phpmyadmin.yml
  docker compose -f docker-compose.phpmyadmin.yml up -d
  clear
  ip_address

  check_docker_app_ip
  echo "鐧诲綍淇℃伅: "
  echo "鐢ㄦ埛鍚�: $dbuse"
  echo "瀵嗙爜: $dbusepasswd"
  echo
  send_stats "鍚姩$ldnmp_pods"
}


cf_purge_cache() {
  local CONFIG_FILE="/home/web/config/cf-purge-cache.txt"
  local API_TOKEN
  local EMAIL
  local ZONE_IDS

  # 妫€鏌ラ厤缃枃浠舵槸鍚﹀瓨鍦�
  if [ -f "$CONFIG_FILE" ]; then
	# 浠庨厤缃枃浠惰鍙� API_TOKEN 鍜� zone_id
	read API_TOKEN EMAIL ZONE_IDS < "$CONFIG_FILE"
	# 灏� ZONE_IDS 杞崲涓烘暟缁�
	ZONE_IDS=($ZONE_IDS)
  else
	# 鎻愮ず鐢ㄦ埛鏄惁娓呯悊缂撳瓨
	read -p "闇€瑕佹竻鐞� Cloudflare 鐨勭紦瀛樺悧锛燂紙y/n锛�: " answer
	if [[ "$answer" == "y" ]]; then
	  echo "CF淇℃伅淇濆瓨鍦�$CONFIG_FILE锛屽彲浠ュ悗鏈熶慨鏀笴F淇℃伅"
	  read -p "璇疯緭鍏ヤ綘鐨� API_TOKEN: " API_TOKEN
	  read -p "璇疯緭鍏ヤ綘鐨凜F鐢ㄦ埛鍚�: " EMAIL
	  read -p "璇疯緭鍏� zone_id锛堝涓敤绌烘牸鍒嗛殧锛�: " -a ZONE_IDS

	  mkdir -p /home/web/config/
	  echo "$API_TOKEN $EMAIL ${ZONE_IDS[*]}" > "$CONFIG_FILE"
	fi
  fi

  # 寰幆閬嶅巻姣忎釜 zone_id 骞舵墽琛屾竻闄ょ紦瀛樺懡浠�
  for ZONE_ID in "${ZONE_IDS[@]}"; do
	echo "姝ｅ湪娓呴櫎缂撳瓨 for zone_id: $ZONE_ID"
	curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
	-H "X-Auth-Email: $EMAIL" \
	-H "X-Auth-Key: $API_TOKEN" \
	-H "Content-Type: application/json" \
	--data '{"purge_everything":true}'
  done

  echo "缂撳瓨娓呴櫎璇锋眰宸插彂閫佸畬姣曘€�"
}



web_cache() {
  send_stats "娓呯悊绔欑偣缂撳瓨"
  # docker exec -it nginx rm -rf /var/cache/nginx
  cf_purge_cache
  docker exec php php -r 'opcache_reset();'
  docker exec php74 php -r 'opcache_reset();'
  docker restart nginx php php74 redis
  restart_redis
}



web_del() {

	send_stats "鍒犻櫎绔欑偣鏁版嵁"
	yuming_list="${1:-}"
	if [ -z "$yuming_list" ]; then
		read -e -p "鍒犻櫎绔欑偣鏁版嵁锛岃杈撳叆浣犵殑鍩熷悕锛堝涓煙鍚嶇敤绌烘牸闅斿紑锛�: " yuming_list
		if [[ -z "$yuming_list" ]]; then
			return
		fi
	fi

	for yuming in $yuming_list; do
		echo "姝ｅ湪鍒犻櫎鍩熷悕: $yuming"
		rm -r /home/web/html/$yuming
		rm /home/web/conf.d/$yuming.conf
		rm /home/web/certs/${yuming}_key.pem
		rm /home/web/certs/${yuming}_cert.pem

		# 灏嗗煙鍚嶈浆鎹负鏁版嵁搴撳悕
		dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
		dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')

		# 鍒犻櫎鏁版嵁搴撳墠妫€鏌ユ槸鍚﹀瓨鍦紝閬垮厤鎶ラ敊
		echo "姝ｅ湪鍒犻櫎鏁版嵁搴�: $dbname"
		docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE ${dbname};" > /dev/null 2>&1
	done

	docker restart nginx
}


nginx_waf() {
	local mode=$1

	if ! grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		wget -O /home/web/nginx.conf "${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf"
	fi

	# 鏍规嵁 mode 鍙傛暟鏉ュ喅瀹氬紑鍚垨鍏抽棴 WAF
	if [ "$mode" == "on" ]; then
		# 寮€鍚� WAF锛氬幓鎺夋敞閲�
		sed -i 's|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# modsecurity on;|\1modsecurity on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /home/web/nginx.conf > /dev/null 2>&1
	elif [ "$mode" == "off" ]; then
		# 鍏抽棴 WAF锛氬姞涓婃敞閲�
		sed -i 's|^load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)modsecurity on;|\1# modsecurity on;|' /home/web/nginx.conf > /dev/null 2>&1
		sed -i 's|^\(\s*\)modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /home/web/nginx.conf > /dev/null 2>&1
	else
		echo "鏃犳晥鐨勫弬鏁帮細浣跨敤 'on' 鎴� 'off'"
		return 1
	fi

	# 妫€鏌� nginx 闀滃儚骞舵牴鎹儏鍐靛鐞�
	if grep -q "kjlion/nginx:alpine" /home/web/docker-compose.yml; then
		docker restart nginx
	else
		sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /home/web/docker-compose.yml
		nginx_upgrade
	fi

}

check_waf_status() {
	if grep -q "^\s*#\s*modsecurity on;" /home/web/nginx.conf; then
		waf_status=""
	elif grep -q "modsecurity on;" /home/web/nginx.conf; then
		waf_status="WAF宸插紑鍚�"
	else
		waf_status=""
	fi
}


check_cf_mode() {
	if [ -f "/path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf" ]; then
		CFmessage="cf妯″紡宸插紑鍚�"
	else
		CFmessage=""
	fi
}


nginx_http_on() {

local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
local ipv6_pattern='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))))$'
if [[ ($yuming =~ $ipv4_pattern || $yuming =~ $ipv6_pattern) ]]; then
	sed -i '/if (\$scheme = http) {/,/}/s/^/#/' /home/web/conf.d/${yuming}.conf
fi

}




















check_docker_app() {

if docker inspect "$docker_name" &>/dev/null; then
	check_docker="${gl_lv}宸插畨瑁�${gl_bai}"
else
	check_docker="${gl_hui}鏈畨瑁�${gl_bai}"
fi

}


check_docker_app_ip() {
echo "------------------------"
echo "璁块棶鍦板潃:"
ip_address
if [ -n "$ipv4_address" ]; then
	echo "http://$ipv4_address:$docker_port"
fi

if [ -n "$ipv6_address" ]; then
	echo "http://[$ipv6_address]:$docker_port"
fi

local search_pattern="$ipv4_address:$docker_port"

for file in /home/web/conf.d/*; do
	if [ -f "$file" ]; then
		if grep -q "$search_pattern" "$file" 2>/dev/null; then
			echo "https://$(basename "$file" | sed 's/\.conf$//')"
		fi
	fi
done

}



docker_app() {
send_stats "${docker_name}绠＄悊"

while true; do
	clear
	check_docker_app
	echo -e "$docker_name $check_docker"
	echo "$docker_describe"
	echo "$docker_url"
	if docker inspect "$docker_name" &>/dev/null; then
		check_docker_app_ip
	fi
	echo ""
	echo "------------------------"
	echo "1. 瀹夎            2. 鏇存柊            3. 鍗歌浇"
	echo "------------------------"
	echo "5. 鍩熷悕璁块棶"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾�"
	echo "------------------------"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " choice
	 case $choice in
		1)
			install_docker
			$docker_rum
			clear
			echo "$docker_name 宸茬粡瀹夎瀹屾垚"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "瀹夎$docker_name"
			;;
		2)
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"

			$docker_rum
			clear
			echo "$docker_name 宸茬粡瀹夎瀹屾垚"
			check_docker_app_ip
			echo ""
			$docker_use
			$docker_passwd
			send_stats "鏇存柊$docker_name"
			;;
		3)
			docker rm -f "$docker_name"
			docker rmi -f "$docker_img"
			rm -rf "/home/docker/$docker_name"
			echo "搴旂敤宸插嵏杞�"
			send_stats "鍗歌浇$docker_name"
			;;

		5)
			echo "${docker_name}鍩熷悕璁块棶璁剧疆"
			send_stats "${docker_name}鍩熷悕璁块棶璁剧疆"
			add_yuming
			ldnmp_Proxy ${yuming} ${ipv4_address} ${docker_port}
			;;
		*)
			break
			;;
	 esac
	 break_end
done

}



prometheus_install() {

local PROMETHEUS_DIR="/home/docker/monitoring/prometheus"
local GRAFANA_DIR="/home/docker/monitoring/grafana"
local NETWORK_NAME="monitoring"

# Create necessary directories
mkdir -p $PROMETHEUS_DIR
mkdir -p $GRAFANA_DIR

# Set correct ownership for Grafana directory
chown -R 472:472 $GRAFANA_DIR

if [ ! -f "$PROMETHEUS_DIR/prometheus.yml" ]; then
	curl -o "$PROMETHEUS_DIR/prometheus.yml" ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/refs/heads/main/prometheus/prometheus.yml
fi

# Create Docker network for monitoring
docker network create $NETWORK_NAME

# Run Node Exporter container
docker run -d \
  --name=node-exporter \
  --network $NETWORK_NAME \
  --restart unless-stopped \
  prom/node-exporter

# Run Prometheus container
docker run -d \
  --name prometheus \
  -v $PROMETHEUS_DIR/prometheus.yml:/etc/prometheus/prometheus.yml \
  -v $PROMETHEUS_DIR/data:/prometheus \
  --network $NETWORK_NAME \
  --restart unless-stopped \
  --user 0:0 \
  prom/prometheus:latest

# Run Grafana container
docker run -d \
  --name grafana \
  -p 8047:3000 \
  -v $GRAFANA_DIR:/var/lib/grafana \
  --network $NETWORK_NAME \
  --restart unless-stopped \
  grafana/grafana:latest

}




cluster_python3() {
	cd ~/cluster/
	curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/python-for-vps/main/cluster/$py_task
	python3 ~/cluster/$py_task
}


tmux_run() {
	# Check if the session already exists
	tmux has-session -t $SESSION_NAME 2>/dev/null
	# $? is a special variable that holds the exit status of the last executed command
	if [ $? != 0 ]; then
	  # Session doesn't exist, create a new one
	  tmux new -s $SESSION_NAME
	else
	  # Session exists, attach to it
	  tmux attach-session -t $SESSION_NAME
	fi
}


tmux_run_d() {

local base_name="tmuxd"
local tmuxd_ID=1

# 妫€鏌ヤ細璇濇槸鍚﹀瓨鍦ㄧ殑鍑芥暟
session_exists() {
  tmux has-session -t $1 2>/dev/null
}

# 寰幆鐩村埌鎵惧埌涓€涓笉瀛樺湪鐨勪細璇濆悕绉�
while session_exists "$base_name-$tmuxd_ID"; do
  local tmuxd_ID=$((tmuxd_ID + 1))
done

# 鍒涘缓鏂扮殑 tmux 浼氳瘽
tmux new -d -s "$base_name-$tmuxd_ID" "$tmuxd"


}



f2b_status() {
	 docker restart fail2ban
	 sleep 3
	 docker exec -it fail2ban fail2ban-client status
}

f2b_status_xxx() {
	docker exec -it fail2ban fail2ban-client status $xxx
}

f2b_install_sshd() {

	docker run -d \
		--name=fail2ban \
		--net=host \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		-e PUID=1000 \
		-e PGID=1000 \
		-e TZ=Etc/UTC \
		-e VERBOSITY=-vv \
		-v /path/to/fail2ban/config:/config \
		-v /var/log:/var/log:ro \
		-v /home/web/log/nginx/:/remotelogs/nginx:ro \
		--restart unless-stopped \
		lscr.io/linuxserver/fail2ban:latest

	sleep 3
	if grep -q 'Alpine' /etc/issue; then
		cd /path/to/fail2ban/config/fail2ban/filter.d
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd.conf
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd-ddos.conf
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-ssh.conf
	elif command -v dnf &>/dev/null; then
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/centos-ssh.conf
	else
		install rsyslog
		systemctl start rsyslog
		systemctl enable rsyslog
		cd /path/to/fail2ban/config/fail2ban/jail.d/
		curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/linux-ssh.conf
	fi
}

f2b_sshd() {
	if grep -q 'Alpine' /etc/issue; then
		xxx=alpine-sshd
		f2b_status_xxx
	elif command -v dnf &>/dev/null; then
		xxx=centos-sshd
		f2b_status_xxx
	else
		xxx=linux-sshd
		f2b_status_xxx
	fi
}






server_reboot() {

	read -e -p "$(echo -e "${gl_huang}鎻愮ず: ${gl_bai}鐜板湪閲嶅惎鏈嶅姟鍣ㄥ悧锛�(Y/N): ")" rboot
	case "$rboot" in
	  [Yy])
		echo "宸查噸鍚�"
		reboot
		;;
	  *)
		echo "宸插彇娑�"
		;;
	esac


}

output_status() {
	output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
		NR > 2 { rx_total += $2; tx_total += $10 }
		END {
			rx_units = "Bytes";
			tx_units = "Bytes";
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

			if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

			printf("鎬绘帴鏀�:       %.2f %s\n鎬诲彂閫�:       %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
		}' /proc/net/dev)

}


ldnmp_install_status_one() {

   if docker inspect "php" &>/dev/null; then
	clear
	send_stats "鏃犳硶鍐嶆瀹夎LDNMP鐜"
	echo -e "${gl_huang}鎻愮ず: ${gl_bai}寤虹珯鐜宸插畨瑁呫€傛棤闇€鍐嶆瀹夎锛�"
	break_end
	linux_ldnmp
   else
	:
   fi

}


ldnmp_install_all() {
cd ~
send_stats "瀹夎LDNMP鐜"
root_use
clear
echo -e "${gl_huang}LDNMP鐜鏈畨瑁咃紝寮€濮嬪畨瑁匧DNMP鐜...${gl_bai}"
check_port
install_dependency
install_docker
install_certbot
install_ldnmp_conf
install_ldnmp

}


nginx_install_all() {
cd ~
send_stats "瀹夎nginx鐜"
root_use
clear
echo -e "${gl_huang}nginx鏈畨瑁咃紝寮€濮嬪畨瑁卬ginx鐜...${gl_bai}"
check_port
install_dependency
install_docker
install_certbot
install_ldnmp_conf
nginx_upgrade
clear
local nginx_version=$(docker exec nginx nginx -v 2>&1)
local nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
echo "nginx宸插畨瑁呭畬鎴�"
echo -e "褰撳墠鐗堟湰: ${gl_huang}v$nginx_version${gl_bai}"
echo ""

}




ldnmp_install_status() {

	if ! docker inspect "php" &>/dev/null; then
		send_stats "璇峰厛瀹夎LDNMP鐜"
		ldnmp_install_all
	fi

}


nginx_install_status() {

	if ! docker inspect "nginx" &>/dev/null; then
		send_stats "璇峰厛瀹夎nginx鐜"
		nginx_install_all
	fi

}




ldnmp_web_on() {
	  clear
	  echo "鎮ㄧ殑 $webname 鎼缓濂戒簡锛�"
	  echo "https://$yuming"
	  echo "------------------------"
	  echo "$webname 瀹夎淇℃伅濡備笅: "

}

nginx_web_on() {
	  clear
	  echo "鎮ㄧ殑 $webname 鎼缓濂戒簡锛�"
	  echo "https://$yuming"

}



ldnmp_wp() {
  clear
  # wordpress
  webname="WordPress"
  yuming="${1:-}"
  send_stats "瀹夎$webname"
  echo "寮€濮嬮儴缃� $webname"
  if [ -z "$yuming" ]; then
	add_yuming
  fi
  repeat_add_yuming
  ldnmp_install_status
  install_ssltls
  certs_status
  add_db
  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf
  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
  nginx_http_on

  cd /home/web/html
  mkdir $yuming
  cd $yuming
  wget -O latest.zip ${gh_proxy}https://github.com/kejilion/Website_source_code/raw/refs/heads/main/wp-latest.zip
  # wget -O latest.zip https://cn.wordpress.org/latest-zh_CN.zip
  # wget -O latest.zip https://wordpress.org/latest.zip
  unzip latest.zip
  rm latest.zip
  echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379');" >> /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|database_name_here|$dbname|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|username_here|$dbuse|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|password_here|$dbusepasswd|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  sed -i "s|localhost|mysql|g" /home/web/html/$yuming/wordpress/wp-config-sample.php
  cp /home/web/html/$yuming/wordpress/wp-config-sample.php /home/web/html/$yuming/wordpress/wp-config.php

  restart_ldnmp
  nginx_web_on
#   echo "鏁版嵁搴撳悕: $dbname"
#   echo "鐢ㄦ埛鍚�: $dbuse"
#   echo "瀵嗙爜: $dbusepasswd"
#   echo "鏁版嵁搴撳湴鍧€: mysql"
#   echo "琛ㄥ墠缂€: wp_"

}


ldnmp_Proxy() {
	clear
	webname="鍙嶅悜浠ｇ悊-IP+绔彛"
	yuming="${1:-}"
	reverseproxy="${2:-}"
	port="${3:-}"

	send_stats "瀹夎$webname"
	echo "寮€濮嬮儴缃� $webname"
	if [ -z "$yuming" ]; then
		add_yuming
	fi
	if [ -z "$reverseproxy" ]; then
		read -e -p "璇疯緭鍏ヤ綘鐨勫弽浠P: " reverseproxy
	fi

	if [ -z "$port" ]; then
		read -e -p "璇疯緭鍏ヤ綘鐨勫弽浠ｇ鍙�: " port
	fi
	nginx_install_status
	install_ssltls
	certs_status
	wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
	sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	sed -i "s/0.0.0.0/$reverseproxy/g" /home/web/conf.d/$yuming.conf
	sed -i "s|0000|$port|g" /home/web/conf.d/$yuming.conf
	nginx_http_on
	docker restart nginx
	nginx_web_on
}



ldnmp_web_status() {
	root_use
	while true; do
		local cert_count=$(ls /home/web/certs/*_cert.pem 2>/dev/null | wc -l)
		local output="绔欑偣: ${gl_lv}${cert_count}${gl_bai}"

		local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
		local db_count=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys" | wc -l)
		local db_output="鏁版嵁搴�: ${gl_lv}${db_count}${gl_bai}"

		clear
		send_stats "LDNMP绔欑偣绠＄悊"
		echo "LDNMP鐜"
		echo "------------------------"
		ldnmp_v

		# ls -t /home/web/conf.d | sed 's/\.[^.]*$//'
		echo -e "${output}                      璇佷功鍒版湡鏃堕棿"
		echo -e "------------------------"
		for cert_file in /home/web/certs/*_cert.pem; do
		  local domain=$(basename "$cert_file" | sed 's/_cert.pem//')
		  if [ -n "$domain" ]; then
			local expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
			local formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
			printf "%-30s%s\n" "$domain" "$formatted_date"
		  fi
		done

		echo "------------------------"
		echo ""
		echo -e "${db_output}"
		echo -e "------------------------"
		local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
		docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

		echo "------------------------"
		echo ""
		echo "绔欑偣鐩綍"
		echo "------------------------"
		echo -e "鏁版嵁 ${gl_hui}/home/web/html${gl_bai}     璇佷功 ${gl_hui}/home/web/certs${gl_bai}     閰嶇疆 ${gl_hui}/home/web/conf.d${gl_bai}"
		echo "------------------------"
		echo ""
		echo "鎿嶄綔"
		echo "------------------------"
		echo "1.  鐢宠/鏇存柊鍩熷悕璇佷功               2.  鏇存崲绔欑偣鍩熷悕"
		echo "3.  娓呯悊绔欑偣缂撳瓨                    4.  鍒涘缓鍏宠仈绔欑偣"
		echo "5.  鏌ョ湅璁块棶鏃ュ織                    6.  鏌ョ湅閿欒鏃ュ織"
		echo "7.  缂栬緫鍏ㄥ眬閰嶇疆                    8.  缂栬緫绔欑偣閰嶇疆"
		echo "9.  绠＄悊绔欑偣鏁版嵁搴�		    10. 鏌ョ湅绔欑偣鍒嗘瀽鎶ュ憡"
		echo "------------------------"
		echo "20. 鍒犻櫎鎸囧畾绔欑偣鏁版嵁"
		echo "------------------------"
		echo "0. 杩斿洖涓婁竴绾ч€夊崟"
		echo "------------------------"
		read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
		case $sub_choice in
			1)
				send_stats "鐢宠鍩熷悕璇佷功"
				read -e -p "璇疯緭鍏ヤ綘鐨勫煙鍚�: " yuming
				install_certbot
				docker run -it --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name "$yuming" -n 2>/dev/null
				install_ssltls
				certs_status

				;;

			2)
				send_stats "鏇存崲绔欑偣鍩熷悕"
				echo -e "${gl_hong}寮虹儓寤鸿: ${gl_bai}鍏堝浠藉ソ鍏ㄧ珯鏁版嵁鍐嶆洿鎹㈢珯鐐瑰煙鍚嶏紒"
				read -e -p "璇疯緭鍏ユ棫鍩熷悕: " oddyuming
				read -e -p "璇疯緭鍏ユ柊鍩熷悕: " yuming
				install_certbot
				install_ssltls
				certs_status

				# mysql鏇挎崲
				add_db

				local odd_dbname=$(echo "$oddyuming" | sed -e 's/[^A-Za-z0-9]/_/g')
				local odd_dbname="${odd_dbname}"

				docker exec mysql mysqldump -u root -p"$dbrootpasswd" $odd_dbname | docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname
				docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $odd_dbname;"


				local tables=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW TABLES;" | awk '{ if (NR>1) print $1 }')
				for table in $tables; do
					columns=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "SHOW COLUMNS FROM $table;" | awk '{ if (NR>1) print $1 }')
					for column in $columns; do
						docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "UPDATE $table SET $column = REPLACE($column, '$oddyuming', '$yuming') WHERE $column LIKE '%$oddyuming%';"
					done
				done

				# docker exec mysql mysql -u root -p"$dbrootpasswd" -D $dbname -e "
				# UPDATE wp_options SET option_value = replace(option_value, '$oddyuming', '$yuming') WHERE option_name = 'home' OR option_name = 'siteurl';
				# UPDATE wp_posts SET guid = replace(guid, '$oddyuming', '$yuming');
				# UPDATE wp_posts SET post_content = replace(post_content, '$oddyuming', '$yuming');
				# UPDATE wp_postmeta SET meta_value = replace(meta_value,'$oddyuming', '$yuming');
				# "


				# 缃戠珯鐩綍鏇挎崲
				mv /home/web/html/$oddyuming /home/web/html/$yuming
				# sed -i "s/$odd_dbname/$dbname/g" /home/web/html/$yuming/wordpress/wp-config.php
				# sed -i "s/$oddyuming/$yuming/g" /home/web/html/$yuming/wordpress/wp-config.php

				find /home/web/html/$yuming -type f -exec sed -i "s/$odd_dbname/$dbname/g" {} +
				find /home/web/html/$yuming -type f -exec sed -i "s/$oddyuming/$yuming/g" {} +

				mv /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
				sed -i "s/$oddyuming/$yuming/g" /home/web/conf.d/$yuming.conf

				rm /home/web/certs/${oddyuming}_key.pem
				rm /home/web/certs/${oddyuming}_cert.pem

				docker restart nginx

				;;


			3)
				web_cache
				;;
			4)
				send_stats "鍒涘缓鍏宠仈绔欑偣"
				echo -e "涓虹幇鏈夌殑绔欑偣鍐嶅叧鑱斾竴涓柊鍩熷悕鐢ㄤ簬璁块棶"
				read -e -p "璇疯緭鍏ョ幇鏈夌殑鍩熷悕: " oddyuming
				read -e -p "璇疯緭鍏ユ柊鍩熷悕: " yuming
				install_certbot
				install_ssltls
				certs_status

				cp /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
				sed -i "s|server_name $oddyuming|server_name $yuming|g" /home/web/conf.d/$yuming.conf
				sed -i "s|/etc/nginx/certs/${oddyuming}_cert.pem|/etc/nginx/certs/${yuming}_cert.pem|g" /home/web/conf.d/$yuming.conf
				sed -i "s|/etc/nginx/certs/${oddyuming}_key.pem|/etc/nginx/certs/${yuming}_key.pem|g" /home/web/conf.d/$yuming.conf

				docker restart nginx

				;;
			5)
				send_stats "鏌ョ湅璁块棶鏃ュ織"
				tail -n 200 /home/web/log/nginx/access.log
				break_end
				;;
			6)
				send_stats "鏌ョ湅閿欒鏃ュ織"
				tail -n 200 /home/web/log/nginx/error.log
				break_end
				;;
			7)
				send_stats "缂栬緫鍏ㄥ眬閰嶇疆"
				install nano
				nano /home/web/nginx.conf
				docker restart nginx
				;;

			8)
				send_stats "缂栬緫绔欑偣閰嶇疆"
				read -e -p "缂栬緫绔欑偣閰嶇疆锛岃杈撳叆浣犺缂栬緫鐨勫煙鍚�: " yuming
				install nano
				nano /home/web/conf.d/$yuming.conf
				docker restart nginx
				;;
			9)
				phpmyadmin_upgrade
				break_end
				;;
			10)
				send_stats "鏌ョ湅绔欑偣鏁版嵁"
				install goaccess
				goaccess --log-format=COMBINED /home/web/log/nginx/access.log
				;;

			20)
				web_del

				;;
			0)
				break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
				;;
			*)
				break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
				;;
		esac
	done


}







check_panel_app() {

if $lujing ; then
	check_panel="${gl_lv}宸插畨瑁�${gl_bai}"
else
	check_panel="${gl_hui}鏈畨瑁�${gl_bai}"
fi

}



install_panel() {
send_stats "${panelname}绠＄悊"
while true; do
	clear
	check_panel_app
	echo -e "$panelname $check_panel"
	echo "${panelname}鏄竴娆炬椂涓嬫祦琛屼笖寮哄ぇ鐨勮繍缁寸鐞嗛潰鏉裤€�"
	echo "瀹樼綉浠嬬粛: $panelurl "

	echo ""
	echo "------------------------"
	echo "1. 瀹夎            2. 绠＄悊            3. 鍗歌浇"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾�"
	echo "------------------------"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " choice
	 case $choice in
		1)
			iptables_open
			install wget
			if grep -q 'Alpine' /etc/issue; then
				$ubuntu_mingling
				$ubuntu_mingling2
			elif command -v dnf &>/dev/null; then
				$centos_mingling
				$centos_mingling2
			elif grep -qi 'Ubuntu' /etc/os-release; then
				$ubuntu_mingling
				$ubuntu_mingling2
			elif grep -qi 'Debian' /etc/os-release; then
				$ubuntu_mingling
				$ubuntu_mingling2
			else
				echo "涓嶆敮鎸佺殑绯荤粺"
			fi
			send_stats "${panelname}瀹夎"
			;;
		2)
			$gongneng1
			$gongneng1_1
			send_stats "${panelname}鎺у埗"
			;;
		3)
			$gongneng2
			$gongneng2_1
			$gongneng2_2
			send_stats "${panelname}鍗歌浇"
			;;
		0)
			break
			;;
		*)
			break
			;;
	 esac
	 break_end
done

}



current_timezone() {
	if grep -q 'Alpine' /etc/issue; then
	   date +"%Z %z"
	else
	   timedatectl | grep "Time zone" | awk '{print $3}'
	fi

}


set_timedate() {
	local shiqu="$1"
	if grep -q 'Alpine' /etc/issue; then
		install tzdata
		cp /usr/share/zoneinfo/${shiqu} /etc/localtime
		hwclock --systohc
	else
		timedatectl set-timezone ${shiqu}
	fi
}



# 淇dpkg涓柇闂
fix_dpkg() {
	pkill -9 -f 'apt|dpkg'
	rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
	DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}


linux_update() {
	echo -e "${gl_huang}姝ｅ湪绯荤粺鏇存柊...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf -y update
	elif command -v yum &>/dev/null; then
		yum -y update
	elif command -v apt &>/dev/null; then
		fix_dpkg
		DEBIAN_FRONTEND=noninteractive apt update -y
		DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
	elif command -v apk &>/dev/null; then
		apk update && apk upgrade
	elif command -v pacman &>/dev/null; then
		pacman -Syu --noconfirm
	elif command -v zypper &>/dev/null; then
		zypper refresh
		zypper update
	elif command -v opkg &>/dev/null; then
		opkg update
	else
		echo "鏈煡鐨勫寘绠＄悊鍣�!"
		return
	fi
}



linux_clean() {
	echo -e "${gl_huang}姝ｅ湪绯荤粺娓呯悊...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf autoremove -y
		dnf clean all
		dnf makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v yum &>/dev/null; then
		yum autoremove -y
		yum clean all
		yum makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apt &>/dev/null; then
		fix_dpkg
		apt autoremove --purge -y
		apt clean -y
		apt autoclean -y
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apk &>/dev/null; then
		echo "娓呯悊鍖呯鐞嗗櫒缂撳瓨..."
		apk cache clean
		echo "鍒犻櫎绯荤粺鏃ュ織..."
		rm -rf /var/log/*
		echo "鍒犻櫎APK缂撳瓨..."
		rm -rf /var/cache/apk/*
		echo "鍒犻櫎涓存椂鏂囦欢..."
		rm -rf /tmp/*

	elif command -v pacman &>/dev/null; then
		pacman -Rns $(pacman -Qdtq) --noconfirm
		pacman -Scc --noconfirm
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v zypper &>/dev/null; then
		zypper clean --all
		zypper refresh
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v opkg &>/dev/null; then
		echo "鍒犻櫎绯荤粺鏃ュ織..."
		rm -rf /var/log/*
		echo "鍒犻櫎涓存椂鏂囦欢..."
		rm -rf /tmp/*

	else
		echo "鏈煡鐨勫寘绠＄悊鍣�!"
		return
	fi
	return
}



bbr_on() {

cat > /etc/sysctl.conf << EOF
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p

}


set_dns() {

ip_address

rm /etc/resolv.conf
touch /etc/resolv.conf

if [ -n "$ipv4_address" ]; then
	echo "nameserver $dns1_ipv4" >> /etc/resolv.conf
	echo "nameserver $dns2_ipv4" >> /etc/resolv.conf
fi

if [ -n "$ipv6_address" ]; then
	echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
	echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
fi

}


set_dns_ui() {
root_use
send_stats "浼樺寲DNS"
while true; do
	clear
	echo "浼樺寲DNS鍦板潃"
	echo "------------------------"
	echo "褰撳墠DNS鍦板潃"
	cat /etc/resolv.conf
	echo "------------------------"
	echo ""
	echo "1. 鍥藉DNS浼樺寲: "
	echo " v4: 1.1.1.1 8.8.8.8"
	echo " v6: 2606:4700:4700::1111 2001:4860:4860::8888"
	echo "2. 鍥藉唴DNS浼樺寲: "
	echo " v4: 223.5.5.5 183.60.83.19"
	echo " v6: 2400:3200::1 2400:da00::6666"
	echo "3. 鎵嬪姩缂栬緫DNS閰嶇疆"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾�"
	echo "------------------------"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " Limiting
	case "$Limiting" in
	  1)
		local dns1_ipv4="1.1.1.1"
		local dns2_ipv4="8.8.8.8"
		local dns1_ipv6="2606:4700:4700::1111"
		local dns2_ipv6="2001:4860:4860::8888"
		set_dns
		send_stats "鍥藉DNS浼樺寲"
		;;
	  2)
		local dns1_ipv4="223.5.5.5"
		local dns2_ipv4="183.60.83.19"
		local dns1_ipv6="2400:3200::1"
		local dns2_ipv6="2400:da00::6666"
		set_dns
		send_stats "鍥藉唴DNS浼樺寲"
		;;
	  3)
		install nano
		nano /etc/resolv.conf
		send_stats "鎵嬪姩缂栬緫DNS閰嶇疆"
		;;
	  *)
		break
		;;
	esac
done

}



restart_ssh() {
	restart sshd ssh > /dev/null 2>&1

}


new_ssh_port() {


  # 澶囦唤 SSH 閰嶇疆鏂囦欢
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

  sed -i 's/^\s*#\?\s*Port/Port/' /etc/ssh/sshd_config

  # 鏇挎崲 SSH 閰嶇疆鏂囦欢涓殑绔彛鍙�
  sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

  rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

  # 閲嶅惎 SSH 鏈嶅姟
  restart_ssh

  iptables_open
  remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1

  echo "SSH 绔彛宸蹭慨鏀逛负: $new_port"

  sleep 1

}



add_sshkey() {

# ssh-keygen -t rsa -b 4096 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""
ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""

cat ~/.ssh/sshkey.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys


ip_address
echo -e "绉侀挜淇℃伅宸茬敓鎴愶紝鍔″繀澶嶅埗淇濆瓨锛屽彲淇濆瓨鎴� ${gl_huang}${ipv4_address}_ssh.key${gl_bai} 鏂囦欢锛岀敤浜庝互鍚庣殑SSH鐧诲綍"

echo "--------------------------------"
cat ~/.ssh/sshkey
echo "--------------------------------"

sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
	   -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
	   -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
	   -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
echo -e "${gl_lv}ROOT绉侀挜鐧诲綍宸插紑鍚紝宸插叧闂璕OOT瀵嗙爜鐧诲綍锛岄噸杩炲皢浼氱敓鏁�${gl_bai}"

}


add_sshpasswd() {

echo "璁剧疆浣犵殑ROOT瀵嗙爜"
passwd
sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
restart_ssh
echo -e "${gl_lv}ROOT鐧诲綍璁剧疆瀹屾瘯锛�${gl_bai}"

}


root_use() {
clear
[ "$EUID" -ne 0 ] && echo -e "${gl_huang}鎻愮ず: ${gl_bai}璇ュ姛鑳介渶瑕乺oot鐢ㄦ埛鎵嶈兘杩愯锛�" && break_end && kejilion
}



dd_xitong() {
		send_stats "閲嶈绯荤粺"
		dd_xitong_MollyLau() {
			wget --no-check-certificate -qO InstallNET.sh "${gh_proxy}https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" && chmod a+x InstallNET.sh

		}

		dd_xitong_bin456789() {
			curl -O ${gh_proxy}https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
		}

		dd_xitong_1() {
		  echo -e "閲嶈鍚庡垵濮嬬敤鎴峰悕: ${gl_huang}root${gl_bai}  鍒濆瀵嗙爜: ${gl_huang}LeitboGi0ro${gl_bai}  鍒濆绔彛: ${gl_huang}22${gl_bai}"
		  echo -e "鎸変换鎰忛敭缁х画..."
		  read -n 1 -s -r -p ""
		  install wget
		  dd_xitong_MollyLau
		}

		dd_xitong_2() {
		  echo -e "閲嶈鍚庡垵濮嬬敤鎴峰悕: ${gl_huang}Administrator${gl_bai}  鍒濆瀵嗙爜: ${gl_huang}Teddysun.com${gl_bai}  鍒濆绔彛: ${gl_huang}3389${gl_bai}"
		  echo -e "鎸変换鎰忛敭缁х画..."
		  read -n 1 -s -r -p ""
		  install wget
		  dd_xitong_MollyLau
		}

		dd_xitong_3() {
		  echo -e "閲嶈鍚庡垵濮嬬敤鎴峰悕: ${gl_huang}root${gl_bai}  鍒濆瀵嗙爜: ${gl_huang}123@@@${gl_bai}  鍒濆绔彛: ${gl_huang}22${gl_bai}"
		  echo -e "鎸変换鎰忛敭缁х画..."
		  read -n 1 -s -r -p ""
		  dd_xitong_bin456789
		}

		dd_xitong_4() {
		  echo -e "閲嶈鍚庡垵濮嬬敤鎴峰悕: ${gl_huang}Administrator${gl_bai}  鍒濆瀵嗙爜: ${gl_huang}123@@@${gl_bai}  鍒濆绔彛: ${gl_huang}3389${gl_bai}"
		  echo -e "鎸変换鎰忛敭缁х画..."
		  read -n 1 -s -r -p ""
		  dd_xitong_bin456789
		}

		  while true; do
			root_use
			echo "閲嶈绯荤粺"
			echo "--------------------------------"
			echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}閲嶈鏈夐闄╁け鑱旓紝涓嶆斁蹇冭€呮厧鐢ㄣ€傞噸瑁呴璁¤姳璐�15鍒嗛挓锛岃鎻愬墠澶囦唤鏁版嵁銆�"
			echo -e "${gl_hui}鎰熻阿MollyLau澶т浆鍜宐in456789澶т浆鐨勮剼鏈敮鎸侊紒${gl_bai} "
			echo "------------------------"
			echo "1. Debian 12                  2. Debian 11"
			echo "3. Debian 10                  4. Debian 9"
			echo "------------------------"
			echo "11. Ubuntu 24.04              12. Ubuntu 22.04"
			echo "13. Ubuntu 20.04              14. Ubuntu 18.04"
			echo "------------------------"
			echo "21. Rocky Linux 9             22. Rocky Linux 8"
			echo "23. Alma Linux 9              24. Alma Linux 8"
			echo "25. oracle Linux 9            26. oracle Linux 8"
			echo "27. Fedora Linux 41           28. Fedora Linux 40"
			echo "29. CentOS 7"
			echo "------------------------"
			echo "31. Alpine Linux              32. Arch Linux"
			echo "33. Kali Linux                34. openEuler"
			echo "35. openSUSE Tumbleweed"
			echo "------------------------"
			echo "41. Windows 11                42. Windows 10"
			echo "43. Windows 7                 44. Windows Server 2022"
			echo "45. Windows Server 2019       46. Windows Server 2016"
			echo "47. Windows 11 ARM"
			echo "------------------------"
			echo "0. 杩斿洖涓婁竴绾ч€夊崟"
			echo "------------------------"
			read -e -p "璇烽€夋嫨瑕侀噸瑁呯殑绯荤粺: " sys_choice
			case "$sys_choice" in
			  1)
				send_stats "閲嶈debian 12"
				dd_xitong_1
				bash InstallNET.sh -debian 12
				reboot
				exit
				;;
			  2)
				send_stats "閲嶈debian 11"
				dd_xitong_1
				bash InstallNET.sh -debian 11
				reboot
				exit
				;;
			  3)
				send_stats "閲嶈debian 10"
				dd_xitong_1
				bash InstallNET.sh -debian 10
				reboot
				exit
				;;
			  4)
				send_stats "閲嶈debian 9"
				dd_xitong_1
				bash InstallNET.sh -debian 9
				reboot
				exit
				;;
			  11)
				send_stats "閲嶈ubuntu 24.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 24.04
				reboot
				exit
				;;
			  12)
				send_stats "閲嶈ubuntu 22.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 22.04
				reboot
				exit
				;;
			  13)
				send_stats "閲嶈ubuntu 20.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 20.04
				reboot
				exit
				;;
			  14)
				send_stats "閲嶈ubuntu 18.04"
				dd_xitong_1
				bash InstallNET.sh -ubuntu 18.04
				reboot
				exit
				;;


			  21)
				send_stats "閲嶈rockylinux9"
				dd_xitong_3
				bash reinstall.sh rocky
				reboot
				exit
				;;

			  22)
				send_stats "閲嶈rockylinux8"
				dd_xitong_3
				bash reinstall.sh rocky 8
				reboot
				exit
				;;

			  23)
				send_stats "閲嶈alma9"
				dd_xitong_3
				bash reinstall.sh almalinux
				reboot
				exit
				;;

			  24)
				send_stats "閲嶈alma8"
				dd_xitong_3
				bash reinstall.sh almalinux 8
				reboot
				exit
				;;

			  25)
				send_stats "閲嶈oracle9"
				dd_xitong_3
				bash reinstall.sh oracle
				reboot
				exit
				;;

			  26)
				send_stats "閲嶈oracle8"
				dd_xitong_3
				bash reinstall.sh oracle 8
				reboot
				exit
				;;

			  27)
				send_stats "閲嶈fedora41"
				dd_xitong_3
				bash reinstall.sh fedora
				reboot
				exit
				;;

			  28)
				send_stats "閲嶈fedora40"
				dd_xitong_3
				bash reinstall.sh fedora 40
				reboot
				exit
				;;

			  29)
				send_stats "閲嶈centos 7"
				dd_xitong_1
				bash InstallNET.sh -centos 7
				reboot
				exit
				;;

			  31)
				send_stats "閲嶈alpine"
				dd_xitong_1
				bash InstallNET.sh -alpine
				reboot
				exit
				;;

			  32)
				send_stats "閲嶈arch"
				dd_xitong_3
				bash reinstall.sh arch
				reboot
				exit
				;;

			  33)
				send_stats "閲嶈kali"
				dd_xitong_3
				bash reinstall.sh kali
				reboot
				exit
				;;

			  34)
				send_stats "閲嶈openeuler"
				dd_xitong_3
				bash reinstall.sh openeuler
				reboot
				exit
				;;

			  35)
				send_stats "閲嶈opensuse"
				dd_xitong_3
				bash reinstall.sh opensuse
				reboot
				exit
				;;

			  41)
				send_stats "閲嶈windows11"
				dd_xitong_2
				bash InstallNET.sh -windows 11 -lang "cn"
				reboot
				exit
				;;
			  42)
				dd_xitong_2
				send_stats "閲嶈windows10"
				bash InstallNET.sh -windows 10 -lang "cn"
				reboot
				exit
				;;
			  43)
				send_stats "閲嶈windows7"
				dd_xitong_4
				local URL="https://massgrave.dev/windows_7_links"
				local web_content=$(wget -q -O - "$URL")
				local iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_7[^"]*professional[^"]*x64[^"]*\.iso')
				# bash reinstall.sh windows --image-name 'Windows 7 Professional' --lang zh-cn
				# bash reinstall.sh windows --iso='$iso_link' --image-name='Windows 7 PROFESSIONAL'
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows 7 PROFESSIONAL'
				reboot
				exit
				;;
			  44)
				send_stats "閲嶈windows server 22"
				dd_xitong_4
				local URL="https://massgrave.dev/windows_server_links"
				local web_content=$(wget -q -O - "$URL")
				local iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_server[^"]*2022[^"]*x64[^"]*\.iso')
				bash reinstall.sh windows --iso="$iso_link" --image-name='Windows Server 2022 SERVERDATACENTER'
				reboot
				exit
				;;
			  45)
				send_stats "閲嶈windows server 19"
				dd_xitong_2
				bash InstallNET.sh -windows 2019 -lang "cn"
				reboot
				exit
				;;
			  46)
				send_stats "閲嶈windows server 16"
				dd_xitong_2
				bash InstallNET.sh -windows 2016 -lang "cn"
				reboot
				exit
				;;

			  47)
				send_stats "閲嶈windows11 ARM"
				dd_xitong_4
				bash reinstall.sh dd --img https://r2.hotdog.eu.org/win11-arm-with-pagefile-15g.xz
				reboot
				exit
				;;

			  0)
				break
				;;
			  *)
				echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
				break
				;;
			esac
		  done
}


bbrv3() {
		  root_use
		  send_stats "bbrv3绠＄悊"

		  local cpu_arch=$(uname -m)
		  if [ "$cpu_arch" = "aarch64" ]; then
			bash <(curl -sL jhb.ovh/jb/bbrv3arm.sh)
			break_end
			linux_Settings
		  fi

		  if dpkg -l | grep -q 'linux-xanmod'; then
			while true; do
				  clear
				  local kernel_version=$(uname -r)
				  echo "鎮ㄥ凡瀹夎xanmod鐨凚BRv3鍐呮牳"
				  echo "褰撳墠鍐呮牳鐗堟湰: $kernel_version"

				  echo ""
				  echo "鍐呮牳绠＄悊"
				  echo "------------------------"
				  echo "1. 鏇存柊BBRv3鍐呮牳              2. 鍗歌浇BBRv3鍐呮牳"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						apt purge -y 'linux-*xanmod1*'
						update-grub

						# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
						wget -qO - ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

						# 姝ラ3锛氭坊鍔犲瓨鍌ㄥ簱
						echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

						# version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
						local version=$(wget -q ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

						apt update -y
						apt install -y linux-xanmod-x64v$version

						echo "XanMod鍐呮牳宸叉洿鏂般€傞噸鍚悗鐢熸晥"
						rm -f /etc/apt/sources.list.d/xanmod-release.list
						rm -f check_x86-64_psabi.sh*

						server_reboot

						  ;;
					  2)
						apt purge -y 'linux-*xanmod1*'
						update-grub
						echo "XanMod鍐呮牳宸插嵏杞姐€傞噸鍚悗鐢熸晥"
						server_reboot
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

				  esac
			done
		else

		  clear
		  echo "璁剧疆BBR3鍔犻€�"
		  echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV14K421x7BS?t=0.1"
		  echo "------------------------------------------------"
		  echo "浠呮敮鎸丏ebian/Ubuntu"
		  echo "璇峰浠芥暟鎹紝灏嗕负浣犲崌绾inux鍐呮牳寮€鍚疊BR3"
		  echo "VPS鏄�512M鍐呭瓨鐨勶紝璇锋彁鍓嶆坊鍔�1G铏氭嫙鍐呭瓨锛岄槻姝㈠洜鍐呭瓨涓嶈冻澶辫仈锛�"
		  echo "------------------------------------------------"
		  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

		  case "$choice" in
			[Yy])
			if [ -r /etc/os-release ]; then
				. /etc/os-release
				if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
					echo "褰撳墠鐜涓嶆敮鎸侊紝浠呮敮鎸丏ebian鍜孶buntu绯荤粺"
					break_end
					linux_Settings
				fi
			else
				echo "鏃犳硶纭畾鎿嶄綔绯荤粺绫诲瀷"
				break_end
				linux_Settings
			fi

			check_swap
			install wget gnupg

			# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
			wget -qO - ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

			# 姝ラ3锛氭坊鍔犲瓨鍌ㄥ簱
			echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

			# version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
			local version=$(wget -q ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

			apt update -y
			apt install -y linux-xanmod-x64v$version

			bbr_on

			echo "XanMod鍐呮牳瀹夎骞禕BR3鍚敤鎴愬姛銆傞噸鍚悗鐢熸晥"
			rm -f /etc/apt/sources.list.d/xanmod-release.list
			rm -f check_x86-64_psabi.sh*
			server_reboot

			  ;;
			[Nn])
			  echo "宸插彇娑�"
			  ;;
			*)
			  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
			  ;;
		  esac
		fi

}


elrepo_install() {
	# 瀵煎叆 ELRepo GPG 鍏挜
	echo "瀵煎叆 ELRepo GPG 鍏挜..."
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	# 妫€娴嬬郴缁熺増鏈�
	local os_version=$(rpm -q --qf "%{VERSION}" $(rpm -qf /etc/os-release) 2>/dev/null | awk -F '.' '{print $1}')
	local os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
	# 纭繚鎴戜滑鍦ㄤ竴涓敮鎸佺殑鎿嶄綔绯荤粺涓婅繍琛�
	if [[ "$os_name" != *"Red Hat"* && "$os_name" != *"AlmaLinux"* && "$os_name" != *"Rocky"* && "$os_name" != *"Oracle"* && "$os_name" != *"CentOS"* ]]; then
		echo "涓嶆敮鎸佺殑鎿嶄綔绯荤粺锛�$os_name"
		break_end
		linux_Settings
	fi
	# 鎵撳嵃妫€娴嬪埌鐨勬搷浣滅郴缁熶俊鎭�
	echo "妫€娴嬪埌鐨勬搷浣滅郴缁�: $os_name $os_version"
	# 鏍规嵁绯荤粺鐗堟湰瀹夎瀵瑰簲鐨� ELRepo 浠撳簱閰嶇疆
	if [[ "$os_version" == 8 ]]; then
		echo "瀹夎 ELRepo 浠撳簱閰嶇疆 (鐗堟湰 8)..."
		yum -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
	elif [[ "$os_version" == 9 ]]; then
		echo "瀹夎 ELRepo 浠撳簱閰嶇疆 (鐗堟湰 9)..."
		yum -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
	else
		echo "涓嶆敮鎸佺殑绯荤粺鐗堟湰锛�$os_version"
		break_end
		linux_Settings
	fi
	# 鍚敤 ELRepo 鍐呮牳浠撳簱骞跺畨瑁呮渶鏂扮殑涓荤嚎鍐呮牳
	echo "鍚敤 ELRepo 鍐呮牳浠撳簱骞跺畨瑁呮渶鏂扮殑涓荤嚎鍐呮牳..."
	yum -y --enablerepo=elrepo-kernel install kernel-ml
	echo "宸插畨瑁� ELRepo 浠撳簱閰嶇疆骞舵洿鏂板埌鏈€鏂颁富绾垮唴鏍搞€�"
	server_reboot

}


elrepo() {
		  root_use
		  send_stats "绾㈠附鍐呮牳绠＄悊"
		  if uname -r | grep -q 'elrepo'; then
			while true; do
				  clear
				  kernel_version=$(uname -r)
				  echo "鎮ㄥ凡瀹夎elrepo鍐呮牳"
				  echo "褰撳墠鍐呮牳鐗堟湰: $kernel_version"

				  echo ""
				  echo "鍐呮牳绠＄悊"
				  echo "------------------------"
				  echo "1. 鏇存柊elrepo鍐呮牳              2. 鍗歌浇elrepo鍐呮牳"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						elrepo_install
						send_stats "鏇存柊绾㈠附鍐呮牳"
						server_reboot

						  ;;
					  2)
						dnf remove -y elrepo-release
						rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
						echo "elrepo鍐呮牳宸插嵏杞姐€傞噸鍚悗鐢熸晥"
						send_stats "鍗歌浇绾㈠附鍐呮牳"
						server_reboot

						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

				  esac
			done
		else

		  clear
		  echo "璇峰浠芥暟鎹紝灏嗕负浣犲崌绾inux鍐呮牳"
		  echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1mH4y1w7qA?t=529.2"
		  echo "------------------------------------------------"
		  echo "浠呮敮鎸佺孩甯界郴鍒楀彂琛岀増 CentOS/RedHat/Alma/Rocky/oracle "
		  echo "鍗囩骇Linux鍐呮牳鍙彁鍗囩郴缁熸€ц兘鍜屽畨鍏紝寤鸿鏈夋潯浠剁殑灏濊瘯锛岀敓浜х幆澧冭皑鎱庡崌绾э紒"
		  echo "------------------------------------------------"
		  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

		  case "$choice" in
			[Yy])
			  check_swap
			  elrepo_install
			  send_stats "鍗囩骇绾㈠附鍐呮牳"
			  server_reboot
			  ;;
			[Nn])
			  echo "宸插彇娑�"
			  ;;
			*)
			  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
			  ;;
		  esac
		fi

}




clamav_freshclam() {
	echo -e "${gl_huang}姝ｅ湪鏇存柊鐥呮瘨搴�...${gl_bai}"
	docker run --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		clamav/clamav-debian:latest \
		freshclam
}

clamav_scan() {
	if [ $# -eq 0 ]; then
		echo "璇锋寚瀹氳鎵弿鐨勭洰褰曘€�"
		return
	fi

	echo -e "${gl_huang}姝ｅ湪鎵弿鐩綍$@... ${gl_bai}"

	# 鏋勫缓 mount 鍙傛暟
	local MOUNT_PARAMS=""
	for dir in "$@"; do
		MOUNT_PARAMS+="--mount type=bind,source=${dir},target=/mnt/host${dir} "
	done

	# 鏋勫缓 clamscan 鍛戒护鍙傛暟
	local SCAN_PARAMS=""
	for dir in "$@"; do
		SCAN_PARAMS+="/mnt/host${dir} "
	done

	mkdir -p /home/docker/clamav/log/ > /dev/null 2>&1
	> /home/docker/clamav/log/scan.log > /dev/null 2>&1

	# 鎵ц Docker 鍛戒护
	docker run -it --rm \
		--name clamav \
		--mount source=clam_db,target=/var/lib/clamav \
		$MOUNT_PARAMS \
		-v /home/docker/clamav/log/:/var/log/clamav/ \
		clamav/clamav-debian:latest \
		clamscan -r --log=/var/log/clamav/scan.log $SCAN_PARAMS

	echo -e "${gl_lv}$@ 鎵弿瀹屾垚锛岀梾姣掓姤鍛婂瓨鏀惧湪${gl_huang}/home/docker/clamav/log/scan.log${gl_bai}"
	echo -e "${gl_lv}濡傛灉鏈夌梾姣掕鍦�${gl_huang}scan.log${gl_lv}鏂囦欢涓悳绱OUND鍏抽敭瀛楃‘璁ょ梾姣掍綅缃� ${gl_bai}"

}







clamav() {
		  root_use
		  send_stats "鐥呮瘨鎵弿绠＄悊"
		  while true; do
				clear
				echo "clamav鐥呮瘨鎵弿宸ュ叿"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1TqvZe4EQm?t=0.1"
				echo "------------------------"
				echo "鏄竴涓紑婧愮殑闃茬梾姣掕蒋浠跺伐鍏凤紝涓昏鐢ㄤ簬妫€娴嬪拰鍒犻櫎鍚勭绫诲瀷鐨勬伓鎰忚蒋浠躲€�"
				echo "鍖呮嫭鐥呮瘨銆佺壒娲涗紛鏈ㄩ┈銆侀棿璋嶈蒋浠躲€佹伓鎰忚剼鏈拰鍏朵粬鏈夊杞欢銆�"
				echo "------------------------"
				echo -e "${gl_lv}1. 鍏ㄧ洏鎵弿 ${gl_bai}             ${gl_huang}2. 閲嶈鐩綍鎵弿 ${gl_bai}            ${gl_kjlan} 3. 鑷畾涔夌洰褰曟壂鎻� ${gl_bai}"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				echo "------------------------"
				read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
				case $sub_choice in
					1)
					  send_stats "鍏ㄧ洏鎵弿"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /
					  break_end

						;;
					2)
					  send_stats "閲嶈鐩綍鎵弿"
					  install_docker
					  docker volume create clam_db > /dev/null 2>&1
					  clamav_freshclam
					  clamav_scan /etc /var /usr /home /root
					  break_end
						;;
					3)
					  send_stats "鑷畾涔夌洰褰曟壂鎻�"
					  read -e -p "璇疯緭鍏ヨ鎵弿鐨勭洰褰曪紝鐢ㄧ┖鏍煎垎闅旓紙渚嬪锛�/etc /var /usr /home /root锛�: " directories
					  install_docker
					  clamav_freshclam
					  clamav_scan $directories
					  break_end
						;;
					*)
					  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						;;
				esac
		  done

}




# 楂樻€ц兘妯″紡浼樺寲鍑芥暟
optimize_high_performance() {
	echo -e "${gl_lv}鍒囨崲鍒�${tiaoyou_moshi}...${gl_bai}"

	echo -e "${gl_lv}浼樺寲鏂囦欢鎻忚堪绗�...${gl_bai}"
	ulimit -n 65535

	echo -e "${gl_lv}浼樺寲铏氭嫙鍐呭瓨...${gl_bai}"
	sysctl -w vm.swappiness=10 2>/dev/null
	sysctl -w vm.dirty_ratio=15 2>/dev/null
	sysctl -w vm.dirty_background_ratio=5 2>/dev/null
	sysctl -w vm.overcommit_memory=1 2>/dev/null
	sysctl -w vm.min_free_kbytes=65536 2>/dev/null

	echo -e "${gl_lv}浼樺寲缃戠粶璁剧疆...${gl_bai}"
	sysctl -w net.core.rmem_max=16777216 2>/dev/null
	sysctl -w net.core.wmem_max=16777216 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null
	sysctl -w net.core.somaxconn=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

	echo -e "${gl_lv}浼樺寲缂撳瓨绠＄悊...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

	echo -e "${gl_lv}浼樺寲CPU璁剧疆...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

	echo -e "${gl_lv}鍏朵粬浼樺寲...${gl_bai}"
	# 绂佺敤閫忔槑澶ч〉闈紝鍑忓皯寤惰繜
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	# 绂佺敤 NUMA balancing
	sysctl -w kernel.numa_balancing=0 2>/dev/null


}

# 鍧囪　妯″紡浼樺寲鍑芥暟
optimize_balanced() {
	echo -e "${gl_lv}鍒囨崲鍒板潎琛℃ā寮�...${gl_bai}"

	echo -e "${gl_lv}浼樺寲鏂囦欢鎻忚堪绗�...${gl_bai}"
	ulimit -n 32768

	echo -e "${gl_lv}浼樺寲铏氭嫙鍐呭瓨...${gl_bai}"
	sysctl -w vm.swappiness=30 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=0 2>/dev/null
	sysctl -w vm.min_free_kbytes=32768 2>/dev/null

	echo -e "${gl_lv}浼樺寲缃戠粶璁剧疆...${gl_bai}"
	sysctl -w net.core.rmem_max=8388608 2>/dev/null
	sysctl -w net.core.wmem_max=8388608 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=125000 2>/dev/null
	sysctl -w net.core.somaxconn=2048 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 8388608' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 32768 8388608' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 49151' 2>/dev/null

	echo -e "${gl_lv}浼樺寲缂撳瓨绠＄悊...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=75 2>/dev/null

	echo -e "${gl_lv}浼樺寲CPU璁剧疆...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

	echo -e "${gl_lv}鍏朵粬浼樺寲...${gl_bai}"
	# 杩樺師閫忔槑澶ч〉闈�
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	# 杩樺師 NUMA balancing
	sysctl -w kernel.numa_balancing=1 2>/dev/null


}

# 杩樺師榛樿璁剧疆鍑芥暟
restore_defaults() {
	echo -e "${gl_lv}杩樺師鍒伴粯璁よ缃�...${gl_bai}"

	echo -e "${gl_lv}杩樺師鏂囦欢鎻忚堪绗�...${gl_bai}"
	ulimit -n 1024

	echo -e "${gl_lv}杩樺師铏氭嫙鍐呭瓨...${gl_bai}"
	sysctl -w vm.swappiness=60 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=0 2>/dev/null
	sysctl -w vm.min_free_kbytes=16384 2>/dev/null

	echo -e "${gl_lv}杩樺師缃戠粶璁剧疆...${gl_bai}"
	sysctl -w net.core.rmem_max=212992 2>/dev/null
	sysctl -w net.core.wmem_max=212992 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=1000 2>/dev/null
	sysctl -w net.core.somaxconn=128 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 6291456' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 16384 4194304' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=2048 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=0 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='32768 60999' 2>/dev/null

	echo -e "${gl_lv}杩樺師缂撳瓨绠＄悊...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=100 2>/dev/null

	echo -e "${gl_lv}杩樺師CPU璁剧疆...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

	echo -e "${gl_lv}杩樺師鍏朵粬浼樺寲...${gl_bai}"
	# 杩樺師閫忔槑澶ч〉闈�
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	# 杩樺師 NUMA balancing
	sysctl -w kernel.numa_balancing=1 2>/dev/null

}



# 缃戠珯鎼缓浼樺寲鍑芥暟
optimize_web_server() {
	echo -e "${gl_lv}鍒囨崲鍒扮綉绔欐惌寤轰紭鍖栨ā寮�...${gl_bai}"

	echo -e "${gl_lv}浼樺寲鏂囦欢鎻忚堪绗�...${gl_bai}"
	ulimit -n 65535

	echo -e "${gl_lv}浼樺寲铏氭嫙鍐呭瓨...${gl_bai}"
	sysctl -w vm.swappiness=10 2>/dev/null
	sysctl -w vm.dirty_ratio=20 2>/dev/null
	sysctl -w vm.dirty_background_ratio=10 2>/dev/null
	sysctl -w vm.overcommit_memory=1 2>/dev/null
	sysctl -w vm.min_free_kbytes=65536 2>/dev/null

	echo -e "${gl_lv}浼樺寲缃戠粶璁剧疆...${gl_bai}"
	sysctl -w net.core.rmem_max=16777216 2>/dev/null
	sysctl -w net.core.wmem_max=16777216 2>/dev/null
	sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null
	sysctl -w net.core.somaxconn=4096 2>/dev/null
	sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
	sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
	sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
	sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
	sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

	echo -e "${gl_lv}浼樺寲缂撳瓨绠＄悊...${gl_bai}"
	sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

	echo -e "${gl_lv}浼樺寲CPU璁剧疆...${gl_bai}"
	sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

	echo -e "${gl_lv}鍏朵粬浼樺寲...${gl_bai}"
	# 绂佺敤閫忔槑澶ч〉闈紝鍑忓皯寤惰繜
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	# 绂佺敤 NUMA balancing
	sysctl -w kernel.numa_balancing=0 2>/dev/null


}


Kernel_optimize() {
	root_use
	while true; do
	  clear
	  send_stats "Linux鍐呮牳璋冧紭绠＄悊"
	  echo "Linux绯荤粺鍐呮牳鍙傛暟浼樺寲"
	  echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1Kb421J7yg?t=0.1"
	  echo "------------------------------------------------"
	  echo "鎻愪緵澶氱绯荤粺鍙傛暟璋冧紭妯″紡锛岀敤鎴峰彲浠ユ牴鎹嚜韬娇鐢ㄥ満鏅繘琛岄€夋嫨鍒囨崲銆�"
	  echo -e "${gl_huang}鎻愮ず: ${gl_bai}鐢熶骇鐜璇疯皑鎱庝娇鐢紒"
	  echo "--------------------"
	  echo "1. 楂樻€ц兘浼樺寲妯″紡锛�     鏈€澶у寲绯荤粺鎬ц兘锛屼紭鍖栨枃浠舵弿杩扮銆佽櫄鎷熷唴瀛樸€佺綉缁滆缃€佺紦瀛樼鐞嗗拰CPU璁剧疆銆�"
	  echo "2. 鍧囪　浼樺寲妯″紡锛�       鍦ㄦ€ц兘涓庤祫婧愭秷鑰椾箣闂村彇寰楀钩琛★紝閫傚悎鏃ュ父浣跨敤銆�"
	  echo "3. 缃戠珯浼樺寲妯″紡锛�       閽堝缃戠珯鏈嶅姟鍣ㄨ繘琛屼紭鍖栵紝鎻愰珮骞跺彂杩炴帴澶勭悊鑳藉姏銆佸搷搴旈€熷害鍜屾暣浣撴€ц兘銆�"
	  echo "4. 鐩存挱浼樺寲妯″紡锛�       閽堝鐩存挱鎺ㄦ祦鐨勭壒娈婇渶姹傝繘琛屼紭鍖栵紝鍑忓皯寤惰繜锛屾彁楂樹紶杈撴€ц兘銆�"
	  echo "5. 娓告垙鏈嶄紭鍖栨ā寮忥細     閽堝娓告垙鏈嶅姟鍣ㄨ繘琛屼紭鍖栵紝鎻愰珮骞跺彂澶勭悊鑳藉姏鍜屽搷搴旈€熷害銆�"
	  echo "6. 杩樺師榛樿璁剧疆锛�       灏嗙郴缁熻缃繕鍘熶负榛樿閰嶇疆銆�"
	  echo "--------------------"
	  echo "0. 杩斿洖涓婁竴绾�"
	  echo "--------------------"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
	  case $sub_choice in
		  1)
			  cd ~
			  clear
			  local tiaoyou_moshi="楂樻€ц兘浼樺寲妯″紡"
			  optimize_high_performance
			  send_stats "楂樻€ц兘妯″紡浼樺寲"
			  ;;
		  2)
			  cd ~
			  clear
			  optimize_balanced
			  send_stats "鍧囪　妯″紡浼樺寲"
			  ;;
		  3)
			  cd ~
			  clear
			  optimize_web_server
			  send_stats "缃戠珯浼樺寲妯″紡"
			  ;;
		  4)
			  cd ~
			  clear
			  local tiaoyou_moshi="鐩存挱浼樺寲妯″紡"
			  optimize_high_performance
			  send_stats "鐩存挱鎺ㄦ祦浼樺寲"
			  ;;
		  5)
			  cd ~
			  clear
			  local tiaoyou_moshi="娓告垙鏈嶄紭鍖栨ā寮�"
			  optimize_high_performance
			  send_stats "娓告垙鏈嶄紭鍖�"
			  ;;
		  6)
			  cd ~
			  clear
			  restore_defaults
			  send_stats "杩樺師榛樿璁剧疆"
			  ;;
		  0)
			  break
			  ;;
		  *)
			  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
			  ;;
	  esac
	  break_end
	done
}





update_locale() {
	local lang=$1
	local locale_file=$2

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case $ID in
			debian|ubuntu|kali)
				install locales
				sed -i "s/^\s*#\?\s*${locale_file}/${locale_file}/" /etc/locale.gen
				locale-gen
				echo "LANG=${lang}" > /etc/default/locale
				export LANG=${lang}
				echo -e "${gl_lv}绯荤粺璇█宸茬粡淇敼涓�: $lang 閲嶆柊杩炴帴SSH鐢熸晥銆�${gl_bai}"
				hash -r
				break_end

				;;
			centos|rhel|almalinux|rocky|fedora)
				install glibc-langpack-zh
				localectl set-locale LANG=${lang}
				echo "LANG=${lang}" | tee /etc/locale.conf
				echo -e "${gl_lv}绯荤粺璇█宸茬粡淇敼涓�: $lang 閲嶆柊杩炴帴SSH鐢熸晥銆�${gl_bai}"
				hash -r
				break_end
				;;
			*)
				echo "涓嶆敮鎸佺殑绯荤粺: $ID"
				break_end
				;;
		esac
	else
		echo "涓嶆敮鎸佺殑绯荤粺锛屾棤娉曡瘑鍒郴缁熺被鍨嬨€�"
		break_end
	fi
}




linux_language() {
root_use
send_stats "鍒囨崲绯荤粺璇█"
while true; do
  clear
  echo "褰撳墠绯荤粺璇█: $LANG"
  echo "------------------------"
  echo "1. 鑻辨枃          2. 绠€浣撲腑鏂�          3. 绻佷綋涓枃"
  echo "------------------------"
  echo "0. 杩斿洖涓婁竴绾�"
  echo "------------------------"
  read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

  case $choice in
	  1)
		  update_locale "en_US.UTF-8" "en_US.UTF-8"
		  send_stats "鍒囨崲鍒拌嫳鏂�"
		  ;;
	  2)
		  update_locale "zh_CN.UTF-8" "zh_CN.UTF-8"
		  send_stats "鍒囨崲鍒扮畝浣撲腑鏂�"
		  ;;
	  3)
		  update_locale "zh_TW.UTF-8" "zh_TW.UTF-8"
		  send_stats "鍒囨崲鍒扮箒浣撲腑鏂�"
		  ;;
	  *)
		  break
		  ;;
  esac
done
}



shell_bianse_profile() {

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
	sed -i '/^PS1=/d' ~/.bashrc
	echo "${bianse}" >> ~/.bashrc
	# source ~/.bashrc
else
	sed -i '/^PS1=/d' ~/.profile
	echo "${bianse}" >> ~/.profile
	# source ~/.profile
fi
echo -e "${gl_lv}鍙樻洿瀹屾垚銆傞噸鏂拌繛鎺SH鍚庡彲鏌ョ湅鍙樺寲锛�${gl_bai}"

hash -r
break_end

}



shell_bianse() {
  root_use
  send_stats "鍛戒护琛岀編鍖栧伐鍏�"
  while true; do
	clear
	echo "鍛戒护琛岀編鍖栧伐鍏�"
	echo "------------------------"
	echo -e "1. \033[1;32mroot \033[1;34mlocalhost \033[1;31m~ \033[0m${gl_bai}#"
	echo -e "2. \033[1;35mroot \033[1;36mlocalhost \033[1;33m~ \033[0m${gl_bai}#"
	echo -e "3. \033[1;31mroot \033[1;32mlocalhost \033[1;34m~ \033[0m${gl_bai}#"
	echo -e "4. \033[1;36mroot \033[1;33mlocalhost \033[1;37m~ \033[0m${gl_bai}#"
	echo -e "5. \033[1;37mroot \033[1;31mlocalhost \033[1;32m~ \033[0m${gl_bai}#"
	echo -e "6. \033[1;33mroot \033[1;34mlocalhost \033[1;35m~ \033[0m${gl_bai}#"
	echo -e "7. root localhost ~ #"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾�"
	echo "------------------------"
	read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

	case $choice in
	  1)
		local bianse="PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;31m\]\w\[\033[0m\] # '"
		shell_bianse_profile

		;;
	  2)
		local bianse="PS1='\[\033[1;35m\]\u\[\033[0m\]@\[\033[1;36m\]\h\[\033[0m\] \[\033[1;33m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  3)
		local bianse="PS1='\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;32m\]\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  4)
		local bianse="PS1='\[\033[1;36m\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\] \[\033[1;37m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  5)
		local bianse="PS1='\[\033[1;37m\]\u\[\033[0m\]@\[\033[1;31m\]\h\[\033[0m\] \[\033[1;32m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  6)
		local bianse="PS1='\[\033[1;33m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\] # '"
		shell_bianse_profile
		;;
	  7)
		local bianse=""
		shell_bianse_profile
		;;
	  *)
		break
		;;
	esac

  done
}




linux_trash() {
  root_use
  send_stats "绯荤粺鍥炴敹绔�"

  local bashrc_profile="/root/.bashrc"
  local TRASH_DIR="$HOME/.local/share/Trash/files"

  while true; do

	local trash_status
	if ! grep -q "trash-put" "$bashrc_profile"; then
		trash_status="${gl_hui}鏈惎鐢�${gl_bai}"
	else
		trash_status="${gl_lv}宸插惎鐢�${gl_bai}"
	fi

	clear
	echo -e "褰撳墠鍥炴敹绔� ${trash_status}"
	echo -e "鍚敤鍚巖m鍒犻櫎鐨勬枃浠跺厛杩涘叆鍥炴敹绔欙紝闃叉璇垹閲嶈鏂囦欢锛�"
	echo "------------------------------------------------"
	ls -l --color=auto "$TRASH_DIR" 2>/dev/null || echo "鍥炴敹绔欎负绌�"
	echo "------------------------"
	echo "1. 鍚敤鍥炴敹绔�          2. 鍏抽棴鍥炴敹绔�"
	echo "3. 杩樺師鍐呭            4. 娓呯┖鍥炴敹绔�"
	echo "------------------------"
	echo "0. 杩斿洖涓婁竴绾�"
	echo "------------------------"
	read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

	case $choice in
	  1)
		install trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='trash-put'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "鍥炴敹绔欏凡鍚敤锛屽垹闄ょ殑鏂囦欢灏嗙Щ鑷冲洖鏀剁珯銆�"
		sleep 2
		;;
	  2)
		remove trash-cli
		sed -i '/alias rm/d' "$bashrc_profile"
		echo "alias rm='rm -i'" >> "$bashrc_profile"
		source "$bashrc_profile"
		echo "鍥炴敹绔欏凡鍏抽棴锛屾枃浠跺皢鐩存帴鍒犻櫎銆�"
		sleep 2
		;;
	  3)
		read -e -p "杈撳叆瑕佽繕鍘熺殑鏂囦欢鍚�: " file_to_restore
		if [ -e "$TRASH_DIR/$file_to_restore" ]; then
		  mv "$TRASH_DIR/$file_to_restore" "$HOME/"
		  echo "$file_to_restore 宸茶繕鍘熷埌涓荤洰褰曘€�"
		else
		  echo "鏂囦欢涓嶅瓨鍦ㄣ€�"
		fi
		;;
	  4)
		read -e -p "纭娓呯┖鍥炴敹绔欙紵[y/n]: " confirm
		if [[ "$confirm" == "y" ]]; then
		  trash-empty
		  echo "鍥炴敹绔欏凡娓呯┖銆�"
		fi
		;;
	  *)
		break
		;;
	esac
  done
}




linux_ps() {

	clear
	send_stats "绯荤粺淇℃伅鏌ヨ"

	ip_address

	local cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')

	local cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
		<(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))

	local cpu_cores=$(nproc)

	local cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')

	local mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

	local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

	local ipinfo=$(curl -s ipinfo.io)
	local country=$(echo "$ipinfo" | grep 'country' | awk -F': ' '{print $2}' | tr -d '",')
	local city=$(echo "$ipinfo" | grep 'city' | awk -F': ' '{print $2}' | tr -d '",')
	local isp_info=$(echo "$ipinfo" | grep 'org' | awk -F': ' '{print $2}' | tr -d '",')

	local load=$(uptime | awk '{print $(NF-2), $(NF-1), $NF}')
	local dns_addresses=$(awk '/^nameserver/{printf "%s ", $2} END {print ""}' /etc/resolv.conf)


	local cpu_arch=$(uname -m)

	local hostname=$(uname -n)

	local kernel_version=$(uname -r)

	local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	local queue_algorithm=$(sysctl -n net.core.default_qdisc)

	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')

	output_status

	local current_time=$(date "+%Y-%m-%d %I:%M %p")


	local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

	local runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d澶� ", run_days); if (run_hours > 0) printf("%d鏃� ", run_hours); printf("%d鍒哱n", run_minutes)}')

	local timezone=$(current_timezone)


	echo ""
	echo -e "绯荤粺淇℃伅鏌ヨ"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}涓绘満鍚�:       ${gl_bai}$hostname"
	echo -e "${gl_kjlan}绯荤粺鐗堟湰:     ${gl_bai}$os_info"
	echo -e "${gl_kjlan}Linux鐗堟湰:    ${gl_bai}$kernel_version"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU鏋舵瀯:      ${gl_bai}$cpu_arch"
	echo -e "${gl_kjlan}CPU鍨嬪彿:      ${gl_bai}$cpu_info"
	echo -e "${gl_kjlan}CPU鏍稿績鏁�:    ${gl_bai}$cpu_cores"
	echo -e "${gl_kjlan}CPU棰戠巼:      ${gl_bai}$cpu_freq"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU鍗犵敤:      ${gl_bai}$cpu_usage_percent%"
	echo -e "${gl_kjlan}绯荤粺璐熻浇:     ${gl_bai}$load"
	echo -e "${gl_kjlan}鐗╃悊鍐呭瓨:     ${gl_bai}$mem_info"
	echo -e "${gl_kjlan}铏氭嫙鍐呭瓨:     ${gl_bai}$swap_info"
	echo -e "${gl_kjlan}纭洏鍗犵敤:     ${gl_bai}$disk_info"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}$output"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}缃戠粶绠楁硶:     ${gl_bai}$congestion_algorithm $queue_algorithm"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}杩愯惀鍟�:       ${gl_bai}$isp_info"
	if [ -n "$ipv4_address" ]; then
		echo -e "${gl_kjlan}IPv4鍦板潃:     ${gl_bai}$ipv4_address"
	fi

	if [ -n "$ipv6_address" ]; then
		echo -e "${gl_kjlan}IPv6鍦板潃:     ${gl_bai}$ipv6_address"
	fi
	echo -e "${gl_kjlan}DNS鍦板潃:      ${gl_bai}$dns_addresses"
	echo -e "${gl_kjlan}鍦扮悊浣嶇疆:     ${gl_bai}$country $city"
	echo -e "${gl_kjlan}绯荤粺鏃堕棿:     ${gl_bai}$timezone $current_time"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}杩愯鏃堕暱:     ${gl_bai}$runtime"
	echo



}



linux_tools() {

  while true; do
	  clear
	  # send_stats "鍩虹宸ュ叿"
	  echo -e "鈻� 鍩虹宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}curl 涓嬭浇宸ュ叿 ${gl_huang}鈽�${gl_bai}                   ${gl_kjlan}2.   ${gl_bai}wget 涓嬭浇宸ュ叿 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}3.   ${gl_bai}sudo 瓒呯骇绠＄悊鏉冮檺宸ュ叿             ${gl_kjlan}4.   ${gl_bai}socat 閫氫俊杩炴帴宸ュ叿"
	  echo -e "${gl_kjlan}5.   ${gl_bai}htop 绯荤粺鐩戞帶宸ュ叿                 ${gl_kjlan}6.   ${gl_bai}iftop 缃戠粶娴侀噺鐩戞帶宸ュ叿"
	  echo -e "${gl_kjlan}7.   ${gl_bai}unzip ZIP鍘嬬缉瑙ｅ帇宸ュ叿             ${gl_kjlan}8.   ${gl_bai}tar GZ鍘嬬缉瑙ｅ帇宸ュ叿"
	  echo -e "${gl_kjlan}9.   ${gl_bai}tmux 澶氳矾鍚庡彴杩愯宸ュ叿             ${gl_kjlan}10.  ${gl_bai}ffmpeg 瑙嗛缂栫爜鐩存挱鎺ㄦ祦宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}btop 鐜颁唬鍖栫洃鎺у伐鍏� ${gl_huang}鈽�${gl_bai}             ${gl_kjlan}12.  ${gl_bai}ranger 鏂囦欢绠＄悊宸ュ叿"
	  echo -e "${gl_kjlan}13.  ${gl_bai}ncdu 纾佺洏鍗犵敤鏌ョ湅宸ュ叿             ${gl_kjlan}14.  ${gl_bai}fzf 鍏ㄥ眬鎼滅储宸ュ叿"
	  echo -e "${gl_kjlan}15.  ${gl_bai}vim 鏂囨湰缂栬緫鍣�                    ${gl_kjlan}16.  ${gl_bai}nano 鏂囨湰缂栬緫鍣� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}17.  ${gl_bai}git 鐗堟湰鎺у埗绯荤粺"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}21.  ${gl_bai}榛戝甯濆浗灞忎繚                      ${gl_kjlan}22.  ${gl_bai}璺戠伀杞﹀睆淇�"
	  echo -e "${gl_kjlan}26.  ${gl_bai}淇勭綏鏂柟鍧楀皬娓告垙                  ${gl_kjlan}27.  ${gl_bai}璐悆铔囧皬娓告垙"
	  echo -e "${gl_kjlan}28.  ${gl_bai}澶┖鍏ヤ镜鑰呭皬娓告垙"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}31.  ${gl_bai}鍏ㄩ儴瀹夎                          ${gl_kjlan}32.  ${gl_bai}鍏ㄩ儴瀹夎锛堜笉鍚睆淇濆拰娓告垙锛�${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}33.  ${gl_bai}鍏ㄩ儴鍗歌浇"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}41.  ${gl_bai}瀹夎鎸囧畾宸ュ叿                      ${gl_kjlan}42.  ${gl_bai}鍗歌浇鎸囧畾宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  install curl
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  curl --help
			  send_stats "瀹夎curl"
			  ;;
		  2)
			  clear
			  install wget
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  wget --help
			  send_stats "瀹夎wget"
			  ;;
			3)
			  clear
			  install sudo
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  sudo --help
			  send_stats "瀹夎sudo"
			  ;;
			4)
			  clear
			  install socat
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  socat -h
			  send_stats "瀹夎socat"
			  ;;
			5)
			  clear
			  install htop
			  clear
			  htop
			  send_stats "瀹夎htop"
			  ;;
			6)
			  clear
			  install iftop
			  clear
			  iftop
			  send_stats "瀹夎iftop"
			  ;;
			7)
			  clear
			  install unzip
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  unzip
			  send_stats "瀹夎unzip"
			  ;;
			8)
			  clear
			  install tar
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  tar --help
			  send_stats "瀹夎tar"
			  ;;
			9)
			  clear
			  install tmux
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  tmux --help
			  send_stats "瀹夎tmux"
			  ;;
			10)
			  clear
			  install ffmpeg
			  clear
			  echo "宸ュ叿宸插畨瑁咃紝浣跨敤鏂规硶濡備笅锛�"
			  ffmpeg --help
			  send_stats "瀹夎ffmpeg"
			  ;;

			11)
			  clear
			  install btop
			  clear
			  btop
			  send_stats "瀹夎btop"
			  ;;
			12)
			  clear
			  install ranger
			  cd /
			  clear
			  ranger
			  cd ~
			  send_stats "瀹夎ranger"
			  ;;
			13)
			  clear
			  install ncdu
			  cd /
			  clear
			  ncdu
			  cd ~
			  send_stats "瀹夎ncdu"
			  ;;
			14)
			  clear
			  install fzf
			  cd /
			  clear
			  fzf
			  cd ~
			  send_stats "瀹夎fzf"
			  ;;
			15)
			  clear
			  install vim
			  cd /
			  clear
			  vim -h
			  cd ~
			  send_stats "瀹夎vim"
			  ;;
			16)
			  clear
			  install nano
			  cd /
			  clear
			  nano -h
			  cd ~
			  send_stats "瀹夎nano"
			  ;;


			17)
			  clear
			  install git
			  cd /
			  clear
			  git --help
			  cd ~
			  send_stats "瀹夎git"
			  ;;

			21)
			  clear
			  install cmatrix
			  clear
			  cmatrix
			  send_stats "瀹夎cmatrix"
			  ;;
			22)
			  clear
			  install sl
			  clear
			  sl
			  send_stats "瀹夎sl"
			  ;;
			26)
			  clear
			  install bastet
			  clear
			  bastet
			  send_stats "瀹夎bastet"
			  ;;
			27)
			  clear
			  install nsnake
			  clear
			  nsnake
			  send_stats "瀹夎nsnake"
			  ;;
			28)
			  clear
			  install ninvaders
			  clear
			  ninvaders
			  send_stats "瀹夎ninvaders"
			  ;;

		  31)
			  clear
			  send_stats "鍏ㄩ儴瀹夎"
			  install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
			  ;;

		  32)
			  clear
			  send_stats "鍏ㄩ儴瀹夎锛堜笉鍚父鎴忓拰灞忎繚锛�"
			  install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf vim nano git
			  ;;


		  33)
			  clear
			  send_stats "鍏ㄩ儴鍗歌浇"
			  remove htop iftop tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
			  ;;

		  41)
			  clear
			  read -e -p "璇疯緭鍏ュ畨瑁呯殑宸ュ叿鍚嶏紙wget curl sudo htop锛�: " installname
			  install $installname
			  send_stats "瀹夎鎸囧畾杞欢"
			  ;;
		  42)
			  clear
			  read -e -p "璇疯緭鍏ュ嵏杞界殑宸ュ叿鍚嶏紙htop ufw tmux cmatrix锛�: " removename
			  remove $removename
			  send_stats "鍗歌浇鎸囧畾杞欢"
			  ;;

		  0)
			  kejilion

			  ;;

		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end
  done




}


linux_bbr() {
	clear
	send_stats "bbr绠＄悊"
	if [ -f "/etc/alpine-release" ]; then
		while true; do
			  clear
			  local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
			  local queue_algorithm=$(sysctl -n net.core.default_qdisc)
			  echo "褰撳墠TCP闃诲绠楁硶: $congestion_algorithm $queue_algorithm"

			  echo ""
			  echo "BBR绠＄悊"
			  echo "------------------------"
			  echo "1. 寮€鍚疊BRv3              2. 鍏抽棴BBRv3锛堜細閲嶅惎锛�"
			  echo "------------------------"
			  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

			  case $sub_choice in
				  1)
					bbr_on
					send_stats "alpine寮€鍚痓br3"
					  ;;
				  2)
					sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
					sysctl -p
					server_reboot
					  ;;
				  0)
					  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
					  ;;

				  *)
					  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
					  ;;

			  esac
		done
	else
		install wget
		wget --no-check-certificate -O tcpx.sh ${gh_proxy}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
		chmod +x tcpx.sh
		./tcpx.sh
	fi


}





linux_docker() {

	while true; do
	  clear
	  # send_stats "docker绠＄悊"
	  echo -e "鈻� Docker绠＄悊"
	  docker_tato
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}瀹夎鏇存柊Docker鐜 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}2.   ${gl_bai}鏌ョ湅Docker鍏ㄥ眬鐘舵€� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}3.   ${gl_bai}Docker瀹瑰櫒绠＄悊 鈻� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}4.   ${gl_bai}Docker闀滃儚绠＄悊 鈻�"
	  echo -e "${gl_kjlan}5.   ${gl_bai}Docker缃戠粶绠＄悊 鈻�"
	  echo -e "${gl_kjlan}6.   ${gl_bai}Docker鍗风鐞� 鈻�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}7.   ${gl_bai}娓呯悊鏃犵敤鐨刣ocker瀹瑰櫒鍜岄暅鍍忕綉缁滄暟鎹嵎"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}8.   ${gl_bai}鏇存崲Docker婧�"
	  echo -e "${gl_kjlan}9.   ${gl_bai}缂栬緫daemon.json鏂囦欢"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}寮€鍚疍ocker-ipv6璁块棶"
	  echo -e "${gl_kjlan}12.  ${gl_bai}鍏抽棴Docker-ipv6璁块棶"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}20.  ${gl_bai}鍗歌浇Docker鐜"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			clear
			send_stats "瀹夎docker鐜"
			install_add_docker

			  ;;
		  2)
			  clear
			  local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
			  local image_count=$(docker images -q 2>/dev/null | wc -l)
			  local network_count=$(docker network ls -q 2>/dev/null | wc -l)
			  local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

			  send_stats "docker鍏ㄥ眬鐘舵€�"
			  echo "Docker鐗堟湰"
			  docker -v
			  docker compose version

			  echo ""
			  echo -e "Docker闀滃儚: ${gl_lv}$image_count${gl_bai} "
			  docker image ls
			  echo ""
			  echo -e "Docker瀹瑰櫒: ${gl_lv}$container_count${gl_bai}"
			  docker ps -a
			  echo ""
			  echo -e "Docker鍗�: ${gl_lv}$volume_count${gl_bai}"
			  docker volume ls
			  echo ""
			  echo -e "Docker缃戠粶: ${gl_lv}$network_count${gl_bai}"
			  docker network ls
			  echo ""

			  ;;
		  3)
			  docker_ps
			  ;;
		  4)
			  docker_image
			  ;;

		  5)
			  while true; do
				  clear
				  send_stats "Docker缃戠粶绠＄悊"
				  echo "Docker缃戠粶鍒楄〃"
				  echo "------------------------------------------------------------"
				  docker network ls
				  echo ""

				  echo "------------------------------------------------------------"
				  container_ids=$(docker ps -q)
				  printf "%-25s %-25s %-25s\n" "瀹瑰櫒鍚嶇О" "缃戠粶鍚嶇О" "IP鍦板潃"

				  for container_id in $container_ids; do
					  local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

					  local container_name=$(echo "$container_info" | awk '{print $1}')
					  local network_info=$(echo "$container_info" | cut -d' ' -f2-)

					  while IFS= read -r line; do
						  local network_name=$(echo "$line" | awk '{print $1}')
						  local ip_address=$(echo "$line" | awk '{print $2}')

						  printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
					  done <<< "$network_info"
				  done

				  echo ""
				  echo "缃戠粶鎿嶄綔"
				  echo "------------------------"
				  echo "1. 鍒涘缓缃戠粶"
				  echo "2. 鍔犲叆缃戠粶"
				  echo "3. 閫€鍑虹綉缁�"
				  echo "4. 鍒犻櫎缃戠粶"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "鍒涘缓缃戠粶"
						  read -e -p "璁剧疆鏂扮綉缁滃悕: " dockernetwork
						  docker network create $dockernetwork
						  ;;
					  2)
						  send_stats "鍔犲叆缃戠粶"
						  read -e -p "鍔犲叆缃戠粶鍚�: " dockernetwork
						  read -e -p "閭ｄ簺瀹瑰櫒鍔犲叆璇ョ綉缁滐紙澶氫釜瀹瑰櫒鍚嶈鐢ㄧ┖鏍煎垎闅旓級: " dockernames

						  for dockername in $dockernames; do
							  docker network connect $dockernetwork $dockername
						  done
						  ;;
					  3)
						  send_stats "鍔犲叆缃戠粶"
						  read -e -p "閫€鍑虹綉缁滃悕: " dockernetwork
						  read -e -p "閭ｄ簺瀹瑰櫒閫€鍑鸿缃戠粶锛堝涓鍣ㄥ悕璇风敤绌烘牸鍒嗛殧锛�: " dockernames

						  for dockername in $dockernames; do
							  docker network disconnect $dockernetwork $dockername
						  done

						  ;;

					  4)
						  send_stats "鍒犻櫎缃戠粶"
						  read -e -p "璇疯緭鍏ヨ鍒犻櫎鐨勭綉缁滃悕: " dockernetwork
						  docker network rm $dockernetwork
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done
			  ;;

		  6)
			  while true; do
				  clear
				  send_stats "Docker鍗风鐞�"
				  echo "Docker鍗峰垪琛�"
				  docker volume ls
				  echo ""
				  echo "鍗锋搷浣�"
				  echo "------------------------"
				  echo "1. 鍒涘缓鏂板嵎"
				  echo "2. 鍒犻櫎鎸囧畾鍗�"
				  echo "3. 鍒犻櫎鎵€鏈夊嵎"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "鏂板缓鍗�"
						  read -e -p "璁剧疆鏂板嵎鍚�: " dockerjuan
						  docker volume create $dockerjuan

						  ;;
					  2)
						  read -e -p "杈撳叆鍒犻櫎鍗峰悕锛堝涓嵎鍚嶈鐢ㄧ┖鏍煎垎闅旓級: " dockerjuans

						  for dockerjuan in $dockerjuans; do
							  docker volume rm $dockerjuan
						  done

						  ;;

					   3)
						  send_stats "鍒犻櫎鎵€鏈夊嵎"
						  read -e -p "$(echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}纭畾鍒犻櫎鎵€鏈夋湭浣跨敤鐨勫嵎鍚楋紵(Y/N): ")" choice
						  case "$choice" in
							[Yy])
							  docker volume prune -f
							  ;;
							[Nn])
							  ;;
							*)
							  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
							  ;;
						  esac
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done
			  ;;
		  7)
			  clear
			  send_stats "Docker娓呯悊"
			  read -e -p "$(echo -e "${gl_huang}鎻愮ず: ${gl_bai}灏嗘竻鐞嗘棤鐢ㄧ殑闀滃儚瀹瑰櫒缃戠粶锛屽寘鎷仠姝㈢殑瀹瑰櫒锛岀‘瀹氭竻鐞嗗悧锛�(Y/N): ")" choice
			  case "$choice" in
				[Yy])
				  docker system prune -af --volumes
				  ;;
				[Nn])
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			  ;;
		  8)
			  clear
			  send_stats "Docker婧�"
			  bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
			  ;;

		  9)
			  clear
			  install nano
			  mkdir -p /etc/docker && nano /etc/docker/daemon.json
			  restart docker
			  ;;

		  11)
			  clear
			  send_stats "Docker v6 寮€"
			  docker_ipv6_on
			  ;;

		  12)
			  clear
			  send_stats "Docker v6 鍏�"
			  docker_ipv6_off
			  ;;

		  20)
			  clear
			  send_stats "Docker鍗歌浇"
			  read -e -p "$(echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}纭畾鍗歌浇docker鐜鍚楋紵(Y/N): ")" choice
			  case "$choice" in
				[Yy])
				  docker ps -a -q | xargs -r docker rm -f && docker images -q | xargs -r docker rmi && docker network prune -f && docker volume prune -f
				  remove docker docker-compose docker-ce docker-ce-cli containerd.io
				  rm -f /etc/docker/daemon.json
				  hash -r
				  ;;
				[Nn])
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			  ;;

		  0)
			  kejilion
			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end


	done


}



linux_test() {

	while true; do
	  clear
	  # send_stats "娴嬭瘯鑴氭湰鍚堥泦"
	  echo -e "鈻� 娴嬭瘯鑴氭湰鍚堥泦"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}IP鍙婅В閿佺姸鎬佹娴�"
	  echo -e "${gl_kjlan}1.   ${gl_bai}ChatGPT 瑙ｉ攣鐘舵€佹娴�"
	  echo -e "${gl_kjlan}2.   ${gl_bai}Region 娴佸獟浣撹В閿佹祴璇�"
	  echo -e "${gl_kjlan}3.   ${gl_bai}yeahwu 娴佸獟浣撹В閿佹娴�"
	  echo -e "${gl_kjlan}4.   ${gl_bai}xykt IP璐ㄩ噺浣撴鑴氭湰 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}缃戠粶绾胯矾娴嬮€�"
	  echo -e "${gl_kjlan}11.  ${gl_bai}besttrace 涓夌綉鍥炵▼寤惰繜璺敱娴嬭瘯"
	  echo -e "${gl_kjlan}12.  ${gl_bai}mtr_trace 涓夌綉鍥炵▼绾胯矾娴嬭瘯"
	  echo -e "${gl_kjlan}13.  ${gl_bai}Superspeed 涓夌綉娴嬮€�"
	  echo -e "${gl_kjlan}14.  ${gl_bai}nxtrace 蹇€熷洖绋嬫祴璇曡剼鏈�"
	  echo -e "${gl_kjlan}15.  ${gl_bai}nxtrace 鎸囧畾IP鍥炵▼娴嬭瘯鑴氭湰"
	  echo -e "${gl_kjlan}16.  ${gl_bai}ludashi2020 涓夌綉绾胯矾娴嬭瘯"
	  echo -e "${gl_kjlan}17.  ${gl_bai}i-abc 澶氬姛鑳芥祴閫熻剼鏈�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}纭欢鎬ц兘娴嬭瘯"
	  echo -e "${gl_kjlan}21.  ${gl_bai}yabs 鎬ц兘娴嬭瘯"
	  echo -e "${gl_kjlan}22.  ${gl_bai}icu/gb5 CPU鎬ц兘娴嬭瘯鑴氭湰"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}缁煎悎鎬ф祴璇�"
	  echo -e "${gl_kjlan}31.  ${gl_bai}bench 鎬ц兘娴嬭瘯"
	  echo -e "${gl_kjlan}32.  ${gl_bai}spiritysdx 铻嶅悎鎬祴璇� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  send_stats "ChatGPT瑙ｉ攣鐘舵€佹娴�"
			  bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
			  ;;
		  2)
			  clear
			  send_stats "Region娴佸獟浣撹В閿佹祴璇�"
			  bash <(curl -L -s check.unlock.media)
			  ;;
		  3)
			  clear
			  send_stats "yeahwu娴佸獟浣撹В閿佹娴�"
			  install wget
			  wget -qO- ${gh_proxy}https://github.com/yeahwu/check/raw/main/check.sh | bash
			  ;;
		  4)
			  clear
			  send_stats "xykt_IP璐ㄩ噺浣撴鑴氭湰"
			  bash <(curl -Ls IP.Check.Place)
			  ;;
		  11)
			  clear
			  send_stats "besttrace涓夌綉鍥炵▼寤惰繜璺敱娴嬭瘯"
			  install wget
			  wget -qO- git.io/besttrace | bash
			  ;;
		  12)
			  clear
			  send_stats "mtr_trace涓夌綉鍥炵▼绾胯矾娴嬭瘯"
			  curl ${gh_proxy}https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
			  ;;
		  13)
			  clear
			  send_stats "Superspeed涓夌綉娴嬮€�"
			  bash <(curl -Lso- https://git.io/superspeed_uxh)
			  ;;
		  14)
			  clear
			  send_stats "nxtrace蹇€熷洖绋嬫祴璇曡剼鏈�"
			  curl nxtrace.org/nt |bash
			  nexttrace --fast-trace --tcp
			  ;;
		  15)
			  clear
			  send_stats "nxtrace鎸囧畾IP鍥炵▼娴嬭瘯鑴氭湰"
			  echo "鍙弬鑰冪殑IP鍒楄〃"
			  echo "------------------------"
			  echo "鍖椾含鐢典俊: 219.141.136.12"
			  echo "鍖椾含鑱旈€�: 202.106.50.1"
			  echo "鍖椾含绉诲姩: 221.179.155.161"
			  echo "涓婃捣鐢典俊: 202.96.209.133"
			  echo "涓婃捣鑱旈€�: 210.22.97.1"
			  echo "涓婃捣绉诲姩: 211.136.112.200"
			  echo "骞垮窞鐢典俊: 58.60.188.222"
			  echo "骞垮窞鑱旈€�: 210.21.196.6"
			  echo "骞垮窞绉诲姩: 120.196.165.24"
			  echo "鎴愰兘鐢典俊: 61.139.2.69"
			  echo "鎴愰兘鑱旈€�: 119.6.6.6"
			  echo "鎴愰兘绉诲姩: 211.137.96.205"
			  echo "婀栧崡鐢典俊: 36.111.200.100"
			  echo "婀栧崡鑱旈€�: 42.48.16.100"
			  echo "婀栧崡绉诲姩: 39.134.254.6"
			  echo "------------------------"

			  read -e -p "杈撳叆涓€涓寚瀹欼P: " testip
			  curl nxtrace.org/nt |bash
			  nexttrace $testip
			  ;;

		  16)
			  clear
			  send_stats "ludashi2020涓夌綉绾胯矾娴嬭瘯"
			  curl ${gh_proxy}https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
			  ;;

		  17)
			  clear
			  send_stats "i-abc澶氬姛鑳芥祴閫熻剼鏈�"
			  bash <(curl -sL ${gh_proxy}https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh)
			  ;;


		  21)
			  clear
			  send_stats "yabs鎬ц兘娴嬭瘯"
			  check_swap
			  curl -sL yabs.sh | bash -s -- -i -5
			  ;;
		  22)
			  clear
			  send_stats "icu/gb5 CPU鎬ц兘娴嬭瘯鑴氭湰"
			  check_swap
			  bash <(curl -sL bash.icu/gb5)
			  ;;

		  31)
			  clear
			  send_stats "bench鎬ц兘娴嬭瘯"
			  curl -Lso- bench.sh | bash
			  ;;
		  32)
			  send_stats "spiritysdx铻嶅悎鎬祴璇�"
			  clear
			  curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
			  ;;

		  0)
			  kejilion

			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done


}


linux_Oracle() {


	 while true; do
	  clear
	  send_stats "鐢查鏂囦簯鑴氭湰鍚堥泦"
	  echo -e "鈻� 鐢查鏂囦簯鑴氭湰鍚堥泦"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}瀹夎闂茬疆鏈哄櫒娲昏穬鑴氭湰"
	  echo -e "${gl_kjlan}2.   ${gl_bai}鍗歌浇闂茬疆鏈哄櫒娲昏穬鑴氭湰"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}3.   ${gl_bai}DD閲嶈绯荤粺鑴氭湰"
	  echo -e "${gl_kjlan}4.   ${gl_bai}R鎺㈤暱寮€鏈鸿剼鏈�"
	  echo -e "${gl_kjlan}5.   ${gl_bai}寮€鍚疪OOT瀵嗙爜鐧诲綍妯″紡"
	  echo -e "${gl_kjlan}6.   ${gl_bai}IPV6鎭㈠宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			  clear
			  echo "娲昏穬鑴氭湰: CPU鍗犵敤10-20% 鍐呭瓨鍗犵敤20% "
			  read -e -p "纭畾瀹夎鍚楋紵(Y/N): " choice
			  case "$choice" in
				[Yy])

				  install_docker

				  # 璁剧疆榛樿鍊�
				  local DEFAULT_CPU_CORE=1
				  local DEFAULT_CPU_UTIL="10-20"
				  local DEFAULT_MEM_UTIL=20
				  local DEFAULT_SPEEDTEST_INTERVAL=120

				  # 鎻愮ず鐢ㄦ埛杈撳叆CPU鏍稿績鏁板拰鍗犵敤鐧惧垎姣旓紝濡傛灉鍥炶溅鍒欎娇鐢ㄩ粯璁ゅ€�
				  read -e -p "璇疯緭鍏PU鏍稿績鏁� [榛樿: $DEFAULT_CPU_CORE]: " cpu_core
				  local cpu_core=${cpu_core:-$DEFAULT_CPU_CORE}

				  read -e -p "璇疯緭鍏PU鍗犵敤鐧惧垎姣旇寖鍥达紙渚嬪10-20锛� [榛樿: $DEFAULT_CPU_UTIL]: " cpu_util
				  local cpu_util=${cpu_util:-$DEFAULT_CPU_UTIL}

				  read -e -p "璇疯緭鍏ュ唴瀛樺崰鐢ㄧ櫨鍒嗘瘮 [榛樿: $DEFAULT_MEM_UTIL]: " mem_util
				  local mem_util=${mem_util:-$DEFAULT_MEM_UTIL}

				  read -e -p "璇疯緭鍏peedtest闂撮殧鏃堕棿锛堢锛� [榛樿: $DEFAULT_SPEEDTEST_INTERVAL]: " speedtest_interval
				  local speedtest_interval=${speedtest_interval:-$DEFAULT_SPEEDTEST_INTERVAL}

				  # 杩愯Docker瀹瑰櫒
				  docker run -itd --name=lookbusy --restart=always \
					  -e TZ=Asia/Shanghai \
					  -e CPU_UTIL="$cpu_util" \
					  -e CPU_CORE="$cpu_core" \
					  -e MEM_UTIL="$mem_util" \
					  -e SPEEDTEST_INTERVAL="$speedtest_interval" \
					  fogforest/lookbusy
				  send_stats "鐢查鏂囦簯瀹夎娲昏穬鑴氭湰"

				  ;;
				[Nn])

				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			  ;;
		  2)
			  clear
			  docker rm -f lookbusy
			  docker rmi fogforest/lookbusy
			  send_stats "鐢查鏂囦簯鍗歌浇娲昏穬鑴氭湰"
			  ;;

		  3)
		  clear
		  echo "閲嶈绯荤粺"
		  echo "--------------------------------"
		  echo -e "${gl_hong}娉ㄦ剰: ${gl_bai}閲嶈鏈夐闄╁け鑱旓紝涓嶆斁蹇冭€呮厧鐢ㄣ€傞噸瑁呴璁¤姳璐�15鍒嗛挓锛岃鎻愬墠澶囦唤鏁版嵁銆�"
		  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

		  case "$choice" in
			[Yy])
			  while true; do
				read -e -p "璇烽€夋嫨瑕侀噸瑁呯殑绯荤粺:  1. Debian12 | 2. Ubuntu20.04 : " sys_choice

				case "$sys_choice" in
				  1)
					local xitong="-d 12"
					break  # 缁撴潫寰幆
					;;
				  2)
					local xitong="-u 20.04"
					break  # 缁撴潫寰幆
					;;
				  *)
					echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
					;;
				esac
			  done

			  read -e -p "璇疯緭鍏ヤ綘閲嶈鍚庣殑瀵嗙爜: " vpspasswd
			  install wget
			  bash <(wget --no-check-certificate -qO- "${gh_proxy}https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh") $xitong -v 64 -p $vpspasswd -port 22
			  send_stats "鐢查鏂囦簯閲嶈绯荤粺鑴氭湰"
			  ;;
			[Nn])
			  echo "宸插彇娑�"
			  ;;
			*)
			  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
			  ;;
		  esac
			  ;;

		  4)
			  clear
			  echo "璇ュ姛鑳藉浜庡紑鍙戦樁娈碉紝鏁鏈熷緟锛�"
			  ;;
		  5)
			  clear
			  add_sshpasswd

			  ;;
		  6)
			  clear
			  bash <(curl -L -s jhb.ovh/jb/v6.sh)
			  echo "璇ュ姛鑳界敱jhb澶х鎻愪緵锛屾劅璋粬锛�"
			  send_stats "ipv6淇"
			  ;;
		  0)
			  kejilion

			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done



}


docker_tato() {

	local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
	local image_count=$(docker images -q 2>/dev/null | wc -l)
	local network_count=$(docker network ls -q 2>/dev/null | wc -l)
	local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

	if command -v docker &> /dev/null; then
		echo -e "${gl_kjlan}------------------------"
		echo -e "${gl_lv}鐜宸茬粡瀹夎${gl_bai}  瀹瑰櫒: ${gl_lv}$container_count${gl_bai}  闀滃儚: ${gl_lv}$image_count${gl_bai}  缃戠粶: ${gl_lv}$network_count${gl_bai}  鍗�: ${gl_lv}$volume_count${gl_bai}"
	fi
}



ldnmp_tato() {
local cert_count=$(ls /home/web/certs/*_cert.pem 2>/dev/null | wc -l)
local output="绔欑偣: ${gl_lv}${cert_count}${gl_bai}"

local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml 2>/dev/null | tr -d '[:space:]')
if [ -n "$dbrootpasswd" ]; then
	local db_count=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys" | wc -l)
fi

local db_output="鏁版嵁搴�: ${gl_lv}${db_count}${gl_bai}"


if command -v docker &>/dev/null; then
	if docker ps --filter "name=nginx" --filter "status=running" | grep -q nginx; then
		echo -e "${gl_huang}------------------------"
		echo -e "${gl_lv}鐜宸插畨瑁�${gl_bai}  $output  $db_output"
	fi
fi

}


linux_ldnmp() {
  while true; do

	clear
	# send_stats "LDNMP寤虹珯"
	echo -e "${gl_huang}鈻� LDNMP寤虹珯"
	ldnmp_tato
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}1.   ${gl_bai}瀹夎LDNMP鐜 ${gl_huang}鈽�${gl_bai}"
	echo -e "${gl_huang}2.   ${gl_bai}瀹夎WordPress ${gl_huang}鈽�${gl_bai}"
	echo -e "${gl_huang}3.   ${gl_bai}瀹夎Discuz璁哄潧"
	echo -e "${gl_huang}4.   ${gl_bai}瀹夎鍙亾浜戞闈�"
	echo -e "${gl_huang}5.   ${gl_bai}瀹夎鑻规灉CMS缃戠珯"
	echo -e "${gl_huang}6.   ${gl_bai}瀹夎鐙鏁板彂鍗＄綉"
	echo -e "${gl_huang}7.   ${gl_bai}瀹夎flarum璁哄潧缃戠珯"
	echo -e "${gl_huang}8.   ${gl_bai}瀹夎typecho杞婚噺鍗氬缃戠珯"
	echo -e "${gl_huang}9.   ${gl_bai}瀹夎LinkStack鍏变韩閾炬帴骞冲彴"
	echo -e "${gl_huang}20.  ${gl_bai}鑷畾涔夊姩鎬佺珯鐐�"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}21.  ${gl_bai}浠呭畨瑁卬ginx ${gl_huang}鈽�${gl_bai}"
	echo -e "${gl_huang}22.  ${gl_bai}绔欑偣閲嶅畾鍚�"
	echo -e "${gl_huang}23.  ${gl_bai}绔欑偣鍙嶅悜浠ｇ悊-IP+绔彛 ${gl_huang}鈽�${gl_bai}"
	echo -e "${gl_huang}24.  ${gl_bai}绔欑偣鍙嶅悜浠ｇ悊-鍩熷悕"
	echo -e "${gl_huang}25.  ${gl_bai}鑷畾涔夐潤鎬佺珯鐐�"
	echo -e "${gl_huang}26.  ${gl_bai}瀹夎Bitwarden瀵嗙爜绠＄悊骞冲彴"
	echo -e "${gl_huang}27.  ${gl_bai}瀹夎Halo鍗氬缃戠珯"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}31.  ${gl_bai}绔欑偣鏁版嵁绠＄悊 ${gl_huang}鈽�${gl_bai}"
	echo -e "${gl_huang}32.  ${gl_bai}澶囦唤鍏ㄧ珯鏁版嵁"
	echo -e "${gl_huang}33.  ${gl_bai}瀹氭椂杩滅▼澶囦唤"
	echo -e "${gl_huang}34.  ${gl_bai}杩樺師鍏ㄧ珯鏁版嵁"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}35.  ${gl_bai}绔欑偣闃插尽绋嬪簭"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}36.  ${gl_bai}浼樺寲LDNMP鐜"
	echo -e "${gl_huang}37.  ${gl_bai}鏇存柊LDNMP鐜"
	echo -e "${gl_huang}38.  ${gl_bai}鍗歌浇LDNMP鐜"
	echo -e "${gl_huang}------------------------"
	echo -e "${gl_huang}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	echo -e "${gl_huang}------------------------${gl_bai}"
	read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice


	case $sub_choice in
	  1)
	  ldnmp_install_status_one
	  ldnmp_install_all
		;;
	  2)
	  ldnmp_wp
		;;

	  3)
	  clear
	  # Discuz璁哄潧
	  webname="Discuz璁哄潧"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/discuz.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/kejilion/Website_source_code/raw/main/Discuz_X3.5_SC_UTF8_20240520.zip
	  unzip latest.zip
	  rm latest.zip

	  restart_ldnmp


	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "琛ㄥ墠缂€: discuz_"


		;;

	  4)
	  clear
	  # 鍙亾浜戞闈�
	  webname="鍙亾浜戞闈�"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/kdy.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/kalcaddle/kodbox/archive/refs/tags/1.50.02.zip
	  unzip -o latest.zip
	  rm latest.zip
	  mv /home/web/html/$yuming/kodbox* /home/web/html/$yuming/kodbox
	  restart_ldnmp

	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "redis涓绘満: redis"

		;;

	  5)
	  clear
	  # 鑻规灉CMS
	  webname="鑻规灉CMS"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/maccms.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  # wget ${gh_proxy}https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
	  wget ${gh_proxy}https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && mv maccms10-*/* . && rm -r maccms10-* && rm maccms10.zip
	  cd /home/web/html/$yuming/template/ && wget ${gh_proxy}https://github.com/kejilion/Website_source_code/raw/main/DYXS2.zip && unzip DYXS2.zip && rm /home/web/html/$yuming/template/DYXS2.zip
	  cp /home/web/html/$yuming/template/DYXS2/asset/admin/Dyxs2.php /home/web/html/$yuming/application/admin/controller
	  cp /home/web/html/$yuming/template/DYXS2/asset/admin/dycms.html /home/web/html/$yuming/application/admin/view/system
	  mv /home/web/html/$yuming/admin.php /home/web/html/$yuming/vip.php && wget -O /home/web/html/$yuming/application/extra/maccms.php ${gh_proxy}https://raw.githubusercontent.com/kejilion/Website_source_code/main/maccms.php

	  restart_ldnmp


	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撶鍙�: 3306"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "鏁版嵁搴撳墠缂€: mac_"
	  echo "------------------------"
	  echo "瀹夎鎴愬姛鍚庣櫥褰曞悗鍙板湴鍧€"
	  echo "https://$yuming/vip.php"

		;;

	  6)
	  clear
	  # 鐙剼鏁板崱
	  webname="鐙剼鏁板崱"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/dujiaoka.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget ${gh_proxy}https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

	  restart_ldnmp


	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撶鍙�: 3306"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo ""
	  echo "redis鍦板潃: redis"
	  echo "redis瀵嗙爜: 榛樿涓嶅～鍐�"
	  echo "redis绔彛: 6379"
	  echo ""
	  echo "缃戠珯url: https://$yuming"
	  echo "鍚庡彴鐧诲綍璺緞: /admin"
	  echo "------------------------"
	  echo "鐢ㄦ埛鍚�: admin"
	  echo "瀵嗙爜: admin"
	  echo "------------------------"
	  echo "鐧诲綍鏃跺彸涓婅濡傛灉鍑虹幇绾㈣壊error0璇蜂娇鐢ㄥ涓嬪懡浠�: "
	  echo "鎴戜篃寰堟皵鎰ょ嫭瑙掓暟鍗′负鍟ヨ繖涔堥夯鐑︼紝浼氭湁杩欐牱鐨勯棶棰橈紒"
	  echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/web/html/$yuming/dujiaoka/.env"

		;;

	  7)
	  clear
	  # flarum璁哄潧
	  webname="flarum璁哄潧"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/flarum.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming

	  docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
	  docker exec php sh -c "php composer-setup.php"
	  docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
	  docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

	  docker exec php composer create-project flarum/flarum /var/www/html/$yuming
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum-lang/chinese-simplified"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/polls"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/sitemap"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/oauth"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/best-answer:*"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require v17development/flarum-seo"
	  docker exec php sh -c "cd /var/www/html/$yuming && composer require clarkwinkelmann/flarum-ext-emojionearea"


	  restart_ldnmp


	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "琛ㄥ墠缂€: flarum_"
	  echo "绠＄悊鍛樹俊鎭嚜琛岃缃�"

		;;

	  8)
	  clear
	  # typecho
	  webname="typecho"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/typecho.com.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/typecho/typecho/releases/latest/download/typecho.zip
	  unzip latest.zip
	  rm latest.zip

	  restart_ldnmp


	  clear
	  ldnmp_web_on
	  echo "鏁版嵁搴撳墠缂€: typecho_"
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "鏁版嵁搴撳悕: $dbname"

		;;


	  9)
	  clear
	  # LinkStack
	  webname="LinkStack"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/refs/heads/main/index_php.conf
	  sed -i "s|/var/www/html/yuming.com/|/var/www/html/yuming.com/linkstack|g" /home/web/conf.d/$yuming.conf
	  sed -i "s|yuming.com|$yuming|g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming
	  wget -O latest.zip ${gh_proxy}https://github.com/linkstackorg/linkstack/releases/latest/download/linkstack.zip
	  unzip latest.zip
	  rm latest.zip

	  restart_ldnmp


	  clear
	  ldnmp_web_on
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撶鍙�: 3306"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
		;;

	  20)
	  clear
	  webname="PHP鍔ㄦ€佺珯鐐�"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  ldnmp_install_status
	  install_ssltls
	  certs_status
	  add_db

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/index_php.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming

	  clear
	  echo -e "[${gl_huang}1/6${gl_bai}] 涓婁紶PHP婧愮爜"
	  echo "-------------"
	  echo "鐩墠鍙厑璁镐笂浼爖ip鏍煎紡鐨勬簮鐮佸寘锛岃灏嗘簮鐮佸寘鏀惧埌/home/web/html/${yuming}鐩綍涓�"
	  read -e -p "涔熷彲浠ヨ緭鍏ヤ笅杞介摼鎺ワ紝杩滅▼涓嬭浇婧愮爜鍖咃紝鐩存帴鍥炶溅灏嗚烦杩囪繙绋嬩笅杞斤細 " url_download

	  if [ -n "$url_download" ]; then
		  wget "$url_download"
	  fi

	  unzip $(ls -t *.zip | head -n 1)
	  rm -f $(ls -t *.zip | head -n 1)

	  clear
	  echo -e "[${gl_huang}2/6${gl_bai}] index.php鎵€鍦ㄨ矾寰�"
	  echo "-------------"
	  # find "$(realpath .)" -name "index.php" -print
	  find "$(realpath .)" -name "index.php" -print | xargs -I {} dirname {}

	  read -e -p "璇疯緭鍏ndex.php鐨勮矾寰勶紝绫讳技锛�/home/web/html/$yuming/wordpress/锛夛細 " index_lujing

	  sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
	  sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

	  clear
	  echo -e "[${gl_huang}3/6${gl_bai}] 璇烽€夋嫨PHP鐗堟湰"
	  echo "-------------"
	  read -e -p "1. php鏈€鏂扮増 | 2. php7.4 : " pho_v
	  case "$pho_v" in
		1)
		  sed -i "s#php:9000#php:9000#g" /home/web/conf.d/$yuming.conf
		  local PHP_Version="php"
		  ;;
		2)
		  sed -i "s#php:9000#php74:9000#g" /home/web/conf.d/$yuming.conf
		  local PHP_Version="php74"
		  ;;
		*)
		  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
		  ;;
	  esac


	  clear
	  echo -e "[${gl_huang}4/6${gl_bai}] 瀹夎鎸囧畾鎵╁睍"
	  echo "-------------"
	  echo "宸茬粡瀹夎鐨勬墿灞�"
	  docker exec php php -m

	  read -e -p "$(echo -e "杈撳叆闇€瑕佸畨瑁呯殑鎵╁睍鍚嶇О锛屽 ${gl_huang}SourceGuardian imap ftp${gl_bai} 绛夌瓑銆傜洿鎺ュ洖杞﹀皢璺宠繃瀹夎 锛� ")" php_extensions
	  if [ -n "$php_extensions" ]; then
		  docker exec $PHP_Version install-php-extensions $php_extensions
	  fi


	  clear
	  echo -e "[${gl_huang}5/6${gl_bai}] 缂栬緫绔欑偣閰嶇疆"
	  echo "-------------"
	  echo "鎸変换鎰忛敭缁х画锛屽彲浠ヨ缁嗚缃珯鐐归厤缃紝濡備吉闈欐€佺瓑鍐呭"
	  read -n 1 -s -r -p ""
	  install nano
	  nano /home/web/conf.d/$yuming.conf


	  clear
	  echo -e "[${gl_huang}6/6${gl_bai}] 鏁版嵁搴撶鐞�"
	  echo "-------------"
	  read -e -p "1. 鎴戞惌寤烘柊绔�        2. 鎴戞惌寤鸿€佺珯鏈夋暟鎹簱澶囦唤锛� " use_db
	  case $use_db in
		  1)
			  echo
			  ;;
		  2)
			  echo "鏁版嵁搴撳浠藉繀椤绘槸.gz缁撳熬鐨勫帇缂╁寘銆傝鏀惧埌/home/鐩綍涓嬶紝鏀寔瀹濆/1panel澶囦唤鏁版嵁瀵煎叆銆�"
			  read -e -p "涔熷彲浠ヨ緭鍏ヤ笅杞介摼鎺ワ紝杩滅▼涓嬭浇澶囦唤鏁版嵁锛岀洿鎺ュ洖杞﹀皢璺宠繃杩滅▼涓嬭浇锛� " url_download_db

			  cd /home/
			  if [ -n "$url_download_db" ]; then
				  wget "$url_download_db"
			  fi
			  gunzip $(ls -t *.gz | head -n 1)
			  latest_sql=$(ls -t *.sql | head -n 1)
			  dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
			  docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname < "/home/$latest_sql"
			  echo "鏁版嵁搴撳鍏ョ殑琛ㄦ暟鎹�"
			  docker exec -i mysql mysql -u root -p"$dbrootpasswd" -e "USE $dbname; SHOW TABLES;"
			  rm -f *.sql
			  echo "鏁版嵁搴撳鍏ュ畬鎴�"
			  ;;
		  *)
			  echo
			  ;;
	  esac

	  restart_ldnmp
	  ldnmp_web_on
	  prefix="web$(shuf -i 10-99 -n 1)_"
	  echo "鏁版嵁搴撳湴鍧€: mysql"
	  echo "鏁版嵁搴撳悕: $dbname"
	  echo "鐢ㄦ埛鍚�: $dbuse"
	  echo "瀵嗙爜: $dbusepasswd"
	  echo "琛ㄥ墠缂€: $prefix"
	  echo "绠＄悊鍛樼櫥褰曚俊鎭嚜琛岃缃�"

		;;


	  21)
	  ldnmp_install_status_one
	  nginx_install_all
		;;

	  22)
	  clear
	  webname="绔欑偣閲嶅畾鍚�"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  read -e -p "璇疯緭鍏ヨ烦杞煙鍚�: " reverseproxy
	  nginx_install_status
	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/rewrite.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s/baidu.com/$reverseproxy/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  docker restart nginx

	  nginx_web_on


		;;

	  23)
	  ldnmp_Proxy
		;;

	  24)
	  clear
	  webname="鍙嶅悜浠ｇ悊-鍩熷悕"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  echo -e "鍩熷悕鏍煎紡: ${gl_huang}google.com${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勫弽浠ｅ煙鍚�: " fandai_yuming
	  nginx_install_status
	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-domain.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  sed -i "s|fandaicom|$fandai_yuming|g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  docker restart nginx

	  nginx_web_on

		;;


	  25)
	  clear
	  webname="闈欐€佺珯鐐�"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  repeat_add_yuming
	  nginx_install_status
	  install_ssltls
	  certs_status

	  wget -O /home/web/conf.d/$yuming.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/html.conf
	  sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	  nginx_http_on

	  cd /home/web/html
	  mkdir $yuming
	  cd $yuming


	  clear
	  echo -e "[${gl_huang}1/2${gl_bai}] 涓婁紶闈欐€佹簮鐮�"
	  echo "-------------"
	  echo "鐩墠鍙厑璁镐笂浼爖ip鏍煎紡鐨勬簮鐮佸寘锛岃灏嗘簮鐮佸寘鏀惧埌/home/web/html/${yuming}鐩綍涓�"
	  read -e -p "涔熷彲浠ヨ緭鍏ヤ笅杞介摼鎺ワ紝杩滅▼涓嬭浇婧愮爜鍖咃紝鐩存帴鍥炶溅灏嗚烦杩囪繙绋嬩笅杞斤細 " url_download

	  if [ -n "$url_download" ]; then
		  wget "$url_download"
	  fi

	  unzip $(ls -t *.zip | head -n 1)
	  rm -f $(ls -t *.zip | head -n 1)

	  clear
	  echo -e "[${gl_huang}2/2${gl_bai}] index.html鎵€鍦ㄨ矾寰�"
	  echo "-------------"
	  # find "$(realpath .)" -name "index.html" -print
	  find "$(realpath .)" -name "index.html" -print | xargs -I {} dirname {}

	  read -e -p "璇疯緭鍏ndex.html鐨勮矾寰勶紝绫讳技锛�/home/web/html/$yuming/index/锛夛細 " index_lujing

	  sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/web/conf.d/$yuming.conf
	  sed -i "s#/home/web/#/var/www/#g" /home/web/conf.d/$yuming.conf

	  docker exec nginx chmod -R nginx:nginx /var/www/html
	  docker restart nginx

	  nginx_web_on

		;;


	  26)
	  clear
	  webname="Bitwarden"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  nginx_install_status
	  install_ssltls
	  certs_status

	  docker run -d \
		--name bitwarden \
		--restart always \
		-p 3280:80 \
		-v /home/web/html/$yuming/bitwarden/data:/data \
		vaultwarden/server
	  duankou=3280
	  reverse_proxy

	  nginx_web_on

		;;

	  27)
	  clear
	  webname="halo"
	  send_stats "瀹夎$webname"
	  echo "寮€濮嬮儴缃� $webname"
	  add_yuming
	  nginx_install_status
	  install_ssltls
	  certs_status

	  docker run -d --name halo --restart always -p 8010:8090 -v /home/web/html/$yuming/.halo2:/root/.halo2 halohub/halo:2
	  duankou=8010
	  reverse_proxy

	  nginx_web_on

		;;



	31)
	  ldnmp_web_status
	  ;;


	32)
	  clear
	  send_stats "LDNMP鐜澶囦唤"

	  local backup_filename="web_$(date +"%Y%m%d%H%M%S").tar.gz"
	  echo -e "${gl_huang}姝ｅ湪澶囦唤 $backup_filename ...${gl_bai}"
	  cd /home/ && tar czvf "$backup_filename" web

	  while true; do
		clear
		echo "澶囦唤鏂囦欢宸插垱寤�: /home/$backup_filename"
		read -e -p "瑕佷紶閫佸浠芥暟鎹埌杩滅▼鏈嶅姟鍣ㄥ悧锛�(Y/N): " choice
		case "$choice" in
		  [Yy])
			read -e -p "璇疯緭鍏ヨ繙绔湇鍔″櫒IP:  " remote_ip
			if [ -z "$remote_ip" ]; then
			  echo "閿欒: 璇疯緭鍏ヨ繙绔湇鍔″櫒IP銆�"
			  continue
			fi
			local latest_tar=$(ls -t /home/*.tar.gz | head -1)
			if [ -n "$latest_tar" ]; then
			  ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
			  sleep 2  # 娣诲姞绛夊緟鏃堕棿
			  scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home/"
			  echo "鏂囦欢宸蹭紶閫佽嚦杩滅▼鏈嶅姟鍣╤ome鐩綍銆�"
			else
			  echo "鏈壘鍒拌浼犻€佺殑鏂囦欢銆�"
			fi
			break
			;;
		  [Nn])
			break
			;;
		  *)
			echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
			;;
		esac
	  done
	  ;;

	33)
	  clear
	  send_stats "瀹氭椂杩滅▼澶囦唤"
	  read -e -p "杈撳叆杩滅▼鏈嶅姟鍣↖P: " useip
	  read -e -p "杈撳叆杩滅▼鏈嶅姟鍣ㄥ瘑鐮�: " usepasswd

	  cd ~
	  wget -O ${useip}_beifen.sh ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/beifen.sh > /dev/null 2>&1
	  chmod +x ${useip}_beifen.sh

	  sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
	  sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh

	  echo "------------------------"
	  echo "1. 姣忓懆澶囦唤                 2. 姣忓ぉ澶囦唤"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " dingshi

	  case $dingshi in
		  1)
			  check_crontab_installed
			  read -e -p "閫夋嫨姣忓懆澶囦唤鐨勬槦鏈熷嚑 (0-6锛�0浠ｈ〃鏄熸湡鏃�): " weekday
			  (crontab -l ; echo "0 0 * * $weekday ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
			  ;;
		  2)
			  check_crontab_installed
			  read -e -p "閫夋嫨姣忓ぉ澶囦唤鐨勬椂闂达紙灏忔椂锛�0-23锛�: " hour
			  (crontab -l ; echo "0 $hour * * * ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
			  ;;
		  *)
			  break  # 璺冲嚭
			  ;;
	  esac

	  install sshpass

	  ;;

	34)
	  root_use
	  send_stats "LDNMP鐜杩樺師"
	  echo "鍙敤鐨勭珯鐐瑰浠�"
	  echo "-------------------------"
	  ls -lt /home/*.gz | awk '{print $NF}'
	  echo ""
	  read -e -p  "鍥炶溅閿繕鍘熸渶鏂扮殑澶囦唤锛岃緭鍏ュ浠芥枃浠跺悕杩樺師鎸囧畾鐨勫浠斤紝杈撳叆0閫€鍑猴細" filename

	  if [ "$filename" == "0" ]; then
		  break_end
		  linux_ldnmp
	  fi

	  # 濡傛灉鐢ㄦ埛娌℃湁杈撳叆鏂囦欢鍚嶏紝浣跨敤鏈€鏂扮殑鍘嬬缉鍖�
	  if [ -z "$filename" ]; then
		  local filename=$(ls -t /home/*.tar.gz | head -1)
	  fi

	  if [ -n "$filename" ]; then
		  cd /home/web/ > /dev/null 2>&1
		  docker compose down > /dev/null 2>&1
		  rm -rf /home/web > /dev/null 2>&1

		  echo -e "${gl_huang}姝ｅ湪瑙ｅ帇 $filename ...${gl_bai}"
		  cd /home/ && tar -xzf "$filename"

		  check_port
		  install_dependency
		  install_docker
		  install_certbot
		  install_ldnmp
	  else
		  echo "娌℃湁鎵惧埌鍘嬬缉鍖呫€�"
	  fi

	  ;;

	35)
	  send_stats "LDNMP鐜闃插尽"
	  while true; do
		check_waf_status
		check_cf_mode
		if docker inspect fail2ban &>/dev/null ; then
			  clear
			  echo -e "鏈嶅姟鍣ㄩ槻寰＄▼搴忓凡鍚姩 ${gl_lv}${CFmessage} ${waf_status}${gl_bai}"
			  echo "------------------------"
			  echo "1. 寮€鍚疭SH闃叉毚鍔涚牬瑙�              2. 鍏抽棴SSH闃叉毚鍔涚牬瑙�"
			  echo "3. 寮€鍚綉绔欎繚鎶�                   4. 鍏抽棴缃戠珯淇濇姢"
			  echo "------------------------"
			  echo "5. 鏌ョ湅SSH鎷︽埅璁板綍                6. 鏌ョ湅缃戠珯鎷︽埅璁板綍"
			  echo "7. 鏌ョ湅闃插尽瑙勫垯鍒楄〃               8. 鏌ョ湅鏃ュ織瀹炴椂鐩戞帶"
			  echo "------------------------"
			  echo "11. 閰嶇疆鎷︽埅鍙傛暟"
			  echo "------------------------"
			  echo "21. cloudflare妯″紡                22. 楂樿礋杞藉紑鍚�5绉掔浘"
			  echo "------------------------"
			  echo "31. 寮€鍚疻AF                       32. 鍏抽棴WAF"
			  echo "------------------------"
			  echo "9. 鍗歌浇闃插尽绋嬪簭"
			  echo "------------------------"
			  echo "0. 閫€鍑�"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
			  case $sub_choice in
				  1)
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
					  f2b_status
					  ;;
				  2)
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
					  f2b_status
					  ;;
				  3)
					  sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  ;;
				  4)
					  sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status
					  ;;
				  5)
					  echo "------------------------"
					  f2b_sshd
					  echo "------------------------"
					  ;;
				  6)

					  echo "------------------------"
					  local xxx="fail2ban-nginx-cc"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="docker-nginx-bad-request"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="docker-nginx-botsearch"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="docker-nginx-http-auth"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="docker-nginx-limit-req"
					  f2b_status_xxx
					  echo "------------------------"
					  local xxx="docker-php-url-fopen"
					  f2b_status_xxx
					  echo "------------------------"

					  ;;

				  7)
					  docker exec -it fail2ban fail2ban-client status
					  ;;
				  8)
					  tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log

					  ;;
				  9)
					  docker rm -f fail2ban
					  rm -rf /path/to/fail2ban
					  crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
					  echo "Fail2Ban闃插尽绋嬪簭宸插嵏杞�"
					  break
					  ;;

				  11)
					  install nano
					  nano /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
					  f2b_status

					  break
					  ;;
				  21)
					  send_stats "cloudflare妯″紡"
					  echo "鍒癱f鍚庡彴鍙充笂瑙掓垜鐨勪釜浜鸿祫鏂欙紝閫夋嫨宸︿晶API浠ょ墝锛岃幏鍙朑lobal API Key"
					  echo "https://dash.cloudflare.com/login"
					  read -e -p "杈撳叆CF鐨勮处鍙�: " cfuser
					  read -e -p "杈撳叆CF鐨凣lobal API Key: " cftoken

					  wget -O /home/web/conf.d/default.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/nginx/main/default11.conf
					  docker restart nginx

					  cd /path/to/fail2ban/config/fail2ban/jail.d/
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf

					  cd /path/to/fail2ban/config/fail2ban/action.d
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/cloudflare-docker.conf

					  sed -i "s/kejilion@outlook.com/$cfuser/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
					  sed -i "s/APIKEY00000/$cftoken/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
					  f2b_status

					  echo "宸查厤缃甤loudflare妯″紡锛屽彲鍦╟f鍚庡彴锛岀珯鐐�-瀹夊叏鎬�-浜嬩欢涓煡鐪嬫嫤鎴褰�"
					  ;;

				  22)
					  send_stats "楂樿礋杞藉紑鍚�5绉掔浘"
					  echo -e "${gl_huang}缃戠珯姣�5鍒嗛挓鑷姩妫€娴嬶紝褰撹揪妫€娴嬪埌楂樿礋杞戒細鑷姩寮€鐩撅紝浣庤礋杞戒篃浼氳嚜鍔ㄥ叧闂�5绉掔浘銆�${gl_bai}"
					  echo "--------------"
					  echo "鑾峰彇CF鍙傛暟: "
					  echo -e "鍒癱f鍚庡彴鍙充笂瑙掓垜鐨勪釜浜鸿祫鏂欙紝閫夋嫨宸︿晶API浠ょ墝锛岃幏鍙�${gl_huang}Global API Key${gl_bai}"
					  echo -e "鍒癱f鍚庡彴鍩熷悕姒傝椤甸潰鍙充笅鏂硅幏鍙�${gl_huang}鍖哄煙ID${gl_bai}"
					  echo "https://dash.cloudflare.com/login"
					  echo "--------------"
					  read -e -p "杈撳叆CF鐨勮处鍙�: " cfuser
					  read -e -p "杈撳叆CF鐨凣lobal API Key: " cftoken
					  read -e -p "杈撳叆CF涓煙鍚嶇殑鍖哄煙ID: " cfzonID

					  cd ~
					  install jq bc
					  check_crontab_installed
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
					  chmod +x CF-Under-Attack.sh
					  sed -i "s/AAAA/$cfuser/g" ~/CF-Under-Attack.sh
					  sed -i "s/BBBB/$cftoken/g" ~/CF-Under-Attack.sh
					  sed -i "s/CCCC/$cfzonID/g" ~/CF-Under-Attack.sh

					  local cron_job="*/5 * * * * ~/CF-Under-Attack.sh"

					  local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

					  if [ -z "$existing_cron" ]; then
						  (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
						  echo "楂樿礋杞借嚜鍔ㄥ紑鐩捐剼鏈凡娣诲姞"
					  else
						  echo "鑷姩寮€鐩捐剼鏈凡瀛樺湪锛屾棤闇€娣诲姞"
					  fi

					  ;;

				  31)
					  nginx_waf on
					  echo "绔欑偣WAF宸插紑鍚�"
					  send_stats "绔欑偣WAF宸插紑鍚�"
					  ;;

				  32)
				  	  nginx_waf off
					  echo "绔欑偣WAF宸插叧闂�"
					  send_stats "绔欑偣WAF宸插叧闂�"
					  ;;

				  0)
					  break
					  ;;
				  *)
					  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
					  ;;
			  esac
		elif [ -x "$(command -v fail2ban-client)" ] ; then
			clear
			echo "鍗歌浇鏃х増fail2ban"
			read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice
			case "$choice" in
			  [Yy])
				remove fail2ban
				rm -rf /etc/fail2ban
				echo "Fail2Ban闃插尽绋嬪簭宸插嵏杞�"
				;;
			  [Nn])
				echo "宸插彇娑�"
				;;
			  *)
				echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				;;
			esac

		else
			clear
			f2b_install_sshd
			cd /path/to/fail2ban/config/fail2ban/filter.d
			curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/fail2ban-nginx-cc.conf
			cd /path/to/fail2ban/config/fail2ban/jail.d/
			curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/config/main/fail2ban/nginx-docker-cc.conf
			sed -i "/cloudflare/d" /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
			f2b_status
			cd ~
			echo "闃插尽绋嬪簭宸插紑鍚�"
		fi
	  break_end
	  done

		;;

	36)
		  while true; do
			  clear
			  send_stats "浼樺寲LDNMP鐜"
			  echo "浼樺寲LDNMP鐜"
			  echo "------------------------"
			  echo "1. 鏍囧噯妯″紡              2. 楂樻€ц兘妯″紡 (鎺ㄨ崘2H2G浠ヤ笂)"
			  echo "------------------------"
			  echo "0. 閫€鍑�"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
			  case $sub_choice in
				  1)
				  send_stats "绔欑偣鏍囧噯妯″紡"
				  # nginx璋冧紭
				  sed -i 's/worker_connections.*/worker_connections 10240;/' /home/web/nginx.conf
				  sed -i 's/worker_processes.*/worker_processes 4;/' /home/web/nginx.conf

				  # php璋冧紭
				  wget -O /home/optimized_php.ini ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php璋冧紭
				  wget -O /home/www.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/www-1.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  # mysql璋冧紭
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf


				  cd /home/web && docker compose restart

				  restart_redis
				  optimize_balanced

				  echo "LDNMP鐜宸茶缃垚 鏍囧噯妯″紡"

					  ;;
				  2)
				  send_stats "绔欑偣楂樻€ц兘妯″紡"
				  # nginx璋冧紭
				  sed -i 's/worker_connections.*/worker_connections 20480;/' /home/web/nginx.conf
				  sed -i 's/worker_processes.*/worker_processes 8;/' /home/web/nginx.conf

				  # php璋冧紭
				  wget -O /home/optimized_php.ini ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
				  docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
				  docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
				  rm -rf /home/optimized_php.ini

				  # php璋冧紭
				  wget -O /home/www.conf ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/www.conf
				  docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
				  docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
				  rm -rf /home/www.conf

				  # mysql璋冧紭
				  wget -O /home/custom_mysql_config.cnf ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config.cnf
				  docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
				  rm -rf /home/custom_mysql_config.cnf

				  cd /home/web && docker compose restart

				  restart_redis
				  optimize_web_server

				  echo "LDNMP鐜宸茶缃垚 楂樻€ц兘妯″紡"

					  ;;
				  0)
					  break
					  ;;
				  *)
					  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
					  ;;
			  esac
			  break_end

		  done
		;;


	37)
	  root_use
	  while true; do
		  clear
		  send_stats "鏇存柊LDNMP鐜"
		  echo "鏇存柊LDNMP鐜"
		  echo "------------------------"
		  ldnmp_v
		  echo "1. 鏇存柊nginx               2. 鏇存柊mysql              3. 鏇存柊php              4. 鏇存柊redis"
		  echo "------------------------"
		  echo "5. 鏇存柊瀹屾暣鐜"
		  echo "------------------------"
		  echo "0. 杩斿洖涓婁竴绾�"
		  echo "------------------------"
		  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
		  case $sub_choice in
			  1)
			  nginx_upgrade

				  ;;

			  2)
			  local ldnmp_pods="mysql"
			  read -e -p "璇疯緭鍏�${ldnmp_pods}鐗堟湰鍙� 锛堝: 8.0 8.3 8.4 9.0锛夛紙鍥炶溅鑾峰彇鏈€鏂扮増锛�: " version
			  local version=${version:-latest}

			  cd /home/web/
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  sed -i "s/image: mysql/image: mysql:${version}/" /home/web/docker-compose.yml
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  docker restart $ldnmp_pods
			  cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
			  send_stats "鏇存柊$ldnmp_pods"
			  echo "鏇存柊${ldnmp_pods}瀹屾垚"

				  ;;
			  3)
			  local ldnmp_pods="php"
			  read -e -p "璇疯緭鍏�${ldnmp_pods}鐗堟湰鍙� 锛堝: 7.4 8.0 8.1 8.2 8.3锛夛紙鍥炶溅鑾峰彇鏈€鏂扮増锛�: " version
			  local version=${version:-8.3}
			  cd /home/web/
			  cp /home/web/docker-compose.yml /home/web/docker-compose1.yml
			  sed -i "s/kjlion\///g" /home/web/docker-compose.yml > /dev/null 2>&1
			  sed -i "s/image: php:fpm-alpine/image: php:${version}-fpm-alpine/" /home/web/docker-compose.yml
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
  			  docker images --filter=reference="kjlion/${ldnmp_pods}*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  docker exec php chown -R www-data:www-data /var/www/html

			  run_command docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories > /dev/null 2>&1

			  docker exec php apk update
			  curl -sL ${gh_proxy}https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions
			  docker exec php mkdir -p /usr/local/bin/
			  docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/
			  docker exec php chmod +x /usr/local/bin/install-php-extensions

			  docker exec php sh -c "\
							apk add --no-cache imagemagick imagemagick-dev \
							&& apk add --no-cache git autoconf gcc g++ make pkgconfig \
							&& rm -rf /tmp/imagick \
							&& git clone ${gh_proxy}https://github.com/Imagick/imagick /tmp/imagick \
							&& cd /tmp/imagick \
							&& phpize \
							&& ./configure \
							&& make \
							&& make install \
							&& echo 'extension=imagick.so' > /usr/local/etc/php/conf.d/imagick.ini \
							&& rm -rf /tmp/imagick"


			  docker exec php install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis


			  docker exec php sh -c 'echo "upload_max_filesize=50M " > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "post_max_size=50M " > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1
			  docker exec php sh -c 'echo "max_input_vars=3000" > /usr/local/etc/php/conf.d/max_input_vars.ini' > /dev/null 2>&1


			  docker restart $ldnmp_pods > /dev/null 2>&1
			  cp /home/web/docker-compose1.yml /home/web/docker-compose.yml
			  send_stats "鏇存柊$ldnmp_pods"
			  echo "鏇存柊${ldnmp_pods}瀹屾垚"

				  ;;
			  4)
			  local ldnmp_pods="redis"
			  cd /home/web/
			  docker rm -f $ldnmp_pods
			  docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi > /dev/null 2>&1
			  docker compose up -d --force-recreate $ldnmp_pods
			  restart_redis
			  docker restart $ldnmp_pods > /dev/null 2>&1
			  send_stats "鏇存柊$ldnmp_pods"
			  echo "鏇存柊${ldnmp_pods}瀹屾垚"

				  ;;
			  5)
				read -e -p "$(echo -e "${gl_huang}鎻愮ず: ${gl_bai}闀挎椂闂翠笉鏇存柊鐜鐨勭敤鎴凤紝璇锋厧閲嶆洿鏂癓DNMP鐜锛屼細鏈夋暟鎹簱鏇存柊澶辫触鐨勯闄┿€傜‘瀹氭洿鏂癓DNMP鐜鍚楋紵(Y/N): ")" choice
				case "$choice" in
				  [Yy])
					send_stats "瀹屾暣鏇存柊LDNMP鐜"
					cd /home/web/
					docker compose down
					docker compose down --rmi all

					check_port
					install_dependency
					install_docker
					install_certbot
					install_ldnmp
					;;
				  *)
					;;
				esac
				  ;;
			  0)
				  break
				  ;;
			  *)
				  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
				  ;;
		  esac
		  break_end
	  done


	  ;;

	38)
		root_use
		send_stats "鍗歌浇LDNMP鐜"
		read -e -p "$(echo -e "${gl_hong}寮虹儓寤鸿锛�${gl_bai}鍏堝浠藉叏閮ㄧ綉绔欐暟鎹紝鍐嶅嵏杞絃DNMP鐜銆傜‘瀹氬垹闄ゆ墍鏈夌綉绔欐暟鎹悧锛�(Y/N): ")" choice
		case "$choice" in
		  [Yy])
			cd /home/web/
			docker compose down
			docker compose down --rmi all
			docker compose -f docker-compose.phpmyadmin.yml down > /dev/null 2>&1
			docker compose -f docker-compose.phpmyadmin.yml down --rmi all > /dev/null 2>&1
			rm -rf /home/web
			;;
		  [Nn])

			;;
		  *)
			echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
			;;
		esac
		;;

	0)
		kejilion
	  ;;

	*)
		echo "鏃犳晥鐨勮緭鍏�!"
	esac
	break_end

  done

}



linux_panel() {

	while true; do
	  clear
	  # send_stats "搴旂敤甯傚満"
	  echo -e "鈻� 搴旂敤甯傚満"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}瀹濆闈㈡澘瀹樻柟鐗�                      ${gl_kjlan}2.   ${gl_bai}aaPanel瀹濆鍥介檯鐗�"
	  echo -e "${gl_kjlan}3.   ${gl_bai}1Panel鏂颁竴浠ｇ鐞嗛潰鏉�                ${gl_kjlan}4.   ${gl_bai}NginxProxyManager鍙鍖栭潰鏉�"
	  echo -e "${gl_kjlan}5.   ${gl_bai}AList澶氬瓨鍌ㄦ枃浠跺垪琛ㄧ▼搴�             ${gl_kjlan}6.   ${gl_bai}Ubuntu杩滅▼妗岄潰缃戦〉鐗�"
	  echo -e "${gl_kjlan}7.   ${gl_bai}鍝悞鎺㈤拡VPS鐩戞帶闈㈡澘                 ${gl_kjlan}8.   ${gl_bai}QB绂荤嚎BT纾佸姏涓嬭浇闈㈡澘"
	  echo -e "${gl_kjlan}9.   ${gl_bai}Poste.io閭欢鏈嶅姟鍣ㄧ▼搴�              ${gl_kjlan}10.  ${gl_bai}RocketChat澶氫汉鍦ㄧ嚎鑱婂ぉ绯荤粺"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}绂呴亾椤圭洰绠＄悊杞欢                    ${gl_kjlan}12.  ${gl_bai}闈掗緳闈㈡澘瀹氭椂浠诲姟绠＄悊骞冲彴"
	  echo -e "${gl_kjlan}13.  ${gl_bai}Cloudreve缃戠洏 ${gl_huang}鈽�${gl_bai}                     ${gl_kjlan}14.  ${gl_bai}绠€鍗曞浘搴婂浘鐗囩鐞嗙▼搴�"
	  echo -e "${gl_kjlan}15.  ${gl_bai}emby澶氬獟浣撶鐞嗙郴缁�                  ${gl_kjlan}16.  ${gl_bai}Speedtest娴嬮€熼潰鏉�"
	  echo -e "${gl_kjlan}17.  ${gl_bai}AdGuardHome鍘诲箍鍛婅蒋浠�               ${gl_kjlan}18.  ${gl_bai}onlyoffice鍦ㄧ嚎鍔炲叕OFFICE"
	  echo -e "${gl_kjlan}19.  ${gl_bai}闆锋睜WAF闃茬伀澧欓潰鏉�                   ${gl_kjlan}20.  ${gl_bai}portainer瀹瑰櫒绠＄悊闈㈡澘"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}21.  ${gl_bai}VScode缃戦〉鐗�                        ${gl_kjlan}22.  ${gl_bai}UptimeKuma鐩戞帶宸ュ叿"
	  echo -e "${gl_kjlan}23.  ${gl_bai}Memos缃戦〉澶囧繕褰�                     ${gl_kjlan}24.  ${gl_bai}Webtop杩滅▼妗岄潰缃戦〉鐗� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}25.  ${gl_bai}Nextcloud缃戠洏                       ${gl_kjlan}26.  ${gl_bai}QD-Today瀹氭椂浠诲姟绠＄悊妗嗘灦"
	  echo -e "${gl_kjlan}27.  ${gl_bai}Dockge瀹瑰櫒鍫嗘爤绠＄悊闈㈡澘              ${gl_kjlan}28.  ${gl_bai}LibreSpeed娴嬮€熷伐鍏�"
	  echo -e "${gl_kjlan}29.  ${gl_bai}searxng鑱氬悎鎼滅储绔� ${gl_huang}鈽�${gl_bai}                 ${gl_kjlan}30.  ${gl_bai}PhotoPrism绉佹湁鐩稿唽绯荤粺"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}31.  ${gl_bai}StirlingPDF宸ュ叿澶у叏                 ${gl_kjlan}32.  ${gl_bai}drawio鍏嶈垂鐨勫湪绾垮浘琛ㄨ蒋浠� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}33.  ${gl_bai}Sun-Panel瀵艰埅闈㈡澘                   ${gl_kjlan}34.  ${gl_bai}Pingvin-Share鏂囦欢鍒嗕韩骞冲彴"
	  echo -e "${gl_kjlan}35.  ${gl_bai}鏋佺畝鏈嬪弸鍦�                          ${gl_kjlan}36.  ${gl_bai}LobeChatAI鑱婂ぉ鑱氬悎缃戠珯"
	  echo -e "${gl_kjlan}37.  ${gl_bai}MyIP宸ュ叿绠� ${gl_huang}鈽�${gl_bai}                        ${gl_kjlan}38.  ${gl_bai}灏忛泤alist鍏ㄥ妗�"
	  echo -e "${gl_kjlan}39.  ${gl_bai}Bililive鐩存挱褰曞埗宸ュ叿                ${gl_kjlan}40.  ${gl_bai}webssh缃戦〉鐗圫SH杩炴帴宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}41.  ${gl_bai}鑰楀瓙绠＄悊闈㈡澘                	 ${gl_kjlan}42.  ${gl_bai}Nexterm杩滅▼杩炴帴宸ュ叿"
	  echo -e "${gl_kjlan}43.  ${gl_bai}RustDesk杩滅▼妗岄潰(鏈嶅姟绔�)            ${gl_kjlan}44.  ${gl_bai}RustDesk杩滅▼妗岄潰(涓户绔�)"
	  echo -e "${gl_kjlan}45.  ${gl_bai}Docker鍔犻€熺珯            		 ${gl_kjlan}46.  ${gl_bai}GitHub鍔犻€熺珯"
	  echo -e "${gl_kjlan}47.  ${gl_bai}鏅綏绫充慨鏂洃鎺�			 ${gl_kjlan}48.  ${gl_bai}鏅綏绫充慨鏂�(涓绘満鐩戞帶)"
	  echo -e "${gl_kjlan}49.  ${gl_bai}鏅綏绫充慨鏂�(瀹瑰櫒鐩戞帶)		 ${gl_kjlan}50.  ${gl_bai}琛ヨ揣鐩戞帶宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}51.  ${gl_bai}PVE寮€灏忛浮闈㈡澘"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)

			local lujing="[ -d "/www/server/panel" ]"
			local panelname="瀹濆闈㈡澘"

			local gongneng1="bt"
			local gongneng1_1=""
			local gongneng2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
			local gongneng2_1="chmod +x bt-uninstall.sh"
			local gongneng2_2="./bt-uninstall.sh"

			local panelurl="https://www.bt.cn/new/index.html"


			local centos_mingling="wget -O install.sh https://download.bt.cn/install/install_6.0.sh"
			local centos_mingling2="sh install.sh ed8484bec"

			local ubuntu_mingling="wget -O install.sh https://download.bt.cn/install/install-ubuntu_6.0.sh"
			local ubuntu_mingling2="bash install.sh ed8484bec"

			install_panel



			  ;;
		  2)

			local lujing="[ -d "/www/server/panel" ]"
			local panelname="aapanel"

			local gongneng1="bt"
			local gongneng1_1=""
			local gongneng2="curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh > /dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh"
			local gongneng2_1="chmod +x bt-uninstall.sh"
			local gongneng2_2="./bt-uninstall.sh"

			local panelurl="https://www.aapanel.com/new/index.html"

			local centos_mingling="wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh"
			local centos_mingling2="bash install.sh aapanel"

			local ubuntu_mingling="wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
			local ubuntu_mingling2="bash install.sh aapanel"

			install_panel

			  ;;
		  3)

			local lujing="command -v 1pctl > /dev/null 2>&1 "
			local panelname="1Panel"

			local gongneng1="1pctl user-info"
			local gongneng1_1="1pctl update password"
			local gongneng2="1pctl uninstall"
			local gongneng2_1=""
			local gongneng2_2=""

			local panelurl="https://1panel.cn/"


			local centos_mingling="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
			local centos_mingling2="sh quick_start.sh"

			local ubuntu_mingling="curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh"
			local ubuntu_mingling2="bash quick_start.sh"

			install_panel

			  ;;
		  4)

			local docker_name="npm"
			local docker_img="jc21/nginx-proxy-manager:latest"
			local docker_port=81
			local docker_rum="docker run -d \
						  --name=$docker_name \
						  -p 80:80 \
						  -p 81:$docker_port \
						  -p 443:443 \
						  -v /home/docker/npm/data:/data \
						  -v /home/docker/npm/letsencrypt:/etc/letsencrypt \
						  --restart=always \
						  $docker_img"
			local docker_describe="濡傛灉鎮ㄥ凡缁忓畨瑁呬簡鍏朵粬闈㈡澘鎴栬€匧DNMP寤虹珯鐜锛屽缓璁厛鍗歌浇锛屽啀瀹夎npm锛�"
			local docker_url="瀹樼綉浠嬬粛: https://nginxproxymanager.com/"
			local docker_use="echo \"鍒濆鐢ㄦ埛鍚�: admin@example.com\""
			local docker_passwd="echo \"鍒濆瀵嗙爜: changeme\""

			docker_app

			  ;;

		  5)

			local docker_name="alist"
			local docker_img="xhofe/alist-aria2:latest"
			local docker_port=5244
			local docker_rum="docker run -d \
								--restart=always \
								-v /home/docker/alist:/opt/alist/data \
								-p 5244:5244 \
								-e PUID=0 \
								-e PGID=0 \
								-e UMASK=022 \
								--name="alist" \
								xhofe/alist-aria2:latest"
			local docker_describe="涓€涓敮鎸佸绉嶅瓨鍌紝鏀寔缃戦〉娴忚鍜� WebDAV 鐨勬枃浠跺垪琛ㄧ▼搴忥紝鐢� gin 鍜� Solidjs 椹卞姩"
			local docker_url="瀹樼綉浠嬬粛: https://alist.nn.ci/zh/"
			local docker_use="docker exec -it alist ./alist admin random"
			local docker_passwd=""

			docker_app

			  ;;

		  6)

			local docker_name="webtop-ubuntu"
			local docker_img="lscr.io/linuxserver/webtop:ubuntu-kde"
			local docker_port=3006
			local docker_rum="docker run -d \
						  --name=webtop-ubuntu \
						  --security-opt seccomp=unconfined \
						  -e PUID=1000 \
						  -e PGID=1000 \
						  -e TZ=Etc/UTC \
						  -e SUBFOLDER=/ \
						  -e TITLE=Webtop \
						  -p 3006:3000 \
						  -v /home/docker/webtop/data:/config \
						  -v /var/run/docker.sock:/var/run/docker.sock \
						  --shm-size="1gb" \
						  --restart unless-stopped \
						  lscr.io/linuxserver/webtop:ubuntu-kde"

			local docker_describe="webtop鍩轰簬Ubuntu鐨勫鍣紝鍖呭惈瀹樻柟鏀寔鐨勫畬鏁存闈㈢幆澧冿紝鍙€氳繃浠讳綍鐜颁唬 Web 娴忚鍣ㄨ闂�"
			local docker_url="瀹樼綉浠嬬粛: https://docs.linuxserver.io/images/docker-webtop/"
			local docker_use=""
			local docker_passwd=""
			docker_app


			  ;;
		  7)
			clear
			send_stats "鎼缓鍝悞"
			while true; do
				clear
				echo "鍝悞鐩戞帶绠＄悊"
				echo "寮€婧愩€佽交閲忋€佹槗鐢ㄧ殑鏈嶅姟鍣ㄧ洃鎺т笌杩愮淮宸ュ叿"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"
				echo "------------------------"
				echo "1. 浣跨敤           0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						curl -L ${gh_proxy}https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh
						./nezha.sh
						;;
					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done
			  ;;

		  8)

			local docker_name="qbittorrent"
			local docker_img="lscr.io/linuxserver/qbittorrent:latest"
			local docker_port=8081
			local docker_rum="docker run -d \
								  --name=qbittorrent \
								  -e PUID=1000 \
								  -e PGID=1000 \
								  -e TZ=Etc/UTC \
								  -e WEBUI_PORT=8081 \
								  -p 8081:8081 \
								  -p 6881:6881 \
								  -p 6881:6881/udp \
								  -v /home/docker/qbittorrent/config:/config \
								  -v /home/docker/qbittorrent/downloads:/downloads \
								  --restart unless-stopped \
								  lscr.io/linuxserver/qbittorrent:latest"
			local docker_describe="qbittorrent绂荤嚎BT纾佸姏涓嬭浇鏈嶅姟"
			local docker_url="瀹樼綉浠嬬粛: https://hub.docker.com/r/linuxserver/qbittorrent"
			local docker_use="sleep 3"
			local docker_passwd="docker logs qbittorrent"

			docker_app

			  ;;

		  9)
			send_stats "鎼缓閭眬"
			clear
			install telnet
			local docker_name=鈥渕ailserver鈥�
			while true; do
				check_docker_app

				clear
				echo -e "閭眬鏈嶅姟 $check_docker"
				echo "poste.io 鏄竴涓紑婧愮殑閭欢鏈嶅姟鍣ㄨВ鍐虫柟妗堬紝"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"

				echo ""
				echo "绔彛妫€娴�"
				port=25
				timeout=3
				if echo "quit" | timeout $timeout telnet smtp.qq.com $port | grep 'Connected'; then
				  echo -e "${gl_lv}绔彛 $port 褰撳墠鍙敤${gl_bai}"
				else
				  echo -e "${gl_hong}绔彛 $port 褰撳墠涓嶅彲鐢�${gl_bai}"
				fi
				echo ""

				if docker inspect "$docker_name" &>/dev/null; then
					yuming=$(cat /home/docker/mail.txt)
					echo "璁块棶鍦板潃: "
					echo "https://$yuming"
				fi

				echo "------------------------"
				echo "1. 瀹夎           2. 鏇存柊           3. 鍗歌浇"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						read -e -p "璇疯缃偖绠卞煙鍚� 渚嬪 mail.yuming.com : " yuming
						mkdir -p /home/docker
						echo "$yuming" > /home/docker/mail.txt
						echo "------------------------"
						ip_address
						echo "鍏堣В鏋愯繖浜汥NS璁板綍"
						echo "A           mail            $ipv4_address"
						echo "CNAME       imap            $yuming"
						echo "CNAME       pop             $yuming"
						echo "CNAME       smtp            $yuming"
						echo "MX          @               $yuming"
						echo "TXT         @               v=spf1 mx ~all"
						echo "TXT         ?               ?"
						echo ""
						echo "------------------------"
						echo "鎸変换鎰忛敭缁х画..."
						read -n 1 -s -r -p ""

						install_docker

						docker run \
							--net=host \
							-e TZ=Europe/Prague \
							-v /home/docker/mail:/data \
							--name "mailserver" \
							-h "$yuming" \
							--restart=always \
							-d analogic/poste.io

						clear
						echo "poste.io宸茬粡瀹夎瀹屾垚"
						echo "------------------------"
						echo "鎮ㄥ彲浠ヤ娇鐢ㄤ互涓嬪湴鍧€璁块棶poste.io:"
						echo "https://$yuming"
						echo ""

						;;

					2)
						docker rm -f mailserver
						docker rmi -f analogic/poste.i
						yuming=$(cat /home/docker/mail.txt)
						docker run \
							--net=host \
							-e TZ=Europe/Prague \
							-v /home/docker/mail:/data \
							--name "mailserver" \
							-h "$yuming" \
							--restart=always \
							-d analogic/poste.i
						clear
						echo "poste.io宸茬粡瀹夎瀹屾垚"
						echo "------------------------"
						echo "鎮ㄥ彲浠ヤ娇鐢ㄤ互涓嬪湴鍧€璁块棶poste.io:"
						echo "https://$yuming"
						echo ""
						;;
					3)
						docker rm -f mailserver
						docker rmi -f analogic/poste.io
						rm /home/docker/mail.txt
						rm -rf /home/docker/mail
						echo "搴旂敤宸插嵏杞�"
						;;

					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done

			  ;;

		  10)
			send_stats "鎼缓鑱婂ぉ"

			local docker_name=rocketchat
			local docker_port=3897
			while true; do
				check_docker_app
				clear
				echo -e "鑱婂ぉ鏈嶅姟 $check_docker"
				echo "Rocket.Chat 鏄竴涓紑婧愮殑鍥㈤槦閫氳骞冲彴锛屾敮鎸佸疄鏃惰亰澶┿€侀煶瑙嗛閫氳瘽銆佹枃浠跺叡浜瓑澶氱鍔熻兘锛�"
				echo "瀹樼綉浠嬬粛: https://www.rocket.chat"
				if docker inspect "$docker_name" &>/dev/null; then
					check_docker_app_ip
				fi
				echo ""

				echo "------------------------"
				echo "1. 瀹夎           2. 鏇存柊           3. 鍗歌浇"
				echo "------------------------"
				echo "5. 鍩熷悕璁块棶"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						install_docker
						docker run --name db -d --restart=always \
							-v /home/docker/mongo/dump:/dump \
							mongo:latest --replSet rs5 --oplogSize 256
						sleep 1
						docker exec -it db mongosh --eval "printjson(rs.initiate())"
						sleep 5
						docker run --name rocketchat --restart=always -p 3897:3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat

						clear

						ip_address
						echo "rocket.chat宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						echo ""

						;;

					2)
						docker rm -f rocketchat
						docker rmi -f rocket.chat:6.3
						docker run --name rocketchat --restart=always -p 3897:3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat
						clear
						ip_address
						echo "rocket.chat宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						echo ""
						;;
					3)
						docker rm -f rocketchat
						docker rmi -f rocket.chat
						docker rm -f db
						docker rmi -f mongo:latest
						rm -rf /home/docker/mongo
						echo "搴旂敤宸插嵏杞�"

						;;
					5)
						echo "${docker_name}鍩熷悕璁块棶璁剧疆"
						send_stats "${docker_name}鍩熷悕璁块棶璁剧疆"
						add_yuming
						ldnmp_Proxy ${yuming} ${ipv4_address} ${docker_port}
						;;

					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done
			  ;;



		  11)
			local docker_name="zentao-server"
			local docker_img="idoop/zentao:latest"
			local docker_port=82
			local docker_rum="docker run -d -p 82:80 -p 3308:3306 \
							  -e ADMINER_USER="root" -e ADMINER_PASSWD="password" \
							  -e BIND_ADDRESS="false" \
							  -v /home/docker/zentao-server/:/opt/zbox/ \
							  --add-host smtp.exmail.qq.com:163.177.90.125 \
							  --name zentao-server \
							  --restart=always \
							  idoop/zentao:latest"
			local docker_describe="绂呴亾鏄€氱敤鐨勯」鐩鐞嗚蒋浠�"
			local docker_url="瀹樼綉浠嬬粛: https://www.zentao.net/"
			local docker_use="echo \"鍒濆鐢ㄦ埛鍚�: admin\""
			local docker_passwd="echo \"鍒濆瀵嗙爜: 123456\""
			docker_app

			  ;;

		  12)
			local docker_name="qinglong"
			local docker_img="whyour/qinglong:latest"
			local docker_port=5700
			local docker_rum="docker run -d \
					  -v /home/docker/qinglong/data:/ql/data \
					  -p 5700:5700 \
					  --name qinglong \
					  --hostname qinglong \
					  --restart unless-stopped \
					  whyour/qinglong:latest"
			local docker_describe="闈掗緳闈㈡澘鏄竴涓畾鏃朵换鍔＄鐞嗗钩鍙�"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/whyour/qinglong"
			local docker_use=""
			local docker_passwd=""
			docker_app

			  ;;
		  13)
			send_stats "鎼缓缃戠洏"


			local docker_name=cloudreve
			local docker_port=5212
			while true; do
				check_docker_app
				clear
				echo -e "缃戠洏鏈嶅姟 $check_docker"
				echo "cloudreve鏄竴涓敮鎸佸瀹朵簯瀛樺偍鐨勭綉鐩樼郴缁�"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV13F4m1c7h7?t=0.1"
				if docker inspect "$docker_name" &>/dev/null; then
					check_docker_app_ip
				fi
				echo ""

				echo "------------------------"
				echo "1. 瀹夎           2. 鏇存柊           3. 鍗歌浇"
				echo "------------------------"
				echo "5. 鍩熷悕璁块棶"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						install_docker
						cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
						curl -o /home/docker/cloud/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/kejilion/docker/main/cloudreve-docker-compose.yml
						cd /home/docker/cloud/ && docker compose up -d

						clear
						echo "cloudreve宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						sleep 3
						docker logs cloudreve
						echo ""


						;;

					2)
						docker rm -f cloudreve
						docker rmi -f cloudreve/cloudreve:latest
						docker rm -f aria2
						docker rmi -f p3terx/aria2-pro
						cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
						curl -o /home/docker/cloud/docker-compose.yml ${gh_proxy}https://raw.githubusercontent.com/kejilion/docker/main/cloudreve-docker-compose.yml
						cd /home/docker/cloud/ && docker compose up -d
						clear
						echo "cloudreve宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						sleep 3
						docker logs cloudreve
						echo ""
						;;
					3)

						docker rm -f cloudreve
						docker rmi -f cloudreve/cloudreve:latest
						docker rm -f aria2
						docker rmi -f p3terx/aria2-pro
						rm -rf /home/docker/cloud
						echo "搴旂敤宸插嵏杞�"

						;;
					5)
						echo "${docker_name}鍩熷悕璁块棶璁剧疆"
						send_stats "${docker_name}鍩熷悕璁块棶璁剧疆"
						add_yuming
						ldnmp_Proxy ${yuming} ${ipv4_address} ${docker_port}
						;;

					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done
			  ;;

		  14)
			local docker_name="easyimage"
			local docker_img="ddsderek/easyimage:latest"
			local docker_port=85
			local docker_rum="docker run -d \
					  --name easyimage \
					  -p 85:80 \
					  -e TZ=Asia/Shanghai \
					  -e PUID=1000 \
					  -e PGID=1000 \
					  -v /home/docker/easyimage/config:/app/web/config \
					  -v /home/docker/easyimage/i:/app/web/i \
					  --restart unless-stopped \
					  ddsderek/easyimage:latest"
			local docker_describe="绠€鍗曞浘搴婃槸涓€涓畝鍗曠殑鍥惧簥绋嬪簭"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/icret/EasyImages2.0"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  15)
			local docker_name="emby"
			local docker_img="linuxserver/emby:latest"
			local docker_port=8096
			local docker_rum="docker run -d --name=emby --restart=always \
						-v /home/docker/emby/config:/config \
						-v /home/docker/emby/share1:/mnt/share1 \
						-v /home/docker/emby/share2:/mnt/share2 \
						-v /mnt/notify:/mnt/notify \
						-p 8096:8096 -p 8920:8920 \
						-e UID=1000 -e GID=100 -e GIDLIST=100 \
						linuxserver/emby:latest"
			local docker_describe="emby鏄竴涓富浠庡紡鏋舵瀯鐨勫獟浣撴湇鍔″櫒杞欢锛屽彲浠ョ敤鏉ユ暣鐞嗘湇鍔″櫒涓婄殑瑙嗛鍜岄煶棰戯紝骞跺皢闊抽鍜岃棰戞祦寮忎紶杈撳埌瀹㈡埛绔澶�"
			local docker_url="瀹樼綉浠嬬粛: https://emby.media/"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  16)
			local docker_name="looking-glass"
			local docker_img="wikihostinc/looking-glass-server"
			local docker_port=89
			local docker_rum="docker run -d --name looking-glass --restart always -p 89:80 wikihostinc/looking-glass-server"
			local docker_describe="Speedtest娴嬮€熼潰鏉挎槸涓€涓猇PS缃戦€熸祴璇曞伐鍏凤紝澶氶」娴嬭瘯鍔熻兘锛岃繕鍙互瀹炴椂鐩戞帶VPS杩涘嚭绔欐祦閲�"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/wikihost-opensource/als"
			local docker_use=""
			local docker_passwd=""
			docker_app

			  ;;
		  17)

			local docker_name="adguardhome"
			local docker_img="adguard/adguardhome"
			local docker_port=3000
			local docker_rum="docker run -d \
							--name adguardhome \
							-v /home/docker/adguardhome/work:/opt/adguardhome/work \
							-v /home/docker/adguardhome/conf:/opt/adguardhome/conf \
							-p 53:53/tcp \
							-p 53:53/udp \
							-p 3000:3000/tcp \
							--restart always \
							adguard/adguardhome"
			local docker_describe="AdGuardHome鏄竴娆惧叏缃戝箍鍛婃嫤鎴笌鍙嶈窡韪蒋浠讹紝鏈潵灏嗕笉姝㈡槸涓€涓狣NS鏈嶅姟鍣ㄣ€�"
			local docker_url="瀹樼綉浠嬬粛: https://hub.docker.com/r/adguard/adguardhome"
			local docker_use=""
			local docker_passwd=""
			docker_app

			  ;;


		  18)

			local docker_name="onlyoffice"
			local docker_img="onlyoffice/documentserver"
			local docker_port=8082
			local docker_rum="docker run -d -p 8082:80 \
						--restart=always \
						--name onlyoffice \
						-v /home/docker/onlyoffice/DocumentServer/logs:/var/log/onlyoffice  \
						-v /home/docker/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  \
						 onlyoffice/documentserver"
			local docker_describe="onlyoffice鏄竴娆惧紑婧愮殑鍦ㄧ嚎office宸ュ叿锛屽お寮哄ぇ浜嗭紒"
			local docker_url="瀹樼綉浠嬬粛: https://www.onlyoffice.com/"
			local docker_use=""
			local docker_passwd=""
			docker_app

			  ;;

		  19)
			send_stats "鎼缓闆锋睜"


			local docker_name=safeline-mgt
			local docker_port=9443
			while true; do
				check_docker_app
				clear
				echo -e "闆锋睜鏈嶅姟 $check_docker"
				echo "闆锋睜鏄暱浜鎶€寮€鍙戠殑WAF绔欑偣闃茬伀澧欑▼搴忛潰鏉匡紝鍙互鍙嶄唬绔欑偣杩涜鑷姩鍖栭槻寰�"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1mZ421T74c?t=0.1"
				if docker inspect "$docker_name" &>/dev/null; then
					check_docker_app_ip
				fi
				echo ""

				echo "------------------------"
				echo "1. 瀹夎           2. 鏇存柊           3. 閲嶇疆瀵嗙爜           4. 鍗歌浇"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						install_docker
						bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
						clear
						echo "闆锋睜WAF闈㈡澘宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						docker exec safeline-mgt resetadmin

						;;

					2)
						bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
						docker rmi $(docker images | grep "safeline" | grep "none" | awk '{print $3}')
						echo ""
						clear
						echo "闆锋睜WAF闈㈡澘宸茬粡鏇存柊瀹屾垚"
						check_docker_app_ip
						;;
					3)
						docker exec safeline-mgt resetadmin
						;;
					4)
						cd /data/safeline
						docker compose down
						docker compose down --rmi all
						echo "濡傛灉浣犳槸榛樿瀹夎鐩綍閭ｇ幇鍦ㄩ」鐩凡缁忓嵏杞姐€傚鏋滀綘鏄嚜瀹氫箟瀹夎鐩綍浣犻渶瑕佸埌瀹夎鐩綍涓嬭嚜琛屾墽琛�:"
						echo "docker compose down && docker compose down --rmi all"
						;;

					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done

			  ;;

		  20)
			local docker_name="portainer"
			local docker_img="portainer/portainer"
			local docker_port=9050
			local docker_rum="docker run -d \
					--name portainer \
					-p 9050:9000 \
					-v /var/run/docker.sock:/var/run/docker.sock \
					-v /home/docker/portainer:/data \
					--restart always \
					portainer/portainer"
			local docker_describe="portainer鏄竴涓交閲忕骇鐨刣ocker瀹瑰櫒绠＄悊闈㈡澘"
			local docker_url="瀹樼綉浠嬬粛: https://www.portainer.io/"
			local docker_use=""
			local docker_passwd=""
			docker_app

			  ;;

		  21)
			local docker_name="vscode-web"
			local docker_img="codercom/code-server"
			local docker_port=8180
			local docker_rum="docker run -d -p 8180:8080 -v /home/docker/vscode-web:/home/coder/.local/share/code-server --name vscode-web --restart always codercom/code-server"
			local docker_describe="VScode鏄竴娆惧己澶х殑鍦ㄧ嚎浠ｇ爜缂栧啓宸ュ叿"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/coder/code-server"
			local docker_use="sleep 3"
			local docker_passwd="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
			docker_app
			  ;;
		  22)
			local docker_name="uptime-kuma"
			local docker_img="louislam/uptime-kuma:latest"
			local docker_port=3003
			local docker_rum="docker run -d \
							--name=uptime-kuma \
							-p 3003:3001 \
							-v /home/docker/uptime-kuma/uptime-kuma-data:/app/data \
							--restart=always \
							louislam/uptime-kuma:latest"
			local docker_describe="Uptime Kuma 鏄撲簬浣跨敤鐨勮嚜鎵樼鐩戞帶宸ュ叿"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/louislam/uptime-kuma"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  23)
			local docker_name="memos"
			local docker_img="ghcr.io/usememos/memos:latest"
			local docker_port=5230
			local docker_rum="docker run -d --name memos -p 5230:5230 -v /home/docker/memos:/var/opt/memos --restart always ghcr.io/usememos/memos:latest"
			local docker_describe="Memos鏄竴娆捐交閲忕骇銆佽嚜鎵樼鐨勫蹇樺綍涓績"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/usememos/memos"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  24)
			local docker_name="webtop"
			local docker_img="lscr.io/linuxserver/webtop:latest"
			local docker_port=3083
			local docker_rum="docker run -d \
						  --name=webtop \
						  --security-opt seccomp=unconfined \
						  -e PUID=1000 \
						  -e PGID=1000 \
						  -e TZ=Etc/UTC \
						  -e SUBFOLDER=/ \
						  -e TITLE=Webtop \
						  -e LC_ALL=zh_CN.UTF-8 \
						  -e DOCKER_MODS=linuxserver/mods:universal-package-install \
						  -e INSTALL_PACKAGES=font-noto-cjk \
						  -p 3083:3000 \
						  -v /home/docker/webtop/data:/config \
						  -v /var/run/docker.sock:/var/run/docker.sock \
						  --shm-size="1gb" \
						  --restart unless-stopped \
						  lscr.io/linuxserver/webtop:latest"

			local docker_describe="webtop鍩轰簬 Alpine銆乁buntu銆丗edora 鍜� Arch 鐨勫鍣紝鍖呭惈瀹樻柟鏀寔鐨勫畬鏁存闈㈢幆澧冿紝鍙€氳繃浠讳綍鐜颁唬 Web 娴忚鍣ㄨ闂�"
			local docker_url="瀹樼綉浠嬬粛: https://docs.linuxserver.io/images/docker-webtop/"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  25)
			local docker_name="nextcloud"
			local docker_img="nextcloud:latest"
			local docker_port=8989
			local rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
			local docker_rum="docker run -d --name nextcloud --restart=always -p 8989:80 -v /home/docker/nextcloud:/var/www/html -e NEXTCLOUD_ADMIN_USER=nextcloud -e NEXTCLOUD_ADMIN_PASSWORD=$rootpasswd nextcloud"
			local docker_describe="Nextcloud鎷ユ湁瓒呰繃 400,000 涓儴缃诧紝鏄偍鍙互涓嬭浇鐨勬渶鍙楁杩庣殑鏈湴鍐呭鍗忎綔骞冲彴"
			local docker_url="瀹樼綉浠嬬粛: https://nextcloud.com/"
			local docker_use="echo \"璐﹀彿: nextcloud  瀵嗙爜: $rootpasswd\""
			local docker_passwd=""
			docker_app
			  ;;

		  26)
			local docker_name="qd"
			local docker_img="qdtoday/qd:latest"
			local docker_port=8923
			local docker_rum="docker run -d --name qd -p 8923:80 -v /home/docker/qd/config:/usr/src/app/config qdtoday/qd"
			local docker_describe="QD-Today鏄竴涓狧TTP璇锋眰瀹氭椂浠诲姟鑷姩鎵ц妗嗘灦"
			local docker_url="瀹樼綉浠嬬粛: https://qd-today.github.io/qd/zh_CN/"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;
		  27)
			local docker_name="dockge"
			local docker_img="louislam/dockge:latest"
			local docker_port=5003
			local docker_rum="docker run -d --name dockge --restart unless-stopped -p 5003:5001 -v /var/run/docker.sock:/var/run/docker.sock -v /home/docker/dockge/data:/app/data -v  /home/docker/dockge/stacks:/home/docker/dockge/stacks -e DOCKGE_STACKS_DIR=/home/docker/dockge/stacks louislam/dockge"
			local docker_describe="dockge鏄竴涓彲瑙嗗寲鐨刣ocker-compose瀹瑰櫒绠＄悊闈㈡澘"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/louislam/dockge"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  28)
			local docker_name="speedtest"
			local docker_img="ghcr.io/librespeed/speedtest:latest"
			local docker_port=6681
			local docker_rum="docker run -d \
							--name speedtest \
							--restart always \
							-e MODE=standalone \
							-p 6681:80 \
							ghcr.io/librespeed/speedtest:latest"
			local docker_describe="librespeed鏄敤Javascript瀹炵幇鐨勮交閲忕骇閫熷害娴嬭瘯宸ュ叿锛屽嵆寮€鍗崇敤"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/librespeed/speedtest"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  29)
			local docker_name="searxng"
			local docker_img="alandoyle/searxng:latest"
			local docker_port=8700
			local docker_rum="docker run --name=searxng \
							-d --init \
							--restart=unless-stopped \
							-v /home/docker/searxng/config:/etc/searxng \
							-v /home/docker/searxng/templates:/usr/local/searxng/searx/templates/simple \
							-v /home/docker/searxng/theme:/usr/local/searxng/searx/static/themes/simple \
							-p 8700:8080/tcp \
							alandoyle/searxng:latest"
			local docker_describe="searxng鏄竴涓鏈変笖闅愮鐨勬悳绱㈠紩鎿庣珯鐐�"
			local docker_url="瀹樼綉浠嬬粛: https://hub.docker.com/r/alandoyle/searxng"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  30)
			local docker_name="photoprism"
			local docker_img="photoprism/photoprism:latest"
			local docker_port=2342
			local rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
			local docker_rum="docker run -d \
							--name photoprism \
							--restart always \
							--security-opt seccomp=unconfined \
							--security-opt apparmor=unconfined \
							-p 2342:2342 \
							-e PHOTOPRISM_UPLOAD_NSFW="true" \
							-e PHOTOPRISM_ADMIN_PASSWORD="$rootpasswd" \
							-v /home/docker/photoprism/storage:/photoprism/storage \
							-v /home/docker/photoprism/Pictures:/photoprism/originals \
							photoprism/photoprism"
			local docker_describe="photoprism闈炲父寮哄ぇ鐨勭鏈夌浉鍐岀郴缁�"
			local docker_url="瀹樼綉浠嬬粛: https://www.photoprism.app/"
			local docker_use="echo \"璐﹀彿: admin  瀵嗙爜: $rootpasswd\""
			local docker_passwd=""
			docker_app
			  ;;


		  31)
			local docker_name="s-pdf"
			local docker_img="frooodle/s-pdf:latest"
			local docker_port=8020
			local docker_rum="docker run -d \
							--name s-pdf \
							--restart=always \
							 -p 8020:8080 \
							 -v /home/docker/s-pdf/trainingData:/usr/share/tesseract-ocr/5/tessdata \
							 -v /home/docker/s-pdf/extraConfigs:/configs \
							 -v /home/docker/s-pdf/logs:/logs \
							 -e DOCKER_ENABLE_SECURITY=false \
							 frooodle/s-pdf:latest"
			local docker_describe="杩欐槸涓€涓己澶х殑鏈湴鎵樼鍩轰簬 Web 鐨� PDF 鎿嶄綔宸ュ叿锛屼娇鐢� docker锛屽厑璁告偍瀵� PDF 鏂囦欢鎵ц鍚勭鎿嶄綔锛屼緥濡傛媶鍒嗗悎骞躲€佽浆鎹€€侀噸鏂扮粍缁囥€佹坊鍔犲浘鍍忋€佹棆杞€佸帇缂╃瓑銆�"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/Stirling-Tools/Stirling-PDF"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  32)
			local docker_name="drawio"
			local docker_img="jgraph/drawio"
			local docker_port=7080
			local docker_rum="docker run -d --restart=always --name drawio -p 7080:8080 -v /home/docker/drawio:/var/lib/drawio jgraph/drawio"
			local docker_describe="杩欐槸涓€涓己澶у浘琛ㄧ粯鍒惰蒋浠躲€傛€濈淮瀵煎浘锛屾嫇鎵戝浘锛屾祦绋嬪浘锛岄兘鑳界敾"
			local docker_url="瀹樼綉浠嬬粛: https://www.drawio.com/"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  33)
			local docker_name="sun-panel"
			local docker_img="hslr/sun-panel"
			local docker_port=3009
			local docker_rum="docker run -d --restart=always -p 3009:3002 \
							-v /home/docker/sun-panel/conf:/app/conf \
							-v /home/docker/sun-panel/uploads:/app/uploads \
							-v /home/docker/sun-panel/database:/app/database \
							--name sun-panel \
							hslr/sun-panel"
			local docker_describe="Sun-Panel鏈嶅姟鍣ㄣ€丯AS瀵艰埅闈㈡澘銆丠omepage銆佹祻瑙堝櫒棣栭〉"
			local docker_url="瀹樼綉浠嬬粛: https://doc.sun-panel.top/zh_cn/"
			local docker_use="echo \"璐﹀彿: admin@sun.cc  瀵嗙爜: 12345678\""
			local docker_passwd=""
			docker_app
			  ;;

		  34)
			local docker_name="pingvin-share"
			local docker_img="stonith404/pingvin-share"
			local docker_port=3060
			local docker_rum="docker run -d \
							--name pingvin-share \
							--restart always \
							-p 3060:3000 \
							-v /home/docker/pingvin-share/data:/opt/app/backend/data \
							stonith404/pingvin-share"
			local docker_describe="Pingvin Share 鏄竴涓彲鑷缓鐨勬枃浠跺垎浜钩鍙帮紝鏄� WeTransfer 鐨勪竴涓浛浠ｅ搧"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/stonith404/pingvin-share"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;


		  35)
			local docker_name="moments"
			local docker_img="kingwrcy/moments:latest"
			local docker_port=8035
			local docker_rum="docker run -d --restart unless-stopped \
							-p 8035:3000 \
							-v /home/docker/moments/data:/app/data \
							-v /etc/localtime:/etc/localtime:ro \
							-v /etc/timezone:/etc/timezone:ro \
							--name moments \
							kingwrcy/moments:latest"
			local docker_describe="鏋佺畝鏈嬪弸鍦堬紝楂樹豢寰俊鏈嬪弸鍦堬紝璁板綍浣犵殑缇庡ソ鐢熸椿"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/kingwrcy/moments?tab=readme-ov-file"
			local docker_use="echo \"璐﹀彿: admin  瀵嗙爜: a123456\""
			local docker_passwd=""
			docker_app
			  ;;



		  36)
			local docker_name="lobe-chat"
			local docker_img="lobehub/lobe-chat:latest"
			local docker_port=8036
			local docker_rum="docker run -d -p 8036:3210 \
							--name lobe-chat \
							--restart=always \
							lobehub/lobe-chat"
			local docker_describe="LobeChat鑱氬悎甯傞潰涓婁富娴佺殑AI澶фā鍨嬶紝ChatGPT/Claude/Gemini/Groq/Ollama"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/lobehub/lobe-chat"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  37)
			local docker_name="myip"
			local docker_img="ghcr.io/jason5ng32/myip:latest"
			local docker_port=8037
			local docker_rum="docker run -d -p 8037:18966 --name myip --restart always ghcr.io/jason5ng32/myip:latest"
			local docker_describe="鏄竴涓鍔熻兘IP宸ュ叿绠憋紝鍙互鏌ョ湅鑷繁IP淇℃伅鍙婅繛閫氭€э紝鐢ㄧ綉椤甸潰鏉垮憟鐜�"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/jason5ng32/MyIP/blob/main/README_ZH.md"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  38)
			send_stats "灏忛泤鍏ㄥ妗�"
			clear
			install_docker
			bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"
			  ;;

		  39)

			if [ ! -d /home/docker/bililive-go/ ]; then
				mkdir -p /home/docker/bililive-go/ > /dev/null 2>&1
				wget -O /home/docker/bililive-go/config.yml ${gh_proxy}https://raw.githubusercontent.com/hr3lxphr6j/bililive-go/master/config.yml > /dev/null 2>&1
			fi

			local docker_name="bililive-go"
			local docker_img="chigusa/bililive-go"
			local docker_port=8039
			local docker_rum="docker run --restart=always --name bililive-go -v /home/docker/bililive-go/config.yml:/etc/bililive-go/config.yml -v /home/docker/bililive-go/Videos:/srv/bililive -p 8039:8080 -d chigusa/bililive-go"
			local docker_describe="Bililive-go鏄竴涓敮鎸佸绉嶇洿鎾钩鍙扮殑鐩存挱褰曞埗宸ュ叿"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/hr3lxphr6j/bililive-go"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  40)
			local docker_name="webssh"
			local docker_img="jrohy/webssh"
			local docker_port=8040
			local docker_rum="docker run -d -p 8040:5032 --restart always --name webssh -e TZ=Asia/Shanghai jrohy/webssh"
			local docker_describe="绠€鏄撳湪绾縮sh杩炴帴宸ュ叿鍜宻ftp宸ュ叿"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/Jrohy/webssh"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  41)
			send_stats "鑰楀瓙闈㈡澘"
			while true; do
				clear
				echo "鑰楀瓙绠＄悊闈㈡澘"
				echo "浣跨敤 Golang + Vue 寮€鍙戠殑寮€婧愯交閲� Linux 鏈嶅姟鍣ㄨ繍缁寸鐞嗛潰鏉裤€�"
				echo "瀹樻柟鍦板潃: ${gh_proxy}https://github.com/TheTNB/panel"
				echo "------------------------"
				echo "1. 瀹夎            2. 绠＄悊            3. 鍗歌浇"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						local HAOZI_DL_URL="https://dl.cdn.haozi.net/panel"; curl -sSL -O ${HAOZI_DL_URL}/install_panel.sh && curl -sSL -O ${HAOZI_DL_URL}/install_panel.sh.checksum.txt && sha256sum -c install_panel.sh.checksum.txt && bash install_panel.sh || echo "Checksum 楠岃瘉澶辫触锛屾枃浠跺彲鑳借绡℃敼锛屽凡缁堟鎿嶄綔"
						;;
					2)
						panel
						;;
					3)
						local HAOZI_DL_URL="https://dl.cdn.haozi.net/panel"; curl -sSL -O ${HAOZI_DL_URL}/uninstall_panel.sh && curl -sSL -O ${HAOZI_DL_URL}/uninstall_panel.sh.checksum.txt && sha256sum -c uninstall_panel.sh.checksum.txt && bash uninstall_panel.sh || echo "Checksum 楠岃瘉澶辫触锛屾枃浠跺彲鑳借绡℃敼锛屽凡缁堟鎿嶄綔"
						;;
					0)
						break
						;;
					*)
						break
						;;

				esac
				break_end
			done
			  ;;


		  42)
			local docker_name="nexterm"
			local docker_img="germannewsmaker/nexterm:latest"
			local docker_port=8042
			local docker_rum="docker run -d \
						  --name nexterm \
						  -p 8042:6989 \
						  -v /home/docker/nexterm:/app/data \
						  --restart unless-stopped \
						  germannewsmaker/nexterm:latest"
			local docker_describe="nexterm鏄竴娆惧己澶х殑鍦ㄧ嚎SSH/VNC/RDP杩炴帴宸ュ叿銆�"
			local docker_url="瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/gnmyt/Nexterm"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  43)
			local docker_name="hbbs"
			local docker_img="rustdesk/rustdesk-server"
			local docker_port=21116
			local docker_rum="docker run --name hbbs -v /home/docker/hbbs/data:/root -td --net=host --restart unless-stopped rustdesk/rustdesk-server hbbs"
			local docker_describe="rustdesk寮€婧愮殑杩滅▼妗岄潰(鏈嶅姟绔�)锛岀被浼艰嚜宸辩殑鍚戞棩钁电鏈嶃€�"
			local docker_url="瀹樼綉浠嬬粛: https://rustdesk.com/zh-cn/"
			local docker_use="docker logs hbbs"
			local docker_passwd="echo \"鎶婁綘鐨処P鍜宬ey璁板綍涓嬶紝浼氬湪杩滅▼妗岄潰瀹㈡埛绔腑鐢ㄥ埌銆傚幓44閫夐」瑁呬腑缁х鍚э紒\""
			docker_app
			  ;;

		  44)
			local docker_name="hbbr"
			local docker_img="rustdesk/rustdesk-server"
			local docker_port=21116
			local docker_rum="docker run --name hbbr -v /home/docker/hbbr/data:/root -td --net=host --restart unless-stopped rustdesk/rustdesk-server hbbr"
			local docker_describe="rustdesk寮€婧愮殑杩滅▼妗岄潰(涓户绔�)锛岀被浼艰嚜宸辩殑鍚戞棩钁电鏈嶃€�"
			local docker_url="瀹樼綉浠嬬粛: https://rustdesk.com/zh-cn/"
			local docker_use="echo \"鍓嶅線瀹樼綉涓嬭浇杩滅▼妗岄潰鐨勫鎴风: https://rustdesk.com/zh-cn/\""
			local docker_passwd=""
			docker_app
			  ;;

		  45)
			local docker_name="registry"
			local docker_img="registry:2"
			local docker_port=8045
			local docker_rum="docker run -d \
							-p 8045:5000 \
							--name registry \
							-v /home/docker/registry:/var/lib/registry \
							-e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
							--restart always \
							registry:2"
			local docker_describe="Docker Registry 鏄竴涓敤浜庡瓨鍌ㄥ拰鍒嗗彂 Docker 闀滃儚鐨勬湇鍔°€�"
			local docker_url="瀹樼綉浠嬬粛: https://hub.docker.com/_/registry"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  46)
			local docker_name="ghproxy"
			local docker_img="wjqserver/ghproxy:latest"
			local docker_port=8046
			local docker_rum="docker run -d --name ghproxy --restart always -p 8046:80 wjqserver/ghproxy:latest"
			local docker_describe="浣跨敤Go瀹炵幇鐨凣HProxy锛岀敤浜庡姞閫熼儴鍒嗗湴鍖篏ithub浠撳簱鐨勬媺鍙栥€�"
			local docker_url="瀹樼綉浠嬬粛: https://github.com/WJQSERVER-STUDIO/ghproxy"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  47)
			send_stats "鏅綏绫充慨鏂洃鎺�"

			local docker_name=prometheus
			local docker_port=8047
			while true; do
				check_docker_app
				clear
				echo -e "鏅綏绫充慨鏂洃鎺� $check_docker"
				echo "Prometheus+Grafana浼佷笟绾х洃鎺х郴缁�"
				echo "瀹樼綉浠嬬粛: https://prometheus.io"
				if docker inspect "$docker_name" &>/dev/null; then
					check_docker_app_ip
				fi
				echo ""

				echo "------------------------"
				echo "1. 瀹夎           2. 鏇存柊           3. 鍗歌浇"
				echo "------------------------"
				echo "5. 鍩熷悕璁块棶"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾�"
				echo "------------------------"
				read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

				case $choice in
					1)
						install_docker
						prometheus_install

						clear

						ip_address
						echo "鏅綏绫充慨鏂洃鎺� 宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip
						echo "鐢ㄦ埛鍚嶅瘑鐮佸潎涓�: admin"

						;;

					2)
						docker rm -f node-exporter prometheus grafana
						docker rmi -f prom/node-exporter
						docker rmi -f prom/prometheus:latest
						docker rmi -f grafana/grafana:latest
						prometheus_install

						clear

						ip_address
						echo "鏅綏绫充慨鏂洃鎺� 宸茬粡瀹夎瀹屾垚"
						check_docker_app_ip

						;;
					3)
						docker rm -f node-exporter prometheus grafana
						docker rmi -f prom/node-exporter
						docker rmi -f prom/prometheus:latest
						docker rmi -f grafana/grafana:latest

						rm -rf /home/docker/monitoring
						echo "搴旂敤宸插嵏杞�"

						;;
					5)
						echo "${docker_name}鍩熷悕璁块棶璁剧疆"
						send_stats "${docker_name}鍩熷悕璁块棶璁剧疆"
						add_yuming
						ldnmp_Proxy ${yuming} ${ipv4_address} ${docker_port}
						;;

					*)
						break
						;;

				esac
				break_end
			done
			  ;;

		  48)
			local docker_name="node-exporter"
			local docker_img="prom/node-exporter"
			local docker_port=8048
			local docker_rum="docker run -d \
  								--name=node-exporter \
  								-p 8048:9100 \
  								--restart unless-stopped \
  								prom/node-exporter"
			local docker_describe="杩欐槸涓€涓櫘缃楃背淇柉鐨勪富鏈烘暟鎹噰闆嗙粍浠讹紝璇烽儴缃插湪琚洃鎺т富鏈轰笂銆�"
			local docker_url="瀹樼綉浠嬬粛: https://github.com/prometheus/node_exporter"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;

		  49)
			local docker_name="cadvisor"
			local docker_img="gcr.io/cadvisor/cadvisor:latest"
			local docker_port=8049
			local docker_rum="docker run -d \
  								--name=cadvisor \
  								--restart unless-stopped \
  								-p 8049:8080 \
  								--volume=/:/rootfs:ro \
  								--volume=/var/run:/var/run:rw \
  								--volume=/sys:/sys:ro \
  								--volume=/var/lib/docker/:/var/lib/docker:ro \
  								gcr.io/cadvisor/cadvisor:latest \
  								-housekeeping_interval=10s \
  								-docker_only=true"
			local docker_describe="杩欐槸涓€涓櫘缃楃背淇柉鐨勫鍣ㄦ暟鎹噰闆嗙粍浠讹紝璇烽儴缃插湪琚洃鎺т富鏈轰笂銆�"
			local docker_url="瀹樼綉浠嬬粛: https://github.com/google/cadvisor"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;


		  50)
			local docker_name="changedetection"
			local docker_img="dgtlmoon/changedetection.io:latest"
			local docker_port=8050
			local docker_rum="docker run -d --restart always -p 8050:5000 \
								-v /home/docker/datastore:/datastore \
								--name changedetection dgtlmoon/changedetection.io:latest"
			local docker_describe="杩欐槸涓€娆剧綉绔欏彉鍖栨娴嬨€佽ˉ璐х洃鎺у拰閫氱煡鐨勫皬宸ュ叿"
			local docker_url="瀹樼綉浠嬬粛: https://github.com/dgtlmoon/changedetection.io"
			local docker_use=""
			local docker_passwd=""
			docker_app
			  ;;


		  51)
			clear
			send_stats "PVE寮€灏忛浮"
			curl -L ${gh_proxy}https://raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh -o install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
			  ;;
		  0)
			  kejilion
			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done
}


linux_work() {

	while true; do
	  clear
	  send_stats "鎴戠殑宸ヤ綔鍖�"
	  echo -e "鈻� 鎴戠殑宸ヤ綔鍖�"
	  echo -e "绯荤粺灏嗕负浣犳彁渚涘彲浠ュ悗鍙板父椹昏繍琛岀殑宸ヤ綔鍖猴紝浣犲彲浠ョ敤鏉ユ墽琛岄暱鏃堕棿鐨勪换鍔�"
	  echo -e "鍗充娇浣犳柇寮€SSH锛屽伐浣滃尯涓殑浠诲姟涔熶笉浼氫腑鏂紝鍚庡彴甯搁┗浠诲姟銆�"
	  echo -e "${gl_huang}鎻愮ず: ${gl_bai}杩涘叆宸ヤ綔鍖哄悗浣跨敤Ctrl+b鍐嶅崟鐙寜d锛岄€€鍑哄伐浣滃尯锛�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}1鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}2.   ${gl_bai}2鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}3.   ${gl_bai}3鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}4.   ${gl_bai}4鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}5.   ${gl_bai}5鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}6.   ${gl_bai}6鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}7.   ${gl_bai}7鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}8.   ${gl_bai}8鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}9.   ${gl_bai}9鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}10.  ${gl_bai}10鍙峰伐浣滃尯"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}98.  ${gl_bai}SSH甯搁┗妯″紡 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}99.  ${gl_bai}宸ヤ綔鍖虹鐞� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in

		  1)
			  clear
			  install tmux
			  local SESSION_NAME="work1"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run

			  ;;
		  2)
			  clear
			  install tmux
			  local SESSION_NAME="work2"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  3)
			  clear
			  install tmux
			  local SESSION_NAME="work3"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  4)
			  clear
			  install tmux
			  local SESSION_NAME="work4"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  5)
			  clear
			  install tmux
			  local SESSION_NAME="work5"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  6)
			  clear
			  install tmux
			  local SESSION_NAME="work6"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  7)
			  clear
			  install tmux
			  local SESSION_NAME="work7"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  8)
			  clear
			  install tmux
			  local SESSION_NAME="work8"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  9)
			  clear
			  install tmux
			  local SESSION_NAME="work9"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;
		  10)
			  clear
			  install tmux
			  local SESSION_NAME="work10"
			  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
			  tmux_run
			  ;;

		  98)
			while true; do
			  clear
			  if grep -q 'tmux attach-session -t sshd || tmux new-session -s sshd' ~/.bashrc; then
				  local tmux_sshd_status="${gl_lv}寮€鍚�${gl_bai}"
			  else
				  local tmux_sshd_status="${gl_hui}鍏抽棴${gl_bai}"
			  fi
			  send_stats "SSH甯搁┗妯″紡 "
			  echo -e "SSH甯搁┗妯″紡 ${tmux_sshd_status}"
			  echo "寮€鍚悗SSH杩炴帴鍚庝細鐩存帴杩涘叆甯搁┗妯″紡锛岀洿鎺ュ洖鍒颁箣鍓嶇殑宸ヤ綔鐘舵€併€�"
			  echo "------------------------"
			  echo "1. 寮€鍚�            2. 鍏抽棴"
			  echo "------------------------"
			  echo "0. 杩斿洖涓婁竴绾�"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " gongzuoqu_del
			  case "$gongzuoqu_del" in
				1)
			  	  install tmux
			  	  local SESSION_NAME="sshd"
			  	  send_stats "鍚姩宸ヤ綔鍖�$SESSION_NAME"
				  grep -q "tmux attach-session -t sshd" ~/.bashrc || echo -e "\n# 鑷姩杩涘叆 tmux 浼氳瘽\nif [[ -z \"\$TMUX\" ]]; then\n    tmux attach-session -t sshd || tmux new-session -s sshd\nfi" >> ~/.bashrc
				  source ~/.bashrc
			  	  tmux_run
				  ;;
				2)
				  sed -i '/# 鑷姩杩涘叆 tmux 浼氳瘽/,+4d' ~/.bashrc
				  tmux kill-window -t sshd
				  ;;
				*)
				  break
				  ;;
			  esac
			done
			  ;;

		  99)
			while true; do
			  clear
			  send_stats "宸ヤ綔鍖虹鐞�"
			  echo "褰撳墠宸插瓨鍦ㄧ殑宸ヤ綔鍖哄垪琛�"
			  echo "------------------------"
			  tmux list-sessions
			  echo "------------------------"
			  echo "1. 鍒涘缓/杩涘叆宸ヤ綔鍖�"
			  echo "2. 娉ㄥ叆鍛戒护鍒板悗鍙板伐浣滃尯"
			  echo "3. 鍒犻櫎鎸囧畾宸ヤ綔鍖�"
			  echo "------------------------"
			  echo "0. 杩斿洖涓婁竴绾�"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " gongzuoqu_del
			  case "$gongzuoqu_del" in
				1)
				  read -e -p "璇疯緭鍏ヤ綘鍒涘缓鎴栬繘鍏ョ殑宸ヤ綔鍖哄悕绉帮紝濡�1001 kj001 work1: " SESSION_NAME
				  tmux_run
				  send_stats "鑷畾涔夊伐浣滃尯"
				  ;;

				2)
				  read -e -p "璇疯緭鍏ヤ綘瑕佸悗鍙版墽琛岀殑鍛戒护锛屽:curl -fsSL https://get.docker.com | sh: " tmuxd
				  tmux_run_d
				  send_stats "娉ㄥ叆鍛戒护鍒板悗鍙板伐浣滃尯"
				  ;;

				3)
				  read -e -p "璇疯緭鍏ヨ鍒犻櫎鐨勫伐浣滃尯鍚嶇О: " gongzuoqu_name
				  tmux kill-window -t $gongzuoqu_name
				  send_stats "鍒犻櫎宸ヤ綔鍖�"
				  ;;
				0)
				  break
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			done

			  ;;
		  0)
			  kejilion
			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done


}












linux_Settings() {

	while true; do
	  clear
	  # send_stats "绯荤粺宸ュ叿"
	  echo -e "鈻� 绯荤粺宸ュ叿"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}璁剧疆鑴氭湰鍚姩蹇嵎閿�                 ${gl_kjlan}2.   ${gl_bai}淇敼鐧诲綍瀵嗙爜"
	  echo -e "${gl_kjlan}3.   ${gl_bai}ROOT瀵嗙爜鐧诲綍妯″紡                   ${gl_kjlan}4.   ${gl_bai}瀹夎Python鎸囧畾鐗堟湰"
	  echo -e "${gl_kjlan}5.   ${gl_bai}寮€鏀炬墍鏈夌鍙�                       ${gl_kjlan}6.   ${gl_bai}淇敼SSH杩炴帴绔彛"
	  echo -e "${gl_kjlan}7.   ${gl_bai}浼樺寲DNS鍦板潃                        ${gl_kjlan}8.   ${gl_bai}涓€閿噸瑁呯郴缁� ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}9.   ${gl_bai}绂佺敤ROOT璐︽埛鍒涘缓鏂拌处鎴�             ${gl_kjlan}10.  ${gl_bai}鍒囨崲浼樺厛ipv4/ipv6"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}11.  ${gl_bai}鏌ョ湅绔彛鍗犵敤鐘舵€�                   ${gl_kjlan}12.  ${gl_bai}淇敼铏氭嫙鍐呭瓨澶у皬"
	  echo -e "${gl_kjlan}13.  ${gl_bai}鐢ㄦ埛绠＄悊                           ${gl_kjlan}14.  ${gl_bai}鐢ㄦ埛/瀵嗙爜鐢熸垚鍣�"
	  echo -e "${gl_kjlan}15.  ${gl_bai}绯荤粺鏃跺尯璋冩暣                       ${gl_kjlan}16.  ${gl_bai}璁剧疆BBR3鍔犻€�"
	  echo -e "${gl_kjlan}17.  ${gl_bai}闃茬伀澧欓珮绾х鐞嗗櫒                   ${gl_kjlan}18.  ${gl_bai}淇敼涓绘満鍚�"
	  echo -e "${gl_kjlan}19.  ${gl_bai}鍒囨崲绯荤粺鏇存柊婧�                     ${gl_kjlan}20.  ${gl_bai}瀹氭椂浠诲姟绠＄悊"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}21.  ${gl_bai}鏈満host瑙ｆ瀽                       ${gl_kjlan}22.  ${gl_bai}fail2banSSH闃插尽绋嬪簭"
	  echo -e "${gl_kjlan}23.  ${gl_bai}闄愭祦鑷姩鍏虫満                       ${gl_kjlan}24.  ${gl_bai}ROOT绉侀挜鐧诲綍妯″紡"
	  echo -e "${gl_kjlan}25.  ${gl_bai}TG-bot绯荤粺鐩戞帶棰勮                 ${gl_kjlan}26.  ${gl_bai}淇OpenSSH楂樺嵄婕忔礊锛堝搏婧愶級"
	  echo -e "${gl_kjlan}27.  ${gl_bai}绾㈠附绯籐inux鍐呮牳鍗囩骇                ${gl_kjlan}28.  ${gl_bai}Linux绯荤粺鍐呮牳鍙傛暟浼樺寲 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}29.  ${gl_bai}鐥呮瘨鎵弿宸ュ叿 ${gl_huang}鈽�${gl_bai}                     ${gl_kjlan}30.  ${gl_bai}鏂囦欢绠＄悊鍣�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}31.  ${gl_bai}鍒囨崲绯荤粺璇█                       ${gl_kjlan}32.  ${gl_bai}鍛戒护琛岀編鍖栧伐鍏�"
	  echo -e "${gl_kjlan}33.  ${gl_bai}璁剧疆绯荤粺鍥炴敹绔�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}41.  ${gl_bai}鐣欒█鏉�                             ${gl_kjlan}66.  ${gl_bai}涓€鏉￠緳绯荤粺璋冧紭 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}99.  ${gl_bai}閲嶅惎鏈嶅姟鍣�                         ${gl_kjlan}100. ${gl_bai}闅愮涓庡畨鍏�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}101. ${gl_bai}鍗歌浇绉戞妧lion鑴氭湰"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			  while true; do
				  clear
				  read -e -p "璇疯緭鍏ヤ綘鐨勫揩鎹锋寜閿紙杈撳叆0閫€鍑猴級: " kuaijiejian
				  if [ "$kuaijiejian" == "0" ]; then
					   break_end
					   linux_Settings
				  fi

				  sed -i '/alias .*='\''k'\''$/d' ~/.bashrc

				  echo "alias $kuaijiejian='k'" >> ~/.bashrc
				  sleep 1
				  source ~/.bashrc

				  echo "蹇嵎閿凡璁剧疆"
				  send_stats "鑴氭湰蹇嵎閿凡璁剧疆"
				  break_end
				  linux_Settings
			  done
			  ;;

		  2)
			  clear
			  send_stats "璁剧疆浣犵殑鐧诲綍瀵嗙爜"
			  echo "璁剧疆浣犵殑鐧诲綍瀵嗙爜"
			  passwd
			  ;;
		  3)
			  root_use
			  send_stats "root瀵嗙爜妯″紡"
			  add_sshpasswd
			  ;;

		  4)
			root_use
			send_stats "py鐗堟湰绠＄悊"
			echo "python鐗堟湰绠＄悊"
			echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1Pm42157cK?t=0.1"
			echo "---------------------------------------"
			echo "璇ュ姛鑳藉彲鏃犵紳瀹夎python瀹樻柟鏀寔鐨勪换浣曠増鏈紒"
			local VERSION=$(python3 -V 2>&1 | awk '{print $2}')
			echo -e "褰撳墠python鐗堟湰鍙�: ${gl_huang}$VERSION${gl_bai}"
			echo "------------"
			echo "鎺ㄨ崘鐗堟湰:  3.12    3.11    3.10    3.9    3.8    2.7"
			echo "鏌ヨ鏇村鐗堟湰: https://www.python.org/downloads/"
			echo "------------"
			read -e -p "杈撳叆浣犺瀹夎鐨刾ython鐗堟湰鍙凤紙杈撳叆0閫€鍑猴級: " py_new_v


			if [[ "$py_new_v" == "0" ]]; then
				send_stats "鑴氭湰PY绠＄悊"
				break_end
				linux_Settings
			fi


			if ! grep -q 'export PYENV_ROOT="\$HOME/.pyenv"' ~/.bashrc; then
				if command -v yum &>/dev/null; then
					yum update -y && yum install git -y
					yum groupinstall "Development Tools" -y
					yum install openssl-devel bzip2-devel libffi-devel ncurses-devel zlib-devel readline-devel sqlite-devel xz-devel findutils -y

					curl -O https://www.openssl.org/source/openssl-1.1.1u.tar.gz
					tar -xzf openssl-1.1.1u.tar.gz
					cd openssl-1.1.1u
					./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
					make
					make install
					echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl-1.1.1u.conf
					ldconfig -v
					cd ..

					export LDFLAGS="-L/usr/local/openssl/lib"
					export CPPFLAGS="-I/usr/local/openssl/include"
					export PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig"

				elif command -v apt &>/dev/null; then
					apt update -y && apt install git -y
					apt install build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev libgdbm-dev libnss3-dev libedit-dev -y
				elif command -v apk &>/dev/null; then
					apk update && apk add git
					apk add --no-cache bash gcc musl-dev libffi-dev openssl-dev bzip2-dev zlib-dev readline-dev sqlite-dev libc6-compat linux-headers make xz-dev build-base  ncurses-dev
				else
					echo "鏈煡鐨勫寘绠＄悊鍣�!"
					return
				fi

				curl https://pyenv.run | bash
				cat << EOF >> ~/.bashrc

export PYENV_ROOT="\$HOME/.pyenv"
if [[ -d "\$PYENV_ROOT/bin" ]]; then
  export PATH="\$PYENV_ROOT/bin:\$PATH"
fi
eval "\$(pyenv init --path)"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"

EOF

			fi

			sleep 1
			source ~/.bashrc
			sleep 1
			pyenv install $py_new_v
			pyenv global $py_new_v

			rm -rf /tmp/python-build.*
			rm -rf $(pyenv root)/cache/*

			local VERSION=$(python -V 2>&1 | awk '{print $2}')
			echo -e "褰撳墠python鐗堟湰鍙�: ${gl_huang}$VERSION${gl_bai}"
			send_stats "鑴氭湰PY鐗堟湰鍒囨崲"

			  ;;

		  5)
			  root_use
			  send_stats "寮€鏀剧鍙�"
			  iptables_open
			  remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
			  echo "绔彛宸插叏閮ㄥ紑鏀�"

			  ;;
		  6)
			root_use
			send_stats "淇敼SSH绔彛"

			while true; do
				clear
				sed -i 's/#Port/Port/' /etc/ssh/sshd_config

				# 璇诲彇褰撳墠鐨� SSH 绔彛鍙�
				local current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

				# 鎵撳嵃褰撳墠鐨� SSH 绔彛鍙�
				echo -e "褰撳墠鐨� SSH 绔彛鍙锋槸:  ${gl_huang}$current_port ${gl_bai}"

				echo "------------------------"
				echo "绔彛鍙疯寖鍥�1鍒�65535涔嬮棿鐨勬暟瀛椼€傦紙杈撳叆0閫€鍑猴級"

				# 鎻愮ず鐢ㄦ埛杈撳叆鏂扮殑 SSH 绔彛鍙�
				read -e -p "璇疯緭鍏ユ柊鐨� SSH 绔彛鍙�: " new_port

				# 鍒ゆ柇绔彛鍙锋槸鍚﹀湪鏈夋晥鑼冨洿鍐�
				if [[ $new_port =~ ^[0-9]+$ ]]; then  # 妫€鏌ヨ緭鍏ユ槸鍚︿负鏁板瓧
					if [[ $new_port -ge 1 && $new_port -le 65535 ]]; then
						send_stats "SSH绔彛宸蹭慨鏀�"
						new_ssh_port
					elif [[ $new_port -eq 0 ]]; then
						send_stats "閫€鍑篠SH绔彛淇敼"
						break
					else
						echo "绔彛鍙锋棤鏁堬紝璇疯緭鍏�1鍒�65535涔嬮棿鐨勬暟瀛椼€�"
						send_stats "杈撳叆鏃犳晥SSH绔彛"
						break_end
					fi
				else
					echo "杈撳叆鏃犳晥锛岃杈撳叆鏁板瓧銆�"
					send_stats "杈撳叆鏃犳晥SSH绔彛"
					break_end
				fi
			done


			  ;;


		  7)
			set_dns_ui
			  ;;

		  8)

			dd_xitong
			  ;;
		  9)
			root_use
			send_stats "鏂扮敤鎴风鐢╮oot"
			read -e -p "璇疯緭鍏ユ柊鐢ㄦ埛鍚嶏紙杈撳叆0閫€鍑猴級: " new_username
			if [ "$new_username" == "0" ]; then
				break_end
				linux_Settings
			fi

			useradd -m -s /bin/bash "$new_username"
			passwd "$new_username"

			echo "$new_username ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers

			passwd -l root

			echo "鎿嶄綔宸插畬鎴愩€�"
			;;


		  10)
			root_use
			send_stats "璁剧疆v4/v6浼樺厛绾�"
			while true; do
				clear
				echo "璁剧疆v4/v6浼樺厛绾�"
				echo "------------------------"
				local ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6)

				if [ "$ipv6_disabled" -eq 1 ]; then
					echo -e "褰撳墠缃戠粶浼樺厛绾ц缃�: ${gl_huang}IPv4${gl_bai} 浼樺厛"
				else
					echo -e "褰撳墠缃戠粶浼樺厛绾ц缃�: ${gl_huang}IPv6${gl_bai} 浼樺厛"
				fi
				echo ""
				echo "------------------------"
				echo "1. IPv4 浼樺厛          2. IPv6 浼樺厛          3. IPv6 淇宸ュ叿          0. 閫€鍑�"
				echo "------------------------"
				read -e -p "閫夋嫨浼樺厛鐨勭綉缁�: " choice

				case $choice in
					1)
						sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
						echo "宸插垏鎹负 IPv4 浼樺厛"
						send_stats "宸插垏鎹负 IPv4 浼樺厛"
						;;
					2)
						sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
						echo "宸插垏鎹负 IPv6 浼樺厛"
						send_stats "宸插垏鎹负 IPv6 浼樺厛"
						;;

					3)
						clear
						bash <(curl -L -s jhb.ovh/jb/v6.sh)
						echo "璇ュ姛鑳界敱jhb澶х鎻愪緵锛屾劅璋粬锛�"
						send_stats "ipv6淇"
						;;

					*)
						break
						;;

				esac
			done
			;;

		  11)
			clear
			ss -tulnape
			;;

		  12)
			root_use
			send_stats "璁剧疆铏氭嫙鍐呭瓨"
			while true; do
				clear
				echo "璁剧疆铏氭嫙鍐呭瓨"
				local swap_used=$(free -m | awk 'NR==3{print $3}')
				local swap_total=$(free -m | awk 'NR==3{print $2}')
				local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dMB/%dMB (%d%%)", used, total, percentage}')

				echo -e "褰撳墠铏氭嫙鍐呭瓨: ${gl_huang}$swap_info${gl_bai}"
				echo "------------------------"
				echo "1. 鍒嗛厤1024MB         2. 鍒嗛厤2048MB         3. 鑷畾涔夊ぇ灏�         0. 閫€鍑�"
				echo "------------------------"
				read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " choice

				case "$choice" in
				  1)
					send_stats "宸茶缃�1G铏氭嫙鍐呭瓨"
					add_swap 1024

					;;
				  2)
					send_stats "宸茶缃�2G铏氭嫙鍐呭瓨"
					add_swap 2048

					;;
				  3)
					read -e -p "璇疯緭鍏ヨ櫄鎷熷唴瀛樺ぇ灏廙B: " new_swap
					add_swap "$new_swap"
					send_stats "宸茶缃嚜瀹氫箟铏氭嫙鍐呭瓨"
					;;

				  *)
					break
					;;
				esac
			done
			;;

		  13)
			  while true; do
				root_use
				send_stats "鐢ㄦ埛绠＄悊"
				echo "鐢ㄦ埛鍒楄〃"
				echo "----------------------------------------------------------------------------"
				printf "%-24s %-34s %-20s %-10s\n" "鐢ㄦ埛鍚�" "鐢ㄦ埛鏉冮檺" "鐢ㄦ埛缁�" "sudo鏉冮檺"
				while IFS=: read -r username _ userid groupid _ _ homedir shell; do
					local groups=$(groups "$username" | cut -d : -f 2)
					local sudo_status=$(sudo -n -lU "$username" 2>/dev/null | grep -q '(ALL : ALL)' && echo "Yes" || echo "No")
					printf "%-20s %-30s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
				done < /etc/passwd


				  echo ""
				  echo "璐︽埛鎿嶄綔"
				  echo "------------------------"
				  echo "1. 鍒涘缓鏅€氳处鎴�             2. 鍒涘缓楂樼骇璐︽埛"
				  echo "------------------------"
				  echo "3. 璧嬩簣鏈€楂樻潈闄�             4. 鍙栨秷鏈€楂樻潈闄�"
				  echo "------------------------"
				  echo "5. 鍒犻櫎璐﹀彿"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
					   # 鎻愮ず鐢ㄦ埛杈撳叆鏂扮敤鎴峰悕
					   read -e -p "璇疯緭鍏ユ柊鐢ㄦ埛鍚�: " new_username

					   # 鍒涘缓鏂扮敤鎴峰苟璁剧疆瀵嗙爜
					   useradd -m -s /bin/bash "$new_username"
					   passwd "$new_username"

					   echo "鎿嶄綔宸插畬鎴愩€�"
						  ;;

					  2)
					   # 鎻愮ず鐢ㄦ埛杈撳叆鏂扮敤鎴峰悕
					   read -e -p "璇疯緭鍏ユ柊鐢ㄦ埛鍚�: " new_username

					   # 鍒涘缓鏂扮敤鎴峰苟璁剧疆瀵嗙爜
					   useradd -m -s /bin/bash "$new_username"
					   passwd "$new_username"

					   # 璧嬩簣鏂扮敤鎴穝udo鏉冮檺
					   echo "$new_username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

					   echo "鎿嶄綔宸插畬鎴愩€�"

						  ;;
					  3)
					   read -e -p "璇疯緭鍏ョ敤鎴峰悕: " username
					   # 璧嬩簣鏂扮敤鎴穝udo鏉冮檺
					   echo "$username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
						  ;;
					  4)
					   read -e -p "璇疯緭鍏ョ敤鎴峰悕: " username
					   # 浠巗udoers鏂囦欢涓Щ闄ょ敤鎴风殑sudo鏉冮檺
					   sed -i "/^$username\sALL=(ALL:ALL)\sALL/d" /etc/sudoers

						  ;;
					  5)
					   read -e -p "璇疯緭鍏ヨ鍒犻櫎鐨勭敤鎴峰悕: " username
					   # 鍒犻櫎鐢ㄦ埛鍙婂叾涓荤洰褰�
					   userdel -r "$username"
						  ;;

					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done
			  ;;

		  14)
			clear
			send_stats "鐢ㄦ埛淇℃伅鐢熸垚鍣�"
			echo "闅忔満鐢ㄦ埛鍚�"
			echo "------------------------"
			for i in {1..5}; do
				username="user$(< /dev/urandom tr -dc _a-z0-9 | head -c6)"
				echo "闅忔満鐢ㄦ埛鍚� $i: $username"
			done

			echo ""
			echo "闅忔満濮撳悕"
			echo "------------------------"
			local first_names=("John" "Jane" "Michael" "Emily" "David" "Sophia" "William" "Olivia" "James" "Emma" "Ava" "Liam" "Mia" "Noah" "Isabella")
			local last_names=("Smith" "Johnson" "Brown" "Davis" "Wilson" "Miller" "Jones" "Garcia" "Martinez" "Williams" "Lee" "Gonzalez" "Rodriguez" "Hernandez")

			# 鐢熸垚5涓殢鏈虹敤鎴峰鍚�
			for i in {1..5}; do
				local first_name_index=$((RANDOM % ${#first_names[@]}))
				local last_name_index=$((RANDOM % ${#last_names[@]}))
				local user_name="${first_names[$first_name_index]} ${last_names[$last_name_index]}"
				echo "闅忔満鐢ㄦ埛濮撳悕 $i: $user_name"
			done

			echo ""
			echo "闅忔満UUID"
			echo "------------------------"
			for i in {1..5}; do
				uuid=$(cat /proc/sys/kernel/random/uuid)
				echo "闅忔満UUID $i: $uuid"
			done

			echo ""
			echo "16浣嶉殢鏈哄瘑鐮�"
			echo "------------------------"
			for i in {1..5}; do
				local password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
				echo "闅忔満瀵嗙爜 $i: $password"
			done

			echo ""
			echo "32浣嶉殢鏈哄瘑鐮�"
			echo "------------------------"
			for i in {1..5}; do
				local password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
				echo "闅忔満瀵嗙爜 $i: $password"
			done
			echo ""

			  ;;

		  15)
			root_use
			send_stats "鎹㈡椂鍖�"
			while true; do
				clear
				echo "绯荤粺鏃堕棿淇℃伅"

				# 鑾峰彇褰撳墠绯荤粺鏃跺尯
				local timezone=$(current_timezone)

				# 鑾峰彇褰撳墠绯荤粺鏃堕棿
				local current_time=$(date +"%Y-%m-%d %H:%M:%S")

				# 鏄剧ず鏃跺尯鍜屾椂闂�
				echo "褰撳墠绯荤粺鏃跺尯锛�$timezone"
				echo "褰撳墠绯荤粺鏃堕棿锛�$current_time"

				echo ""
				echo "鏃跺尯鍒囨崲"
				echo "------------------------"
				echo "浜氭床"
				echo "1.  涓浗涓婃捣鏃堕棿             2.  涓浗棣欐腐鏃堕棿"
				echo "3.  鏃ユ湰涓滀含鏃堕棿             4.  闊╁浗棣栧皵鏃堕棿"
				echo "5.  鏂板姞鍧℃椂闂�               6.  鍗板害鍔犲皵鍚勭瓟鏃堕棿"
				echo "7.  闃胯仈閰嬭开鎷滄椂闂�           8.  婢冲ぇ鍒╀簹鎮夊凹鏃堕棿"
				echo "9.  娉板浗鏇艰胺鏃堕棿"
				echo "------------------------"
				echo "娆ф床"
				echo "11. 鑻卞浗浼︽暒鏃堕棿             12. 娉曞浗宸撮粠鏃堕棿"
				echo "13. 寰峰浗鏌忔灄鏃堕棿             14. 淇勭綏鏂帿鏂鏃堕棿"
				echo "15. 鑽峰叞灏ょ壒璧栬但鐗规椂闂�       16. 瑗跨彮鐗欓┈寰烽噷鏃堕棿"
				echo "------------------------"
				echo "缇庢床"
				echo "21. 缇庡浗瑗块儴鏃堕棿             22. 缇庡浗涓滈儴鏃堕棿"
				echo "23. 鍔犳嬁澶ф椂闂�               24. 澧ㄨタ鍝ユ椂闂�"
				echo "25. 宸磋タ鏃堕棿                 26. 闃挎牴寤锋椂闂�"
				echo "------------------------"
				echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				echo "------------------------"
				read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice


				case $sub_choice in
					1) set_timedate Asia/Shanghai ;;
					2) set_timedate Asia/Hong_Kong ;;
					3) set_timedate Asia/Tokyo ;;
					4) set_timedate Asia/Seoul ;;
					5) set_timedate Asia/Singapore ;;
					6) set_timedate Asia/Kolkata ;;
					7) set_timedate Asia/Dubai ;;
					8) set_timedate Australia/Sydney ;;
					9) set_timedate Asia/Bangkok ;;
					11) set_timedate Europe/London ;;
					12) set_timedate Europe/Paris ;;
					13) set_timedate Europe/Berlin ;;
					14) set_timedate Europe/Moscow ;;
					15) set_timedate Europe/Amsterdam ;;
					16) set_timedate Europe/Madrid ;;
					21) set_timedate America/Los_Angeles ;;
					22) set_timedate America/New_York ;;
					23) set_timedate America/Vancouver ;;
					24) set_timedate America/Mexico_City ;;
					25) set_timedate America/Sao_Paulo ;;
					26) set_timedate America/Argentina/Buenos_Aires ;;
					0) break ;; # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
					*) break ;; # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
				esac
			done
			  ;;

		  16)

			bbrv3
			  ;;

		  17)
		  root_use
		  while true; do
			if dpkg -l | grep -q iptables-persistent; then
				  clear
				  echo "楂樼骇闃茬伀澧欑鐞�"
				  send_stats "楂樼骇闃茬伀澧欑鐞�"
				  echo "------------------------"
				  iptables -L INPUT

				  echo ""
				  echo "闃茬伀澧欑鐞�"
				  echo "------------------------"
				  echo "1.  寮€鏀炬寚瀹氱鍙�                 2.  鍏抽棴鎸囧畾绔彛"
				  echo "3.  寮€鏀炬墍鏈夌鍙�                 4.  鍏抽棴鎵€鏈夌鍙�"
				  echo "------------------------"
				  echo "5.  IP鐧藉悕鍗�                  	 6.  IP榛戝悕鍗�"
				  echo "7.  娓呴櫎鎸囧畾IP"
				  echo "------------------------"
				  echo "11. 鍏佽PING                  	 12. 绂佹PING"
				  echo "------------------------"
				  echo "99. 鍗歌浇闃茬伀澧�"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						   read -e -p "璇疯緭鍏ュ紑鏀剧殑绔彛鍙�: " o_port
						   sed -i "/COMMIT/i -A INPUT -p tcp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
						   sed -i "/COMMIT/i -A INPUT -p udp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
						   iptables-restore < /etc/iptables/rules.v4
						   send_stats "寮€鏀炬寚瀹氱鍙�"

						  ;;
					  2)
						  read -e -p "璇疯緭鍏ュ叧闂殑绔彛鍙�: " c_port
						  sed -i "/--dport $c_port/d" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "鍏抽棴鎸囧畾绔彛"
						  ;;

					  3)
						  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

						  cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "寮€鏀炬墍鏈夌鍙�"
						  ;;
					  4)
						  current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

						  cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "鍏抽棴鎵€鏈夌鍙�"
						  ;;

					  5)
						  read -e -p "璇疯緭鍏ユ斁琛岀殑IP: " o_ip
						  sed -i "/COMMIT/i -A INPUT -s $o_ip -j ACCEPT" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "IP鐧藉悕鍗�"
						  ;;

					  6)
						  read -e -p "璇疯緭鍏ュ皝閿佺殑IP: " c_ip
						  sed -i "/COMMIT/i -A INPUT -s $c_ip -j DROP" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "IP榛戝悕鍗�"
						  ;;

					  7)
						  read -e -p "璇疯緭鍏ユ竻闄ょ殑IP: " d_ip
						  sed -i "/-A INPUT -s $d_ip/d" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "娓呴櫎鎸囧畾IP"
						  ;;

					  11)
						  sed -i '$i -A INPUT -p icmp --icmp-type echo-request -j ACCEPT' /etc/iptables/rules.v4
						  sed -i '$i -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT' /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "鍏佽ping"
						  ;;

					  12)
						  sed -i "/icmp/d" /etc/iptables/rules.v4
						  iptables-restore < /etc/iptables/rules.v4
						  send_stats "绂佺敤ping"
						  ;;

					  99)
						  remove iptables-persistent
						  rm /etc/iptables/rules.v4
						  send_stats "鍗歌浇闃茬伀澧�"
						  break

						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

				  esac
			else

				clear
				echo "灏嗕负浣犲畨瑁呴槻鐏锛岃闃茬伀澧欎粎鏀寔Debian/Ubuntu"
				echo "------------------------------------------------"
				read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

				case "$choice" in
				  [Yy])
					if [ -r /etc/os-release ]; then
						. /etc/os-release
						if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
							echo "褰撳墠鐜涓嶆敮鎸侊紝浠呮敮鎸丏ebian鍜孶buntu绯荤粺"
							break_end
							linux_Settings
						fi
					else
						echo "鏃犳硶纭畾鎿嶄綔绯荤粺绫诲瀷"
						break
					fi

					clear
					iptables_open
					remove iptables-persistent ufw
					rm /etc/iptables/rules.v4

					apt update -y && apt install -y iptables-persistent

					local current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

					cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF

					iptables-restore < /etc/iptables/rules.v4
					systemctl enable netfilter-persistent
					echo "闃茬伀澧欏畨瑁呭畬鎴�"
					break_end
					;;
				  *)
					echo "宸插彇娑�"
					break
					;;
				esac
			fi
		  done
			  ;;

		  18)
		  root_use
		  send_stats "淇敼涓绘満鍚�"

		  while true; do
			  clear
			  local current_hostname=$(uname -n)
			  echo -e "褰撳墠涓绘満鍚�: ${gl_huang}$current_hostname${gl_bai}"
			  echo "------------------------"
			  read -e -p "璇疯緭鍏ユ柊鐨勪富鏈哄悕锛堣緭鍏�0閫€鍑猴級: " new_hostname
			  if [ -n "$new_hostname" ] && [ "$new_hostname" != "0" ]; then
				  if [ -f /etc/alpine-release ]; then
					  # Alpine
					  echo "$new_hostname" > /etc/hostname
					  hostname "$new_hostname"
				  else
					  # 鍏朵粬绯荤粺锛屽 Debian, Ubuntu, CentOS 绛�
					  hostnamectl set-hostname "$new_hostname"
					  sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
					  systemctl restart systemd-hostnamed
				  fi

				  if grep -q "127.0.0.1" /etc/hosts; then
					  sed -i "s/127.0.0.1 .*/127.0.0.1       $new_hostname localhost localhost.localdomain/g" /etc/hosts
				  else
					  echo "127.0.0.1       $new_hostname localhost localhost.localdomain" >> /etc/hosts
				  fi

				  if grep -q "^::1" /etc/hosts; then
					  sed -i "s/^::1 .*/::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback/g" /etc/hosts
				  else
					  echo "::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback" >> /etc/hosts
				  fi

				  echo "涓绘満鍚嶅凡鏇存敼涓�: $new_hostname"
				  send_stats "涓绘満鍚嶅凡鏇存敼"
				  sleep 1
			  else
				  echo "宸查€€鍑猴紝鏈洿鏀逛富鏈哄悕銆�"
				  break
			  fi
		  done
			  ;;

		  19)
		  root_use
		  send_stats "鎹㈢郴缁熸洿鏂版簮"
		  clear
		  echo "閫夋嫨鏇存柊婧愬尯鍩�"
		  echo "鎺ュ叆LinuxMirrors鍒囨崲绯荤粺鏇存柊婧�"
		  echo "------------------------"
		  echo "1. 涓浗澶ч檰銆愰粯璁ゃ€�          2. 涓浗澶ч檰銆愭暀鑲茬綉銆�          3. 娴峰鍦板尯"
		  echo "------------------------"
		  echo "0. 杩斿洖涓婁竴绾�"
		  echo "------------------------"
		  read -e -p "杈撳叆浣犵殑閫夋嫨: " choice

		  case $choice in
			  1)
				  send_stats "涓浗澶ч檰榛樿婧�"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh)
				  ;;
			  2)
				  send_stats "涓浗澶ч檰鏁欒偛婧�"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh) --edu
				  ;;
			  3)
				  send_stats "娴峰婧�"
				  bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad
				  ;;
			  *)
				  echo "宸插彇娑�"
				  ;;

		  esac

			  ;;

		  20)
		  send_stats "瀹氭椂浠诲姟绠＄悊"
			  while true; do
				  clear
				  check_crontab_installed
				  clear
				  echo "瀹氭椂浠诲姟鍒楄〃"
				  crontab -l
				  echo ""
				  echo "鎿嶄綔"
				  echo "------------------------"
				  echo "1. 娣诲姞瀹氭椂浠诲姟              2. 鍒犻櫎瀹氭椂浠诲姟              3. 缂栬緫瀹氭椂浠诲姟"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						  read -e -p "璇疯緭鍏ユ柊浠诲姟鐨勬墽琛屽懡浠�: " newquest
						  echo "------------------------"
						  echo "1. 姣忔湀浠诲姟                 2. 姣忓懆浠诲姟"
						  echo "3. 姣忓ぉ浠诲姟                 4. 姣忓皬鏃朵换鍔�"
						  echo "------------------------"
						  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " dingshi

						  case $dingshi in
							  1)
								  read -e -p "閫夋嫨姣忔湀鐨勫嚑鍙锋墽琛屼换鍔★紵 (1-30): " day
								  (crontab -l ; echo "0 0 $day * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  2)
								  read -e -p "閫夋嫨鍛ㄥ嚑鎵ц浠诲姟锛� (0-6锛�0浠ｈ〃鏄熸湡鏃�): " weekday
								  (crontab -l ; echo "0 0 * * $weekday $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  3)
								  read -e -p "閫夋嫨姣忓ぉ鍑犵偣鎵ц浠诲姟锛燂紙灏忔椂锛�0-23锛�: " hour
								  (crontab -l ; echo "0 $hour * * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  4)
								  read -e -p "杈撳叆姣忓皬鏃剁殑绗嚑鍒嗛挓鎵ц浠诲姟锛燂紙鍒嗛挓锛�0-60锛�: " minute
								  (crontab -l ; echo "$minute * * * * $newquest") | crontab - > /dev/null 2>&1
								  ;;
							  *)
								  break  # 璺冲嚭
								  ;;
						  esac
						  send_stats "娣诲姞瀹氭椂浠诲姟"
						  ;;
					  2)
						  read -e -p "璇疯緭鍏ラ渶瑕佸垹闄や换鍔＄殑鍏抽敭瀛�: " kquest
						  crontab -l | grep -v "$kquest" | crontab -
						  send_stats "鍒犻櫎瀹氭椂浠诲姟"
						  ;;
					  3)
						  crontab -e
						  send_stats "缂栬緫瀹氭椂浠诲姟"
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done

			  ;;

		  21)
			  root_use
			  send_stats "鏈湴host瑙ｆ瀽"
			  while true; do
				  clear
				  echo "鏈満host瑙ｆ瀽鍒楄〃"
				  echo "濡傛灉浣犲湪杩欓噷娣诲姞瑙ｆ瀽鍖归厤锛屽皢涓嶅啀浣跨敤鍔ㄦ€佽В鏋愪簡"
				  cat /etc/hosts
				  echo ""
				  echo "鎿嶄綔"
				  echo "------------------------"
				  echo "1. 娣诲姞鏂扮殑瑙ｆ瀽              2. 鍒犻櫎瑙ｆ瀽鍦板潃"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " host_dns

				  case $host_dns in
					  1)
						  read -e -p "璇疯緭鍏ユ柊鐨勮В鏋愯褰� 鏍煎紡: 110.25.5.33 kejilion.pro : " addhost
						  echo "$addhost" >> /etc/hosts
						  send_stats "鏈湴host瑙ｆ瀽鏂板"

						  ;;
					  2)
						  read -e -p "璇疯緭鍏ラ渶瑕佸垹闄ょ殑瑙ｆ瀽鍐呭鍏抽敭瀛�: " delhost
						  sed -i "/$delhost/d" /etc/hosts
						  send_stats "鏈湴host瑙ｆ瀽鍒犻櫎"
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done
			  ;;

		  22)
		  root_use
		  send_stats "ssh闃插尽"
		  while true; do
			if docker inspect fail2ban &>/dev/null ; then
					clear
					echo "SSH闃插尽绋嬪簭宸插惎鍔�"
					echo "------------------------"
					echo "1. 鏌ョ湅SSH鎷︽埅璁板綍"
					echo "2. 鏃ュ織瀹炴椂鐩戞帶"
					echo "------------------------"
					echo "9. 鍗歌浇闃插尽绋嬪簭"
					echo "------------------------"
					echo "0. 閫€鍑�"
					echo "------------------------"
					read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
					case $sub_choice in

						1)
							echo "------------------------"
							f2b_sshd
							echo "------------------------"
							break_end
							;;
						2)
							tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log
							break
							;;
						9)
							docker rm -f fail2ban
							rm -rf /path/to/fail2ban
							echo "Fail2Ban闃插尽绋嬪簭宸插嵏杞�"
							break
							;;
						*)
							echo "宸插彇娑�"
							break
							;;
					esac

			elif [ -x "$(command -v fail2ban-client)" ] ; then
				clear
				echo "鍗歌浇鏃х増fail2ban"
				read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice
				case "$choice" in
				  [Yy])
					remove fail2ban
					rm -rf /etc/fail2ban
					echo "Fail2Ban闃插尽绋嬪簭宸插嵏杞�"
					break_end
					;;
				  *)
					echo "宸插彇娑�"
					break
					;;
				esac

			else

			  clear
			  echo "fail2ban鏄竴涓猄SH闃叉鏆村姏鐮磋В宸ュ叿"
			  echo "瀹樼綉浠嬬粛: ${gh_proxy}https://github.com/fail2ban/fail2ban"
			  echo "------------------------------------------------"
			  echo "宸ヤ綔鍘熺悊锛氱爺鍒ら潪娉旾P鎭舵剰楂橀璁块棶SSH绔彛锛岃嚜鍔ㄨ繘琛孖P灏侀攣"
			  echo "------------------------------------------------"
			  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  install_docker
				  f2b_install_sshd

				  cd ~
				  f2b_status
				  echo "Fail2Ban闃插尽绋嬪簭宸插紑鍚�"
				  send_stats "ssh闃插尽瀹夎瀹屾垚"
				  break_end
				  ;;
				*)
				  echo "宸插彇娑�"
				  break
				  ;;
			  esac
			fi
		  done
			  ;;


		  23)
			root_use
			send_stats "闄愭祦鍏虫満鍔熻兘"
			while true; do
				clear
				echo "闄愭祦鍏虫満鍔熻兘"
				echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1mC411j7Qd?t=0.1"
				echo "------------------------------------------------"
				echo "褰撳墠娴侀噺浣跨敤鎯呭喌锛岄噸鍚湇鍔″櫒娴侀噺璁＄畻浼氭竻闆讹紒"
				output_status
				echo "$output"

				# 妫€鏌ユ槸鍚﹀瓨鍦� Limiting_Shut_down.sh 鏂囦欢
				if [ -f ~/Limiting_Shut_down.sh ]; then
					# 鑾峰彇 threshold_gb 鐨勫€�
					local rx_threshold_gb=$(grep -oP 'rx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
					local tx_threshold_gb=$(grep -oP 'tx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
					echo -e "${gl_lv}褰撳墠璁剧疆鐨勮繘绔欓檺娴侀槇鍊间负: ${gl_huang}${rx_threshold_gb}${gl_lv}GB${gl_bai}"
					echo -e "${gl_lv}褰撳墠璁剧疆鐨勫嚭绔欓檺娴侀槇鍊间负: ${gl_huang}${tx_threshold_gb}${gl_lv}GB${gl_bai}"
				else
					echo -e "${gl_hui}褰撳墠鏈惎鐢ㄩ檺娴佸叧鏈哄姛鑳�${gl_bai}"
				fi

				echo
				echo "------------------------------------------------"
				echo "绯荤粺姣忓垎閽熶細妫€娴嬪疄闄呮祦閲忔槸鍚﹀埌杈鹃槇鍊硷紝鍒拌揪鍚庝細鑷姩鍏抽棴鏈嶅姟鍣紒"
				read -e -p "1. 寮€鍚檺娴佸叧鏈哄姛鑳�    2. 鍋滅敤闄愭祦鍏虫満鍔熻兘    0. 閫€鍑�  : " Limiting

				case "$Limiting" in
				  1)
					# 杈撳叆鏂扮殑铏氭嫙鍐呭瓨澶у皬
					echo "濡傛灉瀹為檯鏈嶅姟鍣ㄥ氨100G娴侀噺锛屽彲璁剧疆闃堝€间负95G锛屾彁鍓嶅叧鏈猴紝浠ュ厤鍑虹幇娴侀噺璇樊鎴栨孩鍑�."
					read -e -p "璇疯緭鍏ヨ繘绔欐祦閲忛槇鍊硷紙鍗曚綅涓篏B锛�: " rx_threshold_gb
					read -e -p "璇疯緭鍏ュ嚭绔欐祦閲忛槇鍊硷紙鍗曚綅涓篏B锛�: " tx_threshold_gb
					read -e -p "璇疯緭鍏ユ祦閲忛噸缃棩鏈燂紙榛樿姣忔湀1鏃ラ噸缃級: " cz_day
					local cz_day=${cz_day:-1}

					cd ~
					curl -Ss -o ~/Limiting_Shut_down.sh ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/Limiting_Shut_down1.sh
					chmod +x ~/Limiting_Shut_down.sh
					sed -i "s/110/$rx_threshold_gb/g" ~/Limiting_Shut_down.sh
					sed -i "s/120/$tx_threshold_gb/g" ~/Limiting_Shut_down.sh
					check_crontab_installed
					crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
					(crontab -l ; echo "* * * * * ~/Limiting_Shut_down.sh") | crontab - > /dev/null 2>&1
					crontab -l | grep -v 'reboot' | crontab -
					(crontab -l ; echo "0 1 $cz_day * * reboot") | crontab - > /dev/null 2>&1
					echo "闄愭祦鍏虫満宸茶缃�"
					send_stats "闄愭祦鍏虫満宸茶缃�"
					;;
				  2)
					check_crontab_installed
					crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
					crontab -l | grep -v 'reboot' | crontab -
					rm ~/Limiting_Shut_down.sh
					echo "宸插叧闂檺娴佸叧鏈哄姛鑳�"
					;;
				  *)
					break
					;;
				esac
			done
			  ;;


		  24)
			  root_use
			  send_stats "绉侀挜鐧诲綍"
			  echo "ROOT绉侀挜鐧诲綍妯″紡"
			  echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1Q4421X78n?t=209.4"
			  echo "------------------------------------------------"
			  echo "灏嗕細鐢熸垚瀵嗛挜瀵癸紝鏇村畨鍏ㄧ殑鏂瑰紡SSH鐧诲綍"
			  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  send_stats "绉侀挜鐧诲綍浣跨敤"
				  add_sshkey
				  ;;
				[Nn])
				  echo "宸插彇娑�"
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac

			  ;;

		  25)
			  root_use
			  send_stats "鐢垫姤棰勮"
			  echo "TG-bot鐩戞帶棰勮鍔熻兘"
			  echo "瑙嗛浠嬬粛: https://youtu.be/vLL-eb3Z_TY"
			  echo "------------------------------------------------"
			  echo "鎮ㄩ渶瑕侀厤缃畉g鏈哄櫒浜篈PI鍜屾帴鏀堕璀︾殑鐢ㄦ埛ID锛屽嵆鍙疄鐜版湰鏈篊PU锛屽唴瀛橈紝纭洏锛屾祦閲忥紝SSH鐧诲綍鐨勫疄鏃剁洃鎺ч璀�"
			  echo "鍒拌揪闃堝€煎悗浼氬悜鐢ㄦ埛鍙戦璀︽秷鎭�"
			  echo -e "${gl_hui}-鍏充簬娴侀噺锛岄噸鍚湇鍔″櫒灏嗛噸鏂拌绠�-${gl_bai}"
			  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

			  case "$choice" in
				[Yy])
				  send_stats "鐢垫姤棰勮鍚敤"
				  cd ~
				  install nano tmux bc jq
				  check_crontab_installed
				  if [ -f ~/TG-check-notify.sh ]; then
					  chmod +x ~/TG-check-notify.sh
					  nano ~/TG-check-notify.sh
				  else
					  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/TG-check-notify.sh
					  chmod +x ~/TG-check-notify.sh
					  nano ~/TG-check-notify.sh
				  fi
				  tmux kill-session -t TG-check-notify > /dev/null 2>&1
				  tmux new -d -s TG-check-notify "~/TG-check-notify.sh"
				  crontab -l | grep -v '~/TG-check-notify.sh' | crontab - > /dev/null 2>&1
				  (crontab -l ; echo "@reboot tmux new -d -s TG-check-notify '~/TG-check-notify.sh'") | crontab - > /dev/null 2>&1

				  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/TG-SSH-check-notify.sh > /dev/null 2>&1
				  sed -i "3i$(grep '^TELEGRAM_BOT_TOKEN=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh > /dev/null 2>&1
				  sed -i "4i$(grep '^CHAT_ID=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh
				  chmod +x ~/TG-SSH-check-notify.sh

				  # 娣诲姞鍒� ~/.profile 鏂囦欢涓�
				  if ! grep -q 'bash ~/TG-SSH-check-notify.sh' ~/.profile > /dev/null 2>&1; then
					  echo 'bash ~/TG-SSH-check-notify.sh' >> ~/.profile
					  if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
						 echo 'source ~/.profile' >> ~/.bashrc
					  fi
				  fi

				  source ~/.profile

				  clear
				  echo "TG-bot棰勮绯荤粺宸插惎鍔�"
				  echo -e "${gl_hui}浣犺繕鍙互灏唕oot鐩綍涓殑TG-check-notify.sh棰勮鏂囦欢鏀惧埌鍏朵粬鏈哄櫒涓婄洿鎺ヤ娇鐢紒${gl_bai}"
				  ;;
				[Nn])
				  echo "宸插彇娑�"
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			  ;;

		  26)
			  root_use
			  send_stats "淇SSH楂樺嵄婕忔礊"
			  cd ~
			  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/upgrade_openssh9.8p1.sh
			  chmod +x ~/upgrade_openssh9.8p1.sh
			  ~/upgrade_openssh9.8p1.sh
			  rm -f ~/upgrade_openssh9.8p1.sh
			  ;;

		  27)
			  elrepo
			  ;;
		  28)
			  Kernel_optimize
			  ;;

		  29)
			  clamav
			  ;;

		  30)
			  linux_file
			  ;;

		  31)
			  linux_language
			  ;;

		  32)
			  shell_bianse
			  ;;
		  33)
			  linux_trash
			  ;;
		  41)
			clear
			send_stats "鐣欒█鏉�"
			echo "绉戞妧lion鐣欒█鏉垮凡杩佺Щ鑷冲畼鏂圭ぞ鍖猴紒璇峰湪瀹樻柟绀惧尯杩涜鐣欒█鍣紒"
			echo "https://bbs.kejilion.pro/"
			  ;;

		  66)

			  root_use
			  send_stats "涓€鏉￠緳璋冧紭"
			  echo "涓€鏉￠緳绯荤粺璋冧紭"
			  echo "------------------------------------------------"
			  echo "灏嗗浠ヤ笅鍐呭杩涜鎿嶄綔涓庝紭鍖�"
			  echo "1. 鏇存柊绯荤粺鍒版渶鏂�"
			  echo "2. 娓呯悊绯荤粺鍨冨溇鏂囦欢"
			  echo -e "3. 璁剧疆铏氭嫙鍐呭瓨${gl_huang}1G${gl_bai}"
			  echo -e "4. 璁剧疆SSH绔彛鍙蜂负${gl_huang}5522${gl_bai}"
			  echo -e "5. 寮€鏀炬墍鏈夌鍙�"
			  echo -e "6. 寮€鍚�${gl_huang}BBR${gl_bai}鍔犻€�"
			  echo -e "7. 璁剧疆鏃跺尯鍒�${gl_huang}涓婃捣${gl_bai}"
			  echo -e "8. 鑷姩浼樺寲DNS鍦板潃${gl_huang}娴峰: 1.1.1.1 8.8.8.8  鍥藉唴: 223.5.5.5 ${gl_bai}"
			  echo -e "9. 瀹夎鍩虹宸ュ叿${gl_huang}docker wget sudo tar unzip socat btop nano vim${gl_bai}"
			  echo -e "10. Linux绯荤粺鍐呮牳鍙傛暟浼樺寲鍒囨崲鍒�${gl_huang}鍧囪　浼樺寲妯″紡${gl_bai}"
			  echo "------------------------------------------------"
			  read -e -p "纭畾涓€閿繚鍏诲悧锛�(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  send_stats "涓€鏉￠緳璋冧紭鍚姩"
				  echo "------------------------------------------------"
				  linux_update
				  echo -e "[${gl_lv}OK${gl_bai}] 1/10. 鏇存柊绯荤粺鍒版渶鏂�"

				  echo "------------------------------------------------"
				  linux_clean
				  echo -e "[${gl_lv}OK${gl_bai}] 2/10. 娓呯悊绯荤粺鍨冨溇鏂囦欢"

				  echo "------------------------------------------------"
				  add_swap 1024
				  echo -e "[${gl_lv}OK${gl_bai}] 3/10. 璁剧疆铏氭嫙鍐呭瓨${gl_huang}1G${gl_bai}"

				  echo "------------------------------------------------"
				  local new_port=5522
				  new_ssh_port
				  echo -e "[${gl_lv}OK${gl_bai}] 4/10. 璁剧疆SSH绔彛鍙蜂负${gl_huang}5522${gl_bai}"
				  echo "------------------------------------------------"
				  echo -e "[${gl_lv}OK${gl_bai}] 5/10. 寮€鏀炬墍鏈夌鍙�"

				  echo "------------------------------------------------"
				  bbr_on
				  echo -e "[${gl_lv}OK${gl_bai}] 6/10. 寮€鍚�${gl_huang}BBR${gl_bai}鍔犻€�"

				  echo "------------------------------------------------"
				  set_timedate Asia/Shanghai
				  echo -e "[${gl_lv}OK${gl_bai}] 7/10. 璁剧疆鏃跺尯鍒�${gl_huang}涓婃捣${gl_bai}"

				  echo "------------------------------------------------"
				  local country=$(curl -s ipinfo.io/country)
				  if [ "$country" = "CN" ]; then
					 local dns1_ipv4="223.5.5.5"
					 local dns2_ipv4="183.60.83.19"
					 local dns1_ipv6="2400:3200::1"
					 local dns2_ipv6="2400:da00::6666"
				  else
					 local dns1_ipv4="1.1.1.1"
					 local dns2_ipv4="8.8.8.8"
					 local dns1_ipv6="2606:4700:4700::1111"
					 local dns2_ipv6="2001:4860:4860::8888"
				  fi

				  set_dns
				  echo -e "[${gl_lv}OK${gl_bai}] 8/10. 鑷姩浼樺寲DNS鍦板潃${gl_huang}${gl_bai}"

				  echo "------------------------------------------------"
				  install_docker
				  install wget sudo tar unzip socat btop nano vim
				  echo -e "[${gl_lv}OK${gl_bai}] 9/10. 瀹夎鍩虹宸ュ叿${gl_huang}docker wget sudo tar unzip socat btop${gl_bai}"
				  echo "------------------------------------------------"

				  echo "------------------------------------------------"
				  optimize_balanced
				  echo -e "[${gl_lv}OK${gl_bai}] 10/10. Linux绯荤粺鍐呮牳鍙傛暟浼樺寲"
				  echo -e "${gl_lv}涓€鏉￠緳绯荤粺璋冧紭宸插畬鎴�${gl_bai}"

				  ;;
				[Nn])
				  echo "宸插彇娑�"
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac

			  ;;

		  99)
			  clear
			  send_stats "閲嶅惎绯荤粺"
			  server_reboot
			  ;;
		  100)

			root_use
			while true; do
			  clear
			  if grep -q '^ENABLE_STATS="true"' /usr/local/bin/k > /dev/null 2>&1; then
			  	local status_message="${gl_lv}姝ｅ湪閲囬泦鏁版嵁${gl_bai}"
			  elif grep -q '^ENABLE_STATS="false"' /usr/local/bin/k > /dev/null 2>&1; then
			  	local status_message="${gl_hui}閲囬泦宸插叧闂�${gl_bai}"
			  else
			  	local status_message="鏃犳硶纭畾鐨勭姸鎬�"
			  fi

			  echo "闅愮涓庡畨鍏�"
			  echo "鑴氭湰灏嗘敹闆嗙敤鎴蜂娇鐢ㄥ姛鑳界殑鏁版嵁锛屼紭鍖栬剼鏈綋楠岋紝鍒朵綔鏇村濂界帺濂界敤鐨勫姛鑳�"
			  echo "灏嗘敹闆嗚剼鏈増鏈彿锛屼娇鐢ㄧ殑鏃堕棿锛岀郴缁熺増鏈紝CPU鏋舵瀯锛屾満鍣ㄦ墍灞炲浗瀹跺拰浣跨敤鐨勫姛鑳界殑鍚嶇О锛�"
			  echo "------------------------------------------------"
			  echo -e "褰撳墠鐘舵€�: $status_message"
			  echo "--------------------"
			  echo "1. 寮€鍚噰闆�"
			  echo "2. 鍏抽棴閲囬泦"
			  echo "--------------------"
			  echo "0. 杩斿洖涓婁竴绾�"
			  echo "--------------------"
			  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice
			  case $sub_choice in
				  1)
					  cd ~
					  sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' /usr/local/bin/k
					  sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' ~/kejilion.sh
					  echo "宸插紑鍚噰闆�"
					  send_stats "闅愮涓庡畨鍏ㄥ凡寮€鍚噰闆�"
					  ;;
				  2)
					  cd ~
					  sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' /usr/local/bin/k
					  sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/kejilion.sh
					  echo "宸插叧闂噰闆�"
					  send_stats "闅愮涓庡畨鍏ㄥ凡鍏抽棴閲囬泦"
					  ;;
				  0)
					  break
					  ;;
				  *)
					  echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆銆�"
					  ;;
			  esac
			done
			  ;;

		  101)
			  clear
			  send_stats "鍗歌浇绉戞妧lion鑴氭湰"
			  echo "鍗歌浇绉戞妧lion鑴氭湰"
			  echo "------------------------------------------------"
			  echo "灏嗗交搴曞嵏杞絢ejilion鑴氭湰锛屼笉褰卞搷浣犲叾浠栧姛鑳�"
			  read -e -p "纭畾缁х画鍚楋紵(Y/N): " choice

			  case "$choice" in
				[Yy])
				  clear
				  rm -f /usr/local/bin/k
				  rm ~/kejilion.sh
				  echo "鑴氭湰宸插嵏杞斤紝鍐嶈锛�"
				  break_end
				  clear
				  exit
				  ;;
				[Nn])
				  echo "宸插彇娑�"
				  ;;
				*)
				  echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				  ;;
			  esac
			  ;;

		  0)
			  kejilion

			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done



}


linux_cluster() {

	clear
	send_stats "闆嗙兢鎺у埗"
	while true; do
	  clear
	  echo -e "鈻� 鏈嶅姟鍣ㄩ泦缇ゆ帶鍒�"
	  echo -e "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1hH4y1j74M?t=0.1"
	  echo -e "浣犲彲浠ヨ繙绋嬫搷鎺у鍙癡PS涓€璧锋墽琛屼换鍔★紙浠呮敮鎸乁buntu/Debian锛�"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}1.   ${gl_bai}瀹夎闆嗙兢鐜"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}2.   ${gl_bai}闆嗙兢鎺у埗涓績 ${gl_huang}鈽�${gl_bai}"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}7.   ${gl_bai}澶囦唤闆嗙兢鐜"
	  echo -e "${gl_kjlan}8.   ${gl_bai}杩樺師闆嗙兢鐜"
	  echo -e "${gl_kjlan}9.   ${gl_bai}鍗歌浇闆嗙兢鐜"
	  echo -e "${gl_kjlan}------------------------"
	  echo -e "${gl_kjlan}0.   ${gl_bai}杩斿洖涓昏彍鍗�"
	  echo -e "${gl_kjlan}------------------------${gl_bai}"
	  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

	  case $sub_choice in
		  1)
			clear
			send_stats "瀹夎闆嗙兢鐜"
			install python3 python3-paramiko speedtest-cli lrzsz
			mkdir cluster && cd cluster
			touch servers.py

			cat > ./servers.py << EOF
servers = [

]
EOF

			  ;;
		  2)

			  while true; do
				  clear
				  send_stats "闆嗙兢鎺у埗涓績"
				  echo "闆嗙兢鏈嶅姟鍣ㄥ垪琛�"
				  cat ~/cluster/servers.py

				  echo ""
				  echo "鎿嶄綔"
				  echo "------------------------"
				  echo "1. 娣诲姞鏈嶅姟鍣�                2. 鍒犻櫎鏈嶅姟鍣�             3. 缂栬緫鏈嶅姟鍣�"
				  echo "------------------------"
				  echo "11. 瀹夎绉戞妧lion鑴氭湰         12. 鏇存柊绯荤粺              13. 娓呯悊绯荤粺"
				  echo "14. 瀹夎docker               15. 瀹夎BBR3              16. 璁剧疆1G铏氭嫙鍐呭瓨"
				  echo "17. 璁剧疆鏃跺尯鍒颁笂娴�           18. 寮€鏀炬墍鏈夌鍙�"
				  echo "------------------------"
				  echo "51. 鑷畾涔夋寚浠�"
				  echo "------------------------"
				  echo "0. 杩斿洖涓婁竴绾ч€夊崟"
				  echo "------------------------"
				  read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " sub_choice

				  case $sub_choice in
					  1)
						  send_stats "娣诲姞闆嗙兢鏈嶅姟鍣�"
						  read -e -p "鏈嶅姟鍣ㄥ悕绉�: " server_name
						  read -e -p "鏈嶅姟鍣↖P: " server_ip
						  read -e -p "鏈嶅姟鍣ㄧ鍙ｏ紙22锛�: " server_port
						  local server_port=${server_port:-22}
						  read -e -p "鏈嶅姟鍣ㄧ敤鎴峰悕锛坮oot锛�: " server_username
						  local server_username=${server_username:-root}
						  read -e -p "鏈嶅姟鍣ㄧ敤鎴峰瘑鐮�: " server_password

						  sed -i "/servers = \[/a\    {\"name\": \"$server_name\", \"hostname\": \"$server_ip\", \"port\": $server_port, \"username\": \"$server_username\", \"password\": \"$server_password\", \"remote_path\": \"/home/\"}," ~/cluster/servers.py

						  ;;
					  2)
						  send_stats "鍒犻櫎闆嗙兢鏈嶅姟鍣�"
						  read -e -p "璇疯緭鍏ラ渶瑕佸垹闄ょ殑鍏抽敭瀛�: " rmserver
						  sed -i "/$rmserver/d" ~/cluster/servers.py
						  ;;
					  3)
						  send_stats "缂栬緫闆嗙兢鏈嶅姟鍣�"
						  install nano
						  nano ~/cluster/servers.py
						  ;;
					  11)
						  local py_task="install_kejilion.py"
						  cluster_python3
						  ;;
					  12)
						  local py_task="update.py"
						  cluster_python3
						  ;;
					  13)
						  local py_task="clean.py"
						  cluster_python3
						  ;;
					  14)
						  local py_task="install_docker.py"
						  cluster_python3
						  ;;
					  15)
						  local py_task="install_bbr3.py"
						  cluster_python3
						  ;;
					  16)
						  local py_task="swap1024.py"
						  cluster_python3
						  ;;
					  17)
						  local py_task="time_shanghai.py"
						  cluster_python3
						  ;;
					  18)
						  local py_task="firewall_close.py"
						  cluster_python3
						  ;;
					  51)
						  send_stats "鑷畾涔夋墽琛屽懡浠�"
						  read -e -p "璇疯緭鍏ユ壒閲忔墽琛岀殑鍛戒护: " mingling
						  local py_task="custom_tasks.py"
						  cd ~/cluster/
						  curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/python-for-vps/main/cluster/$py_task
						  sed -i "s#Customtasks#$mingling#g" ~/cluster/$py_task
						  python3 ~/cluster/$py_task
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
					  0)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;

					  *)
						  break  # 璺冲嚭寰幆锛岄€€鍑鸿彍鍗�
						  ;;
				  esac
			  done

			  ;;
		  7)
			clear
			send_stats "澶囦唤闆嗙兢"
			echo "灏嗕笅杞芥湇鍔″櫒鍒楄〃鏁版嵁锛屾寜浠绘剰閿笅杞斤紒"
			read -n 1 -s -r -p ""
			sz -y ~/cluster/servers.py

			  ;;

		  8)
			clear
			send_stats "杩樺師闆嗙兢"
			echo "璇蜂笂浼犳偍鐨剆ervers.py锛屾寜浠绘剰閿紑濮嬩笂浼狅紒"
			read -n 1 -s -r -p ""
			cd ~/cluster/
			rz -y
			  ;;

		  9)

			clear
			send_stats "鍗歌浇闆嗙兢"
			read -e -p "璇峰厛澶囦唤鐜锛岀‘瀹氳鍗歌浇闆嗙兢鎺у埗鐜鍚楋紵(Y/N): " choice
			case "$choice" in
			  [Yy])
				remove python3-paramiko speedtest-cli lrzsz
				rm -rf ~/cluster/
				;;
			  [Nn])
				echo "宸插彇娑�"
				;;
			  *)
				echo "鏃犳晥鐨勯€夋嫨锛岃杈撳叆 Y 鎴� N銆�"
				;;
			esac

			  ;;

		  0)
			  kejilion
			  ;;
		  *)
			  echo "鏃犳晥鐨勮緭鍏�!"
			  ;;
	  esac
	  break_end

	done



}




linux_file() {
	root_use
	send_stats "鏂囦欢绠＄悊鍣�"
	while true; do
		clear
		echo "鏂囦欢绠＄悊鍣�"
		echo "------------------------"
		echo "褰撳墠璺緞"
		pwd
		echo "------------------------"
		ls --color=auto -x
		echo "------------------------"
		echo "1.  杩涘叆鐩綍           2.  鍒涘缓鐩綍             3.  淇敼鐩綍鏉冮檺         4.  閲嶅懡鍚嶇洰褰�"
		echo "5.  鍒犻櫎鐩綍           6.  杩斿洖涓婁竴绾х洰褰�"
		echo "------------------------"
		echo "11. 鍒涘缓鏂囦欢           12. 缂栬緫鏂囦欢             13. 淇敼鏂囦欢鏉冮檺         14. 閲嶅懡鍚嶆枃浠�"
		echo "15. 鍒犻櫎鏂囦欢"
		echo "------------------------"
		echo "21. 鍘嬬缉鏂囦欢鐩綍       22. 瑙ｅ帇鏂囦欢鐩綍         23. 绉诲姩鏂囦欢鐩綍         24. 澶嶅埗鏂囦欢鐩綍"
		echo "25. 浼犳枃浠惰嚦鍏朵粬鏈嶅姟鍣�"
		echo "------------------------"
		echo "0.  杩斿洖涓婁竴绾�"
		echo "------------------------"
		read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " Limiting

		case "$Limiting" in
			1)  # 杩涘叆鐩綍
				read -e -p "璇疯緭鍏ョ洰褰曞悕: " dirname
				cd "$dirname" 2>/dev/null || echo "鏃犳硶杩涘叆鐩綍"
				send_stats "杩涘叆鐩綍"
				;;
			2)  # 鍒涘缓鐩綍
				read -e -p "璇疯緭鍏ヨ鍒涘缓鐨勭洰褰曞悕: " dirname
				mkdir -p "$dirname" && echo "鐩綍宸插垱寤�" || echo "鍒涘缓澶辫触"
				send_stats "鍒涘缓鐩綍"
				;;
			3)  # 淇敼鐩綍鏉冮檺
				read -e -p "璇疯緭鍏ョ洰褰曞悕: " dirname
				read -e -p "璇疯緭鍏ユ潈闄� (濡� 755): " perm
				chmod "$perm" "$dirname" && echo "鏉冮檺宸蹭慨鏀�" || echo "淇敼澶辫触"
				send_stats "淇敼鐩綍鏉冮檺"
				;;
			4)  # 閲嶅懡鍚嶇洰褰�
				read -e -p "璇疯緭鍏ュ綋鍓嶇洰褰曞悕: " current_name
				read -e -p "璇疯緭鍏ユ柊鐩綍鍚�: " new_name
				mv "$current_name" "$new_name" && echo "鐩綍宸查噸鍛藉悕" || echo "閲嶅懡鍚嶅け璐�"
				send_stats "閲嶅懡鍚嶇洰褰�"
				;;
			5)  # 鍒犻櫎鐩綍
				read -e -p "璇疯緭鍏ヨ鍒犻櫎鐨勭洰褰曞悕: " dirname
				rm -rf "$dirname" && echo "鐩綍宸插垹闄�" || echo "鍒犻櫎澶辫触"
				send_stats "鍒犻櫎鐩綍"
				;;
			6)  # 杩斿洖涓婁竴绾х洰褰�
				cd ..
				send_stats "杩斿洖涓婁竴绾х洰褰�"
				;;
			11) # 鍒涘缓鏂囦欢
				read -e -p "璇疯緭鍏ヨ鍒涘缓鐨勬枃浠跺悕: " filename
				touch "$filename" && echo "鏂囦欢宸插垱寤�" || echo "鍒涘缓澶辫触"
				send_stats "鍒涘缓鏂囦欢"
				;;
			12) # 缂栬緫鏂囦欢
				read -e -p "璇疯緭鍏ヨ缂栬緫鐨勬枃浠跺悕: " filename
				install nano
				nano "$filename"
				send_stats "缂栬緫鏂囦欢"
				;;
			13) # 淇敼鏂囦欢鏉冮檺
				read -e -p "璇疯緭鍏ユ枃浠跺悕: " filename
				read -e -p "璇疯緭鍏ユ潈闄� (濡� 755): " perm
				chmod "$perm" "$filename" && echo "鏉冮檺宸蹭慨鏀�" || echo "淇敼澶辫触"
				send_stats "淇敼鏂囦欢鏉冮檺"
				;;
			14) # 閲嶅懡鍚嶆枃浠�
				read -e -p "璇疯緭鍏ュ綋鍓嶆枃浠跺悕: " current_name
				read -e -p "璇疯緭鍏ユ柊鏂囦欢鍚�: " new_name
				mv "$current_name" "$new_name" && echo "鏂囦欢宸查噸鍛藉悕" || echo "閲嶅懡鍚嶅け璐�"
				send_stats "閲嶅懡鍚嶆枃浠�"
				;;
			15) # 鍒犻櫎鏂囦欢
				read -e -p "璇疯緭鍏ヨ鍒犻櫎鐨勬枃浠跺悕: " filename
				rm -f "$filename" && echo "鏂囦欢宸插垹闄�" || echo "鍒犻櫎澶辫触"
				send_stats "鍒犻櫎鏂囦欢"
				;;
			21) # 鍘嬬缉鏂囦欢/鐩綍
				read -e -p "璇疯緭鍏ヨ鍘嬬缉鐨勬枃浠�/鐩綍鍚�: " name
				install tar
				tar -czvf "$name.tar.gz" "$name" && echo "宸插帇缂╀负 $name.tar.gz" || echo "鍘嬬缉澶辫触"
				send_stats "鍘嬬缉鏂囦欢/鐩綍"
				;;
			22) # 瑙ｅ帇鏂囦欢/鐩綍
				read -e -p "璇疯緭鍏ヨ瑙ｅ帇鐨勬枃浠跺悕 (.tar.gz): " filename
				install tar
				tar -xzvf "$filename" && echo "宸茶В鍘� $filename" || echo "瑙ｅ帇澶辫触"
				send_stats "瑙ｅ帇鏂囦欢/鐩綍"
				;;

			23) # 绉诲姩鏂囦欢鎴栫洰褰�
				read -e -p "璇疯緭鍏ヨ绉诲姩鐨勬枃浠舵垨鐩綍璺緞: " src_path
				if [ ! -e "$src_path" ]; then
					echo "閿欒: 鏂囦欢鎴栫洰褰曚笉瀛樺湪銆�"
					send_stats "绉诲姩鏂囦欢鎴栫洰褰曞け璐�: 鏂囦欢鎴栫洰褰曚笉瀛樺湪"
					continue
				fi

				read -e -p "璇疯緭鍏ョ洰鏍囪矾寰� (鍖呮嫭鏂版枃浠跺悕鎴栫洰褰曞悕): " dest_path
				if [ -z "$dest_path" ]; then
					echo "閿欒: 璇疯緭鍏ョ洰鏍囪矾寰勩€�"
					send_stats "绉诲姩鏂囦欢鎴栫洰褰曞け璐�: 鐩爣璺緞鏈寚瀹�"
					continue
				fi

				mv "$src_path" "$dest_path" && echo "鏂囦欢鎴栫洰褰曞凡绉诲姩鍒� $dest_path" || echo "绉诲姩鏂囦欢鎴栫洰褰曞け璐�"
				send_stats "绉诲姩鏂囦欢鎴栫洰褰�"
				;;


		   24) # 澶嶅埗鏂囦欢鐩綍
				read -e -p "璇疯緭鍏ヨ澶嶅埗鐨勬枃浠舵垨鐩綍璺緞: " src_path
				if [ ! -e "$src_path" ]; then
					echo "閿欒: 鏂囦欢鎴栫洰褰曚笉瀛樺湪銆�"
					send_stats "澶嶅埗鏂囦欢鎴栫洰褰曞け璐�: 鏂囦欢鎴栫洰褰曚笉瀛樺湪"
					continue
				fi

				read -e -p "璇疯緭鍏ョ洰鏍囪矾寰� (鍖呮嫭鏂版枃浠跺悕鎴栫洰褰曞悕): " dest_path
				if [ -z "$dest_path" ]; then
					echo "閿欒: 璇疯緭鍏ョ洰鏍囪矾寰勩€�"
					send_stats "澶嶅埗鏂囦欢鎴栫洰褰曞け璐�: 鐩爣璺緞鏈寚瀹�"
					continue
				fi

				# 浣跨敤 -r 閫夐」浠ラ€掑綊鏂瑰紡澶嶅埗鐩綍
				cp -r "$src_path" "$dest_path" && echo "鏂囦欢鎴栫洰褰曞凡澶嶅埗鍒� $dest_path" || echo "澶嶅埗鏂囦欢鎴栫洰褰曞け璐�"
				send_stats "澶嶅埗鏂囦欢鎴栫洰褰�"
				;;


			 25) # 浼犻€佹枃浠惰嚦杩滅鏈嶅姟鍣�
				read -e -p "璇疯緭鍏ヨ浼犻€佺殑鏂囦欢璺緞: " file_to_transfer
				if [ ! -f "$file_to_transfer" ]; then
					echo "閿欒: 鏂囦欢涓嶅瓨鍦ㄣ€�"
					send_stats "浼犻€佹枃浠跺け璐�: 鏂囦欢涓嶅瓨鍦�"
					continue
				fi

				read -e -p "璇疯緭鍏ヨ繙绔湇鍔″櫒IP: " remote_ip
				if [ -z "$remote_ip" ]; then
					echo "閿欒: 璇疯緭鍏ヨ繙绔湇鍔″櫒IP銆�"
					send_stats "浼犻€佹枃浠跺け璐�: 鏈緭鍏ヨ繙绔湇鍔″櫒IP"
					continue
				fi

				read -e -p "璇疯緭鍏ヨ繙绔湇鍔″櫒鐢ㄦ埛鍚� (榛樿root): " remote_user
				remote_user=${remote_user:-root}

				read -e -p "璇疯緭鍏ヨ繙绔湇鍔″櫒瀵嗙爜: " -s remote_password
				echo
				if [ -z "$remote_password" ]; then
					echo "閿欒: 璇疯緭鍏ヨ繙绔湇鍔″櫒瀵嗙爜銆�"
					send_stats "浼犻€佹枃浠跺け璐�: 鏈緭鍏ヨ繙绔湇鍔″櫒瀵嗙爜"
					continue
				fi

				read -e -p "璇疯緭鍏ョ櫥褰曠鍙� (榛樿22): " remote_port
				remote_port=${remote_port:-22}

				# 娓呴櫎宸茬煡涓绘満鐨勬棫鏉＄洰
				ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
				sleep 2  # 绛夊緟鏃堕棿

				# 浣跨敤scp浼犺緭鏂囦欢
				scp -P "$remote_port" -o StrictHostKeyChecking=no "$file_to_transfer" "$remote_user@$remote_ip:/home/" <<EOF
$remote_password
EOF

				if [ $? -eq 0 ]; then
					echo "鏂囦欢宸蹭紶閫佽嚦杩滅▼鏈嶅姟鍣╤ome鐩綍銆�"
					send_stats "鏂囦欢浼犻€佹垚鍔�"
				else
					echo "鏂囦欢浼犻€佸け璐ャ€�"
					send_stats "鏂囦欢浼犻€佸け璐�"
				fi

				break_end
				;;



			0)  # 杩斿洖涓婁竴绾�
				send_stats "杩斿洖涓婁竴绾ц彍鍗�"
				break
				;;
			*)  # 澶勭悊鏃犳晥杈撳叆
				echo "鏃犳晥鐨勯€夋嫨锛岃閲嶆柊杈撳叆"
				send_stats "鏃犳晥閫夋嫨"
				;;
		esac
	done
}






kejilion_update() {

	send_stats "鑴氭湰鏇存柊"
	cd ~
	clear
	echo "鏇存柊鏃ュ織"
	echo "------------------------"
	echo "鍏ㄩ儴鏃ュ織: ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt"
	echo "------------------------"

	curl -s ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt | tail -n 35
	local sh_v_new=$(curl -s ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

	if [ "$sh_v" = "$sh_v_new" ]; then
		echo -e "${gl_lv}浣犲凡缁忔槸鏈€鏂扮増鏈紒${gl_huang}v$sh_v${gl_bai}"
		send_stats "鑴氭湰宸茬粡鏈€鏂颁簡锛屾棤闇€鏇存柊"
	else
		echo "鍙戠幇鏂扮増鏈紒"
		echo -e "褰撳墠鐗堟湰 v$sh_v        鏈€鏂扮増鏈� ${gl_huang}v$sh_v_new${gl_bai}"
		echo "------------------------"
		read -e -p "纭畾鏇存柊鑴氭湰鍚楋紵(Y/N): " choice
		case "$choice" in
			[Yy])
				clear
				local country=$(curl -s ipinfo.io/country)
				if [ "$country" = "CN" ]; then
					curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/cn/kejilion.sh && chmod +x kejilion.sh
				else
					curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh
				fi
				canshu_v6
				CheckFirstRun_true
				yinsiyuanquan2
				cp -f ~/kejilion.sh /usr/local/bin/k > /dev/null 2>&1
				echo -e "${gl_lv}鑴氭湰宸叉洿鏂板埌鏈€鏂扮増鏈紒${gl_huang}v$sh_v_new${gl_bai}"
				send_stats "鑴氭湰宸茬粡鏈€鏂�$sh_v_new"
				break_end
				~/kejilion.sh
				exit
				;;
			[Nn])
				echo "宸插彇娑�"
				;;
			*)
				;;
		esac
	fi


}



kejilion_Affiliates() {

clear
send_stats "骞垮憡涓撴爮"
echo "骞垮憡涓撴爮"
echo "------------------------"
echo "灏嗕负鐢ㄦ埛鎻愪緵鏇寸畝鍗曚紭闆呯殑鎺ㄥ箍涓庤喘涔颁綋楠岋紒"
echo ""
echo -e "鏈嶅姟鍣ㄤ紭鎯�"
echo "------------------------"
echo -e "${gl_lan}RackNerd 10.18鍒€姣忓勾 缇庡浗 1鏍稿績 768M鍐呭瓨 15G纭洏 1T娴侀噺姣忔湀${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://my.racknerd.com/aff.php?aff=5501&pid=792${gl_bai}"
echo "------------------------"
echo -e "${gl_lv}Cloudcone 10鍒€姣忓勾 缇庡浗 1鏍稿績 768M鍐呭瓨 5G纭洏 3T娴侀噺姣忔湀${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://app.cloudcone.com.cn/vps/261/create?ref=8355&token=cloudcone.cc-24-vps-2${gl_bai}"
echo "------------------------"
echo -e "${gl_huang}鎼摝宸� 49鍒€姣忓 缇庡浗CN2GIA 鏃ユ湰杞摱 2鏍稿績 1G鍐呭瓨 20G纭洏 1T娴侀噺姣忔湀${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://bandwagonhost.com/aff.php?aff=69004&pid=87${gl_bai}"
echo "------------------------"
echo -e "${gl_lan}DMIT 28鍒€姣忓 缇庡浗CN2GIA 1鏍稿績 2G鍐呭瓨 20G纭洏 800G娴侀噺姣忔湀${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://www.dmit.io/aff.php?aff=4966&pid=100${gl_bai}"
echo "------------------------"
echo -e "${gl_zi}V.PS 6.9鍒€姣忔湀 涓滀含杞摱 2鏍稿績 1G鍐呭瓨 20G纭洏 1T娴侀噺姣忔湀${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://vps.hosting/cart/tokyo-cloud-kvm-vps/?id=148&?affid=1355&?affid=1355${gl_bai}"
echo "------------------------"
echo -e "${gl_kjlan}VPS鏇村鐑棬浼樻儬${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://kejilion.pro/topvps/${gl_bai}"
echo "------------------------"
echo ""
echo -e "鍩熷悕浼樻儬"
echo "------------------------"
echo -e "${gl_lan}GNAME 8.8鍒€棣栧勾COM鍩熷悕 6.68鍒€棣栧勾CC鍩熷悕${gl_bai}"
echo -e "${gl_bai}缃戝潃: https://www.gname.com/register?tt=86836&ttcode=KEJILION86836&ttbj=sh${gl_bai}"
echo "------------------------"
echo ""
echo -e "绉戞妧lion鍛ㄨ竟"
echo "------------------------"
echo -e "${gl_kjlan}B绔�:   ${gl_bai}https://b23.tv/2mqnQyh              ${gl_kjlan}娌圭:     ${gl_bai}https://www.youtube.com/@kejilion${gl_bai}"
echo -e "${gl_kjlan}瀹樼綉:  ${gl_bai}https://kejilion.pro/               ${gl_kjlan}瀵艰埅:     ${gl_bai}https://dh.kejilion.pro/${gl_bai}"
echo -e "${gl_kjlan}鍗氬:  ${gl_bai}https://blog.kejilion.pro/          ${gl_kjlan}杞欢涓績: ${gl_bai}https://app.kejilion.pro/${gl_bai}"
echo "------------------------"
echo ""
}


kejilion_sh() {
while true; do
clear
echo -e "${gl_kjlan}_  _ ____  _ _ _    _ ____ _  _ "
echo "|_/  |___  | | |    | |  | |\ | "
echo "| \_ |___ _| | |___ | |__| | \| "
echo "                                "
echo -e "绉戞妧lion鑴氭湰宸ュ叿绠� v$sh_v 鍙负鏇寸畝鍗曠殑Linux鐨勪娇鐢紒"
echo -e "閫傞厤Ubuntu/Debian/CentOS/Alpine/Kali/Arch/RedHat/Fedora/Alma/Rocky绯荤粺"
echo -e "-杈撳叆${gl_huang}k${gl_kjlan}鍙揩閫熷惎鍔ㄦ鑴氭湰-${gl_bai}"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}1.   ${gl_bai}绯荤粺淇℃伅鏌ヨ"
echo -e "${gl_kjlan}2.   ${gl_bai}绯荤粺鏇存柊"
echo -e "${gl_kjlan}3.   ${gl_bai}绯荤粺娓呯悊"
echo -e "${gl_kjlan}4.   ${gl_bai}鍩虹宸ュ叿 鈻�"
echo -e "${gl_kjlan}5.   ${gl_bai}BBR绠＄悊 鈻�"
echo -e "${gl_kjlan}6.   ${gl_bai}Docker绠＄悊 鈻� "
echo -e "${gl_kjlan}7.   ${gl_bai}WARP绠＄悊 鈻� "
echo -e "${gl_kjlan}8.   ${gl_bai}娴嬭瘯鑴氭湰鍚堥泦 鈻� "
echo -e "${gl_kjlan}9.   ${gl_bai}鐢查鏂囦簯鑴氭湰鍚堥泦 鈻� "
echo -e "${gl_huang}10.  ${gl_bai}LDNMP寤虹珯 鈻� "
echo -e "${gl_kjlan}11.  ${gl_bai}搴旂敤甯傚満 鈻� "
echo -e "${gl_kjlan}12.  ${gl_bai}鎴戠殑宸ヤ綔鍖� 鈻� "
echo -e "${gl_kjlan}13.  ${gl_bai}绯荤粺宸ュ叿 鈻� "
echo -e "${gl_kjlan}14.  ${gl_bai}鏈嶅姟鍣ㄩ泦缇ゆ帶鍒� 鈻� "
echo -e "${gl_kjlan}15.  ${gl_bai}骞垮憡涓撴爮"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}p.   ${gl_bai}骞诲吔甯曢瞾寮€鏈嶈剼鏈� 鈻�"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}00.  ${gl_bai}鑴氭湰鏇存柊"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}0.   ${gl_bai}閫€鍑鸿剼鏈�"
echo -e "${gl_kjlan}------------------------${gl_bai}"
read -e -p "璇疯緭鍏ヤ綘鐨勯€夋嫨: " choice

case $choice in
  1) linux_ps ;;
  2) clear ; send_stats "绯荤粺鏇存柊" ; linux_update ;;
  3) clear ; send_stats "绯荤粺娓呯悊" ; linux_clean ;;
  4) linux_tools ;;
  5) linux_bbr ;;
  6) linux_docker ;;
  7) clear ; send_stats "warp绠＄悊" ; install wget
	wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh ; bash menu.sh [option] [lisence/url/token]
	;;
  8) linux_test ;;
  9) linux_Oracle ;;
  10) linux_ldnmp ;;
  11) linux_panel ;;
  12) linux_work ;;
  13) linux_Settings ;;
  14) linux_cluster ;;
  15) kejilion_Affiliates ;;
  p) send_stats "骞诲吔甯曢瞾寮€鏈嶈剼鏈�" ; cd ~
	 curl -sS -O ${gh_proxy}https://raw.githubusercontent.com/kejilion/sh/main/palworld.sh ; chmod +x palworld.sh ; ./palworld.sh
	 exit
	 ;;
  00) kejilion_update ;;
  0) clear ; exit ;;
  *) echo "鏃犳晥鐨勮緭鍏�!" ;;
esac
	break_end
done
}


k_info() {
send_stats "k鍛戒护鍙傝€冪敤渚�"
echo "鏃犳晥鍙傛暟"
echo "-------------------"
echo "瑙嗛浠嬬粛: https://www.bilibili.com/video/BV1ib421E7it?t=0.1"
echo "浠ヤ笅鏄痥鍛戒护鍙傝€冪敤渚嬶細"
echo "鍚姩鑴氭湰            k"
echo "瀹夎杞欢鍖�          k install nano wget | k add nano wget | k 瀹夎 nano wget"
echo "鍗歌浇杞欢鍖�          k remove nano wget | k del nano wget | k uninstall nano wget | k 鍗歌浇 nano wget"
echo "鏇存柊绯荤粺            k update | k 鏇存柊"
echo "娓呯悊绯荤粺鍨冨溇        k clean | k 娓呯悊"
echo "鎵撳紑閲嶈绯荤粺闈㈡澘    k dd | k 閲嶈"
echo "鎵撳紑bbr3鎺у埗闈㈡澘    k bbr3 | k bbrv3"
echo "鎵撳紑鍐呮牳璋冧紭闈㈡澘    k nhyh | k 鍐呮牳浼樺寲"
echo "鎵撳紑绯荤粺鍥炴敹绔�      k trash | k hsz | k 鍥炴敹绔�"
echo "杞欢鍚姩            k start sshd | k 鍚姩 sshd "
echo "杞欢鍋滄            k stop sshd | k 鍋滄 sshd "
echo "杞欢閲嶅惎            k restart sshd | k 閲嶅惎 sshd "
echo "杞欢鐘舵€佹煡鐪�        k status sshd | k 鐘舵€� sshd "
echo "杞欢寮€鏈哄惎鍔�        k enable docker | k autostart docke | k 寮€鏈哄惎鍔� docker "
echo "鍩熷悕璇佷功鐢宠        k ssl"
echo "鍩熷悕璇佷功鍒版湡鏌ヨ    k ssl ps"
echo "docker鐜瀹夎      k docker install |k docker 瀹夎"
echo "docker瀹瑰櫒绠＄悊      k docker ps |k docker 瀹瑰櫒"
echo "docker闀滃儚绠＄悊      k docker img |k docker 闀滃儚"
echo "LDNMP绔欑偣绠＄悊       k web"
echo "LDNMP缂撳瓨娓呯悊       k web cache"
echo "瀹夎WordPress       k wp |k wordpress |k wp xxx.com"
echo "瀹夎鍙嶅悜浠ｇ悊        k fd |k rp |k 鍙嶄唬 |k fd xxx.com"

}



if [ "$#" -eq 0 ]; then
	# 濡傛灉娌℃湁鍙傛暟锛岃繍琛屼氦浜掑紡閫昏緫
	kejilion_sh
else
	# 濡傛灉鏈夊弬鏁帮紝鎵ц鐩稿簲鍑芥暟
	case $1 in
		install|add|瀹夎)
			shift
			send_stats "瀹夎杞欢"
			install "$@"
			;;
		remove|del|uninstall|鍗歌浇)
			shift
			send_stats "鍗歌浇杞欢"
			remove "$@"
			;;
		update|鏇存柊)
			linux_update
			;;
		clean|娓呯悊)
			linux_clean
			;;
		dd|閲嶈)
			dd_xitong
			;;
		bbr3|bbrv3)
			bbrv3
			;;
		nhyh|鍐呮牳浼樺寲)
			Kernel_optimize
			;;
		trash|hsz|鍥炴敹绔�)
			linux_trash
			;;
		wp|wordpress)
			shift
			ldnmp_wp "$@"

			;;
		fd|rp|鍙嶄唬)
			shift
			ldnmp_Proxy "$@"
			;;
		status|鐘舵€�)
			shift
			send_stats "杞欢鐘舵€佹煡鐪�"
			status "$@"
			;;
		start|鍚姩)
			shift
			send_stats "杞欢鍚姩"
			start "$@"
			;;
		stop|鍋滄)
			shift
			send_stats "杞欢鏆傚仠"
			stop "$@"
			;;
		restart|閲嶅惎)
			shift
			send_stats "杞欢閲嶅惎"
			restart "$@"
			;;

		enable|autostart|寮€鏈哄惎鍔�)
			shift
			send_stats "杞欢寮€鏈鸿嚜鍚�"
			enable "$@"
			;;

		ssl)
			shift
			if [ "$1" = "ps" ]; then
				send_stats "鏌ョ湅璇佷功鐘舵€�"
				ssl_ps
			elif [ -z "$1" ]; then
				add_ssl
				send_stats "蹇€熺敵璇疯瘉涔�"
			elif [ -n "$1" ]; then
				add_ssl "$1"
				send_stats "蹇€熺敵璇疯瘉涔�"
			else
				k_info
			fi
			;;

		docker)
			shift
			case $1 in
				install|瀹夎)
					send_stats "蹇嵎瀹夎docker"
					install_docker
					;;
				ps|瀹瑰櫒)
					send_stats "蹇嵎瀹瑰櫒绠＄悊"
					docker_ps
					;;
				img|闀滃儚)
					send_stats "蹇嵎闀滃儚绠＄悊"
					docker_image
					;;
				*)
					k_info
					;;
			esac
			;;

		web)
		   shift
			if [ "$1" = "cache" ]; then
				web_cache
			elif [ -z "$1" ]; then
				ldnmp_web_status
			else
				k_info
			fi
			;;
		*)
			k_info
			;;
	esac
fi
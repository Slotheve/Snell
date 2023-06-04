#!/bin/bash
# Author: Slotheve<https://slotheve.com>

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

IP=`curl -sL -4 ip.sb`
CPU=`uname -m`
snell_conf="/etc/snell/snell-server.conf"

version=(
v3.0.1
v4.0.1
)

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

archAffix(){
    if   [[ "$CPU" = "x86_64" ]] || [[ "$CPU" = "amd64" ]]; then
		CPU="amd64"
	elif [[ "$CPU" = "armv8" ]] || [[ "$CPU" = "aarch64" ]]; then
		CPU="arm64"
	else
		colorEcho $RED " 不支持的CPU架构！"
	fi
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        result=$(id | awk '{print $1}')
	if [[ $result != "用户id=0(root)" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
	fi
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    fi
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

status() {
    if [[ ! -f /etc/snell/snell ]]; then
        echo 0
        return
    fi
    if [[ ! -f $snell_conf ]]; then
        echo 1
        return
    fi
    tmp=`grep 0.0.0.0: $snell_conf | cut -d: -f2 | tr -d \",' '`
    res=`ss -nutlp| grep ${tmp} | grep -i snell`
    if [[ -z "$res" ]]; then
		echo 2
	else
		echo 3
		return
    fi
}

statusText() {
    res=`status`
    case $res in
        2)
            echo -e ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装${PLAIN}
            ;;
    esac
}

Install_dependency(){
if [[ ${release} == "centos" ]]; then
			yum install unzip wget -y
		else
			apt-get install unzip wget -y
fi
}

selectversion() {
	for ((i=1;i<=${#version[@]};i++ )); do
		hint="${version[$i-1]}"
		echo -e "${green}${i}${plain}) ${hint}"
	done
	echo -e "${YELLOW}仅v3向下兼容,且仅v3/v4支持uot${PLAIN}"
	read -p "选择版本(默认: ${version[0]}):" pick
	[ -z "$pick" ] && pick=1
	expr ${pick} + 1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "[${red}Error${plain}] Please enter a number"
		continue
	fi
	if [[ "$pick" -lt 1 || "$pick" -gt ${#version[@]} ]]; then
		echo -e "${BLUE}[${PLAIN}${RED}Error${PLAIN}${BLUE}] 请选择 1 或 ${#version[@]}${PLAIN}"
		exit 0
	fi
	VER=${version[$pick-1]}
}

Download_snell(){
	rm -rf /etc/snell /tmp/snell
	mkdir -p /etc/snell /tmp/snell
	archAffix
	DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/Snell/main/snell-server-${VER}-linux-${CPU}.zip"
	colorEcho $BLUE " 下载Snell: ${DOWNLOAD_LINK}"
	curl -L -H "Cache-Control: no-cache" -o /tmp/snell/snell.zip ${DOWNLOAD_LINK}
	unzip /tmp/snell/snell.zip -d /tmp/snell/
	mv /tmp/snell/snell-server /etc/snell/snell
	chmod +x /etc/snell/snell
}

Generate_conf(){
	Set_V6
	Set_port
	Set_psk
	Set_obfs
}


Deploy_snell(){
	cd /etc/systemd/system
	cat > snell.service<<-EOF
	[Unit]
	Description=Snell Server
	After=network.target
	[Service]
	ExecStart=/etc/snell/snell -c /etc/snell/snell-server.conf
	Restart=on-failure
	RestartSec=1s
	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl daemon-reload
	systemctl start snell
	systemctl restart snell
	systemctl enable snell.service
	echo "snell已安装完毕并运行"
}

Set_V6(){
	read -p "是否开启V6？[y/n]：" answer
	if [[ "${answer,,}" = "y" ]]; then
		colorEcho $BLUE "启用V6"
		V6="true"
	elif [[ "${answer,,}" = "n" ]]; then
		colorEcho $BLUE "禁用V6"
		V6="false"
	else
		colorEcho $RED "输入错误, 请输入正确操作。"
		exit
	fi
}

Set_port(){
	while true
		do
		echo -e "请输入 Snell 端口 [1-65535]"
		read -e -p "(默认: 6666，回车):" PORT
		[[ -z "${PORT}" ]] && PORT="6666"
		echo $((${PORT}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${PORT} -ge 1 ]] && [[ ${PORT} -le 65535 ]]; then
				colorEcho $BLUE "端口: ${PORT}"
			else
				colorEcho $RED "输入错误, 请输入正确的端口。"
			fi
		else
			colorEcho $RED "输入错误, 请输入正确的端口。"
		fi
		done
}

Set_psk(){
	echo "请输入 Snell psk（建议随机生成）"
	read -e -p "(避免出错，强烈推荐随机生成，直接回车):" PSK
	if [[ -z "${PSK}" ]]; then
		PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 31)
	elif [[ ${#PSK} != 31 ]]
		colorEcho $RED "请输入正确的密匙（31位字符）。"
		exit
	fi
	colorEcho $BLUE "PSK: ${PSK}"
}

Set_obfs(){
	read -p " 是否开启obfs？[y/n]：" answer
	if [[ "${answer,,}" = "y" ]]; then
		read -e -p "请输入 obfs 混淆 (tls/http)" OBFS
		if [[  -z "${OBFS}" ]]; then
			colorEcho $BLUE "obfs: ${OBFS}"
		else
			echo "输入错误, 请输入正确操作。"
			exit
		fi
	elif [[ "${answer,,}" = "n" ]]; then
		OBFS="false"
		colorEcho $BLUE "禁用obfs"
	fi
}

Write_config(){
	cat > ${snell_conf}<<-EOF
[snell-server]
listen = ${IP}:${PORT}
psk = ${PSK}
ipv6 = ${V6}
obfs = ${OBFS}
# $VER
EOF
}

Install_snell(){
	selectversion
	Install_dependency
	Generate_conf
	Download_snell
	Write_config
	Deploy_snell
	ShowInfo
}

Start_snell(){
	systemctl start snell
	colorEcho $BLUE "snell已启动"
}

Stop_snell(){
	systemctl stop snell
	colorEcho $BLUE "snell已停止"
}

Restart_snell(){
	systemctl restart snell
	colorEcho $BLUE "snell已重启"
}

Uninstall_snell(){
	read -p " 是否卸载Snell？[y/n]：" answer
	if [[ "${answer,,}" = "y" ]]; then
		systemctl stop snell
		systemctl disable snell
		rm -rf /etc/systemd/snell.service
		rm -rf /etc/snell
		systemctl daemon-reload
		colorEcho $BLUE "snell已经卸载完毕"
	elif [[ "${answer,,}" = "n" ]]; then
		colorEcho $BLUE "取消卸载"
	else
		colorEcho $RED "输入错误, 请输入正确操作。"
		exit
	fi
}

ShowInfo() {
	echo ""
	echo -e " ${BLUE}Snell配置文件: ${PLAIN} ${RED}${snell_conf}${PLAIN}"
	colorEcho $BLUE " Snell配置信息："
	GetConfig
	outputSnell
}

GetConfig() {
	port=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f2`
	if [[ -z "${port}" ]]; then
		port=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f4`
	fi
	psk=`grep psk ${snell_conf} | awk -F '= ' '{print $2}'`
	psk=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
	psk=`grep obfs ${snell_conf} | awk -F '= ' '{print $2}'`
	ver=`/etc/snell/snell -version | grep 'version' | awk -F ':' '{print $2}'`
}

outputSnell() {
	echo -e "   ${BLUE}协议: ${PLAIN} ${RED}snell${PLAIN}"
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}端口(port)：${PLAIN} ${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}密钥(PSK)：${PLAIN} ${RED}${psk}${PLAIN}"
	echo -e "   ${BLUE}版本(VER)：${PLAIN} ${RED}${ver}${PLAIN}"
}

Change_snell_info(){
	colorEcho $BLUE "修改 snell 配置信息"
	selectversion
	Set_port
	Set_psk
	Write_config
	Restart_snell
	colorEcho $BLUE "修改配置成功"
	ShowInfo
}

checkSystem
menu() {
	clear
	echo "###############################"
	echo -e "# ${RED}Snell一键安装脚本${PLAIN}             #"
	echo -e "# ${GREEN}作者${PLAIN}: 怠惰(Slotheve)        #"
	echo -e "# ${GREEN}网址${PLAIN}: https://slotheve.com  #"
	echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/slotheve #"
	echo "###############################"
	echo " -------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装Snell"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载Snell${PLAIN}"
	echo " -------------"
	echo -e "  ${GREEN}3.${PLAIN}  启动Snell"
	echo -e "  ${GREEN}4.${PLAIN}  重启Snell"
	echo -e "  ${GREEN}5.${PLAIN}  停止Snell"
	echo " -------------"
	echo -e "  ${GREEN}6.${PLAIN}  查看Snell配置"
	echo -e "  ${GREEN}7.${PLAIN}  修改Snell配置"
	echo " -------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo ""
	echo -n " 当前状态："
	statusText
	echo 

	read -p " 请选择操作[0-8]：" answer
	case $answer in
		0)
			exit 0
			;;
		1)
			Install_snell
			;;
		2)
			Uninstall_snell
			;;
		3)
			Start_snell
			;;
		4)
			Restart_snell
			;;
		5)
			Stop_snell
			;;
		6)
			ShowInfo
			;;
		7)
			Change_snell_info
			;;
		*)
			colorEcho $RED " 请选择正确的操作！"
			exit 1
			;;
	esac
}
menu

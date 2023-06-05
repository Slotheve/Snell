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
    tmp=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f2`
    if [[ -z "${tmp}" ]]; then
        tmp=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f4`
    fi
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
	echo ""
	colorEcho $YELLOW "安装依赖中..."
	yum install unzip wget -y >/dev/null 2>&1
	echo ""
else
	echo ""
	colorEcho $YELLOW "安装依赖中..."
	apt install unzip wget -y >/dev/null 2>&1
	echo ""
fi
}

selectversion() {
	read -p $'1. v3.0.1\n2. v4.0.1\n请选择版本 [1/2]\n(默认v3.0.1, 回车)' NUM
	if [[ "${NUM}" = "2" ]]; then
		VER="v4.0.1"
	elif [[ "${NUM}" = "1" || -z "${NUM}" ]]; then
		VER="v3.0.1"
	else
		colorEcho $RED "输入错误, 请输入 1/2"
		echo ""
		exit 1
	fi
	colorEcho $BLUE "版本: ${VER}"
	echo ""
}

Download_snell(){
	rm -rf /etc/snell /tmp/snell
	mkdir -p /etc/snell /tmp/snell
	archAffix
	DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/Snell/main/snell-server-${VER}-linux-${CPU}.zip"
	colorEcho $YELLOW "下载Snell: ${DOWNLOAD_LINK}"
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
	colorEcho $BLUE "Snell安装完成"
}

Set_V6(){
	read -p $'是否开启V6？[y/n]\n(默认n, 回车)' answer
	if [[ "${answer}" = "y" ]]; then
		colorEcho $BLUE "启用V6"
		echo ""
		V6="true"
		LIP="[::]"
	elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
		colorEcho $BLUE "禁用V6"
		echo ""
		V6="false"
		LIP="0.0.0.0"
	else
		colorEcho $RED "输入错误, 请输入 y/n"
		exit 1
	fi
}

Set_port(){
	read -p $'请输入 Snell 端口 [1-65535]\n(默认: 6666，回车):' PORT
	[[ -z "${PORT}" ]] && PORT="6666"
	echo $((${PORT}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${PORT} -ge 1 ]] && [[ ${PORT} -le 65535 ]]; then
			colorEcho $BLUE "端口: ${PORT}"
			echo ""
		else
			colorEcho $RED "输入错误, 请输入正确的端口。"
			echo ""
		fi
	else
		colorEcho $RED "输入错误, 请输入数字。"
		echo ""
		exit 1
	fi
}

Set_psk(){
	read -p $'请输入 Snell PSK 密钥\n(推荐随机生成，直接回车):' PSK
	[[ -z "${PSK}" ]] && PSK=`tr -dc A-Za-z0-9 </dev/urandom | head -c 31`
	if [[ "${#PSK}" != 31 ]]; then
		colorEcho $RED "请输入正确的密匙（31位字符）。"
		echo ""
		exit 1
	fi
	colorEcho $BLUE "PSK: ${PSK}"
	echo ""
}

Set_obfs(){
	read -p $'是否开启obfs？[y/n]：\n(默认n, 回车)' answer
	if [[ "${answer}" = "y" ]]; then
		read -e -p "请输入 obfs 混淆 (tls/http)" OBFS
		if [[ "${OBFS}" = "tls" || "${OBFS}" = "http" ]]; then
			colorEcho $BLUE "obfs: ${OBFS}"
			echo ""
		else
			echo "错误, 请输入 http/tls"
			echo ""
			exit 1
		fi
	elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
		OBFS="none"
		colorEcho $BLUE "禁用obfs"
		echo ""
	else
		echo "错误, 请输入 y/n"
		echo ""
		exit 1
	fi
}

Write_config(){
	cat > ${snell_conf}<<-EOF
[snell-server]
listen = ${LIP}:${PORT}
psk = ${PSK}
ipv6 = ${V6}
obfs = ${OBFS}
# $VER
EOF
}

Install_snell(){
	Install_dependency
	selectversion
	Generate_conf
	Download_snell
	Write_config
	Deploy_snell
	ShowInfo
}

Start_snell(){
	systemctl start snell
	colorEcho $BLUE " Snell已启动"
}

Stop_snell(){
	systemctl stop snell
	colorEcho $BLUE " Snell已停止"
}

Restart_snell(){
	systemctl restart snell
	colorEcho $BLUE " Snell已重启"
}

Uninstall_snell(){
	read -p $' 是否卸载Snell？[y/n]：\n (默认n, 回车)' answer
	if [[ "${answer}" = "y" ]]; then
		systemctl stop snell
		systemctl disable snell
		rm -rf /etc/systemd/snell.service
		rm -rf /etc/snell
		systemctl daemon-reload
		colorEcho $BLUE " Snell已经卸载完毕"
	elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
		colorEcho $BLUE " 取消卸载"
	else
		colorEcho $RED " 输入错误, 请输入正确操作。"
		exit 1
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
	ipv6=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
	obfs=`grep obfs ${snell_conf} | awk -F '= ' '{print $2}'`
	ver=`grep '#' ${snell_conf} | awk -F '# ' '{print $2}'`
	if [[ "$ver" = "v3.0.1" ]]; then
		ver="v3"
	else
		ver="v4"
	fi
}

outputSnell() {
	echo -e "   ${BLUE}协议: ${PLAIN} ${RED}snell${PLAIN}"
	echo -e "   ${BLUE}地址(IP): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}端口(PORT)：${PLAIN} ${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}密钥(PSK)：${PLAIN} ${RED}${psk}${PLAIN}"
	echo -e "   ${BLUE}IPV6：${PLAIN} ${RED}${ipv6}${PLAIN}"
	echo -e "   ${BLUE}混淆(OBFS)：${PLAIN} ${RED}${obfs}${PLAIN}"
	echo -e "   ${BLUE}版本(VER)：${PLAIN} ${RED}${ver}${PLAIN}"
}

Change_snell_info(){
	colorEcho $BLUE " 修改 Snell 配置信息"
	selectversion
	Generate_conf
	Write_config
	Restart_snell
	colorEcho $BLUE " 修改配置成功"
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

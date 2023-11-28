#!/bin/bash
# Author: Slotheve<https://slotheve.com>

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

IP4=`curl -sL -4 ip.sb`
IP6=`curl -sL -6 ip.sb`
CPU=`uname -m`
snell_conf="/etc/snell/snell-server.conf"
stls_conf="/etc/systemd/system/shadowtls.service"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

versions=(
v1
v2
v3
v4
)

domains=(
gateway.icloud.com
cn.bing.com
mp.weixin.qq.com
自定义
)

archAffix(){
    if [[ "$CPU" = "x86_64" ]] || [[ "$CPU" = "amd64" ]]; then
	CPU="amd64"
	ARCH="x86_64"
    elif [[ "$CPU" = "armv8" ]] || [[ "$CPU" = "aarch64" ]]; then
	CPU="arm64"
	ARCH="aarch64"
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
	OS="apt"
    else
	OS="yum"
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
    if [[ -z ${tmp} ]]; then
        tmp=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f4`
    fi
    res=`ss -nutlp| grep ${tmp} | grep -i snell`
    if [[ -z $res ]]; then
	echo 2
    else
	echo 3
	return
    fi
}

status_stls() {
    if [[ ! -f /etc/snell/shadowtls ]]; then
        echo 0
        return
    fi
    if [[ ! -f $stls_conf ]]; then
        echo 1
        return
    fi
    V6=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
    if [[ $V6 = "true" ]]; then
	tmp2=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f4`
    else
	tmp2=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f2`
    fi
    res2=`ss -nutlp| grep ${tmp2} | grep -i shadowtls`
    if [[ -z $res2 ]]; then
	echo 2
    else
	echo 3
	return
    fi
}

statusText() {
    res=`status`
    res2=`status_stls`
    case ${res}${res2} in
        22)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}"
            ;;
        23)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}"
            ;;
        32)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}"
            ;;
        33)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}"
            ;;
        20)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${RED}未安装${PLAIN}"
            ;;
        21)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${RED}未安装${PLAIN}"
            ;;
        30)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${RED}未安装${PLAIN}"
            ;;
        31)
            echo -e ${BLUE}Snell:${PLAIN} ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${RED}未安装${PLAIN}"
            ;;
        *)
            echo -e ${BLUE}Snell:${PLAIN} ${RED}未安装${PLAIN}
            echo -e "       ${BLUE}ShadowTls:${PLAIN} ${RED}未安装${PLAIN}"
            ;;
    esac
}

Install_dependency(){
    if [[ ${OS} == "yum" ]]; then
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
    echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

selectversion() {
    for ((i=1;i<=${#versions[@]};i++ )); do
 	hint="${versions[$i-1]}"
 	echo -e "${GREEN}${i}${PLAIN}) ${hint}"
    done
    read -p "请选择版本[1-4] (默认: ${versions[3]}):" pick
    [ -z "$pick" ] && pick=4
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
	colorEcho $RED "错误, 请选择[1-4]"
	selectversion
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#versions[@]} ]]; then
	colorEcho $RED "错误, 请选择[1-4]"
	selectversion
    fi
    vers=${versions[$pick-1]}
    if [[ "$pick" = "4" ]]; then
	VER="v4.0.1"
    else
	VER="v3.0.1"
    fi
}

show_version() {
    if [[ ! -z "${vers}" ]]; then
	colorEcho $BLUE "版本: ${vers}"
	echo ""
    else
	echo ""
	return
    fi
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

Download_stls() {
    rm -rf /etc/snell/shadowtls
    archAffix
    TAG_URL="https://api.github.com/repos/ihciah/shadow-tls/releases/latest"
    DOWN_VER=`curl -s "${TAG_URL}" --connect-timeout 10| grep -Eo '\"tag_name\"(.*?)\",' | cut -d\" -f4`
    DOWNLOAD_LINK="https://github.com/ihciah/shadow-tls/releases/download/${DOWN_VER}/shadow-tls-${ARCH}-unknown-linux-musl"
    colorEcho $YELLOW "下载ShadowTLS: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o /etc/snell/shadowtls ${DOWNLOAD_LINK}
    chmod +x /etc/snell/shadowtls
}

Generate_conf(){
    show_version
    Set_V6
    Set_port
    Set_psk
    show_psk
    Set_obfs
    Set_tfo
}

Generate_stls() {
    Decide_sv6
    Set_sport
    Set_domain
    show_domain
    Set_pass
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
    systemctl enable snell
    systemctl restart snell
    echo "net.ipv4.tcp_fastopen = 3" >> /etc/sysctl.conf
    sysctl -p
}

Deploy_stls() {
    cd /etc/systemd/system
    cat > shadowtls.service<<-EOF
[Unit]
Description=Shadow-TLS Server Service
Documentation=man:sstls-server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/etc/snell/shadowtls --fastopen --v3 server --listen $SV6:$SPORT --server 127.0.0.1:$PORT --tls $DOMAIN --password $PASS
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=shadow-tls

[Install]
WantedBy=multi-user.target
# ${V6}
EOF
    systemctl daemon-reload
    systemctl enable shadowtls
    systemctl restart shadowtls
}

Set_V6(){
    read -p $'是否开启V6？[y/n]\n(默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
	if [[ $VER == "v3.0.1" ]]; then
		LIP="[::]"
		colorEcho $BLUE "启用V6"
		echo ""
	else
		LIP="::0"
		colorEcho $BLUE "启用V6"
		echo ""
	fi
    V6="true"
    elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
	colorEcho $BLUE "禁用V6"
	echo ""
	LIP="0.0.0.0"
 	V6="false"
    else
	colorEcho $RED "输入错误, 请输入 y/n"
	Set_V6
    fi
}

Set_port(){
    read -p $'请输入 Snell 端口 [1-65535]\n(默认: 6666，回车): ' PORT
    [[ -z "${PORT}" ]] && PORT="6666"
    echo $((${PORT}+0)) &>/dev/null
    if [[ $? -eq 0 ]]; then
	if [[ ${PORT} -ge 1 ]] && [[ ${PORT} -le 65535 ]]; then
		colorEcho $BLUE "端口: ${PORT}"
		echo ""
	else
		colorEcho $RED "输入错误, 请输入正确的端口。"
		Set_port
	fi
    else
	colorEcho $RED "输入错误, 请输入数字。"
	Set_port
    fi
}

Set_psk(){
    read -p $'请输入 Snell PSK 密钥\n(推荐随机生成，直接回车): ' PSK
    [[ -z "${PSK}" ]] && PSK=`tr -dc A-Za-z0-9 </dev/urandom | head -c 31`
    if [[ "${#PSK}" != 31 ]]; then
	colorEcho $RED "请输入正确的密匙（31位字符）。"
	Set_psk
    fi
}

show_psk() {
    colorEcho $BLUE "PSK: ${PSK}"
    echo ""
}

Set_obfs(){
    read -p $'是否开启obfs？[y/n]\n(默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
	read -e -p "请输入 obfs 混淆 (tls/http): " OBFS
	if [[ "${OBFS}" = "tls" || "${OBFS}" = "http" ]]; then
		colorEcho $BLUE "obfs: ${OBFS}"
		echo ""
	else
		colorEcho $RED "错误, 请输入 http/tls"
		Set_obfs
	fi
    elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
	if [[ $VER == "v3.0.1" ]]; then
		OBFS="none"
		colorEcho $BLUE "禁用obfs"
		echo ""
	else
		OBFS="off"
		colorEcho $BLUE "禁用obfs"
		echo ""
	fi
    else
	colorEcho $RED "错误, 请输入 y/n"
	Set_obfs
    fi
}

Set_tfo(){
    read -p $'是否开启TFO？[y/n]\n(默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
	TFO="true"
	colorEcho $BLUE "启用TFO"
	echo ""
    elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
	TFO="false"
	colorEcho $BLUE "禁用TFO"
	echo ""
    else
	colorEcho $RED "错误, 请输入 y/n"
	Set_tfo
    fi
}

Decide_sv6() {
    if [[ "${V6}" = "true" ]]; then
	SV6="::0"
    elif [[ "${V6}" = "false" ]]; then
	SV6="0.0.0.0"
    fi
}

Set_sport() {
    read -p $'请输入 ShadowTLS 端口 [1-65535]\n(默认: 9999，回车): ' SPORT
    [[ -z "${SPORT}" ]] && SPORT="9999"
    echo $((${SPORT}+0)) &>/dev/null
    if [[ $? -eq 0 ]]; then
	if [[ ${SPORT} -ge 1 ]] && [[ ${SPORT} -le 65535 ]]; then
		colorEcho $BLUE "端口: ${SPORT}"
		echo ""
	else
		colorEcho $RED "输入错误, 请输入正确的端口。"
		Set_sport
	fi
    else
	colorEcho $RED "输入错误, 请输入数字。"
	Set_sport
    fi
}

Set_domain() {
    for ((i=1;i<=${#domains[@]};i++ )); do
 	hint="${domains[$i-1]}"
 	echo -e "${GREEN}${i}${PLAIN}) ${hint}"
    done
    read -p "请选择域名[1-4] (默认: ${domains[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
	colorEcho $RED "错误, 请输入正确选项"
	Set_domain
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#domains[@]} ]]; then
	echo -e "${red}错误, 请输入正确选项${plain}"
	Set_domain
    fi
    DOMAIN=${domains[$pick-1]}
    if [[ "$pick" = "4" ]]; then
	colorEcho $BLUE "已选择: ${domains[$pick-1]}"
	echo ""
	read -p $'请输入自定义域名: ' DOMAIN
	if [[ -z "${DOMAIN}" ]]; then
		colorEcho $RED "错误, 请输入正确的域名"
		Set_domain
	else
		colorEcho $BLUE "域名：$DOMAIN"
		echo ""
	fi
    fi
}

show_domain() {
	colorEcho $BLUE "域名：${domains[$pick-1]}"
	echo ""
}

Set_pass() {
    read -p $'请设置ShadowTLS的密码\n(默认随机生成, 回车): ' PASS
    [[ -z "$PASS" ]] && PASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
    colorEcho $BLUE " 密码：$PASS"
    echo ""
}

Write_config(){
    cat > ${snell_conf}<<-EOF
[snell-server]
listen = ${LIP}:${PORT}
psk = ${PSK}
ipv6 = ${V6}
obfs = ${OBFS}
tfo = ${TFO}
# ${vers}
EOF
}

Install_snell(){
    Install_dependency
    selectversion
    Generate_conf
    Install_stls
    colorEcho $BLUE "安装完成"
    echo ""
    ShowInfo
}

Install_stls() {
    read -p $'是否安装ShadowTls？[y/n]\n(默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
	colorEcho $BLUE "安装ShadowTls"
	echo ""
	Generate_stls
	Download_snell
	Write_config
	Deploy_snell
	Download_stls
	Deploy_stls
    elif [[ "${answer}" = "n" || -z "${answer}" ]]; then
	colorEcho $BLUE "不安装ShadowTls"
	echo ""
	Download_snell
	Write_config
	Deploy_snell
    else
	colorEcho $RED " 输入错误, 请输入[y/n]。"
	Install_stls
    fi
}

Restart_snell(){
    systemctl restart snell
    colorEcho $BLUE " Snell已启动"
}

Restart_stls(){
    systemctl restart shadowtls
    colorEcho $BLUE " ShadowTls已重启"
}

Stop_snell(){
    systemctl stop snell
    colorEcho $BLUE " Snell已停止"
}

Uninstall_snell(){
    read -p $' 是否卸载Snell？[y/n]\n (默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
	if [[ -f "$stls_conf" ]]; then
		systemctl stop snell shadowtls
		systemctl disable snell shadowtls >/dev/null 2>&1
		rm -rf /etc/systemd/system/snell.service
		rm -rf /etc/systemd/system/shadowtls.service
		rm -rf /etc/snell
		systemctl daemon-reload
		colorEcho $BLUE " Snell已经卸载完毕"
	else
		systemctl stop snell
		systemctl disable snell >/dev/null 2>&1
		rm -rf /etc/systemd/system/snell.service
		rm -rf /etc/snell
		systemctl daemon-reload
		colorEcho $BLUE " Snell已经卸载完毕"
	fi
    else
	colorEcho $BLUE " 取消卸载"
    fi
}

ShowInfo() {
    if [[ ! -f $snell_conf ]]; then
	colorEcho $RED " Snell未安装"
 	exit 1
    fi
    echo ""
    echo -e " ${BLUE}Snell配置文件: ${PLAIN} ${RED}${snell_conf}${PLAIN}"
    colorEcho $BLUE " Snell配置信息："
    GetConfig
    outputSnell
    if [[ -f $stls_conf ]]; then
	GetConfig_stls
	outputSTLS
	echo ""
	echo -e " ${BLUE}若要使用ShadowTls, 请将${PLAIN}${RED} 端口 ${PLAIN}${BLUE}替换为${PLAIN}${RED} ${sport} ${PLAIN}"
    fi
}

GetConfig() {
    port=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f2`
    if [[ -z "${port}" ]]; then
	port=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f4`
    fi
    psk=`grep psk ${snell_conf} | awk -F '= ' '{print $2}'`
    ipv6=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
    if [[ $ipv6 == "true" ]]; then
	IP=${IP6}
    else
	IP=${IP4}
    fi
    obfs=`grep obfs ${snell_conf} | awk -F '= ' '{print $2}'`
    tfo=`grep tfo ${snell_conf} | awk -F '= ' '{print $2}'`
    ver=`grep '#' ${snell_conf} | awk -F '# ' '{print $2}'`
}

GetConfig_stls() {
    V6=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
    if [[ $V6 = "true" ]]; then
	sport=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f4`
    else
	sport=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f2`
    fi
    pass=`grep password ${stls_conf} | cut -d- -f13 | cut -d " " -f 2`
    domain=`grep password ${stls_conf} | cut -d- -f11 | cut -d " " -f 2`
}

outputSnell() {
    echo -e "   ${BLUE}协议: ${PLAIN} ${RED}snell${PLAIN}"
    echo -e "   ${BLUE}地址(IP): ${PLAIN} ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}Snell端口(PORT)：${PLAIN} ${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}Snell密钥(PSK)：${PLAIN} ${RED}${psk}${PLAIN}"
    echo -e "   ${BLUE}IPV6：${PLAIN} ${RED}${ipv6}${PLAIN}"
    echo -e "   ${BLUE}混淆(OBFS)：${PLAIN} ${RED}${obfs}${PLAIN}"
    echo -e "   ${BLUE}TCP记忆(TFO)：${PLAIN} ${RED}${tfo}${PLAIN}"
    echo -e "   ${BLUE}Snell版本(VER)：${PLAIN} ${RED}${ver}${PLAIN}"
}

outputSTLS() {
    echo -e "   ${BLUE}ShadowTls端口(PORT)：${PLAIN} ${RED}${sport}${PLAIN}"
    echo -e "   ${BLUE}ShadowTls密码(PASS)：${PLAIN} ${RED}${pass}${PLAIN}"
    echo -e "   ${BLUE}ShadowTls域名(DOMAIN)：${PLAIN} ${RED}${domain}${PLAIN}"
    echo -e "   ${BLUE}ShadowTls版本(VER)：${PLAIN} ${RED}v3${PLAIN}"
}

Change_snell(){
    tmp3=`grep '#' ${snell_conf} | awk -F '# ' '{print $2}'`
    Generate_conf
    if [[ -f "$stls_conf" ]]; then
	if [[ ${V6} = "true" ]]; then
		SV6="::0"
		SPORT=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f2`
		PASS=`grep password ${stls_conf} | cut -d- -f13 | cut -d " " -f 2`
		DOMAIN=`grep password ${stls_conf} | cut -d- -f11 | cut -d " " -f 2`
	else
		SV6="0.0.0.0"
		SPORT=`grep listen ${stls_conf} | cut -d- -f7 | cut -d: -f4`
		PASS=`grep password ${stls_conf} | cut -d- -f13 | cut -d " " -f 2`
		DOMAIN=`grep password ${stls_conf} | cut -d- -f11 | cut -d " " -f 2`
	fi
	Deploy_stls
    fi
    vers=$tmp3
    Write_config
    systemctl restart snell
    colorEcho $BLUE " 修改配置成功"
    ShowInfo
}

Change_stls() {
    PORT=`grep listen ${snell_conf} | awk -F '=' '{print $2}' | cut -d: -f4`
    if [[ -f "$stls_conf" ]]; then
	V6=`grep ipv6 ${snell_conf} | awk -F '= ' '{print $2}'`
	Generate_stls
	Deploy_stls
	colorEcho $BLUE " 修改配置成功"
	ShowInfo
    else
	colorEcho $RED " 未安装ShadowTls"
    fi
}

checkSystem
menu() {
	clear
	echo "################################"
	echo -e "#      ${RED}Snell一键安装脚本${PLAIN}       #"
	echo -e "# ${GREEN}作者${PLAIN}: 怠惰(Slotheve)         #"
	echo -e "# ${GREEN}网址${PLAIN}: https://slotheve.com   #"
	echo -e "# ${GREEN}频道${PLAIN}: https://t.me/SlothNews #"
	echo "################################"
	echo " ----------------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装Snell"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载Snell${PLAIN}"
	echo " ----------------------"
	echo -e "  ${GREEN}3.${PLAIN}  重启Snell"
	echo -e "  ${GREEN}4.${PLAIN}  重启ShadowTls"
	echo -e "  ${GREEN}5.${PLAIN}  停止Snell"
	echo " ----------------------"
	echo -e "  ${GREEN}6.${PLAIN}  查看Snell配置"
	echo -e "  ${GREEN}7.${PLAIN}  修改Snell配置"
	echo -e "  ${GREEN}8.${PLAIN}  修改ShadowTLS配置"
	echo " ----------------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo ""
	echo -n " 当前状态："
	statusText
	echo 

	read -p " 请选择操作[0-11]：" answer
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
			Restart_snell
			;;
		4)
			Restart_stls
			;;
		5)
			Stop_snell
			;;
		6)
			ShowInfo
			;;
		7)
			Change_snell
			;;
		8)
			Change_stls
			;;
		*)
			colorEcho $RED " 请选择正确的操作！"
   			sleep 2s
			menu
			;;
	esac
}
menu

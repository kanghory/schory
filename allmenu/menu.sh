#!/bin/bash
# =========================================
vlx=$(grep -c -E "^#& " "/etc/xray/config.json")
let vla=$vlx/2
vmc=$(grep -c -E "^### " "/etc/xray/config.json")
let vma=$vmc/2
ssh1="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"

trx=$(grep -c -E "^#! " "/etc/xray/config.json")
let tra=$trx/2
ssx=$(grep -c -E "^## " "/etc/xray/config.json")
let ssa=$ssx/2
COLOR1='\033[0;35m'
COLOR2='\033[0;39m'
clear

BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White
UWhite='\033[4;37m'       # White
On_IPurple='\033[0;105m'  #
On_IRed='\033[0;101m'
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
NC='\e[0m'

# // Export Color & Information
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'

# // Export Banner Status Information
export EROR="[${RED} EROR ${NC}]"
export INFO="[${YELLOW} INFO ${NC}]"
export OKEY="[${GREEN} OKEY ${NC}]"
export PENDING="[${YELLOW} PENDING ${NC}]"
export SEND="[${YELLOW} SEND ${NC}]"
export RECEIVE="[${YELLOW} RECEIVE ${NC}]"

# // Export Align
export BOLD="\e[1m"
export WARNING="${RED}\e[5m"
export UNDERLINE="\e[4m"

# // Exporting URL Host
export Server_URL="raw.githubusercontent.com/Zeastore/test/main"
export Server1_URL="raw.githubusercontent.com/Zeastore/limit/main"
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"
export MYIP=$( curl -s https://ipinfo.io/ip/ )
Name=$(curl -sS https://raw.githubusercontent.com/kanghory/schory/main/izin | grep $MYIP | awk '{print $2}')
Exp=$(curl -sS https://raw.githubusercontent.com/kanghory/schory/main/izin | grep $MYIP | awk '{print $3}')

# // Root Checking
if [ "${EUID}" -ne 0 ]; then
		echo -e "${EROR} Please Run This Script As Root User !"
		exit 1
fi

# // Exporting IP Address
export IP=$( curl -sS ipv4.icanhazip.com )

# TOTAL RAM
total_ram=` grep "MemTotal: " /proc/meminfo | awk '{ print $2}'`
totalram=$(($total_ram/1024))

# // Exporting Network Interface
export NETWORK_IFACE="$(ip route show to default | awk '{print $5}')"

# // Clear
clear
clear && clear && clear
clear;clear;clear
cek=$(service ssh status | grep active | cut -d ' ' -f5)
if [ "$cek" = "active" ]; then
stat=-f5
else
stat=-f7
fi
ngx=$(service nginx status | grep active | cut -d ' ' $stat)
if [ "$ngx" = "active" ]; then
resngx="${green}ON${NC}"
else
resngx="${red}OFF${NC}"
fi
v2r=$(service xray status | grep active | cut -d ' ' $stat)
if [ "$v2r" = "active" ]; then
resv2r="${green}ON${NC}"
else
resv2r="${red}OFF${NC}"
fi
function addhost(){
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -rp "Domain/Host: " -e host
echo ""
if [ -z $host ]; then
echo "????"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
setting-menu
else
rm -fr /etc/xray/domain
echo "IP=$host" > /var/lib/scrz-prem/ipvps.conf
echo $host > /etc/xray/domain
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Dont forget to renew gen-ssl"
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
fi
}
IPVPS=$(curl -sS ipv4.icanhazip.com )
ISPVPS=$( curl -s ipinfo.io/org )
ttoday="$(vnstat | grep today | awk '{print $8" "substr ($9, 1, 3)}' | head -1)"
tmon="$(vnstat -m | grep `date +%G-%m` | awk '{print $8" "substr ($9, 1 ,3)}' | head -1)"
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m                   ⇱ SCRIPT PREMIUM BY KANGHORY TUNNELING⇲             \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "${BICyan} "                                                                      
echo -e "${BICyan} ⇲  ${BICyan}Use Core        :  ${BIYellow}Xray-core"    
echo -e "${BICyan} ⇲  ${BICyan}Current Domain  :  ${BIYellow}$(cat /etc/xray/domain)${NC}" 
echo -e "${BICyan} ⇲  ${BICyan}NS Domain       :  $(cat /root/nsdomain)"
echo -e "${BICyan} ⇲  ${BICyan}IP-VPS          :  ${BIYellow}$IPVPS${NC}"                  
echo -e "${BICyan} ⇲  ${BICyan}ISP-VPS         :  ${BIYellow}$ISPVPS${NC}"
echo -e "${BICyan} ⇲  ${BICyan}TOTAL RAM       :  ${BIYellow}${totalram}MB"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m STATUS HARI INI  :  ⇱ ILMU PADI ⇲             \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "${BICyan} "
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m                    ⇱ STATUS SERVICE ⇲                        \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "${BICyan}┌──────────────────────────────────────────────────┐${NC}"
echo -e "  ${GREEN}SSH      ${NC} : ${GREEN} ON ${NC}   "     
echo -e "  ${GREEN}CRON     ${NC} : ${GREEN} ON ${NC}   "   
echo -e "  ${GREEN}WEBSOCKET${NC} :  ${GREEN}ON${NC}    " 
echo -e "  ${GREEN}DROPBEAR ${NC} :  ${GREEN}ON${NC}    " 
echo -e "${BICyan}└──────────────────────────────────────────────────┘${NC}"

echo -e "${GREEN}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  \033[0m ${BOLD}${YELLOW}SSH     VMESS       VLESS      TROJAN       SHADOWSOCKS$NC  $COLOR1"
echo -e "${GREEN}│  \033[0m ${Blue} $ssh1        $vma           $vla          $tra               $ssa   $NC"
echo -e "${GREEN}└──────────────────────────────────────────────────┘${NC}"

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[39;1;92m                    ⇱ STATUS PENGUNAAN ⇲                        \E[0m"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "     ${BICyan} NGINX ${NC}: ${GREEN}$resngx         ${LIGHT} Today  : $ttoday"
echo -e "     ${BICyan} XRAY  ${NC}: ${GREEN}$resv2r         ${LIGHT} Monthly: $tmon"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m                     ⇱ MENU SERVICE ⇲                         \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e ""
echo -e " ${BICyan}[${BIWhite}01${BICyan}]${RED} •${NC} ${YELLOW}SSH ${GREEN}MENU        $NC  ${BICyan}[${BIWhite}12${BICyan}]${RED} • ${NC}${YELLOW}GEN-SSL / CERTV $NC"
echo -e " ${BICyan}[${BIWhite}02${BICyan}]${RED} •${NC} ${YELLOW}VMESS ${GREEN}MENU      $NC  ${BICyan}[${BIWhite}13${BICyan}]${RED} • ${NC}${YELLOW}BANNER CHAGE $NC"
echo -e " ${BICyan}[${BIWhite}03${BICyan}]${RED} •${NC} ${YELLOW}VLESS ${GREEN}MENU      $NC  ${BICyan}[${BIWhite}14${BICyan}]${RED} • ${NC}${YELLOW}CEK RUNNING SERVICE $NC"
echo -e " ${BICyan}[${BIWhite}04${BICyan}]${RED} •${NC} ${YELLOW}TROJAN ${GREEN}MENU     $NC  ${BICyan}[${BIWhite}15${BICyan}]${RED} • ${NC}${YELLOW}CEK TRAFIC $NC"
echo -e " ${BICyan}[${BIWhite}05${BICyan}]${RED} •${NC} ${YELLOW}S-SOCK ${GREEN}MENU     $NC  ${BICyan}[${BIWhite}16${BICyan}]${RED} • ${NC}${YELLOW}SPEEDTEDT  $NC"
echo -e " ${BICyan}[${BIWhite}06${BICyan}]${RED} •${NC} ${YELLOW}MENU ${GREEN}BACKUP     $NC  ${BICyan}[${BIWhite}17${BICyan}]${RED} • ${NC}${YELLOW}CEK BANDWIDTH USE $NC"
echo -e " ${BICyan}[${BIWhite}07${BICyan}]${RED} •${NC} ${YELLOW}AUTO ${GREEN}REBOOT     $NC  ${BICyan}[${BIWhite}18${BICyan}]${RED} • ${NC}${YELLOW}LIMMIT SPEED $NC"
echo -e " ${BICyan}[${BIWhite}08${BICyan}]${RED} •${NC} ${YELLOW}REBOOT          $NC  ${BICyan}[${BIWhite}19${BICyan}]${RED} • ${NC}${YELLOW}WEBMIN $NC"
echo -e " ${BICyan}[${BIWhite}09${BICyan}]${RED} •${NC} ${YELLOW}RESTART ${GREEN}SERVICE $NC  ${BICyan}[${BIWhite}20${BICyan}]${RED} • ${NC}${YELLOW}SCRIPT INFO $NC"
echo -e " ${BICyan}[${BIWhite}10${BICyan}]${RED} •${NC} ${YELLOW}TRIAL           $NC  ${BICyan}[${BIWhite}21${BICyan}]${RED} • ${NC}${YELLOW}CLEAR LOG $NC"
echo -e " ${BICyan}[${BIWhite}11${BICyan}]${RED} •${NC} ${YELLOW}ADD ${GREEN}HOST        $NC  ${BICyan}[${BIWhite}22${BICyan}]${RED} • ${NC}${YELLOW}FIX MISSING POINTING $NC"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m                     ⇱ MENU SERVICE VPS ⇲                         \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e " ${BICyan}[${BIWhite}23${BICyan}]${RED} •${NC} ${YELLOW}GANTI ${GREEN}PASS VPS & HOSTNAME $NC  ${BICyan}[${BIWhite}24${BICyan}]${RED} • ${NC}${YELLOW}UPDATE SCRIPT $NC"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[39;1;92m                     ⇱ MENU BOT dan WEB SERVER ⇲                         \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e " ${BICyan}[${BIWhite}25${BICyan}]${RED} •${NC} ${YELLOW}SET ${GREEN}BOT TELEGRAM $NC  ${BICyan}[${BIWhite}26${BICyan}]${RED} • ${NC}${YELLOW}WEB SERVER $NC"
echo -e " ${BICyan}[${BIWhite}27${BICyan}]${RED} •${NC} ${YELLOW}SET DOMAIN WILDCARD $NC"
echo -e " ${BICyan}[${BIWhite} X ${BICyan}] TYPE X FOR EXIT ${BICyan}${BIYellow}${BICyan}${NC}"  
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"

echo -e "${BICyan}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${BICyan}│ ${BOLD}${BLUE}Client    = $Name                           ${NC}"
echo -e "${BICyan}│ ${BOLD}${BLUE}Expired   = $Exp                            ${NC}"
echo -e "${BICyan}│ ${BOLD}${BLUE}Developer = KANGHORY TUNNELING                   ${NC}"
echo -e "${BICyan}│ ${BOLD}${RED}Version   = SUPER LTS                       ${NC}"
echo -e "${BICyan}└──────────────────────────────────────────────────┘${NC}"

echo
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear ; menun-ssh ;;
2) clear ; menu-vmess ;;
3) clear ; menu-vless ;;
4) clear ; menu-trojan ;;
5) clear ; menu-ss ;;
6) clear ; menu-backup ;;
7) clear ; menu-autoreboot ;;
8) clear ; reboot ;;
9) clear ; restarts ;;
10) clear ; trialssh ;;
11) clear ; addhost ;;
12) clear ; genssl ;;
13) clear ; nano /etc/issue.net ;;
14) clear ; running ;;
15) clear ; cek-trafik ;;
16) clear ; cek-speed ;;
17) clear ; cek-bandwidth ;;
#18) clear ; cek-ram ;;
18) clear ; limit-speed ;;
19) clear ; wbm ;;
20) clear ; cat /root/log-install.txt ;;
21) clear ; clearlog ;;
#99) clear ; update ;;
22) clear ; fix ;;
23) clear ; menu_pw_host ;;
24) clear ; update-script ;;
25) clear ; menu_bot_tele ;;
26) clear ; instal-webserver ;;
27) clear ; menu-wildcard ;;

0) clear ; menu ;;
x) exit ;;
*) echo -e "" ; echo "Press any key to back exit" ; sleep 1 ; ./menu ;;
esac

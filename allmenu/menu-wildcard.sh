#!/bin/bash

NC='\033[0m'
r='\033[1;91m'
g='\033[1;92m'
y='\033[1;93m'
c='\033[0;96m'
w='\033[1;97m'

if [[ ! -f '/etc/.data' ]]; then
    echo -e "${y}File konfigurasi tidak ditemukan. Membuat file baru...${NC}"
    mkdir -p /etc
    cat <<EOF > /etc/.data
EMAILCF example@gmail.com
KEY your_global_api_key
EOF
    echo -e "${g}File /etc/.data berhasil dibuat dengan credential default.${NC}"
    sleep 2
fi

EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')

if [[ -z "$EMAILCF" || -z "$KEY" ]]; then
  echo -e "${r}Email/API Key tidak ditemukan !!${NC}"
  exit 1
fi

lane_atas(){ echo -e "${c}┌──────────────────────────────────────────┐${NC}"; }
lane_bawah(){ echo -e "${c}└──────────────────────────────────────────┘${NC}"; }

# ================== API ==================
get_account_id() {
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")
    AKUNID=$(echo "$response" | jq -r '.result[0].id')
}

get_zone_id() {
    ZONE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
        -H "X-Auth-Email: ${EMAILCF}" \
        -H "X-Auth-Key: ${KEY}" \
        -H "Content-Type: application/json" | jq -r .result[0].id)
}

# ================== AKUN ==================
add_akun_cf() {
    clear
    echo -e "${c}ADD AKUN CLOUDFLARE${NC}"
    read -p "Masukkan Email Cloudflare: " input_email
    read -p "Masukkan API Key Cloudflare: " input_key
    [[ -z "$input_email" || -z "$input_key" ]] && { echo -e "${r}Tidak boleh kosong!${NC}"; sleep 2; menu_wc; }
    cat <<EOF > /etc/.data
EMAILCF $input_email
KEY $input_key
EOF
    echo -e "${g}Akun Cloudflare berhasil ditambahkan.${NC}"
    sleep 2; menu_wc
}

del_akun_cf() {
    clear
    echo -e "${c}DELETE AKUN CLOUDFLARE${NC}"
    [[ -f "/etc/.data" ]] && { rm -f /etc/.data; echo -e "${g}Akun berhasil dihapus.${NC}"; } || echo -e "${r}File akun tidak ada.${NC}"
    sleep 2; menu_wc
}

# ================== WORKER ==================
generate_random(){ WORKER_NAME="$(</dev/urandom tr -dc a-j0-9 | head -c4)-$(</dev/urandom tr -dc a-z0-9 | head -c8)"; }

buat_worker() {
    generate_random; get_account_id
    WORKER_SCRIPT="addEventListener('fetch', e => { e.respondWith(new Response('Hello',{status:200})) })"
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    response=$(curl -s -w "%{http_code}" -o /tmp/resp.json -X PUT \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/javascript" \
        --data "$WORKER_SCRIPT" "$URL")
    [[ "$response" -eq 200 ]] && echo "Succes. Name : $WORKER_NAME" || { echo -e "${r}Gagal membuat worker${NC}"; cat /tmp/resp.json; }
    rm -f /tmp/resp.json
}

add_domain_worker() {
    get_account_id; WORKER_NAME="${1}"; CUSTOM_DOMAIN="${2}"
    DATA="{\"hostname\":\"$CUSTOM_DOMAIN\",\"service\":\"$WORKER_NAME\",\"environment\":\"production\"}"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/json" -d "$DATA" >/dev/null
    echo -e "${g}Domain $CUSTOM_DOMAIN ditambahkan${NC}"
}

# ================== WILDCARD ==================
add_wc() {
    echo -e "${c}Masukkan domain yg akan di pointing wildcard${NC}"
    read -p " Domain: " domain
    [[ "$domain" = "x" ]] && { echo "Batal"; exit 0; }
    workername=$(buat_worker | awk '{print $4}')
    [[ ! -f /etc/.wc/bug.txt ]] && { echo -e "${r}File bug.txt kosong!${NC}"; sleep 2; menu_wc; }
    data=($(cat /etc/.wc/bug.txt))
    for bug in "${data[@]}"; do add_domain_worker $workername ${bug}.${domain}; done
    echo -e "${g}Wildcard $domain selesai${NC}"
    read -p "Enter untuk kembali..."; menu_wc
}

del_wc() {
    echo -e "${c}Hapus Wildcard${NC}"
    echo -e "1) Pilih dari list aktif (hapus 1 wildcard)"
    echo -e "2) Input manual (hapus 1 wildcard)"
    echo -e "3) Hapus semua wildcard dari bug.txt"
    read -p "Pilih opsi: " pil
    if [[ "$pil" == "1" ]]; then
        list_wc "delete"
    elif [[ "$pil" == "2" ]]; then
        read -p "Masukkan domain: " domain
        hapus_wc_domain "$domain"
    elif [[ "$pil" == "3" ]]; then
        hapus_semua_wc
    fi
}

hapus_wc_domain() {
    domain="$1"
    DOMAIN=$(echo "$domain" | cut -d "." -f2-)
    get_zone_id
    get_account_id

    echo -e "${y}Menghapus wildcard untuk $domain${NC}"

    # Hapus bug subdomain
    if [[ -f /etc/.wc/bug.txt ]]; then
        data=($(cat /etc/.wc/bug.txt))
        for bug in "${data[@]}"; do
            target="${bug}.${domain}"
            RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${target}" \
                -H "X-Auth-Email: ${EMAILCF}" \
                -H "X-Auth-Key: ${KEY}" \
                -H "Content-Type: application/json" | jq -r '.result[].id')
            for rec in $RECORDS; do
                curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/$rec" \
                    -H "X-Auth-Email: ${EMAILCF}" \
                    -H "X-Auth-Key: ${KEY}" \
                    -H "Content-Type: application/json" >/dev/null
                echo -e "${g}Record ${target} dihapus${NC}"
            done
        done
    fi

    # Hapus mapping worker yang cocok
    MAPS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/json")
    MAP_IDs=$(echo "$MAPS" | jq -r --arg dom ".$domain" '.result[] | select(.hostname | endswith($dom)) | .id')

    for mid in $MAP_IDs; do
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/$mid" \
            -H "X-Auth-Email: $EMAILCF" \
            -H "X-Auth-Key: $KEY" \
            -H "Content-Type: application/json" >/dev/null
        echo -e "${g}Mapping worker $mid dihapus${NC}"
    done
}

hapus_semua_wc() {
    [[ ! -f /etc/.wc/bug.txt ]] && { echo -e "${r}File bug.txt kosong!${NC}"; sleep 2; menu_wc; }
    bugs=($(cat /etc/.wc/bug.txt))
    get_account_id
    RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")
    arr=($(echo "$RESP" | jq -r '.result[].hostname'))

    echo -e "${y}Menghapus semua wildcard yang ada di bug.txt...${NC}"
    for d in "${arr[@]}"; do
        for bug in "${bugs[@]}"; do
            if [[ "$d" == $bug.* ]]; then
                hapus_wc_domain "$d"
            fi
        done
    done
    echo -e "${g}Semua wildcard dari bug.txt berhasil dihapus${NC}"
    read -p "Enter untuk kembali..."; menu_wc
}

list_wc() {
    get_account_id
    RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")
    arr=($(echo "$RESP" | jq -r '.result[].hostname'))
    [[ ${#arr[@]} -eq 0 ]] && { echo -e "${r}Tidak ada wildcard aktif${NC}"; sleep 2; menu_wc; }
    [[ -f /etc/.wc/bug.txt ]] && bugs=($(cat /etc/.wc/bug.txt)) || bugs=()
    echo -e "${c}Daftar Wildcard Aktif:${NC}"
    i=1
    for d in "${arr[@]}"; do
        label=""
        for bug in "${bugs[@]}"; do
            [[ "$d" == $bug.* ]] && label="[BUG]"
        done
        echo "$i) $d $label"
        ((i++))
    done
    [[ "$1" == "delete" ]] && {
        read -p "Pilih nomor yang mau dihapus: " no
        hapus_wc_domain "${arr[$((no-1))]}"
        read -p "Enter untuk kembali..."; menu_wc
    } || { read -p "Enter untuk kembali..."; menu_wc; }
}

# ================== MENU ==================
menu_wc() {
clear
lane_atas
echo -e "${c}│${NC}     ${w}MENU POINTING WC${NC}     ${c}│${NC}"
lane_bawah
echo -e "${c}│${NC} 1) Add Akun Cloudflare"
echo -e "${c}│${NC} 2) Delete Akun Cloudflare"
echo -e "${c}│${NC} 3) Add Wildcard"
echo -e "${c}│${NC} 4) Delete Wildcard"
echo -e "${c}│${NC} 5) Add/Edit bug Wildcard"
echo -e "${c}│${NC} 6) List Wildcard Aktif"
echo -e "${c}│${NC} x) Exit"
lane_bawah
read -p "Select: " opt
case $opt in
1) add_akun_cf ;;
2) del_akun_cf ;;
3) add_wc ;;
4) del_wc ;;
5) mkdir -p /etc/.wc; nano /etc/.wc/bug.txt; menu_wc ;;
6) list_wc ;;
x|X) exit 0 ;;
*) menu_wc ;;
esac
}

menu_wc

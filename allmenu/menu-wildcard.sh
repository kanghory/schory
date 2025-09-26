#!/bin/bash

# =====================[ Warna Terminal ]=====================
NC='\033[0m'
R='\033[1;91m'
G='\033[1;92m'
Y='\033[1;93m'
C='\033[0;96m'
W='\033[1;97m'
U='\033[0;35m'

# =====================[ Persiapan Awal ]=====================
if [[ ! -f '/etc/.data' ]]; then
    echo -e "${Y}File konfigurasi tidak ditemukan. Membuat file baru...${NC}"
    mkdir -p /etc
    cat <<EOF > /etc/.data
EMAILCF 
KEY 
EOF
    echo -e "${G}Silakan isi email & token di /etc/.data sebelum lanjut.${NC}"
    sleep 2
fi

EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')

mkdir -p /etc/.wc

# =====================[ Fungsi Dasar CF ]=====================
get_account_id() {
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")

    success=$(echo "$response" | jq -r '.success')
    if [[ "$success" != "true" ]]; then
        return 1
    fi

    AKUNID=$(echo "$response" | jq -r '.result[0].id')
    echo "$AKUNID"
}

get_zone_id() {
    DOMAIN_INPUT="$1"
    ZONE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN_INPUT}&status=active" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" | jq -r .result[0].id)
}

generate_random() {
    WORKER_NAME="$(</dev/urandom tr -dc a-j0-9 | head -c4)-$(</dev/urandom tr -dc a-z0-9 | head -c8)-$(</dev/urandom tr -dc a-z0-9 | head -c5)"
}

# =====================[ Login / Logout Akun ]=====================
add_akun_cf() {
    clear
    echo -e "${C}ADD AKUN CLOUDFLARE${NC}"
    read -p "Masukkan Email Cloudflare: " input_email
    read -p "Masukkan API Token Cloudflare: " input_key
    if [[ -z "$input_email" || -z "$input_key" ]]; then
        echo -e "${R}Email/API token tidak boleh kosong!${NC}"
        return
    fi
    cat <<EOF > /etc/.data
EMAILCF $input_email
KEY $input_key
EOF
    echo -e "${G}Akun Cloudflare berhasil ditambahkan.${NC}"
}

del_akun_cf() {
    rm -f /etc/.data
    echo -e "${G}Akun Cloudflare berhasil dihapus.${NC}"
}

# =====================[ Worker Management ]=====================
buat_worker() {
    get_account_id || { echo -e "${R}Login gagal.${NC}"; return; }
    generate_random

    WORKER_SCRIPT="
    addEventListener('fetch', event => {
        event.respondWith(handleRequest(event.request))
    })
    async function handleRequest(request) {
        return new Response('Hello World!', { status: 200 })
    }"

    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    response=$(curl -s -w "%{http_code}" -o response.json -X PUT \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/javascript" \
        --data "$WORKER_SCRIPT" \
        "$URL")

    httpCode=$(tail -n1 <<<"$response")
    if [[ "$httpCode" -eq 200 ]]; then
        echo -e "${G}Worker berhasil dibuat: ${W}$WORKER_NAME${NC}"
    else
        echo -e "${R}Gagal membuat worker ($httpCode).${NC}"
        cat response.json
    fi
    rm -f response.json
}

hapus_worker() {
    get_account_id || { echo -e "${R}Login gagal.${NC}"; return; }
    echo -e "${C}Mengambil daftar worker...${NC}"
    workers=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')

    [[ -z "$workers" ]] && echo -e "${Y}Tidak ada worker.${NC}" && return

    echo -e "\n${U}Daftar Worker Aktif:${NC}"
    i=1
    for w in $workers; do
        echo "$i) $w"
        ((i++))
    done
    echo "a) Hapus semua"
    echo "x) Batal"
    read -p "Pilih nomor: " pilih

    if [[ "$pilih" == "a" ]]; then
        for w in $workers; do
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$w" \
                -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" >/dev/null
            echo -e "${G}Hapus: $w${NC}"
        done
    elif [[ "$pilih" == "x" ]]; then
        return
    else
        target=$(echo "$workers" | sed -n "${pilih}p")
        [[ -z "$target" ]] && echo -e "${R}Nomor tidak valid.${NC}" && return
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$target" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" >/dev/null
        echo -e "${G}Worker $target berhasil dihapus.${NC}"
    fi
}

# =====================[ Mapping Hostname (bug.txt + domain) ]=====================
add_domain_worker() {
    get_account_id || { echo -e "${R}Login gagal.${NC}"; return; }
    echo -e "${C}Ambil daftar worker...${NC}"
    workers=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')

    [[ -z "$workers" ]] && echo -e "${Y}Tidak ada worker.${NC}" && return

    echo -e "\n${U}Daftar Worker Aktif:${NC}"
    i=1
    for w in $workers; do echo "$i) $w"; ((i++)); done
    read -p "Pilih worker: " pil
    WORKER_NAME=$(echo "$workers" | sed -n "${pil}p")
    [[ -z "$WORKER_NAME" ]] && echo -e "${R}Nomor tidak valid.${NC}" && return

    read -p "Masukkan domain utama (contoh: vvip-hory.my.id): " DOMAIN_VPS
    [[ -z "$DOMAIN_VPS" ]] && echo -e "${R}Domain kosong.${NC}" && return

    if [[ ! -f /etc/.wc/bug.txt ]]; then
        echo -e "${R}File bug.txt tidak ditemukan.${NC}"
        return
    fi

    while read -r BUG; do
        [[ -z "$BUG" ]] && continue
        HOSTNAME="${BUG}.${DOMAIN_VPS}"
        DATA=$(cat <<EOF
{"hostname":"$HOSTNAME","service":"$WORKER_NAME","environment":"production"}
EOF
)
        RESPONSE=$(curl -s -w "%{http_code}" -o response.json \
            -X PUT "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/json" -d "$DATA")
        CODE=$(tail -n1 <<<"$RESPONSE")
        [[ "$CODE" -eq 200 ]] && echo -e "${G}✅ ${HOSTNAME}${NC}" || echo -e "${R}❌ ${HOSTNAME}${NC}"
        rm -f response.json
    done </etc/.wc/bug.txt
}

# =====================[ Pointing CNAME Manual ]=====================
pointing_cname() {
    read -p "Masukkan subdomain (contoh: vpn.domain.com): " domain_sub
    DOMAIN=$(echo "$domain_sub" | cut -d "." -f2-)
    SUB=$(echo "$domain_sub" | cut -d "." -f1)
    SUB_DOMAIN="*.${SUB}.${DOMAIN}"

    get_zone_id "$DOMAIN"
    RECORD_INFO=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
         -H "X-Auth-Email: ${EMAILCF}" -H "X-Auth-Key: ${KEY}" -H "Content-Type: application/json")

    RECORD=$(echo $RECORD_INFO | jq -r .result[0].id)

    if [[ "${#RECORD}" -le 10 ]]; then
         curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
         -H "X-Auth-Email: ${EMAILCF}" -H "X-Auth-Key: ${KEY}" -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}' >/dev/null
         echo -e "${G}CNAME ${SUB_DOMAIN} berhasil dibuat.${NC}"
    else
         curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
         -H "X-Auth-Email: ${EMAILCF}" -H "X-Auth-Key: ${KEY}" -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}' >/dev/null
         echo -e "${G}CNAME ${SUB_DOMAIN} diperbarui.${NC}"
    fi
}

# =====================[ Cek List Hostname Aktif ]=====================
cek_hostname_mapping() {
    get_account_id || { echo -e "${R}Login gagal.${NC}"; return; }
    echo -e "${C}Mengambil daftar hostname mapping aktif...${NC}"
    result=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")

    success=$(echo "$result" | jq -r '.success')
    [[ "$success" != "true" ]] && echo -e "${R}Gagal mengambil data mapping.${NC}" && return

    list=$(echo "$result" | jq -r '.result[] | "\(.hostname) -> \(.service)"')
    [[ -z "$list" ]] && echo -e "${Y}Tidak ada hostname aktif.${NC}" && return

    echo -e "\n${U}Daftar Hostname Aktif:${NC}"
    i=1
    while read -r line; do
        echo "$i) $line"
        ((i++))
    done <<<"$list"
}

# =====================[ Menu Utama ]=====================
menu_wc() {
    clear
    echo -e "${C}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${C}│${NC}        ${U}.::.${NC} ${W} MENU CLOUDFLARE AUTOMATION ${NC} ${U}.::.${NC}     ${C}│${NC}"
    echo -e "${C}└──────────────────────────────────────────────┘${NC}"

    if get_account_id >/dev/null 2>&1; then
        echo -e "🔐 Login Status: ${G}Connected${NC} (${W}$EMAILCF${NC})"
    else
        echo -e "🔒 Login Status: ${R}Not Connected${NC}"
    fi

    echo
    echo -e "1) Add Akun Cloudflare"
    echo -e "2) Delete Akun Cloudflare"
    echo -e "3) Add / Edit bug.txt"
    echo -e "4) Buat Worker JS"
    echo -e "5) Tambah Hostname Mapping dari bug.txt"
    echo -e "6) Pointing CNAME Manual"
    echo -e "7) Hapus Worker JS"
    echo -e "8) Cek List Hostname Mapping Aktif"
    echo -e "x) Exit"
    echo
    read -p "Pilih menu: " opt
    case $opt in
        1) add_akun_cf ;;
        2) del_akun_cf ;;
        3) nano /etc/.wc/bug.txt ;;
        4) buat_worker ;;
        5) add_domain_worker ;;
        6) pointing_cname ;;
        7) hapus_worker ;;
        8) cek_hostname_mapping ;;
        x|X) exit 0 ;;
        *) menu_wc ;;
    esac
    read -p "Tekan Enter untuk kembali..."
    menu_wc
}

menu_wc

#!/bin/bash

# ────────────────🎨 WARNA ────────────────
NC='\033[0m'
R='\033[1;91m'
G='\033[1;92m'
Y='\033[1;93m'
C='\033[1;96m'
W='\033[1;97m'
U='\033[0;35m'

# ────────────────⚙️ KONFIGURASI ────────────────
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    touch "$ENV_FILE"
fi

# ────────────────🔐 AUTH CF ────────────────
get_account_id() {
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY")

    AKUNID=$(echo "$response" | jq -r '.result[0].id')
    if [[ "$AKUNID" == "null" || -z "$AKUNID" ]]; then
        echo -e "${R}Gagal mendapatkan Account ID! Pastikan API Key dan Email benar.${NC}"
        return 1
    fi
    return 0
}

check_login_status() {
    if [[ -z "$EMAILCF" || -z "$KEY" ]]; then
        LOGIN_STATUS="${R}Belum Login${NC}"
    else
        resp=$(curl -s -o /dev/null -w "%{http_code}" -X GET "https://api.cloudflare.com/client/v4/user" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")
        if [ "$resp" == "200" ]; then
            LOGIN_STATUS="${G}Login Berhasil${NC} (${EMAILCF})"
        else
            LOGIN_STATUS="${R}Login Gagal / Invalid API${NC}"
        fi
    fi
}

# ────────────────🧩 UTIL ────────────────
generate_random() {
    WORKER_NAME=$(tr -dc 'a-z0-9' </dev/urandom | head -c 8)
}

pause() {
    echo -ne "\n${Y}Tekan Enter untuk kembali ke menu...${NC}"
    read
}

clear_screen() {
    clear
}

# ────────────────🔑 AKUN CLOUDFLARE ────────────────
add_account() {
    echo -e "${C}Masukkan Email Cloudflare:${NC}"
    read EMAIL
    echo -e "${C}Masukkan API Key Cloudflare:${NC}"
    read KEYCF

    echo "EMAILCF=\"$EMAIL\"" >"$ENV_FILE"
    echo "KEY=\"$KEYCF\"" >>"$ENV_FILE"

    source "$ENV_FILE"
    echo -e "${G}Akun berhasil ditambahkan & tersimpan di .env${NC}"
}

delete_account() {
    rm -f "$ENV_FILE"
    unset EMAILCF
    unset KEY
    echo -e "${G}Akun Cloudflare berhasil dihapus.${NC}"
}

# ────────────────🐞 BUG MANAGEMENT ────────────────
add_bug() {
    echo -e "${C}Masukkan daftar bug (pisahkan dengan enter, ketik 'done' jika selesai):${NC}"
    >bug.txt
    while true; do
        read bug
        [[ "$bug" == "done" ]] && break
        echo "$bug" >>bug.txt
    done
    echo -e "${G}Daftar bug tersimpan di bug.txt${NC}"
}

# ────────────────⚙️ WORKER JS ────────────────
buat_worker() {
    generate_random
    get_account_id || return

    WORKER_SCRIPT="
addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
    return new Response('Hello World!', { status: 200 })
}
"
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    response=$(curl -s -w "%{http_code}" -o response.json -X PUT \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/javascript" \
        --data "$WORKER_SCRIPT" \
        "$URL")

    httpCode=$(tail -n1 <<<"$response")

    if [ "$httpCode" -eq 200 ]; then
        echo -e "${G}Worker berhasil dibuat: ${W}$WORKER_NAME${NC}"
    else
        echo -e "${R}Gagal Membuat Worker '$WORKER_NAME' (Kode: $httpCode)${NC}"
        cat response.json
    fi
    rm -f response.json
}

hapus_worker() {
    get_account_id || return
    echo -e "${C}Mengambil daftar worker dari Cloudflare...${NC}"
    workers=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')

    if [ -z "$workers" ]; then
        echo -e "${Y}Tidak ada worker ditemukan.${NC}"
        return
    fi

    echo -e "\n${U}Daftar Worker Tersedia:${NC}"
    i=1
    for w in $workers; do
        echo "$i) $w"
        ((i++))
    done
    echo "a) Hapus semua"
    echo "x) Batal"
    echo -ne "${C}Pilih: ${NC}"
    read opt

    if [[ "$opt" == "x" ]]; then return; fi

    if [[ "$opt" == "a" ]]; then
        for w in $workers; do
            hapus_worker "$w"
        done
        return
    fi

    selected=$(echo "$workers" | sed -n "${opt}p")
    if [ -n "$selected" ]; then
        echo -e "${C}Menghapus worker: $selected${NC}"
        URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$selected"
        resp=$(curl -s -w "%{http_code}" -o response.json -X DELETE \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" "$URL")
        code=$(tail -n1 <<<"$resp")
        if [ "$code" -eq 200 ]; then
            echo -e "${G}Berhasil hapus $selected${NC}"
        else
            echo -e "${R}Gagal hapus $selected${NC}"
            cat response.json
        fi
        rm -f response.json
    fi
}

# ────────────────🌐 HOSTNAME MAPPING ────────────────
add_domain_worker() {
    get_account_id || return
    echo -e "${C}Memetakan bug.txt ke worker aktif...${NC}"

    if [ ! -f bug.txt ]; then
        echo -e "${R}bug.txt tidak ditemukan!${NC}"
        return
    fi

    echo -e "${C}Daftar Worker Aktif:${NC}"
    workers=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')
    echo "$workers"
    echo -ne "${C}Masukkan nama worker yang akan digunakan:${NC} "
    read WORKER_NAME

    while read -r BUG; do
        [ -z "$BUG" ] && continue
        DATA=$(cat <<EOF
{
    "hostname": "$BUG",
    "service": "$WORKER_NAME",
    "environment": "production"
}
EOF
        )

        RESP=$(curl -s -w "%{http_code}" -o response.json \
            -X PUT "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
            -H "X-Auth-Email: $EMAILCF" \
            -H "X-Auth-Key: $KEY" \
            -H "Content-Type: application/json" \
            -d "$DATA")
        CODE=$(tail -n1 <<<"$RESP")
        if [ "$CODE" -eq 200 ]; then
            echo -e "${G}Berhasil menambahkan: $BUG${NC}"
        else
            echo -e "${R}Gagal menambahkan $BUG (Kode $CODE)${NC}"
        fi
    done <bug.txt
    rm -f response.json
}

list_mapping() {
    get_account_id || return
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[] | "\(.hostname) => \(.service)"'
}

hapus_mapping() {
    get_account_id || return
    echo -e "${C}Mengambil daftar mapping...${NC}"
    maps=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[] | "\(.hostname):\(.service)"')

    if [ -z "$maps" ]; then
        echo -e "${Y}Tidak ada mapping ditemukan.${NC}"
        return
    fi

    i=1
    declare -a hostnames
    declare -a services
    echo -e "${U}Daftar Mapping Aktif:${NC}"
    while read -r line; do
        hostname=$(echo "$line" | cut -d: -f1)
        service=$(echo "$line" | cut -d: -f2)
        hostnames[i]="$hostname"
        services[i]="$service"
        echo "$i) $hostname => $service"
        ((i++))
    done <<<"$maps"
    echo "a) Hapus semua"
    echo "x) Batal"
    echo -ne "${C}Pilih: ${NC}"
    read opt

    if [[ "$opt" == "x" ]]; then return; fi
    if [[ "$opt" == "a" ]]; then
        for idx in "${!hostnames[@]}"; do
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records/${hostnames[idx]}" \
                -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY"
            echo -e "${G}Hapus ${hostnames[idx]}${NC}"
        done
        return
    fi

    hostname=${hostnames[$opt]}
    if [ -n "$hostname" ]; then
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records/$hostname" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY"
        echo -e "${G}Hapus $hostname${NC}"
    fi
}

# ────────────────📜 MENU ────────────────
while true; do
    clear_screen
    check_login_status
    echo -e "${C}╔══════════════════════════════════════════╗${NC}"
    echo -e "${C}║   🌩️ CLOUDFLARE WORKER MANAGER CLI   ║${NC}"
    echo -e "${C}╚══════════════════════════════════════════╝${NC}"
    echo -e "Status Login : $LOGIN_STATUS\n"

    echo -e "${W}1.${NC} Tambah Akun Cloudflare"
    echo -e "${W}2.${NC} Hapus Akun Cloudflare"
    echo -e "${W}3.${NC} Tambah Bug (bug.txt)"
    echo -e "${W}4.${NC} Buat Worker JS"
    echo -e "${W}5.${NC} Tambah Hostname Mapping dari bug.txt"
    echo -e "${W}6.${NC} Lihat List Hostname Mapping Aktif"
    echo -e "${W}7.${NC} Hapus Hostname Mapping"
    echo -e "${W}8.${NC} Lihat List Worker JS Aktif"
    echo -e "${W}9.${NC} Hapus Worker JS"
    echo -e "${W}0.${NC} Keluar"
    echo
    echo -ne "${Y}Pilih menu: ${NC}"
    read menu

    case $menu in
    1) add_account ;;
    2) delete_account ;;
    3) add_bug ;;
    4) buat_worker ;;
    5) add_domain_worker ;;
    6) list_mapping ;;
    7) hapus_mapping ;;
    8) get_account_id && curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id' ;;
    9) hapus_worker ;;
    0) exit 0 ;;
    *) echo -e "${R}Pilihan tidak valid!${NC}" ;;
    esac

    pause
done

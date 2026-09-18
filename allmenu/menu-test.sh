#!/bin/bash

# Warna
CYAN='\033[1;96m'
LIGHT='\033[1;97m'
NC='\033[0m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
GREEN='\033[1;92m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[0;41;36m               DELETE USER                \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " [1] Hapus Single User"
echo -e " [2] Hapus Multi User (Range: user1-5 ATAU Koma: Gus,Hudi,joko)"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p " Pilih Mode [1/2] : " mode_del

users_to_del=()

case $mode_del in
    1)
        read -p " Username SSH to Delete : " Pengguna
        [[ -n "$Pengguna" ]] && users_to_del+=("$Pengguna")
        ;;
    2)
        read -p " Format Multi Delete : " multi_input
        
        # FIX REGEX: Range format (contoh: user1-5 atau zxl1241-1245)
        if [[ "$multi_input" =~ ^([a-zA-Z_-]*[a-zA-Z_-])?([0-9]+)-([0-9]+)$ ]]; then
            prefix="${BASH_REMATCH[1]}"
            start_str="${BASH_REMATCH[2]}"
            end_str="${BASH_REMATCH[3]}"

            # Konversi ke integer basis 10
            start=$((10#$start_str))
            end=$((10#$end_str))

            if (( start > end )); then
                echo -e "\n${RED}[ERROR]${NC} Angka awal ($start) tidak boleh lebih besar dari angka akhir ($end)!"
                read -n 1 -s -r -p "Tekan ENTER untuk kembali..."
                [[ -f /usr/bin/menu ]] && /usr/bin/menu || exit 0
            fi

            # Jaga panjang digit (jika ada angka berkepala nol misal 01-05)
            num_len=${#start_str}

            for (( i=start; i<=end; i++ )); do
                formatted_num=$(printf "%0${num_len}d" "$i")
                users_to_del+=("${prefix}${formatted_num}")
            done

        # Comma format (contoh: Gus,Hudi,joko)
        elif [[ "$multi_input" == *","* ]]; then
            IFS=',' read -ra ADDR <<< "$multi_input"
            for item in "${ADDR[@]}"; do
                clean_user=$(echo "$item" | xargs)
                [[ -n "$clean_user" ]] && users_to_del+=("$clean_user")
            done
        else
            # Single input fallback
            clean_user=$(echo "$multi_input" | xargs)
            [[ -n "$clean_user" ]] && users_to_del+=("$clean_user")
        fi
        ;;
    *)
        echo -e "\n${RED}[ERROR]${NC} Pilihan tidak valid."
        read -n 1 -s -r -p "Tekan ENTER untuk kembali..."
        [[ -f /usr/bin/menu ]] && /usr/bin/menu || exit 0
        ;;
esac

if [[ ${#users_to_del[@]} -eq 0 ]]; then
    echo -e "\n${RED}Failure: Username cannot be empty.${NC}"
else
    success_count=0
    fail_count=0

    echo -e "\n${CYAN}──────────────────────────────────────────${NC}"
    for user in "${users_to_del[@]}"; do
        if getent passwd "$user" > /dev/null 2>&1; then
            pkill -KILL -u "$user" 2>/dev/null
            userdel "$user" > /dev/null 2>&1

            limit_file="/etc/klmpk/limit/ssh/ip/$user"
            [[ -f "$limit_file" ]] && rm -f "$limit_file"

            log_file="/etc/klmpk/log-ssh/$user.txt"
            [[ -f "$log_file" ]] && rm -f "$log_file"

            echo -e "User \033[1;33m$user\033[0m berhasil dihapus beserta Limit IP & Log."
            ((success_count++))
        else
            echo -e "Failure: User \033[1;31m$user\033[0m does not exist."
            ((fail_count++))
        fi
    done
    echo -e "${CYAN}──────────────────────────────────────────${NC}"
    echo -e "${GREEN}TOTAL KETERANGAN PENGHAPUSAN:${NC}"
    echo -e " Real User Berhasil Dihapus : ${YELLOW}$success_count${NC} user"
    echo -e " User Gagal / Tidak Ada     : ${RED}$fail_count${NC} user"
    echo -e "${CYAN}──────────────────────────────────────────${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu..."
[[ -f /usr/bin/menu ]] && /usr/bin/menu || exit 0

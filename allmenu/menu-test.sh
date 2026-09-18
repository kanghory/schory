#!/bin/bash

# ==================================================
# BLOK 1: VARIABEL GLOBAL & WARNA
# ==================================================
CYAN='\033[1;96m'
LIGHT='\033[1;97m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
GREEN='\033[1;92m'
NC='\033[0m'

# ==================================================
# BLOK 2: AREA LAB / SANDBOX FUNGSI
# Taruh script fitur baru yang sedang dikerjakan di sini.
# Bungkus dengan function.
# ==================================================

function fitur_test_A() {
    clear
    echo -e "${YELLOW}Ini adalah tempat test fitur A${NC}"
    # ... taruh script uji coba Anda di sini ...
    
    echo ""
    read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu test..."
    menu-test
}

function fitur_test_B() {
    clear
    echo -e "${YELLOW}Ini adalah tempat test fitur B${NC}"
    # ... taruh script uji coba Anda di sini ...
    
    echo ""
    read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu test..."
    menu-test
}

# ==================================================
# BLOK 3: ANTARMUKA (UI) & ROUTER
# ==================================================
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m          ⇱ MENU TESTING / LAB FITUR ⇲          \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " [1] Uji Coba Fitur A (Sebutkan Nama Fiturnya)"
echo -e " [2] Uji Coba Fitur B (Sebutkan Nama Fiturnya)"
echo -e " [0] Kembali ke Menu Utama Produksi"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p " Pilih Fitur Yang Ingin Di-test [0-2]: " test_opt

case $test_opt in
    1)
        # Memanggil fungsi test A
        fitur_test_A
        ;;
    2)
        # Memanggil fungsi test B
        fitur_test_B
        ;;
    0)
        # Keluar dari lab dan kembali ke menu utama VPS
        [[ -f /usr/bin/menu ]] && /usr/bin/menu || exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Pilihan tidak valid!"
        sleep 1
        menu-test
        ;;
esac

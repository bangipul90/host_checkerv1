#!/bin/bash

# Warna ANSI
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

FOLDER="ping"
MAX_PARALLEL=10  # Jumlah proses paralel (multi-threaded)

# Deteksi perintah ping sesuai OS
if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "cygwin"* ]]; then
    PING_CMD='ping -n 1'
else
    PING_CMD='ping -c 1 -W 1'
fi

# Cek folder ping/
if [ ! -d "$FOLDER" ]; then
    echo -e "${RED}[!] Folder '$FOLDER' tidak ditemukan.${NC}"
    exit 1
fi

# Tampilkan daftar file dalam folder ping/
echo -e "${BLUE}📁 Pilih file dari folder '${FOLDER}':${NC}"
echo "========================================"
files=()
i=1
for file in "$FOLDER"/*.txt; do
    [ -e "$file" ] || continue
    files+=("$file")
    echo "[$i] $(basename "$file")"
    ((i++))
done

# Input pilihan file
echo -ne "${YELLOW}📝 Masukkan nomor file yang ingin digunakan: ${NC}"
read choice
selected="${files[$((choice - 1))]}"

if [ -z "$selected" ] || [ ! -f "$selected" ]; then
    echo -e "${RED}[!] Pilihan tidak valid.${NC}"
    exit 1
fi

echo -e "\n${BLUE}🚀 Memulai pengecekan paralel dari file: $(basename "$selected") (maks ${MAX_PARALLEL} domain sekaligus)...${NC}"
echo "====================================================="

# Jalankan paralel ping + deteksi Cloudflare
grep -v '^\s*$' "$selected" | xargs -P "$MAX_PARALLEL" -I{} bash -c '
    domain="{}"
    if '"$PING_CMD"' "$domain" > /dev/null 2>&1; then
        nslookup "$domain" 2>/dev/null | grep -iE "cloudflare|104\.|172\.|198\.|2606:4700" >/dev/null
        if [ $? -eq 0 ]; then
            cf_info=" (Cloudflare)"
        else
            cf_info=""
        fi
        echo -e "$domain : \033[0;32m✅ OK\033[0m\033[1;33m$cf_info\033[0m"
    fi
'

echo "====================================================="
echo -e "${YELLOW}✅ Selesai pengecekan domain aktif.${NC}\n"

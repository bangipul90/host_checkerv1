#!/bin/bash

echo -e "
\e[1;32m🔍 TOOL       : \e[0mHOST CHECKER
\e[1;36m🔒 PROVIDER   : \e[0mVPN SUKADATA NETWORK
\e[1;33m🚀 STATUS     : \e[0mSECURE & STABLE CONNECTION
"

DOMAIN_DIR="domain"
SETTING_DIR="setting"
TIMEOUT=1
PORT_TIMEOUT=0.5
SPIN='|/-\'
CLOUDFLARE_TAG="[CLOUDFLARE]"

PORT_FILE="$SETTING_DIR/port.txt"
METHOD_FILE="$SETTING_DIR/method.txt"

if [[ ! -f "$PORT_FILE" ]]; then
    echo "❌ File $PORT_FILE tidak ditemukan!"
    exit 1
fi

if [[ ! -f "$METHOD_FILE" ]]; then
    echo "❌ File $METHOD_FILE tidak ditemukan!"
    exit 1
fi

mapfile -t PORTS_TO_CHECK < "$PORT_FILE"
mapfile -t METHODS < "$METHOD_FILE"

# === PILIH FILE DOMAIN ===
echo "📁 Pilih file daftar domain dari folder '$DOMAIN_DIR':"
echo "========================================================"
mapfile -t FILE_LIST < <(find "$DOMAIN_DIR" -type f)

if [[ ${#FILE_LIST[@]} -eq 0 ]]; then
    echo "❌ Tidak ada file di folder '$DOMAIN_DIR'."
    exit 1
fi

for i in "${!FILE_LIST[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${FILE_LIST[$i]}"
done

echo -n "📝 Masukkan nomor file yang ingin digunakan: "
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#FILE_LIST[@]})); then
    echo "❌ Pilihan tidak valid!"
    exit 1
fi

DOMAIN_FILE="${FILE_LIST[$((choice - 1))]}"
echo "✅ Menggunakan file: $DOMAIN_FILE"
echo ""

mkdir -p result
BASENAME=$(basename "$DOMAIN_FILE")
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_FILE="result/${BASENAME}-${TIMESTAMP}.txt"

mapfile -t DOMAIN_LIST < "$DOMAIN_FILE"
TOTAL=${#DOMAIN_LIST[@]}
DONE=0
TMP_RESULT=$(mktemp)

print_spinner() {
    local text="$1"
    local i=0
    while true; do
        local spin_char="${SPIN:i++%${#SPIN}:1}"
        echo -ne "\r $spin_char  $text\033[K"
        sleep 0.1
    done
}

echo "📦 Menampilkan domain yang menggunakan Cloudflare saja"
echo "========================================================"

for domain in "${DOMAIN_LIST[@]}"; do
    [[ -z "$domain" ]] && continue
    ((DONE++))
    percent=$((DONE * 100 / TOTAL))
    status_line=$(printf "Memeriksa: %-35s [ %2d / %d ] (%d%%)" "$domain" "$DONE" "$TOTAL" "$percent")

    (print_spinner "$status_line") &
    SPIN_PID=$!

    headers=$(curl -s -I --connect-timeout $TIMEOUT --max-time $TIMEOUT "http://$domain")
    kill $SPIN_PID 2>/dev/null
    wait $SPIN_PID 2>/dev/null

    if echo "$headers" | grep -qiE "cloudflare|cf-ray"; then
        echo -ne "\r✔️  $status_line\n"
        echo "🌐 $CLOUDFLARE_TAG $domain"

        hasil_method=""

        for method in "${METHODS[@]}"; do
            for port in "${PORTS_TO_CHECK[@]}"; do
                echo -ne "\r🔎 Mengecek $method - port $port pada $domain...\033[K"
                timeout $PORT_TIMEOUT bash -c "echo > /dev/tcp/$domain/$port" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" --connect-timeout $TIMEOUT --max-time $TIMEOUT "http://$domain:$port")
                    [[ "$code" != "000" ]] && hasil_method+="[${method^^} - port $port]=$code"$'\n'
                fi
            done
        done

        sorted_output=$(echo "$hasil_method" | sort -k1,1 -k3,3n)
        {
            echo "🌐 $CLOUDFLARE_TAG $domain"
            echo "$sorted_output" | while IFS='=' read -r tag code; do
                printf "  %-25s => %s\n" "$tag" "$code"
            done
            echo ""
        } >> "$TMP_RESULT"
    else
        echo -ne "\r✔️  $status_line\033[K"
    fi
done

echo -e "\n"
cat "$TMP_RESULT" | tee "$OUTPUT_FILE"
rm -f "$TMP_RESULT"
echo "✅ Selesai! Hasil disimpan di: $OUTPUT_FILE"

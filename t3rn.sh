#!/bin/bash

# Warna untuk output
GRN='\e[32m'
YLW='\e[33m'
RED='\e[31m'
BLU='\e[34m'
RST='\e[0m'

# Variabel global
STEPS_TOTAL=7

# Fungsi untuk menampilkan pesan dengan nomor langkah
log_step() {
    printf "${GRN}[%d/%d] %s${RST}\n" "$1" "$STEPS_TOTAL" "$2"
}

# Fungsi menu utama
display_menu() {
    printf "\n${BLU}=== T3RN EXECUTOR CONTROL ===${RST}\n"
    printf "${YLW}1. Pasang Executor\n"
    printf "2. Hapus Executor\n"
    printf "3. Keluar${RST}\n"
    printf "${BLU}============================${RST}\n"
    read -p "${YLW}Pilih [1-3]: ${RST}" option
    
    case "$option" in
        1) setup_executor ;;
        2) remove_executor ;;
        3) printf "${GRN}Terima kasih telah menggunakan program ini.${RST}\n"; exit 0 ;;
        *) printf "${RED}Opsi tidak valid!${RST}\n"; display_menu ;;
    esac
}

# Fungsi instalasi executor
setup_executor() {
    # Input pengguna
    read -p "${YLW}Nama user (default: root): ${RST}" user
    EXEC_USER=${user:-root}
    
    printf "${YLW}Masukkan PRIVATE_KEY_LOCAL: ${RST}"
    read -s key
    printf "\n"
    
    # Direktori dan file
    DIR="/home/$EXEC_USER/t3rn"
    SVC="/etc/systemd/system/t3rn-executor.service"
    ENV="/etc/t3rn-executor.env"

    # Langkah-langkah instalasi
    log_step 1 "Menyiapkan direktori..."
    mkdir -p "$DIR" && cd "$DIR" || exit 1

    log_step 2 "Mencari versi terbaru..."
    VERSION=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    printf "${GRN}Versi: %s${RST}\n" "$VERSION"

    log_step 3 "Mengunduh paket..."
    wget -q "https://github.com/t3rn/executor-release/releases/download/$VERSION/executor-linux-$VERSION.tar.gz"
    tar -xzf "executor-linux-$VERSION.tar.gz"
    cd executor/executor/bin || exit 1

    log_step 4 "Menulis konfigurasi..."
    sudo tee "$ENV" > /dev/null <<EOL
RPC_ENDPOINTS="{\"l2rn\": [\"https://b2n.rpc.caldera.xyz/http\"], \"arbt\": [\"https://arbitrum-sepolia.drpc.org\", \"https://sepolia-rollup.arbitrum.io/rpc\"], \"bast\": [\"https://base-sepolia-rpc.publicnode.com\", \"https://base-sepolia.drpc.org\"], \"opst\": [\"https://sepolia.optimism.io\", \"https://optimism-sepolia.drpc.org\"], \"unit\": [\"https://unichain-sepolia.drpc.org\", \"https://sepolia.unichain.org\"]}"
EOL

    log_step 5 "Mengatur izin..."
    sudo chown -R "$EXEC_USER:$EXEC_USER" "$DIR"
    sudo chmod 600 "$ENV"

    log_step 6 "Membuat layanan systemd..."
    sudo tee "$SVC" > /dev/null <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=$EXEC_USER
WorkingDirectory=$DIR/executor/executor/bin
ExecStart=$DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_MAX_L3_GAS_PRICE=100
Environment=PRIVATE_KEY_LOCAL=$key
Environment=ENABLED_NETWORKS=arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn
EnvironmentFile=$ENV
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true

[Install]
WantedBy=multi-user.target
EOL

    log_step 7 "Memulai layanan..."
    sudo systemctl daemon-reload
    sudo systemctl enable t3rn-executor.service
    sudo systemctl start t3rn-executor.service

    printf "${GRN}✅ Instalasi selesai!${RST}\n"
    
    read -p "${YLW}Lihat log? (y/n): ${RST}" logs
    if [ "$logs" = "y" ] || [ "$logs" = "Y" ]; then
        printf "${YLW}Menampilkan log (Ctrl+C untuk keluar)...${RST}\n"
        sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
    else
        printf "${GRN}Lihat log: sudo journalctl -u t3rn-executor.service -f${RST}\n"
        sleep 2
        display_menu
    fi
}

# Fungsi untuk menghapus executor
remove_executor() {
    printf "${YLW}Menghapus T3rn Executor...${RST}\n"
    
    if systemctl is-active --quiet t3rn-executor.service; then
        printf "${YLW}[1/4] Menghentikan layanan...${RST}\n"
        sudo systemctl stop t3rn-executor.service
        sudo systemctl disable t3rn-executor.service
    else
        printf "${YLW}[1/4] Layanan tidak aktif.${RST}\n"
    fi
    
    printf "${YLW}[2/4] Menghapus file layanan...${RST}\n"
    [ -f "/etc/systemd/system/t3rn-executor.service" ] && sudo rm /etc/systemd/system/t3rn-executor.service && sudo systemctl daemon-reload
    
    printf "${YLW}[3/4] Menghapus konfigurasi...${RST}\n"
    [ -f "/etc/t3rn-executor.env" ] && sudo rm /etc/t3rn-executor.env
    
    read -p "${YLW}[4/4] Hapus direktori? (y/n): ${RST}" del_dir
    if [ "$del_dir" = "y" ] || [ "$del_dir" = "Y" ]; then
        read -p "${YLW}Nama user instalasi (default: root): ${RST}" user
        EXEC_USER=${user:-root}
        DIR="/home/$EXEC_USER/t3rn"
        
        [ -d "$DIR" ] && sudo rm -rf "$DIR" && printf "${GRN}Direktori %s dihapus.${RST}\n" "$DIR" || printf "${YLW}Direktori tidak ada.${RST}\n"
    fi
    
    printf "${GRN}✅ Penghapusan selesai!${RST}\n"
    sleep 2
    display_menu
}

# Jalankan program
display_menu

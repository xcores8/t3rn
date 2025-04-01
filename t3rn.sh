#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print formatted messages
print_step() {
    echo -e "${GREEN}[$1/$TOTAL_STEPS] $2${NC}"
}

# Function to install the executor
install_executor() {
    # Configuration
    TOTAL_STEPS=7

    # Ask for private key (securely)
    echo -e "${YELLOW}Masukkan PRIVATE_KEY_LOCAL:${NC}"
    read -sp "" PRIVATE_KEY_LOCAL
    echo ""

    # Ask for Infura API key
    echo -e "${YELLOW}Masukkan Infura API Key:${NC}"
    read -p "" INFURA_API_KEY
    echo ""

    # Set directory paths (default to root)
    INSTALL_DIR="/root/t3rn"
    SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"
    ENV_FILE="/etc/t3rn-executor.env"

    # Step 1: Create installation directory
    print_step "1" "Membuat direktori instalasi..."
    mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

    # Step 2: Get latest release version
    print_step "2" "Mendapatkan versi terbaru..."
    TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    echo -e "${GREEN}Versi terbaru: $TAG${NC}"

    # Step 3: Download and extract release
    print_step "3" "Mengunduh dan mengekstrak rilis..."
    wget -q "https://github.com/t3rn/executor-release/releases/download/$TAG/executor-linux-$TAG.tar.gz"
    tar -xzf "executor-linux-$TAG.tar.gz"
    cd executor/executor/bin

    # Step 4: Create configuration file with Infura API key
    print_step "4" "Membuat file konfigurasi..."
    sudo bash -c "cat > $ENV_FILE" <<EOL
RPC_ENDPOINTS="{\"l2rn\": [\"https://b2n.rpc.caldera.xyz/http\"], \"arbt\": [\"https://arbitrum-sepolia.infura.io/v3/$INFURA_API_KEY\"], \"bast\": [\"https://base-sepolia.infura.io/v3/$INFURA_API_KEY\"], \"opst\": [\"https://optimism-sepolia.infura.io/v3/$INFURA_API_KEY\"], \"unit\": [\"https://unichain-sepolia.infura.io/v3/$INFURA_API_KEY\"], \"blst\": [\"https://sepolia.blast.io\"]}"
EOL

    # Step 5: Set proper permissions
    print_step "5" "Mengatur kepemilikan dan izin..."
    sudo chown -R root:root "$INSTALL_DIR"
    sudo chmod 600 "$ENV_FILE"

    # Step 6: Create systemd service file
    print_step "6" "Membuat file service..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=root
WorkingDirectory=$INSTALL_DIR/executor/executor/bin
ExecStart=$INSTALL_DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_MAX_L3_GAS_PRICE=100
Environment=PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
Environment=ENABLED_NETWORKS=arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn
EnvironmentFile=$ENV_FILE
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true

[Install]
WantedBy=multi-user.target
EOL

    # Step 7: Start service
    print_step "7" "Memulai layanan..."
    sudo systemctl daemon-reload
    sudo systemctl enable t3rn-executor.service
    sudo systemctl start t3rn-executor.service

    # Installation complete
    echo -e "${GREEN}✅ Executor berhasil diinstall dan dijalankan!${NC}"
    
    # Ask if user wants to see logs
    read -p "$(echo -e ${YELLOW}"Tampilkan log? (y/n): "${NC})" show_logs
    if [[ $show_logs == "y" || $show_logs == "Y" ]]; then
        echo -e "${YELLOW}Menampilkan log real-time... (Tekan Ctrl+C untuk keluar)${NC}"
        sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
    else
        echo -e "${GREEN}Untuk melihat log gunakan perintah: sudo journalctl -u t3rn-executor.service -f${NC}"
    fi
}

# Start program by directly running installation
install_executor

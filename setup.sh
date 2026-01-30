#!/bin/bash

# HomeCraft - Minecraft Server Admin Panel Setup Script
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MC_DIR="/minecraft"
MC_JAR_URL="https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar"
PANEL_PORT=3000

echo -e "${GREEN}"
echo "  ⛏️  HomeCraft Setup Script"
echo "  =========================="
echo -e "${NC}"

# Parse arguments
PRODUCTION=false
SKIP_MC=false
SKIP_SERVICE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --production|-p)
            PRODUCTION=true
            shift
            ;;
        --skip-minecraft)
            SKIP_MC=true
            shift
            ;;
        --skip-service)
            SKIP_SERVICE=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./setup.sh [options]"
            echo ""
            echo "Options:"
            echo "  --production, -p    Build for production and create systemd service"
            echo "  --skip-minecraft    Skip Minecraft server download"
            echo "  --skip-service      Skip systemd service creation"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check for required tools
echo -e "${BLUE}[1/7]${NC} Checking requirements..."

if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    echo "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}Error: Node.js 18+ required (found v$NODE_VERSION)${NC}"
    exit 1
fi
echo -e "  ✓ Node.js $(node -v)"

if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    exit 1
fi
echo -e "  ✓ npm $(npm -v)"

if ! command -v java &> /dev/null; then
    echo -e "${YELLOW}Warning: Java is not installed${NC}"
    echo -e "  Installing OpenJDK 21..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y openjdk-21-jre-headless
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y java-21-openjdk-headless
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm jre-openjdk-headless
    else
        echo -e "${RED}Please install Java 17+ manually${NC}"
        exit 1
    fi
fi
echo -e "  ✓ Java $(java -version 2>&1 | head -1)"

# Install Node.js dependencies
echo -e "\n${BLUE}[2/7]${NC} Installing dependencies..."
npm install --silent
echo -e "  ✓ Dependencies installed"

# Create Minecraft server directory
echo -e "\n${BLUE}[3/7]${NC} Setting up Minecraft server directory..."

if [ ! -d "$MC_DIR" ]; then
    echo -e "  Creating $MC_DIR..."
    sudo mkdir -p "$MC_DIR"
    sudo chown $USER:$USER "$MC_DIR"
    echo -e "  ✓ Created $MC_DIR"
else
    echo -e "  ✓ $MC_DIR already exists"
fi

# Download Minecraft server
if [ "$SKIP_MC" = false ]; then
    echo -e "\n${BLUE}[4/7]${NC} Setting up Minecraft server..."
    
    if [ ! -f "$MC_DIR/server.jar" ]; then
        echo -e "  Downloading Minecraft server..."
        curl -sL -o "$MC_DIR/server.jar" "$MC_JAR_URL"
        echo -e "  ✓ Downloaded server.jar"
    else
        echo -e "  ✓ server.jar already exists"
    fi

    # Create eula.txt
    if [ ! -f "$MC_DIR/eula.txt" ]; then
        echo "eula=true" > "$MC_DIR/eula.txt"
        echo -e "  ✓ Created eula.txt (EULA accepted)"
    fi

    # Create default server.properties if not exists
    if [ ! -f "$MC_DIR/server.properties" ]; then
        cat > "$MC_DIR/server.properties" << 'EOF'
#Minecraft server properties
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=\u00A7aHomeCraft Server\u00A7r - Welcome!
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=false
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
EOF
        echo -e "  ✓ Created server.properties"
    fi

    # Create empty JSON files
    [ ! -f "$MC_DIR/whitelist.json" ] && echo '[]' > "$MC_DIR/whitelist.json"
    [ ! -f "$MC_DIR/ops.json" ] && echo '[]' > "$MC_DIR/ops.json"
    [ ! -f "$MC_DIR/banned-players.json" ] && echo '[]' > "$MC_DIR/banned-players.json"
    echo -e "  ✓ Server configuration ready"
else
    echo -e "\n${BLUE}[4/7]${NC} Skipping Minecraft server setup..."
fi

# Build for production
if [ "$PRODUCTION" = true ]; then
    echo -e "\n${BLUE}[5/7]${NC} Building for production..."
    npm run build --silent
    echo -e "  ✓ Production build complete"
else
    echo -e "\n${BLUE}[5/7]${NC} Skipping production build (dev mode)..."
fi

# Create systemd service
if [ "$PRODUCTION" = true ] && [ "$SKIP_SERVICE" = false ]; then
    echo -e "\n${BLUE}[6/7]${NC} Creating systemd service..."
    
    INSTALL_DIR=$(pwd)
    SERVICE_FILE="/etc/systemd/system/homecraft.service"
    
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=HomeCraft Minecraft Server Panel
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/build
Restart=on-failure
RestartSec=10
Environment=PORT=$PANEL_PORT
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable homecraft
    echo -e "  ✓ Created systemd service: homecraft"
    echo -e "  ✓ Service enabled on boot"
else
    echo -e "\n${BLUE}[6/7]${NC} Skipping systemd service creation..."
fi

# Final instructions
echo -e "\n${BLUE}[7/7]${NC} Setup complete!"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$PRODUCTION" = true ]; then
    echo -e "  ${GREEN}Production Setup Complete!${NC}"
    echo ""
    echo -e "  Start the panel:"
    echo -e "    ${YELLOW}sudo systemctl start homecraft${NC}"
    echo ""
    echo -e "  Check status:"
    echo -e "    ${YELLOW}sudo systemctl status homecraft${NC}"
    echo ""
    echo -e "  View logs:"
    echo -e "    ${YELLOW}journalctl -u homecraft -f${NC}"
    echo ""
    echo -e "  Access the panel at:"
    echo -e "    ${BLUE}http://localhost:$PANEL_PORT${NC}"
else
    echo -e "  ${GREEN}Development Setup Complete!${NC}"
    echo ""
    echo -e "  Start development server:"
    echo -e "    ${YELLOW}npm run dev${NC}"
    echo ""
    echo -e "  Build for production:"
    echo -e "    ${YELLOW}./setup.sh --production${NC}"
    echo ""
    echo -e "  Access the panel at:"
    echo -e "    ${BLUE}http://localhost:5173${NC}"
fi

echo ""
echo -e "  Minecraft server directory: ${BLUE}$MC_DIR${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW} You can also remove the content inside the directory and add your server folder !${NC}"
echo -e "  ${GREEN}⛏️  Happy crafting!${NC}"
echo ""

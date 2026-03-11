#!/bin/bash
# ============================================================
#  PHANTOM OSINT — One-Line Auto Installer
#  Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/phantom/main/install.sh | bash
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

INSTALL_DIR="$HOME/phantom"
REPO="YOUR_USERNAME/phantom"  # <-- Change this to your GitHub username/repo

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗"
echo "  ██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║"
echo "  ██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║"
echo "  ██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║"
echo "  ██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║"
echo "  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝"
echo -e "${NC}"
echo -e "  ${CYAN}OSINT Intelligence Terminal — Auto Installer${NC}"
echo "  https://github.com/$REPO"
echo ""
echo "════════════════════════════════════════════════════════"

# ── Check Kali / Debian ───────────────────────────────────
if ! command -v apt-get &>/dev/null; then
  echo -e "${RED}ERROR: This installer requires a Debian/Kali-based system.${NC}"
  exit 1
fi

# ── Download latest release ───────────────────────────────
echo ""
echo -e "${YELLOW}[1/3]${NC} ${BOLD}Downloading PHANTOM...${NC}"

if [ -d "$INSTALL_DIR" ]; then
  echo -e "  ${YELLOW}→${NC} $INSTALL_DIR already exists — updating..."
  cd "$INSTALL_DIR" && git pull -q 2>/dev/null
  echo -e "  ${GREEN}✓${NC} Updated"
else
  git clone "https://github.com/$REPO.git" "$INSTALL_DIR" -q 2>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "  ${YELLOW}→${NC} git clone failed, trying wget..."
    # Fallback: download zip
    mkdir -p "$INSTALL_DIR"
    wget -q "https://github.com/$REPO/archive/refs/heads/main.zip" -O /tmp/phantom.zip
    unzip -q /tmp/phantom.zip -d /tmp/
    cp -r /tmp/phantom-main/* "$INSTALL_DIR/"
    rm -rf /tmp/phantom.zip /tmp/phantom-main
  fi
  echo -e "  ${GREEN}✓${NC} Downloaded to $INSTALL_DIR"
fi

# ── Install dependencies ──────────────────────────────────
echo ""
echo -e "${YELLOW}[2/3]${NC} ${BOLD}Installing dependencies...${NC}"
chmod +x "$INSTALL_DIR/install_tools.sh"
bash "$INSTALL_DIR/install_tools.sh"

# ── Create launch shortcut ────────────────────────────────
echo ""
echo -e "${YELLOW}[3/3]${NC} ${BOLD}Creating launch shortcuts...${NC}"

# Desktop shortcut
cat > "$HOME/Desktop/PHANTOM.desktop" 2>/dev/null << 'DESK'
[Desktop Entry]
Name=PHANTOM OSINT
Comment=Open Source Intelligence Terminal
Exec=bash -c 'cd ~/phantom && python3 backend/app.py & sleep 2 && xdg-open frontend/index.html'
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Network;Security;
DESK
chmod +x "$HOME/Desktop/PHANTOM.desktop" 2>/dev/null

# CLI command
cat > /usr/local/bin/phantom 2>/dev/null << SCRIPT
#!/bin/bash
echo "Starting PHANTOM OSINT Terminal..."
cd $INSTALL_DIR
python3 backend/app.py &
BACKEND_PID=\$!
sleep 2
xdg-open frontend/index.html 2>/dev/null || firefox frontend/index.html 2>/dev/null || chromium frontend/index.html 2>/dev/null
echo ""
echo "PHANTOM is running. Press Ctrl+C to stop."
wait \$BACKEND_PID
SCRIPT
chmod +x /usr/local/bin/phantom 2>/dev/null
echo -e "  ${GREEN}✓${NC} Created 'phantom' command"

# ── Done ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}${BOLD}  PHANTOM installed successfully!${NC}"
echo ""
echo -e "  To start PHANTOM, run ONE of these:"
echo ""
echo -e "  ${CYAN}Option 1 (recommended):${NC}"
echo -e "  ${BOLD}  phantom${NC}"
echo ""
echo -e "  ${CYAN}Option 2 (manual):${NC}"
echo -e "  ${BOLD}  cd ~/phantom/backend && python3 app.py${NC}"
echo -e "  Then open: ${BOLD}~/phantom/frontend/index.html${NC}"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

#!/bin/bash
# ============================================================
#  PHANTOM — OSINT App Tool Installer
#  Works on Kali Linux / Debian-based systems
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗"
echo "  ██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║"
echo "  ██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║"
echo "  ██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║"
echo "  ██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║"
echo "  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝"
echo -e "${NC}"
echo -e "${CYAN}         OSINT Intelligence Terminal — Tool Installer${NC}"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

ERRORS=0
INSTALLED=0

install_ok() { echo -e "  ${GREEN}✓${NC} $1"; INSTALLED=$((INSTALLED+1)); }
install_err() { echo -e "  ${RED}✗${NC} $1 — $2"; ERRORS=$((ERRORS+1)); }
step() { echo -e "\n${YELLOW}[$1]${NC} ${BOLD}$2${NC}"; }

# ── STEP 1: System update ──────────────────────────────────
step "1/7" "Updating package lists..."
sudo apt-get update -qq 2>/dev/null && install_ok "apt updated" || install_err "apt update" "check your internet"

# ── STEP 2: System packages ───────────────────────────────
step "2/7" "Installing system dependencies..."
sudo apt-get install -y -qq git python3 python3-pip curl wget libssl-dev \
  libffi-dev python3-dev build-essential 2>/dev/null
install_ok "System dependencies (git, python3, pip, curl, wget)"

# ── STEP 3: Flask backend ─────────────────────────────────
step "3/7" "Installing Flask backend..."
pip3 install flask flask-cors --break-system-packages -q 2>/dev/null \
  && install_ok "flask + flask-cors" \
  || { sudo pip3 install flask flask-cors --break-system-packages -q 2>/dev/null \
    && install_ok "flask + flask-cors (sudo)" \
    || install_err "flask" "try: sudo pip3 install flask flask-cors"; }

# ── STEP 4: Holehe ────────────────────────────────────────
step "4/7" "Installing OSINT tools..."
echo -e "  ${CYAN}→${NC} holehe..."
pip3 install holehe --break-system-packages -q 2>/dev/null \
  && install_ok "holehe" \
  || { pip3 install holehe --break-system-packages --ignore-requires-python -q 2>/dev/null \
    && install_ok "holehe (forced)" \
    || install_err "holehe" "try: pip3 install holehe --break-system-packages"; }

# ── h8mail ────────────────────────────────────────────────
echo -e "  ${CYAN}→${NC} h8mail..."
pip3 install h8mail --break-system-packages -q 2>/dev/null \
  && install_ok "h8mail" \
  || install_err "h8mail" "try: pip3 install h8mail --break-system-packages"

# ── maigret ───────────────────────────────────────────────
echo -e "  ${CYAN}→${NC} maigret..."
pip3 install maigret --break-system-packages -q 2>/dev/null \
  && install_ok "maigret" \
  || {
    # Try from git if pip fails
    echo -e "  ${YELLOW}  pip failed, trying from git...${NC}"
    if [ ! -d "$HOME/maigret" ]; then
      git clone https://github.com/soxoj/maigret.git "$HOME/maigret" -q 2>/dev/null
    fi
    pip3 install -r "$HOME/maigret/requirements.txt" --break-system-packages -q 2>/dev/null
    pip3 install "$HOME/maigret" --break-system-packages -q 2>/dev/null \
      && install_ok "maigret (from git)" \
      || install_err "maigret" "manual: cd ~/maigret && pip3 install . --break-system-packages"
  }

# ── theHarvester ──────────────────────────────────────────
echo -e "  ${CYAN}→${NC} theHarvester..."
sudo apt-get install -y -qq theharvester 2>/dev/null \
  && install_ok "theHarvester" \
  || { pip3 install theHarvester --break-system-packages -q 2>/dev/null \
    && install_ok "theHarvester (pip)" \
    || install_err "theHarvester" "try: sudo apt install theharvester"; }

# ── STEP 5: Sherlock ──────────────────────────────────────
step "5/7" "Installing Sherlock..."
if [ ! -d "$HOME/sherlock" ]; then
  git clone https://github.com/sherlock-project/sherlock.git "$HOME/sherlock" -q 2>/dev/null \
    && install_ok "sherlock (cloned to ~/sherlock)" \
    || install_err "sherlock" "git clone failed — check internet"
else
  echo -e "  ${YELLOW}→${NC} ~/sherlock already exists, pulling updates..."
  cd "$HOME/sherlock" && git pull -q 2>/dev/null
  install_ok "sherlock (updated)"
fi
pip3 install -r "$HOME/sherlock/requirements.txt" --break-system-packages -q 2>/dev/null \
  && install_ok "sherlock requirements" \
  || install_err "sherlock requirements" "run: pip3 install -r ~/sherlock/requirements.txt --break-system-packages"

# ── STEP 6: PhoneInfoga ───────────────────────────────────
step "6/7" "Installing PhoneInfoga..."
# Try pre-built binary first (most reliable)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  BINARY="phoneinfoga_Linux_x86_64"
elif [ "$ARCH" = "aarch64" ]; then
  BINARY="phoneinfoga_Linux_arm64"
else
  BINARY="phoneinfoga_Linux_x86_64"
fi

PHONEINFOGA_URL="https://github.com/sundowndev/phoneinfoga/releases/latest/download/${BINARY}.tar.gz"
TMP_DIR=$(mktemp -d)

echo -e "  ${CYAN}→${NC} Downloading PhoneInfoga binary..."
wget -q "$PHONEINFOGA_URL" -O "$TMP_DIR/phoneinfoga.tar.gz" 2>/dev/null
if [ $? -eq 0 ]; then
  tar -xzf "$TMP_DIR/phoneinfoga.tar.gz" -C "$TMP_DIR" 2>/dev/null
  sudo mv "$TMP_DIR/phoneinfoga" /usr/local/bin/phoneinfoga 2>/dev/null
  sudo chmod +x /usr/local/bin/phoneinfoga 2>/dev/null
  rm -rf "$TMP_DIR"
  phoneinfoga version &>/dev/null \
    && install_ok "phoneinfoga (binary installed)" \
    || install_err "phoneinfoga" "binary install failed, try Go method below"
else
  rm -rf "$TMP_DIR"
  # Try via Go
  echo -e "  ${YELLOW}  wget failed, trying via Go...${NC}"
  if command -v go &>/dev/null; then
    go install github.com/sundowndev/phoneinfoga/v2/cmd/phoneinfoga@latest -q 2>/dev/null
    export PATH=$PATH:$(go env GOPATH)/bin
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
    install_ok "phoneinfoga (via Go)" \
      || install_err "phoneinfoga" "manual download: https://github.com/sundowndev/phoneinfoga/releases"
  else
    sudo apt-get install -y -qq golang 2>/dev/null
    go install github.com/sundowndev/phoneinfoga/v2/cmd/phoneinfoga@latest 2>/dev/null
    export PATH=$PATH:$(go env GOPATH)/bin
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
    install_ok "phoneinfoga (Go installed + binary)" \
      || install_err "phoneinfoga" "download manually from GitHub releases"
  fi
fi

# ── STEP 7: Verify all tools ──────────────────────────────
step "7/7" "Verifying installations..."
echo ""
verify() {
  local name=$1; local cmd=$2
  if eval "$cmd" &>/dev/null; then
    echo -e "  ${GREEN}[✓]${NC} $name"
  else
    echo -e "  ${RED}[✗]${NC} $name — NOT WORKING"
  fi
}
verify "python3"        "python3 --version"
verify "flask"          "python3 -c 'import flask'"
verify "flask_cors"     "python3 -c 'import flask_cors'"
verify "holehe"         "holehe --help"
verify "h8mail"         "h8mail --help"
verify "maigret"        "maigret --help"
verify "theHarvester"   "theHarvester --help"
verify "sherlock"       "[ -f $HOME/sherlock/sherlock.py ]"
verify "phoneinfoga"    "phoneinfoga version"

# ── SUMMARY ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${BOLD}Installation Summary:${NC}"
echo -e "  ${GREEN}Installed: $INSTALLED${NC}  |  ${RED}Errors: $ERRORS${NC}"
echo ""
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  All tools installed successfully!${NC}"
else
  echo -e "${YELLOW}  Some tools had issues. Check errors above.${NC}"
fi
echo ""
echo -e "${CYAN}  To start PHANTOM:${NC}"
echo -e "  ${BOLD}cd ~/phantom && python3 backend/app.py${NC}"
echo -e "  Then open ${BOLD}frontend/index.html${NC} in browser"
echo ""

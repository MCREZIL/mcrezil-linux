#!/bin/bash
# MCREZIL Linux Installer - Fixed Version
# Installs Ubuntu / Debian / Kali / Alpine / Arch in Termux via proot-distro
# Fixes: META order, VNC password escaping, wake-lock, bloat, broken rootfs

set -e
# set -u is NOT used on purpose - we handle empty vars manually

APP="MCREZIL-LINUX"
HOME_DIR="$HOME"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[*] $1${NC}"; }
ok() { echo -e "${GREEN}[+] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err() { echo -e "${RED}[x] $1${NC}"; }

# --- Wake lock: install termux-api FIRST, then try to lock ---
if ! command -v termux-wake-lock >/dev/null 2>&1; then
  info "Installing termux-api for wake-lock..."
  pkg install -y termux-api 2>/dev/null || true
fi
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
  trap 'termux-wake-unlock 2>/dev/null || true' EXIT
else
  warn "termux-wake-lock not available. Keep Termux in foreground, disable battery optimization."
fi

# --- Helpers ---
ask() {
  local prompt="$1" def="$2" var=""
  if [ -t 0 ]; then
    read -r -p "$prompt [$def]: " var </dev/tty || var=""
  else
    warn "No TTY, using default: $def"
    var=""
  fi
  echo "${var:-$def}"
}

check_space() {
  local need_gb="$1"
  local avail_kb
  # FIX: check $PREFIX where proot-distro actually installs, fallback to $HOME
  avail_kb=$(df -k "$PREFIX" 2>/dev/null | awk 'NR==2 {print $4}')
  [ -z "$avail_kb" ] && avail_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
  local avail_gb=$((avail_kb / 1024 / 1024))
  info "Free space: ${avail_gb}GB, needed: ${need_gb}GB"
  if [ "$avail_gb" -lt "$need_gb" ]; then
    err "Not enough space. Free at least ${need_gb}GB and try again."
    exit 1
  fi
}

# --- Base packages ---
info "Updating Termux..."
pkg update -y
pkg install -y proot-distro wget curl ncurses-utils termux-api 2>/dev/null || pkg install -y proot-distro wget curl

# --- Choose Distro ---
echo ""
echo "=== $APP ==="
echo "1) Ubuntu  (recommended)"
echo "2) Debian"
echo "3) Kali   (pentest - needs more space)"
echo "4) Alpine (light, terminal only)"
echo "5) Arch"
echo ""
CHOICE=$(ask "Choose distro (1-5)" "1")

case "$CHOICE" in
  1) DISTRO="ubuntu" ;;
  2) DISTRO="debian" ;;
  3) DISTRO="kali" ;;
  4) DISTRO="alpine" ;;
  5) DISTRO="arch" ;;
  *) DISTRO="ubuntu" ;;
esac

# --- Choose Mode ---
MODE="terminal"
if [ "$DISTRO" != "alpine" ]; then
  echo ""
  echo "Mode:"
  echo "1) Terminal only (light, fast)"
  echo "2) Desktop (XFCE + VNC)"
  echo ""
  MCHOICE=$(ask "Choose mode (1-2)" "1")
  if [ "$MCHOICE" = "2" ]; then MODE="desktop"; fi
else
  # FIX: tell user, don't silently force
  warn "Alpine only supports terminal mode in this installer. Using terminal."
  MODE="terminal"
fi

# --- FIX 1: Set META / TOOLS BEFORE space check ---
TOOLS="standard"
META=""
if [ "$DISTRO" = "kali" ]; then
  echo ""
  echo "Kali tools:"
  echo "1) Top10 (recommended)"
  echo "2) Web"
  echo "3) Full (very big, 15GB+)"
  echo ""
  TCHOICE=$(ask "Choose Kali tools (1-3)" "1")
  case "$TCHOICE" in
    1) META="kali-tools-top10"; TOOLS="top10" ;;
    2) META="kali-tools-web"; TOOLS="web" ;;
    3) META="kali-tools-top10"; TOOLS="full"; warn "Full selected - will install top10 first, you can add more later." ;;
    *) META="kali-tools-top10"; TOOLS="top10" ;;
  esac
fi

# --- Space check with CORRECT size ---
if [ "$DISTRO" = "kali" ]; then
  if [ "$TOOLS" = "full" ]; then check_space 16
  elif [ "$TOOLS" = "web" ]; then check_space 12
  else check_space 10; fi
elif [ "$MODE" = "desktop" ]; then check_space 8
else check_space 6; fi

# --- Install Distro ---
# FIX: detect broken partial install with marker file
MARKER="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO/.mcrezil-ok"
ROOTFS_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"

if [ -f "$MARKER" ]; then
  ok "$DISTRO already installed, skipping download."
elif [ -d "$ROOTFS_DIR" ]; then
  warn "Found incomplete $DISTRO install. Removing broken rootfs..."
  proot-distro remove "$DISTRO" || rm -rf "$ROOTFS_DIR"
  info "Installing $DISTRO..."
  proot-distro install "$DISTRO"
else
  info "Installing $DISTRO..."
  proot-distro install "$DISTRO"
fi

# Mark as ok after successful login test
proot-distro login "$DISTRO" -- sh -c 'echo ok' || { err "Install failed. Try: proot-distro remove '"$DISTRO"' and run again."; exit 1; }
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"

# --- Kali special setup ---
if [ "$DISTRO" = "kali" ]; then
  info "Setting up Kali / NetHunter..."
  # FIX 4: Do NOT use short link without verification.
  # Use official Kali NetHunter installer. If you must use a mirror, add sha256 check.
  # Official docs: https://www.kali.org/docs/nethunter/nethunter-rootless/
  warn "Kali Rootless: please follow official NetHunter guide if nethunter command fails."
  warn "Do not run random short-links (offs.ec etc) without checking them first."

  # Install tools inside Kali - use non-interactive, avoid hang on config prompts
  proot-distro login "$DISTRO" -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends kali-tools-top10 2>/dev/null || apt-get install -y $META
    touch /root/.mcrezil-kali-ok
  " || warn "Kali tools install had warnings, continuing..."
fi

# --- Desktop setup ---
if [ "$MODE" = "desktop" ]; then
  info "Setting up Desktop (XFCE + VNC)..."

  # FIX 2: VNC password - never expand it in heredoc.
  # We ask once, store in a temp file with 600 perms, and use env file.
  VNCPASS=""
  while [ ${#VNCPASS} -lt 6 ] || [ ${#VNCPASS} -gt 8 ]; do
    echo ""
    echo "VNC password must be 6-8 characters."
    read -r -s -p "Enter VNC password (6-8 chars): " VNCPASS </dev/tty; echo ""
    read -r -s -p "Confirm VNC password: " VNCPASS2 </dev/tty; echo ""
    if [ "$VNCPASS" != "$VNCPASS2" ]; then echo "Passwords do not match."; VNCPASS=""; continue; fi
    if [ ${#VNCPASS} -lt 6 ] || [ ${#VNCPASS} -gt 8 ]; then echo "Must be 6-8 chars."; fi
  done

  # Write setup script with QUOTED heredoc so $ etc are NOT expanded
  cat > /tmp/mcrezil-setup-desktop.sh <<'SETUP_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
# Password comes from /tmp/.vncpass, not from script expansion
apt-get update -y
# FIX: --no-install-recommends saves ~1-2GB
apt-get install -y --no-install-recommends xfce4 xfce4-terminal tigervnc-standalone-server dbus-x11 x11-xserver-utils 2>/dev/null || apt-get install -y xfce4 tigervnc-standalone-server
mkdir -p ~/.vnc
# vncpasswd reads from file, no shell expansion of special chars
cat /tmp/.vncpass | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd
rm -f /tmp/.vncpass
echo "exec startxfce4" > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup
echo "Desktop setup done"
SETUP_EOF

  # Write password to temp file securely, copy it into distro, then delete host copy
  printf '%s\n' "$VNCPASS" > /tmp/.vncpass_host
  chmod 600 /tmp/.vncpass_host
  # Copy password file into distro via proot-distro login stdin is tricky, so we use a shared path:
  # proot-distro shares $HOME, use $HOME/.vncpass_tmp then move inside
  cp /tmp/.vncpass_host "$HOME/.vncpass_tmp"
  chmod 600 "$HOME/.vncpass_tmp"

  proot-distro login "$DISTRO" -- bash -c '
    cp ~/".vncpass_tmp" /tmp/.vncpass
    chmod 600 /tmp/.vncpass
    rm -f ~/".vncpass_tmp"
    bash /tmp/mcrezil-setup-desktop.sh
    rm -f /tmp/mcrezil-setup-desktop.sh
  '

  rm -f /tmp/.vncpass_host "$HOME/.vncpass_tmp"
  unset VNCPASS VNCPASS2

  # FIX: Ask for resolution, don't hardcode 1280x720
  echo ""
  echo "VNC Resolution:"
  echo "1) 1280x720 (phone)"
  echo "2) 1920x1080 (tablet / big screen)"
  echo "3) 1024x768"
  RCHOICE=$(ask "Choose resolution" "1")
  case "$RCHOICE" in
    2) GEOM="1920x1080" ;;
    3) GEOM="1024x768" ;;
    *) GEOM="1280x720" ;;
  esac

  # Create starter - FIX 3: only create desktop starter if MODE=desktop
  cat > "$HOME/linux-start" <<EOF
#!/bin/bash
# Start $DISTRO desktop
proot-distro login $DISTRO -- bash -c 'vncserver -geometry $GEOM -localhost no :1; echo "VNC on localhost:5901"; echo "Open VNC Viewer -> localhost:5901"; sleep infinity' &
echo "Desktop started. Open VNC Viewer and connect to localhost:5901"
echo "To stop: proot-distro login $DISTRO -- vncserver -kill :1"
EOF
  chmod +x "$HOME/linux-start"
  ok "Desktop ready. Run: ./linux-start  then open VNC Viewer -> localhost:5901"

else
  # FIX 3: Terminal mode gets terminal starter, NOT desktop starter
  cat > "$HOME/linux-start" <<EOF
#!/bin/bash
proot-distro login $DISTRO
EOF
  chmod +x "$HOME/linux-start"
  ok "Terminal ready. Run: ./linux-start"
fi

echo ""
ok "Done! $DISTRO ($MODE) installed."
echo "Start with: ./linux-start"
echo "Remove with: proot-distro remove $DISTRO"

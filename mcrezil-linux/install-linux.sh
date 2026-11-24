#!/data/data/com.termux/files/usr/bin/bash
# MCREZIL LINUX installer runs Linux (Kali, Ubuntu, Debian or Alpine) inside Android using Termux.
# No root and no bootloader unlock needed. Usage: bash install-linux.sh [kali|ubuntu|debian|alpine] [desktop|terminal] [standard|top10|web]
set -e
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; B="\033[1;36m"; N="\033[0m"
say()  { echo -e "${B}==>${N} $*"; }
ok()   { echo -e "${G}✔${N} $*"; }
fail() { echo -e "${R}✘ $*${N}"; exit 1; }
ask()  { local a; read -r -p "$1" a < /dev/tty; echo "$a"; }

[ -d /data/data/com.termux ] || fail "Run this inside the Termux app on your Android phone."

echo -e "${G}"
echo "  ┌──────────────────────────────┐"
echo "  │   MCREZIL LINUX installer    │"
echo "  │   Linux on your Android      │"
echo "  └──────────────────────────────┘"
echo -e "${N}"

BG_URL="${BG_URL:-}"

# Android 12+ check (SDK 31 = Android 12)
SDK="$(getprop ro.build.version.sdk 2>/dev/null)"
case "$SDK" in ''|*[!0-9]*) ;; *) [ "$SDK" -ge 31 ] || fail "MCREZIL LINUX is built for Android 12 or newer (this phone reports SDK $SDK).";; esac

# Keep the phone awake during long installs
if command -v termux-wake-lock >/dev/null 2>&1; then termux-wake-lock; trap 'termux-wake-unlock' EXIT; fi

check_space() { # $1 = GB needed
  local kb; kb="$(df -Pk "$HOME" | awk 'NR==2{print $4}')"
  if [ "${kb:-0}" -lt $(( $1 * 1024 * 1024 )) ]; then
    fail "Not enough free space: about $1 GB needed, $(( ${kb:-0} / 1024 / 1024 )) GB free. Delete some files and try again."
  fi
}

# Put the MCREZIL wallpaper on the Linux desktop (XFCE). $1 = rootfs path, then home folders relative to it.
apply_bg() {
  local root="$1"; shift
  [ -n "$BG_URL" ] || return 0
  mkdir -p "$root/usr/share/backgrounds"
  if ! curl -fsSL "$BG_URL" -o "$root/usr/share/backgrounds/mcrezil.jpg"; then
    echo -e "${Y}Could not download the background image, skipping it.${N}"; return 0
  fi
  local h d m
  for h in "$@"; do
    d="$root/$h/.config/xfce4/xfconf/xfce-perchannel-xml"; mkdir -p "$d"
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<channel name="xfce4-desktop" version="1.0">'
      echo ' <property name="backdrop" type="empty"><property name="screen0" type="empty">'
      for m in monitorVNC-0 monitor0 monitorscreen; do
        echo "  <property name=\"$m\" type=\"empty\"><property name=\"workspace0\" type=\"empty\"><property name=\"image-style\" type=\"int\" value=\"4\"/><property name=\"color-style\" type=\"int\" value=\"0\"/><property name=\"rgba1\" type=\"array\"><value type=\"double\" value=\"0\"/><value type=\"double\" value=\"0\"/><value type=\"double\" value=\"0\"/><value type=\"double\" value=\"1\"/></property><property name=\"last-image\" type=\"string\" value=\"/usr/share/backgrounds/mcrezil.jpg\"/></property></property>"
      done
      echo ' </property></property>'
      echo '</channel>'
    } > "$d/xfce4-desktop.xml"
  done
  ok "Wallpaper applied to the desktop."
}

DISTRO="$1"; MODE="$2"; TOOLS="$3"
if [ -z "$DISTRO" ]; then
  echo "Which Linux would you like?"
  echo "  1) Ubuntu  (friendly, most guides online)"
  echo "  2) Debian  (stable and light)"
  echo "  3) Alpine  (tiny, terminal only)"
  echo "  4) Kali    (security tools, official NetHunter build)"
  case "$(ask 'Type 1, 2, 3 or 4: ')" in 1) DISTRO=ubuntu;; 2) DISTRO=debian;; 3) DISTRO=alpine;; 4) DISTRO=kali;; *) fail "Please type 1, 2, 3 or 4.";; esac
fi
case "$DISTRO" in kali|ubuntu|debian|alpine) ;; *) fail "Unsupported choice: $DISTRO";; esac
if [ "$DISTRO" = alpine ]; then MODE=terminal; fi
if [ -z "$MODE" ]; then
  echo "How do you want to use it?"
  echo "  1) Desktop  (windows, mouse and apps; needs about 3 GB)"
  echo "  2) Terminal (text only; needs about 300 MB)"
  case "$(ask 'Type 1 or 2: ')" in 1) MODE=desktop;; 2) MODE=terminal;; *) fail "Please type 1 or 2.";; esac
fi

# ---------- Kali Linux (official NetHunter rootless installer) ----------
if [ "$DISTRO" = kali ]; then
  if [ -z "$TOOLS" ]; then
    echo "Which Kali tools do you want?"
    echo "  1) Standard  (the tools in the NetHunter image, fits 20 GB easily)"
    echo "  2) Top 10    (adds kali-tools-top10, about 2 to 4 GB more)"
    echo "  3) Web       (adds kali-tools-web, about 3 to 5 GB more)"
    case "$(ask 'Type 1, 2 or 3: ')" in 1) TOOLS=standard;; 2) TOOLS=top10;; 3) TOOLS=web;; *) fail "Please type 1, 2 or 3.";; esac
  fi
  if [ -n "$META" ] || [ "$TOOLS" != standard ]; then check_space 14; else check_space 10; fi
  say "Installing Kali. When asked, choose the full image if you want the desktop."
  pkg update -y
  pkg install -y wget
  wget -O "$HOME/install-nethunter-termux" https://offs.ec/2MceZWr
  chmod +x "$HOME/install-nethunter-termux"
  "$HOME/install-nethunter-termux" < /dev/tty
  ok "Kali installed."

  case "$TOOLS" in
    top10) META=kali-tools-top10;;
    web)   META=kali-tools-web;;
    *)     META="";;
  esac
  say "Updating Kali${META:+ and installing $META} (this can take a long time)..."
  nethunter -r bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get -y full-upgrade ${META:+&& apt-get install -y $META}; apt-get clean"
  rm -f "$HOME/install-nethunter-termux"
  ok "Kali is up to date."
  [ -d "$HOME/kali-arm64" ] && apply_bg "$HOME/kali-arm64" root home/kali

  if [ "$MODE" != terminal ]; then
    echo "Now choose the password for your Kali desktop."
    nethunter kex passwd < /dev/tty
  fi
  printf '#!/data/data/com.termux/files/usr/bin/bash\nnethunter kex &\necho\necho "Kali desktop is starting. Open NetHunter KeX and connect to localhost:5901"\n' > "$PREFIX/bin/linux-start"
  printf '#!/data/data/com.termux/files/usr/bin/bash\nnethunter kex stop\n' > "$PREFIX/bin/linux-stop"
  printf '#!/data/data/com.termux/files/usr/bin/bash\nnethunter\n' > "$PREFIX/bin/linux-terminal"
  chmod +x "$PREFIX/bin/linux-start" "$PREFIX/bin/linux-stop" "$PREFIX/bin/linux-terminal"
  echo; ok "All done!"
  echo -e "  Start desktop:   ${Y}linux-start${N}   then open NetHunter KeX > localhost:5901"
  echo -e "  Stop desktop:    ${Y}linux-stop${N}"
  echo -e "  Open terminal:   ${Y}linux-terminal${N}"
  exit 0
fi

VNCPASS=""
if [ "$MODE" = desktop ]; then
  while [ "${#VNCPASS}" -lt 6 ]; do
    echo -n "Choose a password for your Linux desktop (6 to 8 characters): "
    read -rs VNCPASS < /dev/tty; echo
    q="'"; VNCPASS="${VNCPASS//$q/}"; VNCPASS="${VNCPASS:0:8}"
  done
fi

case "$DISTRO-$MODE" in alpine-*) check_space 1;; *-desktop) check_space 6;; *) check_space 2;; esac
say "Updating Termux and installing tools (a few minutes)..."
pkg update -y
pkg install -y proot-distro curl
ok "Tools ready."

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"
if [ -d "$ROOTFS" ]; then
  ok "$DISTRO is already downloaded."
else
  say "Downloading $DISTRO (keep Termux open and your phone awake)..."
  proot-distro install "$DISTRO"
  ok "$DISTRO installed."
fi

if [ "$MODE" = desktop ]; then
  say "Installing the desktop. This is the longest step (10 to 30 minutes)."
  cat > "$ROOTFS/root/setup-desktop.sh" <<SETUP
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y xfce4 xfce4-terminal tigervnc-standalone-server dbus-x11 nano sudo
mkdir -p /root/.vnc
printf '%s\n' '$VNCPASS' | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd
printf '#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec dbus-launch --exit-with-session startxfce4\n' > /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
apt-get clean
SETUP
  proot-distro login "$DISTRO" -- bash /root/setup-desktop.sh
  rm -f "$ROOTFS/root/setup-desktop.sh"
  apply_bg "$ROOTFS" root
  pkg clean 2>/dev/null || true
  ok "Desktop installed."

  cat > "$PREFIX/bin/linux-start" <<START
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login $DISTRO --shared-tmp -- bash -c 'vncserver -kill :1 >/dev/null 2>&1; rm -f /tmp/.X1-lock /tmp/.X11-unix/X1; vncserver :1 -localhost yes -geometry 1280x720 -depth 24'
echo
echo "Desktop is running. Open VNC Viewer and connect to:  localhost:5901"
START
  cat > "$PREFIX/bin/linux-stop" <<STOP
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login $DISTRO --shared-tmp -- vncserver -kill :1
STOP
  chmod +x "$PREFIX/bin/linux-start" "$PREFIX/bin/linux-stop"
fi

cat > "$PREFIX/bin/linux-terminal" <<TERM
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login $DISTRO
TERM
chmod +x "$PREFIX/bin/linux-terminal"

echo
ok "All done!"
if [ "$MODE" = desktop ]; then
  echo -e "  Start desktop:   ${Y}linux-start${N}   then open VNC Viewer > localhost:5901"
  echo -e "  Stop desktop:    ${Y}linux-stop${N}"
fi
echo -e "  Open terminal:   ${Y}linux-terminal${N}"

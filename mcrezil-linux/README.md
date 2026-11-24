# MCREZIL LINUX
A friendly guided installer for running Linux (Kali, Ubuntu, Debian, Alpine) on Android 12+ phones with about 20 GB of free storage, through Termux. No root needed.

- `index.html`: step-by-step wizard.
- `install-linux.sh`: the installer that runs inside Termux. Checks for Android 12+ and enough free space.
- `background.jpg`: the MCREZIL TECH AGENCY logo, already included. Keep it next to both files (same GitHub folder). The wizard uses it as its page background and the installer sets it as the Linux desktop wallpaper.

Kali uses the official Kali NetHunter rootless installer. Tool sets: standard, top10 (kali-tools-top10), web (kali-tools-web).

Quick use without the wizard (inside Termux): `BG_URL=<raw link to background.jpg> bash install-linux.sh kali desktop top10`

Use security tools only on systems you own or have written permission to test.

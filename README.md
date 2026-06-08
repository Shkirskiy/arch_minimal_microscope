# Arch Linux Minimal Microscopy Workstation

A single setup script that turns a fresh Arch Linux installation into a minimal, dedicated microscopy workstation. On boot it auto-logs into a lightweight Openbox desktop with the camera preview ready to go, plus desktop icons and a right-click menu for the handful of tools the station needs.

## What it installs

| Component | Purpose |
|-----------|---------|
| Xorg | Display server |
| LightDM + lightdm-gtk-greeter | Login manager (configured for auto-login) |
| Openbox | Lightweight window manager |
| tint2 | Minimal taskbar (shows open windows) |
| guvcview | Live camera preview and capture |
| Fiji (ImageJ) | Scientific image analysis (downloaded to `/opt/fiji`) |
| pcmanfm | File manager + draws the desktop and its icons |
| udiskie + udisks2 | Auto-mount USB drives on plug-in |
| firefox | Web browser |
| v4l-utils | Camera diagnostics |
| xterm | Terminal emulator |

**Keyboard layout:** French AZERTY (Mac variant), applied to both the graphical session and the text console. See the note below for a standard PC keyboard.

## What you get after install

- **Auto-login** as the `microscopist` user — no password prompt, straight to the desktop.
- **On login, these start automatically:** the tint2 taskbar, USB auto-mounting, the desktop (with icons), and guvcview (and Fiji, if installed).
- **Desktop icons** for: Copy Files (USB), Terminal, Camera (Microscope), Firefox, and Fiji.
- **Right-click menu** (right-click anywhere on the desktop) with the same five apps plus Log Out.

## Requirements

A working Arch Linux base installation with:
- Internet access
- A user account with `sudo` privileges
- `git` installed (`sudo pacman -S git`)

Tested on **x86_64** Arch Linux. It is **not** compatible with Arch Linux ARM (the Fiji build it downloads is x86_64).

---

## How to run it

### Step 1 — Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

Replace `YOUR_USERNAME` and `YOUR_REPO_NAME` with your actual GitHub details.

### Step 2 — Make the script executable

```bash
chmod +x microscopy-setup.sh
```

`chmod +x` grants execute permission — downloaded files are not executable by default.

### Step 3 — Run it as root

```bash
sudo ./microscopy-setup.sh
```

Root is required because the script installs packages, creates a user, and writes system config files.

Expect **5–15 minutes** depending on your connection — it downloads all packages, Firefox, and Fiji (~650 MB).

### Step 4 — Reboot

```bash
sudo reboot
```

On next boot the machine auto-logs in as `microscopist` and launches the desktop with the camera ready.

---

## The script is safe to re-run (idempotent)

Running it again will not damage anything: it skips already-installed packages, skips Fiji if `/opt/fiji` already exists, and skips creating the user if it already exists. It simply refreshes the configuration. This is handy when tweaking the setup.

**After re-running while already logged in**, apply changes without a full reboot:
- **Menu changes:** run `openbox --reconfigure` (re-reads the right-click menu immediately).
- **Desktop icons and autostart:** log out and back in (these apply at session start).

---

## Notes

### Keyboard layout
The script sets **French AZERTY — Mac variant** for both the graphical session and the console. The graphical setting is written permanently to `/etc/X11/xorg.conf.d/00-keyboard.conf`, so it survives reboots.

For a **standard PC keyboard**, edit the script and change:

```bash
# Mac keyboard (default in this script):
localectl set-x11-keymap fr pc105 mac

# Standard PC keyboard:
localectl set-x11-keymap fr
```

Verify the active layout from a terminal with `setxkbmap -query`.

### USB camera / webcam
No extra drivers needed. The Linux kernel's built-in `uvcvideo` driver handles virtually all USB Video Class cameras automatically. guvcview opens a live preview when a camera is connected.

Note: guvcview **requires a camera to be present** — with no camera attached it reports "not connected" and closes. That is expected. On the lab station the camera is permanently attached, so it opens straight into a live preview.

Verify detection:
```bash
v4l2-ctl --list-devices
```

### Copying images to a USB drive
1. Plug in a USB drive — udiskie auto-mounts it under `/run/media/microscopist/`.
2. Double-click the **Copy Files (USB)** desktop icon (or right-click desktop → Copy Files) to open the file manager.
3. Drag images onto the USB drive shown in the sidebar.

### First click on a desktop icon
Some versions of pcmanfm ask once whether to "Execute" or "Display" a launcher icon. Choose **Execute** and it won't ask again. The script marks the icons executable to minimize this.

### Fiji
Fiji is downloaded from the official server (`fiji-latest-linux64-jdk.zip`, Java bundled). The download step is **optional**: if it fails, the script warns and continues, and the rest of the system still sets up correctly. Manual install instructions are printed at the end of the script if needed.

Fiji's built-in updater (`Help → Update...`) works because the `microscopist` user owns `/opt/fiji`.

---

## Directory structure after install

```
/opt/fiji/                      ← Fiji installation
/usr/local/bin/fiji             ← shortcut to the Fiji launcher (on PATH)
/etc/X11/xorg.conf.d/
└── 00-keyboard.conf            ← permanent AZERTY keyboard config
/home/microscopist/
├── Desktop/                    ← clickable launcher icons
│   ├── copy-files.desktop
│   ├── terminal.desktop
│   ├── camera.desktop
│   ├── firefox.desktop
│   └── fiji.desktop
└── .config/
    └── openbox/
        ├── autostart           ← apps that launch on login
        ├── rc.xml              ← Openbox keybindings and behaviour
        └── menu.xml            ← right-click desktop menu (5 apps + Log Out)
```

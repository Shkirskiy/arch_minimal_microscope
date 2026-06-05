# Arch Linux Minimal Microscopy Workstation

A single setup script that turns a fresh Arch Linux installation into a minimal, dedicated microscopy workstation with automatic camera preview and image analysis on login.

## What it installs

| Component | Purpose |
|-----------|---------|
| Xorg | Display server |
| LightDM + Openbox | Login manager + window manager |
| tint2 | Minimal taskbar |
| guvcview | Live camera preview and capture |
| Fiji (ImageJ) | Scientific image analysis |
| pcmanfm | File manager (for USB copying) |
| udiskie | Auto-mounts USB drives on plug-in |
| v4l-utils | Camera diagnostics |
| xterm | Terminal emulator |

**Keyboard layout:** French AZERTY (Mac variant). See note below if using a standard PC keyboard.

## Requirements

Before running this script, you need a working Arch Linux base installation with:
- Internet access
- A user account with `sudo` privileges
- `git` installed (`sudo pacman -S git`)

This script is tested on **x86_64** Arch Linux. It is **not** compatible with Arch Linux ARM.

---

## How to run it

### Step 1 — Clone the repository

Open a terminal and run:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME
```

Replace `YOUR_USERNAME` and `YOUR_REPO_NAME` with your actual GitHub username and repository name.

### Step 2 — Make the script executable

```bash
chmod +x microscopy-setup.sh
```

`chmod +x` means "give this file execute permission" — by default downloaded files are not executable for safety reasons.

### Step 3 — Run it as root

```bash
sudo ./microscopy-setup.sh
```

`sudo` runs the command as root (administrator). The script needs root because it installs system packages, creates a user account, and writes to system config files.

The script will take **5–15 minutes** depending on your internet speed (it downloads all packages and Fiji).

### Step 4 — Reboot

```bash
sudo reboot
```

On next boot, the system will automatically log in as `microscopist` and launch guvcview and Fiji.

---

## Notes

### Keyboard layout
The script sets **French AZERTY — Mac variant** (`fr pc105 mac`).  
If you are installing on a **standard PC keyboard**, open the script and change this line:

```bash
# Original (Mac keyboard):
localectl set-x11-keymap fr pc105 mac

# For a standard PC keyboard:
localectl set-x11-keymap fr
```

### USB camera / webcam
No extra drivers are needed for modern USB cameras. The Linux kernel includes the `uvcvideo` driver built-in, which supports virtually all USB Video Class cameras automatically.

To verify your camera is detected after plugging it in:
```bash
v4l2-ctl --list-devices
```

### Copying images to a USB drive
1. Plug in a USB drive — it will be auto-mounted by udiskie under `/run/media/microscopist/`
2. Open pcmanfm (file manager) from the taskbar to browse and copy files

### Fiji updates
Fiji can update itself via its built-in updater (`Help → Update...`). The `microscopist` user has write access to `/opt/fiji` for this purpose.

---

## Directory structure after install

```
/opt/fiji/              ← Fiji installation
/home/microscopist/
└── .config/
    └── openbox/
        ├── autostart   ← apps that launch on login
        ├── rc.xml      ← Openbox keybindings and behaviour
        └── menu.xml    ← right-click desktop menu
```

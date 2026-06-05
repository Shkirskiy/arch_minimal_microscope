#!/bin/bash
# =============================================================================
# Arch Linux Minimal Microscopy Workstation Setup
# =============================================================================
# Run this script as root on a fresh Arch Linux installation that already has:
#   - Internet access
#   - A normal user with sudo rights (used during installation only)
#
# Usage:
#   chmod +x microscopy-setup.sh
#   sudo ./microscopy-setup.sh
# =============================================================================

set -e  # Stop immediately if any command fails

echo ""
echo "============================================================"
echo "  Microscopy Workstation Setup — Starting"
echo "============================================================"
echo ""


# =============================================================================
# SECTION 1 — System update and package installation
# =============================================================================
# Rule on Arch: ALWAYS use -Syu before installing anything.
# -S  = install (Sync)
# -y  = refresh the package database (download fresh list of available packages)
# -u  = upgrade all currently installed packages first
# --noconfirm = don't ask "are you sure?" for each step (safe in a script)
#
# This prevents "partial upgrades" — a situation where your installed packages
# are older than what the new packages expect, causing breakage.

echo ">>> [1/6] Updating system and installing packages..."

pacman -Syu --noconfirm \
    xorg-server \
    xorg-xinit \
    lightdm \
    lightdm-gtk-greeter \
    openbox \
    tint2 \
    xterm \
    v4l-utils \
    guvcview \
    pcmanfm \
    udisks2 \
    udiskie \
    unzip \
    wget

# Package reference:
#   xorg-server          : X11 display server — the foundation that draws
#                          everything graphical on screen
#   xorg-xinit           : Helpers for starting an X session (used by LightDM)
#   lightdm              : Display/login manager — runs at boot, starts X,
#                          handles the login screen
#   lightdm-gtk-greeter  : The visual theme/skin for the LightDM login screen
#   openbox              : Lightweight window manager — draws window borders,
#                          handles the right-click desktop menu, manages layout
#   tint2               : Minimal taskbar — shows open windows and clock
#   xterm                : Simple terminal emulator
#   v4l-utils            : Video4Linux userspace tools — lets you list and
#                          inspect camera devices (e.g. v4l2-ctl --list-devices)
#   guvcview             : Camera live preview and image/video capture (UVC)
#   pcmanfm              : Lightweight file manager — for copying files to USB
#   udisks2              : System service enabling USB drive mounting
#   udiskie              : User tool that auto-mounts USB drives on plug-in
#   unzip                : Needed to extract the Fiji .zip archive
#   wget                 : Download tool — used to fetch Fiji from the internet


# =============================================================================
# SECTION 2 — French AZERTY keyboard layout
# =============================================================================
# localectl controls the system locale and keyboard layout.
# This sets it system-wide for X11 (graphical sessions).
#
# set-x11-keymap <layout> <model> <variant>
#   fr      = French language layout
#   pc105   = standard 105-key PC keyboard model
#   mac     = the Mac variant of the French layout (AZERTY with Mac key positions)
#
# If you are installing on a standard PC keyboard (not a Mac keyboard),
# change "mac" to "" (empty) or remove the last argument entirely.

echo ">>> [2/6] Setting French AZERTY keyboard layout..."

localectl set-x11-keymap fr pc105 mac

echo "    Keyboard layout set to: French (Mac AZERTY)"
echo "    NOTE: If this is a standard PC keyboard, edit this script and"
echo "          change 'mac' to '' in the localectl command."


# =============================================================================
# SECTION 3 — Create the microscopist user
# =============================================================================
# useradd creates a new user account.
#
# Flags:
#   -m          : create the home directory /home/microscopist
#   -G video,storage,optical
#               : add to groups that grant hardware access:
#                   video   = /dev/video* — the camera device node
#                   storage = USB storage devices
#                   optical = optical drives (future-proofing)
#               Note: USB mounting does NOT need a special group on Arch —
#               udisks2 + polkit handle it automatically. (The 'plugdev'
#               group from Debian/Ubuntu does not exist on Arch.)
#   -s /bin/bash : use bash as the default shell

echo ">>> [3/6] Creating microscopist user..."

if id "microscopist" &>/dev/null; then
    echo "    User 'microscopist' already exists — skipping creation."
else
    useradd -m -G video,storage,optical -s /bin/bash microscopist
    echo "    User 'microscopist' created (no password — auto-login enabled)."
fi


# =============================================================================
# SECTION 4 — Install Fiji to /opt/fiji
# =============================================================================
# Fiji ("Fiji Is Just ImageJ") is a scientific image analysis application.
# It is not in the Arch repositories, so we download it directly.
#
# Since Fiji 2.15.0 (February 2025), the launcher script is called 'fiji'
# (a shell script), replacing the old 'ImageJ-linux64' binary.
#
# Download source: https://downloads.imagej.net/fiji/latest/fiji-linux64.zip
# Installed to:    /opt/fiji/  (standard location for third-party system apps)

echo ">>> [4/6] Installing Fiji to /opt/fiji..."

FIJI_URL="https://downloads.imagej.net/fiji/latest/fiji-linux64.zip"
FIJI_ZIP="/tmp/fiji-linux64.zip"
FIJI_DEST="/opt/fiji"

if [ -d "$FIJI_DEST" ]; then
    echo "    /opt/fiji already exists — skipping Fiji download."
    echo "    To reinstall, remove /opt/fiji first: rm -rf /opt/fiji"
else
    echo "    Downloading Fiji (this may take a few minutes)..."
    wget -q --show-progress -O "$FIJI_ZIP" "$FIJI_URL"

    echo "    Extracting..."
    # Fiji's zip contains a folder called "Fiji.app"
    # We extract to /tmp first, then move it to /opt/fiji
    unzip -q "$FIJI_ZIP" -d /tmp/fiji-extract

    mv /tmp/fiji-extract/Fiji.app "$FIJI_DEST"

    # Make the launcher script executable
    # The launcher is a shell script called 'fiji' at the root of the install
    chmod +x "$FIJI_DEST/fiji"

    # Clean up the downloaded zip
    rm -f "$FIJI_ZIP"
    rm -rf /tmp/fiji-extract

    echo "    Fiji installed to $FIJI_DEST"
fi

# Give the microscopist user ownership of Fiji so it can update itself
# (Fiji has a built-in updater that needs write access to its own directory)
chown -R microscopist:microscopist "$FIJI_DEST"


# =============================================================================
# SECTION 5 — Enable and configure LightDM
# =============================================================================
# LightDM is a "display manager" — it starts when the system boots,
# initialises the X display server, shows a login screen, and then
# launches the chosen desktop session.
#
# systemctl enable lightdm : register LightDM with systemd so it starts
#                            automatically at every boot
#
# LightDM's config file is /etc/lightdm/lightdm.conf
# Lines starting with # are comments (inactive settings).
# We use sed to uncomment and set the values we need.
#
# sed -i 's/OLD/NEW/' file
#   -i   = edit the file in-place (modify it directly, no copy)
#   s/   = substitute
#   ^#   = line starts with #  (the comment character)

echo ">>> [5/6] Configuring LightDM with auto-login..."

systemctl enable lightdm

# Set the greeter (the visual login screen component)
sed -i 's/^#greeter-session=.*/greeter-session=lightdm-gtk-greeter/' \
    /etc/lightdm/lightdm.conf

# Set which session (window manager) to launch after login
sed -i 's/^#autologin-session=.*/autologin-session=openbox/' \
    /etc/lightdm/lightdm.conf

# Set the auto-login user (skip the login screen entirely)
sed -i 's/^#autologin-user=.*/autologin-user=microscopist/' \
    /etc/lightdm/lightdm.conf

# Set delay to 0 (log in immediately, no countdown)
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' \
    /etc/lightdm/lightdm.conf

# LightDM requires a special group called 'autologin' to allow
# passwordless auto-login — this is a security gate built into LightDM.
# groupadd -f : create the group, silently skip if it already exists
groupadd -f autologin
gpasswd -a microscopist autologin


# =============================================================================
# SECTION 6 — Configure Openbox and autostart for microscopist
# =============================================================================
# Openbox stores its config in ~/.config/openbox/ inside each user's home.
# The key file is 'autostart' — a shell script that Openbox runs every time
# a session starts. This is where we launch all our apps.
#
# We also copy the default rc.xml and menu.xml from /etc/xdg/openbox/
# as a starting point (they define keybindings and the right-click menu).

echo ">>> [6/6] Setting up Openbox and autostart for microscopist..."

OPENBOX_CFG=/home/microscopist/.config/openbox
mkdir -p "$OPENBOX_CFG"

# Copy default Openbox configs
cp /etc/xdg/openbox/rc.xml   "$OPENBOX_CFG/rc.xml"
cp /etc/xdg/openbox/menu.xml "$OPENBOX_CFG/menu.xml"

# Write the autostart script.
# The 'cat > file << EOF' syntax writes everything between EOF markers
# directly into the file — this is called a "here document".
#
# The & at the end of each command means "run in the background".
# Without & each app would have to finish before the next one starts.

cat > "$OPENBOX_CFG/autostart" << 'EOF'
#!/bin/bash
# =============================================================
# Openbox autostart — runs when microscopist logs in
# =============================================================

# Start the taskbar (shows open windows, clock, system tray)
tint2 &

# Auto-mount USB drives when plugged in
# --no-notify : suppress desktop notifications (we have no notification daemon)
udiskie --no-notify &

# File manager in background (stays resident, opens quickly when needed)
pcmanfm --daemon-mode &

# Launch the camera preview and capture application
guvcview &

# Launch Fiji (scientific image analysis)
# The launcher script is called 'fiji' (updated in Fiji 2.15+)
/opt/fiji/fiji &
EOF

chmod +x "$OPENBOX_CFG/autostart"

# Fix ownership: this script runs as root, but all files inside
# /home/microscopist must belong to the microscopist user, not root.
# -R = recursive (applies to everything inside the directory)
chown -R microscopist:microscopist /home/microscopist/.config
chown -R microscopist:microscopist /home/microscopist/.local 2>/dev/null || true


# =============================================================================
# Done
# =============================================================================

echo ""
echo "============================================================"
echo "  Setup complete!"
echo "============================================================"
echo ""
echo "  What was configured:"
echo "    [x] System updated"
echo "    [x] All packages installed (Xorg, LightDM, Openbox, guvcview...)"
echo "    [x] French AZERTY (Mac) keyboard layout set"
echo "    [x] 'microscopist' user created"
echo "    [x] Fiji downloaded and installed to /opt/fiji"
echo "    [x] LightDM enabled with auto-login as microscopist"
echo "    [x] Openbox configured with autostart (guvcview + Fiji + tint2)"
echo "    [x] USB auto-mount configured (udiskie)"
echo ""
echo "  On next boot:"
echo "    - LightDM starts automatically"
echo "    - microscopist logs in without a password"
echo "    - Openbox starts with tint2, guvcview, and Fiji"
echo "    - USB drives are auto-mounted when plugged in"
echo ""
echo "  NOTE on keyboard layout:"
echo "    This script sets the Mac French AZERTY variant."
echo "    If you are on a standard PC keyboard, edit the script and"
echo "    change the localectl line to: localectl set-x11-keymap fr"
echo ""
echo "  To reboot now:"
echo "    sudo reboot"
echo ""

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
    firefox \
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
#   firefox              : Web browser
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

# This writes a PERMANENT config file: /etc/X11/xorg.conf.d/00-keyboard.conf
# X reads it every time the graphical session starts, so it survives reboots.
localectl set-x11-keymap fr pc105 mac

# Also set the TEXT CONSOLE (TTY) keymap, written to /etc/vconsole.conf.
# This covers the black text screen you see if you ever leave the desktop.
# Harmless if you never use the console; it just keeps both consistent.
localectl set-keymap fr

echo "    Keyboard layout set to: French (Mac AZERTY), graphical + console"
echo "    Permanent: written to /etc/X11/xorg.conf.d/00-keyboard.conf"
echo "    NOTE: If this is a standard PC keyboard, edit this script and"
echo "          change 'mac' to '' in the set-x11-keymap command."


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
# SECTION 4 — Install Fiji to /opt/fiji  (optional — failures don't abort)
# =============================================================================
# Fiji ("Fiji Is Just ImageJ") is a scientific image analysis application.
# It is not in the Arch repositories, so we download it directly.
#
# Download source (x86_64 Linux, Java bundled):
#   https://downloads.imagej.net/fiji/latest/fiji-latest-linux64-jdk.zip
#   - "linux64"  = x86_64 (correct for a normal PC and an x86_64 VM;
#                   do NOT use the arm64 build on these machines)
#   - "jdk"      = Java is bundled inside, so no separate Java install needed
# Installed to: /opt/fiji/  (standard location for third-party system apps)
#
# IMPORTANT DESIGN NOTE:
# This whole section is wrapped so that if the download or extraction fails,
# the script PRINTS A WARNING AND CONTINUES to steps 5-6 instead of aborting.
# Fiji is not required for the desktop/login to work, so a flaky download
# should never block the core setup. This is done by running the work inside
# an "if ! ( ... ); then warn; fi" block, which catches any failure locally.

echo ">>> [4/6] Installing Fiji to /opt/fiji..."

FIJI_URL="https://downloads.imagej.net/fiji/latest/fiji-latest-linux64-jdk.zip"
FIJI_ZIP="/tmp/fiji-linux64.zip"
FIJI_DEST="/opt/fiji"
FIJI_OK=0   # flag: did Fiji install succeed? (0 = no, 1 = yes)

if [ -d "$FIJI_DEST" ]; then
    echo "    /opt/fiji already exists — skipping Fiji download."
    echo "    To reinstall, remove it first: sudo rm -rf /opt/fiji"
    FIJI_OK=1
else
    # The parentheses ( ) run these commands in a "subshell".
    # If any command inside fails, the subshell exits non-zero, and the
    # "if (" catches it — so 'set -e' does NOT kill the whole script here.
    if ( set -e
        echo "    Downloading Fiji (~650 MB, this may take a few minutes)..."
        # No -q this time, so you can SEE the download progress and any error.
        wget -O "$FIJI_ZIP" "$FIJI_URL"

        echo "    Extracting..."
        rm -rf /tmp/fiji-extract
        unzip -q "$FIJI_ZIP" -d /tmp/fiji-extract

        # The zip extracts to a single top-level folder, but its exact name
        # has changed across Fiji versions (e.g. "Fiji.app" or "Fiji").
        # Rather than hard-code it, we DISCOVER it: take the first directory
        # found inside the extraction folder and move it to /opt/fiji.
        INNER=$(find /tmp/fiji-extract -mindepth 1 -maxdepth 1 -type d | head -n1)
        if [ -z "$INNER" ]; then
            echo "    ERROR: could not find extracted Fiji folder."
            exit 1
        fi
        mv "$INNER" "$FIJI_DEST"

        # Clean up
        rm -f "$FIJI_ZIP"
        rm -rf /tmp/fiji-extract
    ); then
        FIJI_OK=1
        echo "    Fiji files installed to $FIJI_DEST"
    else
        echo ""
        echo "    !!! WARNING: Fiji download/extraction FAILED."
        echo "    !!! The rest of the setup will continue normally."
        echo "    !!! You can install Fiji later — see the notes at the end."
        echo ""
        rm -f "$FIJI_ZIP"
        rm -rf /tmp/fiji-extract
    fi
fi

# If Fiji installed, find its launcher and make a stable shortcut.
# The launcher's name/location varies by version, so we SEARCH for it:
#   - newer builds: a shell script called 'fiji'
#   - older builds: a binary called 'ImageJ-linux64'
# We then symlink whichever we find to /usr/local/bin/fiji, which is on the
# system PATH — so autostart can simply call "fiji" without knowing the path.
if [ "$FIJI_OK" -eq 1 ]; then
    FIJI_LAUNCHER=$(find "$FIJI_DEST" -maxdepth 2 -type f \
        \( -name 'fiji' -o -name 'ImageJ-linux64' \) | head -n1)

    if [ -n "$FIJI_LAUNCHER" ]; then
        chmod +x "$FIJI_LAUNCHER"
        ln -sf "$FIJI_LAUNCHER" /usr/local/bin/fiji
        echo "    Fiji launcher found: $FIJI_LAUNCHER"
        echo "    Shortcut created: /usr/local/bin/fiji"
    else
        echo "    WARNING: Fiji installed but no launcher found inside it."
        echo "             Autostart will skip Fiji until this is resolved."
        FIJI_OK=0
    fi

    # Give microscopist ownership so Fiji's built-in updater can write to itself
    chown -R microscopist:microscopist "$FIJI_DEST"
fi


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

# Copy the default rc.xml (keybindings, window behaviour) as a base.
cp /etc/xdg/openbox/rc.xml "$OPENBOX_CFG/rc.xml"

# Write a CUSTOM right-click menu (menu.xml) instead of the default.
# In Openbox, right-clicking the desktop opens this menu. It is the
# built-in launcher. We give it our four apps plus a Log Out option.
# Each <item> has a label and an Execute action running a command.
cat > "$OPENBOX_CFG/menu.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Menu">
    <item label="Terminal">
      <action name="Execute"><command>xterm</command></action>
    </item>
    <item label="Copy Files (USB)">
      <action name="Execute"><command>pcmanfm</command></action>
    </item>
    <item label="Firefox">
      <action name="Execute"><command>firefox</command></action>
    </item>
    <item label="Camera (Microscope)">
      <action name="Execute"><command>guvcview</command></action>
    </item>
    <item label="Fiji">
      <action name="Execute"><command>fiji</command></action>
    </item>
    <separator />
    <item label="Log Out">
      <action name="Exit"><prompt>yes</prompt></action>
    </item>
  </menu>
</openbox_menu>
EOF

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

# Draw the desktop: wallpaper + clickable icons read from ~/Desktop.
# pcmanfm --desktop turns pcmanfm into the desktop manager (it shows the
# icons we place in ~/Desktop). Clicking the "Copy Files" icon later will
# open a normal pcmanfm file-browser window.
pcmanfm --desktop &

# Launch the camera preview and capture application.
# NOTE: guvcview needs a camera to be connected. With no camera it will
# report "not connected" and close — that is expected, not an error.
guvcview &

# Launch Fiji (scientific image analysis) if it is installed.
# The setup script created a 'fiji' shortcut in /usr/local/bin (on PATH).
# 'command -v fiji' checks whether that shortcut exists before running it,
# so the session won't error if Fiji wasn't installed.
if command -v fiji >/dev/null 2>&1; then
    fiji &
fi
EOF

chmod +x "$OPENBOX_CFG/autostart"

# -----------------------------------------------------------------------------
# Desktop launcher icons (~/Desktop)
# -----------------------------------------------------------------------------
# pcmanfm --desktop (set in autostart above) shows icons placed in ~/Desktop.
# Each icon is a ".desktop" file — a small text file describing an app:
#   Type=Application   : this launches a program
#   Name=...           : the label shown under the icon
#   Exec=...           : the command to run when double-clicked
#   Icon=...           : an icon name from the system icon theme
#   Terminal=false     : don't open a terminal window to run it
# We mark them executable so pcmanfm launches them on click without warning.

echo "    Creating desktop icons..."

DESKTOP_DIR=/home/microscopist/Desktop
mkdir -p "$DESKTOP_DIR"

# Icon 1 — Copy Files (opens the file manager for USB transfers)
cat > "$DESKTOP_DIR/copy-files.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Copy Files (USB)
Comment=Open the file manager to copy images to a USB drive
Exec=pcmanfm
Icon=system-file-manager
Terminal=false
EOF

# Icon 2 — Terminal
cat > "$DESKTOP_DIR/terminal.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
Comment=Open a command-line terminal
Exec=xterm
Icon=utilities-terminal
Terminal=false
EOF

# Icon 3 — Camera
cat > "$DESKTOP_DIR/camera.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Camera
Comment=Live camera preview and image capture
Exec=guvcview
Icon=camera-web
Terminal=false
EOF

# Icon 4 — Firefox
cat > "$DESKTOP_DIR/firefox.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web browser
Exec=firefox
Icon=firefox
Terminal=false
EOF

# Icon 5 — Fiji (only created if Fiji actually installed)
if [ "$FIJI_OK" -eq 1 ]; then
cat > "$DESKTOP_DIR/fiji.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fiji
Comment=Scientific image analysis (ImageJ)
Exec=fiji
Icon=applications-graphics
Terminal=false
EOF
fi

# Make all the icons executable so pcmanfm runs them on double-click
chmod +x "$DESKTOP_DIR"/*.desktop

# Fix ownership: this script runs as root, but all files inside
# /home/microscopist must belong to the microscopist user, not root.
# -R = recursive (applies to everything inside the directory)
chown -R microscopist:microscopist /home/microscopist/.config
chown -R microscopist:microscopist /home/microscopist/Desktop
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
if [ "$FIJI_OK" -eq 1 ]; then
echo "    [x] Fiji installed to /opt/fiji (shortcut: /usr/local/bin/fiji)"
else
echo "    [ ] Fiji NOT installed (download failed) — see manual steps below"
fi
echo "    [x] LightDM enabled with auto-login as microscopist"
echo "    [x] Openbox configured with autostart (guvcview + tint2)"
echo "    [x] USB auto-mount configured (udiskie)"
echo ""
echo "  On next boot:"
echo "    - LightDM starts automatically"
echo "    - microscopist logs in without a password"
echo "    - Openbox starts with tint2 and guvcview"
if [ "$FIJI_OK" -eq 1 ]; then
echo "    - Fiji launches automatically"
fi
echo "    - USB drives are auto-mounted when plugged in"
echo ""

if [ "$FIJI_OK" -ne 1 ]; then
echo "  ----------------------------------------------------------"
echo "  TO INSTALL FIJI MANUALLY (if the download failed):"
echo "  ----------------------------------------------------------"
echo "    1. Download it:"
echo "       wget -O /tmp/fiji.zip \\"
echo "         https://downloads.imagej.net/fiji/latest/fiji-latest-linux64-jdk.zip"
echo "    2. Extract and move into place:"
echo "       unzip /tmp/fiji.zip -d /tmp/fiji-extract"
echo "       sudo mv /tmp/fiji-extract/* /opt/fiji"
echo "    3. Create the launcher shortcut (adjust name if needed):"
echo "       sudo ln -sf \"\$(find /opt/fiji -maxdepth 2 -name fiji -type f | head -n1)\" /usr/local/bin/fiji"
echo "       sudo chmod +x /opt/fiji/fiji"
echo "    4. Fix ownership:"
echo "       sudo chown -R microscopist:microscopist /opt/fiji"
echo ""
fi

echo "  NOTE on keyboard layout:"
echo "    This script sets the Mac French AZERTY variant."
echo "    If you are on a standard PC keyboard, edit the script and"
echo "    change the localectl line to: localectl set-x11-keymap fr"
echo ""
echo "  To reboot now:"
echo "    sudo reboot"
echo ""

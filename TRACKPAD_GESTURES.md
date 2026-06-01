# Custom Trackpad Gestures on COSMIC Desktop (Wayland) using Fusuma

This guide explains how to set up custom three-finger trackpad gestures on Pop!_OS 24.04 (featuring the Rust-based COSMIC desktop environment on Wayland).

By default, COSMIC handles four-finger swipes natively for switching workspaces. To add custom three-finger gestures with **smooth, continuous scrolling** (similar to macOS or a Chromebook), we use **`Fusuma`** to capture raw trackpad events and translate them into keystrokes or D-Bus actions.

---

## 📋 Prerequisites

Before starting, ensure the following utilities are installed:
1. **`libinput-tools`**: Used by Fusuma to read pointer events.
2. **`wtype`**: A Wayland-native virtual keyboard simulator (necessary for simulating tab switching).
3. **`ruby`**: The programming language runtime required to run Fusuma.

---

## 🛠️ Step-by-Step Installation

Follow these steps to install and configure the gesture system from scratch on a new machine:

### 1. Install System Packages
```bash
sudo apt update && sudo apt install -y libinput-tools wtype ruby build-essential
```

### 2. Configure Permissions
Your user account must belong to the `input` group to read raw trackpad gesture events from libinput:
```bash
sudo gpasswd -a $USER input
```

> [!IMPORTANT]
> **You must reboot the computer** (or log out and log back in) after adding yourself to the `input` group for the permission change to take effect.

### 3. Install Fusuma
Install the Fusuma gem package:
```bash
sudo gem install fusuma
```

### 4. Apply Custom Swipe Detector Patch
By default, Fusuma lacks a robust continuous gesture tracker, resulting in time-based repeated keys that lag and feel jittery. To fix this, we apply a custom `SwipeDetector` patch that locks the gesture to the primary axis (horizontal vs vertical) once movement begins, and triggers key presses based on **physical distance swiped** (like a scroll wheel) rather than time intervals.

To apply this patch:
1. Locate the file: `/var/lib/gems/3.2.0/gems/fusuma-3.12.0/lib/fusuma/plugin/detectors/swipe_detector.rb` (paths may vary based on Ruby versions).
2. Apply the custom python script:
   ```bash
   sudo python3 ~/patch_fusuma.py
   ```

### 5. Create the Configuration File
Create the folder:
```bash
mkdir -p ~/.config/fusuma
```
Write the custom mappings to `~/.config/fusuma/config.yml` (see configuration below).

### 6. Configure Autostart
On COSMIC/Pop!_OS, autostart is handled via XDG `.desktop` files which systemd picks up at login. Create the file `~/.config/autostart/fusuma.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Fusuma Gesture Daemon
Exec=/usr/local/bin/fusuma -d
Icon=input-touchpad
Comment=Multi-touch gesture recognizer for trackpad
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
```

Then reload systemd so the service is registered immediately without a reboot:

```bash
systemctl --user daemon-reload
```

---

## ⚙️ Configuration File (`~/.config/fusuma/config.yml`)

Write the following content to `~/.config/fusuma/config.yml`:

```yaml
# ~/.config/fusuma/config.yml
#
# Custom 3-finger gestures configuration for Apple Magic Trackpad / Touchpad.
# (Leaving 4-finger swipes alone to let COSMIC handle desktop switching natively)

swipe:
  3:
    # 3-finger swipe left -> Switch to previous tab (reversed for natural/reverse scrolling)
    left:
      command: 'wtype -M ctrl -k Page_Up -m ctrl'
      threshold: 6.0

    # 3-finger swipe right -> Switch to next tab (reversed for natural/reverse scrolling)
    right:
      command: 'wtype -M ctrl -k Page_Down -m ctrl'
      threshold: 6.0

    # 3-finger swipe up -> Show Workspaces Overview (One-shot)
    up:
      command: 'gdbus call --session -d com.system76.CosmicWorkspaces -o /com/system76/CosmicWorkspaces -m com.system76.CosmicWorkspaces.Show'
      threshold: 1.0

    # 3-finger swipe down -> Hide Workspaces Overview (One-shot)
    down:
      command: 'gdbus call --session -d com.system76.CosmicWorkspaces -o /com/system76/CosmicWorkspaces -m com.system76.CosmicWorkspaces.Hide'
      threshold: 1.0
```

---

## 🔍 How the Gestures Work (Technical Details)

### 1. Axis-Locked, Distance-Based Dragging
Our custom patch tracks the touch surface coordinates and locks the gesture direction to either horizontal or vertical as soon as a threshold is met. For horizontal gestures (tab switching), page transitions are triggered dynamically for every `threshold * 25` pixels of physical travel, providing an incredibly natural dragging experience without timer delay or keyboard sticking.

### 2. Wayland-Safe Desktop Controls (D-Bus)
Because Wayland blocks virtual keyboard emulation (like `wtype` or `xdotool`) from triggering system-level global hotkeys like `Super + w`, we bypass keyboard simulation entirely for desktop actions. Instead, Fusuma directly invokes COSMIC's native D-Bus API to show and hide the workspaces overview.

---

## 🔄 Management

To check if Fusuma is running or debug its event detection:
1. Kill any background instances:
   ```bash
   pkill fusuma
   ```
2. Run it manually in the foreground to see real-time output as you swipe:
   ```bash
   fusuma
   ```
3. Check the autostart service status:
   ```bash
   systemctl --user status app-fusuma@autostart.service
   ```

---

## 🛠️ Troubleshooting

### Gestures stop working after reboot
Fusuma had no autostart entry — it was only started manually. Fix by creating the `.desktop` autostart file (see Step 6 above) and running `systemctl --user daemon-reload`.

To restart Fusuma immediately without rebooting:
```bash
fusuma -d
```
Or via systemd if the autostart file exists:
```bash
systemctl --user restart app-fusuma@autostart.service
```

### Gestures not detected at all
- Confirm your user is in the `input` group: `groups $USER`
- If not, run `sudo gpasswd -a $USER input` then **reboot**
- Check fusuma can see the device: run `fusuma` (no `-d`) in a terminal and swipe — you should see event output

### Gestures trigger but feel laggy or double-fire
- The custom swipe detector patch (Step 4) may not be applied
- Verify by running `fusuma` in foreground and checking if events feel distance-based or timer-based

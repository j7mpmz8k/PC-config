# Nerd Dictation with Multi-Monitor Recording Indicator

This guide explains how to set up `nerd-dictation` on Pop!_OS (Wayland, multi-monitor) with a custom wrapper script for single-key toggling and a pulsing visual recording dot displayed in the top-right corner of each active screen.

---

## 📋 Components Overview

1.  **`nerd-dictation`**: The core speech-to-text engine (VOSK-based).
2.  **Toggle Wrapper Script**: Located at `~/.local/bin/nerd-dictation`. Maps the single key shortcut (`Super + d`) to toggle dictation on/off.
3.  **Visual Indicator Daemon**: Located at `~/.local/bin/nerd-dictation-indicator`. A Python/Tkinter background process that displays a pulsing red recording dot in the top-right corner of each connected monitor when dictation is active.
4.  **Autostart Configuration**: Located at `~/.config/autostart/nerd-dictation-indicator.desktop` to launch the indicator automatically upon logging in.

---

## 🛠️ Installation & Setup

If you need to recreate this setup on a new system:

### 1. Create the Toggle Wrapper Script
Write the following script to `~/.local/bin/nerd-dictation` (making sure it is executable: `chmod +x`):

```bash
#!/bin/bash
# Wrapper to run nerd-dictation with the correct Python interpreter (GIL-disabled) and default parameters for Pop!_OS on Wayland.

PYTHON_EXE="/home/johndoe/.pyenv/versions/3.14.5t/bin/python"
DICTATION_SCRIPT="/home/johndoe/Github/nerd-dictation/nerd-dictation"

# If executing the "toggle" command, check if already running
if [ "$1" = "toggle" ]; then
    # Check if the Python nerd-dictation process is already running (excluding the indicator)
    if pgrep -f "python.*nerd-dictatio[n](\$|[^a-zA-Z0-9_-])" > /dev/null; then
        exec "$PYTHON_EXE" "$DICTATION_SCRIPT" end
    else
        # Start it in the background so it doesn't freeze
        exec "$PYTHON_EXE" "$DICTATION_SCRIPT" begin --input=PAREC --simulate-input-tool=WTYPE &
    fi
elif [ "$1" = "begin" ]; then
    shift
    exec "$PYTHON_EXE" "$DICTATION_SCRIPT" begin --input=PAREC --simulate-input-tool=WTYPE "$@"
else
    exec "$PYTHON_EXE" "$DICTATION_SCRIPT" "$@"
fi
```

### 2. Create the Visual Indicator Script
Write the Python script to `~/.local/bin/nerd-dictation-indicator` (and make it executable: `chmod +x`):

```python
#!/usr/bin/env python3
import tkinter as tk
import os
import glob
import subprocess
import re
import threading
import struct
import select
import time

dictation_pid = None

def is_dictation_running():
    # 1. Cookie file presence = dictation is running; absence = stopped.
    if not os.path.exists('/tmp/nerd-dictation.cookie'):
        return False

    # 2. Verify that the process is actually running (handling crashes)
    global dictation_pid
    # Quick check using cached PID
    if dictation_pid is not None:
        if os.path.exists(f'/proc/{dictation_pid}'):
            try:
                with open(f'/proc/{dictation_pid}/cmdline', 'rb') as f:
                    cmdline = f.read().decode('utf-8', errors='ignore')
                    if 'nerd-dictation' in cmdline and 'indicator' not in cmdline:
                        return True
            except Exception:
                pass
        # Cache is invalid or process ended
        dictation_pid = None
        
    # Scanning /proc if no cached PID
    my_pid = os.getpid()
    for path in glob.glob('/proc/[0-9]*/cmdline'):
        try:
            pid = int(path.split('/')[2])
            if pid == my_pid:
                continue
            with open(path, 'rb') as f:
                cmdline = f.read().decode('utf-8', errors='ignore')
                if 'nerd-dictation' in cmdline and 'indicator' not in cmdline:
                    dictation_pid = pid
                    return True
        except (IOError, OSError, ValueError):
            continue
    return False

def check_cookie_running():
    # Cookie file exists while dictation is running; it is removed when dictation ends.
    return os.path.exists('/tmp/nerd-dictation.cookie')

def keyboard_listener_thread():
    fds = {}  # fd -> path
    last_scan_time = 0
    
    while True:
        current_time = time.time()
        # Rescan for new keyboards every 5 seconds
        if current_time - last_scan_time > 5.0:
            last_scan_time = current_time
            try:
                devices = set(glob.glob('/dev/input/by-id/*event-kbd') + glob.glob('/dev/input/by-path/*event-kbd'))
                opened_paths = set(fds.values())
                for path in devices:
                    if path not in opened_paths:
                        try:
                            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                            fds[fd] = path
                        except Exception:
                            pass
            except Exception:
                pass

        if not fds:
            time.sleep(1)
            continue

        try:
            r, _, _ = select.select(list(fds.keys()), [], [], 1.0)
            for fd in r:
                try:
                    while True:
                        try:
                            data = os.read(fd, 24)
                        except BlockingIOError:
                            break
                        
                        if not data:
                            raise OSError("EOF")
                            
                        if len(data) == 24:
                            sec, usec, ev_type, code, val = struct.unpack('qqHHi', data)
                            if ev_type == 1:  # EV_KEY
                                if code in (28, 96) and val == 1:  # Enter or Numpad Enter pressed
                                    if is_dictation_running():
                                        subprocess.run(
                                            ['/home/johndoe/.local/bin/nerd-dictation', 'toggle'],
                                            stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL
                                        )
                        else:
                            break
                except (OSError, Exception):
                    try:
                        os.close(fd)
                    except Exception:
                        pass
                    fds.pop(fd, None)
        except Exception:
            for fd in list(fds.keys()):
                try:
                    os.close(fd)
                except Exception:
                    pass
            fds.clear()
            time.sleep(1)


def get_monitors():
    monitors = []
    try:
        output = subprocess.check_output(['xrandr', '--listmonitors']).decode('utf-8')
        for line in output.splitlines():
            # Match layout line
            match = re.search(r'\s*\d+:\s+\S+\s+(\d+)/\d+x(\d+)/\d+\+(\d+)\+(\d+)', line)
            if match:
                w, h, x, y = map(int, match.groups())
                monitors.append({'w': w, 'h': h, 'x': x, 'y': y})
            else:
                match = re.search(r'\s*\d+:\s+\S+\s+(\d+)x(\d+)\+(\d+)\+(\d+)', line)
                if match:
                    w, h, x, y = map(int, match.groups())
                    monitors.append({'w': w, 'h': h, 'x': x, 'y': y})
    except Exception:
        pass
    if not monitors:
        # Fallback to single primary screen bounds
        monitors = [{'w': 1920, 'h': 1080, 'x': 0, 'y': 0}]
    return monitors

class MultiMonitorIndicatorApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.withdraw() # Hide the main root window
        
        self.windows = []
        self.canvas_ovals = []
        self.visible = False
        
        self.colors = ['#ff0000', '#ff2222', '#ff4444', '#ff6666', '#ff8888', '#ff6666', '#ff4444', '#ff2222']
        self.pulse_index = 0
        
        # Start keyboard listener in a daemon thread so it runs in background
        self.listener_thread = threading.Thread(target=keyboard_listener_thread, daemon=True)
        self.listener_thread.start()
        
        self.check_status()
        self.animate()
        
    def show_indicators(self):
        self.hide_indicators() # Clean up any existing first
        
        monitors = get_monitors()
        width = 25
        
        for i, mon in enumerate(monitors):
            try:
                win = tk.Toplevel(self.root)
                win.title(f"Nerd Dictation Indicator {i}")
                
                # Make it borderless and topmost
                win.overrideredirect(True)
                win.attributes("-topmost", True)
                
                # Position at top-right corner of this monitor with 15px margin
                x = mon['x'] + mon['w'] - width - 15
                y = mon['y'] + 15
                win.geometry(f"{width}x{width}+{x}+{y}")
                
                # Hide initially to prepare for batch showing
                win.withdraw()
                
                # Create a rounded borderless dark panel with pulsing red circle inside
                canvas = tk.Canvas(win, width=width, height=width, bg='#1a1a1a', highlightthickness=0)
                canvas.pack()
                
                oval = canvas.create_oval(3, 3, width-3, width-3, fill='#ff0000', outline='#ff0000')
                
                self.windows.append(win)
                self.canvas_ovals.append((canvas, oval))
            except Exception:
                pass
                
        # Show all windows at once
        for win in self.windows:
            try:
                win.deiconify()
            except Exception:
                pass
                
        # Batch-flush window mapping requests to X11/compositor
        try:
            self.root.update()
        except Exception:
            pass
            
        self.visible = True
        
    def hide_indicators(self):
        # 1. Withdraw all windows immediately to remove them from screen simultaneously
        for win in self.windows:
            try:
                win.withdraw()
            except Exception:
                pass
                
        # Batch-flush window unmapping requests
        try:
            self.root.update()
        except Exception:
            pass
            
        # 2. Safely destroy the window objects
        for win in self.windows:
            try:
                win.destroy()
            except Exception:
                pass
        self.windows.clear()
        self.canvas_ovals.clear()
        self.visible = False
        
    def check_status(self):
        try:
            running = is_dictation_running()
            if running and not self.visible:
                self.show_indicators()
            elif not running and self.visible:
                self.hide_indicators()
        except Exception:
            pass
        # Check status every 50ms for extremely snappy response time
        self.root.after(50, self.check_status)
        
    def animate(self):
        if self.visible:
            color = self.colors[self.pulse_index]
            for canvas, oval in self.canvas_ovals:
                try:
                    canvas.itemconfig(oval, fill=color, outline=color)
                except Exception:
                    pass
            self.pulse_index = (self.pulse_index + 1) % len(self.colors)
        self.root.after(120, self.animate)
        
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = MultiMonitorIndicatorApp()
    app.run()
```

### 3. Create the Autostart File
To automatically start the indicator process on login, create the file `~/.config/autostart/nerd-dictation-indicator.desktop`:

> [!IMPORTANT]
> The `Exec` line **must** use the full path to the pyenv Python interpreter, not just the script path. On COSMIC/Pop!_OS, the XDG autostart is run via systemd which does not inherit your shell's `PATH` or pyenv shims. Using the bare script path causes it to launch with system Python, which lacks `tkinter` and will silently fail.

```ini
[Desktop Entry]
Type=Application
Name=Nerd Dictation Indicator
Exec=/home/johndoe/.pyenv/versions/3.14.5t/bin/python3 /home/johndoe/.local/bin/nerd-dictation-indicator
Icon=audio-input-microphone
Comment=Visual indicator for nerd-dictation
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
```

After creating or editing this file, reload the systemd user daemon so COSMIC picks up the change immediately (without needing a reboot):

```bash
systemctl --user daemon-reload
systemctl --user restart "app-nerd\x2ddictation\x2dindicator@autostart.service"
```

### 4. Bind the Toggle Command to a Keyboard Shortcut
On COSMIC Desktop, you can configure the shortcut by going to **Settings > Input Devices > Keyboard > Keyboard Shortcuts** and adding a custom shortcut:
*   **Name**: `Nerd Dictation`
*   **Shortcut Key**: `Super + d`
*   **Command**: `/home/johndoe/.local/bin/nerd-dictation toggle`

---

## 🛠️ Troubleshooting

### Indicator not showing after reboot
The autostart service is managed by systemd. To check if it started correctly:

```bash
systemctl --user status "app-nerd\x2ddictation\x2dindicator@autostart.service"
```

Common failure reasons:

| Symptom | Cause | Fix |
|---|---|---|
| `ModuleNotFoundError: No module named 'tkinter'` | `Exec` in `.desktop` uses system Python instead of pyenv | Update `Exec` to use full pyenv path (see Step 3 above) then run `systemctl --user daemon-reload` |
| Indicator does not appear but dictation works | Stale `/tmp/nerd-dictation.cookie` file from a previous session | Run `rm -f /tmp/nerd-dictation.cookie` then toggle dictation again |
| Enter key does not toggle dictation off | `check_cookie_running()` was checking `mtime == 0` which nerd-dictation never sets; cookie presence/absence is the correct signal | Fixed in current script — `check_cookie_running()` now uses `os.path.exists()` |
| Indicator flashes briefly when pressing Enter with dictation off | `nerd-dictation end` unconditionally calls `touch()` on the cookie file even when nothing is running, causing a brief false-positive | Fixed — keyboard listener now uses `is_dictation_running()` (cookie + `/proc` check) and calls `toggle` instead of `end` |

### Manually starting the indicator for the current session
If the daemon died and you need to restart it without rebooting:

```bash
systemctl --user restart "app-nerd\x2ddictation\x2dindicator@autostart.service"
```

Or to start it directly in the background:

```bash
/home/johndoe/.pyenv/versions/3.14.5t/bin/python3 /home/johndoe/.local/bin/nerd-dictation-indicator &
```

### Clearing a stale cookie file
If dictation was running when the system was rebooted, the cookie file may be left with a non-zero timestamp. This causes the indicator to think dictation is off even when you start it:

```bash
rm -f /tmp/nerd-dictation.cookie
```

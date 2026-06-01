# Firefox & Zen Browser Wayland Crash Fix (Crostini / ChromeOS)

This guide documents the root cause and the permanent fix for Firefox-based browsers (like Zen Browser) crashing when running natively under Wayland on ChromeOS Linux (Crostini).

## The Issue

When running Firefox or Zen Browser natively on Wayland under Crostini, interacting with context menus (right-clicking, dropdown menus, etc.) causes the browser to instantly crash with the following terminal output:

```text
Exiting due to channel error.
Exiting due to channel error.
Segmentation fault (core dumped)
```

### Root Cause
1. **Sommelier (Wayland Proxy):** Crostini uses a custom Wayland proxy named `sommelier` to display Linux windows on the ChromeOS host desktop.
2. **Popup Grabs:** When a right-click or dropdown menu is opened in native Wayland mode, the browser requests a window popup and pointer grab. If the browser's Wayland protocol implementation clashes with how `sommelier` expects grabs or coordinates to be computed, the display server terminates the connection, causing a crash.
3. **X11 Sluggishness:** Forcing the browser to X11 mode (`MOZ_ENABLE_WAYLAND=0`) acts as a workaround to prevent the crash, but it runs extremely sluggishly/laggy because it bypasses native hardware acceleration and runs software-rendered WebRender in a virtualized container.

---

## The Solution

To get smooth, hardware-accelerated rendering under native Wayland without crashes, we must disable the Wayland fractional scaling protocol, which is the source of the Sommelier grab conflict.

This is accomplished by setting `widget.wayland.fractional-scale.enabled` to `false`.

### Step 1: Force Wayland Mode
In the browser wrapper launcher script (e.g., [~/.local/bin/zen](file:///home/crostini/.local/bin/zen)), export the Wayland environment variable before execution:

```bash
#!/bin/bash
export MOZ_ENABLE_WAYLAND=1
exec "/home/crostini/.tarball-installations/zen/zen" "$@"
```

### Step 2: Set Global Enterprise Policies (Recommended)
Rather than manually configuring this setting for every profile, create a global `policies.json` file inside the browser's installation directory. This locks the preference globally, covering all current and future profiles.

Create [~/.tarball-installations/zen/distribution/policies.json](file:///home/crostini/.tarball-installations/zen/distribution/policies.json):

```json
{
  "policies": {
    "Preferences": {
      "widget.wayland.fractional-scale.enabled": {
        "Value": false,
        "Status": "locked"
      }
    }
  }
}
```

### Step 3: Add to Profile Configurations (Safety Net)
To ensure the settings are immediately applied to the current profile, create a `user.js` file in the active profile directory (e.g., `~/.config/zen/<profile-name>/user.js`):

```javascript
user_pref("widget.wayland.fractional-scale.enabled", false);
```

---

## Summary of Benefits
* **Hardware Acceleration:** Native Wayland uses the host GPU via Sommelier, removing all interface lag.
* **No Crashes:** Disabling the fractional scaling negotiation prevents Sommelier from abruptly closing the browser's connection on right-click.

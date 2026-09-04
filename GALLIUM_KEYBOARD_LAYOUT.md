# Gallium v2 Custom Keyboard Layout Setup & Troubleshooting (Pop!_OS / COSMIC)

This guide documents the setup, configuration, and common issues with the Gallium v2 custom XKB keyboard layout (with angle mod and Backspace ↔ CapsLock swap) on Pop!_OS running the COSMIC desktop.

## Overview

The Gallium v2 layout is a custom XKB layout that remaps all letter keys to the Gallium arrangement (with angle mod) and swaps Backspace with CapsLock. It is defined in `/usr/share/X11/xkb/symbols/custom` and registered in the XKB evdev rules so it appears as a selectable input source alongside the standard US layout in COSMIC Settings.

Two input sources are configured: **US** (standard QWERTY) and **Gallium v2** (custom). The Backspace ↔ CapsLock swap only applies when the Gallium layout is active.

---

## Fresh Install Setup

Follow these steps in order on a clean Pop!_OS install to set up the Gallium v2 layout.

### Run the Installer Script

The installer script handles everything — creating the XKB symbols file, registering the layout in `evdev.xml`, and configuring the COSMIC compositor. It is idempotent and safe to re-run (e.g., after a system update overwrites the files).

```bash
sudo ./install-gallium-layout.sh
```

Then log out and back in. You can switch between US and Gallium from **COSMIC Settings → Keyboard → Input Sources**.

The script performs three steps:

1. **Creates `/usr/share/X11/xkb/symbols/custom`** — the XKB symbols file with the full Gallium v2 layout and the Backspace ↔ CapsLock swap.
2. **Registers the layout in `/usr/share/X11/xkb/rules/evdev.xml`** — adds a `<layout>` entry so it appears as a selectable input source in COSMIC Settings. Skips if already registered.
3. **Configures `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config`** — sets `us` as the default layout with `custom` (Gallium) as secondary. Creates the file if it doesn't exist, or fixes the layout order if it's wrong.

> **⚠️ Note:** Steps 1 and 2 modify files in `/usr/share/` which may be overwritten by system updates. If the layout breaks or disappears after an update, re-run the script.

---

## Configuration Files

### 1. XKB Symbols File

**Path:** `/usr/share/X11/xkb/symbols/custom`

This file defines the Gallium key layout and the Backspace ↔ CapsLock swap. The swap section requires special handling because CapsLock is a modifier key (bound to the `Lock` modifier). Without explicit `replace`, `actions`, and `repeat` directives:
- The Lock modifier **bleeds through** even after reassigning the keysym to BackSpace.
- The key **won't auto-repeat** when held (since modifier keys don't repeat by default).

```xkb
default partial
xkb_symbols "basic" {
    include "us(basic)"

    name[Group1] = "Gallium v2 (rowstag, angle mod)";

    // Top row: b l d c v   j f o u ;
    key <AD01> {[ b, B ]};
    key <AD02> {[ l, L ]};
    key <AD03> {[ d, D ]};
    key <AD04> {[ c, C ]};
    key <AD05> {[ v, V ]};
    key <AD06> {[ j, J ]};
    key <AD07> {[ f, F ]};
    key <AD08> {[ o, O ]};
    key <AD09> {[ u, U ]};
    key <AD10> {[ semicolon, colon ]};

    // Home row: n r t s g   y h a e i '
    key <AC01> {[ n, N ]};
    key <AC02> {[ r, R ]};
    key <AC03> {[ t, T ]};
    key <AC04> {[ s, S ]};
    key <AC05> {[ g, G ]};
    key <AC06> {[ y, Y ]};
    key <AC07> {[ h, H ]};
    key <AC08> {[ a, A ]};
    key <AC09> {[ e, E ]};
    key <AC10> {[ i, I ]};
    key <AC11> {[ apostrophe, quotedbl ]};

    // Bottom row (angle mod): q m w z x   k p , . /
    key <AB01> {[ q, Q ]};
    key <AB02> {[ m, M ]};
    key <AB03> {[ w, W ]};
    key <AB04> {[ z, Z ]};
    key <AB05> {[ x, X ]};
    key <AB06> {[ k, K ]};
    key <AB07> {[ p, P ]};
    key <AB08> {[ comma, less ]};
    key <AB09> {[ period, greater ]};
    key <AB10> {[ slash, question ]};

};
```

### Hardware-Level Swap for Laptop Keyboard (`udev hwdb`)

The built-in laptop keyboard (`AT Translated Set 2 keyboard`) swaps CapsLock and Backspace at the kernel hardware driver level via `/etc/udev/hwdb.d/90-custom-keyboard.hwdb`:

```ini
evdev:name:AT Translated Set 2 keyboard:*
 KEYBOARD_KEY_3a=backspace
 KEYBOARD_KEY_0e=capslock
```

**Why this is done:**
- Hardware scancode `3a` (CapsLock) emits true Linux input event `KEY_BACKSPACE` (evdev 14).
- Hardware scancode `0e` (Backspace) emits true Linux input event `KEY_CAPSLOCK` (evdev 58).
- Chromium, Brave, VSCode, Electron, and Wayland all see real hardware Backspace with native auto-repeat without needing any application-level hacks or X11 fallback flags.
- **External keyboards (like the BCORNE) are completely untouched**, since the rule only applies to the internal keyboard device.

> **⚠️ Note:** This file and the XKB layout in `/usr/share/` require `sudo` to set up and are managed automatically by `install-gallium-layout.sh`.

### Automatic Layout Switching on BCORNE Connect/Disconnect

When using the BCORNE external keyboard, you need the OS set to **US** so the keyboard's QMK firmware can output Gallium characters directly without double-translation. When typing on the laptop's built-in keyboard, you need the OS set to **Gallium**.

An automatic `udev` rule (`/etc/udev/rules.d/99-bcorne-layout-switch.rules`), switcher script (`/usr/local/bin/switch-cosmic-layout`), and native Wayland helper (`/usr/local/bin/cosmic-layout-ctl`) handle this seamlessly:
- **BCORNE plugged in:** Udev triggers on `ENV{DEVTYPE}=="usb_device"` and `ENV{PRODUCT}=="6401/45d4/*"`, running `switch-cosmic-layout us` which invokes `cosmic-layout-ctl 0` (US).
- **BCORNE unplugged:** Udev triggers removal on the same product ID, running `switch-cosmic-layout custom` which invokes `cosmic-layout-ctl 1` (Gallium).
- **How it works:** `cosmic-comp` manages active layouts dynamically in memory via its private `zcosmic_keyboard_layout_v1` Wayland protocol. `cosmic-layout-ctl` talks directly to the user's active Wayland socket (`/run/user/<uid>/wayland-*`), switching the live layout instantly without touching disk configs or reloading the compositor.
- **Manual override:** You can still manually toggle layouts at any time via `Super+Space` or the COSMIC top panel applet.

---

### 2. COSMIC Compositor XKB Config

**Path:** `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config`

This file controls which keyboard layouts COSMIC loads and in what order. The **first layout listed is the default** on login.

```ron
(
    rules: "",
    model: "",
    layout: "us,custom",
    variant: ",",
    options: Some("lv3:ralt_switch,compose:rctrl"),
    repeat_delay: 600,
    repeat_rate: 25,
)
```

**Critical:** `us` must come **before** `custom` in the `layout` field. The first layout is the system default on every login. If `custom` is listed first, the Gallium layout (with the Backspace ↔ CapsLock swap) will be active by default on all keyboards, including external keyboards that handle their own layout in firmware (e.g., QMK/Vial keyboards like the BCORNE).

---

## Common Issues & Fixes

### Issue 1: CapsLock and Backspace are swapped on ALL layouts (including US)

**Symptom:** Even when switched to the US layout, CapsLock and Backspace are swapped on all keyboards.

**Cause:** The Gallium layout (`custom`) is listed first in the COSMIC `xkb_config`, making it the default. COSMIC loads the first layout on login, and the swap from Gallium applies system-wide.

**Fix:** Edit `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config` and change the layout order so `us` comes first:

```
layout: "us,custom",
```

Then log out and back in.

> **Note:** This can happen after a system update — COSMIC or Pop!_OS updates may regenerate this config file and reorder the layouts.

### Issue 2: CapsLock acts as both BackSpace AND CapsLock when in Gallium

**Symptom:** When the Gallium layout is active, pressing CapsLock triggers a backspace AND toggles Caps Lock (the caps lock indicator light turns on/off).

**Cause:** In XKB, `/usr/share/X11/xkb/symbols/pc` defines `modifier_map Lock { Caps_Lock };`. Because Group 1 (US) assigns `Caps_Lock` to `<CAPS>` (keycode 66), physical key 66 is added to the `Lock` modifier map across the entire system. Since `modifier_map` bindings apply to physical keys regardless of the active layout, pressing `<CAPS>` toggles the `Lock` modifier even when Gallium maps it to `BackSpace`.

**Fix:** Disable `modifier_map Lock { Caps_Lock };` in `/usr/share/X11/xkb/symbols/pc` (handled automatically by `install-gallium-layout.sh`). XKB's default compatibility rule (`interpret Caps_Lock { action = LockMods(modifiers = Lock); };`) will still lock CapsLock whenever the `Caps_Lock` keysym is emitted (on `<CAPS>` in US and on `<BKSP>` in Gallium), but without erroneously binding physical key 66 to Lock in Gallium.

### Issue 3: Holding CapsLock (as BackSpace) doesn't repeat

**Symptom:** When the Gallium layout is active, pressing and holding CapsLock (remapped to BackSpace) only deletes a single character. You have to repeatedly tap it.

**Cause:** CapsLock is classified as a modifier key by default, and modifier keys do not have auto-repeat enabled in XKB.

**Fix:** Add `repeat = Yes` to the `<CAPS>` key definition in `/usr/share/X11/xkb/symbols/custom`.

### Issue 4: CapsLock and Backspace stop working on the US layout

**Symptom:** When switched to the US layout, CapsLock does nothing (no lock, no backspace), and/or Backspace doesn't work correctly. Everything works fine on Gallium.

**Cause:** Using `replace key` or custom `actions` inside the Gallium symbols file. When a secondary layout is loaded with `:2`, defining explicit actions causes XKB to initialize unconfigured action slots in Group 1 (US) with `NoAction()`, breaking CapsLock on US.

**Fix:** Use clean shorthand key definitions (`key <CAPS> { repeat = Yes, [ BackSpace, BackSpace ] };`) and let XKB's compatibility engine handle modifier actions automatically without explicit `actions` blocks.

### Issue 5: Built-in laptop keyboard misbehaves in Electron/Chromium apps (VSCode, Brave)

**Symptom:** On the laptop keyboard under Gallium, CapsLock does not auto-repeat in Brave or VSCode (only single tap works), and/or physical Backspace triggers both deletion and CapsLock in VSCode, while native apps (terminal, COSMIC search) work as expected. The BCORNE keyboard is unaffected.

**Cause:** Chromium/Electron inspects the hardware evdev scancode. If the physical keycode is `KEY_CAPSLOCK` (58), Chromium's Wayland backend hardcodes modifier suppression and disables the auto-repeat timer for that scancode. Furthermore, VSCode defaults to `"keyboard.dispatch": "code"`, triggering `deleteLeft` on the physical Backspace key regardless of XKB remapping. (The BCORNE is unaffected because its QMK firmware physically emits `KEY_BACKSPACE` for that key).

**Fix for VSCode:** In `~/.config/Code/User/settings.json`, set:
```json
"keyboard.dispatch": "keyCode"
```

---

## Restoring After a System Update

If the layout breaks or disappears from COSMIC Settings after a system update, simply re-run the installer script from this repo:

```bash
sudo ~/Github/PC-config/install-gallium-layout.sh
```

The script is idempotent — it will only update what's needed (e.g., if `evdev.xml` was overwritten but the COSMIC config is fine, it will only fix `evdev.xml`).

Then log out and back in for changes to take effect.

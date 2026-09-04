#!/bin/bash
# ============================================================================
# Gallium v2 Custom Keyboard Layout Installer
# ============================================================================
# Sets up the Gallium v2 XKB layout with angle mod and Backspace <-> CapsLock
# swap on Pop!_OS / COSMIC desktop.
#
# What this script does:
#   1. Creates the XKB symbols file (/usr/share/X11/xkb/symbols/custom)
#   2. Registers the layout in evdev.xml (if not already registered)
#   3. Configures COSMIC compositor with US as default, Gallium as secondary
#
# Usage: sudo ./install-gallium-layout.sh
#
# After running, log out and back in for changes to take effect.
# Switch between US and Gallium from COSMIC Settings -> Keyboard -> Input Sources.
# ============================================================================

set -e

# --- Check for root ---
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with sudo."
    echo "Usage: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

echo "=== Gallium v2 Layout Installer ==="
echo ""

# --- Step 1: Create XKB symbols file ---
echo "[1/3] Creating XKB symbols file..."

cat > /usr/share/X11/xkb/symbols/custom << 'LAYOUT'
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
LAYOUT

echo "      Created /usr/share/X11/xkb/symbols/custom"

# --- Step 1b: Hardware-level swap for built-in laptop keyboard via udev hwdb ---
echo "[1b/3] Configuring hardware-level CapsLock <-> Backspace for laptop keyboard..."
HWDB_FILE="/etc/udev/hwdb.d/90-custom-keyboard.hwdb"
cat > "$HWDB_FILE" << 'HWDB'
evdev:name:AT Translated Set 2 keyboard:*
 KEYBOARD_KEY_3a=backspace
 KEYBOARD_KEY_0e=capslock
HWDB
systemd-hwdb update
udevadm trigger /sys/class/input/event*
echo "      Created $HWDB_FILE and reloaded hardware database"

# Restore symbols/pc if it was previously commented out
PC_SYMBOLS="/usr/share/X11/xkb/symbols/pc"
if grep -q "^\/\/[[:space:]]*modifier_map Lock[[:space:]]*{[[:space:]]*Caps_Lock[[:space:]]*};" "$PC_SYMBOLS" 2>/dev/null; then
    sed -i 's/^\/\/[[:space:]]*modifier_map Lock[[:space:]]*{[[:space:]]*Caps_Lock[[:space:]]*};/    modifier_map Lock    { Caps_Lock };/' "$PC_SYMBOLS"
fi

# --- Step 1c: Auto-switch layout on BCORNE connect/disconnect ---
echo "[1c/3] Setting up auto-switching udev rule for BCORNE..."

# Compile native COSMIC Wayland layout control helper
LAYOUT_CTL_SRC="/tmp/cosmic-layout-ctl.c"
cat > "$LAYOUT_CTL_SRC" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <wayland-client.h>

extern const struct wl_interface wl_keyboard_interface;
extern const struct wl_interface zcosmic_keyboard_layout_v1_interface;
extern const struct wl_interface zcosmic_keyboard_layout_manager_v1_interface;

static const struct wl_interface *cosmic_types[] = {
    NULL,
    &zcosmic_keyboard_layout_v1_interface,
    &wl_keyboard_interface,
};

static const struct wl_message manager_requests[] = {
    { "get_keyboard_layout", "no", cosmic_types + 1 },
    { "destroy", "", cosmic_types + 0 },
};

const struct wl_interface zcosmic_keyboard_layout_manager_v1_interface = {
    "zcosmic_keyboard_layout_manager_v1", 1,
    2, manager_requests,
    0, NULL,
};

static const struct wl_message layout_requests[] = {
    { "set_group", "u", cosmic_types + 0 },
    { "destroy", "", cosmic_types + 0 },
};

static const struct wl_message layout_events[] = {
    { "group", "u", cosmic_types + 0 },
};

const struct wl_interface zcosmic_keyboard_layout_v1_interface = {
    "zcosmic_keyboard_layout_v1", 1,
    2, layout_requests,
    1, layout_events,
};

struct state {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_seat *seat;
    struct wl_keyboard *keyboard;
    struct wl_proxy *layout_mgr;
    struct wl_proxy *layout;
    uint32_t current_group;
};

static void layout_group(void *data, struct wl_proxy *layout, uint32_t group) {
    struct state *st = data;
    st->current_group = group;
}

static const struct {
    void (*group)(void *data, struct wl_proxy *layout, uint32_t group);
} layout_listener = { .group = layout_group };

static void seat_caps(void *data, struct wl_seat *seat, uint32_t caps) {
    struct state *st = data;
    if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !st->keyboard) {
        st->keyboard = wl_seat_get_keyboard(seat);
    }
}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_caps,
    .name = (void*)NULL,
};

static void reg_global(void *data, struct wl_registry *registry, uint32_t name, const char *iface, uint32_t v) {
    struct state *st = data;
    if (strcmp(iface, wl_seat_interface.name) == 0) {
        st->seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
        wl_seat_add_listener(st->seat, &seat_listener, st);
    } else if (strcmp(iface, "zcosmic_keyboard_layout_manager_v1") == 0) {
        st->layout_mgr = wl_registry_bind(registry, name, &zcosmic_keyboard_layout_manager_v1_interface, 1);
    }
}

static const struct wl_registry_listener reg_listener = {
    .global = reg_global,
    .global_remove = (void*)NULL,
};

int main(int argc, char *argv[]) {
    struct state st = {0};
    st.display = wl_display_connect(NULL);
    if (!st.display) return 1;
    st.registry = wl_display_get_registry(st.display);
    wl_registry_add_listener(st.registry, &reg_listener, &st);
    wl_display_roundtrip(st.display);
    if (!st.seat || !st.layout_mgr) return 1;
    wl_display_roundtrip(st.display);
    if (!st.keyboard) return 1;
    st.layout = (struct wl_proxy *) wl_proxy_marshal_flags(
        st.layout_mgr, 0, &zcosmic_keyboard_layout_v1_interface,
        wl_proxy_get_version(st.layout_mgr), 0, NULL, st.keyboard);
    wl_proxy_add_listener(st.layout, (void (**)(void)) &layout_listener, &st);
    wl_display_roundtrip(st.display);
    if (argc > 1) {
        uint32_t target = (strcmp(argv[1], "0") == 0 || strcasecmp(argv[1], "us") == 0) ? 0 : 1;
        wl_proxy_marshal_flags(st.layout, 0, NULL, wl_proxy_get_version(st.layout), 0, target);
        wl_display_roundtrip(st.display);
    } else {
        printf("%u\n", st.current_group);
    }
    return 0;
}
EOF
gcc -O2 "$LAYOUT_CTL_SRC" -lwayland-client -o /usr/local/bin/cosmic-layout-ctl
chmod 755 /usr/local/bin/cosmic-layout-ctl
rm -f "$LAYOUT_CTL_SRC"

SWITCHER_SCRIPT="/usr/local/bin/switch-cosmic-layout"
cat > "$SWITCHER_SCRIPT" << 'EOF'
#!/bin/bash
TARGET="$1"
if [ "$TARGET" = "us" ] || [ "$TARGET" = "0" ]; then
    GROUP="0"
else
    GROUP="1"
fi
apply_switch() {
    for run_dir in /run/user/*; do
        if [ -d "$run_dir" ]; then
            uid=$(basename "$run_dir")
            if [[ "$uid" =~ ^[0-9]+$ ]]; then
                username=$(id -nu "$uid" 2>/dev/null)
                if [ -n "$username" ]; then
                    for s in "$run_dir"/wayland-*; do
                        if [ -S "$s" ]; then
                            wdisp=$(basename "$s")
                            runuser -u "$username" -- env XDG_RUNTIME_DIR="$run_dir" WAYLAND_DISPLAY="$wdisp" /usr/local/bin/cosmic-layout-ctl "$GROUP" >/dev/null 2>&1 || true
                        fi
                    done
                fi
            fi
        fi
    done
}
if [ -x /usr/local/bin/cosmic-layout-ctl ]; then
    apply_switch
    (sleep 0.25 && apply_switch) &
fi
EOF
chmod 755 "$SWITCHER_SCRIPT"

UDEV_RULE="/etc/udev/rules.d/99-bcorne-layout-switch.rules"
cat > "$UDEV_RULE" << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="6401/45d4/*", RUN+="/usr/local/bin/switch-cosmic-layout us"
ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="6401/45d4/*", RUN+="/usr/local/bin/switch-cosmic-layout custom"
EOF
udevadm control --reload-rules
echo "      Created $UDEV_RULE, $SWITCHER_SCRIPT, and /usr/local/bin/cosmic-layout-ctl"

# --- Step 2: Register layout in evdev.xml (if not already registered) ---
echo "[2/3] Registering layout in evdev.xml..."

EVDEV_XML="/usr/share/X11/xkb/rules/evdev.xml"

if grep -q '<name>custom</name>' "$EVDEV_XML" 2>/dev/null; then
    echo "      Layout already registered in evdev.xml (skipping)"
else
    sed -i '/<\/layoutList>/i \    <layout>\n      <configItem>\n\t<name>custom</name>\n        <shortDescription>custom</shortDescription>\n        <description>Gallium v2 (Rowstag, Angle Mod)</description>\n        <languageList>\n          <iso639Id>und</iso639Id>\n        </languageList>\n      </configItem>\n      <variantList/>\n    </layout>' "$EVDEV_XML"
    echo "      Registered layout in $EVDEV_XML"
fi

# --- Step 3: Configure COSMIC compositor ---
echo "[3/3] Configuring COSMIC compositor..."

COSMIC_DIR="$REAL_HOME/.config/cosmic/com.system76.CosmicComp/v1"
COSMIC_XKB="$COSMIC_DIR/xkb_config"

mkdir -p "$COSMIC_DIR"

# Check if the config already exists and has the correct layout order
if [[ -f "$COSMIC_XKB" ]]; then
    if grep -q 'layout: "us,custom"' "$COSMIC_XKB"; then
        echo "      COSMIC xkb_config already correct (skipping)"
    elif grep -q 'layout: "custom,us"' "$COSMIC_XKB"; then
        # Fix the layout order (Gallium is default, should be US)
        sed -i 's/layout: "custom,us"/layout: "us,custom"/' "$COSMIC_XKB"
        echo "      Fixed layout order in $COSMIC_XKB (us is now default)"
    else
        # Config exists but doesn't have our layouts — add them
        sed -i 's/layout: ".*"/layout: "us,custom"/' "$COSMIC_XKB"
        echo "      Updated layout in $COSMIC_XKB"
    fi
else
    cat > "$COSMIC_XKB" << 'EOF'
(
    rules: "",
    model: "",
    layout: "us,custom",
    variant: ",",
    options: Some("lv3:ralt_switch,compose:rctrl"),
    repeat_delay: 600,
    repeat_rate: 25,
)
EOF
    chown "$REAL_USER:$REAL_USER" "$COSMIC_XKB"
    echo "      Created $COSMIC_XKB"
fi

echo ""
echo "=== Done! ==="
echo "Log out and back in for changes to take effect."
echo "Switch layouts from COSMIC Settings -> Keyboard -> Input Sources."

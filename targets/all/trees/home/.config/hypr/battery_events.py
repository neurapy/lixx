"""Show Hyprland battery alerts in response to UPower's system D-Bus signals."""

import subprocess
import sys

from gi.repository import Gio, GLib


UPOWER = "org.freedesktop.UPower"
ROOT = "/org/freedesktop/UPower"
WARNING, FLASH, CRITICAL = 15, 10, 5
# Values of org.freedesktop.UPower.Device.Type and .State
BATTERY = 2
CHARGING, DISCHARGING = 1, 2


def proxy(path, interface):
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SYSTEM, Gio.DBusProxyFlags.GET_INVALIDATED_PROPERTIES, None,
        UPOWER, path, interface, None,
    )


def cached(device, name):
    value = device.get_cached_property(name)
    return value.unpack() if value is not None else None


def display(action):
    try:
        result = subprocess.run(
            ["hyprctl", "eval", f'require("config.battery_alerts").{action}'],
            capture_output=True, text=True, timeout=5, check=True,
        )
        if result.stdout.strip() == "ok":
            return True
        message = result.stdout.strip() or result.stderr.strip()
    except (OSError, subprocess.SubprocessError) as error:
        message = str(error)
    print(f"Could not display battery feedback: {message}", file=sys.stderr, flush=True)
    return False


class BatteryAlerts:
    def __init__(self):
        self.manager = proxy(ROOT, UPOWER)
        self.battery = proxy(ROOT + "/devices/DisplayDevice", UPOWER + ".Device")
        self.last_threshold = None
        self.pending = 0
        for obj, fields in (
            (self.manager, {"OnBattery"}),
            (self.battery, {"Percentage", "State", "Type", "IsPresent"}),
        ):
            obj.connect("g-properties-changed", self.changed, fields)
            obj.connect("notify::g-name-owner", self.queue_update)
        self.queue_update()  # Covers signing in while the battery is already low.

    def changed(self, obj, changed, invalidated, fields):
        if fields.intersection(changed.keys()) or fields.intersection(invalidated):
            self.queue_update()

    def queue_update(self, *_):
        # UPower can publish the charger and battery changes in the same burst.
        if not self.pending:
            self.pending = GLib.idle_add(self.update)

    def update(self):
        self.pending = 0
        owner = self.manager.get_name_owner()
        on_battery = cached(self.manager, "OnBattery")
        state = cached(self.battery, "State")
        percent = cached(self.battery, "Percentage")
        if (
            not owner or self.battery.get_name_owner() != owner
            or on_battery is None or state is None or percent is None
            or not 0 <= percent <= 100
            or cached(self.battery, "Type") != BATTERY
            or not cached(self.battery, "IsPresent")
        ):
            return

        if not on_battery or state == CHARGING:
            if self.last_threshold is not None:
                action = "power_restored()" if percent < WARNING else "clear()"
                if display(action):
                    self.last_threshold = None
            return

        if state != DISCHARGING or percent > WARNING:
            return

        shown_percent = int(percent + 0.5)
        if percent <= CRITICAL:
            threshold = shown_percent
        elif percent <= FLASH:
            threshold = FLASH
        else:
            threshold = WARNING

        if self.last_threshold is None or threshold < self.last_threshold:
            flash = "true" if percent <= FLASH else "false"
            if display(f"warn({shown_percent}, {flash})"):
                self.last_threshold = threshold


if __name__ == "__main__":
    alerts = BatteryAlerts()
    GLib.MainLoop().run()

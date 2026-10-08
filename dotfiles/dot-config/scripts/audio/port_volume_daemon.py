#!/usr/bin/env python3
"""Remember the volume level of each audio output.

Watches PipeWire (via `pactl subscribe`). Whenever the active output changes
- 3.5mm jack: headphones <-> speakers (port switch)
- bluetooth headphones connecting / disconnecting
- default sink changing
it saves the volume+mute you had on the old output and restores whatever you
last used on the new one, so unplugging headphones doesn't blast the speakers.

The volume that gets saved/restored is the one on the *default sink node*,
because that's the knob the user actually controls. The state key is derived
from the underlying hardware output, so it also works when the default sink is
a filter-chain (e.g. an equalizer) wrapping the real card.

State file: ~/.local/state/port-volumes/levels  (one "key<TAB>vol<TAB>mute" line)
Run as a user service, see port-volume-daemon.service.
"""

import json
import os
import subprocess
import sys
import threading
import time

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "port-volumes",
)
STATE_FILE = os.path.join(STATE_DIR, "levels")
DEBOUNCE = 0.2  # s; pactl emits bursts of events per change


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def pactl(*args, timeout=5):
    try:
        p = subprocess.run(
            ["pactl", *args], capture_output=True, text=True, timeout=timeout
        )
        return p.stdout
    except Exception as e:
        log("pactl failed:", e)
        return ""


def load_levels():
    levels = {}
    try:
        with open(STATE_FILE) as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3:
                    try:
                        levels[parts[0]] = (int(parts[1]), parts[2] == "1")
                    except ValueError:
                        pass
    except FileNotFoundError:
        pass
    return levels


def save_levels(levels):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        for key, (vol, mute) in sorted(levels.items()):
            f.write(f"{key}\t{vol}\t{int(mute)}\n")
    os.replace(tmp, STATE_FILE)


def sinks():
    try:
        return json.loads(pactl("-f", "json", "list", "sinks"))
    except Exception:
        return []


def default_sink_name():
    try:
        return json.loads(pactl("-f", "json", "info"))["default_sink_name"]
    except Exception:
        return None


def node_volume(sink):
    vol = sink.get("volume", {})
    ch = vol.get("front-left") or vol.get("mono")
    if ch is None and vol:
        ch = next(iter(vol.values()), None)
    if ch is None:
        return None
    try:
        return int(str(ch.get("value_percent", "")).rstrip("%"))
    except ValueError:
        return None


def observe():
    """Return (state_key, knob_node, vol_pct, mute) or None."""
    ss = sinks()
    if not ss:
        return None
    dname = default_sink_name()
    d = next((s for s in ss if s["name"] == dname), None)
    if d is None:
        return None

    if d.get("active_port"):
        # hardware sink with ports (incl. bluetooth if it ever has them)
        key = f"{d['name']}|{d['active_port']}"
    elif d.get("properties", {}).get("node.virtual") == "true":
        # default sink is a filter-chain wrapper; key on the hardware sink
        # behind it, which is the thing that actually changes (jack ports)
        hw = [
            s
            for s in ss
            if s.get("active_port")
            and s.get("properties", {}).get("device.api") == "alsa"
        ]
        if not hw:
            return None
        key = f"{hw[0]['name']}|{hw[0]['active_port']}"
    else:
        # portless hardware sink, e.g. bluetooth
        key = d["name"]

    vol = node_volume(d)
    if vol is None:
        return None
    return key, d["name"], vol, bool(d.get("mute"))


def apply(node, vol, mute):
    subprocess.run(["pactl", "set-sink-volume", node, f"{vol}%"], timeout=5)
    subprocess.run(["pactl", "set-sink-mute", node, "1" if mute else "0"], timeout=5)


def main():
    levels = load_levels()
    wake = threading.Event()

    def watch():
        # pactl subscribe exits if pipewire restarts; restart the watcher
        while True:
            try:
                p = subprocess.Popen(
                    ["pactl", "subscribe"], stdout=subprocess.PIPE, text=True
                )
                for _ in p.stdout:
                    wake.set()
            except Exception as e:
                log("watcher error:", e)
            time.sleep(1)

    threading.Thread(target=watch, daemon=True).start()
    log("port-volume daemon running, state in", STATE_FILE)

    last = None  # (key, node, vol, mute) from the previous poll
    while True:
        wake.wait()
        wake.clear()
        time.sleep(DEBOUNCE)
        cur = observe()
        if cur is None:
            continue
        if last is None or last[0] == cur[0]:
            last = cur
            continue

        old, new = last, cur
        last = cur
        log(f"output changed: {old[0]} -> {new[0]}")

        # remember what the old output was at (volume we last saw on it)
        levels[old[0]] = (old[2], old[3])
        save_levels(levels)

        # restore what the new output had, if we've seen it before
        saved = levels.get(new[0])
        if saved is not None and (saved[0] != new[2] or saved[1] != new[3]):
            log(f"  restore {new[0]}: {saved[0]}% mute={saved[1]} on {new[1]}")
            apply(new[1], *saved)
            last = (new[0], new[1], saved[0], saved[1])


if __name__ == "__main__":
    main()

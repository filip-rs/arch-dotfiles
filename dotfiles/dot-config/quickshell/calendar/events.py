#!/usr/bin/env python3
"""Calendar events for the quickshell calendar panel.

Reads the iCal (ICS) feeds listed in calendar/.env as CALENDAR_ICS_URLS
(space separated; the environment variable of the same name overrides it),
e.g. Google Calendar's "Secret address in iCal format". Recurring events are
expanded, and the events from 60 days ago to 180 days ahead are printed as
JSON, in local time:

  {"configured": true, "updated": 1730000000, "errors": [],
   "calendars": [{"index": 0, "name": "Personal"}],
   "events": [{"title": "...", "location": "...", "calendar": 0,
               "all_day": false,
               "start": "2026-11-03T14:00", "end": "2026-11-03T15:00",
               "start_date": "2026-11-03", "end_date": "2026-11-03"}]}

For all-day events `end` is exclusive (midnight after the last day); for every
event `end_date` is the last day it covers.

The result is cached for 15 minutes in ~/.cache/quickshell/calendar. A stale
cache is printed straight away and refreshed in the background.
"""

import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from zoneinfo import ZoneInfo

from dateutil.rrule import rrulestr

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, ".env")
CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "quickshell", "calendar")
OUT_FILE = os.path.join(CACHE_DIR, "events.json")
LOCK_FILE = os.path.join(CACHE_DIR, "refresh.lock")
MAX_AGE = 900
PAST_DAYS = 60
FUTURE_DAYS = 180
MAX_EVENTS = 5000
MAX_FEED_BYTES = 20 * 1024 * 1024


# --- configuration -----------------------------------------------------------

def read_urls():
    raw = os.environ.get("CALENDAR_ICS_URLS")
    if raw is None:
        raw = ""
        try:
            with open(ENV_FILE, encoding="utf-8") as f:
                for line in f:
                    m = re.match(r'\s*CALENDAR_ICS_URLS\s*=\s*"?([^"]*)"?\s*$', line)
                    if m:
                        raw = m.group(1)
        except FileNotFoundError:
            pass
    return [re.sub(r"^webcal://", "https://", u, flags=re.I) for u in raw.split()]


def config_hash(urls):
    return hashlib.sha256("\n".join(urls).encode()).hexdigest()[:16]


def local_zone():
    name = os.environ.get("TZ", "").lstrip(":")
    if not name:
        path = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in path:
            name = path.split("zoneinfo/", 1)[1]
    try:
        return ZoneInfo(name) if name else None
    except Exception:
        return None


LOCAL = local_zone() or dt.datetime.now().astimezone().tzinfo


# --- ICS parsing ---------------------------------------------------------------

def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def parse_line(line):
    """'NAME;P=V;P2="a:b":VALUE' -> (NAME, {P: V, P2: 'a:b'}, VALUE)."""
    in_quotes = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ":" and not in_quotes:
            head, value = line[:i], line[i + 1:]
            break
    else:
        return None
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        k, _, v = p.partition("=")
        params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def unescape(value):
    return re.sub(r"\\([\\;,nN])",
                  lambda m: "\n" if m.group(1) in "nN" else m.group(1), value)


def parse_calendar(text):
    """Returns (calendar name, [VEVENT property dicts]).

    Each event maps a property name to a list of (params, value). Nested
    components (VALARM) are skipped so their properties don't leak in.
    """
    name = None
    events = []
    cur = None
    depth = 0
    for line in unfold(text):
        parsed = parse_line(line)
        if not parsed:
            continue
        key, params, value = parsed
        if key == "BEGIN":
            if cur is None:
                if value.upper() == "VEVENT":
                    cur, depth = {}, 0
            else:
                depth += 1
        elif key == "END":
            if cur is not None:
                if depth:
                    depth -= 1
                elif value.upper() == "VEVENT":
                    events.append(cur)
                    cur = None
        elif cur is None:
            if key == "X-WR-CALNAME":
                name = unescape(value).strip()
        elif not depth:
            cur.setdefault(key, []).append((params, value))
    return name, events


_zones = {}


def zone(tzid):
    """IANA zone for a TZID, also accepting prefixed forms such as
    '/mozilla.org/20050126_1/America/New_York'. Unknown ones (e.g. Windows
    names) fall back to the local zone."""
    if tzid not in _zones:
        tz = None
        parts = tzid.strip('"').split("/")
        for i in range(len(parts)):
            try:
                tz = ZoneInfo("/".join(parts[i:]))
                break
            except Exception:
                continue
        _zones[tzid] = tz or LOCAL
    return _zones[tzid]


def parse_dt(params, value):
    """(datetime, all_day). All-day values are naive midnights; timed values
    are always timezone-aware (floating times are taken as local)."""
    value = value.strip()
    if params.get("VALUE", "").upper() == "DATE" or re.fullmatch(r"\d{8}", value):
        return dt.datetime.strptime(value[:8], "%Y%m%d"), True
    d = dt.datetime.strptime(value.rstrip("Zz")[:15], "%Y%m%dT%H%M%S")
    if value[-1:] in "Zz":
        return d.replace(tzinfo=dt.timezone.utc), False
    tzid = params.get("TZID")
    return d.replace(tzinfo=zone(tzid) if tzid else LOCAL), False


def parse_duration(value):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?",
                     value.strip())
    if not m:
        return None
    w, d, h, mi, s = (int(x) if x else 0 for x in m.groups()[1:])
    delta = dt.timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)
    return -delta if m.group(1) == "-" else delta


def aware(d):
    return d.replace(tzinfo=LOCAL) if d.tzinfo is None else d


def occurrence_key(d, all_day):
    """Key that matches an occurrence against EXDATE / RECURRENCE-ID values,
    whatever timezone those were written in."""
    if all_day:
        return (d.astimezone(LOCAL) if d.tzinfo else d).date().isoformat()
    return int(aware(d).timestamp())


def fix_until(rule, start):
    """dateutil wants UNTIL to match DTSTART: UTC when DTSTART is aware,
    floating when it is naive. Feeds don't always comply."""
    m = re.search(r"UNTIL=([0-9TZz]+)", rule, re.I)
    if not m:
        return rule
    raw = m.group(1).upper()
    try:
        if len(raw) == 8:
            until, tz = dt.datetime.strptime(raw, "%Y%m%d").replace(hour=23, minute=59, second=59), None
        else:
            until = dt.datetime.strptime(raw.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
            tz = dt.timezone.utc if raw.endswith("Z") else None
    except ValueError:
        return rule
    if start.tzinfo is None:
        if tz:
            until = until.replace(tzinfo=tz).astimezone(LOCAL).replace(tzinfo=None)
        new = until.strftime("%Y%m%dT%H%M%S")
    else:
        until = until.replace(tzinfo=tz or start.tzinfo)
        new = until.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return rule[:m.start(1)] + new + rule[m.end(1):]


def first(ev, key, default=""):
    values = ev.get(key)
    return values[0][1] if values else default


def occurrences(ev, ws, we, skip_keys=()):
    """(start, end, all_day) for each occurrence of `ev` overlapping [ws, we)."""
    start, all_day = parse_dt(*ev["DTSTART"][0])
    dur = None
    if "DTEND" in ev:
        try:
            dur = parse_dt(*ev["DTEND"][0])[0] - start
        except (TypeError, ValueError):
            dur = None
    elif "DURATION" in ev:
        dur = parse_duration(first(ev, "DURATION"))
    if dur is None or dur < dt.timedelta(0):
        dur = dt.timedelta(days=1) if all_day else dt.timedelta(0)

    if "RRULE" in ev:
        rule = rrulestr("RRULE:" + fix_until(first(ev, "RRULE"), start), dtstart=start)
        lo = ws - dur - dt.timedelta(days=1)
        if start.tzinfo is None:
            starts = rule.between(lo.astimezone(LOCAL).replace(tzinfo=None),
                                  we.astimezone(LOCAL).replace(tzinfo=None), inc=True)
        else:
            starts = rule.between(lo, we, inc=True)
        for params, value in ev.get("RDATE", []):
            if params.get("VALUE", "").upper() == "PERIOD":
                continue
            for item in value.split(","):
                try:
                    d, _ = parse_dt(params, item)
                except ValueError:
                    continue
                if all_day:
                    d = dt.datetime.combine(dt.date.fromisoformat(occurrence_key(d, True)), dt.time())
                starts.append(d)
        excluded = set(skip_keys)
        for params, value in ev.get("EXDATE", []):
            for item in value.split(","):
                try:
                    excluded.add(occurrence_key(parse_dt(params, item)[0], all_day))
                except ValueError:
                    continue
        starts = sorted({occurrence_key(s, all_day): s for s in starts
                         if occurrence_key(s, all_day) not in excluded}.values(),
                        key=lambda s: aware(s))
    else:
        starts = [start]

    for s in starts:
        e = s + dur
        sa, ea = aware(s), aware(e)
        if sa < we and (ea > ws or (ea == sa and sa >= ws)):
            yield s, e, all_day


def to_output(ev, s, e, all_day, cal_index):
    if all_day:
        sd = s.date()
        end_excl = e.date() if e.date() > sd else sd + dt.timedelta(days=1)
        start_s, end_s = sd.isoformat() + "T00:00", end_excl.isoformat() + "T00:00"
        end_date = end_excl - dt.timedelta(days=1)
    else:
        ls, le = s.astimezone(LOCAL), e.astimezone(LOCAL)
        sd = ls.date()
        start_s, end_s = ls.strftime("%Y-%m-%dT%H:%M"), le.strftime("%Y-%m-%dT%H:%M")
        end_date = (le - dt.timedelta(microseconds=1)).date() if le > ls else sd
    return {
        "title": unescape(first(ev, "SUMMARY", "(No title)")).strip() or "(No title)",
        "location": unescape(first(ev, "LOCATION")).strip(),
        "calendar": cal_index,
        "all_day": all_day,
        "start": start_s,
        "end": end_s,
        "start_date": sd.isoformat(),
        "end_date": end_date.isoformat(),
    }


def collect(events, cal_index, ws, we):
    """Expand the VEVENTs of one feed, applying moved/cancelled occurrences
    (RECURRENCE-ID overrides) to their recurring masters."""
    masters, overrides = [], {}
    for ev in events:
        if "DTSTART" not in ev:
            continue
        if "RECURRENCE-ID" in ev:
            overrides.setdefault(first(ev, "UID"), []).append(ev)
        else:
            masters.append(ev)

    out = []
    for ev in masters:
        if first(ev, "STATUS").upper() == "CANCELLED":
            continue
        uid = first(ev, "UID")
        try:
            all_day = parse_dt(*ev["DTSTART"][0])[1]
            skip = [occurrence_key(parse_dt(*o["RECURRENCE-ID"][0])[0], all_day)
                    for o in overrides.get(uid, [])]
            for s, e, ad in occurrences(ev, ws, we, skip):
                out.append(to_output(ev, s, e, ad, cal_index))
        except Exception:
            continue  # one malformed event shouldn't hide the rest
    for evs in overrides.values():
        for ev in evs:
            if first(ev, "STATUS").upper() == "CANCELLED":
                continue
            try:
                for s, e, ad in occurrences({k: v for k, v in ev.items() if k != "RRULE"}, ws, we):
                    out.append(to_output(ev, s, e, ad, cal_index))
            except Exception:
                continue
    return out


# --- fetching & caching ------------------------------------------------------------

def is_fresh(path):
    try:
        return time.time() - os.stat(path).st_mtime < MAX_AGE
    except FileNotFoundError:
        return False


def write_private(path, data):
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-calendar"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = resp.read(MAX_FEED_BYTES + 1)
    if len(data) > MAX_FEED_BYTES:
        raise ValueError("feed larger than 20 MB")
    if b"BEGIN:VCALENDAR" not in data[:4096]:
        raise ValueError("not an iCal feed")
    write_private(path, data)


def build(urls):
    os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
    today = dt.datetime.now(LOCAL).replace(hour=0, minute=0, second=0, microsecond=0)
    ws = today - dt.timedelta(days=PAST_DAYS)
    we = today + dt.timedelta(days=FUTURE_DAYS)
    events, calendars, errors = [], [], []

    for idx, url in enumerate(urls):
        label = f"Calendar {idx + 1}"
        # Name the cache after a hash: the URL itself is a secret.
        path = os.path.join(CACHE_DIR, hashlib.sha256(url.encode()).hexdigest()[:16] + ".ics")
        if not is_fresh(path):
            try:
                download(url, path)
            except Exception as e:
                reason = getattr(e, "reason", None) or e
                errors.append(f"{label}: download failed ({reason})")
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                name, feed_events = parse_calendar(f.read())
        except FileNotFoundError:
            calendars.append({"index": idx, "name": label})
            continue
        calendars.append({"index": idx, "name": name or label})
        events.extend(collect(feed_events, idx, ws, we))

    events.sort(key=lambda e: (e["start"], not e["all_day"], e["title"]))
    return {
        "configured": True,
        "config": config_hash(urls),
        "day": today.date().isoformat(),
        "updated": int(time.time()),
        "errors": errors,
        "calendars": calendars,
        "events": events[:MAX_EVENTS],
    }


def save(data):
    os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
    write_private(OUT_FILE, json.dumps(data, ensure_ascii=False).encode())


def refresh_locked(urls):
    os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
    with open(LOCK_FILE, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return  # another refresh is already running
        save(build(urls))


def main():
    urls = read_urls()
    if not urls:
        print(json.dumps({"configured": False, "errors": [], "calendars": [], "events": []}))
        return

    if "--refresh" in sys.argv:
        refresh_locked(urls)
        return

    today = dt.datetime.now(LOCAL).date().isoformat()
    try:
        with open(OUT_FILE, encoding="utf-8") as f:
            cached = json.load(f)
    except (FileNotFoundError, ValueError):
        cached = None

    if cached and cached.get("config") == config_hash(urls) and cached.get("day") == today:
        print(json.dumps(cached, ensure_ascii=False))
        if time.time() - cached.get("updated", 0) > MAX_AGE:
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "--refresh"],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        return

    data = build(urls)
    save(data)
    print(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    main()

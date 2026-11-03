#!/usr/bin/env bash
# Weather for the calendar panel, from Open-Meteo (https://open-meteo.com).
# Free and keyless; hourly data for 16 days in the location's local time.
#
#   weather.sh --json    print the cached forecast and refresh it in the
#                        background when it is older than 15 minutes (fetches
#                        synchronously when there is no usable cache yet)
#   weather.sh --fetch   fetch now and print
#
# Location and units come from calendar/.env (see .env.example):
#   WEATHER_LAT, WEATHER_LON, WEATHER_UNIT=metric|imperial
#
# Output:
#   { updated, location, units: {temp, wind, precip},
#     current: {time, temp, feels, humidity, wind, precip, code, is_day, icon, desc, hex},
#     days: [ {date, max, min, feels_max, pop, precip, wind, uv, humidity,
#              sunrise, sunset, code, icon, desc, hex,
#              hours: [ {time, hour, temp, feels, humidity, pop, precip, wind,
#                        uv, code, is_day, icon, desc, hex} x24 ]} x16 ] }
# or { "error": "..." } when there is nothing to show.

export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/weather"
CACHE_FILE="$CACHE_DIR/forecast.json"
LOCK_FILE="$CACHE_DIR/fetch.lock"
MAX_AGE=900

mkdir -p "$CACHE_DIR"

# Read only the keys used here. .env is parsed, not sourced, so nothing in it
# is ever executed.
WEATHER_LAT=""
WEATHER_LON=""
WEATHER_UNIT="metric"
env_re='^[[:space:]]*(WEATHER_LAT|WEATHER_LON|WEATHER_UNIT)[[:space:]]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$'
if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ $env_re ]] && printf -v "${BASH_REMATCH[1]}" '%s' "${BASH_REMATCH[2]}"
    done < "$ENV_FILE"
fi
LOCATION="$WEATHER_LAT,$WEATHER_LON,$WEATHER_UNIT"

read -r -d '' JQ_PROGRAM <<'JQ'
def r1: if . == null then null else (. * 10 | round) / 10 end;
def rnd: if . == null then null else round end;
def hm: if . == null then null else split("T")[1] end;

# WMO weather code -> [day icon, night icon, description, day colour, night colour]
# Icons are from the Weather Icons set bundled with Nerd Fonts.
def wmo_table: {
  "0":  ["", "", "Clear sky",               "#f9e2af", "#cba6f7"],
  "1":  ["", "", "Mainly clear",            "#f9e2af", "#cba6f7"],
  "2":  ["", "", "Partly cloudy",           "#bac2de", "#bac2de"],
  "3":  ["", "", "Overcast",                "#bac2de", "#bac2de"],
  "45": ["", "", "Fog",                     "#84afdb", "#84afdb"],
  "48": ["", "", "Freezing fog",            "#84afdb", "#84afdb"],
  "51": ["", "", "Light drizzle",           "#74c7ec", "#74c7ec"],
  "53": ["", "", "Drizzle",                 "#74c7ec", "#74c7ec"],
  "55": ["", "", "Heavy drizzle",           "#74c7ec", "#74c7ec"],
  "56": ["", "", "Freezing drizzle",        "#89dceb", "#89dceb"],
  "57": ["", "", "Freezing drizzle",        "#89dceb", "#89dceb"],
  "61": ["", "", "Light rain",              "#74c7ec", "#74c7ec"],
  "63": ["", "", "Rain",                    "#74c7ec", "#74c7ec"],
  "65": ["", "", "Heavy rain",              "#74c7ec", "#74c7ec"],
  "66": ["", "", "Freezing rain",           "#89dceb", "#89dceb"],
  "67": ["", "", "Freezing rain",           "#89dceb", "#89dceb"],
  "71": ["", "", "Light snow",              "#cdd6f4", "#cdd6f4"],
  "73": ["", "", "Snow",                    "#cdd6f4", "#cdd6f4"],
  "75": ["", "", "Heavy snow",              "#cdd6f4", "#cdd6f4"],
  "77": ["", "", "Snow grains",             "#cdd6f4", "#cdd6f4"],
  "80": ["", "", "Light showers",           "#74c7ec", "#74c7ec"],
  "81": ["", "", "Showers",                 "#74c7ec", "#74c7ec"],
  "82": ["", "", "Heavy showers",           "#74c7ec", "#74c7ec"],
  "85": ["", "", "Snow showers",            "#cdd6f4", "#cdd6f4"],
  "86": ["", "", "Heavy snow showers",      "#cdd6f4", "#cdd6f4"],
  "95": ["", "", "Thunderstorm",            "#f9e2af", "#f9e2af"],
  "96": ["", "", "Thunderstorm with hail",  "#f9e2af", "#f9e2af"],
  "99": ["", "", "Thunderstorm with hail",  "#f9e2af", "#f9e2af"]
};
def wmo($code; $is_day):
  (wmo_table[($code // -1) | tostring] // ["", "", "Unknown", "#cdd6f4", "#cdd6f4"]) as $m
  | if $is_day == 0 then {icon: $m[1], desc: $m[2], hex: $m[4]}
    else {icon: $m[0], desc: $m[2], hex: $m[3]} end;

. as $r
| $r.hourly as $h
| [ range(0; $h.time | length) as $i
    | $h.time[$i] as $t
    | { date: ($t | split("T")[0]),
        time: ($t | hm),
        hour: ($t | hm | split(":")[0] | tonumber),
        temp: ($h.temperature_2m[$i] | r1),
        feels: ($h.apparent_temperature[$i] | r1),
        humidity: ($h.relative_humidity_2m[$i] | rnd),
        pop: ($h.precipitation_probability[$i] | rnd),
        precip: ($h.precipitation[$i] | r1),
        wind: ($h.wind_speed_10m[$i] | r1),
        uv: ($h.uv_index[$i] | r1),
        code: $h.weather_code[$i],
        is_day: $h.is_day[$i] }
      + wmo($h.weather_code[$i]; $h.is_day[$i]) ] as $hours
| $r.daily as $d
| { updated: (now | floor),
    location: $loc,
    units: (if $unit == "imperial"
            then {temp: "°F", wind: "mph", precip: "in"}
            else {temp: "°C", wind: "m/s", precip: "mm"} end),
    current: ($r.current
      | { time: (.time | hm),
          temp: (.temperature_2m | r1),
          feels: (.apparent_temperature | r1),
          humidity: (.relative_humidity_2m | rnd),
          wind: (.wind_speed_10m | r1),
          precip: (.precipitation | r1),
          code: .weather_code,
          is_day: .is_day }
        + wmo(.weather_code; .is_day)),
    days: [ range(0; $d.time | length) as $i
      | $d.time[$i] as $date
      | ($hours | map(select(.date == $date) | del(.date))) as $hs
      | { date: $date,
          max: ($d.temperature_2m_max[$i] | r1),
          min: ($d.temperature_2m_min[$i] | r1),
          feels_max: ($d.apparent_temperature_max[$i] | r1),
          pop: ($d.precipitation_probability_max[$i] | rnd),
          precip: ($d.precipitation_sum[$i] | r1),
          wind: ($d.wind_speed_10m_max[$i] | r1),
          uv: ($d.uv_index_max[$i] | r1),
          humidity: ([$hs[].humidity | select(. != null)]
                     | if length > 0 then add / length | round else null end),
          sunrise: ($d.sunrise[$i] | hm),
          sunset: ($d.sunset[$i] | hm),
          code: $d.weather_code[$i] }
        + wmo($d.weather_code[$i]; 1)
        + { hours: $hs } ] }
JQ

emit_error() {
    jq -cn --arg e "$1" '{error: $e}'
}

fetch() {
    local num_re='^-?[0-9]+(\.[0-9]+)?$'
    if [[ ! "$WEATHER_LAT" =~ $num_re || ! "$WEATHER_LON" =~ $num_re ]]; then
        echo "Set WEATHER_LAT and WEATHER_LON in calendar/.env"
        return 1
    fi

    local units="temperature_unit=celsius&wind_speed_unit=ms&precipitation_unit=mm"
    if [ "$WEATHER_UNIT" = "imperial" ]; then
        units="temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
    fi

    local url="https://api.open-meteo.com/v1/forecast?latitude=${WEATHER_LAT}&longitude=${WEATHER_LON}&timezone=auto&forecast_days=16&${units}"
    url+="&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day,precipitation"
    url+="&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,is_day,uv_index"
    url+="&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,uv_index_max,sunrise,sunset"

    local raw tmp
    if ! raw=$(curl -sf --max-time 15 "$url"); then
        echo "Could not reach Open-Meteo"
        return 1
    fi

    # Write to a temp file and rename, so readers never see a partial file.
    tmp=$(mktemp "$CACHE_DIR/forecast.XXXXXX")
    if jq -c --arg loc "$LOCATION" --arg unit "$WEATHER_UNIT" "$JQ_PROGRAM" <<< "$raw" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv -f "$tmp" "$CACHE_FILE"
    else
        rm -f "$tmp"
        echo "Unexpected response from Open-Meteo"
        return 1
    fi
}

cache_usable() {
    [ -s "$CACHE_FILE" ] && [ "$(jq -r '.location // ""' "$CACHE_FILE" 2>/dev/null)" = "$LOCATION" ]
}

case "${1:---json}" in
    --fetch)
        if err=$(fetch); then cat "$CACHE_FILE"; else emit_error "$err"; fi
        ;;
    --json)
        if cache_usable; then
            age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
            if [ "$age" -gt "$MAX_AGE" ]; then
                # Background refresh: stdout/stderr are detached so the caller
                # isn't kept waiting, and flock stops overlapping fetches.
                ( flock -n 9 || exit 0; fetch ) 9>"$LOCK_FILE" >/dev/null 2>&1 &
            fi
            cat "$CACHE_FILE"
        elif err=$(fetch); then
            cat "$CACHE_FILE"
        else
            emit_error "$err"
        fi
        ;;
    *)
        echo "usage: $0 [--json|--fetch]" >&2
        exit 2
        ;;
esac

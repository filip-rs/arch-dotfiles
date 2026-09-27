#!/usr/bin/env bash
# Emit `mullvad relay list` as JSON for MullvadPopup.qml.
#
# The CLI prints a tab-indented tree that is tedious to parse in QML:
#
#   Albania (al)
#   \tTirana (tia) @ 41.32795°N, 19.81902°W
#   \t\tal-tia-wg-001 (103.124.165.2, ...) - hosted by iRegister (rented)
#
# Only countries and cities are kept -- the panel selects at city granularity,
# and carrying ~700 hostnames into QML just to drop them is wasteful. `servers`
# is the per-city hostname count, which the list shows as a density hint.
#
# Output: [{"name","code","servers",cities:[{"name","code","countryCode","servers"}]}]

set -uo pipefail

mullvad relay list 2>/dev/null | awk '
    BEGIN { print "["; first_country = 1 }

    # Depth is the leading-tab count: 0 country, 1 city, 2 server.
    {
        line = $0
        depth = 0
        while (substr(line, 1, 1) == "\t") { depth++; line = substr(line, 2) }
    }

    /^[[:space:]]*$/ { next }

    depth == 0 {
        # "Albania (al)"  -- a country name may itself contain spaces.
        if (match(line, /^(.*) \(([a-z]{2})\)$/, m)) {
            close_city(); close_country()
            if (!first_country) printf ",\n"
            first_country = 0
            cur_cc = m[2]
            printf "  {\"name\":%s,\"code\":\"%s\",\"cities\":[", jstr(m[1]), m[2]
            in_country = 1; first_city = 1
        }
        next
    }

    depth == 1 {
        # "Tirana (tia) @ 41.32795°N, 19.81902°W" -- coords are unused.
        if (match(line, /^(.*) \(([a-z]{3})\)/, m)) {
            close_city()
            if (!first_city) printf ","
            first_city = 0
            city_name = m[1]; city_code = m[2]; city_servers = 0
            in_city = 1
        }
        next
    }

    depth >= 2 { if (in_city) city_servers++; next }

    END { close_city(); close_country(); print "\n]" }

    function jstr(s) {
        gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
        return "\"" s "\""
    }
    function close_city() {
        if (in_city) {
            printf "{\"name\":%s,\"code\":\"%s\",\"countryCode\":\"%s\",\"servers\":%d}", jstr(city_name), city_code, cur_cc, city_servers
            country_servers += city_servers
            in_city = 0
        }
    }
    function close_country() {
        if (in_country) { printf "],\"servers\":%d}", country_servers; country_servers = 0; in_country = 0 }
    }
'

#!/usr/bin/env bash
# Waybar weather module. Reads the calendar panel's cached Open-Meteo forecast:
# quickshell/calendar/weather.sh prints the cache and refreshes it in the
# background once it is older than 15 minutes, so this costs no network
# request of its own. Prints nothing (which hides the module) until a location
# is set in quickshell/calendar/.env.

json=$("$HOME/.config/quickshell/calendar/weather.sh" --json 2>/dev/null) || exit 0

jq -c '
  if .error or (.current == null) then empty else
    .units.temp as $u
    | def day($label): "\($label): \(.desc), \(.min | round)–\(.max | round)\($u), rain \(.pop)%";
    {
      text: "\(.current.icon) \(.current.temp | round)°",
      tooltip: (
        "<b>\(.current.desc) \(.current.temp | round)\($u)</b>\n"
        + "Feels like \(.current.feels | round)\($u)\n"
        + "Humidity \(.current.humidity)%\n"
        + "Wind \(.current.wind) \(.units.wind)\n\n"
        + ([.days[0] | day("Today")] + [.days[1] | day("Tomorrow")] | join("\n"))
      )
    }
  end' <<< "$json" 2>/dev/null

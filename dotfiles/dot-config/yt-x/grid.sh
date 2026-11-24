# yt-x grid behaviour for the rofi launcher. Sourced from ./config.
#
# yt-x sources its config after it has defined all of its own functions, so
# the functions below replace yt-x's. Copying the stock action menu uses
# `declare -f`, which works because /bin/sh is bash on Arch.
#
#  - Left click (or Enter) on a video plays it straight away.
#  - Right click (or Alt+Enter) opens yt-x's own action menu for that video
#    (Save, Download, Go To Channel, Open in Browser, ...) with its details and
#    description shown above the options. Back/Escape returns to the grid.
#    The keys are kb-custom-1 in rofi/preview.rasi; rofi exits with 10 for it.
#  - Titles get two lines in the grid.

# Keep yt-x's own action menu under another name before replacing it below.
if __ytx_def=$(declare -f _menu_media_actions 2>/dev/null) && [ -n "$__ytx_def" ]; then
  eval "$(printf '%s\n' "$__ytx_def" | sed '1s/^_menu_media_actions /__ytx_stock_menu_media_actions /')"
fi
unset __ytx_def

# Set by the grid when the details key picked the video, consumed right after.
__ytx_details_flag="${XDG_RUNTIME_DIR:-/tmp}/yt-x-details.$$"

# Grid launcher (replaces yt-x's). rofi doesn't wrap text, so the last space
# within the first 24 characters of each title becomes a newline and entries
# are separated by \036 (rofi -sep) so the newline stays inside its entry;
# "eh: 2" in rofi/preview.rasi gives every tile two text lines. On the way back
# the newline turns into a space again, so yt-x gets the exact original title
# (it matches saved videos by title). Multi-select keeps yt-x's own behaviour.
__ui_rofi_launcher_with_preview() {
  ! [ -s "$CONFIG_ROFI_THEME_PREVIEW" ] && ui_notify_critical "$TXT_ROFI_NOT_CONFIGURED: where CONFIG_ROFI_THEME_PREVIEW=\"$CONFIG_ROFI_THEME_PREVIEW\""
  if [ "$2" = "multi" ]; then
    sed -E "s/$THEME_ESC(\[[0-9;]*[a-zA-Z]|\(B)//g" |
      rofi -no-config -theme "$CONFIG_ROFI_THEME_PREVIEW" -dmenu -i -multi-select -p "$1"
    return
  fi
  local selection rc
  rm -f "$__ytx_details_flag"
  selection=$(
    sed -E "s/$THEME_ESC(\[[0-9;]*[a-zA-Z]|\(B)//g" |
      perl -CSD -ne 'chomp; my ($t, $m) = split /\0/, $_, 2;
        if (length($t) > 24) { my $c = rindex(substr($t, 0, 25), " "); substr($t, $c, 1) = "\n" if $c > 0 }
        print "\036" if $. > 1; print $t, defined $m ? "\0$m" : ""' |
      rofi -no-config -theme "$CONFIG_ROFI_THEME_PREVIEW" -dmenu -i -sep "$(printf '\036')" -p "$1"
  )
  rc=$?
  [ "$rc" -eq 10 ] && : >"$__ytx_details_flag"
  printf '%s' "$selection" | tr '\n' ' ' | sed 's/ $//'
}

# Pango markup for the details box: title, channel and length, then the
# description (fetched now; feed entries don't include it), trimmed to 14
# lines / 900 characters so the menu still fits on screen.
__ytx_video_details() {
  local desc
  # shellcheck disable=SC2086
  desc=$(yt-dlp $CONFIG_YT_DLP_OPTS --no-warnings --skip-download --print description "$STATE_CURRENT_VIDEO_URL" 2>/dev/null)
  {
    printf '%s\n' "$STATE_CURRENT_VIDEO_TITLE"
    printf '%s' "$STATE_CURRENT_VIDEO" | jq -r '
      [ .channel // empty,
        (.duration // empty | floor | "\(. / 3600 | floor | if . > 0 then "\(.):" else "" end)\(. % 3600 / 60 | floor | tostring | if length < 2 then "0" + . else . end):\(. % 60 | tostring | if length < 2 then "0" + . else . end)")
      ] | join("  ·  ")'
    printf '%s' "$desc"
  } | perl -CSD -0777 -ne '
    my ($title, $info, @rest) = split /\n/, $_, -1;
    my $d = join "\n", @rest; $d =~ s/\n{3,}/\n\n/g; $d =~ s/\s+$//;
    my @l = split /\n/, $d; my $more = @l > 14; @l = @l[0..13] if $more;
    $d = join "\n", @l; if (length $d > 900) { $d = substr($d, 0, 900); $more = 1 }
    for ($title, $info, $d) { s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g }
    print "<b>$title</b>\n<i>$info</i>";
    print "\n\n$d", ($more ? " \x{2026}" : "") if length $d;'
}

# Picking a video: play it, unless the details key was used, in which case
# open yt-x's own action menu with the details box. The state pop mirrors what
# that menu's "Back" does (every caller pushes state before opening it).
_menu_media_actions() {
  if [ -e "$__ytx_details_flag" ] && command -v __ytx_stock_menu_media_actions >/dev/null; then
    rm -f "$__ytx_details_flag"
    YTX_MENU_MESG=$(__ytx_video_details)
    __ytx_stock_menu_media_actions "$@"
    YTX_MENU_MESG=""
  else
    __menu_media_actions_watch
    _state_pop
  fi
}

# yt-x's plain rofi menu (replaces yt-x's), plus the details box (-mesg) on the
# action menu while it is open from the details key. Only that menu's prompt
# gets it, not menus opened from it (e.g. Go To Channel).
__ui_rofi_launcher() {
  ! [ -s "$CONFIG_ROFI_THEME_MAIN" ] && ui_notify_critical "$TXT_ROFI_NOT_CONFIGURED: where CONFIG_ROFI_THEME_MAIN=\"$CONFIG_ROFI_THEME_MAIN\""
  local selection custom_opts
  [ "$2" = "multi" ] && custom_opts="-multi-select"
  if [ -n "$YTX_MENU_MESG" ] && [ "$1" = "$TXT_MENU_PLAYLIST_PROMPT_ACTION" ]; then
    # shellcheck disable=SC2086
    selection=$(
      sed -E "s/$THEME_ESC(\[[0-9;]*[a-zA-Z]|\(B)//g" |
        rofi -no-config -theme "$CONFIG_ROFI_THEME_MAIN" -dmenu -i $custom_opts -p "$1" -mesg "$YTX_MENU_MESG"
    )
  else
    # shellcheck disable=SC2086
    selection=$(
      sed -E "s/$THEME_ESC(\[[0-9;]*[a-zA-Z]|\(B)//g" |
        rofi -no-config -theme "$CONFIG_ROFI_THEME_MAIN" -dmenu -i $custom_opts -p "$1"
    )
  fi
  printf '%s' "$selection"
}

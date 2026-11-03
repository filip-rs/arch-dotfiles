import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"

// Calendar panel: month grid (left), clock + 3-hourly orbit (centre), weather
// for the selected day (right) and a 24-hour timeline with the day's
// temperature, rain chance and events (bottom).
//
// Data comes from two scripts next to this file:
//   weather.sh --json  Open-Meteo forecast, 16 days x 24 hours (local time)
//   events.py          events from the iCal feeds in calendar/.env
// Both print a cached copy straight away and refresh it in the background.
Item {
    id: window

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        // Uses the physical screen width so the popup scales synchronously
        currentWidth: Screen.width
    }

    // Helper function scoped to the root Item for easy access
    function s(val) {
        return scaler.s(val);
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // (Escape is handled by Main.qml)
    // -------------------------------------------------------------------------
    Shortcut { sequence: "Left";  onActivated: window.selectDate(window.addDays(window.selectedDate, -1)) }
    Shortcut { sequence: "Right"; onActivated: window.selectDate(window.addDays(window.selectedDate, 1)) }
    Shortcut { sequence: "Up";    onActivated: window.selectDate(window.addDays(window.selectedDate, -7)) }
    Shortcut { sequence: "Down";  onActivated: window.selectDate(window.addDays(window.selectedDate, 7)) }
    Shortcut { sequence: "Home";  onActivated: window.goToday() }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext1: _theme.subtext1
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay2: _theme.overlay2
    readonly property color overlay1: _theme.overlay1
    readonly property color overlay0: _theme.overlay0
    readonly property color surface2: _theme.surface2
    readonly property color surface1: _theme.surface1
    readonly property color surface0: _theme.surface0

    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color teal: _theme.teal
    readonly property color green: _theme.green
    readonly property color red: _theme.red

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/calendar"

    // One colour per calendar feed, in the order they are listed in .env.
    function calColor(i) {
        let c = [window.mauve, window.sapphire, window.peach, window.green,
                 window.pink, window.teal, window.yellow, window.blue];
        return c[(i || 0) % c.length];
    }

    // -------------------------------------------------------------------------
    // TIME OF DAY DYNAMIC COLORS
    // -------------------------------------------------------------------------
    readonly property color timeColor: {
        let h = window.currentHour;
        if (h >= 5 && h < 12) return window.peach;      // Morning
        if (h >= 12 && h < 17) return window.sapphire;  // Afternoon
        if (h >= 17 && h < 21) return window.mauve;     // Evening
        return window.blue;                             // Night
    }

    readonly property color timeAccent: {
        let h = window.currentHour;
        if (h >= 5 && h < 12) return window.yellow;     // Morning Accent
        if (h >= 12 && h < 17) return window.teal;      // Afternoon Accent
        if (h >= 17 && h < 21) return window.pink;      // Evening Accent
        return window.mauve;                            // Night Accent
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    // -------------------------------------------------------------------------
    // STARTUP ANIMATION STATES
    // -------------------------------------------------------------------------
    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0
    property real introTimeline: 0

    SequentialAnimation {
        running: true

        // Short buffer to allow the window manager to map the surface before animating
        PauseAnimation { duration: 20 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 350 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 400 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 500 }
                NumberAnimation { target: window; property: "introTimeline"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutExpo }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // -------------------------------------------------------------------------
    // STATE & TIME (WITH SECOND PULSE)
    // -------------------------------------------------------------------------
    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000
    // Integer views of the clock: they only notify when they actually change,
    // so bindings on them don't re-run every second.
    readonly property int currentHour: currentTime.getHours()
    readonly property int nowMinutes: currentTime.getHours() * 60 + currentTime.getMinutes()
    readonly property string todayKey: dateKey(currentTime)

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            window.currentTime = new Date();
            window.secondPulse = 1.06; // Gentle pulse
            pulseReset.start();
        }
    }

    // Day rollover (midnight, or waking from suspend on a later day): keep
    // following "today" if it was the selected day.
    property string lastTodayKey: ""
    onTodayKeyChanged: {
        if (window.lastTodayKey !== "" && window.selectedDate === window.lastTodayKey) {
            window.selectedDate = window.todayKey;
            window.viewDate = window.todayKey;
        }
        window.lastTodayKey = window.todayKey;
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // DATE HELPERS (dates are "YYYY-MM-DD" keys, local time)
    // -------------------------------------------------------------------------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function dateKey(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
    function parseKey(k) {
        let p = (k || "").split("-");
        return p.length === 3 ? new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2])) : new Date();
    }
    function addDays(k, n) {
        let d = parseKey(k);
        return dateKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() + n));
    }
    function monthOffsetOf(k) {
        let d = parseKey(k);
        return (d.getFullYear() - window.currentTime.getFullYear()) * 12 + (d.getMonth() - window.currentTime.getMonth());
    }
    // "2026-11-03T14:30" -> 870
    function minutesOf(iso) { return parseInt(iso.substring(11, 13)) * 60 + parseInt(iso.substring(14, 16)); }

    function dayTitle(k) {
        if (k === window.todayKey) return "TODAY";
        if (k === addDays(window.todayKey, 1)) return "TOMORROW";
        if (k === addDays(window.todayKey, -1)) return "YESTERDAY";
        return Qt.formatDate(parseKey(k), "dddd").toUpperCase();
    }

    // -------------------------------------------------------------------------
    // DAY SELECTION
    // selectedDate changes immediately on click; viewDate follows it halfway
    // through the transition, while the weather content is faded out.
    // -------------------------------------------------------------------------
    property string selectedDate: ""
    property string viewDate: ""
    readonly property bool viewIsToday: viewDate === todayKey

    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1
    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: window.s(-40) * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }

            // Spin the 3D orbit out and scale it down for depth
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                window.viewDate = window.selectedDate;
                window.weatherContentOffset = window.s(40) * weatherAnimDirection; // Move to opposite side while hidden

                // Reset the spin to the opposite side so it continues spinning into place seamlessly
                window.transitionSpin = -180 * weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function selectDate(key) {
        if (!key) return;
        // Show the month the day is in.
        let off = monthOffsetOf(key);
        if (off !== window.targetMonthOffset) window.setMonthOffset(off);

        if (key === window.selectedDate) return;

        // Interrupt a running transition, applying its switch first so the
        // data doesn't get desynced.
        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.viewDate = window.selectedDate;
        }

        window.weatherAnimDirection = key > window.viewDate ? 1 : -1;
        window.selectedDate = key;
        weatherTransitionAnim.start();
    }

    function goToday() {
        window.selectDate(window.todayKey);
        window.setMonthOffset(0);
    }

    // -------------------------------------------------------------------------
    // WEATHER DATA
    // -------------------------------------------------------------------------
    property var weatherData: null
    property var forecastByDate: ({})
    property bool weatherRechecked: false

    onWeatherDataChanged: {
        let m = {};
        let days = window.weatherData && window.weatherData.days ? window.weatherData.days : [];
        for (let i = 0; i < days.length; i++) m[days[i].date] = days[i];
        window.forecastByDate = m;
    }

    readonly property var units: weatherData && weatherData.units ? weatherData.units : ({ temp: "°C", wind: "m/s", precip: "mm" })
    // Current conditions are only trusted for an hour; after that (e.g. the
    // panel opened on a cache from before a suspend) the hourly slot is used.
    readonly property bool weatherFresh: !!(weatherData && weatherData.updated && (currentEpoch - weatherData.updated) < 3600)

    function forecastFor(k) { return window.forecastByDate[k] || null; }

    function hourOf(day, h) {
        if (!day || !day.hours) return null;
        for (let i = 0; i < day.hours.length; i++) if (day.hours[i].hour === h) return day.hours[i];
        return null;
    }

    // "Right now" conditions for a date: only for today, else null.
    function nowFor(k) {
        if (k !== window.todayKey) return null;
        if (window.weatherFresh && window.weatherData.current) return window.weatherData.current;
        return hourOf(forecastFor(k), window.currentHour);
    }

    readonly property var viewDay: forecastFor(viewDate)
    readonly property var viewNow: nowFor(viewDate)
    readonly property var selDay: forecastFor(selectedDate)
    readonly property var selNow: nowFor(selectedDate)
    readonly property bool selHasWeather: !!(selNow || selDay)

    readonly property string viewIcon: viewNow ? viewNow.icon : (viewDay ? viewDay.icon : "")
    readonly property color activeWeatherHex: viewNow ? viewNow.hex : (viewDay ? viewDay.hex : window.mauve)

    readonly property string viewDesc: {
        if (viewNow) return viewNow.desc;
        if (viewDay) return viewDay.desc;
        if (!weatherData) return "Loading weather...";
        if (weatherData.error) return weatherData.error;
        return "No forecast for this day";
    }

    // 3-hourly slots of the viewed day for the orbit (00:00, 03:00, ...).
    readonly property var orbitSlots: {
        let d = forecastFor(viewDate);
        if (!d || !d.hours) return [];
        let out = [];
        for (let i = 0; i < d.hours.length; i++) if (d.hours[i].hour % 3 === 0) out.push(d.hours[i]);
        return out;
    }
    readonly property int activeHourIndex: (viewIsToday && orbitSlots.length > 0)
        ? Math.min(orbitSlots.length - 1, Math.round(currentHour / 3)) : -1

    // -------------------------------------------------------------------------
    // TEMPERATURE LOGIC
    // -------------------------------------------------------------------------
    property real targetTemp: (selNow && selNow.temp !== null) ? selNow.temp : (selDay && selDay.max !== null ? selDay.max : 0)
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;   // counting up
        if (window.targetTemp < window.displayedTemp) return window.blue;  // counting down
        return window.text;
    }

    Process {
        id: weatherPoller
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    window.weatherData = JSON.parse(txt);
                } catch (e) {
                    console.warn("CalendarPopup: bad weather JSON:", e, txt.substring(0, 200));
                    return;
                }
                // weather.sh refreshes a stale cache in the background; pick
                // the new data up shortly instead of on the next poll.
                if (!window.weatherRechecked && window.weatherData.updated
                        && Date.now() / 1000 - window.weatherData.updated > 900) {
                    window.weatherRechecked = true;
                    weatherRecheck.start();
                }
            }
        }
    }
    Timer { id: weatherRecheck; interval: 4000; onTriggered: weatherPoller.running = true }
    Timer {
        interval: 150000
        running: true; repeat: true
        onTriggered: weatherPoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR EVENTS
    // -------------------------------------------------------------------------
    property var eventsData: null
    property var eventsByDate: ({})
    property bool eventsRechecked: false

    onEventsDataChanged: {
        let m = {};
        let evs = window.eventsData && window.eventsData.events ? window.eventsData.events : [];
        for (let i = 0; i < evs.length; i++) {
            let e = evs[i];
            let k = e.start_date;
            // Multi-day events appear on every day they cover (capped).
            for (let guard = 0; k <= e.end_date && guard < 62; guard++) {
                if (!m[k]) m[k] = [];
                m[k].push(e);
                k = addDays(k, 1);
            }
        }
        window.eventsByDate = m;
    }

    function eventsOn(k) { return window.eventsByDate[k] || []; }

    readonly property var viewEvents: eventsOn(viewDate)
    readonly property var viewAllDay: viewEvents.filter(e => e.all_day)

    // Timed events of the viewed day as {ev, s, e, lane}, with s/e in minutes
    // clipped to the day, packed into two lanes.
    readonly property var viewTimed: {
        let list = [];
        let evs = window.viewEvents;
        for (let i = 0; i < evs.length; i++) {
            let e = evs[i];
            if (e.all_day) continue;
            let st = e.start_date < window.viewDate ? 0 : window.minutesOf(e.start);
            let en = e.end.substring(0, 10) > window.viewDate ? 1440 : window.minutesOf(e.end);
            if (en <= st) en = Math.min(1440, st + 15);
            list.push({ ev: e, s: st, e: en, lane: 0 });
        }
        list.sort((a, b) => a.s - b.s);
        let laneEnd = [];
        for (let i = 0; i < list.length; i++) {
            let lane = 0;
            while (lane < laneEnd.length && laneEnd[lane] > list[i].s) lane++;
            if (lane > 1) lane = 1; // further overlaps stack in the second lane
            laneEnd[lane] = Math.max(laneEnd[lane] || 0, list[i].e);
            list[i].lane = lane;
        }
        return list;
    }

    readonly property string eventsSummary: {
        if (!eventsData) return "";
        if (!eventsData.configured) return "No calendar connected · set CALENDAR_ICS_URLS in calendar/.env";
        let n = viewEvents.length;
        let txt = n === 0 ? "No events" : (n === 1 ? "1 event" : n + " events");
        if (eventsData.errors && eventsData.errors.length > 0) txt += "  ·  " + eventsData.errors[0];
        return txt;
    }

    Process {
        id: eventsPoller
        command: ["python3", window.scriptsDir + "/events.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    window.eventsData = JSON.parse(txt);
                } catch (e) {
                    console.warn("CalendarPopup: bad events JSON:", e, txt.substring(0, 200));
                    return;
                }
                if (!window.eventsRechecked && window.eventsData.updated
                        && Date.now() / 1000 - window.eventsData.updated > 900) {
                    window.eventsRechecked = true;
                    eventsRecheck.start();
                }
            }
        }
    }
    Timer { id: eventsRecheck; interval: 5000; onTriggered: eventsPoller.running = true }
    Timer {
        interval: 300000
        running: true; repeat: true
        onTriggered: eventsPoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR GRID LOGIC & TRANSITIONS
    // -------------------------------------------------------------------------
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: window.s(-20) * calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let first = new Date(window.currentTime.getFullYear(), window.currentTime.getMonth() + window.monthOffset, 1);
        let month = first.getMonth();
        window.targetMonthName = Qt.formatDateTime(first, "MMMM yyyy");

        // Weeks start on Monday; always 6 rows.
        let lead = (first.getDay() + 6) % 7;
        calendarModel.clear();
        for (let i = 0; i < 42; i++) {
            let d = new Date(first.getFullYear(), month, 1 - lead + i);
            let key = dateKey(d);
            calendarModel.append({
                dayNum: d.getDate().toString(),
                dateKey: key,
                isCurrentMonth: d.getMonth() === month,
                isToday: key === window.todayKey
            });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        window.lastTodayKey = window.todayKey;
        window.selectedDate = window.todayKey;
        window.viewDate = window.todayKey;
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            // =======================================================
            // AMBIENT WIDGET COLOR BLOBS (Spread Out)
            // =======================================================
            Rectangle {
                width: window.s(parent.width * 0.5); height: width; radius: width / 2
                x: (parent.width * 0.75 - width / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(350)
                y: (parent.height * 0.3 - height / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(200)
                opacity: 0.025 * window.introAmbient
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: window.s(parent.width * 0.6); height: width; radius: width / 2
                x: (parent.width * 0.25 - width / 2) + Math.sin(window.globalOrbitAngle * 1.2) * window.s(-300)
                y: (parent.height * 0.7 - height / 2) + Math.cos(window.globalOrbitAngle * 1.2) * window.s(-250)
                opacity: 0.02 * window.introAmbient
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Rectangle {
                width: window.s(parent.width * 0.45); height: width; radius: width / 2
                x: (parent.width * 0.5 - width / 2) + Math.cos(window.globalOrbitAngle * -1.8) * window.s(400)
                y: (parent.height * 0.5 - height / 2) + Math.sin(window.globalOrbitAngle * -1.8) * window.s(-350)
                opacity: 0.015 * window.introAmbient
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // Big Parallax Weather Icon (Tied to Weather Transition)
            Text {
                id: bigWeatherIcon
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.s(-100)
                text: window.viewIcon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window.s(800)
                color: window.activeWeatherHex
                opacity: (0.03 + (0.01 * Math.sin(window.globalOrbitAngle * 4))) * window.introAmbient * window.weatherContentOpacity
                z: 0
                Behavior on color { ColorAnimation { duration: 1500 } }

                property real drift: 0
                SequentialAnimation on drift {
                    loops: Animation.Infinite
                    NumberAnimation { to: window.s(-20); duration: 6000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                }

                transform: [
                    Translate { y: bigWeatherIcon.drift },
                    Translate { x: window.weatherContentOffset * 2 } // Exaggerated shift for background depth
                ]
            }

            // =======================================================
            // CENTRAL HERO: THE BREATHING TIME HUB & 3D HOURLY ORBIT
            // =======================================================
            Item {
                id: centralHub
                anchors.centerIn: parent
                anchors.verticalCenterOffset: window.s(-100)
                width: window.s(1); height: window.s(1)
                z: 5

                opacity: introClock
                scale: 0.85 + (0.15 * introClock)

                property real levitation: 0
                SequentialAnimation on levitation {
                    loops: Animation.Infinite
                    NumberAnimation { to: window.s(-15); duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 4000; easing.type: Easing.InOutSine }
                }

                property real orbitBreath: 1.0
                SequentialAnimation on orbitBreath {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 1.035; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 3500; easing.type: Easing.InOutSine }
                }

                // 3D Perspective Wobble (Pitch, Yaw, Roll)
                property real pitchBreath: 0
                SequentialAnimation on pitchBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 3.5; duration: 4200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -3.5; duration: 4200; easing.type: Easing.InOutSine }
                }

                property real yawBreath: 0
                SequentialAnimation on yawBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 2.5; duration: 5100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -2.5; duration: 5100; easing.type: Easing.InOutSine }
                }

                property real rollBreath: 0
                SequentialAnimation on rollBreath {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { to: 1.5; duration: 5800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1.5; duration: 5800; easing.type: Easing.InOutSine }
                }

                transform: [
                    Translate { y: window.s(25) * (1.0 - introClock) },
                    Translate { y: centralHub.levitation },
                    Rotation { axis { x: 1; y: 0; z: 0 } angle: centralHub.pitchBreath },
                    Rotation { axis { x: 0; y: 1; z: 0 } angle: centralHub.yawBreath },
                    Rotation { axis { x: 0; y: 0; z: 1 } angle: centralHub.rollBreath }
                ]

                // Drawn once and scaled on the GPU, rather than repainted every frame.
                Canvas {
                    id: orbitCanvas
                    z: -10
                    x: window.s(-400)   // Widened to prevent clipping when scaled
                    y: window.s(-200)   // Heightened to prevent clipping when scaled
                    width: window.s(800)
                    height: window.s(400)
                    opacity: 0.25

                    scale: centralHub.orbitBreath

                    property color lineColor: window.textAccent
                    onLineColorChanged: requestPaint()
                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        var currentRx = window.s(320);
                        var currentRy = window.s(140);
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * currentRx;
                            var yy = height/2 + Math.sin(i) * currentRy;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = lineColor;
                        ctx.lineWidth = window.s(1.5);
                        ctx.setLineDash([window.s(4), window.s(10)]);
                        ctx.stroke();
                    }
                }

                // Core Clock
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0
                    scale: 0.95 + (0.05 * window.secondPulse)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: window.s(2)
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(84)
                            color: window.text
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: window.s(32)
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: window.s(15)
                            opacity: window.secondPulse > 1.02 ? 1.0 : 0.6
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: window.s(16)
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                // 3D orbit of the viewed day's 3-hourly forecast. Today rotates
                // the current slot to the front; other days slowly circle.
                Item {
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity
                    scale: window.transitionScale
                    transform: Translate { x: window.weatherContentOffset * 1.5 }

                    Repeater {
                        id: hourRepeater
                        model: window.orbitSlots

                        delegate: Item {
                            property int mCount: hourRepeater.count
                            property bool isToday: window.viewIsToday
                            property bool isHighlighted: isToday && index === window.activeHourIndex

                            property real rx: window.s(320) * centralHub.orbitBreath
                            property real ry: window.s(140) * centralHub.orbitBreath

                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            property real targetAngleDeg: isToday ? (65 + (relIdx * 30)) : (index * (360 / Math.max(1, mCount)))
                            property real orbitOffset: isToday ? 0 : (window.globalOrbitAngle * (180 / Math.PI) * -1.5)
                            property real osc: isToday ? (Math.sin(window.globalOrbitAngle * 10 + index) * 5) : 0
                            property real rad: (targetAngleDeg + orbitOffset + osc + window.transitionSpin) * (Math.PI / 180)

                            x: Math.cos(rad) * rx - width/2
                            y: Math.sin(rad) * ry - height/2
                            z: Math.sin(rad) * window.s(100)

                            scale: isHighlighted ? 1.4 : (isToday ? (0.95 + 0.20 * Math.sin(rad)) : (0.90 + 0.25 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: window.s(56); height: window.s(95)

                            Rectangle {
                                anchors.fill: parent
                                radius: window.s(28)
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? window.surface2 : window.surface0)
                                border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.textAccent : window.surface1)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 200 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: window.s(4)

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time
                                        font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(12)
                                        color: isHighlighted ? window.base : (hrMa.containsMouse ? window.text : window.overlay1)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || ""
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                        color: isHighlighted ? window.base : (modelData.hex || window.text)
                                        transform: Translate { y: hrMa.containsMouse ? window.s(-3) : 0 }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.temp !== null ? Math.round(modelData.temp) + "°" : "--"
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(14)
                                        color: isHighlighted ? window.base : window.text
                                    }
                                }
                            }
                            MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }

            // =======================================================
            // LEFT WING: FLOATING GLASS CALENDAR
            // =======================================================
            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: window.s(40)
                width: window.s(320)
                height: window.s(420)
                color: Qt.alpha(window.surface0, 0.2)
                radius: window.s(14)
                border.color: Qt.alpha(window.surface1, 0.4)
                border.width: 1
                z: 10

                opacity: introCalendar
                transform: Translate { x: window.s(-40) * (1.0 - introCalendar) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(25)
                    spacing: window.s(15)

                    RowLayout {
                        Layout.fillWidth: true

                        // Mirrors the "Return to Today" button on the right so
                        // the month title stays centred.
                        Item { width: window.s(32); height: window.s(32) }

                        Rectangle {
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: prevMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: "\uF104"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.setMonthOffset(window.targetMonthOffset - 1) }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(16)
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter

                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        Rectangle {
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: nextMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: "\uF105"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.setMonthOffset(window.targetMonthOffset + 1) }
                        }

                        // "Return to Today" button (also: Home key). Always takes
                        // its space so nothing shifts when it fades in.
                        Rectangle {
                            property bool active: window.targetMonthOffset !== 0 || window.selectedDate !== window.todayKey
                            width: window.s(32); height: window.s(32); radius: window.s(16)
                            color: homeMa.containsMouse ? window.surface1 : "transparent"
                            opacity: active ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: "\u{F00ED}"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: window.s(16) }
                            MouseArea {
                                id: homeMa; anchors.fill: parent
                                enabled: parent.active; hoverEnabled: parent.active
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.goToday()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: window.s(14)
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(6)
                        columnSpacing: window.s(6)

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel

                            // Each day: number, plus the day's weather icon and
                            // up to three event dots when there are any.
                            Rectangle {
                                id: dayCell
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property string key: model.dateKey
                                property bool today: model.isToday
                                property bool inMonth: model.isCurrentMonth
                                property bool selected: key === window.selectedDate
                                property var fc: window.forecastFor(key)
                                property var evs: window.eventsOn(key)
                                property bool hasExtras: !!fc || evs.length > 0

                                color: today ? window.textAccent
                                     : selected ? Qt.alpha(window.textAccent, 0.16)
                                     : (dayMa.containsMouse ? Qt.alpha(window.surface2, 0.4) : "transparent")
                                radius: window.s(10)
                                scale: dayMa.containsMouse ? 1.12 : 1.0
                                border.color: selected ? window.textAccent : (today ? window.surface0 : (dayMa.containsMouse ? window.overlay0 : "transparent"))
                                border.width: selected ? window.s(2) : ((today || dayMa.containsMouse) ? 1 : 0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: dayCell.hasExtras ? -parent.height * 0.14 : 0
                                    text: model.dayNum
                                    font.family: "JetBrains Mono"
                                    font.weight: (dayCell.today || dayCell.selected) ? Font.Black : Font.Bold
                                    font.pixelSize: window.s(14)
                                    color: dayCell.today ? window.base : (dayCell.inMonth ? window.text : window.surface2)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: parent.height * 0.1
                                    spacing: window.s(3)
                                    visible: dayCell.hasExtras
                                    opacity: dayCell.inMonth ? 1.0 : 0.45

                                    Text {
                                        visible: !!dayCell.fc
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: dayCell.fc ? dayCell.fc.icon : ""
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(10)
                                        color: dayCell.today ? window.base : (dayCell.fc ? dayCell.fc.hex : window.text)
                                    }

                                    Repeater {
                                        model: Math.min(3, dayCell.evs.length)
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: window.s(4); height: width; radius: width / 2
                                            color: dayCell.today ? window.base : window.calColor(dayCell.evs[index].calendar)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.selectDate(dayCell.key)
                                }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // RIGHT WING: WEATHER FOR THE SELECTED DAY
            // =======================================================
            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.s(40)
                width: window.s(320)
                height: window.s(420)
                z: 10

                opacity: introWeather
                transform: Translate { x: window.s(40) * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: window.s(14)

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: window.s(14)

                        MouseArea {
                            id: wPrevMa; width: window.s(30); height: window.s(30); hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.selectDate(window.addDays(window.selectedDate, -1))

                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: window.s(-3); duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent; text: "\uF053"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                color: parent.containsMouse ? window.textAccent : window.overlay1
                                transform: Translate { x: wPrevMa.containsMouse ? window.s(-5) : wPrevMa.pulseOffset }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: window.s(150)
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: window.selectedDate !== "" ? window.dayTitle(window.selectedDate) : ""
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: window.s(16)
                                color: window.text
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: window.selectedDate !== "" ? Qt.formatDate(window.parseKey(window.selectedDate), "d MMMM").toUpperCase() : ""
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(11)
                                color: window.overlay1
                            }
                        }

                        MouseArea {
                            id: wNextMa; width: window.s(30); height: window.s(30); hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.selectDate(window.addDays(window.selectedDate, 1))

                            property real pulseOffset: 0
                            SequentialAnimation on pulseOffset {
                                loops: Animation.Infinite; running: true
                                NumberAnimation { to: window.s(3); duration: 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1000; easing.type: Easing.InOutSine }
                            }

                            Text {
                                anchors.centerIn: parent; text: "\uF054"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                color: parent.containsMouse ? window.textAccent : window.overlay1
                                transform: Translate { x: wNextMa.containsMouse ? window.s(5) : wNextMa.pulseOffset }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: window.s(260)
                        spacing: window.s(-5)

                        // Big temperature: right now for today, the day's high otherwise.
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.selHasWeather ? Math.round(window.displayedTemp) + "°" : "--°"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: window.s(84)
                            color: window.tempGlowColor
                            style: Text.Outline;
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(window.crust, 0.4)

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on styleColor { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: window.s(260)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: window.viewDesc
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: window.s(16)
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }

                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.weatherContentOffset }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: window.s(10)
                            visible: !!window.viewDay
                            text: window.viewDay
                                ? "H " + Math.round(window.viewDay.max) + "°   L " + Math.round(window.viewDay.min) + "°"
                                  + (window.viewNow && window.viewNow.feels !== null ? "   Feels " + Math.round(window.viewNow.feels) + "°" : "")
                                : ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: window.s(13)
                            color: window.subtext0

                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.weatherContentOffset }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: window.s(10)
                        spacing: window.s(20)

                        Repeater {
                            model: 4

                            Item {
                                id: gaugeWrapper
                                width: window.s(68)
                                height: window.s(100)
                                scale: gaugeMa.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                // Today uses current conditions where it can.
                                property var day: window.selDay
                                property var now: window.selNow
                                property bool imperial: window.units.wind === "mph"

                                property string gaugeIcon: index === 0 ? "\uE34B" : index === 1 ? "\uF043" : index === 2 ? "\uE371" : "\uE30D"
                                property string gaugeLbl: index === 0 ? "WIND" : index === 1 ? "HUMID" : index === 2 ? "RAIN" : "UV"

                                property var gaugeRaw: {
                                    if (!day && !now) return null;
                                    if (index === 0) return now ? now.wind : day.wind;
                                    if (index === 1) return now ? now.humidity : day.humidity;
                                    if (index === 2) return day ? day.pop : null;
                                    return day ? day.uv : null;
                                }

                                property string gaugeVal: gaugeRaw === null || gaugeRaw === undefined ? "--" : (
                                    index === 0 ? Math.round(gaugeRaw) + (imperial ? "mph" : "m/s") :
                                    index === 1 ? Math.round(gaugeRaw) + "%" :
                                    index === 2 ? Math.round(gaugeRaw) + "%" :
                                    Math.round(gaugeRaw).toString()
                                )

                                property real gaugeFill: gaugeRaw === null || gaugeRaw === undefined ? 0.0 : (
                                    index === 0 ? Math.min(1.0, gaugeRaw / (imperial ? 45.0 : 20.0)) :
                                    index === 3 ? Math.min(1.0, gaugeRaw / 11.0) :
                                    gaugeRaw / 100.0
                                )

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: window.s(68); height: window.s(68); radius: window.s(34)
                                    color: window.textAccent
                                    opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }

                                Item {
                                    id: circleItem
                                    width: window.s(68); height: window.s(68)
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Canvas {
                                        id: gaugeCanvas
                                        anchors.fill: parent
                                        rotation: -90

                                        property real animProgress: gaugeWrapper.gaugeFill

                                        Behavior on animProgress {
                                            NumberAnimation { duration: 1000; easing.type: Easing.OutExpo }
                                        }

                                        onAnimProgressChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        Component.onCompleted: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var r = width / 2;

                                            ctx.beginPath();
                                            ctx.arc(r, r, r - window.s(4), 0, 2 * Math.PI);
                                            ctx.strokeStyle = Qt.alpha(window.text, 0.1);
                                            ctx.lineWidth = window.s(3);
                                            ctx.stroke();

                                            if (animProgress > 0) {
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - window.s(4), 0, animProgress * 2 * Math.PI);
                                                var grad = ctx.createLinearGradient(0, 0, width, height);
                                                grad.addColorStop(0, window.timeAccent);
                                                grad.addColorStop(1, window.sapphire);
                                                ctx.strokeStyle = grad;
                                                ctx.lineWidth = window.s(4);
                                                ctx.lineCap = "round";
                                                ctx.stroke();
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: gaugeWrapper.gaugeVal
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(14)
                                        color: window.text
                                    }
                                }

                                RowLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: window.s(4)

                                    Text {
                                        text: gaugeWrapper.gaugeIcon
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(14)
                                        color: gaugeMa.containsMouse ? window.textAccent : window.overlay0
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        text: gaugeWrapper.gaugeLbl
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: window.s(12)
                                        color: window.overlay0
                                    }
                                }

                                MouseArea { id: gaugeMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: window.s(10)
                        visible: !!(window.weatherData && window.weatherData.updated)
                        text: window.weatherData && window.weatherData.updated
                            ? "Open-Meteo · updated " + Qt.formatTime(new Date(window.weatherData.updated * 1000), "HH:mm")
                            : ""
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(10)
                        color: window.overlay0
                        opacity: 0.8
                    }
                }
            }

            // =======================================================
            // BOTTOM SECTION: 24-HOUR TIMELINE OF THE VIEWED DAY
            // Events on top, then the temperature curve with rain-chance
            // bars, then the hour axis. Hover an hour or event for details.
            // =======================================================
            Item {
                id: bottomSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: window.s(240)
                z: 20

                opacity: introTimeline
                transform: Translate { y: window.s(50) * (1.0 - introTimeline) }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(window.crust, 0.6) }
                    }
                }

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.alpha(window.surface1, 0.5) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(25)
                    anchors.rightMargin: window.s(25)
                    anchors.topMargin: window.s(16)
                    anchors.bottomMargin: window.s(16)
                    spacing: window.s(10)

                    // ---- Header: date, event count, all-day events, sun times
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(14)

                        Rectangle {
                            width: window.s(40); height: window.s(40); radius: window.s(20); color: window.surface0
                            Text { anchors.centerIn: parent; text: "\uF073"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18); color: window.textAccent }
                        }

                        ColumnLayout {
                            spacing: window.s(2)
                            Layout.maximumWidth: window.s(520)
                            Text {
                                text: window.viewDate !== "" ? Qt.formatDate(window.parseKey(window.viewDate), "dddd, d MMMM") : ""
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(16)
                                color: window.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: window.eventsSummary
                                elide: Text.ElideRight
                                visible: text !== ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(12)
                                color: window.overlay0
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // All-day events
                        Repeater {
                            model: window.viewAllDay.slice(0, 3)
                            Rectangle {
                                property color cc: window.calColor(modelData.calendar)
                                Layout.preferredHeight: window.s(26)
                                Layout.preferredWidth: Math.min(window.s(200), chipText.implicitWidth + window.s(20))
                                radius: height / 2
                                color: Qt.alpha(cc, chipMa.containsMouse ? 0.35 : 0.18)
                                border.color: cc
                                border.width: 1
                                Text {
                                    id: chipText
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(10)
                                    anchors.rightMargin: window.s(10)
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.title
                                    elide: Text.ElideRight
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(12)
                                    color: window.text
                                }
                                MouseArea {
                                    id: chipMa; anchors.fill: parent; hoverEnabled: true
                                    onContainsMouseChanged: timeline.setHoveredEvent(containsMouse, modelData, parent)
                                }
                            }
                        }
                        Text {
                            visible: window.viewAllDay.length > 3
                            text: "+" + (window.viewAllDay.length - 3)
                            font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(12)
                            color: window.overlay1
                        }

                        // Sunrise / sunset
                        RowLayout {
                            visible: !!window.viewDay
                            spacing: window.s(6)
                            Layout.leftMargin: window.s(10)
                            Text { text: "\uE34C"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(16); color: window.peach }
                            Text { text: window.viewDay ? window.viewDay.sunrise : ""; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(13); color: window.subtext0 }
                            Item { width: window.s(6) }
                            Text { text: "\uE34D"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(16); color: window.mauve }
                            Text { text: window.viewDay ? window.viewDay.sunset : ""; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(13); color: window.subtext0 }
                        }
                    }

                    // ---- Timeline
                    Item {
                        id: timeline
                        objectName: "timeline"
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property real pad: window.s(16)
                        readonly property real axisW: width - 2 * pad
                        readonly property real laneH: window.s(20)
                        readonly property real laneGap: window.s(4)
                        readonly property real chartTop: 2 * laneH + laneGap + window.s(8)
                        readonly property real labelH: window.s(16)
                        readonly property real chartH: Math.max(window.s(30), height - chartTop - labelH)

                        readonly property var hours: window.viewDay && window.viewDay.hours ? window.viewDay.hours : []
                        readonly property real tMin: {
                            let v = 999;
                            for (let i = 0; i < hours.length; i++) if (hours[i].temp !== null) v = Math.min(v, hours[i].temp);
                            return v;
                        }
                        readonly property real tMax: {
                            let v = -999;
                            for (let i = 0; i < hours.length; i++) if (hours[i].temp !== null) v = Math.max(v, hours[i].temp);
                            return v;
                        }

                        function xAt(minutes) { return pad + (minutes / 1440) * axisW; }
                        // y of a temperature inside the chart; room above for labels.
                        function chartYAt(t) {
                            let top = window.s(18), bottom = chartH - window.s(6);
                            if (tMax - tMin < 0.5) return (top + bottom) / 2;
                            return top + (1 - (t - tMin) / (tMax - tMin)) * (bottom - top);
                        }

                        // Hovered item for the tooltip: an hour of the chart or an event.
                        property var hoveredEvent: null
                        property Item hoveredEventItem: null
                        function setHoveredEvent(on, ev, item) {
                            if (on) { hoveredEvent = ev; hoveredEventItem = item; }
                            else if (hoveredEvent === ev) { hoveredEvent = null; hoveredEventItem = null; }
                        }
                        // Event blocks are recreated (without a mouse-exit) when the
                        // day or its events change; drop the hover so the tooltip
                        // doesn't stick to a destroyed item.
                        Connections {
                            target: window
                            function onViewEventsChanged() { timeline.hoveredEvent = null; timeline.hoveredEventItem = null; }
                        }
                        readonly property int hoverHour: (chartMa.containsMouse && hours.length > 0)
                            ? Math.max(0, Math.min(hours.length - 1, Math.round((chartMa.mouseX - pad) / axisW * 24)))
                            : -1

                        opacity: window.weatherContentOpacity

                        // Grid lines every 3 hours
                        Repeater {
                            model: 9
                            Rectangle {
                                x: timeline.xAt(index * 180)
                                y: 0
                                width: 1
                                height: timeline.height - timeline.labelH
                                color: Qt.alpha(window.surface1, index % 4 === 0 ? 0.5 : 0.25)
                            }
                        }

                        // Hour labels
                        Repeater {
                            model: 8
                            Text {
                                x: timeline.xAt(index * 180) - width / 2
                                y: timeline.height - timeline.labelH + window.s(2)
                                text: window.pad2(index * 3) + ":00"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(10)
                                color: window.overlay0
                            }
                        }

                        // Event lanes
                        Text {
                            visible: window.viewTimed.length === 0 && !!window.eventsData && window.eventsData.configured
                            x: timeline.pad + window.s(6)
                            y: (2 * timeline.laneH + timeline.laneGap - height) / 2
                            text: window.viewAllDay.length > 0 ? "No timed events" : "Nothing scheduled"
                            font.family: "JetBrains Mono"
                            font.italic: true
                            font.pixelSize: window.s(12)
                            color: window.overlay0
                        }

                        Repeater {
                            model: window.viewTimed
                            Rectangle {
                                property color cc: window.calColor(modelData.ev.calendar)
                                property bool past: window.viewIsToday && modelData.e <= window.nowMinutes
                                x: timeline.xAt(modelData.s)
                                y: modelData.lane * (timeline.laneH + timeline.laneGap)
                                width: Math.max(window.s(6), timeline.xAt(modelData.e) - timeline.xAt(modelData.s) - window.s(2))
                                height: timeline.laneH
                                radius: window.s(6)
                                color: Qt.alpha(cc, evMa.containsMouse ? 0.45 : 0.22)
                                border.color: cc
                                border.width: 1
                                opacity: past ? 0.5 : 1.0

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(6)
                                    anchors.rightMargin: window.s(4)
                                    verticalAlignment: Text.AlignVCenter
                                    visible: parent.width > window.s(28)
                                    text: modelData.ev.title
                                    elide: Text.ElideRight
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(11)
                                    color: window.text
                                }

                                MouseArea {
                                    id: evMa; anchors.fill: parent; hoverEnabled: true
                                    onContainsMouseChanged: timeline.setHoveredEvent(containsMouse, modelData.ev, parent)
                                }
                            }
                        }

                        // Temperature curve and rain-chance bars
                        Canvas {
                            id: chartCanvas
                            x: 0
                            y: timeline.chartTop
                            width: timeline.width
                            height: timeline.chartH

                            property var hoursRef: timeline.hours
                            property color accent: window.textAccent
                            property color accent2: window.activeWeatherHex
                            onHoursRefChanged: requestPaint()
                            onAccentChanged: requestPaint()
                            onAccent2Changed: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var hrs = hoursRef;
                                if (!hrs || hrs.length < 2) return;

                                // Rain chance: bars from the bottom, opacity by chance.
                                var colW = timeline.axisW / 24;
                                for (var i = 0; i < hrs.length; i++) {
                                    var p = hrs[i].pop || 0;
                                    if (p <= 0) continue;
                                    var bh = (p / 100) * window.s(30);
                                    ctx.fillStyle = Qt.alpha(window.sapphire, 0.15 + 0.35 * p / 100);
                                    ctx.fillRect(timeline.xAt(hrs[i].hour * 60) - colW * 0.3, height - bh, colW * 0.6, bh);
                                }

                                var pts = [];
                                for (i = 0; i < hrs.length; i++) {
                                    if (hrs[i].temp === null) continue;
                                    pts.push({ x: timeline.xAt(hrs[i].hour * 60), y: timeline.chartYAt(hrs[i].temp) });
                                }
                                if (pts.length < 2) return;

                                // Smooth curve through the midpoints between samples.
                                ctx.beginPath();
                                ctx.moveTo(pts[0].x, pts[0].y);
                                for (i = 1; i < pts.length - 1; i++) {
                                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, (pts[i].x + pts[i + 1].x) / 2, (pts[i].y + pts[i + 1].y) / 2);
                                }
                                ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);

                                var stroke = ctx.createLinearGradient(0, 0, width, 0);
                                stroke.addColorStop(0, accent);
                                stroke.addColorStop(1, accent2);
                                ctx.strokeStyle = stroke;
                                ctx.lineWidth = window.s(2.5);
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.stroke();

                                // Soft fill under the curve.
                                ctx.lineTo(pts[pts.length - 1].x, height);
                                ctx.lineTo(pts[0].x, height);
                                ctx.closePath();
                                var fill = ctx.createLinearGradient(0, 0, 0, height);
                                fill.addColorStop(0, Qt.alpha(accent, 0.22));
                                fill.addColorStop(1, Qt.alpha(accent, 0.0));
                                ctx.fillStyle = fill;
                                ctx.fill();
                            }
                        }

                        // Temperature labels every 3 hours
                        Repeater {
                            model: timeline.hours.length >= 24 ? 8 : 0
                            Text {
                                property var h: timeline.hours[index * 3]
                                visible: h && h.temp !== null
                                x: timeline.xAt(index * 180) - width / 2
                                y: timeline.chartTop + (h && h.temp !== null ? timeline.chartYAt(h.temp) : 0) - height - window.s(3)
                                text: h && h.temp !== null ? Math.round(h.temp) + "°" : ""
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: window.s(11)
                                color: window.subtext0
                            }
                        }

                        Text {
                            visible: timeline.hours.length === 0
                            x: (timeline.width - width) / 2
                            y: timeline.chartTop + (timeline.chartH - height) / 2
                            text: !window.weatherData ? "Loading weather..."
                                : (window.weatherData.error ? window.weatherData.error : "No hourly forecast this far ahead")
                            font.family: "JetBrains Mono"
                            font.italic: true
                            font.pixelSize: window.s(13)
                            color: window.overlay0
                        }

                        // "Now" marker
                        Rectangle {
                            visible: window.viewIsToday
                            x: timeline.xAt(window.nowMinutes) - width / 2
                            y: 0
                            width: window.s(2)
                            height: timeline.height - timeline.labelH
                            radius: width / 2
                            color: window.textAccent
                            opacity: 0.85
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -height / 2
                                width: window.s(8); height: width; radius: width / 2
                                color: window.textAccent
                            }
                        }

                        // Hover marker on the curve
                        Rectangle {
                            visible: timeline.hoverHour >= 0
                            x: timeline.xAt(timeline.hoverHour * 60) - width / 2
                            y: timeline.chartTop
                            width: 1
                            height: timeline.chartH
                            color: window.overlay1
                        }
                        Rectangle {
                            property var h: timeline.hoverHour >= 0 ? timeline.hours[timeline.hoverHour] : null
                            visible: !!h && h.temp !== null
                            width: window.s(9); height: width; radius: width / 2
                            x: timeline.xAt(timeline.hoverHour * 60) - width / 2
                            y: timeline.chartTop + (h && h.temp !== null ? timeline.chartYAt(h.temp) : 0) - height / 2
                            color: window.base
                            border.color: window.textAccent
                            border.width: window.s(2)
                        }

                        MouseArea {
                            id: chartMa
                            x: 0
                            y: timeline.chartTop
                            width: timeline.width
                            height: timeline.chartH + timeline.labelH
                            hoverEnabled: true
                        }

                        // Tooltip
                        Rectangle {
                            id: tip
                            z: 50
                            property var h: timeline.hoverHour >= 0 ? timeline.hours[timeline.hoverHour] : null
                            property var ev: timeline.hoveredEvent
                            property real anchorX: ev && timeline.hoveredEventItem
                                ? timeline.hoveredEventItem.mapToItem(timeline, timeline.hoveredEventItem.width / 2, 0).x
                                : (h ? timeline.xAt(timeline.hoverHour * 60) : 0)
                            visible: !!ev || !!h
                            width: tipCol.implicitWidth + window.s(20)
                            height: tipCol.implicitHeight + window.s(14)
                            x: Math.max(0, Math.min(timeline.width - width, anchorX - width / 2))
                            // Events: below the lanes. Hours: above the curve, in the lane area.
                            y: ev ? Math.min(timeline.height - height, 2 * timeline.laneH + timeline.laneGap + window.s(4)) : 0
                            radius: window.s(8)
                            color: window.mantle
                            border.color: window.surface2
                            border.width: 1

                            Column {
                                id: tipCol
                                anchors.centerIn: parent
                                spacing: window.s(2)

                                Text {
                                    text: {
                                        if (tip.ev) {
                                            if (tip.ev.all_day) return tip.ev.title;
                                            return tip.ev.start.substring(11, 16) + " – " + tip.ev.end.substring(11, 16) + "   " + tip.ev.title;
                                        }
                                        if (tip.h) return tip.h.time + "   " + tip.h.desc + "   " + Math.round(tip.h.temp) + "°";
                                        return "";
                                    }
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(12)
                                    color: window.text
                                }
                                Text {
                                    visible: text !== ""
                                    text: {
                                        if (tip.ev) {
                                            let parts = [];
                                            if (tip.ev.location) parts.push(tip.ev.location);
                                            if (window.eventsData && window.eventsData.calendars) {
                                                let c = window.eventsData.calendars[tip.ev.calendar];
                                                if (c && window.eventsData.calendars.length > 1) parts.push(c.name);
                                            }
                                            return parts.join("   ·   ");
                                        }
                                        if (tip.h) {
                                            let u = window.units;
                                            let rain = "Rain " + (tip.h.pop !== null ? tip.h.pop : 0) + "%";
                                            if (tip.h.precip > 0) rain += " (" + tip.h.precip + " " + u.precip + ")";
                                            return "Feels " + Math.round(tip.h.feels) + "°   ·   " + rain
                                                + "   ·   Wind " + Math.round(tip.h.wind) + " " + u.wind
                                                + "   ·   UV " + Math.round(tip.h.uv || 0);
                                        }
                                        return "";
                                    }
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(11)
                                    color: window.subtext0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

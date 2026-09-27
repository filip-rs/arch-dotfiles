import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WindowRegistry.js" as Registry

PanelWindow {
    id: masterWindow
    color: "transparent"

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay
    
    exclusionMode: ExclusionMode.Ignore 
    focusable: true

    // Which output the overlay lives on. qs_manager.sh resolves this from the
    // cursor (bar clicks) or the focused monitor (keybinds) and sends it over
    // IPC; empty means "leave it where it is".
    property string targetMonitor: ""

    screen: {
        if (masterWindow.targetMonitor !== "") {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === masterWindow.targetMonitor)
                    return Quickshell.screens[i];
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    readonly property int screenW: screen ? screen.width : Screen.width
    readonly property int screenH: screen ? screen.height : Screen.height

    // Cover the whole output. Anchoring all four sides lets the layer surface
    // resize itself when the resolution changes or the overlay moves to a
    // different monitor.
    anchors { top: true; bottom: true; left: true; right: true }

    visible: isVisible

    // Punch a click-through hole over waybar (which is at the BOTTOM) so its
    // icons stay clickable while a panel is open — clicking a different icon
    // then switches panels instead of just dismissing the current one.
    mask: Region { item: barHole; intersection: Intersection.Xor }
    
    Item {
        id: barHole
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Registry.BAR_HEIGHT
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    // Initialize state on boot
    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > /tmp/qs_active_widget"]);
    }

    property string currentActive: "hidden" 
    property bool isVisible: false
    property string activeArg: ""
    property string activeAnchor: ""
    property bool disableMorph: false 
    property bool isWallpaperTransition: false 
    property int morphDuration: 500

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0
    
    // NEW: Explicit targets for the inner content wrapper so widgets can override them dynamically
    property real targetW: 1
    property real targetH: 1

    function getLayout(name) {
        // Coordinates are window-local and the window covers exactly one
        // output, so the monitor offset is always 0/0.
        return Registry.getLayout(name, 0, 0, masterWindow.screenW, masterWindow.screenH,
                                  masterWindow.activeAnchor);
    }

    // Automatically recalculates position and scale if the resolution or the
    // output the overlay lives on changes.
    onScreenWChanged: handleNativeScreenChange()
    onScreenHChanged: handleNativeScreenChange()

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;
        
        let t = getLayout(masterWindow.currentActive);
        if (t) {
            // Update the animation targets. The Behaviors below will 
            // glide the widget to the new layout perfectly.
            masterWindow.animX = t.rx;
            masterWindow.animY = t.ry;
            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.targetW = t.w;
            masterWindow.targetH = t.h;
        }
    }
    // ---------------------------------------

    onIsVisibleChanged: {
        if (isVisible) masterWindow.requestActivate();
    }

    // --- THE WIDGET CONTAINER ---
    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width: masterWindow.animW
        height: masterWindow.animH
        clip: true 

        Behavior on x { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on width { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { enabled: !masterWindow.disableMorph; NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.InOutCubic } }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: masterWindow.isWallpaperTransition ? 150 : (masterWindow.morphDuration === 500 ? 300 : 200); easing.type: Easing.InOutSine } }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.centerIn: parent
            // CHANGE: Now uses the overrideable properties instead of strict registry bindings
            width: masterWindow.targetW
            height: masterWindow.targetH

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true
                
                Keys.onEscapePressed: {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.98; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                    }
                }
                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 300; easing.type: Easing.InExpo }
                        NumberAnimation { property: "scale"; from: 1.0; to: 1.02; duration: 300; easing.type: Easing.InExpo }
                    }
                }
            }
        }
    }

    // Widgets that resize themselves at runtime (e.g. the calendar when the
    // schedule module is absent) must go through this, so a bar-docked panel
    // stays docked to the bar instead of floating away from it.
    function setContentHeight(h) {
        masterWindow.animH = h;
        masterWindow.targetH = h;
        if (Registry.isDocked(masterWindow.currentActive)) {
            masterWindow.animY = Registry.dockedY(h, masterWindow.screenH,
                                                  Registry.getScale(masterWindow.screenW));
        }
    }

    function switchWidget(newWidget, arg) {
        // FIX 1: Immediately update the system state file so the bash manager 
        // doesn't read stale data during the morph animations.
        Quickshell.execDetached(["bash", "-c", "echo '" + newWidget + "' > /tmp/qs_active_widget"]);

        prepTimer.stop();
        teleportFadeOutTimer.stop();
        teleportFadeInTimer.stop();
        delayedClear.stop();

        let involvesWallpaper = (newWidget === "wallpaper" || currentActive === "wallpaper");
        masterWindow.isWallpaperTransition = involvesWallpaper;

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = 250; 
                masterWindow.disableMorph = false;
                
                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false; 
                
                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden") {
                masterWindow.morphDuration = 250;
                masterWindow.disableMorph = false;
                
                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = 1;
                masterWindow.animH = 1;

                prepTimer.newWidget = newWidget;
                prepTimer.newArg = arg;
                prepTimer.start();
                
            } else {
                masterWindow.morphDuration = 500;
                if (involvesWallpaper) {
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false; 
                    teleportFadeOutTimer.newWidget = newWidget;
                    teleportFadeOutTimer.newArg = arg;
                    teleportFadeOutTimer.start();
                } else {
                    masterWindow.disableMorph = false;
                    executeSwitch(newWidget, arg, false);
                }
            }
        }
    }

    Timer {
        id: prepTimer
        interval: 50
        property string newWidget: ""
        property string newArg: ""
        onTriggered: executeSwitch(newWidget, newArg, false)
    }

    Timer {
        id: teleportFadeOutTimer
        interval: 150 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            let t = getLayout(newWidget);

            masterWindow.currentActive = newWidget;
            masterWindow.activeArg = newArg;

            masterWindow.animX = t.rx;
            masterWindow.animY = t.ry;
            masterWindow.animW = t.w;
            masterWindow.animH = t.h;
            masterWindow.targetW = t.w;
            masterWindow.targetH = t.h;

            let props = newWidget === "wallpaper" ? { "widgetArg": newArg } : {};
            widgetStack.replace(t.comp, props, StackView.Immediate);

            teleportFadeInTimer.newWidget = newWidget;
            teleportFadeInTimer.newArg = newArg;
            teleportFadeInTimer.start();
        }
    }

    Timer {
        id: teleportFadeInTimer
        interval: 50 
        property string newWidget: ""
        property string newArg: ""
        onTriggered: {
            masterWindow.isVisible = true; 
            if (newWidget !== "wallpaper") resetMorphTimer.start();
        }
    }

    Timer {
        id: resetMorphTimer
        interval: masterWindow.morphDuration 
        onTriggered: masterWindow.disableMorph = false
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        
        let t = getLayout(newWidget);
        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;
        
        let props = newWidget === "wallpaper" ? { "widgetArg": arg } : {};

        if (immediate) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, props);
        }
        
        masterWindow.isVisible = true;
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: { if (!ipcPoller.running) ipcPoller.running = true; }
    }

    Process {
        id: ipcPoller
        // FIX 2: Use `mv` to make the file read/delete atomic. This prevents 
        // wiping out rapid subsequent commands that happen during execution.
        command: ["bash", "-c", "if [ -f /tmp/qs_widget_state ]; then mv /tmp/qs_widget_state /tmp/qs_widget_state_read 2>/dev/null && cat /tmp/qs_widget_state_read && rm /tmp/qs_widget_state_read; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rawCmd = this.text.trim();
                if (rawCmd === "") return;

                // Wire format: "<cmd>[:<arg>][|<anchor>|<monitor>]".
                // qs_manager.sh appends the anchor (which side of the bar the
                // invoking icon lives on) and the output to open on. Both are
                // optional, so older/plain "close" and "network" still work.
                let envelope = rawCmd.split("|");
                let head = envelope[0];
                let anchor = envelope.length > 1 ? envelope[1] : "";
                let monitor = envelope.length > 2 ? envelope[2] : "";

                let hp = head.split(":");
                let cmd = hp[0];
                let arg = hp.length > 1 ? hp.slice(1).join(":") : "";

                if (cmd === "close") {
                    switchWidget("hidden", "");
                } else if (getLayout(cmd)) {
                    delayedClear.stop();
                    if (monitor !== "") masterWindow.targetMonitor = monitor;
                    masterWindow.activeAnchor = anchor;
                    switchWidget(cmd, arg);
                }
            }
        }
    }

    Timer {
        id: delayedClear
        interval: masterWindow.isWallpaperTransition ? 150 : masterWindow.morphDuration 
        onTriggered: {
            masterWindow.currentActive = "hidden";
            widgetStack.clear();
            masterWindow.disableMorph = false;
        }
    }
}

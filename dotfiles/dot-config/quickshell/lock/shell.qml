import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Quickshell lockscreen. Start it with lock.sh, never directly: lock.sh
// restarts it if it crashes and falls back to hyprlock if it can't lock.
//
// The only code path that unlocks is release(), and only LockContext's
// unlocked() signal (a successful PAM conversation) calls it. Any other way
// out (crash, kill, QML error) leaves the session locked by the compositor.
ShellRoot {
    id: shell

    // A lock must never hot-reload itself: a git pull or stow run mid-lock
    // shouldn't swap the code you're authenticating against.
    settings.watchFiles: false

    // lock.sh hands us a file to report progress through:
    //   "requested" - the config loaded and the lock has been asked for
    //   "locked"    - the compositor confirmed every output is covered
    //   "unlocked"  - PAM succeeded and the lock was released
    readonly property string stateFile: Quickshell.env("QSLOCK_STATE_FILE") ?? ""

    Component.onCompleted: writeState(secure ? "locked" : "requested")

    readonly property bool secure: sessionLock.secure
    onSecureChanged: if (secure) writeState("locked")

    Theme {
        id: lockTheme
    }

    LockContext {
        id: lockContext
        onUnlocked: shell.release()
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            color: lockTheme.crust

            LockSurface {
                anchors.fill: parent
                context: lockContext
                theme: lockTheme
            }
        }
    }

    function release() {
        sessionLock.locked = false;
        quitTimer.start();
    }

    // Give the unlock request time to reach the compositor before exiting.
    Timer {
        id: quitTimer
        interval: 300
        onTriggered: {
            shell.writeState("unlocked");
            Qt.quit();
        }
    }

    FileView {
        id: stateView
        path: shell.stateFile
        preload: false
        printErrors: false
        blockWrites: true
        atomicWrites: true
    }

    function writeState(s) {
        if (stateFile !== "")
            stateView.setText(s);
    }
}

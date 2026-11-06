import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Authentication state shared by every lock surface.
//
// Password and fingerprint are two independent PAM conversations running at
// the same time; whichever succeeds first unlocks. The fingerprint side never
// gives up on reader errors (fprintd busy right after resume, the sensor
// re-enumerating on USB, fprintd restarting). It retries with backoff. Only
// real non-matching scans count towards fpMaxAttempts.
Scope {
    id: root

    // Emitted exactly once, after a PAM conversation succeeded.
    signal unlocked()

    readonly property int fpMaxAttempts: 7

    // ---- password ----------------------------------------------------------
    property string currentText: ""    // shared by the input on every screen
    property bool checking: false      // a password conversation is in flight
    property string passwordError: ""  // shown under the field until the next keystroke
    property int failSerial: 0         // bumps on each password failure (drives the shake)
    property string pendingPassword: ""
    property string pamNotice: ""      // non-prompt PAM text, e.g. faillock's "account is locked"

    // ---- fingerprint -------------------------------------------------------
    // "starting" | "ready" | "nomatch" | "waking" | "unavailable" | "disabled"
    property string fpState: "starting"
    property string fpHint: ""         // mid-scan retry text from pam_fprintd
    property int fpFailures: 0
    property int fpErrorStreak: 0
    property bool fpScanning: false    // pam_fprintd announced a live scan this run
    readonly property int fpAttemptsLeft: Math.max(0, fpMaxAttempts - fpFailures)

    property bool unlocking: false

    onCurrentTextChanged: if (currentText !== "") passwordError = ""

    function tryPassword() {
        if (unlocking || checking || currentText === "")
            return;
        pendingPassword = currentText;
        pamNotice = "";
        passwordError = "";
        checking = true;
        if (!passwd.start()) {
            checking = false;
            pendingPassword = "";
            failPassword("Couldn't start the password check");
        }
    }

    function failPassword(msg) {
        currentText = "";
        passwordError = msg;
        failSerial++;
    }

    function startFingerprint() {
        if (unlocking || fpState === "disabled")
            return;
        if (fprint.active) {  // previous run still winding down
            fpRetry.interval = 300;
            fpRetry.restart();
            return;
        }
        fpScanning = false;
        if (!fprint.start())
            fingerprintError();
    }

    // The reader couldn't run a scan at all. Not the user's fault, so it
    // doesn't count as an attempt; back off 1s, 2s, 4s ... 15s and retry forever.
    function fingerprintError() {
        fpScanning = false;
        fpHint = "";
        fpErrorStreak++;
        fpState = fpErrorStreak > 4 ? "unavailable" : "waking";
        fpRetry.interval = Math.min(500 * Math.pow(2, fpErrorStreak), 15000);
        fpRetry.restart();
    }

    function finish() {
        if (unlocking)
            return;
        unlocking = true;
        fpRetry.stop();
        if (fprint.active)
            fprint.abort();
        if (passwd.active)
            passwd.abort();
        currentText = "";
        pendingPassword = "";
        unlocked();
    }

    Component.onCompleted: startFingerprint()

    Timer {
        id: fpRetry
        onTriggered: root.startFingerprint()
    }

    Timer {
        id: fpHintClear
        interval: 2500
        onTriggered: root.fpHint = ""
    }

    Timer {
        id: nomatchClear
        interval: 2500
        onTriggered: if (root.fpState === "nomatch") root.fpState = root.fpScanning ? "ready" : "starting"
    }

    PamContext {
        id: passwd
        // The same stack hyprlock used (/etc/pam.d/hyprlock is "auth include
        // login"), so faillock and the rest of the system policy still apply.
        config: "login"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.pendingPassword);
            } else if (this.message !== "") {
                root.pamNotice = root.pamNotice === "" ? this.message : root.pamNotice + " " + this.message;
            }
        }

        onCompleted: result => {
            root.checking = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.finish();
                return;
            }
            root.failPassword(root.pamNotice !== "" ? root.pamNotice : "Wrong password");
        }

        onError: err => {
            root.checking = false;
            root.pendingPassword = "";
            root.failPassword("Password check failed (" + PamError.toString(err) + ")");
        }
    }

    PamContext {
        id: fprint
        configDirectory: Quickshell.shellDir + "/pam"
        config: "fingerprint"

        onPamMessage: {
            if (this.responseRequired) {  // pam_fprintd never asks; don't hang if something does
                this.respond("");
                return;
            }
            if (!this.messageIsError) {
                // "Place your finger on the fingerprint reader": the scan is live.
                root.fpScanning = true;
                root.fpErrorStreak = 0;
                if (root.fpState !== "nomatch")
                    root.fpState = "ready";
            } else if (this.message !== "") {
                // Retry prompts ("Place your finger on the reader again") and the
                // no-match notice that precedes a failed completion.
                root.fpHint = this.message;
                fpHintClear.restart();
            }
        }

        onCompleted: result => {
            if (root.unlocking)
                return;
            if (result === PamResult.Success) {
                root.finish();
                return;
            }
            const scanned = root.fpScanning;
            root.fpScanning = false;
            root.fpHint = "";
            if (scanned && (result === PamResult.Failed || result === PamResult.MaxTries)) {
                // A finger was read and didn't match.
                root.fpFailures++;
                if (root.fpFailures >= root.fpMaxAttempts) {
                    root.fpState = "disabled";
                    return;
                }
                root.fpState = "nomatch";
                nomatchClear.restart();
                fpRetry.interval = 800;  // time to lift the finger before the next scan
                fpRetry.restart();
            } else {
                root.fingerprintError();
            }
        }

        onError: err => {
            if (!root.unlocking)
                root.fingerprintError();
        }
    }
}

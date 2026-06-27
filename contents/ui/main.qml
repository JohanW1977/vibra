import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.vibra

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    Plasmoid.icon: "audio-track"

    hideOnWindowDeactivate: !Plasmoid.configuration.pin

    readonly property int bezel:     Kirigami.Units.smallSpacing * 2
    readonly property int barHeight: Kirigami.Units.gridUnit * 2
    readonly property int totalH:    Kirigami.Units.gridUnit * 31
    readonly property int coverSide: totalH - barHeight - bezel * 2
    readonly property int panelW:    coverSide + bezel * 2
    readonly property int popupW:    panelW * 2 + 1

    // ── Single source of truth ────────────────────────────────────────────
    property var  selectedTrack:     null
    property var  history:           []
    property var  fullViewItem:      null
    property bool continuousSearch:  Plasmoid.configuration.continuousSearch

    // Save continuous mode state when it changes
    onContinuousSearchChanged: {
        Plasmoid.configuration.continuousSearch = continuousSearch;
    }

    // Called by SearchTab when a listen cycle completes (found or not)
    function onListenCycleComplete() {
        if (root.continuousSearch && vibraBackend.state !== "listening" &&
            vibraBackend.state !== "identifying") {
            // Small delay before restarting
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.continuousSearch)
                vibraBackend.startListening(
                    Plasmoid.configuration.deviceId,
                    Plasmoid.configuration.searchSeconds
                );
        }
    }

    // ── History persistence via Plasmoid.configuration ───────────────────
    function loadHistory() {
        try {
            root.history = JSON.parse(Plasmoid.configuration.history);
        } catch(e) {
            root.history = [];
        }
    }

    function saveHistory() {
        Plasmoid.configuration.history = JSON.stringify(root.history);
    }

    function clearHistory() {
        root.history = [];
        root.selectedTrack = null;
        Plasmoid.configuration.history = "[]";
    }

    // Sync root.history if Plasmoid.configuration.history changes externally
    // (e.g. when user removes an item directly via the delegate)
    Connections {
        target: Plasmoid.configuration
        function onHistoryChanged() {
            try {
                const hist = JSON.parse(Plasmoid.configuration.history);
                root.history = hist;
                // If selected track no longer exists in history, select the first one
                if (root.selectedTrack) {
                    const still = hist.findIndex(
                        h => h.title === root.selectedTrack.title &&
                             h.artist === root.selectedTrack.artist &&
                             h.timestamp === root.selectedTrack.timestamp
                    );
                    if (still < 0) {
                        // Force update by clearing first then setting
                        root.selectedTrack = null;
                        if (hist.length > 0)
                            Qt.callLater(function() { root.selectedTrack = hist[0]; });
                    }
                }
            } catch(e) {}
        }
    }

    // ── Backend ───────────────────────────────────────────────────────────
    VibraBackend {
        id: vibraBackend

        Component.onCompleted: {
            root.loadHistory();
            if (root.history.length > 0)
                root.selectedTrack = root.history[0];
            if (Plasmoid.configuration.autoListen)
                vibraBackend.startListening(
                    Plasmoid.configuration.deviceId,
                    Plasmoid.configuration.searchSeconds
                );
            // Restore continuous mode state
            root.continuousSearch = Plasmoid.configuration.continuousSearch;
        }

        onResultReady: function(title, artist, coverUrl, trackUrl, rawJson) {
            const now = new Date();
            const pad = n => String(n).padStart(2, "0");
            const timestamp = now.getFullYear() + "-"
                            + pad(now.getMonth() + 1) + "-"
                            + pad(now.getDate()) + " "
                            + pad(now.getHours()) + ":"
                            + pad(now.getMinutes());

            const entry = { title, artist, coverUrl, trackUrl, timestamp };
            let hist = root.history.slice();

            if (!Plasmoid.configuration.showDuplicates) {
                // Only skip if the MOST RECENT entry is the same track
                if (hist.length > 0 &&
                    hist[0].title === title && hist[0].artist === artist) {
                    root.selectedTrack = hist[0];
                    root.onListenCycleComplete();
                    return;
                }
            }

            hist.unshift(entry);
            if (hist.length > 50) hist = hist.slice(0, 50);
            root.history = hist;
            root.saveHistory();
            root.selectedTrack = entry;
            root.onListenCycleComplete();

            // Show notification if enabled and plasmoid is not expanded
            if (Plasmoid.configuration.showNotifications && !root.expanded) {
                const tmpIcon = "/tmp/vibra-cover-notify.jpg";
                vibraBackend.sendNotification(title, artist, coverUrl, tmpIcon);
            }
        }

        onErrorOccurred: function(message) {
            console.warn("VibraBackend error:", message);
            root.onListenCycleComplete();
        }
    }

    // ── Reset to Search tab when popup opens ─────────────────────────────
    onExpandedChanged: (expanded) => {
        if (expanded && root.fullViewItem)
            root.fullViewItem.resetToSearchTab();
    }

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.centerIn: parent
            width:  Math.min(parent.width, parent.height) * 0.85
            height: width
            source: "audio-track"
            activeFocusOnTab: true
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        implicitWidth:  root.popupW
        implicitHeight: root.totalH
        width:          root.popupW
        height:         root.totalH

        Loader {
            id: fullLoader
            width:  root.popupW
            height: root.totalH
            source: "FullView.qml"

            Binding { target: fullLoader.item; property: "backend";          value: vibraBackend;          when: fullLoader.status === Loader.Ready }
            Binding { target: fullLoader.item; property: "selectedTrack";    value: root.selectedTrack;    when: fullLoader.status === Loader.Ready }
            Binding { target: fullLoader.item; property: "history";          value: root.history;          when: fullLoader.status === Loader.Ready }
            Binding { target: fullLoader.item; property: "continuousSearch"; value: root.continuousSearch; when: fullLoader.status === Loader.Ready }

            onLoaded: {
                root.fullViewItem = item;
                item.onSelectTrack        = function(track) { root.selectedTrack = track; };
                item.onClearHistory       = function() { root.clearHistory(); };
                item.onToggleContinuous   = function() { root.continuousSearch = !root.continuousSearch; };
                item.resetToSearchTab();
            }
            onStatusChanged: {
                if (status === Loader.Null) root.fullViewItem = null;
            }
        }
    }
}

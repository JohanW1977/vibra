import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import Qt.labs.platform as Platform

Item {
    id: searchTab

    property var  backend:            null
    property var  selectedTrack:      null
    property var  history:            []
    property bool continuousSearch:   false
    property var  onToggleContinuous: null

    // ── History model ─────────────────────────────────────────────────────
    ListModel { id: historyModel }

    function reloadHistory() {
        historyModel.clear();
        for (let i = 0; i < searchTab.history.length; i++)
            historyModel.append(searchTab.history[i]);
    }

    onHistoryChanged: reloadHistory()
    Component.onCompleted: reloadHistory()

    // ── Walk up to find tabLoader ─────────────────────────────────────────
    property var tabLoader: {
        let p = searchTab.parent;
        while (p) {
            if (typeof p.selectTrack === "function") return p;
            p = p.parent;
        }
        return null;
    }

    // ── Clipboard helper ──────────────────────────────────────────────────
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    // ── CSV Export ───────────────────────────────────────────────────────
    function exportToCsv(fileUrl) {
        // Build CSV content
        let csv = "Artist,Title,Date\n";
        for (let i = 0; i < searchTab.history.length; i++) {
            const h = searchTab.history[i];
            const artist = (h.artist || "").replace(/"/g, '""');
            const title  = (h.title  || "").replace(/"/g, '""');
            const ts     = (h.timestamp || "").replace(/"/g, '""');
            csv += '"' + artist + '","' + title + '","' + ts + '"\n';
        }
        // Write via backend
        if (backend) backend.writeFile(fileUrl.toString().replace("file://", ""), csv);
    }

    Platform.FileDialog {
        id: saveDialog
        title: i18n("Export history to CSV")
        fileMode: Platform.FileDialog.SaveFile
        nameFilters: [ i18n("CSV files (*.csv)"), i18n("All files (*)") ]
        defaultSuffix: "csv"
        onAccepted: searchTab.exportToCsv(saveDialog.file)
    }

    // ── Layout ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: i18n("Results")
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            PlasmaComponents3.ToolButton {
                icon.name: "document-save"
                visible: historyModel.count > 0
                onClicked: saveDialog.open()
                QQC2.ToolTip.text: i18n("Export to CSV")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            PlasmaComponents3.ToolButton {
                icon.name: "edit-clear-history"
                visible: historyModel.count > 0
                onClicked: {
                    if (searchTab.tabLoader &&
                        typeof searchTab.tabLoader.clearHistory === "function")
                        searchTab.tabLoader.clearHistory();
                }
                QQC2.ToolTip.text: i18n("Clear history")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        PlasmaComponents3.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: resultsList
                clip: true
                model: historyModel

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    text: i18n("No results yet.\nPress Listen to start.")
                    horizontalAlignment: Text.AlignHCenter
                    color: Kirigami.Theme.disabledTextColor
                    visible: historyModel.count === 0
                }

                delegate: QQC2.ItemDelegate {
                    id: trackDelegate
                    width: resultsList.width
                    highlighted: searchTab.selectedTrack !== null
                                 && searchTab.selectedTrack.title === model.title
                                 && searchTab.selectedTrack.artist === model.artist
                                 && searchTab.selectedTrack.timestamp === model.timestamp

                    // Right-click context menu
                    QQC2.Menu {
                        id: contextMenu
                        QQC2.MenuItem {
                            text: i18n("Copy track name to clipboard")
                            icon.name: "edit-copy"
                            onTriggered: {
                                const text = model.artist + " - " + model.title;
                                clipboardHelper.text = text;
                                clipboardHelper.selectAll();
                                clipboardHelper.copy();
                            }
                        }
                        QQC2.MenuItem {
                            text: i18n("Open in Shazam")
                            icon.name: "globe"
                            enabled: model.trackUrl !== ""
                            onTriggered: Qt.openUrlExternally(model.trackUrl)
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18n("Remove from list")
                            icon.name: "edit-delete"
                            onTriggered: {
                                // Remove from history
                                let hist = root.history ? root.history.slice() : [];
                                const idx = hist.findIndex(
                                    h => h.title === model.title && h.artist === model.artist
                                         && h.timestamp === model.timestamp
                                );
                                if (idx >= 0) hist.splice(idx, 1);
                                Plasmoid.configuration.history = JSON.stringify(hist);
                                if (searchTab.tabLoader) {
                                    const wasSelected = searchTab.selectedTrack &&
                                        searchTab.selectedTrack.title === model.title &&
                                        searchTab.selectedTrack.artist === model.artist &&
                                        searchTab.selectedTrack.timestamp === model.timestamp;
                                    if (wasSelected || idx === 0) {
                                        searchTab.tabLoader.selectTrack(null);
                                        if (hist.length > 0)
                                            Qt.callLater(function() {
                                                searchTab.tabLoader.selectTrack(hist[0]);
                                            });
                                    }
                                }
                            }
                        }
                    }

                    contentItem: Item {
                        implicitHeight: textCol.implicitHeight

                        ColumnLayout {
                            id: textCol
                            anchors.left: parent.left
                            anchors.right: hoverActions.left
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: 0

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: model.artist
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: model.title
                                elide: Text.ElideRight
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: model.timestamp
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }

                        // Hover action icons — only visible on hover
                        Row {
                            id: hoverActions
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 2
                            visible: trackDelegate.hovered
                            opacity: trackDelegate.hovered ? 1.0 : 0.0

                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            // Copy button
                            PlasmaComponents3.ToolButton {
                                width:  Kirigami.Units.iconSizes.small * 2
                                height: Kirigami.Units.iconSizes.small * 2
                                icon.name: "edit-copy"
                                onClicked: {
                                    clipboardHelper.text = model.artist + " - " + model.title;
                                    clipboardHelper.selectAll();
                                    clipboardHelper.copy();
                                }
                                QQC2.ToolTip.text: i18n("Copy track name")
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }

                            // Remove button
                            PlasmaComponents3.ToolButton {
                                width:  Kirigami.Units.iconSizes.small * 2
                                height: Kirigami.Units.iconSizes.small * 2
                                icon.name: "edit-delete"
                                onClicked: {
                                    let hist = [];
                                    try { hist = JSON.parse(Plasmoid.configuration.history); } catch(e) {}
                                    const idx = hist.findIndex(
                                        h => h.title === model.title && h.artist === model.artist
                                             && h.timestamp === model.timestamp
                                    );
                                    if (idx >= 0) hist.splice(idx, 1);
                                    Plasmoid.configuration.history = JSON.stringify(hist);
                                    // Always update selection after removal
                                    if (searchTab.tabLoader) {
                                        const wasSelected = searchTab.selectedTrack &&
                                            searchTab.selectedTrack.title === model.title &&
                                            searchTab.selectedTrack.artist === model.artist &&
                                            searchTab.selectedTrack.timestamp === model.timestamp;
                                        if (wasSelected || idx === 0) {
                                            // Force null first so the binding detects the change
                                            searchTab.tabLoader.selectTrack(null);
                                            if (hist.length > 0)
                                                Qt.callLater(function() {
                                                    searchTab.tabLoader.selectTrack(hist[0]);
                                                });
                                        }
                                    }
                                }
                                QQC2.ToolTip.text: i18n("Remove from list")
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }
                    }

                    onClicked: {
                        if (searchTab.tabLoader)
                            searchTab.tabLoader.selectTrack({
                                title:     model.title,
                                artist:    model.artist,
                                coverUrl:  model.coverUrl,
                                trackUrl:  model.trackUrl,
                                timestamp: model.timestamp
                            });
                    }

                    // Right-click
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton)
                                contextMenu.popup();
                        }
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: backend ? backend.statusText : ""
            color: {
                if (!backend) return Kirigami.Theme.disabledTextColor;
                switch(backend.state) {
                    case "found":       return Kirigami.Theme.positiveTextColor;
                    case "error":       return Kirigami.Theme.negativeTextColor;
                    case "listening":
                    case "identifying": return Kirigami.Theme.neutralTextColor;
                    default:            return Kirigami.Theme.disabledTextColor;
                }
            }
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Continuous mode toggle
            PlasmaComponents3.ToolButton {
                id: continuousButton
                icon.name: "media-playlist-repeat"
                checkable: true
                checked: searchTab.continuousSearch
                onClicked: {
                    if (searchTab.onToggleContinuous)
                        searchTab.onToggleContinuous();
                }
                // Highlight when active
                opacity: checked ? 1.0 : 0.5
                QQC2.ToolTip.text: checked ? i18n("Continuous search: on") : i18n("Continuous search: off")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            PlasmaComponents3.Button {
                id: listenButton
                Layout.fillWidth: true

                readonly property bool isActive:
                    backend && (backend.state === "listening" ||
                                backend.state === "identifying")

                text:      isActive ? i18n("Stop")          : i18n("Listen")
                icon.name: isActive ? "media-playback-stop" : "media-record"

                onClicked: {
                    if (!backend) return;
                    if (isActive) {
                        // Stop and disable continuous mode
                        if (searchTab.continuousSearch && searchTab.onToggleContinuous)
                            searchTab.onToggleContinuous();
                        backend.stopListening();
                    } else {
                        backend.startListening(
                            Plasmoid.configuration.deviceId,
                            Plasmoid.configuration.searchSeconds
                        );
                    }
                }
            }

            PlasmaComponents3.BusyIndicator {
                running: listenButton.isActive
                visible: running
                implicitWidth:  Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
        }
    }
}

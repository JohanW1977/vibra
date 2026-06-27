import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import Qt.labs.platform as Platform

Item {
    id: fullView

    property var  backend:           null
    property var  selectedTrack:     null
    property var  history:           []
    property bool continuousSearch:  false
    property var  onSelectTrack:     null
    property var  onClearHistory:    null
    property var  onToggleContinuous: null

    function resetToSearchTab() {
        tabBar.currentIndex = 0;
    }

    readonly property int bezel:     Kirigami.Units.smallSpacing * 2
    readonly property int barHeight: Kirigami.Units.gridUnit * 2
    readonly property int coverSide: height - barHeight - bezel * 2
    readonly property int panelWidth: coverSide + bezel * 2

    implicitWidth:  panelWidth * 2 + 1
    implicitHeight: Kirigami.Units.gridUnit * 31

    // ── Cover art save dialog ────────────────────────────────────────────
    Platform.FileDialog {
        id: coverSaveDialog
        title: i18n("Save cover art")
        fileMode: Platform.FileDialog.SaveFile
        nameFilters: [ i18n("JPEG images (*.jpg)"), i18n("All files (*)") ]
        defaultSuffix: "jpg"
        onAccepted: {
            if (fullView.selectedTrack && fullView.backend) {
                // coverArtStandard=false = HQ (800x800), true = standard (400x400)
                const url = Plasmoid.configuration.coverArtStandard
                    ? fullView.selectedTrack.coverUrl
                    : fullView.selectedTrack.coverUrl.replace("400x400cc", "800x800cc");
                fullView.backend.downloadFile(
                    url,
                    coverSaveDialog.file.toString().replace("file://", "")
                );
            }
        }
    }

    // ── LEFT PANEL ────────────────────────────────────────────────────────
    Item {
        id: leftPanel
        x: 0; y: 0
        width:  fullView.panelWidth
        height: fullView.height

        Rectangle {
            x:      fullView.bezel
            y:      fullView.bezel
            width:  fullView.coverSide
            height: fullView.coverSide
            color:  Kirigami.Theme.alternateBackgroundColor
            border.color: Kirigami.Theme.separatorColor || "#888888"
            border.width: 1
            radius: Kirigami.Units.cornerRadius || Kirigami.Units.smallSpacing
            clip: true

            Image {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 1
                fillMode: Image.PreserveAspectCrop
                source: fullView.selectedTrack
                        ? (Plasmoid.configuration.coverArtStandard
                           ? fullView.selectedTrack.coverUrl
                           : fullView.selectedTrack.coverUrl.replace("400x400cc", "800x800cc"))
                        : ""
                visible: source !== ""

                Behavior on source {
                    SequentialAnimation {
                        NumberAnimation { target: coverImage; property: "opacity"; to: 0; duration: 150 }
                        PropertyAction {}
                        NumberAnimation { target: coverImage; property: "opacity"; to: 1; duration: 150 }
                    }
                }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width:  Kirigami.Units.iconSizes.huge
                height: Kirigami.Units.iconSizes.huge
                source: "media-optical-audio"
                opacity: 0.4
                visible: !coverImage.visible
            }

            // Right-click menu on cover art
            QQC2.Menu {
                id: coverContextMenu
                QQC2.MenuItem {
                    text: i18n("Save cover art...")
                    icon.name: "document-save"
                    enabled: fullView.selectedTrack !== null
                    onTriggered: coverSaveDialog.open()
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && fullView.selectedTrack !== null)
                        coverContextMenu.popup();
                }
            }

            // Save button — bottom right, only visible on hover when cover art is shown
            PlasmaComponents3.ToolButton {
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Kirigami.Units.smallSpacing
                icon.name: "document-save"
                visible: fullView.selectedTrack !== null && coverImage.visible && coverHoverArea.containsMouse
                onClicked: coverSaveDialog.open()
                QQC2.ToolTip.text: i18n("Save cover art")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            // Hover detector for the cover art area
            MouseArea {
                id: coverHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }

        Row {
            x:      fullView.bezel
            y:      fullView.coverSide + fullView.bezel * 2
            height: fullView.barHeight
            spacing: Kirigami.Units.smallSpacing

            property bool hasTrack: fullView.selectedTrack !== null
            property string searchQuery: hasTrack
                ? encodeURIComponent(fullView.selectedTrack.artist + " " + fullView.selectedTrack.title)
                : ""
            property string noTrackTip: i18n("No detected track")

            ServiceButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  Math.round((Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2) * 0.85)
                implicitHeight: implicitWidth
                iconSource:  Qt.resolvedUrl("../images/youtube.svg")
                tooltipText: parent.hasTrack ? i18n("Search on YouTube") : parent.noTrackTip
                enabled:     parent.hasTrack
                grayscale:   !parent.hasTrack
                onClicked:   Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + parent.searchQuery)
            }
            ServiceButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  Math.round((Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2) * 0.85)
                implicitHeight: implicitWidth
                iconSource:  Qt.resolvedUrl("../images/discogs.svg")
                tooltipText: parent.hasTrack ? i18n("Search on Discogs") : parent.noTrackTip
                enabled:     parent.hasTrack
                grayscale:   !parent.hasTrack
                onClicked:   Qt.openUrlExternally("https://www.discogs.com/search/?q=" + parent.searchQuery)
            }
            ServiceButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  Math.round((Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2) * 0.85)
                implicitHeight: implicitWidth
                iconSource:  Qt.resolvedUrl("../images/spotify.svg")
                tooltipText: parent.hasTrack ? i18n("Search on Spotify") : parent.noTrackTip
                enabled:     parent.hasTrack
                grayscale:   !parent.hasTrack
                onClicked:   Qt.openUrlExternally("https://open.spotify.com/search/" + parent.searchQuery)
            }
            ServiceButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  Math.round((Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2) * 0.85)
                implicitHeight: implicitWidth
                iconSource:  Qt.resolvedUrl("../images/beatport.svg")
                tooltipText: parent.hasTrack ? i18n("Search on Beatport") : parent.noTrackTip
                enabled:     parent.hasTrack
                grayscale:   !parent.hasTrack
                onClicked:   Qt.openUrlExternally("https://www.beatport.com/search?q=" + parent.searchQuery)
            }
        }
    }

    Rectangle {
        x:      fullView.panelWidth
        y:      0
        width:  1
        height: fullView.height
        color:  Kirigami.Theme.disabledTextColor
        opacity: 0.3
    }

    // ── RIGHT PANEL ───────────────────────────────────────────────────────
    Item {
        id: rightPanel
        x:      fullView.panelWidth + 1
        y:      0
        width:  fullView.panelWidth
        height: fullView.height

        Loader {
            id: tabLoader
            x:      0
            y:      0
            width:  rightPanel.width
            height: rightPanel.height - tabBarItem.height

            source: tabBar.currentIndex === 0 ? "SearchTab.qml"
                  : tabBar.currentIndex === 1 ? "SettingsTab.qml"
                  :                             "InfoTab.qml"

            onLoaded: {
                if (item) {
                    item.backend           = Qt.binding(() => fullView.backend);
                    item.selectedTrack     = Qt.binding(() => fullView.selectedTrack);
                    item.history           = Qt.binding(() => fullView.history);
                    if ("continuousSearch" in item)
                        item.continuousSearch = Qt.binding(() => fullView.continuousSearch);
                    if ("onToggleContinuous" in item)
                        item.onToggleContinuous = function() {
                            if (fullView.onToggleContinuous) fullView.onToggleContinuous();
                        };
                }
            }

            function selectTrack(track) {
                if (fullView.onSelectTrack) fullView.onSelectTrack(track);
            }

            function clearHistory() {
                if (fullView.onClearHistory) fullView.onClearHistory();
            }

            function toggleContinuous() {
                if (fullView.onToggleContinuous) fullView.onToggleContinuous();
            }
        }

        Item {
            id: tabBarItem
            x:      0
            y:      rightPanel.height - height
            width:  rightPanel.width
            height: fullView.barHeight

            PlasmaComponents3.TabBar {
                id: tabBar
                anchors {
                    left: parent.left; top: parent.top
                    bottom: parent.bottom; right: pinArea.left
                }
                position: PlasmaComponents3.TabBar.Footer

                PlasmaComponents3.TabButton {
                    icon.name: "search"
                    text: i18n("Search")
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Search")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents3.TabButton {
                    icon.name: "configure"
                    text: i18n("Settings")
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Settings")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                PlasmaComponents3.TabButton {
                    icon.name: "help-about"
                    text: i18n("Info")
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Info")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            Item {
                id: pinArea
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: height

                PlasmaComponents3.ToolButton {
                    anchors.centerIn: parent
                    checkable: true
                    checked: Plasmoid.configuration.pin || false
                    icon.name: checked ? "window-pin" : "window-unpin"
                    onCheckedChanged: Plasmoid.configuration.pin = checked
                    QQC2.ToolTip.text: checked ? i18n("Keep Open") : i18n("Pin")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }
}

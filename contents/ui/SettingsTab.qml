import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: settingsTab

    property var backend:       null
    property var selectedTrack: null
    property var history:       null

    // ── Device list ───────────────────────────────────────────────────────
    property var devices: []

    function reloadDevices() {
        if (!backend) return;
        try {
            settingsTab.devices = JSON.parse(backend.deviceListJson);
        } catch(e) {
            settingsTab.devices = [{ id: "default", name: i18n("Default source") }];
        }
        syncDeviceCombo();
    }

    function syncDeviceCombo() {
        const stored = Plasmoid.configuration.deviceId || "default";
        for (let i = 0; i < settingsTab.devices.length; i++) {
            if (settingsTab.devices[i].id === stored) {
                deviceCombo.currentIndex = i;
                return;
            }
        }
        deviceCombo.currentIndex = 0;
    }

    onBackendChanged: {
        if (backend) {
            backend.deviceListChanged.connect(reloadDevices);
            reloadDevices();
        }
    }

    Component.onCompleted: {
        if (backend) {
            backend.deviceListChanged.connect(reloadDevices);
            reloadDevices();
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: flick.width
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.smallSpacing
                text: i18n("Settings")
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label { text: i18n("Source") }

                QQC2.ComboBox {
                    id: deviceCombo
                    Layout.fillWidth: true
                    model: {
                        let names = [];
                        for (let i = 0; i < settingsTab.devices.length; i++)
                            names.push(settingsTab.devices[i].name);
                        return names;
                    }
                    onActivated: {
                        if (currentIndex >= 0 && currentIndex < settingsTab.devices.length)
                            Plasmoid.configuration.deviceId = settingsTab.devices[currentIndex].id;
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: backend && backend.refreshDevices()
                    QQC2.ToolTip.text: i18n("Refresh device list")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Listen duration (s)")
                }
                QQC2.SpinBox {
                    from: 15; to: 60
                    stepSize: 5
                    value: Plasmoid.configuration.searchSeconds
                    onValueModified: Plasmoid.configuration.searchSeconds = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Show notifications when minimized")
                    color: notifSwitch.checked
                           ? Kirigami.Theme.positiveTextColor
                           : Kirigami.Theme.negativeTextColor
                }
                QQC2.Switch {
                    id: notifSwitch
                    checked: Plasmoid.configuration.showNotifications
                    onCheckedChanged: Plasmoid.configuration.showNotifications = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Show consecutive duplicates")
                    color: dupSwitch.checked
                           ? Kirigami.Theme.positiveTextColor
                           : Kirigami.Theme.negativeTextColor
                }
                QQC2.Switch {
                    id: dupSwitch
                    checked: Plasmoid.configuration.showDuplicates
                    onCheckedChanged: Plasmoid.configuration.showDuplicates = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Cover art quality")
                }
                QQC2.ComboBox {
                    Layout.fillWidth: true
                    model: [ i18n("High quality"), i18n("Standard quality") ]
                    currentIndex: Plasmoid.configuration.coverArtStandard ? 1 : 0
                    onActivated: Plasmoid.configuration.coverArtStandard = (currentIndex === 1)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: i18n("Start listening at startup")
                    color: autoListenSwitch.checked
                           ? Kirigami.Theme.positiveTextColor
                           : Kirigami.Theme.negativeTextColor
                }
                QQC2.Switch {
                    id: autoListenSwitch
                    checked: Plasmoid.configuration.autoListen
                    onCheckedChanged: Plasmoid.configuration.autoListen = checked
                }
            }

            Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
        }
    }
}

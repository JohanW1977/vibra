import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: infoTab

    // Injected by FullView Loader (unused here, but declared for consistency)
    property var backend:       null
    property var selectedTrack: null

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            Layout.minimumWidth: 200
            Layout.minimumHeight: 200
            Layout.maximumWidth: 200
            Layout.maximumHeight: 200

            source:  Qt.resolvedUrl("../images/logo.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.separatorColor
            Layout.topMargin:    Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("Version")
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label { text: "0.2" }
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("Release date")
                color: Kirigami.Theme.disabledTextColor
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label { text: "2026-06-24" }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.separatorColor
            Layout.topMargin:    Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Backend powered by")
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "<a href=\"https://github.com/BayernMuller/vibra\">vibra</a> " +
                  i18n("by") + " <b>Bayern Muller</b>"
            onLinkActivated: link => Qt.openUrlExternally(link)
            color: Kirigami.Theme.textColor
        }

        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Frontend powered by")
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "<a href=\"https://github.com/JohanW1977/vibra\">plasmoid</a> " +
                  i18n("by") + " <b>Johan Wauters</b>"
            onLinkActivated: link => Qt.openUrlExternally(link)
            color: Kirigami.Theme.textColor
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.separatorColor
            Layout.topMargin:    Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        Item {
            Layout.fillHeight: true
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Parts of the code are generated with " +
                "<a href=\"https://claude.ai\">Claude AI</a>" +
                " and " +
                "<a href=\"https://chatgpt.com\">ChatGPT</a>"

            textFormat: Text.RichText
            onLinkActivated: Qt.openUrlExternally(link)
            color: Kirigami.Theme.textColor
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "vibra is licensed under the GPLv3 license. See " +
                "<a href=\"https://github.com/BayernMuller/vibra/blob/main/LICENSE\">LICENSE</a>" +
                " for more details."

            textFormat: Text.RichText
            onLinkActivated: Qt.openUrlExternally(link)
            color: Kirigami.Theme.textColor
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: "<a href=\"https://www.shazam.com\">Shazam</a>" + " is a trademark from Apple Inc."
            textFormat: Text.RichText
            onLinkActivated: Qt.openUrlExternally(link)
            color: Kirigami.Theme.textColor
        }
    }
}

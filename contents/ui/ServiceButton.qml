import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami

QQC2.AbstractButton {
    id: control
    property string iconSource:  ""
    property string tooltipText: ""
    property bool   grayscale:   false

    implicitWidth:  Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
    implicitHeight: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius || Kirigami.Units.smallSpacing
        color: !control.enabled
               ? "transparent"
               : control.pressed
               ? Kirigami.Theme.highlightColor
               : control.hovered
               ? Kirigami.Theme.hoverColor
               : "transparent"
        border.color: control.enabled
                      ? Kirigami.Theme.separatorColor
                      : Kirigami.Theme.disabledTextColor
        border.width: 1
        opacity: control.enabled ? 1.0 : 0.4
        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    contentItem: Item {
        anchors.centerIn: parent
        width:  Kirigami.Units.iconSizes.smallMedium
        height: Kirigami.Units.iconSizes.smallMedium

        Image {
            id: iconImg
            anchors.fill: parent
            source: control.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false  // used as source for MultiEffect
        }

        MultiEffect {
            anchors.fill: parent
            source: iconImg
            saturation: control.grayscale ? -1.0 : 0.0
            opacity: control.grayscale ? 0.5 : (control.enabled ? 1.0 : 0.4)
        }
    }

    QQC2.ToolTip.text:    control.tooltipText
    QQC2.ToolTip.visible: hovered && tooltipText !== ""
    QQC2.ToolTip.delay:   Kirigami.Units.toolTipDelay
}

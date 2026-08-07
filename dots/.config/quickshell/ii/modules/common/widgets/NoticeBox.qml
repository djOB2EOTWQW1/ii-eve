import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property alias materialIcon: icon.text
    property alias text: noticeText.text
    default property alias boxData: buttonRow.data

    radius: Appearance.rounding.large
    color: Appearance.colors.colPrimaryContainer
    border.color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.8)
    border.width: 1
    
    implicitWidth: mainRowLayout.implicitWidth + mainRowLayout.anchors.margins * 2
    implicitHeight: mainRowLayout.implicitHeight + mainRowLayout.anchors.margins * 2

    RowLayout {
        id: mainRowLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        MaterialSymbol {
            id: icon
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            text: "info"
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.colors.colOnPrimaryContainer
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledText {
                id: noticeText
                Layout.fillWidth: true
                text: "Notice message"
                color: Appearance.colors.colOnPrimaryContainer
                wrapMode: Text.WordWrap
            }

            RowLayout {
                id: buttonRow
                visible: children.length > 0
                Layout.fillWidth: true 
            }
        }
    }
}

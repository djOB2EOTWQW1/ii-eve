import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string tagsString: ""
    property real cornerRadius: Appearance.rounding.small
    property var tagInputField
    signal closeRequested()

    readonly property var tagList: root.tagsString.split(/\s+/).filter(t => t.length > 0)

    radius: root.cornerRadius
    color: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.12)

    ColumnLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8

        RowLayout { // Header
            Layout.fillWidth: true
            MaterialSymbol {
                text: "sell"
                iconSize: 16
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: Translation.tr("Tags · %1").arg(root.tagList.length)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
            Item { Layout.fillWidth: true }
            RippleButton {
                implicitWidth: 24
                implicitHeight: 24
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.85)
                onClicked: root.closeRequested()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 14
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        StyledFlickable { // Scrollable tag list
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: tagFlow.implicitHeight
            clip: true

            Flow {
                id: tagFlow
                width: parent.width
                spacing: 5

                Repeater {
                    model: root.tagList
                    delegate: ApiCommandButton {
                        required property var modelData
                        buttonText: modelData
                        colBackground: Appearance.colors.colSecondaryContainer
                        onClicked: {
                            if (root.tagInputField.text.length !== 0) root.tagInputField.text += " "
                            root.tagInputField.text += modelData
                        }
                    }
                }
            }
        }
    }
}

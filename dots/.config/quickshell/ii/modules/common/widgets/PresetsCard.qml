import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property string imageSource: ""
    property string title: ""
    property string description: ""
    property var onApply: () => {}
    property var onRemove: () => {}
    property var onRename: (newName) => {}

    property bool isEditing: false

    implicitWidth: 290
    implicitHeight: contentColumn.implicitHeight + 16
    radius: Appearance.rounding.normal
    color: hoverHandler.hovered ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
    border.width: hoverHandler.hovered ? 2 : 1
    border.color: hoverHandler.hovered ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    HoverHandler {
        id: hoverHandler
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 0
        }
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 12
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                id: avatarShape
                shape: MaterialShape.Shape.Circle 
                text: root.title.length > 0 ? root.title.charAt(0).toUpperCase() : "?"
                iconSize: Appearance.font.pixelSize.normal
                implicitSize: 40
                font: Appearance.font.family.main
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: -2
                Layout.fillWidth: true
                visible: !root.isEditing

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.description.length > 0
                    text: root.description
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.isEditing

                MaterialTextField {
                    id: renameInput
                    Layout.fillWidth: true
                    text: root.title
                    placeholderText: Translation.tr("New Name")
                    onAccepted: confirmRenameBtn.clicked()
                }

                RippleButtonWithIcon {
                    id: confirmRenameBtn
                    materialIcon: "check"
                    mainText: ""
                    colBackground: Appearance.colors.colPrimaryContainer
                    onClicked: {
                        if (renameInput.text.trim() !== "" && renameInput.text.trim() !== root.title) {
                            root.onRename(renameInput.text.trim())
                        }
                        root.isEditing = false
                    }
                }
            }
        }

        // Wallpaper preview card
        Rectangle {
            id: imageRect
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            implicitHeight: 130
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            clip: true

            StyledImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.imageSource
                cache: false
                visible: status === Image.Ready && root.imageSource !== ""
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: imageRect.width
                        height: imageRect.height
                        radius: Appearance.rounding.small
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "auto_awesome"
                iconSize: 44
                color: Appearance.colors.colPrimary
                visible: root.imageSource === ""
            }
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            spacing: 6

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "check_circle"
                mainText: Translation.tr("Apply")
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: root.onApply()
            }

            RippleButtonWithIcon {
                materialIcon: "edit"
                mainText: ""
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.isEditing = !root.isEditing
            }

            RippleButtonWithIcon {
                materialIcon: "delete"
                mainText: ""
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.onRemove()
            }
        }
    }
}

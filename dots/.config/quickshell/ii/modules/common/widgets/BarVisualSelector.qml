import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: 210
    color: Appearance.colors.colLayer2
    radius: Appearance.rounding.normal
    border.color: Appearance.colors.colLayer0Border
    border.width: 1

    property int barPosition: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
    // 0 = Top, 2 = Left, 1 = Bottom, 3 = Right

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20

        // Visual Desktop Preview Diagram
        Item {
            id: screenMonitor
            Layout.preferredWidth: 260
            Layout.preferredHeight: 160
            Layout.alignment: Qt.AlignVCenter

            // Outer Monitor Frame
            Rectangle {
                anchors.fill: parent
                color: Appearance.m3colors.m3surfaceContainerLowest
                radius: Appearance.rounding.small
                border.color: Appearance.colors.colPrimary
                border.width: 2

                // Wallpaper background inside preview monitor
                ThumbnailImage {
                    anchors.fill: parent
                    anchors.margins: 4
                    sourcePath: Config.options.background.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    generateThumbnail: true
                    thumbnailSizeName: Images.thumbnailSizeNameForDimensions(256, 160)
                    sourceSize: Qt.size(256, 160)
                }

                // Interactive Bar Overlays
                // TOP BAR
                Rectangle {
                    id: topBarRegion
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 6
                    }
                    height: 18
                    radius: Config.options.bar.cornerStyle === 1 ? 9 : (Config.options.bar.cornerStyle === 0 ? 4 : 0)
                    color: root.barPosition === 0 ? Appearance.colors.colPrimary : (topBarHover.hovered ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3)
                    opacity: root.barPosition === 0 ? 0.95 : 0.6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        MaterialSymbol {
                            text: "widgets"
                            iconSize: 10
                            color: root.barPosition === 0 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 10
                            color: root.barPosition === 0 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                    }

                    HoverHandler { id: topBarHover }
                    TapHandler {
                        onTapped: {
                            Config.options.bar.bottom = false
                            Config.options.bar.vertical = false
                        }
                    }
                }

                // LEFT BAR
                Rectangle {
                    id: leftBarRegion
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        margins: 6
                    }
                    width: 18
                    radius: Config.options.bar.cornerStyle === 1 ? 9 : (Config.options.bar.cornerStyle === 0 ? 4 : 0)
                    color: root.barPosition === 2 ? Appearance.colors.colPrimary : (leftBarHover.hovered ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3)
                    opacity: root.barPosition === 2 ? 0.95 : 0.6

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        MaterialSymbol {
                            text: "widgets"
                            iconSize: 10
                            color: root.barPosition === 2 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Item { Layout.fillHeight: true }
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 10
                            color: root.barPosition === 2 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    HoverHandler { id: leftBarHover }
                    TapHandler {
                        onTapped: {
                            Config.options.bar.bottom = false
                            Config.options.bar.vertical = true
                        }
                    }
                }

                // BOTTOM BAR
                Rectangle {
                    id: bottomBarRegion
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: 6
                    }
                    height: 18
                    radius: Config.options.bar.cornerStyle === 1 ? 9 : (Config.options.bar.cornerStyle === 0 ? 4 : 0)
                    color: root.barPosition === 1 ? Appearance.colors.colPrimary : (bottomBarHover.hovered ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3)
                    opacity: root.barPosition === 1 ? 0.95 : 0.6

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        MaterialSymbol {
                            text: "widgets"
                            iconSize: 10
                            color: root.barPosition === 1 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 10
                            color: root.barPosition === 1 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                    }

                    HoverHandler { id: bottomBarHover }
                    TapHandler {
                        onTapped: {
                            Config.options.bar.bottom = true
                            Config.options.bar.vertical = false
                        }
                    }
                }

                // RIGHT BAR
                Rectangle {
                    id: rightBarRegion
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        margins: 6
                    }
                    width: 18
                    radius: Config.options.bar.cornerStyle === 1 ? 9 : (Config.options.bar.cornerStyle === 0 ? 4 : 0)
                    color: root.barPosition === 3 ? Appearance.colors.colPrimary : (rightBarHover.hovered ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3)
                    opacity: root.barPosition === 3 ? 0.95 : 0.6

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        MaterialSymbol {
                            text: "widgets"
                            iconSize: 10
                            color: root.barPosition === 3 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Item { Layout.fillHeight: true }
                        MaterialSymbol {
                            text: "schedule"
                            iconSize: 10
                            color: root.barPosition === 3 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    HoverHandler { id: rightBarHover }
                    TapHandler {
                        onTapped: {
                            Config.options.bar.bottom = true
                            Config.options.bar.vertical = true
                        }
                    }
                }
            }
        }

        // Controls Column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            StyledText {
                text: Translation.tr("Interactive Bar Placement")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
            }

            StyledText {
                text: Translation.tr("Click any side on the monitor preview to quickly move the shell bar.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 8
                Layout.topMargin: 4

                ConfigSelectionArray {
                    currentValue: root.barPosition
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                        { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                    ]
                }
            }
        }
    }
}

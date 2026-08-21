import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: heroContentLayout.implicitHeight + 36
    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    border.color: Appearance.colors.colLayer0Border
    border.width: 1

    ColumnLayout {
        id: heroContentLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 18
        }
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            RowLayout {
                spacing: 12
                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "tune"
                        iconSize: 22
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: Translation.tr("illogical-impulse")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("System & Shell Control Center")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Quick Status Telemetry Chips
            Flow {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                // Dark/Light Mode Chip
                Rectangle {
                    implicitHeight: 30
                    implicitWidth: modeRow.implicitWidth + 18
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                            iconSize: 14
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Appearance.m3colors.darkmode ? Translation.tr("Dark Theme") : Translation.tr("Light Theme")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }

                // Bar Position Chip
                Rectangle {
                    implicitHeight: 30
                    implicitWidth: barPosRow.implicitWidth + 18
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: barPosRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: Config.options.bar.vertical ? "view_sidebar" : "page_header"
                            iconSize: 14
                            color: Appearance.colors.colSecondary
                        }
                        StyledText {
                            text: (Config.options.bar.vertical ? (Config.options.bar.bottom ? Translation.tr("Right Bar") : Translation.tr("Left Bar")) : (Config.options.bar.bottom ? Translation.tr("Bottom Bar") : Translation.tr("Top Bar")))
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }

                // Hyprland Layout Chip
                Rectangle {
                    implicitHeight: 30
                    implicitWidth: layoutRow.implicitWidth + 18
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: layoutRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: Persistent.states.hyprland.layout === "scrolling" ? "view_carousel" : "dashboard"
                            iconSize: 14
                            color: Appearance.colors.colTertiary
                        }
                        StyledText {
                            text: Persistent.states.hyprland.layout === "scrolling" ? Translation.tr("Scrolling") : Translation.tr("Dwindle")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
        }

        // Action Cards Grid
        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 680 ? 4 : 2
            columnSpacing: 10
            rowSpacing: 10

            // Dark/Light Mode Preference Switcher Card
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 56
                buttonRadius: Appearance.rounding.normal
                colBackground: Appearance.m3colors.darkmode ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                onClicked: {
                    const newMode = Appearance.m3colors.darkmode ? "light" : "dark"
                    Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${newMode} --noswitch`]);
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    MaterialSymbol {
                        text: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                        iconSize: 22
                        color: Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Theme Mode")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Appearance.m3colors.darkmode ? Translation.tr("Dark") : Translation.tr("Light")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Transparency Toggle Card
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 56
                buttonRadius: Appearance.rounding.normal
                colBackground: Config.options.appearance.transparency.enable ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                onClicked: {
                    Config.options.appearance.transparency.enable = !Config.options.appearance.transparency.enable
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    MaterialSymbol {
                        text: "ev_shadow"
                        iconSize: 22
                        color: Config.options.appearance.transparency.enable ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Transparency")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Config.options.appearance.transparency.enable ? Translation.tr("Enabled") : Translation.tr("Disabled")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Audio Protection Toggle Card
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 56
                buttonRadius: Appearance.rounding.normal
                colBackground: Config.options.audio.protection.enable ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                onClicked: {
                    Config.options.audio.protection.enable = !Config.options.audio.protection.enable
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    MaterialSymbol {
                        text: "hearing"
                        iconSize: 22
                        color: Config.options.audio.protection.enable ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Earbang Guard")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Config.options.audio.protection.enable ? Translation.tr("Protected") : Translation.tr("Off")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Hyprland Layout Toggle Card
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 56
                buttonRadius: Appearance.rounding.normal
                colBackground: Persistent.states.hyprland.layout === "scrolling" ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                onClicked: {
                    if (Persistent.states.hyprland.layout === "scrolling") {
                        HyprlandSettings.setLayout(Config.options.hyprland.defaultHyprlandLayout || "dwindle")
                    } else {
                        HyprlandSettings.setLayout("scrolling")
                    }
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    MaterialSymbol {
                        text: Persistent.states.hyprland.layout === "scrolling" ? "view_carousel" : "dashboard"
                        iconSize: 22
                        color: Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Layout")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Persistent.states.hyprland.layout === "scrolling" ? Translation.tr("Scrolling") : Translation.tr("Dwindle")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}

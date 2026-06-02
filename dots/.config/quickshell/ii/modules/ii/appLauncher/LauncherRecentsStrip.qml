import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Horizontal Recent/Frequent strip shown above the app grid. Mouse-only
// (deliberately excluded from vimium hints — see plan/spec YAGNI notes).
ColumnLayout {
    id: root

    // Reference to LauncherContent's root (for closing on activate, etc.).
    property var launcher

    readonly property string mode: Persistent.states.appLauncher?.recentsMode ?? "recent"
    readonly property var model: root.mode === "frequent"
        ? CustomApps.frequentApps
        : CustomApps.recentApps

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 6

        StyledText {
            text: root.mode === "frequent"
                ? Translation.tr("Frequent")
                : Translation.tr("Recent")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        Item { Layout.fillWidth: true }

        RippleButton {
            implicitHeight: 24
            buttonRadius: Appearance.rounding.full
            onClicked: {
                const al = Persistent.states.appLauncher
                if (!al) return
                al.recentsMode = (root.mode === "recent") ? "frequent" : "recent"
            }
            contentItem: RowLayout {
                spacing: 3
                MaterialSymbol {
                    text: root.mode === "frequent" ? "trending_up" : "history"
                    iconSize: 16
                }
                StyledText {
                    text: root.mode === "frequent"
                        ? Translation.tr("Frequent")
                        : Translation.tr("Recent")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: 64
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        model: root.model

        delegate: Item {
            id: tile
            required property var modelData
            width: 64
            height: 64

            readonly property bool tileRunning: !!tile.modelData?.path
                && CustomApps.isPathRunning(tile.modelData.path)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Appearance.rounding.normal
                color: tileArea.containsMouse
                    ? Appearance.colors.colLayer3
                    : "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: {
                            const icon = tile.modelData?.icon || ""
                            if (icon.startsWith("/")) return "file://" + icon
                            return Quickshell.iconPath(icon, "application-x-executable")
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        text: tile.modelData?.name ?? ""
                    }
                }

                Rectangle {
                    visible: tile.tileRunning
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 2
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: height / 2
                    color: Appearance.colors.colPrimary
                    z: 3
                }

                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        CustomApps.activate(tile.modelData)
                        GlobalStates.appLauncherOpen = false
                    }
                }
            }
        }
    }
}

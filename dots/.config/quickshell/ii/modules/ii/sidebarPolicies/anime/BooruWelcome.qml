import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property var tagInputField
    signal searchRequested(string text)

    readonly property var recent: Persistent.states.booru.searchHistory ?? []

    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 4
        }
        spacing: 12

        ProviderChipStrip { // Provider switcher
            Layout.fillWidth: true
        }

        Rectangle { // Hero banner
            Layout.fillWidth: true
            implicitHeight: 150
            radius: Appearance.rounding.normal
            color: Appearance.colors.colPrimaryContainer

            MaterialShape {
                id: heroShape
                shapeString: "Cookie9Sided"
                implicitSize: 96
                color: Appearance.colors.colPrimary
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    margins: 20
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "bookmark_heart"
                    iconSize: 44
                    color: Appearance.colors.colOnPrimary
                }
            }

            Rectangle { // Provider pill
                anchors {
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                radius: Appearance.rounding.full
                color: Appearance.colors.colOnPrimary
                implicitHeight: pillRow.implicitHeight + 10
                implicitWidth: pillRow.implicitWidth + 20

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: "api"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Booru.providers[Booru.currentProvider]?.name ?? Booru.currentProvider
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }

            StyledText { // Title
                text: Translation.tr("Anime boorus")
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: 6
                    margins: 20
                }
                horizontalAlignment: Text.AlignRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.hugeass
                    weight: Font.Black
                }
                color: Appearance.colors.colOnPrimaryContainer
            }

            StyledText { // Subtitle
                text: Translation.tr("Search any tag")
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 20
                }
                horizontalAlignment: Text.AlignRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.large
                    weight: Font.Black
                }
                opacity: 0.85
                color: Appearance.colors.colOnPrimaryContainer
            }
        }

        StyledText { // Popular label
            text: Translation.tr("Popular")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            Layout.leftMargin: 4
        }

        FlowButtonGroup { // Popular tags
            Layout.fillWidth: true
            spacing: 7
            Repeater {
                model: Config.options.sidebar.booru.popularTags ?? []
                delegate: ApiCommandButton {
                    required property var modelData
                    buttonText: modelData
                    colBackground: Appearance.colors.colSecondaryContainer
                    onClicked: {
                        root.tagInputField.text = modelData
                        root.searchRequested(modelData)
                    }
                }
            }
        }

        StyledText { // Recent label
            visible: root.recent.length > 0
            text: Translation.tr("Recent")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            Layout.leftMargin: 4
        }

        Repeater { // Recent searches (inline)
            model: root.recent
            delegate: RippleButton {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: recentRow.implicitHeight + 18
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover

                onClicked: {
                    const entry = modelData
                    const searchText = entry.tags.join(" ") + (entry.page > 1 ? " " + entry.page : "")
                    if (entry.provider && entry.provider !== Booru.currentProvider) {
                        Booru.setProvider(entry.provider)
                    }
                    root.tagInputField.text = searchText
                    root.searchRequested(searchText)
                }

                contentItem: RowLayout {
                    id: recentRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: 11
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 9
                    MaterialSymbol {
                        text: "undo"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.tags?.join(", ") || Translation.tr("[no tags]")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: Translation.tr("p%1 · %2")
                            .arg(modelData.page ?? 1)
                            .arg(Booru.providers[modelData.provider]?.name ?? modelData.provider ?? "?")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}

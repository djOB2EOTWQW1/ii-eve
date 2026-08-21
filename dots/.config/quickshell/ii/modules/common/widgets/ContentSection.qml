import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property string title
    property string icon: ""
    property string tooltip: ""
    property list<string> stringMap: []
    default property alias contentData: sectionContent.data

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 32
    implicitWidth: mainLayout.implicitWidth + 32

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    border.color: Appearance.colors.colLayer0Border
    border.width: 1

    Component.onCompleted: {
        if (page?.register == false) return
        // console.log("KEYWORDS", root.stringMap)
        if (!page?.index) return
        SearchRegistry.registerSection({
            pageIndex: page?.index,
            title: root.title,
            searchStrings: root.stringMap.slice(),
            yPos: root.y
        })
    }

    function addKeyword(word) {
        if (!word) return
        // console.log("ADD KEYWORD", word)
        stringMap.push(word)
    }

    SearchHandler {
        searchString: root.title
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            spacing: 8
            OptionalMaterialSymbol {
                opacity: 1 - highlightOverlay.opacity
                icon: root.icon
                iconSize: Appearance.font.pixelSize.hugeass
            }
            StyledText {
                opacity: 1 - highlightOverlay.opacity
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
            MaterialSymbol {
                opacity: 1 - highlightOverlay.opacity
                visible: root.tooltip && root.tooltip.length > 0
                text: "info"
                iconSize: Appearance.font.pixelSize.larger
                
                color: Appearance.colors.colSubtext
                MouseArea {
                    id: infoMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.WhatsThisCursor
                    StyledToolTip {
                        extraVisibleCondition: false
                        alternativeVisibleCondition: infoMouseArea.containsMouse
                        text: root.tooltip
                    }
                }
            }
            HighlightOverlay {
                id: highlightOverlay
                visible: false
            }
        }

        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: 8
        }
    }
}

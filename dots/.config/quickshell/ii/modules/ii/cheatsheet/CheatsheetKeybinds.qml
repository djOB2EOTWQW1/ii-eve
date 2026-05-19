pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property real padding: 4
    implicitWidth: QsWindow?.window?.screen.width * 0.7 ?? 0
    implicitHeight: QsWindow?.window?.screen.height * 0.7 ?? 0

    readonly property string query: CheatsheetSearch.query
    readonly property string normalizedQuery: query.trim().toLowerCase()

    // Search predicate is owned here so the empty-state counter and the cards
    // filter through the exact same logic — drift between them would be a UX bug.
    function modMaskToStringList(modMask) {
        var list = [];
        if (modMask & (1 << 2)) list.push("Ctrl");
        if (modMask & (1 << 6)) list.push("Super");
        if (modMask & (1 << 0)) list.push("Shift");
        if (modMask & (1 << 3)) list.push("Alt");
        if (modMask & (1 << 1)) list.push("Caps");
        if (modMask & (1 << 4)) list.push("Mod2");
        if (modMask & (1 << 5)) list.push("Mod3");
        if (modMask & (1 << 7)) list.push("Mod5");
        return list;
    }
    function categoryOf(bind) {
        const d = bind.description ?? "";
        const i = d.indexOf(":");
        return i === -1 ? "" : d.substring(0, i);
    }
    function bindMatches(bind, categoryName) {
        const q = root.normalizedQuery;
        if (q === "") return true;
        if (categoryName && categoryName.toLowerCase().includes(q)) return true;
        let blob = bind.__searchBlob;
        if (blob === undefined) {
            blob = [...root.modMaskToStringList(bind.modmask), bind.key ?? "", bind.description ?? ""].join(" ").toLowerCase();
            bind.__searchBlob = blob;
        }
        return blob.includes(q);
    }

    readonly property int matchCount: {
        if (root.normalizedQuery === "") return -1;
        let n = 0;
        const binds = HyprlandKeybinds.keybinds;
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i];
            if ((b.description?.length ?? 0) > 0 && root.bindMatches(b, root.categoryOf(b))) n++;
        }
        return n;
    }
    readonly property bool isEmpty: root.matchCount === 0

    focus: true
    Component.onCompleted: root.forceActiveFocus()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            CheatsheetSearch.query = "";
            searchField.text = "";
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Slash) {
            searchField.forceActiveFocus();
            event.accepted = true;
            return;
        }
        const t = event.text;
        const blocked = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (t.length === 1 && t.charCodeAt(0) >= 0x20 && !blocked) {
            searchField.forceActiveFocus();
            searchField.text += t;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.rounding.small
        spacing: 10

        MaterialTextField {
            id: searchField
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            placeholderText: "Search keybinds"
            text: CheatsheetSearch.query
            onTextChanged: CheatsheetSearch.query = text
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    text = "";
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }
        }

        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledFlickable {
                id: flickable
                anchors.fill: parent
                contentHeight: height
                contentWidth: flow.implicitWidth
                opacity: root.isEmpty ? 0 : 1
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Flow {
                    id: flow
                    height: flickable.height
                    flow: Flow.TopToBottom
                    spacing: 10
                    Repeater {
                        model: [...HyprlandKeybinds.keybindCategories, ""]
                        delegate: CheatsheetKeybindsCategory {
                            required property var modelData
                            categoryName: modelData
                            cheatsheet: root
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                opacity: root.isEmpty ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "search_off"
                    iconSize: Appearance.font.pixelSize.huge * 1.6
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    color: Appearance.m3colors.m3onSurfaceVariant
                    text: `No keybinds match "${root.query}"`
                }
            }
        }
    }
}

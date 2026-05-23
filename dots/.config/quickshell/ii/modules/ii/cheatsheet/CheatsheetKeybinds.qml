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
    property bool editMode: false
    implicitWidth: QsWindow?.window?.screen.width * 0.7 ?? 0
    implicitHeight: QsWindow?.window?.screen.height * 0.7 ?? 0

    readonly property string query: CheatsheetSearch.query
    readonly property string normalizedQuery: query.trim().toLowerCase()

    // Predicates live here so the empty-state counter and the cards filter through one source.
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

    function requestEdit(keyData, combo, category) {
        const desc = keyData.description ?? "";
        const idx = desc.indexOf(":");
        const descNoCat = idx >= 0 ? desc.substring(idx + 1).trim() : desc;
        const cat = idx >= 0 ? desc.substring(0, idx).trim() : (category ?? "");
        const source = KeybindsEditor.findSourceFor(combo);
        if (source === "generated") return;
        keybindDialog.open({
            mode: "edit",
            combo: combo,
            category: cat,
            description: descNoCat,
            source: source,
        });
    }

    function requestAdd(category) {
        keybindDialog.open({
            mode: "add",
            presetCategory: category || "Misc",
            source: "custom",
        });
    }

    function requestDelete(keyData, combo) {
        const source = KeybindsEditor.findSourceFor(combo);
        if (source === "generated") return;
        KeybindsEditor.applyDelete({ source: source, combo: combo });
    }

    Connections {
        target: KeybindsEditor
        function onApplyFinished(operation, result) {
            if (result.ok) {
                keybindDialog.visible = false;
                snackbar.show(operation === "delete" ? "Keybind deleted" : "Keybind saved");
            } else {
                snackbar.show("Failed: " + (result.error || "unknown error"));
            }
        }
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
    Component.onCompleted: searchField.forceActiveFocus()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            CheatsheetSearch.query = "";
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
            searchInput.text += t;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.rounding.small
        spacing: 14

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            // Pill-shaped search bar with a leading search glyph — matches the look of the screenshot.
            Item {
                id: searchField
                Layout.preferredWidth: 460
                Layout.preferredHeight: 44
                function forceActiveFocus() { searchInput.forceActiveFocus(); }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colSurfaceContainer
                    radius: Appearance.rounding.full
                }
                MaterialSymbol {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    iconSize: Appearance.font.pixelSize.large
                    color: searchInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
                }
                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Appearance.colors.colOnLayer0
                    selectionColor: Appearance.colors.colSecondaryContainer
                    selectedTextColor: Appearance.colors.colOnSecondaryContainer
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    Component.onCompleted: text = CheatsheetSearch.query
                    onTextChanged: CheatsheetSearch.query = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (text.length > 0) text = "";
                            else root.forceActiveFocus();
                            event.accepted = true;
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: searchInput.text.length === 0
                        text: "Search keybinds"
                        color: Appearance.m3colors.m3onSurfaceVariant
                        font.pixelSize: searchInput.font.pixelSize
                    }
                }
            }

            // Edit-mode toggle, visible only when allowEditing is on.
            Rectangle {
                id: editToggle
                visible: Config.options.cheatsheet.allowEditing
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Appearance.rounding.full
                color: root.editMode
                    ? Appearance.m3colors.m3primary
                    : Appearance.colors.colSurfaceContainer
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "edit"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.editMode
                        ? Appearance.m3colors.m3onPrimary
                        : Appearance.m3colors.m3onSurfaceVariant
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editMode = !root.editMode
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
                    spacing: 12
                    // Survivors glide to their repacked slots after non-matching cards fade out.
                    move: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
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

    KeybindEditDialog {
        id: keybindDialog
        visible: false
        onCanceled: visible = false
        onSaved: payload => {
            if (payload.mode === "edit") {
                if (payload.combo === payload.originalCombo) {
                    KeybindsEditor.applySetDescription({
                        source: payload.source,
                        combo: payload.combo,
                        description: payload.description,
                        category: payload.category,
                    });
                } else {
                    KeybindsEditor.applyEdit({
                        source: payload.source,
                        oldCombo: payload.originalCombo,
                        newCombo: payload.combo,
                        description: payload.description,
                        category: payload.category,
                    });
                }
            } else {
                KeybindsEditor.applyAdd({
                    combo: payload.combo,
                    command: payload.command,
                    description: payload.description,
                    category: payload.category,
                });
            }
        }
    }

    Item {
        id: snackbar
        function show(_msg) { /* implemented in Task 12 */ }
    }
}

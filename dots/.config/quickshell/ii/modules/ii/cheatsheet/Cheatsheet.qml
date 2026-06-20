import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
Scope { // Scope
    id: root

    // cheatsheetPages contribution point: external extension tabs
    property var extensionPages: ExtensionManager.ready ? ExtensionManager.getContributionPoint("cheatsheetPages") : []
    Connections {
        target: ExtensionManager
        function onRefreshExtensions() { root.extensionPages = ExtensionManager.getContributionPoint("cheatsheetPages") }
        function onExtensionInstalled() { root.extensionPages = ExtensionManager.getContributionPoint("cheatsheetPages") }
        function onExtensionRemoved() { root.extensionPages = ExtensionManager.getContributionPoint("cheatsheetPages") }
        function onExtensionToggled() { root.extensionPages = ExtensionManager.getContributionPoint("cheatsheetPages") }
    }
    readonly property var extensionTabs: root.extensionPages.map(p => ({
        key: "ext:" + p.extensionId + ":" + p.identifier,
        icon: p.icon || "extension",
        name: p.title || p.identifier,
        component: ExtensionManager.loadExtensionQmlComponent(p.fullPath),
        extensionId: p.extensionId
    }))

    readonly property var visibleTabs: root.extensionTabs

    readonly property var tabButtonList: root.visibleTabs.map(t => ({ icon: t.icon, name: t.name }))

    Loader {
        id: cheatsheetLoader
        active: false

        sourceComponent: PanelWindow { // Window
            id: cheatsheetRoot
            visible: cheatsheetLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                cheatsheetLoader.active = false;
            }
            exclusiveZone: 0
            implicitWidth: cheatsheetBackground.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: cheatsheetBackground.height + Appearance.sizes.elevationMargin * 2
            WlrLayershell.namespace: "quickshell:cheatsheet"
            // OnDemand at map time hangs the surface for ~5s on some compositors.
            // Map with None first, then upgrade to OnDemand after the panel is visible,
            // and only on tabs that actually need text input (Commands).
            property bool _focusReady: false
            WlrLayershell.keyboardFocus: {
                if (!_focusReady) return WlrKeyboardFocus.None;
                const icon = root.tabButtonList[swipeView.currentIndex]?.icon;
                // Keybinds tab also needs OnDemand so the search field can take text input.
                return (icon === "terminal" || icon === "keyboard")
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None;
            }
            Timer {
                id: focusUpgradeTimer
                interval: 80
                repeat: false
                onTriggered: {
                    cheatsheetRoot._focusReady = true;
                    cheatsheetRoot.focusCurrentTab();
                }
            }
            function focusCurrentTab() {
                const loader = swipeView.itemAt(swipeView.currentIndex);
                if (loader && loader.item) loader.item.forceActiveFocus();
            }
            onVisibleChanged: {
                if (visible) focusUpgradeTimer.start();
                else _focusReady = false;
            }
            color: "transparent"

            mask: Region {
                item: cheatsheetBackground
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(cheatsheetRoot);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(cheatsheetRoot);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    cheatsheetRoot.hide();
                }
            }

            // Background
            StyledRectangularShadow {
                target: cheatsheetBackground
            }
            Rectangle {
                id: cheatsheetBackground
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.windowRounding
                property real padding: 20
                implicitWidth: cheatsheetColumnLayout.implicitWidth + padding * 2
                implicitHeight: cheatsheetColumnLayout.implicitHeight + padding * 2

                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        cheatsheetRoot.hide();
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_PageDown) {
                            tabBar.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
                            tabBar.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            tabBar.setCurrentIndex((tabBar.currentIndex + 1) % root.tabButtonList.length);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            tabBar.setCurrentIndex((tabBar.currentIndex - 1 + root.tabButtonList.length) % root.tabButtonList.length);
                            event.accepted = true;
                        }
                    }
                }

                RippleButton { // Close button
                    id: closeButton
                    focusPolicy: Qt.NoFocus
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 20
                        rightMargin: 20
                    }

                    onClicked: {
                        cheatsheetRoot.hide();
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.title
                        text: "close"
                    }
                }

                ColumnLayout { // Real content
                    id: cheatsheetColumnLayout
                    anchors.centerIn: parent
                    spacing: 10

                    Toolbar {
                        Layout.alignment: Qt.AlignHCenter
                        enableShadow: false
                        ToolbarTabBar {
                            id: tabBar
                            tabButtonList: root.tabButtonList

                            Synchronizer on currentIndex {
                                property alias source: swipeView.currentIndex
                            }
                        }
                    }

                    SwipeView { // Content pages
                        id: swipeView
                        Layout.topMargin: 5
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        currentIndex: Persistent.states.cheatsheet.tabIndex
                        onCurrentIndexChanged: {
                            Persistent.states.cheatsheet.tabIndex = currentIndex;
                            if (cheatsheetRoot._focusReady) cheatsheetRoot.focusCurrentTab();
                        }

                        Connections {
                            target: root
                            function onTabButtonListChanged() {
                                if (swipeView.currentIndex >= root.tabButtonList.length) {
                                    swipeView.currentIndex = Math.max(0, root.tabButtonList.length - 1);
                                }
                            }
                        }

                        implicitWidth: Math.max.apply(null, contentChildren.map(child => child.implicitWidth || 0))
                        implicitHeight: Math.max.apply(null, contentChildren.map(child => child.implicitHeight || 0))

                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: swipeView.width
                                height: swipeView.height
                                radius: Appearance.rounding.small
                            }
                        }

                        Repeater {
                            model: root.visibleTabs
                            delegate: Loader {
                                required property var modelData
                                sourceComponent: modelData.component
                                onLoaded: {
                                    if (modelData.extensionId && item) {
                                        if ("extensionId" in item) {
                                            item.extensionId = modelData.extensionId;
                                        } else {
                                            Object.defineProperty(item, "extensionId", {
                                                value: modelData.extensionId,
                                                writable: true,
                                                configurable: true,
                                                enumerable: true
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }

        function close(): void {
            cheatsheetLoader.active = false;
        }

        function open(): void {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggles cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = !cheatsheetLoader.active;
        }
    }

    GlobalShortcut {
        name: "cheatsheetOpen"
        description: "Opens cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = true;
        }
    }

    GlobalShortcut {
        name: "cheatsheetClose"
        description: "Closes cheatsheet on press"

        onPressed: {
            cheatsheetLoader.active = false;
        }
    }
}

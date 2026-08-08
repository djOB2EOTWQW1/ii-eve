import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: page
    readonly property int index: 6
    property bool register: parent.register ?? false
    property bool isLoaded: false

    property var monitorsList: HyprlandData.monitors && HyprlandData.monitors.length > 0 ? HyprlandData.monitors : [
        {
            name: "eDP-1",
            description: "AU Optronics 0x978F",
            width: 1920,
            height: 1080,
            refreshRate: 144.03,
            transform: 0,
            scale: 1,
            x: 0,
            y: 0,
            focused: true,
            availableModes: ["1920x1080@144.03Hz", "1920x1080@60.02Hz"]
        }
    ]
    property int selectedMonitorIndex: 0
    readonly property var currentMonitor: monitorsList[selectedMonitorIndex] || monitorsList[0]

    // Per-monitor state maps for previewing before applying
    property var previewTransforms: ({})
    property var previewModes: ({})
    property var previewScales: ({})

    // Input settings states (defaulting to safe values without mutating mouse sensitivity)
    property bool inputNaturalScroll: true
    property bool inputTapToClick: true
    property bool inputDisableWhileTyping: true
    property int inputRepeatRate: 35
    property int inputRepeatDelay: 250

    // Window Opacity & Dimming states
    property bool dimInactive: false
    property int dimStrength: 20
    property int activeOpacity: 100
    property int inactiveOpacity: 100

    // Dynamic available modes for the CURRENTLY SELECTED monitor
    readonly property var availableModes: {
        if (!currentMonitor || !currentMonitor.availableModes || currentMonitor.availableModes.length === 0) {
            const w = currentMonitor?.width || 1920
            const h = currentMonitor?.height || 1080
            const hz = Math.round(currentMonitor?.refreshRate || 60)
            return [
                { displayName: `${w}x${h} @ ${hz}Hz`, modeString: `${w}x${h}@${hz}Hz`, hz: hz }
            ]
        }

        let result = []
        for (let i = 0; i < currentMonitor.availableModes.length; i++) {
            let modeStr = currentMonitor.availableModes[i]
            let parts = modeStr.split("@")
            let hzVal = 60
            if (parts.length > 1) {
                hzVal = parseFloat(parts[1].replace("Hz", ""))
            }
            result.push({
                displayName: modeStr,
                modeString: modeStr,
                hz: hzVal
            })
        }
        return result
    }

    function getPreviewTransform(monName) {
        if (previewTransforms[monName] !== undefined) return previewTransforms[monName]
        const mon = monitorsList.find(m => m.name === monName)
        return mon?.transform || 0
    }

    function setPreviewTransform(monName, val) {
        let temp = Object.assign({}, previewTransforms)
        temp[monName] = val
        previewTransforms = temp
    }

    function getPreviewMode(monName) {
        if (previewModes[monName] !== undefined) return previewModes[monName]
        const mon = monitorsList.find(m => m.name === monName)
        if (mon && mon.availableModes && mon.availableModes.length > 0) {
            return mon.availableModes[0]
        }
        return (mon?.width || 1920) + "x" + (mon?.height || 1080) + "@" + (mon?.refreshRate || 60) + "Hz"
    }

    function setPreviewMode(monName, val) {
        let temp = Object.assign({}, previewModes)
        temp[monName] = val
        previewModes = temp
    }

    function getPreviewScale(monName) {
        if (previewScales[monName] !== undefined) return previewScales[monName]
        const mon = monitorsList.find(m => m.name === monName)
        return mon?.scale || 1.0
    }

    function setPreviewScale(monName, val) {
        let temp = Object.assign({}, previewScales)
        temp[monName] = val
        previewScales = temp
    }

    Process {
        id: fetchMonitorsProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(monitorsCollector.text);
                    if (parsed && parsed.length > 0) {
                        page.monitorsList = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function reloadMonitors() {
        fetchMonitorsProc.running = false
        fetchMonitorsProc.running = true
    }

    function applyMonitorSettings(monName, modeStr, transformVal, scaleVal) {
        if (!page.isLoaded) return
        const mon = page.monitorsList.find(m => m.name === monName) || page.currentMonitor
        if (!mon) return
        const name = mon.name || "eDP-1"
        const mode = modeStr || getPreviewMode(name)
        const posX = mon.x !== undefined ? mon.x : 0
        const posY = mon.y !== undefined ? mon.y : 0
        const transform = transformVal !== undefined ? transformVal : getPreviewTransform(name)
        const scale = scaleVal !== undefined ? scaleVal : getPreviewScale(name)

        const luaCmd = `hyprctl eval "hl.monitor({ output = '${name}', mode = '${mode}', position = '${posX}x${posY}', scale = ${scale}, transform = ${transform} })"`
        const legacyCmd = `hyprctl keyword monitor "${name},${mode},${posX}x${posY},${scale},transform,${transform}"`

        Quickshell.execDetached(["bash", "-c", `${luaCmd} || ${legacyCmd}`]);
        refreshTimer.restart();
    }

    function applyInputSettings() {
        if (!page.isLoaded) return
        const luaCode = `hl.config({ input = { repeat_delay = ${inputRepeatDelay}, repeat_rate = ${inputRepeatRate}, touchpad = { natural_scroll = ${inputNaturalScroll}, tap_to_click = ${inputTapToClick}, disable_while_typing = ${inputDisableWhileTyping} } } })`
        const luaCmd = `hyprctl eval "${luaCode}"`
        const fallbackCmd = `hyprctl keyword input:repeat_delay ${inputRepeatDelay} && hyprctl keyword input:repeat_rate ${inputRepeatRate} && hyprctl keyword input:touchpad:natural_scroll ${inputNaturalScroll ? 1 : 0} && hyprctl keyword input:touchpad:tap-to-click ${inputTapToClick ? 1 : 0} && hyprctl keyword input:touchpad:disable_while_typing ${inputDisableWhileTyping ? 1 : 0}`
        const scriptPath = FileUtils.trimFileProtocol(Directories.config) + "/hypr/custom/scripts/update_general_lua.py"
        const saveCmd = `python3 '${scriptPath}' INPUT "${luaCode}"`
        const applyCmd = `(${luaCmd} || (${fallbackCmd})) && (${saveCmd})`
        Quickshell.execDetached(["bash", "-c", applyCmd]);
    }

    function applyOpacitySettings() {
        if (!page.isLoaded) return
        const dimStr = (dimStrength / 100.0).toFixed(2)
        const actOpStr = (activeOpacity / 100.0).toFixed(2)
        const inactOpStr = (inactiveOpacity / 100.0).toFixed(2)

        const luaCode = `hl.config({ decoration = { dim_inactive = ${dimInactive}, dim_strength = ${dimStr}, active_opacity = ${actOpStr}, inactive_opacity = ${inactOpStr} } })`
        const luaCmd = `hyprctl eval "${luaCode}"`
        const fallbackCmd = `hyprctl keyword decoration:dim_inactive ${dimInactive ? 1 : 0} && hyprctl keyword decoration:dim_strength ${dimStr} && hyprctl keyword decoration:active_opacity ${actOpStr} && hyprctl keyword decoration:inactive_opacity ${inactOpStr}`
        const scriptPath = FileUtils.trimFileProtocol(Directories.config) + "/hypr/custom/scripts/update_general_lua.py"
        const saveCmd = `python3 '${scriptPath}' DECORATION "${luaCode}"`
        const applyCmd = `(${luaCmd} || (${fallbackCmd})) && (${saveCmd})`
        Quickshell.execDetached(["bash", "-c", applyCmd]);
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: page.reloadMonitors()
    }

    Component.onCompleted: {
        page.reloadMonitors();
        Qt.callLater(() => {
            page.isLoaded = true;
        });
    }

    // SECTION 1: MONITORS & DISPLAYS
    ContentSection {
        icon: "desktop_windows"
        title: Translation.tr("Monitors & Displays")
        tooltip: Translation.tr("Click any monitor in the layout preview below to select it, change orientation, and set refresh rate.")

        // Header Action Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StyledText {
                text: Translation.tr("Display Arrangement")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: Translation.tr("Detect Displays")
                onClicked: page.reloadMonitors()
            }
        }

        // Unified Display Arrangement Canvas Tile
        Rectangle {
            id: displayTile
            Layout.fillWidth: true
            implicitHeight: 360
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.color: Appearance.colors.colLayer0Border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                // Selected Monitor Details Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        StyledText {
                            text: (page.currentMonitor?.name || "eDP-1") + (page.currentMonitor?.description ? " — " + page.currentMonitor.description : "")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Translation.tr("Resolution: ") + (page.currentMonitor?.width || 1920) + "x" + (page.currentMonitor?.height || 1080) +
                                  " • " + Translation.tr("Refresh Rate: ") + Math.round(page.currentMonitor?.refreshRate || 60) + "Hz" +
                                  " • " + Translation.tr("Scale: ") + (page.currentMonitor?.scale || 1.0) + "x"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: page.currentMonitor?.focused ?? false
                        implicitWidth: activeBadgeText.implicitWidth + 12
                        implicitHeight: 22
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer3

                        StyledText {
                            id: activeBadgeText
                            anchors.centerIn: parent
                            text: Translation.tr("Active")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Interactive Multi-Monitor Arrangement Canvas
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 24

                        Repeater {
                            model: page.monitorsList

                            delegate: Item {
                                id: monitorItem
                                required property var modelData
                                required property int index

                                readonly property bool isSelected: page.selectedMonitorIndex === index
                                readonly property string monName: modelData.name || "eDP-1"
                                readonly property int animTransform: page.getPreviewTransform(monName)
                                readonly property bool isPortrait: animTransform === 1 || animTransform === 3

                                implicitWidth: isPortrait ? 150 : 250
                                implicitHeight: isPortrait ? 250 : 150

                                Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                                Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                                Rectangle {
                                    id: previewBox
                                    anchors.centerIn: parent
                                    width: isPortrait ? 150 : 250
                                    height: isPortrait ? 250 : 150
                                    radius: Appearance.rounding.small
                                    color: isSelected ? Appearance.colors.colLayer1 : Appearance.colors.colLayer3
                                    border.color: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colOutline || Appearance.colors.colLayer0Border
                                    border.width: isSelected ? 2 : 1

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

                                    rotation: {
                                        switch (animTransform) {
                                        case 1: return 90
                                        case 2: return 180
                                        case 3: return 270
                                        default: return 0
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.selectedMonitorIndex = index
                                        }
                                    }

                                    // Inner Screen Details
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        radius: Appearance.rounding.unsharpen
                                        color: isSelected ? Appearance.colors.colLayer3 : Appearance.colors.colLayer2
                                        clip: true

                                        // Screen Bar Header
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 16
                                            color: Appearance.colors.colLayer2

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 4

                                                Rectangle {
                                                    implicitWidth: 6
                                                    implicitHeight: 6
                                                    radius: 3
                                                    color: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                                }
                                                Item { Layout.fillWidth: true }
                                                StyledText {
                                                    text: animTransform === 1 ? "90°" :
                                                          animTransform === 2 ? "180°" :
                                                          animTransform === 3 ? "270°" : "0°"
                                                    font.pixelSize: 9
                                                    color: Appearance.colors.colSubtext
                                                }
                                            }
                                        }

                                        // Screen Title & Resolution text
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            StyledText {
                                                text: monitorItem.monName
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.weight: isSelected ? Font.Bold : Font.DemiBold
                                                color: isSelected ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                                                elide: Text.ElideRight
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            StyledText {
                                                text: (modelData.width || 1920) + " × " + (modelData.height || 1080)
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                elide: Text.ElideRight
                                                Layout.alignment: Qt.AlignHCenter
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

        // Orientation Control & Dedicated Apply Button for Selected Display
        ContentSubsection {
            title: Translation.tr("Orientation & Rotation")
            tooltip: Translation.tr("Select orientation to preview in the display canvas above, then click 'Apply Orientation'.")
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                ConfigSelectionArray {
                    currentValue: page.getPreviewTransform(page.currentMonitor?.name || "eDP-1")
                    onSelected: newValue => {
                        page.setPreviewTransform(page.currentMonitor?.name || "eDP-1", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Landscape (0°)"), icon: "crop_landscape", value: 0 },
                        { displayName: Translation.tr("Portrait (90°)"), icon: "crop_portrait", value: 1 },
                        { displayName: Translation.tr("Flipped (180°)"), icon: "screen_rotation", value: 2 },
                        { displayName: Translation.tr("Portrait (270°)"), icon: "crop_portrait", value: 3 }
                    ]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RippleButtonWithIcon {
                        materialIcon: "done"
                        mainText: Translation.tr("Apply Orientation")
                        onClicked: {
                            const monName = page.currentMonitor?.name || "eDP-1"
                            page.applyMonitorSettings(
                                monName,
                                page.getPreviewMode(monName),
                                page.getPreviewTransform(monName),
                                page.getPreviewScale(monName)
                            )
                        }
                    }

                    StyledText {
                        text: Translation.tr("Applies rotation to physical display")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Supported Modes & Refresh Rates fetched directly from Hyprland for Selected Display
        ContentSubsection {
            title: Translation.tr("Supported Modes & Refresh Rates")
            tooltip: Translation.tr("Select display mode for the active display and click Apply to change refresh rate.")
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                ConfigSelectionArray {
                    currentValue: page.getPreviewMode(page.currentMonitor?.name || "eDP-1")
                    onSelected: newValue => {
                        page.setPreviewMode(page.currentMonitor?.name || "eDP-1", newValue)
                    }
                    options: page.availableModes.map(m => {
                        return {
                            displayName: m.displayName,
                            icon: m.hz >= 120 ? "bolt" : "speed",
                            value: m.modeString
                        }
                    })
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RippleButtonWithIcon {
                        materialIcon: "check"
                        mainText: Translation.tr("Apply Refresh Rate & Mode")
                        onClicked: {
                            const monName = page.currentMonitor?.name || "eDP-1"
                            page.applyMonitorSettings(
                                monName,
                                page.getPreviewMode(monName),
                                page.getPreviewTransform(monName),
                                page.getPreviewScale(monName)
                            )
                        }
                    }
                }
            }
        }

        // Display Scale Factor & Apply Button
        ContentSubsection {
            title: Translation.tr("Display Scale Factor")
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                ConfigSelectionArray {
                    currentValue: page.getPreviewScale(page.currentMonitor?.name || "eDP-1")
                    onSelected: newValue => {
                        page.setPreviewScale(page.currentMonitor?.name || "eDP-1", newValue)
                    }
                    options: [
                        { displayName: "1.0x", icon: "zoom_out_map", value: 1.0 },
                        { displayName: "1.25x", icon: "zoom_in", value: 1.25 },
                        { displayName: "1.5x", icon: "zoom_in", value: 1.5 },
                        { displayName: "1.75x", icon: "zoom_in", value: 1.75 },
                        { displayName: "2.0x", icon: "zoom_in_map", value: 2.0 }
                    ]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RippleButtonWithIcon {
                        materialIcon: "zoom_in"
                        mainText: Translation.tr("Apply Scale")
                        onClicked: {
                            const monName = page.currentMonitor?.name || "eDP-1"
                            page.applyMonitorSettings(
                                monName,
                                page.getPreviewMode(monName),
                                page.getPreviewTransform(monName),
                                page.getPreviewScale(monName)
                            )
                        }
                    }
                }
            }
        }
    }

    // SECTION 2: KEYBOARD LAYOUTS & SHORTCUTS (НАСТРОЙКИ КЛАВИАТУРЫ)
    ContentSection {
        id: kbSection
        icon: "keyboard"
        title: Translation.tr("Keyboard Layouts & Shortcuts")
        tooltip: Translation.tr("Configure keyboard layouts (e.g. en,ru or ru,en) and layout switching hotkey.")

        property string kbLayouts: "us,ru"
        property string kbOption: "grp:alt_shift_toggle"
        property int kbRepeatRate: 35
        property int kbRepeatDelay: 250
        property bool appliedKbSuccess: false

        ContentSubsection {
            title: Translation.tr("Keyboard Layouts")
            tooltip: Translation.tr("Enter layout codes separated by comma. Primary layout first (e.g. 'us,ru' or 'ru,us' or 'en')")
            Layout.fillWidth: true

            MaterialTextArea {
                id: kbLayoutInput
                Layout.fillWidth: true
                placeholderText: Translation.tr("Layouts (e.g. us,ru or ru,us)")
                text: kbSection.kbLayouts
                onTextChanged: kbSection.kbLayouts = text.trim()
            }
        }

        ContentSubsection {
            title: Translation.tr("Layout Switching Shortcut")
            tooltip: Translation.tr("Choose hotkey shortcut for switching between keyboard layouts")
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: kbSection.kbOption
                onSelected: newValue => {
                    kbSection.kbOption = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Alt + Shift"),
                        value: "grp:alt_shift_toggle"
                    },
                    {
                        displayName: Translation.tr("Caps Lock (Pure Layout Switch)"),
                        value: "grp:caps_toggle,caps:none"
                    },
                    {
                        displayName: Translation.tr("Caps Lock"),
                        value: "grp:caps_toggle"
                    },
                    {
                        displayName: Translation.tr("Ctrl + Shift"),
                        value: "grp:ctrl_shift_toggle"
                    },
                    {
                        displayName: Translation.tr("Alt + Space"),
                        value: "grp:alt_space_toggle"
                    }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Keyboard Repeat Speed & Delay")
            tooltip: Translation.tr("Configure key repeat rate (repeats per second) and initial repeat delay (ms).")
            Layout.fillWidth: true

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Repeat Rate (cps)")
                    value: kbSection.kbRepeatRate
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        kbSection.kbRepeatRate = value;
                    }
                }
                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Repeat Delay (ms)")
                    value: kbSection.kbRepeatDelay
                    from: 100
                    to: 1000
                    stepSize: 25
                    onValueChanged: {
                        kbSection.kbRepeatDelay = value;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RippleButtonWithIcon {
                materialIcon: kbSection.appliedKbSuccess ? "check" : "keyboard"
                mainText: kbSection.appliedKbSuccess ? Translation.tr("Layout Applied!") : Translation.tr("Apply Keyboard Settings")
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: {
                    const layoutStr = kbSection.kbLayouts.length > 0 ? kbSection.kbLayouts : "us,ru";
                    const optStr = kbSection.kbOption;
                    const rateVal = kbSection.kbRepeatRate;
                    const delayVal = kbSection.kbRepeatDelay;
                    const luaCode = `hl.config({ input = { kb_layout = "${layoutStr}", kb_options = "${optStr}", repeat_rate = ${rateVal}, repeat_delay = ${delayVal} } })`;
                    const luaCmd = `hyprctl eval "${luaCode}"`;
                    const fallbackCmd = `hyprctl keyword input:kb_layout '${layoutStr}' && hyprctl keyword input:kb_options '${optStr}' && hyprctl keyword input:repeat_rate ${rateVal} && hyprctl keyword input:repeat_delay ${delayVal}`;
                    const scriptPath = FileUtils.trimFileProtocol(Directories.config) + "/hypr/custom/scripts/update_general_lua.py";
                    const saveCmd = `python3 '${scriptPath}' KEYBOARD "${luaCode}"`;
                    const applyCmd = `(${luaCmd} || (${fallbackCmd})) && (${saveCmd})`;
                    Quickshell.execDetached(["bash", "-c", applyCmd]);
                    kbSection.appliedKbSuccess = true;
                    kbApplyTimer.restart();
                }

                Timer {
                    id: kbApplyTimer
                    interval: 2000
                    onTriggered: kbSection.appliedKbSuccess = false
                }
            }
        }
    }

    // SECTION 3: WINDOW OPACITY & DIMMING
    ContentSection {
        icon: "opacity"
        title: Translation.tr("Window Opacity & Dimming")
        tooltip: Translation.tr("Configure active and inactive window opacity levels, and background window dimming.")

        ContentSubsection {
            title: Translation.tr("Inactive Window Dimming")
            Layout.fillWidth: true

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "contrast"
                    text: Translation.tr("Dim Inactive Windows")
                    checked: page.dimInactive
                    onCheckedChanged: {
                        page.dimInactive = checked;
                        page.applyOpacitySettings();
                    }
                }
            }

            ConfigRow {
                uniform: true
                visible: page.dimInactive
                ConfigSpinBox {
                    icon: "exposure"
                    text: Translation.tr("Dim Strength (%)")
                    value: page.dimStrength
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        page.dimStrength = value;
                        page.applyOpacitySettings();
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Window Opacity Levels")
            Layout.fillWidth: true

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "visibility"
                    text: Translation.tr("Active Window Opacity (%)")
                    value: page.activeOpacity
                    from: 50
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        page.activeOpacity = value;
                        page.applyOpacitySettings();
                    }
                }
                ConfigSpinBox {
                    icon: "visibility_off"
                    text: Translation.tr("Inactive Window Opacity (%)")
                    value: page.inactiveOpacity
                    from: 50
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        page.inactiveOpacity = value;
                        page.applyOpacitySettings();
                    }
                }
            }
        }
    }
}

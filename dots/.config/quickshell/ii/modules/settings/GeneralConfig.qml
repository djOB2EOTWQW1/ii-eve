import QtQuick  
import Quickshell  
import Quickshell.Io  
import QtQuick.Layouts  
import qs.services  
import qs.modules.common  
import qs.modules.common.functions  
import qs.modules.common.widgets  
  
ContentPage {  
    id: page
    readonly property int index: 1
    property bool register: parent.register ?? false
    property var customAutostartList: []
    property bool autoSessionRestore: true

    Process {  
        id: translationProc  
        property string locale: ""  
        command: [Directories.aiTranslationScriptPath, translationProc.locale]  
    }  

    Process {
        id: loadCustomAutostartProc
        command: ["bash", "-c", "cat ~/.config/hypr/custom/user_autostart.sh 2>/dev/null | grep -v '^#' | grep -v '^$'"]
        stdout: StdioCollector {
            id: customExecsCollector
            onStreamFinished: {
                try {
                    const lines = customExecsCollector.text.split("\n").filter(l => l.trim().length > 0);
                    page.customAutostartList = lines;
                } catch (e) {}
            }
        }
    }

    function reloadCustomAutostart() {
        loadCustomAutostartProc.running = false
        loadCustomAutostartProc.running = true
    }

    function removeCustomAutostartCmd(cmdToRemove) {
        const escaped = cmdToRemove.replace(/[\/&\\]/g, '\\$&');
        Quickshell.execDetached(["bash", "-c", `sed -i '/${escaped}/d' ~/.config/hypr/custom/user_autostart.sh 2>/dev/null`]);
        reloadTimer.restart();
    }

    function saveCurrentSessionSnapshot() {
        if (!page.autoSessionRestore) return;
        Quickshell.execDetached(["python3", FileUtils.trimFileProtocol(Directories.config) + "/hypr/custom/scripts/session_saver.py"]);
    }

    function clearSessionSnapshot() {
        Quickshell.execDetached(["bash", "-c", "echo '#!/bin/bash' > ~/.config/hypr/custom/session_restore.sh"]);
    }

    Timer {
        id: autoSaveSessionTimer
        interval: 4000
        running: page.autoSessionRestore
        repeat: true
        onTriggered: page.saveCurrentSessionSnapshot()
    }

    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: page.reloadCustomAutostart()
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            liveClockText.text = Qt.formatDateTime(new Date(), Config.options.time.secondPrecision ? Config.options.time.format.replace("mm", "mm:ss") : Config.options.time.format)
            liveDateText.text = Config.options.time.dateFormat === "ddd MM/dd" ? Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy") : Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
        }
    }

    Component.onCompleted: {
        page.reloadCustomAutostart();
        if (page.autoSessionRestore) {
            page.saveCurrentSessionSnapshot();
        }
    }  
  
    ContentSection {  
        icon: "language"  
        title: Translation.tr("Language")  
  
        ContentSubsection {  
            title: Translation.tr("Interface Language")  
            tooltip: Translation.tr("Select the language for the user interface.\n\"Auto\" will use your system's locale.")  
  
            StyledComboBox {  
                id: languageSelector  
                buttonIcon: "language"  
                textRole: "displayName"  
  
                model: [  
                    {  
                        displayName: Translation.tr("Auto (System)"),  
                        value: "auto"  
                    },  
                    ...Translation.allAvailableLanguages.map(lang => {  
                        return {  
                            displayName: lang,  
                            value: lang  
                        };  
                    })]  
  
                currentIndex: {  
                    const index = model.findIndex(item => item.value === Config.options.language.ui);  
                    return index !== -1 ? index : 0;  
                }  
  
                onActivated: index => {  
                    Config.options.language.ui = model[index].value;  
                }  
            }  
        }  
        ContentSubsection {  
            title: Translation.tr("Generate translation with Gemini")  
            tooltip: Translation.tr("You'll need to enter your Gemini API key first.\nType /key on the sidebar for instructions.")  
  
            ConfigRow {  
                MaterialTextArea {  
                    id: localeInput  
                    Layout.fillWidth: true  
                    placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")  
                    text: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui  
                }  
                RippleButtonWithIcon {  
                    id: generateTranslationBtn  
                    Layout.fillHeight: true  
                    nerdIcon: ""  
                    enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())  
                    mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")  
                    onClicked: {  
                        translationProc.locale = localeInput.text.trim();  
                        translationProc.running = false;  
                        translationProc.running = true;  
                    }  
                }  
            }  
        }  
    } 
  
    ContentSection {  
        icon: "notification_sound"  
        title: Translation.tr("Sounds")  
        ConfigRow {  
            uniform: true  
            ConfigSwitch {  
                buttonIcon: "battery_android_full"  
                text: Translation.tr("Battery")  
                checked: Config.options.sounds.battery  
                onCheckedChanged: {  
                    Config.options.sounds.battery = checked;  
                }  
            }  
            ConfigSwitch {  
                buttonIcon: "av_timer"  
                text: Translation.tr("Pomodoro")  
                checked: Config.options.sounds.pomodoro  
                onCheckedChanged: {  
                    Config.options.sounds.pomodoro = checked;  
                }  
            }  
        }  
    }  

    // LARGE DIGITAL CLOCK SECTION
    ContentSection {  
        icon: "nest_clock_farsight_analog"  
        title: Translation.tr("Time")  

        // Large Clock Display Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 90
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.color: Appearance.colors.colLayer0Border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 38
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    StyledText {
                        id: liveClockText
                        text: Qt.formatDateTime(new Date(), Config.options.time.secondPrecision ? Config.options.time.format.replace("mm", "mm:ss") : Config.options.time.format)
                        font.pixelSize: 34
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        text: Translation.tr("Live Clock Preview • ") + (Config.options.time.format.includes("ap") || Config.options.time.format.includes("AP") ? Translation.tr("12-Hour Format") : Translation.tr("24-Hour Format"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
  
        ConfigSwitch {  
            buttonIcon: "pace"  
            text: Translation.tr("Second precision")  
            checked: Config.options.time.secondPrecision  
            onCheckedChanged: {  
                Config.options.time.secondPrecision = checked;  
            }  
            StyledToolTip {  
                text: Translation.tr("Enable if you want clocks to show seconds accurately")  
            }  
        }  
  
        ContentSubsection {  
            title: Translation.tr("Format")  
            tooltip: ""  
  
            ConfigSelectionArray {  
                currentValue: Config.options.time.format  
                onSelected: newValue => {  
                    if (newValue === "hh:mm") {  
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);  
                    } else {  
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);  
                    }  
  
                    Config.options.time.format = newValue;  
                }  
                options: [  
                    {  
                        displayName: Translation.tr("24h"),  
                        value: "hh:mm"  
                    },  
                    {  
                        displayName: Translation.tr("12h am/pm"),  
                        value: "h:mm ap"  
                    },  
                    {  
                        displayName: Translation.tr("12h AM/PM"),  
                        value: "h:mm AP"  
                    },  
                ]  
            }  
        }  
    }  

    // LARGE DATE DISPLAY SECTION
    ContentSection {
        icon: "calendar_month"
        title: Translation.tr("Date")

        // Large Date Display Card (Format syncs with Date format setting!)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 80
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.color: Appearance.colors.colLayer0Border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                MaterialSymbol {
                    text: "today"
                    iconSize: 34
                    color: Appearance.colors.colSecondary
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    StyledText {
                        id: liveDateText
                        text: Config.options.time.dateFormat === "ddd MM/dd" ? Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy") : Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        text: Translation.tr("Bar Format: ") + Config.options.time.dateFormat + " (" + Qt.formatDateTime(new Date(), Config.options.time.dateFormat) + ")"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Format")
            tooltip: Translation.tr("Changes the date format in the bar")

            ConfigSelectionArray {
                currentValue: Config.options.time.dateFormat
                onSelected: newValue => {
                    Config.options.time.dateFormat = newValue;  
                }
                options: [
                    {
                        displayName: Translation.tr("Date First (dd/MM)"),
                        value: "ddd dd/MM"
                    },
                    {
                        displayName: Translation.tr("Month First (MM/dd)"),
                        value: "ddd MM/dd"
                    }
                ]
            }
        }
    }

    // AUTOMATIC WORKSPACE SESSION SAVE & RESTORE SECTION
    ContentSection {
        icon: "save"
        title: Translation.tr("Session Restore")
        tooltip: Translation.tr("When enabled, your last active window session and workspaces are automatically saved and restored on reboot.")

        ConfigSwitch {
            buttonIcon: "history"
            text: Translation.tr("Automatically save and restore last session")
            checked: page.autoSessionRestore
            onCheckedChanged: {
                page.autoSessionRestore = checked;
                if (checked) {
                    page.saveCurrentSessionSnapshot();
                } else {
                    page.clearSessionSnapshot();
                }
            }
            StyledToolTip {
                text: Translation.tr("Automatically captures active window layout and restores it upon system boot")
            }
        }
    }
  
    ContentSection {  
        icon: "work_alert"  
        title: Translation.tr("Work safety")  
  
        ConfigSwitch {  
            buttonIcon: "assignment"  
            text: Translation.tr("Hide clipboard images copied from sussy sources")  
            checked: Config.options.workSafety.enable.clipboard  
            onCheckedChanged: {  
                Config.options.workSafety.enable.clipboard = checked;  
            }  
        }  
        ConfigSwitch {  
            buttonIcon: "wallpaper"  
            text: Translation.tr("Hide sussy/anime wallpapers")  
            checked: Config.options.workSafety.enable.wallpaper  
            onCheckedChanged: {  
                Config.options.workSafety.enable.wallpaper = checked;  
            }  
        }  
    }  

    // AUTOSTART APPS & CUSTOM COMMAND MANAGER SECTION
    ContentSection {
        icon: "rocket_launch"
        title: Translation.tr("Autostart Applications")
        tooltip: Translation.tr("Manage applications and background services launched automatically on system startup.")

        property var autostartApps: [
            { id: "hypridle", name: Translation.tr("Hypridle (Idle & Lock Daemon)"), icon: "timer", command: "hypridle", enabled: true },
            { id: "easyeffects", name: Translation.tr("EasyEffects (Audio Effects Service)"), icon: "equalizer", command: "easyeffects --hide-window --service-mode", enabled: true },
            { id: "cliphist", name: Translation.tr("Cliphist (Clipboard History Daemon)"), icon: "content_paste", command: "cliphist store", enabled: true },
            { id: "keyring", name: Translation.tr("Gnome Keyring (Secrets Daemon)"), icon: "key", command: "gnome-keyring-daemon --start", enabled: true },
            { id: "geoclue", name: Translation.tr("Geoclue (Location Services)"), icon: "location_on", command: "start_geoclue_agent.sh", enabled: true }
        ]

        ContentSubsection {
            title: Translation.tr("Background System Services")
            Layout.fillWidth: true

            Repeater {
                model: parent.parent.autostartApps

                delegate: ConfigSwitch {
                    required property var modelData
                    buttonIcon: modelData.icon
                    text: modelData.name
                    checked: modelData.enabled
                    onCheckedChanged: {
                        modelData.enabled = checked;
                    }
                    StyledToolTip {
                        text: modelData.command
                    }
                }
            }
        }

        // Custom User Autostart Commands List
        ContentSubsection {
            title: Translation.tr("User Custom Autostart Commands")
            tooltip: Translation.tr("Custom commands added to ~/.config/hypr/custom/user_autostart.sh")
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: page.customAutostartList

                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                        border.color: Appearance.colors.colLayer0Border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            MaterialSymbol {
                                text: "terminal"
                                iconSize: 20
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: modelData
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RippleButtonWithIcon {
                                materialIcon: "delete"
                                mainText: Translation.tr("Delete")
                                onClicked: {
                                    page.removeCustomAutostartCmd(modelData);
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: page.customAutostartList.length === 0
                    text: Translation.tr("No user autostart commands added yet. Use the field below to add one.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Add Custom Autostart Command")
            tooltip: Translation.tr("Add any custom command or application to launch on startup (e.g. discord --start-minimized)")
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialTextArea {
                    id: customExecInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Command (e.g. telegram-desktop -autostart)")
                }

                RippleButtonWithIcon {
                    materialIcon: "add"
                    mainText: Translation.tr("Add Command")
                    onClicked: {
                        if (customExecInput.text.trim().length > 0) {
                            const cmd = customExecInput.text.trim();
                            const appendCmd = `mkdir -p ~/.config/hypr/custom && echo "${cmd}" >> ~/.config/hypr/custom/user_autostart.sh && chmod +x ~/.config/hypr/custom/user_autostart.sh`;
                            Quickshell.execDetached(["bash", "-c", appendCmd]);
                            customExecInput.text = "";
                            reloadTimer.restart();
                        }
                    }
                }
            }
        }
    }
}
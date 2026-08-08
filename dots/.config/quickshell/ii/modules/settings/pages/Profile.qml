import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ContentPage {
    id: page

    property string descriptionMode: {
        if (Config.options.profile.descriptionText === "::uptime::") return "uptime"
        return "distro"
    }
    property string hostnameInput: SystemInfo.hostname ?? ""

    Connections {
        target: SystemInfo
        function onHostnameChanged() {
            page.hostnameInput = SystemInfo.hostname ?? ""
        }
    }

    FolderListModel {
        id: avatarFolderModel
        folder: Config.options.profile.avatarPath !== "" ? Qt.resolvedUrl(Config.options.profile.avatarPath) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
    }

    Process {
        id: hostnameSetProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                SystemInfo.refreshHostname()
            }
        }
    }

    function applyHostname() {
        const newName = page.hostnameInput.trim()
        if (newName.length === 0 || newName === SystemInfo.hostname) return
        hostnameSetProc.command = ["hostnamectl", "set-hostname", newName]
        hostnameSetProc.running = true
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // =========================================================================
        // HERO USER PROFILE DASHBOARD BANNER
        // =========================================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 120
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // Hero Avatar Circle with Active Ring
                Rectangle {
                    id: heroAvatarRing
                    width: 80
                    height: 80
                    radius: 40
                    color: Appearance.colors.colPrimaryContainer

                    Image {
                        id: heroAvatarImg
                        anchors.fill: parent
                        source: Config.options.profile.avatarPicture !== "" ? "file://" + Config.options.profile.avatarPicture : "file://" + CF.FileUtils.trimFileProtocol(Directories.home) + "/.face"
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 80
                                height: 80
                                radius: 40
                            }
                        }
                        onStatusChanged: {
                            if (status === Image.Error) visible = false
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "account_circle"
                        iconSize: 48
                        color: Appearance.colors.colOnPrimaryContainer
                        visible: !heroAvatarImg.visible || heroAvatarImg.status === Image.Error
                    }

                    // Online Status Indicator Dot
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 2
                        anchors.bottomMargin: 2
                        width: 18
                        height: 18
                        radius: 9
                        color: "#10b981" // Emerald Green
                        border.width: 2
                        border.color: Appearance.colors.colLayer1
                    }
                }

                // User Info & Greeting
                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 8
                        StyledText {
                            text: Translation.tr("Welcome back,")
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: Config.options.profile.displayName !== "" ? Config.options.profile.displayName : SystemInfo.username
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    RowLayout {
                        spacing: 10

                        // Username @ Hostname Chip
                        Rectangle {
                            implicitWidth: userChipLayout.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: Appearance.colors.colSecondaryContainer

                            RowLayout {
                                id: userChipLayout
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    text: "badge"
                                    iconSize: 14
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                StyledText {
                                    text: (SystemInfo.username ?? "user") + "@" + (SystemInfo.hostname && SystemInfo.hostname !== "" ? SystemInfo.hostname : "cachyos")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }
                        }

                        // Distro / Uptime Tagline Chip
                        Rectangle {
                            implicitWidth: taglineChipLayout.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: Appearance.colors.colPrimaryContainer

                            RowLayout {
                                id: taglineChipLayout
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    text: Config.options.profile.descriptionText === "::uptime::" ? "timelapse" : "deployed_code"
                                    iconSize: 14
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    text: Config.options.profile.descriptionText === "::uptime::" ? Translation.tr("Up • %1").arg(DateTime.uptime) : SystemInfo.distroName
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }

                // Hero Quick Action Buttons
                ColumnLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    RippleButtonWithIcon {
                        materialIcon: "folder"
                        mainText: Translation.tr("Pictures")
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: Quickshell.execDetached(["dolphin", CF.FileUtils.trimFileProtocol(Directories.pictures)])
                    }

                    RippleButtonWithIcon {
                        materialIcon: "restart_alt"
                        mainText: Translation.tr("Reset Picture")
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: Config.options.profile.avatarPicture = ""
                    }
                }
            }
        }

        // =========================================================================
        // SECTION 1: AVATAR SELECTION & IDENTITY SETTINGS
        // =========================================================================
        ContentSection {
            icon: "account_circle"
            title: Translation.tr("User Profile & Avatar")
            tooltip: Translation.tr("Customize your avatar image, display name, and status line tagline.")

            ContentSubsection {
                title: Translation.tr("Avatar Selection & Image Path")
                tooltip: Translation.tr("Enter avatar folder or direct image file path")
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialTextField {
                        id: avatarPathField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Avatar folder or image path (e.g. /home/user/Pictures/avatar.png)")
                        text: Config.options.profile.avatarPath !== "" ? Config.options.profile.avatarPath : Config.options.profile.avatarPicture
                        onTextChanged: {
                            const trimmed = text.trim()
                            Config.options.profile.avatarPath = trimmed
                            if (/\.(png|jpg|jpeg|webp|svg)$/i.test(trimmed)) {
                                Config.options.profile.avatarPicture = trimmed
                            }
                        }
                    }

                    RippleButtonWithIcon {
                        materialIcon: "folder_open"
                        mainText: Translation.tr("Choose Folder")
                        onClicked: {
                            if (Config.options.profile.avatarPath !== "") {
                                Quickshell.execDetached(["dolphin", Config.options.profile.avatarPath])
                            } else {
                                Quickshell.execDetached(["dolphin", CF.FileUtils.trimFileProtocol(Directories.pictures)])
                            }
                        }
                    }
                }

                // Interactive Avatar Grid Carousel
                Item {
                    Layout.fillWidth: true
                    implicitHeight: Config.options.profile.avatarPath === "" ? 45 : avatarFlow.implicitHeight + 10

                    Flow {
                        id: avatarFlow
                        anchors.fill: parent
                        spacing: 12
                        visible: Config.options.profile.avatarPath !== ""

                        Repeater {
                            model: avatarFolderModel
                            delegate: Rectangle {
                                id: avatarCard
                                required property string fileName
                                required property string filePath
                                width: 60
                                height: 60
                                radius: 30
                                color: Appearance.colors.colLayer2
                                border.color: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                border.width: isSelected ? 3 : 1
                                scale: avatarMouseArea.containsMouse ? 1.08 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }

                                property bool isSelected: CF.FileUtils.trimFileProtocol(filePath.toString()) === Config.options.profile.avatarPicture

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: filePath
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 60; height: 60; radius: 30
                                        }
                                    }
                                }

                                // Selection Checkmark Badge
                                Rectangle {
                                    visible: avatarCard.isSelected
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: Appearance.colors.colPrimary

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 14
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }

                                MouseArea {
                                    id: avatarMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.options.profile.avatarPicture = CF.FileUtils.trimFileProtocol(filePath.toString())
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: Config.options.profile.avatarPath === ""
                        text: Translation.tr("Set an avatar folder path above to pick custom avatars.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Display Name Subsection
            ContentSubsection {
                title: Translation.tr("Display Name")
                tooltip: Translation.tr("Custom name shown in sidebar header and desktop widgets")
                Layout.fillWidth: true

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: SystemInfo.username
                    text: Config.options.profile.displayName
                    onTextChanged: Config.options.profile.displayName = text.trim()
                }
            }

            // System Hostname Subsection
            ContentSubsection {
                title: Translation.tr("System Hostname")
                tooltip: Translation.tr("Device network identifier (requires authentication to change)")
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialTextField {
                        id: hostnameField
                        Layout.fillWidth: true
                        placeholderText: SystemInfo.hostname ?? "cachyos"
                        text: page.hostnameInput
                        onTextChanged: page.hostnameInput = text.trim()
                    }

                    RippleButtonWithIcon {
                        materialIcon: "dns"
                        mainText: Translation.tr("Apply Hostname")
                        colBackground: Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        onClicked: page.applyHostname()
                    }
                }
            }

            // Tagline Format Subsection
            ContentSubsection {
                title: Translation.tr("Status Line Format")
                tooltip: Translation.tr("Choose info shown under your display name")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: page.descriptionMode
                    onSelected: newValue => {
                        page.descriptionMode = newValue
                        if (newValue === "distro") Config.options.profile.descriptionText = "::distro::"
                        if (newValue === "uptime") Config.options.profile.descriptionText = "::uptime::"
                    }
                    options: [
                        { displayName: Translation.tr("Distro Info"), value: "distro" },
                        { displayName: Translation.tr("System Uptime"), value: "uptime" }
                    ]
                }
            }
        }

        // =========================================================================
        // SECTION 2: SYSTEM ENVIRONMENT SHOWCASE
        // =========================================================================
        ContentSection {
            icon: "info"
            title: Translation.tr("System Environment")
            tooltip: Translation.tr("Live hardware and session environment specs.")

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: [
                        { title: Translation.tr("User"), val: SystemInfo.username ?? "user", icon: "person" },
                        { title: Translation.tr("Hostname"), val: SystemInfo.hostname && SystemInfo.hostname !== "" ? SystemInfo.hostname : "cachyos", icon: "dns" },
                        { title: Translation.tr("Distro"), val: SystemInfo.distroName ?? "Linux", icon: "memory" },
                        { title: Translation.tr("Shell"), val: "fish (/usr/bin/fish)", icon: "terminal" },
                        { title: Translation.tr("Terminal"), val: "kitty (/usr/bin/kitty)", icon: "aspect_ratio" },
                        { title: Translation.tr("Compositor"), val: "Hyprland (Wayland)", icon: "desktop_windows" }
                    ]

                    delegate: Rectangle {
                        id: specCard
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: Appearance.rounding.normal
                        color: specHover.hovered ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                        border.color: specHover.hovered ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        HoverHandler {
                            id: specHover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                shape: MaterialShape.Shape.Superellipse
                                text: modelData.icon
                                iconSize: 22
                                implicitSize: 40
                                color: Appearance.colors.colPrimaryContainer
                                colSymbol: Appearance.colors.colOnPrimaryContainer
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.title
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }

                                StyledText {
                                    text: modelData.val ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }

        // =========================================================================
        // SECTION 3: DESKTOP CONFIGURATION PRESETS MANAGER
        // =========================================================================
        ContentSection {
            icon: "auto_awesome"
            title: Translation.tr("Configuration Presets")
            tooltip: Translation.tr("Save and restore custom desktop configuration snapshots.")

            ContentSubsection {
                title: Translation.tr("What's stored in a Preset Snapshot?")
                tooltip: Translation.tr("Detailed breakdown of saved configuration settings")
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("A preset snapshot saves your full shell configuration (~/.config/illogical-impulse/config.json), including:\n• Wallpapers & Background Media settings\n• Material 3 Color Schemes & Sharpness settings\n• Top Bar layout, Widget positioning & Island sizes\n• Custom AI prompts, Quick Toggles & User Profile info")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }
            }

            ContentSubsection {
                title: Translation.tr("Save Preset Snapshot")
                tooltip: Translation.tr("Enter preset name and optional description separated by a comma")
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialTextField {
                        id: presetNameInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Preset Name, Description (e.g. Minimal_Dark, Custom setup)")
                        onAccepted: saveBtn.clicked()
                    }

                    RippleButtonWithIcon {
                        id: saveBtn
                        materialIcon: "save"
                        mainText: Translation.tr("Save Preset")
                        colBackground: Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        onClicked: {
                            if (presetNameInput.text.trim() !== "") {
                                Presets.save(presetNameInput.text.trim())
                                presetNameInput.text = ""
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: Presets.folderModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No presets saved yet. Type a name above to create your first desktop preset.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Flow {
                Layout.topMargin: 12
                Layout.fillWidth: true
                spacing: 14
                visible: Presets.folderModel.count > 0

                Repeater {
                    model: Presets.folderModel
                    delegate: PresetsCard {
                        id: presetDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: (fileName ?? "").replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        FileView {
                            path: presetDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text())
                                    const rawWallpaper = data?.background?.wallpaperPath ?? ""
                                    const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper)
                                    presetDelegate.presetWallpaper = isVideo
                                        ? (data?.background?.thumbnailPath ?? "")
                                        : rawWallpaper
                                    presetDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                } catch (e) {
                                    console.log("Failed to parse preset JSON:", e)
                                }
                            }
                        }

                        imageSource: presetDelegate.presetWallpaper
                        title: presetDelegate.presetName
                        description: presetDelegate.presetDescription !== "" ? presetDelegate.presetDescription : Translation.tr("Saved Preset Snapshot")
                        onApply: () => Presets.apply(presetDelegate.presetName)
                        onRename: (newName) => Presets.rename(presetDelegate.presetName, newName)
                        onRemove: () => Presets.remove(presetDelegate.presetName)
                    }
                }
            }
        }
    }
}

/*
 *  SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
 *  SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
 *  SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@aolabs.dev>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols 2.0 as KQuickControls
import "utils.js" as Utils

Item {
    id: root

    property var configDialog
    property var wallpaperConfiguration
    property alias cfg_Color: colorButton.color
    property alias cfg_Blur: blurRadioButton.checked
    property int cfg_FillMode
    property int cfg_WallpaperDelay: 60
    property int cfg_RetryRequestCount: 3
    property int cfg_RetryRequestDelay: 5
    property bool cfg_RefreshNotification
    property bool cfg_ErrorNotification
    property bool cfg_RefetchSignal
    property string cfg_currentWallpaperThumbnail
    property string cfg_Market
    property bool cfg_ShowCopyright
    property string cfg_CopyrightPosition
    readonly property string currentThumbnailSource: (wallpaperConfiguration && wallpaperConfiguration.currentWallpaperThumbnail) ? wallpaperConfiguration.currentWallpaperThumbnail : cfg_currentWallpaperThumbnail
    function refreshImage() {
        cfg_RefetchSignal = !cfg_RefetchSignal;
        if (wallpaperConfiguration)
            wallpaperConfiguration.RefetchSignal = cfg_RefetchSignal;
        if (configDialog && "needsSave" in configDialog)
            configDialog.needsSave = true;
        if (configDialog && typeof configDialog.save === "function")
            configDialog.save();
    }

    implicitWidth: parent.width
    implicitHeight: parent.height
    Component.onCompleted: {
        if (!wallpaperConfiguration) {
            if (configDialog && configDialog.configuration)
                wallpaperConfiguration = configDialog.configuration;
            else if (typeof wallpaper !== "undefined" && wallpaper && wallpaper.configuration)
                wallpaperConfiguration = wallpaper.configuration;
        }
        if (!cfg_Market || cfg_Market === "")
            cfg_Market = Utils.detectMarket();
    }
    onConfigDialogChanged: {
        if (!wallpaperConfiguration && configDialog && configDialog.configuration)
            wallpaperConfiguration = configDialog.configuration;
    }

    ScrollView {
        id: scrollView

        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: Kirigami.Units.smallSpacing
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
        }

        Kirigami.FormLayout {
            id: formLayout

            // Fix binding loop by using a fixed width calculation
            width: scrollView.width - (scrollView.ScrollBar.vertical.visible ? scrollView.ScrollBar.vertical.width + Kirigami.Units.smallSpacing : 0) - Kirigami.Units.largeSpacing

            Item {
                Kirigami.FormData.label: i18n("Current Wallpaper:")
                implicitHeight: 200
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                visible: currentThumbnailSource !== ""

                Kirigami.ShadowedRectangle {
                    id: imageContainer

                    anchors.centerIn: parent
                    height: 160
                    width: 250
                    radius: 8
                    shadow.size: 15
                    shadow.color: Qt.rgba(0, 0, 0, 0.2)
                    shadow.yOffset: 2
                    Kirigami.Theme.colorSet: Kirigami.Theme.View
                    Kirigami.Theme.inherit: false
                    color: Kirigami.Theme.alternateBackgroundColor

                    Image {
                        id: currentWallpaper

                        anchors.fill: parent
                        anchors.margins: 5
                        fillMode: Image.PreserveAspectCrop
                        source: currentThumbnailSource
                        asynchronous: true
                        cache: true
                        smooth: true
                    }

                }

            }

            // Display and Positioning section
            ComboBox {
                id: resizeComboBox

                function setMethod() {
                    for (var i = 0; i < model.length; i++) {
                        const fillModeValue = wallpaperConfiguration ? wallpaperConfiguration.FillMode : cfg_FillMode;
                        if (model[i]["fillMode"] === fillModeValue) {
                            resizeComboBox.currentIndex = i;
                            var tl = model[i]["label"].length;
                        }
                    }
                }

                Kirigami.FormData.label: i18nd("plasma_wallpaper_org.kde.image", "Positioning:")
                model: [{
                    "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled and Cropped"),
                    "fillMode": Image.PreserveAspectCrop
                }, {
                    "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled"),
                    "fillMode": Image.Stretch
                }, {
                    "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled, Keep Proportions"),
                    "fillMode": Image.PreserveAspectFit
                }, {
                    "label": i18nd("plasma_wallpaper_org.kde.image", "Centered"),
                    "fillMode": Image.Pad
                }, {
                    "label": i18nd("plasma_wallpaper_org.kde.image", "Tiled"),
                    "fillMode": Image.Tile
                }]
                textRole: "label"
                onCurrentIndexChanged: cfg_FillMode = model[currentIndex]["fillMode"]
                Component.onCompleted: setMethod()
            }

            // Background options
            ButtonGroup {
                id: backgroundGroup
            }

            RadioButton {
                id: blurRadioButton

                visible: cfg_FillMode === Image.PreserveAspectFit || cfg_FillMode === Image.Pad
                Kirigami.FormData.label: i18nd("plasma_wallpaper_org.kde.image", "Background:")
                text: i18nd("plasma_wallpaper_org.kde.image", "Blur")
                ButtonGroup.group: backgroundGroup
            }

            RowLayout {
                id: colorRow

                visible: cfg_FillMode === Image.PreserveAspectFit || cfg_FillMode === Image.Pad

                RadioButton {
                    id: colorRadioButton

                    text: i18nd("plasma_wallpaper_org.kde.image", "Solid color")
                    checked: !cfg_Blur
                    ButtonGroup.group: backgroundGroup
                }

                KQuickControls.ColorButton {
                    id: colorButton

                    dialogTitle: i18nd("plasma_wallpaper_org.kde.image", "Select Background Color")
                }

            }

            // PotD Settings
            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Image Source Settings")
            }

            ComboBox {
                id: marketInput

                Kirigami.FormData.label: i18n("Region:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "Deutsch (Deutschland)", value: "de-DE" },
                    { text: "English (Australia)", value: "en-AU" },
                    { text: "English (Canada)", value: "en-CA" },
                    { text: "English (Great Britain)", value: "en-GB" },
                    { text: "English (India)", value: "en-IN" },
                    { text: "English (New Zealand)", value: "en-NZ" },
                    { text: "English (United States)", value: "en-US" },
                    { text: "Español (España)", value: "es-ES" },
                    { text: "Français (Canada)", value: "fr-CA" },
                    { text: "Français (France)", value: "fr-FR" },
                    { text: "Italiano (Italia)", value: "it-IT" },
                    { text: "日本語 (日本)", value: "ja-JP" },
                    { text: "Português (Brasil)", value: "pt-BR" },
                    { text: "中文 (中国)", value: "zh-CN" }
                ]
                Component.onCompleted: {
                    var market = cfg_Market;
                    if (!market || market === "")
                        market = Utils.detectMarket();
                    currentIndex = indexOfValue(market);
                }
                onActivated: cfg_Market = currentValue
            }

            // Copyright overlay settings
            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Copyright Overlay")
            }

            CheckBox {
                id: showCopyrightCheckbox

                Kirigami.FormData.label: i18n("Show Copyright:")
                text: i18n("Display copyright text on wallpaper")
                checked: cfg_ShowCopyright
                onToggled: cfg_ShowCopyright = checked
            }

            ComboBox {
                id: copyrightPositionInput

                Kirigami.FormData.label: i18n("Position:")
                enabled: cfg_ShowCopyright
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Top Left"), value: "top-left" },
                    { text: i18n("Top Right"), value: "top-right" },
                    { text: i18n("Bottom Left"), value: "bottom-left" },
                    { text: i18n("Bottom Right"), value: "bottom-right" }
                ]
                Component.onCompleted: currentIndex = indexOfValue(cfg_CopyrightPosition)
                onActivated: cfg_CopyrightPosition = currentValue
            }

            // Timer settings
            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Timer Settings")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Check every:")
                Layout.bottomMargin: Kirigami.Units.largeSpacing

                SpinBox {
                    id: delaySpinBox

                    value: cfg_WallpaperDelay
                    onValueChanged: cfg_WallpaperDelay = value
                    stepSize: 1
                    from: 1
                    to: 50000
                    editable: true
                    textFromValue: function(value, locale) {
                        return " " + value + " minutes";
                    }
                    valueFromText: function(text, locale) {
                        return text.replace(/ minutes/, '');
                    }
                }

                Button {
                    icon.name: "view-refresh"
                    ToolTip.text: i18n("Refresh Wallpaper")
                    ToolTip.visible: hovered
                    onClicked: {
                        focus = false;
                        refreshImage();
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Retry failed request every:")
                Layout.bottomMargin: Kirigami.Units.largeSpacing

                SpinBox {
                    id: retryDelaySpinBox

                    value: cfg_RetryRequestDelay
                    onValueChanged: cfg_RetryRequestDelay = value
                    stepSize: 1
                    from: 1
                    to: 60
                    editable: true
                    textFromValue: function(value, locale) {
                        return " " + value + " seconds";
                    }
                    valueFromText: function(text, locale) {
                        return text.replace(/ seconds/, '');
                    }
                }

                SpinBox {
                    id: retryCountSpinBox

                    value: cfg_RetryRequestCount
                    onValueChanged: cfg_RetryRequestCount = value
                    stepSize: 1
                    from: 1
                    to: 10
                    editable: true
                    ToolTip.text: i18n("Max number of retries")
                    ToolTip.visible: hovered
                    textFromValue: function(value, locale) {
                        return " " + value + " times";
                    }
                    valueFromText: function(text, locale) {
                        return text.replace(/ times/, '');
                    }
                }
            }

            // Notification controls
            GroupBox {
                Kirigami.FormData.label: i18n("Show Notification:")
                Layout.fillWidth: true
                padding: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.gridUnit

                RowLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.largeSpacing * 2

                    CheckBox {
                        text: i18n("Refresh")
                        checked: cfg_RefreshNotification
                        ToolTip.text: i18n("Show a notification when the wallpaper is refreshed")
                        ToolTip.visible: hovered
                        onToggled: {
                            cfg_RefreshNotification = checked;
                            if (wallpaperConfiguration)
                                wallpaperConfiguration.refreshNotification = checked;
                        }
                    }

                    CheckBox {
                        text: i18n("Error")
                        checked: cfg_ErrorNotification
                        ToolTip.text: i18n("Show a notification when an error occurs")
                        ToolTip.visible: hovered
                        onToggled: {
                            cfg_ErrorNotification = checked;
                            if (wallpaperConfiguration)
                                wallpaperConfiguration.errorNotification = checked;
                        }
                    }
                }

                background: Rectangle {
                    color: "transparent"
                    border.width: 0
                }
            }

            Item {
                implicitHeight: Kirigami.Units.gridUnit
            }
        }
    }
}

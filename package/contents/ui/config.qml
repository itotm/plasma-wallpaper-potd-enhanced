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
    property bool cfg_RefetchSignal
    property string cfg_currentWallpaperThumbnail
    property string cfg_Market
    property string cfg_Provider
    property string cfg_LastTitle
    property string cfg_LastDescription
    property string cfg_LastParsedCopyright
    property string cfg_LastCopyrightLink
    property bool cfg_ShowOverlay
    property string cfg_OverlayPosition
    property string cfg_lastValidImagePath

    readonly property string currentThumbnailSource: (wallpaperConfiguration && wallpaperConfiguration.currentWallpaperThumbnail) ? wallpaperConfiguration.currentWallpaperThumbnail : cfg_currentWallpaperThumbnail
    readonly property string currentTitle: (wallpaperConfiguration && wallpaperConfiguration.LastTitle) ? wallpaperConfiguration.LastTitle : cfg_LastTitle
    readonly property string currentDescription: (wallpaperConfiguration && wallpaperConfiguration.LastDescription) ? wallpaperConfiguration.LastDescription : cfg_LastDescription
    readonly property string currentParsedCopyright: (wallpaperConfiguration && wallpaperConfiguration.LastParsedCopyright) ? wallpaperConfiguration.LastParsedCopyright : cfg_LastParsedCopyright
    readonly property string currentCopyrightLink: (wallpaperConfiguration && wallpaperConfiguration.LastCopyrightLink) ? wallpaperConfiguration.LastCopyrightLink : cfg_LastCopyrightLink
    readonly property string currentImagePath: (wallpaperConfiguration && wallpaperConfiguration.lastValidImagePath) ? wallpaperConfiguration.lastValidImagePath : cfg_lastValidImagePath

    function refreshImage() {
        cfg_RefetchSignal = !cfg_RefetchSignal;
        if (wallpaperConfiguration)
            wallpaperConfiguration.RefetchSignal = cfg_RefetchSignal;
        if (configDialog && "needsSave" in configDialog)
            configDialog.needsSave = true;
        if (configDialog && typeof configDialog.save === "function")
            configDialog.save();
    }

    function openImageLocation() {
        if (currentImagePath && currentImagePath !== "")
            Qt.openUrlExternally(currentImagePath);
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
        if (!cfg_Provider || cfg_Provider === "")
            cfg_Provider = "bing";
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

            width: scrollView.width - (scrollView.ScrollBar.vertical.visible ? scrollView.ScrollBar.vertical.width + Kirigami.Units.smallSpacing : 0) - Kirigami.Units.largeSpacing

            // Positioning
            ComboBox {
                id: resizeComboBox

                function setMethod() {
                    for (var i = 0; i < model.length; i++) {
                        const fillModeValue = wallpaperConfiguration ? wallpaperConfiguration.FillMode : cfg_FillMode;
                        if (model[i]["fillMode"] === fillModeValue) {
                            resizeComboBox.currentIndex = i;
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

            // Provider
            ComboBox {
                id: providerInput

                Kirigami.FormData.label: i18n("Provider:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "Bing", value: "bing" }
                ]
                Component.onCompleted: currentIndex = indexOfValue(cfg_Provider)
                onActivated: cfg_Provider = currentValue
            }

            // Region selector
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
                    { text: "Português (Brasil)", value: "pt-BR" },
                    { text: "中文 (中国)", value: "zh-CN" },
                    { text: "日本語 (日本)", value: "ja-JP" }
                ]
                Component.onCompleted: {
                    var market = cfg_Market;
                    if (!market || market === "")
                        market = Utils.detectMarket();
                    currentIndex = indexOfValue(market);
                }
                onActivated: cfg_Market = currentValue
            }

            // Today's picture
            Item {
                Kirigami.FormData.label: i18n("Today's picture:")
                implicitHeight: 170
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: currentThumbnailSource !== ""

                Kirigami.ShadowedRectangle {
                    id: imageContainer

                    anchors.horizontalCenter: parent.horizontalCenter
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

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openImageLocation()
                    }
                }
            }

            // Title
            Label {
                Kirigami.FormData.label: i18n("Title:")
                text: currentTitle
                font.bold: true
                visible: currentTitle !== ""
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Description (part before parentheses)
            Label {
                Kirigami.FormData.label: i18n("Description:")
                text: currentDescription
                visible: currentDescription !== ""
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Copyright (part inside parentheses, clickable)
            Label {
                Kirigami.FormData.label: i18n("Copyright:")
                text: currentCopyrightLink ? "<a href='" + currentCopyrightLink + "'>" + currentParsedCopyright + "</a>" : currentParsedCopyright
                visible: currentParsedCopyright !== ""
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                onLinkActivated: function(link) { Qt.openUrlExternally(link) }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            // Overlay settings
            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Overlay")
            }

            CheckBox {
                id: showOverlayCheckbox

                Kirigami.FormData.label: i18n("Show Overlay:")
                text: i18n("Display title and description on wallpaper")
                checked: cfg_ShowOverlay
                onToggled: cfg_ShowOverlay = checked
            }

            ComboBox {
                id: overlayPositionInput

                Kirigami.FormData.label: i18n("Position:")
                enabled: cfg_ShowOverlay
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Top Left"), value: "top-left" },
                    { text: i18n("Top Right"), value: "top-right" },
                    { text: i18n("Bottom Left"), value: "bottom-left" },
                    { text: i18n("Bottom Right"), value: "bottom-right" }
                ]
                Component.onCompleted: currentIndex = indexOfValue(cfg_OverlayPosition)
                onActivated: cfg_OverlayPosition = currentValue
            }

            Item {
                implicitHeight: Kirigami.Units.gridUnit
            }
        }
    }
}

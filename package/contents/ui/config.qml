/*
* SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
* SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
* SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@aolabs.dev>
*
* SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols 2.0 as KQuickControls
import "utils.js" as Utils
import "providers.js" as Providers

Item {
    id: root

    property var configDialog
    property var wallpaperConfiguration
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

            property string previewThumbnail: ""
            property string previewTitle: ""
            property string previewDescription: ""
            property string previewParsedCopyright: ""
            property string previewCopyrightLink: ""
            property bool hasPreview: false

            property string cfg_CachedResponse
            property string cfg_CachedProvider

            readonly property string currentThumbnailSource: hasPreview ? previewThumbnail : (wallpaperConfiguration ? (wallpaperConfiguration.currentWallpaperThumbnail || "") : cfg_currentWallpaperThumbnail)
                readonly property string currentTitle: hasPreview ? previewTitle : (wallpaperConfiguration ? (wallpaperConfiguration.LastTitle || "") : cfg_LastTitle)
                    readonly property string currentDescription: hasPreview ? previewDescription : (wallpaperConfiguration ? (wallpaperConfiguration.LastDescription || "") : cfg_LastDescription)
                        readonly property string currentParsedCopyright: hasPreview ? previewParsedCopyright : (wallpaperConfiguration ? (wallpaperConfiguration.LastParsedCopyright || "") : cfg_LastParsedCopyright)
                            readonly property string currentCopyrightLink: hasPreview ? previewCopyrightLink : (wallpaperConfiguration ? (wallpaperConfiguration.LastCopyrightLink || "") : cfg_LastCopyrightLink)

                                function fetchPreview()
                                {
                                    var provider = cfg_Provider;
                                    var market = cfg_Market;
                                    if (!market || market === "")
                                    {
                                        market = Utils.detectMarket();
                                    }
                                    cfg_RefetchSignal = !(wallpaperConfiguration ? wallpaperConfiguration.RefetchSignal : cfg_RefetchSignal);
                                    cfg_CachedResponse = "";
                                    cfg_CachedProvider = "";
                                    var url = Providers.buildUrl(provider, market);
                                    console.log("PotD Enhanced config: Fetching preview from " + provider + ": " + url);

                                    var xhr = new XMLHttpRequest();
                                    xhr.onload = function() {
                                        if (xhr.status !== 200)
                                        {
                                            console.log("PotD Enhanced config: Preview fetch failed: " + xhr.status);
                                            return;
                                        }
                                        try {
                                            var result = Providers.parseResponse(provider, xhr.responseText, false);
                                            if (!result)
                                            {
                                                return;
                                            }
                                            previewThumbnail = result.thumbnailUrl;
                                            previewTitle = result.title;
                                            previewDescription = result.description;
                                            previewParsedCopyright = result.copyright;
                                            previewCopyrightLink = result.copyrightLink;
                                            hasPreview = true;

                                            cfg_currentWallpaperThumbnail = result.thumbnailUrl;
                                            cfg_LastTitle = result.title;
                                            cfg_LastDescription = result.description;
                                            cfg_LastParsedCopyright = result.copyright;
                                            cfg_LastCopyrightLink = result.copyrightLink;
                                            cfg_CachedResponse = xhr.responseText;
                                            cfg_CachedProvider = provider;
                                        } catch (e) {
                                            console.log("PotD Enhanced config: Preview parse error: " + e);
                                        }
                                    };
                                    xhr.onerror = function() {
                                        console.log("PotD Enhanced config: Preview request error");
                                    };
                                    xhr.open("GET", url);
                                    xhr.setRequestHeader("User-Agent", "PotDEnhanced/1.0 (KDE Plasma Wallpaper; https://github.com)");
                                    xhr.timeout = 30000;
                                    xhr.send();
                                }

                                property bool _syncing: false

                                function syncMetadata()
                                {
                                    if (_syncing || !wallpaperConfiguration || hasPreview)
                                        return;
                                    _syncing = true;
                                    cfg_currentWallpaperThumbnail = wallpaperConfiguration.currentWallpaperThumbnail || "";
                                    cfg_LastTitle = wallpaperConfiguration.LastTitle || "";
                                    cfg_LastDescription = wallpaperConfiguration.LastDescription || "";
                                    cfg_LastParsedCopyright = wallpaperConfiguration.LastParsedCopyright || "";
                                    cfg_LastCopyrightLink = wallpaperConfiguration.LastCopyrightLink || "";
                                    _syncing = false;
                                }

                                function openCopyrightLink()
                                {
                                    if (currentCopyrightLink && currentCopyrightLink !== "")
                                        Qt.openUrlExternally(currentCopyrightLink);
                                }

                                implicitWidth: parent.width
                                implicitHeight: parent.height
                                Component.onCompleted: {
                                    if (!wallpaperConfiguration)
                                    {
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

                                            // Provider
                        ComboBox {
                            id: providerInput

                            Kirigami.FormData.label: i18n("Provider:")
                            textRole: "text"
                            valueRole: "value"
                            model: [
                            { text: "Bing", value: "bing" },
                            { text: "Spotlight", value: "spotlight" },
                            { text: "Wikimedia Commons", value: "wikimedia" }
                            ]
                            Component.onCompleted: currentIndex = indexOfValue(cfg_Provider)
                            onActivated: {
                                cfg_Provider = currentValue;
                                hasPreview = false;
                                fetchPreview();
                            }
                        }

                        // Region selector
                        ComboBox {
                            id: marketInput

                            visible: cfg_Provider !== "wikimedia"
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
                            onActivated: {
                                cfg_Market = currentValue;
                                hasPreview = false;
                                fetchPreview();
                            }
                        }

                        Item {
                            implicitHeight: 162
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.largeSpacing
                            Layout.bottomMargin: Kirigami.Units.largeSpacing
                            visible: currentThumbnailSource !== ""

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.ShadowedRectangle {
                                    id: imageContainer

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
                                        cursorShape: currentCopyrightLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: openCopyrightLink()
                                    }
                                }

                                Button {
                                    id: refreshButton

                                    visible: cfg_Provider === "spotlight"
                                    icon.name: "view-refresh"
                                    display: Button.IconOnly
                                    anchors.verticalCenter: parent.verticalCenter
                                    ToolTip.text: i18n("Refresh Image")
                                    ToolTip.visible: hovered
                                    onClicked: fetchPreview()
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
                            elide: Text.ElideRight
                            maximumLineCount: 2
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

                        // Copyright (part inside parentheses)
                        Label {
                            Kirigami.FormData.label: i18n("Copyright:")
                            text: currentParsedCopyright
                            visible: currentParsedCopyright !== ""
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
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

                Connections {
                    target: wallpaperConfiguration
                    function onValueChanged(key, value) {
                        if (key === "LastTitle" || key === "LastDescription" ||
                            key === "LastParsedCopyright" || key === "LastCopyrightLink" ||
                            key === "currentWallpaperThumbnail")
                            syncMetadata();
                    }
                }

                Timer {
                    id: metadataSyncTimer

                    interval: 5000
                    repeat: false
                    onTriggered: syncMetadata()
                }
            }

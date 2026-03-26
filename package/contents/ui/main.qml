/*
SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@aolabs.dev>

SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami 2.20 as Kirigami
import org.kde.notification 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid
import "utils.js" as Utils
import "providers.js" as Providers

WallpaperItem {
    id: main

    property url currentUrl
    readonly property int fillMode: Image.PreserveAspectCrop
        readonly property bool refreshSignal: main.configuration.RefetchSignal
            readonly property string provider: main.configuration.Provider || "bing"
                readonly property int retryRequestCount: main.configuration.RetryRequestCount
                    readonly property int retryRequestDelay: main.configuration.RetryRequestDelay
                        readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
                        property Item pendingImage
                        readonly property string lastValidImagePath: main.configuration.lastValidImagePath || ""
                            property bool isLoading: false
                                property string lastLoadedUrl: ""
                                    property string copyrightText: main.configuration.LastCopyrightText || ""
                                        property string copyrightLink: main.configuration.LastCopyrightLink || ""
                                            property string imageTitle: main.configuration.LastTitle || ""
                                                property string description: main.configuration.LastDescription || ""
                                                    property string parsedCopyright: main.configuration.LastParsedCopyright || ""
                                                        property int consecutiveErrors: 0
                                                        property bool _initialRefreshDone: false

                                                            function log(msg)
                                                            {
                                                                console.log("PotD Enhanced: " + msg);
                                                            }

                                                            function loadFallbackImage()
                                                            {
                                                                var fallback = lastValidImagePath !== "" ? lastValidImagePath : "blackscreen.jpg";
                                                                log("Using fallback image: " + fallback);
                                                                if (main.currentUrl.toString() === fallback) {
                                                                    loadImage();
                                                                } else {
                                                                    main.currentUrl = fallback;
                                                                }
                                                            }

                                                        function showErrorNotification(text)
                                                        {
                                                            consecutiveErrors++;
                                                            if (consecutiveErrors >= 3)
                                                            {
                                                                var note = notificationComponent.createObject(root, {
                                                                "title": "PotD Enhanced Error",
                                                                "text": text,
                                                                "iconName": "dialog-error"
                                                            });
                                                            note.sendEvent();
                                                            consecutiveErrors = 0;
                                                        }
                                                    }

                                                    function refreshImage()
                                                    {
                                                        if (isLoading)
                                                        {
                                                            log("Loading in progress - skipping refresh");
                                                            return;
                                                        }
                                                        isLoading = true;
                                                        fetchImage(main.retryRequestCount);
                                                    }

                                                    function handleRequestError(retries, errorText)
                                                    {
                                                        let msg = "";
                                                        if (retries > 0)
                                                        {
                                                            msg = "Retrying in " + main.retryRequestDelay + " seconds...";
                                                            log(msg);
                                                            retryTimer.retries = retries;
                                                            retryTimer.start();
                                                        } else {
                                                        msg = "Request failed" + (errorText ? ": " + errorText : "");
                                                        log(msg);
                                                        showErrorNotification(msg);
                                                        loadFallbackImage();
                                                        isLoading = false;
                                                    }
                                                }

                                                function applyFetchResult(result)
                                                {
                                                    copyrightText = result.copyrightText;
                                                    copyrightLink = result.copyrightLink;
                                                    imageTitle = result.title;
                                                    description = result.description;
                                                    parsedCopyright = result.copyright;

                                                    main.configuration.LastCopyrightText = copyrightText;
                                                    main.configuration.LastCopyrightLink = copyrightLink;
                                                    main.configuration.LastTitle = imageTitle;
                                                    main.configuration.LastDescription = description;
                                                    main.configuration.LastParsedCopyright = parsedCopyright;
                                                    main.configuration.currentWallpaperThumbnail = result.thumbnailUrl;

                                                    if (result.imageUrl === lastLoadedUrl)
                                                    {
                                                        log("Same image as current, skipping load");
                                                        wallpaper.configuration.writeConfig();
                                                        isLoading = false;
                                                        return;
                                                    }

                                                    consecutiveErrors = 0;
                                                    var oldUrl = main.currentUrl.toString();
                                                    main.currentUrl = result.imageUrl;
                                                    wallpaper.configuration.writeConfig();
                                                    // If URL didn't change, onCurrentUrlChanged won't fire,
                                                    // so loadImage() won't be called — reset isLoading here
                                                    if (main.currentUrl.toString() === oldUrl) {
                                                        log("URL unchanged after fetch, resetting state");
                                                        isLoading = false;
                                                    }
                                                }

                                                function fetchImage(retries)
                                                {
                                                    var provider = main.configuration.Provider || "bing";

                                                    // Use cached response from config preview if available
                                                    var cachedResponse = main.configuration.CachedResponse || "";
                                                    var cachedProvider = main.configuration.CachedProvider || "";
                                                    if (cachedResponse !== "") {
                                                        main.configuration.CachedResponse = "";
                                                        main.configuration.CachedProvider = "";
                                                        if (cachedProvider === provider) {
                                                            log("Using cached response from config preview");
                                                            try {
                                                                var isPortrait = main.height > main.width;
                                                                var result = Providers.parseResponse(provider, cachedResponse, isPortrait);
                                                                if (result) {
                                                                    applyFetchResult(result);
                                                                    return;
                                                                }
                                                            } catch (e) {
                                                                log("Cached response parse error: " + e + ", fetching fresh");
                                                            }
                                                        }
                                                    }

                                                    var market = main.configuration.Market;
                                                    if (!market || market === "")
                                                        market = Utils.detectMarket();
                                                    var url = Providers.buildUrl(provider, market);
                                                    log("Fetching from " + provider + ": " + url);

                                                    var xhr = new XMLHttpRequest();
                                                    xhr.onload = function() {
                                                    if (xhr.status !== 200)
                                                    {
                                                        handleRequestError(retries, xhr.responseText);
                                                        return;
                                                    }
                                                    try {
                                                        var isPortrait = main.height > main.width;
                                                        var result = Providers.parseResponse(provider, xhr.responseText, isPortrait);
                                                        if (!result)
                                                        {
                                                            handleRequestError(retries, "No image in response");
                                                            return;
                                                        }
                                                        applyFetchResult(result);
                                                    } catch (e) {
                                                    handleRequestError(retries, "Parse error: " + e);
                                                }
                                            };
                                            xhr.onerror = function() {
                                            handleRequestError(retries, null);
                                        };
                                        xhr.ontimeout = function() {
                                        handleRequestError(retries, "Request timed out");
                                    };
                                    xhr.open("GET", url);
                                    xhr.setRequestHeader("User-Agent", "PotDEnhanced/1.0 (KDE Plasma Wallpaper; https://github.com)");
                                    xhr.timeout = 30000;
                                    xhr.send();
                                }

                                function loadImage()
                                {
                                    try {
                                        if (main.currentUrl.toString() === lastLoadedUrl && main.pendingImage)
                                        {
                                            log("Skipping duplicate load");
                                            isLoading = false;
                                            return;
                                        }
                                        log("Loading: " + main.currentUrl.toString());
                                        lastLoadedUrl = main.currentUrl.toString();
                                        main.pendingImage = mainImage.createObject(root, {
                                        "source": main.currentUrl,
                                        "fillMode": main.fillMode,
                                        "sourceSize": main.sourceSize
                                    });
                                } catch (e) {
                                log("Error in loadImage: " + e);
                                isLoading = false;
                                main.currentUrl = "blackscreen.jpg";
                                lastLoadedUrl = "blackscreen.jpg";
                                main.pendingImage = mainImage.createObject(root, {
                                "source": "blackscreen.jpg",
                                "fillMode": main.fillMode,
                                "sourceSize": main.sourceSize
                            });
                            root.replace(main.pendingImage);
                        }
                    }

                    anchors.fill: parent
                    onCurrentUrlChanged: loadImage()
                    onRefreshSignalChanged: Qt.callLater(refreshImage)
                    onProviderChanged: if (_initialRefreshDone) Qt.callLater(refreshImage)
                    onWidthChanged: _tryInitialRefresh()
                    onHeightChanged: _tryInitialRefresh()
                    Component.onCompleted: {
                        if (lastValidImagePath !== "") {
                            main.currentUrl = lastValidImagePath;
                        }
                        _tryInitialRefresh();
                        startupRefreshTimer.start();
                    }

                    function _tryInitialRefresh() {
                        if (_initialRefreshDone) return;
                        if (main.width > 0 && main.height > 0) {
                            _initialRefreshDone = true;
                            Qt.callLater(refreshImage);
                        }
                    }
                    onIsLoadingChanged: {
                        if (isLoading)
                            loadingTimeoutTimer.restart();
                        else
                            loadingTimeoutTimer.stop();
                    }

                    contextualActions: [
                        PlasmaCore.Action {
                            text: i18n("Open Wallpaper")
                            icon.name: "folder-open"
                            onTriggered: {
                                if (main.currentUrl && main.currentUrl.toString() !== "" && main.currentUrl.toString() !== "blackscreen.jpg")
                                    Qt.openUrlExternally(main.currentUrl);
                            }
                        },
                        PlasmaCore.Action {
                            text: i18n("Refresh Image")
                            icon.name: "view-refresh"
                            visible: main.provider === "spotlight"
                            onTriggered: refreshImage()
                        }
                    ]

                    Timer {
                        id: retryTimer

                        property int retries

                        interval: main.retryRequestDelay * 1000
                        repeat: false
                        onTriggered: fetchImage(retryTimer.retries - 1)
                    }

                    Timer {
                        id: loadingTimeoutTimer
                        interval: 60000
                        repeat: false
                        onTriggered: {
                            if (isLoading) {
                                log("Loading timeout - resetting isLoading flag");
                                isLoading = false;
                            }
                        }
                    }

                    Timer {
                        id: startupRefreshTimer
                        interval: 5000
                        repeat: false
                        onTriggered: {
                            if (!_initialRefreshDone) {
                                log("Startup fallback: forcing initial refresh");
                                _initialRefreshDone = true;
                                refreshImage();
                            }
                        }
                    }

                    Component {
                        id: notificationComponent

                        Notification {
                            componentName: "plasma_workspace"
                            eventId: "notification"
                            urgency: Notification.HighUrgency
                            autoDelete: true
                        }
                    }

                    QQC2.StackView {
                        id: root

                        anchors.fill: parent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: isLoading ? Qt.BusyCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.NoButton
                        }

                        Component {
                            id: mainImage

                            Image {
                                id: imageItem

                                asynchronous: true
                                cache: false
                                autoTransform: true
                                smooth: true
                                onStatusChanged: {
                                    if (status === Image.Error)
                                    {
                                        log("Error loading image");
                                        showErrorNotification("Failed to load image");
                                        if (imageItem === main.pendingImage)
                                        {
                                            main.pendingImage = null;
                                            imageItem.destroy();
                                        }
                                        isLoading = false;
                                    } else if (status === Image.Ready) {
                                    log("Image loaded successfully");
                                    if (Utils.isHttpUrl(source))
                                    {
                                        main.configuration.lastValidImagePath = source.toString();
                                        wallpaper.configuration.writeConfig();
                                    }
                                    if (imageItem === main.pendingImage && root.currentItem !== imageItem)
                                    {
                                        if (root.depth === 0)
                                            root.push(imageItem);
                                        else
                                            root.replace(imageItem);
                                        }
                                        isLoading = false;
                                    }
                                }
                                QQC2.StackView.onActivated: main.accentColorChanged()
                                QQC2.StackView.onDeactivated: destroy()
                                QQC2.StackView.onRemoved: destroy()
                            }
                        }

                        replaceEnter: Transition {
                            OpacityAnimator {
                                id: replaceEnterOpacityAnimator

                                from: 0
                                to: 1
                                duration: main.doesSkipAnimation ? 1 : Math.round(Kirigami.Units.longDuration * 2.5)
                            }
                        }

                        replaceExit: Transition {
                            PauseAnimation {
                                duration: replaceEnterOpacityAnimator.duration
                            }
                        }
                    }

                    // Overlay: "title - description"
                    Text {
                        id: overlayLabel

                        readonly property string overlayText: {
                            if (imageTitle !== "" && description !== "")
                                return imageTitle + " - " + description;
                            if (imageTitle !== "")
                                return imageTitle;
                            return description;
                        }

                        visible: main.configuration.ShowOverlay && overlayText !== ""
                        text: overlayText
                        color: "white"
                        style: Text.Outline
                        styleColor: "black"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        width: Math.min(implicitWidth, main.width * 0.7)

                        horizontalAlignment: {
                            var pos = main.configuration.OverlayPosition || "bottom-left";
                            if (pos === "top-right" || pos === "bottom-right")
                                return Text.AlignRight;
                            return Text.AlignLeft;
                        }

                        x: {
                            var pos = main.configuration.OverlayPosition || "bottom-left";
                            if (pos === "top-right" || pos === "bottom-right")
                                return main.width - width - 10;
                            return 10;
                        }

                        y: {
                            var pos = main.configuration.OverlayPosition || "bottom-left";
                            if (pos === "top-left" || pos === "top-right")
                                return 10;
                            return main.height - height - 40;
                        }
                    }
                }

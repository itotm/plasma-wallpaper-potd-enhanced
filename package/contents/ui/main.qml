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

WallpaperItem {
    id: main

    property url currentUrl
    readonly property int fillMode: main.configuration.FillMode
        readonly property bool refreshSignal: main.configuration.RefetchSignal
            readonly property int retryRequestCount: main.configuration.RetryRequestCount
                readonly property int retryRequestDelay: main.configuration.RetryRequestDelay
                    readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
                    property Item pendingImage
                    readonly property string lastValidImagePath: main.configuration.lastValidImagePath || ""
                        property bool isLoading: false
                            property string lastLoadedUrl: ""
                                property string copyrightText: main.configuration.LastCopyrightText || ""
                                    property string copyrightLink: main.configuration.LastCopyrightLink || ""

                                        function log(msg)
                                        {
                                            console.log("PotD Enhanced: " + msg);
                                        }

                                        function loadFallbackImage()
                                        {
                                            if (lastValidImagePath !== "")
                                            {
                                                log("Using last valid cached image");
                                                main.currentUrl = lastValidImagePath;
                                            } else {
                                            main.currentUrl = "blackscreen.jpg";
                                        }
                                        loadImage();
                                    }

                                    function showNotification(title, text, iconName, isError)
                                    {
                                        const isErrorNotif = !!isError;
                                        if (isErrorNotif && !main.configuration.ErrorNotification)
                                            return;
                                        if (!isErrorNotif && !main.configuration.RefreshNotification)
                                            return;
                                        var note = notificationComponent.createObject(root, {
                                        "title": title,
                                        "text": text,
                                        "iconName": iconName
                                    });
                                    note.sendEvent();
                                }

                                function refreshImage()
                                {
                                    if (isLoading)
                                    {
                                        log("Loading in progress - skipping refresh");
                                        return;
                                    }
                                    isLoading = true;
                                    fetchBingImage(main.retryRequestCount);
                                }

                                function handleRequestError(retries, errorText)
                                {
                                    let msg = "";
                                    if (retries > 0)
                                    {
                                        msg = "Retrying in " + main.retryRequestDelay + " seconds...";
                                        log(msg);
                                        showNotification("PotD Enhanced Error", msg, "dialog-error", true);
                                        retryTimer.retries = retries;
                                        retryTimer.start();
                                    } else {
                                    msg = "Request failed" + (errorText ? ": " + errorText : "");
                                    showNotification("PotD Enhanced Error", msg, "dialog-error", true);
                                    loadFallbackImage();
                                    isLoading = false;
                                }
                            }

                            function fetchBingImage(retries)
                            {
                                var market = main.configuration.Market;
                                if (!market || market === "")
                                    market = Utils.detectMarket();
                                var url = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=" + encodeURIComponent(market);
                                log("Fetching from: " + url);

                                if (main.configuration.RefreshNotification)
                                    showNotification("PotD Enhanced", "Fetching daily image...", "preferences-desktop-wallpaper");

                                var xhr = new XMLHttpRequest();
                                xhr.onload = function() {
                                if (xhr.status !== 200)
                                {
                                    handleRequestError(retries, xhr.responseText);
                                    return;
                                }
                                try {
                                    var data = JSON.parse(xhr.responseText);
                                    if (!data.images || data.images.length === 0)
                                    {
                                        handleRequestError(retries, "No images in response");
                                        return;
                                    }
                                    var image = data.images[0];
                                    var urlbase = image.urlbase;
                                    if (!urlbase)
                                    {
                                        handleRequestError(retries, "Missing urlbase in response");
                                        return;
                                    }

                                    // Build full resolution URL
                                    var suffix = "_UHD.jpg";
                                    if (main.height > main.width)
                                        suffix = "_1080x1920.jpg";
                                    var imageUrl = "https://www.bing.com" + urlbase + suffix;

                                    // Update copyright info
                                    copyrightText = image.copyright || "";
                                    copyrightLink = image.copyrightlink || "";
                                    main.configuration.LastCopyrightText = copyrightText;
                                    main.configuration.LastCopyrightLink = copyrightLink;
                                    main.configuration.currentWallpaperThumbnail = "https://www.bing.com" + urlbase + "_320x240.jpg";
                                    wallpaper.configuration.writeConfig();

                                    if (imageUrl === lastLoadedUrl)
                                    {
                                        log("Same image as current, skipping load");
                                        isLoading = false;
                                        return;
                                    }

                                    main.currentUrl = imageUrl;
                                    main.configuration.lastValidImagePath = imageUrl;
                                    wallpaper.configuration.writeConfig();
                                    showNotification("PotD Enhanced", copyrightText, "preferences-desktop-wallpaper");
                                } catch (e) {
                                handleRequestError(retries, "JSON parse error: " + e);
                            }
                        };
                        xhr.onerror = function() {
                        handleRequestError(retries, null);
                    };
                    xhr.open("GET", url);
                    xhr.timeout = 10000;
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
    onFillModeChanged: loadImage()
    onRefreshSignalChanged: refreshTimer.restart()

    contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open in Browser")
            icon.name: "internet-web-browser"
            onTriggered: {
                if (main.copyrightLink)
                    Qt.openUrlExternally(main.copyrightLink);
                else
                    Qt.openUrlExternally("https://www.bing.com");
                }
            },
            PlasmaCore.Action {
                text: i18n("Refresh Wallpaper")
                icon.name: "view-refresh"
                onTriggered: refreshImage()
            }
        ]

        Timer {
            id: retryTimer

            property int retries

            interval: main.retryRequestDelay * 1000
            repeat: false
            onTriggered: fetchBingImage(retryTimer.retries - 1)
        }

        Timer {
            id: refreshTimer

            interval: main.configuration.WallpaperDelay * 60 * 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                log("refreshTimer triggered");
                Qt.callLater(refreshImage);
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
                            showNotification("PotD Enhanced Error", "Failed to load image", "dialog-error", true);
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

        // Copyright overlay
        Text {
            id: copyrightLabel

            visible: main.configuration.ShowCopyright && copyrightText !== ""
            text: copyrightText
            color: "white"
            style: Text.Outline
            styleColor: "black"
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.Wrap
            width: Math.min(implicitWidth, main.width * 0.7)

            horizontalAlignment: {
                var pos = main.configuration.CopyrightPosition || "bottom-left";
                if (pos === "top-right" || pos === "bottom-right")
                    return Text.AlignRight;
                return Text.AlignLeft;
            }

            x: {
                var pos = main.configuration.CopyrightPosition || "bottom-left";
                if (pos === "top-right" || pos === "bottom-right")
                    return main.width - width - 10;
                return 10;
            }

            y: {
                var pos = main.configuration.CopyrightPosition || "bottom-left";
                if (pos === "top-left" || pos === "top-right")
                    return 10;
                return main.height - height - 40;
            }
        }
    }

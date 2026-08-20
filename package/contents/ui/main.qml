import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid
import "utils.js" as Utils
import "providers.js" as Providers

WallpaperItem {
    id: main

    loading: false
    property url currentUrl
    readonly property int fillMode: main.provider === "dscovr"
        ? Image.PreserveAspectFit
        : Image.PreserveAspectCrop
    readonly property bool refreshSignal: main.configuration.RefetchSignal
    readonly property string provider: main.configuration.Provider || "bing"
    readonly property int retryRequestDelay: main.configuration.RetryRequestDelay
    readonly property int retryRequestCount: main.configuration.RetryRequestCount
    readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
    property Item pendingImage
    readonly property string lastValidImagePath: main.configuration.lastValidImagePath || ""
    property bool isLoading: false
    property string lastLoadedUrl: ""
    property bool _initialRefreshDone: false
    property bool _triedFallback: false
    property bool _fromConfigApply: false
    property bool _pendingProviderRefresh: false
    readonly property string lastFetchDate: main.configuration.LastFetchDate || ""

    function log(msg) {
        console.log("PotD Enhanced: " + msg);
    }

    function refreshImage() {
        if (isLoading) {
            log("Loading in progress - skipping refresh");
            // If the refresh was triggered by a config apply, drop the pending
            // cached-URL flag so it is not spuriously consumed later.
            _fromConfigApply = false;
            return;
        }
        isLoading = true;
        _triedFallback = false;
        fetchImage();
    }

    function _handleFetchError(errorText) {
        if (!_triedFallback) {
            var prov = main.provider;
            var mkt = (main.configuration && main.configuration.Market) || "";
            if (!mkt || mkt === "") mkt = Utils.detectMarket();
            var fallbackUrl = Providers.buildFallbackUrl(prov, mkt);
            if (fallbackUrl) {
                _triedFallback = true;
                log("Primary URL failed, trying fallback: " + fallbackUrl);
                _fetchFromFallbackUrl(fallbackUrl);
                return;
            }
        }
        var attempts = main.retryRequestCount + 1;
        var msg = "Request failed" + (errorText ? ": " + errorText : "");
        log(msg);
        isLoading = false;
    }

    function _fetchFromFallbackUrl(url) {
        var prov = main.provider;
        log("Fetching fallback from " + prov + ": " + url);

        Utils.httpGet(url, function(responseText) {
            try {
                var isPortrait = main.height > main.width;
                var result = Providers.parseFallbackResponse(prov, responseText, isPortrait);
                if (!result) {
                    _handleFetchError("No image in fallback response");
                    return;
                }
                applyFetchResult(result);
            } catch (e) {
                _handleFetchError("Fallback parse error: " + e);
            }
        }, function(errorText) {
            _handleFetchError(errorText);
        }, { retryDelay: main.retryRequestDelay * 1000, maxRetries: main.retryRequestCount });
    }

    function applyFetchResult(result) {
        if (!main.configuration) {
            log("configuration not ready in applyFetchResult");
            isLoading = false;
            return;
        }
        main.configuration.LastCopyrightText = result.copyrightText;
        main.configuration.LastCopyrightLink = result.copyrightLink;
        main.configuration.LastTitle = result.title;
        main.configuration.LastDescription = result.description;
        main.configuration.LastParsedCopyright = result.copyright;
        main.configuration.currentWallpaperThumbnail = result.thumbnailUrl;
        main.configuration.CachedProvider = main.provider;

        if (result.imageUrl === lastLoadedUrl) {
            log("Same image as current, skipping load");
            wallpaper.configuration.writeConfig();
            isLoading = false;
            return;
        }

        var oldUrl = main.currentUrl.toString();
        main.currentUrl = result.imageUrl;
        wallpaper.configuration.writeConfig();
        if (main.currentUrl.toString() === oldUrl) {
            log("URL unchanged after fetch, resetting state");
            isLoading = false;
        }
    }

    function fetchImage() {
        if (!main.configuration) {
            log("configuration not ready, deferring fetch");
            Qt.callLater(function() {
                if (main.configuration) fetchImage();
                else isLoading = false;
            });
            return;
        }

        if (_fromConfigApply) {
            _fromConfigApply = false;
            var cachedUrl = main.configuration.CachedImageUrl || "";
            main.configuration.CachedImageUrl = "";
            if (cachedUrl !== "") {
                log("Using cached image URL from config: " + cachedUrl);
                var oldUrl = main.currentUrl.toString();
                main.currentUrl = cachedUrl;
                main.configuration.CachedProvider = main.provider;
                wallpaper.configuration.writeConfig();
                if (main.currentUrl.toString() === oldUrl) {
                    log("Cached URL same as current, resetting state");
                    isLoading = false;
                }
                return;
            }
        }

        var prov = main.provider;
        var market = main.configuration.Market;
        if (!market || market === "")
            market = Utils.detectMarket();
        var url = Providers.buildUrl(prov, market);
        log("Fetching from " + prov + ": " + url);

        Utils.httpGet(url, function(responseText) {
            try {
                var isPortrait = main.height > main.width;
                var result = Providers.parseResponse(prov, responseText, isPortrait);
                if (!result) {
                    _handleFetchError("No image in response");
                    return;
                }
                applyFetchResult(result);
            } catch (e) {
                _handleFetchError("Parse error: " + e);
            }
        }, function(errorText) {
            _handleFetchError(errorText);
        }, { retryDelay: main.retryRequestDelay * 1000, maxRetries: main.retryRequestCount });
    }

    function loadImage() {
        try {
            if (main.currentUrl.toString() === lastLoadedUrl && main.pendingImage) {
                log("Skipping duplicate load");
                isLoading = false;
                return;
            }
            log("Loading: " + main.currentUrl.toString());
            lastLoadedUrl = main.currentUrl.toString();
            // Destroy any previous pending image that was never pushed to the stack
            if (main.pendingImage && main.pendingImage !== root.currentItem) {
                main.pendingImage.destroy();
                main.pendingImage = null;
            }
            main.pendingImage = mainImage.createObject(root, {
                "source": main.currentUrl,
                "fillMode": main.fillMode,
                "sourceSize": main.sourceSize
            });
        } catch (e) {
            log("Error in loadImage: " + e);
            isLoading = false;
            main.currentUrl = "";
            lastLoadedUrl = "";
            main.pendingImage = null;
        }
    }

    anchors.fill: parent
    onCurrentUrlChanged: loadImage()
    onRefreshSignalChanged: {
        _fromConfigApply = true;
        Qt.callLater(refreshImage);
    }
    onProviderChanged: {
        if (_initialRefreshDone) {
            if (isLoading) {
                // Provider changed while a fetch is in progress: queue a refresh
                // once the current load finishes.
                _pendingProviderRefresh = true;
                return;
            }
            root.clear();
            Qt.callLater(refreshImage);
        }
    }
    onWidthChanged: _tryInitialRefresh()
    onHeightChanged: _tryInitialRefresh()
    Component.onCompleted: {
        if (main.configuration && main.configuration.CachedImageUrl) {
            main.configuration.CachedImageUrl = "";
            wallpaper.configuration.writeConfig();
        }
        _tryInitialRefresh();
        startupRefreshTimer.start();
    }

    function _tryInitialRefresh() {
        if (_initialRefreshDone) return;
        if (main.width > 0 && main.height > 0 && main.configuration) {
            _initialRefreshDone = true;
            var today = new Date().toISOString().substring(0, 10);
            var cachedProv = main.configuration.CachedProvider || "";
            var providerMismatch = cachedProv !== "" && cachedProv !== provider;
            if (provider === "spotlight" || lastFetchDate !== today || providerMismatch) {
                log("Refreshing (provider=" + provider + ", cached=" + cachedProv + ", lastFetch=" + (lastFetchDate || "none") + ", today=" + today + ")");
                refreshImage();
            } else if (lastValidImagePath && lastValidImagePath !== "") {
                log("Already fetched today (" + today + ") - loading last image: " + lastValidImagePath);
                main.currentUrl = lastValidImagePath;
            } else {
                log("Already fetched today (" + today + ") but no cached image - refreshing");
                refreshImage();
            }
        }
    }

    onIsLoadingChanged: {
        if (isLoading)
            loadingTimeoutTimer.restart();
        else {
            loadingTimeoutTimer.stop();
            if (_pendingProviderRefresh) {
                _pendingProviderRefresh = false;
                root.clear();
                Qt.callLater(refreshImage);
            }
        }
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

    // Auto refresh timer for providers that update hourly (Spotlight, DSCOVR)
    // Only runs when the "Enable Hourly Refresh" option is checked in config.
    Timer {
        id: loadingTimeoutTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (isLoading) {
                log("Loading timeout - destroying pending image");
                if (main.pendingImage) {
                    main.pendingImage.destroy();
                    main.pendingImage = null;
                }
                isLoading = false;
                log("Loading timeout - fetch failed");
            }
        }
    }

    Timer {
        id: startupRefreshTimer
        interval: 5000
        repeat: false
        onTriggered: {
            _tryInitialRefresh()
        }
    }

    Timer {
        id: spotlightRefreshTimer
        interval: 3600000
        repeat: true
        onTriggered: {
            if ((main.provider === "spotlight" || main.provider === "dscovr") && 
                main.configuration && 
                main.configuration.EnableHourlyRefresh) {
                refreshImage()
            }
        }
    }

    QQC2.StackView {
        id: root

        anchors.fill: parent

        background: Rectangle {
            color: "black"
        }

        Component {
            id: mainImage

            Image {
                id: imageItem

                asynchronous: true
                cache: true
                autoTransform: true
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        log("Error loading image");
                        if (imageItem === main.pendingImage) {
                            main.pendingImage = null;
                            imageItem.destroy();
                        }
                        isLoading = false;
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully");
                        main.configuration.LastFetchDate = new Date().toISOString().substring(0, 10);
                        if (Utils.isHttpUrl(source)) {
                            main.configuration.lastValidImagePath = source.toString();
                            wallpaper.configuration.writeConfig();
                        }
                        if (imageItem === main.pendingImage && root.currentItem !== imageItem) {
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

    Text {
        id: overlayLabel

        readonly property string overlayText: {
            var title = main.configuration.LastTitle || "";
            var desc = main.configuration.LastDescription || "";
            if (title !== "" && desc !== "")
                return title + " - " + desc;
            if (title !== "")
                return title;
            return desc;
        }

        visible: main.configuration && main.configuration.ShowOverlay && overlayText !== ""
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

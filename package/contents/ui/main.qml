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
    readonly property int maxStartupRetries: 10
    readonly property int startupRetryInterval: 30000
    readonly property int maxImageLoadRetries: 3
    readonly property int imageLoadRetryInterval: 10000
    // Worst-case duration of the HTTP fetch phase: every attempt can take up to
    // the XHR timeout (60 s, see utils.js) plus the delay before the next retry.
    readonly property int fetchPhaseTimeoutMs: ((main.retryRequestCount + 1) * (60 + main.retryRequestDelay) + 60) * 1000
    // Time allowed for the image download/decode phase.
    readonly property int imageLoadPhaseTimeoutMs: 180000
    property Item pendingImage
    readonly property string lastValidImagePath: main.configuration.lastValidImagePath || ""
    property bool isLoading: false
    property string lastLoadedUrl: ""
    property bool _initialRefreshDone: false
    // True once the first image has actually been displayed. Unlike
    // _initialRefreshDone (which means "initial refresh was attempted"), this
    // is what decides whether we are still in the startup phase and should
    // keep retrying after failures.
    property bool _everLoaded: false
    property bool _triedFallback: false
    property bool _fromConfigApply: false
    property bool _pendingProviderRefresh: false
    property int _startupRetryCount: 0
    property int _imageLoadRetryCount: 0
    // Incremented every time a new fetch starts. Async callbacks capture the
    // current value and ignore results that belong to an older run.
    property int _fetchGeneration: 0

    readonly property string lastFetchDate: main.configuration.LastFetchDate || ""

    // Caption of the image that is being loaded. It is copied onto the Image
    // item at creation time and only becomes visible when that item reaches the
    // stack, so the text always matches the picture actually on screen.
    property string pendingOverlayText: ""

    function composeOverlayText(title, description, copyright) {
        var t = title || "";
        var d = description || "";
        // If there is no description, fall back to the copyright holder so the
        // overlay still shows something meaningful.
        if (d === "")
            d = copyright || "";
        if (t !== "" && d !== "")
            return t + " - " + d;
        return t !== "" ? t : d;
    }

    // Used when the caption changes but the picture does not, so the overlay
    // would otherwise keep showing the previous text.
    function updateDisplayedOverlayText() {
        if (root.currentItem)
            root.currentItem.overlayText = main.pendingOverlayText;
    }

    function log(msg) {
        console.log("PotD Enhanced: " + msg);
    }

    // force: cancel any run already in progress instead of bailing out. Used by
    // user-initiated refreshes so they are never swallowed by a long retry chain.
    function refreshImage(force) {
        if (isLoading) {
            if (!force) {
                log("Loading in progress - skipping refresh");
                // If the refresh was triggered by a config apply, drop the pending
                // cached-URL flag so it is not spuriously consumed later.
                _fromConfigApply = false;
                return;
            }
            log("Loading in progress - cancelling it for a forced refresh");
            // Bumping _fetchGeneration below invalidates the in-flight XHR
            // callbacks; drop the pending image so it cannot report status.
            if (main.pendingImage && main.pendingImage !== root.currentItem) {
                main.pendingImage.destroy();
                main.pendingImage = null;
            }
            lastLoadedUrl = "";
        }
        isLoading = true;
        _triedFallback = false;
        _imageLoadRetryCount = 0;
        // New fetch run: invalidate any in-flight async callbacks and (re)arm
        // the watchdog for the fetch phase (the XHR chain can be long when
        // many retries are configured).
        _fetchGeneration++;
        loadingTimeoutTimer.interval = fetchPhaseTimeoutMs;
        loadingTimeoutTimer.restart();
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
        log(msg + " (" + attempts + " attempts)");
        isLoading = false;
        // If no image has been displayed yet (startup phase) and we haven't
        // exhausted our startup retries, schedule a retry. Note: the network
        // may not be available right after login, so keep trying.
        if (!_everLoaded && _startupRetryCount < maxStartupRetries) {
            _startupRetryCount++;
            log("Scheduling startup retry " + _startupRetryCount + "/" + maxStartupRetries + " in " + (startupRetryInterval / 1000) + "s");
            startupRetryTimer.start();
        }
    }

    function _fetchFromFallbackUrl(url) {
        var prov = main.provider;
        var generation = _fetchGeneration;
        log("Fetching fallback from " + prov + ": " + url);
        // The fallback runs a full retry chain of its own, so it needs a fresh
        // budget: without this it would inherit whatever is left of the primary
        // phase's watchdog and could be aborted mid-flight.
        loadingTimeoutTimer.interval = fetchPhaseTimeoutMs;
        loadingTimeoutTimer.restart();

        Utils.httpGet(url, function(responseText) {
            if (generation !== _fetchGeneration) {
                log("Stale fallback response ignored");
                return;
            }
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
            if (generation !== _fetchGeneration) return;
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
        main.pendingOverlayText = composeOverlayText(result.title, result.description, result.copyright);

        if (result.imageUrl === lastLoadedUrl) {
            log("Same image as current, skipping load");
            wallpaper.configuration.writeConfig();
            updateDisplayedOverlayText();
            isLoading = false;
            return;
        }

        var oldUrl = main.currentUrl.toString();
        main.currentUrl = result.imageUrl;
        wallpaper.configuration.writeConfig();
        if (main.currentUrl.toString() === oldUrl) {
            // currentUrl did not change, so onCurrentUrlChanged won't fire:
            // load explicitly unless the image is already on screen.
            log("URL unchanged after fetch, loading explicitly");
            loadImage();
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
                // The config dialog stored title/description together with the
                // cached URL, so they describe this very image.
                main.pendingOverlayText = composeOverlayText(main.configuration.LastTitle, main.configuration.LastDescription, main.configuration.LastParsedCopyright);
                var oldUrl = main.currentUrl.toString();
                main.currentUrl = cachedUrl;
                main.configuration.CachedProvider = main.provider;
                wallpaper.configuration.writeConfig();
                if (main.currentUrl.toString() === oldUrl) {
                    // currentUrl did not change, so onCurrentUrlChanged won't
                    // fire: load explicitly (loadImage skips if already shown).
                    log("Cached URL same as current, loading explicitly");
                    loadImage();
                }
                return;
            }
        }

        var prov = main.provider;
        var market = main.configuration.Market;
        if (!market || market === "")
            market = Utils.detectMarket();
        var url = Providers.buildUrl(prov, market);
        var generation = _fetchGeneration;
        log("Fetching from " + prov + ": " + url);

        Utils.httpGet(url, function(responseText) {
            if (generation !== _fetchGeneration) {
                log("Stale response ignored");
                return;
            }
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
            if (generation !== _fetchGeneration) return;
            _handleFetchError(errorText);
        }, { retryDelay: main.retryRequestDelay * 1000, maxRetries: main.retryRequestCount });
    }

    function loadImage() {
        try {
            var urlStr = main.currentUrl.toString();
            if (urlStr === "") {
                log("No image URL to load");
                isLoading = false;
                return;
            }
            if (urlStr === lastLoadedUrl && main.pendingImage) {
                log("Skipping duplicate load");
                updateDisplayedOverlayText();
                isLoading = false;
                return;
            }
            log("Loading: " + urlStr);
            lastLoadedUrl = urlStr;
            isLoading = true;
            // Destroy any previous pending image that was never pushed to the stack
            if (main.pendingImage && main.pendingImage !== root.currentItem) {
                main.pendingImage.destroy();
                main.pendingImage = null;
            }
            // We are now in the image download/decode phase: rearm the watchdog
            // with the (shorter) load-phase timeout.
            loadingTimeoutTimer.interval = imageLoadPhaseTimeoutMs;
            loadingTimeoutTimer.restart();
            main.pendingImage = mainImage.createObject(root, {
                "source": main.currentUrl,
                "fillMode": main.fillMode,
                "sourceSize": main.sourceSize,
                "overlayText": main.pendingOverlayText
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
                main.pendingOverlayText = composeOverlayText(main.configuration.LastTitle, main.configuration.LastDescription, main.configuration.LastParsedCopyright);
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
                if (main.currentUrl && main.currentUrl.toString() !== "")
                    Qt.openUrlExternally(main.currentUrl);
            }
        },
        PlasmaCore.Action {
            text: i18n("Refresh Image")
            icon.name: "view-refresh"
            visible: main.provider === "spotlight"
            onTriggered: refreshImage(true)
        }
    ]

    // Watchdog: aborts a fetch/load run that hangs. The interval is adjusted
    // per phase (HTTP fetch vs image download) before each restart.
    Timer {
        id: loadingTimeoutTimer
        // Interval is adjusted per phase (fetch vs image load) before restart.
        interval: main.fetchPhaseTimeoutMs
        repeat: false
        onTriggered: {
            if (isLoading) {
                log("Loading timeout - aborting current run");
                // Invalidate any in-flight XHR callbacks so late results from
                // the aborted run cannot mutate state.
                _fetchGeneration++;
                if (main.pendingImage && main.pendingImage !== root.currentItem) {
                    main.pendingImage.destroy();
                    main.pendingImage = null;
                }
                lastLoadedUrl = "";
                isLoading = false;
                // During startup keep trying so the wallpaper eventually shows.
                if (!_everLoaded && _startupRetryCount < maxStartupRetries) {
                    _startupRetryCount++;
                    log("Scheduling startup retry after timeout " + _startupRetryCount + "/" + maxStartupRetries);
                    startupRetryTimer.start();
                }
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

    // Retries the fetch after a startup failure (e.g. network not ready yet),
    // so the wallpaper is eventually applied instead of leaving a black screen.
    Timer {
        id: startupRetryTimer
        interval: main.startupRetryInterval
        repeat: false
        onTriggered: {
            log("Retrying after startup failure");
            refreshImage()
        }
    }

    Timer {
        id: imageLoadRetryTimer
        interval: main.imageLoadRetryInterval
        repeat: false
        onTriggered: {
            log("Retrying image load");
            loadImage()
        }
    }

    // Auto refresh timer for providers that update frequently (Spotlight, DSCOVR).
    // Only acts when the "Enable Hourly Refresh" option is checked in config.
    Timer {
        id: spotlightRefreshTimer
        interval: 3600000
        repeat: true
        running: true
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

                // Caption shown by the overlay while this image is on screen.
                property string overlayText: ""

                asynchronous: true
                cache: true
                autoTransform: true
                smooth: true
                onStatusChanged: {
                    // Ignore status changes from images that are not the
                    // current pending one (e.g. destroyed/stale instances).
                    if (imageItem !== main.pendingImage)
                        return;
                    if (status === Image.Error) {
                        log("Error loading image");
                        var failedUrl = lastLoadedUrl;
                        main.pendingImage = null;
                        imageItem.destroy();
                        isLoading = false;
                        // Allow the next load to retry this URL instead of being
                        // skipped as a duplicate.
                        lastLoadedUrl = "";
                        if (!_everLoaded) {
                            // Startup phase: no image shown yet, keep retrying
                            // the whole fetch so the wallpaper eventually loads.
                            if (_startupRetryCount < maxStartupRetries) {
                                _startupRetryCount++;
                                log("Scheduling startup retry " + _startupRetryCount + "/" + maxStartupRetries);
                                startupRetryTimer.start();
                            }
                        } else if (_imageLoadRetryCount < maxImageLoadRetries) {
                            // Already had an image before: retry loading the
                            // same URL a few times (transient errors).
                            _imageLoadRetryCount++;
                            log("Scheduling image load retry " + _imageLoadRetryCount + "/" + maxImageLoadRetries);
                            imageLoadRetryTimer.start();
                        } else {
                            log("Image load retries exhausted");
                            _imageLoadRetryCount = 0;
                            // Fall back to the last known good image, unless it
                            // is the one that just failed.
                            var fallbackPath = main.configuration.lastValidImagePath || "";
                            if (fallbackPath !== "" && fallbackPath !== failedUrl) {
                                log("Falling back to last valid image: " + fallbackPath);
                                main.currentUrl = fallbackPath;
                            }
                        }
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully");
                        _everLoaded = true;
                        _startupRetryCount = 0;
                        _imageLoadRetryCount = 0;
                        main.configuration.LastFetchDate = new Date().toISOString().substring(0, 10);
                        if (Utils.isHttpUrl(source)) {
                            main.configuration.lastValidImagePath = source.toString();
                            wallpaper.configuration.writeConfig();
                        }
                        if (root.currentItem !== imageItem) {
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
                duration: Math.round(Kirigami.Units.longDuration * 2.5)
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

        // Follows the image currently on the stack, so the caption appears (and
        // changes) together with the picture it belongs to, never before it.
        readonly property string overlayText: root.currentItem ? (root.currentItem.overlayText || "") : ""

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

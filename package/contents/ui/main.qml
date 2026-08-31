import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid
import "utils.js" as Utils
import "providers.js" as Providers
import "imagecache.js" as ImageCache

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
    // How old the last fetch must be before the hourly auto-refresh kicks in.
    readonly property int hourlyRefreshIntervalMs: 3600000
    // Cadence of the hourly-refresh check timer.
    readonly property int hourlyCheckIntervalMs: 300000
    property Item pendingImage
    // Cached-restore image (data URI) being decoded. Kept separate from
    // pendingImage so the fetch/load state machine never confuses the two.
    property Item pendingCachedImage
    // Http URL whose cached (data URI) copy was put on screen from the
    // persistent image cache.
    property string cachedDisplayedUrl: ""
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

    // Displays a data URI restored from the persistent cache without touching
    // the fetch/load state machine (isLoading, watchdog, lastLoadedUrl): a
    // refresh can keep running in parallel and will replace this image when
    // its own picture lands on the stack.
    function _showCachedImage(dataUri) {
        _dropPendingCachedImage();
        main.pendingCachedImage = mainImage.createObject(root, {
            "source": dataUri,
            "fillMode": main.fillMode,
            "sourceSize": main.sourceSize,
            "overlayText": main.pendingOverlayText,
            "isCachedRestore": true
        });
    }

    function _dropPendingCachedImage() {
        if (main.pendingCachedImage) {
            main.pendingCachedImage.destroy();
            main.pendingCachedImage = null;
        }
    }

    // Best-effort persistent caching: the Image element cannot expose its
    // decoded bytes, so the file is downloaded once more via XHR and stored
    // as a data URI in the shared LocalStorage cache. On the next plasmashell
    // start the cached copy is displayed instantly, without network.
    function cacheImage(url) {
        try {
            if (!Utils.isHttpUrl(url))
                return;
            if (ImageCache.has(url)) {
                ImageCache.touch(url);
                return;
            }
            if (ImageCache.isPending(url))
                return;
            ImageCache.markPending(url);
            Utils.httpGetBinary(url, function(buf, contentType) {
                ImageCache.clearPending(url);
                var dataUri = Utils.arrayBufferToDataUri(buf, contentType);
                if (dataUri !== "" && ImageCache.store(url, dataUri))
                    log("Cached image for next startup (" + Math.round(dataUri.length / 1024) + " KiB)");
            }, function(err) {
                ImageCache.clearPending(url);
                log("Image caching failed (non-fatal): " + err);
            });
        } catch (e) {
            log("Image caching error (non-fatal): " + e);
        }
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
            _dropPendingCachedImage();
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
        main.configuration.LastRefreshTime = Date.now().toString();
        main.configuration.LastCopyrightText = result.copyrightText;
        main.configuration.LastCopyrightLink = result.copyrightLink;
        main.configuration.LastTitle = result.title;
        main.configuration.LastDescription = result.description;
        main.configuration.LastParsedCopyright = result.copyright;
        main.configuration.currentWallpaperThumbnail = result.thumbnailUrl;
        main.configuration.CachedProvider = main.provider;
        main.pendingOverlayText = composeOverlayText(result.title, result.description, result.copyright);

        // The image is already on screen either as a live load or as the
        // cached copy restored at startup: no need to download it again.
        var cachedCopyOnScreen = result.imageUrl !== ""
            && result.imageUrl === cachedDisplayedUrl
            && root.currentItem && root.currentItem.isCachedRestore === true;
        if (result.imageUrl === lastLoadedUrl || cachedCopyOnScreen) {
            log(cachedCopyOnScreen
                ? "Fetched image matches the cached copy on screen, skipping load"
                : "Same image as current, skipping load");
            // The fetch itself succeeded: record it so the daily check does
            // not refetch, and keep the cache entry alive in the LRU prune.
            main.configuration.LastFetchDate = new Date().toISOString().substring(0, 10);
            ImageCache.touch(result.imageUrl);
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
                // The config dialog fetched this image moments ago, so the
                // hourly auto-refresh countdown starts from now.
                main.configuration.LastRefreshTime = Date.now().toString();
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
        // At startup the binding flips from the default to the stored config
        // value, which is not a real "Apply" from the config dialog: acting on
        // it would trigger a spurious second fetch racing the initial refresh.
        if (!_initialRefreshDone)
            return;
        _fromConfigApply = true;
        Qt.callLater(refreshImage);
    }
    onProviderChanged: {
        if (_initialRefreshDone) {
            _dropPendingCachedImage();
            cachedDisplayedUrl = "";
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
            var needRefresh = provider === "spotlight" || lastFetchDate !== today || providerMismatch;

            // Whether a refresh is due or not, put the persisted copy of the
            // last image on screen right away: it shows instantly, without
            // network, and is simply replaced if a newer image arrives.
            var cachedData = "";
            if (!providerMismatch && lastValidImagePath !== "")
                cachedData = ImageCache.get(lastValidImagePath);
            if (cachedData !== "") {
                log("Showing cached copy of last image: " + lastValidImagePath);
                main.pendingOverlayText = composeOverlayText(main.configuration.LastTitle, main.configuration.LastDescription, main.configuration.LastParsedCopyright);
                cachedDisplayedUrl = lastValidImagePath;
                _showCachedImage(cachedData);
            }

            if (needRefresh) {
                log("Refreshing (provider=" + provider + ", cached=" + cachedProv + ", lastFetch=" + (lastFetchDate || "none") + ", today=" + today + ")");
                refreshImage();
            } else if (cachedData !== "") {
                log("Already fetched today (" + today + ") - cached copy shown, no network needed");
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
                // When only the cached copy is on screen, currentUrl is empty:
                // open the http URL the copy was made from instead.
                var url = main.currentUrl ? main.currentUrl.toString() : "";
                if (url === "")
                    url = main.cachedDisplayedUrl || main.configuration.lastValidImagePath || "";
                if (url !== "")
                    Qt.openUrlExternally(url);
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

    // Hourly auto-refresh for providers that update frequently (Spotlight,
    // DSCOVR), gated by the "Enable Hourly Refresh" config option.
    //
    // Deliberately NOT a single one-hour timer: a fire lost for any reason
    // (event coalescing, suspend, instance teardown) would silently stop the
    // rotation for good, and a restart would reset the countdown. Instead the
    // last successful fetch time is persisted in the config and checked every
    // few minutes, so a missed check only delays the refresh by one tick.
    function checkHourlyRefresh() {
        if (main.provider !== "spotlight" && main.provider !== "dscovr")
            return;
        if (!main.configuration || !main.configuration.EnableHourlyRefresh)
            return;
        if (isLoading)
            return;
        var last = parseInt(main.configuration.LastRefreshTime || "0", 10);
        if (isNaN(last))
            last = 0;
        var elapsed = Date.now() - last;
        // Half a tick of tolerance: the check grid is not aligned with the
        // fetch timestamps, so without it the refresh lands on the tick AFTER
        // the full hour (~65 min cadence) instead of the one closest to it.
        // elapsed < 0 means the clock moved backwards: treat the stamp as
        // stale rather than waiting for the clock to catch up.
        if (elapsed >= hourlyRefreshIntervalMs - hourlyCheckIntervalMs / 2 || elapsed < 0) {
            log("Hourly refresh due (last fetch "
                + (last === 0 ? "never" : Math.round(elapsed / 60000) + " min ago") + ")");
            refreshImage();
        }
    }

    Timer {
        id: hourlyRefreshTimer
        interval: main.hourlyCheckIntervalMs
        repeat: true
        running: true
        onTriggered: checkHourlyRefresh()
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
                // True for an image restored from the persistent cache (data
                // URI): it bypasses the fetch/load state machine entirely.
                property bool isCachedRestore: false

                asynchronous: true
                cache: true
                autoTransform: true
                smooth: true
                onStatusChanged: {
                    // Ignore status changes from images that are not the
                    // current pending one (e.g. destroyed/stale instances).
                    if (imageItem !== main.pendingImage && imageItem !== main.pendingCachedImage)
                        return;
                    if (isCachedRestore) {
                        if (status === Image.Error) {
                            // Corrupt cache entry: drop it, the normal
                            // fetch/retry path is unaffected and will recover.
                            log("Cached image failed to decode, dropping it");
                            main.pendingCachedImage = null;
                            imageItem.destroy();
                            // If nothing else is on screen or in flight (i.e.
                            // no refresh was due today), fall back to loading
                            // the network copy of the same image.
                            if (!root.currentItem && !isLoading && main.cachedDisplayedUrl !== "") {
                                log("Loading network copy instead: " + main.cachedDisplayedUrl);
                                main.currentUrl = main.cachedDisplayedUrl;
                            }
                        } else if (status === Image.Ready) {
                            main.pendingCachedImage = null;
                            if (root.currentItem && !root.currentItem.isCachedRestore) {
                                // A freshly fetched image reached the stack
                                // first: this restore is obsolete.
                                imageItem.destroy();
                                return;
                            }
                            log("Cached image displayed");
                            if (root.depth === 0)
                                root.push(imageItem);
                            else
                                root.replace(imageItem);
                            // Deliberately do NOT touch isLoading, _everLoaded
                            // or the watchdog: a refresh may be running in
                            // parallel and must keep its own state.
                        }
                        return;
                    }
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
                            // is the one that just failed. Prefer the cached
                            // copy: the network is evidently unreliable here.
                            var fallbackPath = main.configuration.lastValidImagePath || "";
                            if (fallbackPath !== "" && fallbackPath !== failedUrl) {
                                var cachedData = ImageCache.get(fallbackPath);
                                if (cachedData !== "") {
                                    log("Falling back to cached copy of last valid image: " + fallbackPath);
                                    main.pendingOverlayText = composeOverlayText(main.configuration.LastTitle, main.configuration.LastDescription, main.configuration.LastParsedCopyright);
                                    main.cachedDisplayedUrl = fallbackPath;
                                    main._showCachedImage(cachedData);
                                } else {
                                    log("Falling back to last valid image: " + fallbackPath);
                                    main.currentUrl = fallbackPath;
                                }
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
                            // Persist a copy so the next shell start can show
                            // it instantly, before any network is available.
                            main.cacheImage(source.toString());
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
            var pos = (main.configuration && main.configuration.OverlayPosition) || "bottom-left";
            if (pos === "top-right" || pos === "bottom-right")
                return Text.AlignRight;
            return Text.AlignLeft;
        }

        x: {
            var pos = (main.configuration && main.configuration.OverlayPosition) || "bottom-left";
            if (pos === "top-right" || pos === "bottom-right")
                return main.width - width - 10;
            return 10;
        }

        y: {
            var pos = (main.configuration && main.configuration.OverlayPosition) || "bottom-left";
            if (pos === "top-left" || pos === "top-right")
                return 10;
            return main.height - height - 40;
        }
    }
}

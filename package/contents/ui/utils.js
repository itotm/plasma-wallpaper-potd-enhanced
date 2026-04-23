function isHttpUrl(url) {
    if (!url) {
        return false;
    }
    return url.toString().startsWith("http");
}

function detectMarket() {
    var locale = Qt.locale().name;
    var converted = locale.replace("_", "-");
    var markets = [
        "de-DE", "en-AU", "en-CA", "en-GB", "en-IN", "en-NZ", "en-US",
        "es-ES", "fr-CA", "fr-FR", "it-IT", "ja-JP", "pt-BR", "zh-CN"
    ];
    for (var i = 0; i < markets.length; i++) {
        if (markets[i] === converted) {
            return converted;
        }
    }
    var lang = converted.split("-")[0];
    for (var i = 0; i < markets.length; i++) {
        if (markets[i].indexOf(lang + "-") === 0) {
            return markets[i];
        }
    }
    return "en-US";
}

function parseCopyright(str) {
    if (!str) {
        return { description: "", copyright: "" };
    }
    var match = str.match(/^(.*?)\s*\(©\s*(.*)\)\s*$/);
    if (match) {
        return { description: match[1].trim(), copyright: match[2].trim() };
    }
    match = str.match(/^(.*?)\s*\((.*)\)\s*$/);
    if (match) {
        return { description: match[1].trim(), copyright: match[2].trim() };
    }
    return { description: str, copyright: "" };
}

/**
 * Centralized HTTP GET with retry and timeout.
 *
 * @param {string}   url        - URL to fetch
 * @param {function} onSuccess  - Called with (responseText) on HTTP 200
 * @param {function} onError    - Called with (errorString) after all retries exhausted
 * @param {object}   [opts]     - Optional overrides:
 *                                  maxRetries (default 3),
 *                                  timeout    (default 60000 ms),
 *                                  retryDelay (default 5000 ms)
 */
function httpGet(url, onSuccess, onError, opts) {
    var maxRetries = (opts && opts.maxRetries !== undefined) ? opts.maxRetries : 3;
    var timeout    = (opts && opts.timeout    !== undefined) ? opts.timeout    : 60000;
    var retryDelay = (opts && opts.retryDelay !== undefined) ? opts.retryDelay : 5000;

    function attempt(retriesLeft) {
        var xhr = new XMLHttpRequest();
        xhr.onload = function() {
            if (xhr.status === 200) {
                onSuccess(xhr.responseText);
            } else if (retriesLeft > 0) {
                console.log("PotD Enhanced: HTTP " + xhr.status + ", retrying in " + retryDelay + "ms (" + retriesLeft + " left)");
                _delay(retryDelay, function() { attempt(retriesLeft - 1); });
            } else {
                onError("HTTP " + xhr.status + (xhr.responseText ? ": " + xhr.responseText.substring(0, 200) : ""));
            }
        };
        xhr.onerror = function() {
            if (retriesLeft > 0) {
                console.log("PotD Enhanced: Network error, retrying in " + retryDelay + "ms (" + retriesLeft + " left)");
                _delay(retryDelay, function() { attempt(retriesLeft - 1); });
            } else {
                onError("Network error");
            }
        };
        xhr.ontimeout = function() {
            if (retriesLeft > 0) {
                console.log("PotD Enhanced: Timeout, retrying in " + retryDelay + "ms (" + retriesLeft + " left)");
                _delay(retryDelay, function() { attempt(retriesLeft - 1); });
            } else {
                onError("Request timed out");
            }
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "PotDEnhanced/1.0 (KDE Plasma Wallpaper; https://github.com)");
        xhr.timeout = timeout;
        xhr.send();
    }

    attempt(maxRetries);
}

/**
 * Read a cached provider result. Returns the entry object or null if missing/expired.
 */
function getProviderCache(cacheJson, provider, retentionDays) {
    try {
        var cache = JSON.parse(cacheJson || "{}");
        var entry = cache[provider];
        if (!entry || !entry.imageUrl || !entry.fetchDate) return null;
        var diffDays = (new Date() - new Date(entry.fetchDate + "T00:00:00")) / 86400000;
        if (diffDays > retentionDays) return null;
        return entry;
    } catch (e) {
        return null;
    }
}

/**
 * Write a provider result to cache and purge expired entries.
 * Returns the updated JSON string.
 */
function setProviderCache(cacheJson, provider, result, retentionDays) {
    try {
        var cache = JSON.parse(cacheJson || "{}");
        cache[provider] = {
            imageUrl: result.imageUrl,
            thumbnailUrl: result.thumbnailUrl,
            title: result.title,
            description: result.description,
            copyright: result.copyright,
            copyrightLink: result.copyrightLink,
            copyrightText: result.copyrightText,
            fetchDate: new Date().toISOString().substring(0, 10)
        };
        var now = new Date();
        for (var key in cache) {
            if (cache[key].fetchDate) {
                if ((now - new Date(cache[key].fetchDate + "T00:00:00")) / 86400000 > retentionDays)
                    delete cache[key];
            }
        }
        return JSON.stringify(cache);
    } catch (e) {
        return cacheJson;
    }
}

// Internal: schedule a callback after delayMs using a Timer component.
// Falls back to immediate call if Qt.createQmlObject is unavailable.
function _delay(delayMs, callback) {
    try {
        var timer = Qt.createQmlObject(
            "import QtQuick; Timer { interval: " + delayMs + "; repeat: false; running: true }",
            Qt.application, "delayTimer");
        timer.triggered.connect(function() {
            timer.destroy();
            callback();
        });
    } catch (e) {
        callback();
    }
}

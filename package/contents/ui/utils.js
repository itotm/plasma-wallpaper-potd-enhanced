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
 * HTTP GET of a binary resource. Single attempt, no retries: this is used for
 * opportunistic caching where a failure is acceptable.
 *
 * @param {string}   url        - URL to fetch
 * @param {function} onSuccess  - Called with (arrayBuffer, contentType) on HTTP 200
 * @param {function} onError    - Called with (errorString)
 * @param {number}   [timeout]  - Timeout in ms (default 120000)
 */
function httpGetBinary(url, onSuccess, onError, timeout) {
    var xhr = new XMLHttpRequest();
    xhr.onload = function() {
        if (xhr.status === 200 && xhr.response) {
            onSuccess(xhr.response, xhr.getResponseHeader("Content-Type") || "");
        } else {
            onError("HTTP " + xhr.status);
        }
    };
    xhr.onerror = function() { onError("Network error"); };
    xhr.ontimeout = function() { onError("Request timed out"); };
    xhr.open("GET", url);
    xhr.responseType = "arraybuffer";
    xhr.setRequestHeader("User-Agent", "PotDEnhanced/1.0 (KDE Plasma Wallpaper; https://github.com)");
    xhr.timeout = timeout !== undefined ? timeout : 120000;
    xhr.send();
}

var _B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Pure-JS base64 (Qt.btoa cannot be used: it encodes the UTF-8 form of the
// string, which mangles bytes >= 0x80 and corrupts binary data).
function _base64Encode(bytes) {
    var out = [];
    var chunk = "";
    var len = bytes.length;
    var i, n;
    for (i = 0; i + 2 < len; i += 3) {
        n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
        chunk += _B64_ALPHABET[(n >> 18) & 63] + _B64_ALPHABET[(n >> 12) & 63]
               + _B64_ALPHABET[(n >> 6) & 63] + _B64_ALPHABET[n & 63];
        if (chunk.length >= 8192) {
            out.push(chunk);
            chunk = "";
        }
    }
    if (i < len) {
        var b1 = i + 1 < len ? bytes[i + 1] : -1;
        n = (bytes[i] << 16) | ((b1 < 0 ? 0 : b1) << 8);
        chunk += _B64_ALPHABET[(n >> 18) & 63] + _B64_ALPHABET[(n >> 12) & 63];
        chunk += (b1 < 0 ? "=" : _B64_ALPHABET[(n >> 6) & 63]) + "=";
    }
    out.push(chunk);
    return out.join("");
}

function _guessImageMime(bytes) {
    if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF)
        return "image/jpeg";
    if (bytes.length >= 2 && bytes[0] === 0x89 && bytes[1] === 0x50)
        return "image/png";
    if (bytes.length >= 12 && bytes[8] === 0x57 && bytes[9] === 0x45
            && bytes[10] === 0x42 && bytes[11] === 0x50)
        return "image/webp";
    if (bytes.length >= 3 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46)
        return "image/gif";
    return "image/jpeg";
}

/**
 * Encodes a downloaded image into a data: URI usable as an Image source.
 * Returns "" on failure.
 */
function arrayBufferToDataUri(buf, contentType) {
    try {
        var bytes = new Uint8Array(buf);
        if (bytes.length === 0)
            return "";
        var mime = (contentType || "").split(";")[0].trim().toLowerCase();
        if (mime.indexOf("image/") !== 0)
            mime = _guessImageMime(bytes);
        return "data:" + mime + ";base64," + _base64Encode(bytes);
    } catch (e) {
        console.log("PotD Enhanced: data URI encode failed: " + e);
        return "";
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

.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

// Persistent cache of the last few wallpapers, stored as base64 data URIs in
// the QML LocalStorage SQLite database (the only persistent storage reachable
// from pure QML/JS: wallpaper plugins cannot touch the file system directly,
// and stuffing megabytes of base64 into the applet config would bloat
// plasma-org.kde.plasma.desktop-appletsrc, which is parsed at every shell
// start and rewritten by every plasmoid config change).
//
// The database lives in the QML engine's offline-storage path and is shared
// by every containment in the plasmashell process, so with multiple monitors
// the cache is keyed by image URL: each containment keeps its own URL and
// metadata in its per-screen config and looks the pixels up here. Two screens
// showing the same provider share a single entry (and a single download).
//
// Every function is best-effort: any failure returns ""/false and the caller
// falls back to the network path, exactly as before the cache existed.

var MAX_ENTRIES = 6;
// Safety valve: never store absurdly large blobs (data URI length in chars).
var MAX_DATAURI_LENGTH = 24 * 1024 * 1024;

var _db = null;
var _dbFailed = false;
// URLs with a download+store already in flight, so that two containments
// showing the same image do not both download it for the cache. Shared state
// works because .pragma library scripts are singletons per QML engine.
var _pending = {};

function _log(msg) {
    console.log("PotD Enhanced cache: " + msg);
}

function _getDb() {
    if (_db)
        return _db;
    if (_dbFailed)
        return null;
    try {
        _db = Sql.LocalStorage.openDatabaseSync(
            "potd-enhanced-image-cache", "1.0",
            "PotD Enhanced wallpaper image cache", 50 * 1024 * 1024);
        _db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS image_cache(" +
                "url TEXT PRIMARY KEY, data TEXT NOT NULL, ts INTEGER NOT NULL)");
        });
    } catch (e) {
        _db = null;
        _dbFailed = true;
        _log("LocalStorage unavailable: " + e);
    }
    return _db;
}

// Returns the cached data URI for the given image URL, or "" on miss/error.
// A hit also refreshes the entry's timestamp so the LRU prune in store()
// keeps entries that are actually being displayed (e.g. a weekly provider on
// one monitor must survive the hourly churn of Spotlight on another).
function get(url) {
    if (!url || url === "")
        return "";
    var db = _getDb();
    if (!db)
        return "";
    var data = "";
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql("SELECT data FROM image_cache WHERE url = ?", [url]);
            if (rs.rows.length > 0) {
                data = rs.rows.item(0).data || "";
                tx.executeSql("UPDATE image_cache SET ts = ? WHERE url = ?", [Date.now(), url]);
            }
        });
    } catch (e) {
        _log("read failed: " + e);
        return "";
    }
    return data;
}

function has(url) {
    if (!url || url === "")
        return false;
    var db = _getDb();
    if (!db)
        return false;
    var found = false;
    try {
        db.transaction(function(tx) {
            var rs = tx.executeSql("SELECT 1 FROM image_cache WHERE url = ?", [url]);
            found = rs.rows.length > 0;
        });
    } catch (e) {
        _log("read failed: " + e);
        return false;
    }
    return found;
}

// Refreshes the timestamp of an entry (no-op if the URL is not cached).
function touch(url) {
    if (!url || url === "")
        return;
    var db = _getDb();
    if (!db)
        return;
    try {
        db.transaction(function(tx) {
            tx.executeSql("UPDATE image_cache SET ts = ? WHERE url = ?", [Date.now(), url]);
        });
    } catch (e) {
        _log("touch failed: " + e);
    }
}

// Stores/replaces an entry and prunes the least recently used ones beyond
// MAX_ENTRIES. Returns true on success.
function store(url, dataUri) {
    if (!url || url === "" || !dataUri || dataUri === "")
        return false;
    if (dataUri.length > MAX_DATAURI_LENGTH) {
        _log("entry too large, not caching (" + dataUri.length + " chars)");
        return false;
    }
    var db = _getDb();
    if (!db)
        return false;
    try {
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO image_cache(url, data, ts) VALUES(?, ?, ?)",
                [url, dataUri, Date.now()]);
            tx.executeSql("DELETE FROM image_cache WHERE url NOT IN (" +
                "SELECT url FROM image_cache ORDER BY ts DESC LIMIT " + MAX_ENTRIES + ")");
        });
    } catch (e) {
        _log("write failed: " + e);
        return false;
    }
    return true;
}

function isPending(url) {
    return _pending[url] === true;
}

function markPending(url) {
    _pending[url] = true;
}

function clearPending(url) {
    delete _pending[url];
}

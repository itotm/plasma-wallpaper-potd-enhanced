// Flickr Interestingness - based on KDE's official flickrprovider.cpp
// Uses flickr.interestingness.getList API (date = 2 days ago)
// API key from KDE autoconfig: https://autoconfig.kde.org/potd/flickrprovider.conf

var _apiKey = "65a0b7386726804b1af4f30dcf69adaf";

function buildUrl(market) {
    var date = new Date();
    date.setDate(date.getDate() - 2);

    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    var dateStr = date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());

    return "https://api.flickr.com/services/rest/"
        + "?api_key=" + _apiKey
        + "&method=flickr.interestingness.getList"
        + "&date=" + dateStr
        + "&extras=url_k,url_h,url_o"
        + "&per_page=100";
}

// Simple seeded PRNG matching KDE's deterministic selection
// Seed: days since 2022-02-03 (Plasma 5.24.0 release date)
function _seededRandom(max) {
    var epoch = new Date(2022, 1, 3); // Feb 3 2022
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var seed = Math.floor((today - epoch) / 86400000);
    // Simple hash to spread values
    seed = ((seed * 1103515245 + 12345) & 0x7fffffff);
    return seed % max;
}

function parseResponse(responseText, isPortrait) {
    // Parse <photo> elements from XML response
    var photoRegex = /<photo\s[^>]*ispublic="1"[^>]*>/g;
    var photos = [];
    var match;

    while ((match = photoRegex.exec(responseText)) !== null) {
        var tag = match[0];

        // Extract best URL: prefer url_k, then url_h, then url_o
        var urlMatch = tag.match(/url_k="([^"]+)"/) ||
                       tag.match(/url_h="([^"]+)"/) ||
                       tag.match(/url_o="([^"]+)"/);
        if (!urlMatch) continue;

        var url = urlMatch[1];

        // If url_k or url_h present and url_o also present, prefer url_o (higher quality)
        if ((tag.indexOf('url_k="') !== -1 || tag.indexOf('url_h="') !== -1) && tag.indexOf('url_o="') !== -1) {
            var oMatch = tag.match(/url_o="([^"]+)"/);
            if (oMatch) url = oMatch[1];
        }

        var titleMatch = tag.match(/title="([^"]*)"/);
        var ownerMatch = tag.match(/owner="([^"]*)"/);
        var idMatch = tag.match(/id="([^"]*)"/);

        photos.push({
            url: url,
            title: titleMatch ? titleMatch[1] : "",
            owner: ownerMatch ? ownerMatch[1] : "",
            id: idMatch ? idMatch[1] : ""
        });
    }

    if (photos.length === 0) return null;

    // Deterministic random pick (same as KDE's C++ provider)
    var idx = _seededRandom(photos.length);
    var photo = photos[idx];

    var photoPageUrl = "";
    if (photo.owner && photo.id) {
        photoPageUrl = "https://www.flickr.com/photos/" + photo.owner + "/" + photo.id;
    }

    // Decode HTML entities in title
    var title = photo.title
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#x27;/g, "'")
        .replace(/&#39;/g, "'");

    return {
        imageUrl: photo.url,
        thumbnailUrl: photo.url,
        title: title,
        description: "",
        copyright: "Flickr",
        copyrightLink: photoPageUrl,
        copyrightText: "Flickr"
    };
}

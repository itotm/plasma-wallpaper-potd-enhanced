function isHttpUrl(url) {
    if (!url)
        return false;
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
        if (markets[i] === converted)
            return converted;
    }
    var lang = converted.split("-")[0];
    for (var i = 0; i < markets.length; i++) {
        if (markets[i].indexOf(lang + "-") === 0)
            return markets[i];
    }
    return "en-US";
}

function parseCopyright(str) {
    if (!str)
        return { description: "", copyright: "" };
    var match = str.match(/^(.*?)\s*\(©\s*(.*)\)\s*$/);
    if (match)
        return { description: match[1].trim(), copyright: match[2].trim() };
    match = str.match(/^(.*?)\s*\((.*)\)\s*$/);
    if (match)
        return { description: match[1].trim(), copyright: match[2].trim() };
    return { description: str, copyright: "" };
}

// --- Provider abstraction ---

// Build API URL for a given provider and market/locale
function buildProviderUrl(provider, market) {
    if (provider === "spotlight") {
        var country = market.split("-")[1] || "US";
        return "https://fd.api.iris.microsoft.com/v4/api/selection?&placement=88000820&bcnt=1&country="
            + encodeURIComponent(country) + "&locale=" + encodeURIComponent(market) + "&fmt=json";
    }
    // Default: Bing
    return "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=" + encodeURIComponent(market);
}

// Parse Bing API response into common image result
function parseBingResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data.images || data.images.length === 0)
        return null;
    var image = data.images[0];
    var urlbase = image.urlbase;
    if (!urlbase)
        return null;

    var suffix = isPortrait ? "_1080x1920.jpg" : "_UHD.jpg";
    var imageUrl = "https://www.bing.com" + urlbase + suffix;
    var thumbnailUrl = "https://www.bing.com" + urlbase + "_320x240.jpg";

    var rawCopyright = image.copyright || "";
    var parsed = parseCopyright(rawCopyright);
    var rawTitle = image.title || "";
    var title = (rawTitle === "Info") ? "" : rawTitle;

    return {
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: parsed.description,
        copyright: parsed.copyright,
        copyrightLink: image.copyrightlink || "",
        copyrightText: rawCopyright
    };
}

// Parse Spotlight API v4 response into common image result
function parseSpotlightResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data.batchrsp || !data.batchrsp.items || data.batchrsp.items.length === 0)
        return null;

    var itemWrapper = data.batchrsp.items[0];
    if (!itemWrapper.item)
        return null;

    var item = JSON.parse(itemWrapper.item);
    if (!item.ad)
        return null;

    var ad = item.ad;

    // Extract image URL
    var urlField = isPortrait ? "portraitImage" : "landscapeImage";
    var imageUrl = "";
    if (ad[urlField] && ad[urlField].asset)
        imageUrl = ad[urlField].asset;
    if (!imageUrl)
        return null;

    // Extract title from iconHoverText (first line) or title field
    var title = "";
    if (ad.iconHoverText) {
        title = ad.iconHoverText.split(/[\r\n]/)[0];
    }
    if (!title && ad.title) {
        title = ad.title;
    }

    // Extract copyright
    var copyright = ad.copyright || "";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        title: title,
        description: "",
        copyright: copyright,
        copyrightLink: imageUrl,
        copyrightText: copyright
    };
}

// Dispatch to the correct provider parser
function parseProviderResponse(provider, responseText, isPortrait) {
    if (provider === "spotlight")
        return parseSpotlightResponse(responseText, isPortrait);
    return parseBingResponse(responseText, isPortrait);
}

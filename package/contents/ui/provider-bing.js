function buildUrl(market) {
    return "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt="
        + encodeURIComponent(market);
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

function parseResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data.images || data.images.length === 0) {
        return null;
    }

    var image = data.images[0];
    var urlbase = image.urlbase;
    if (!urlbase) {
        return null;
    }

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

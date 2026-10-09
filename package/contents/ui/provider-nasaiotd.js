// NASA Image of the Day — RSS feed on www.nasa.gov.
// Each <item> has an <enclosure> with the original upload. Files under
// www.nasa.gov/wp-content/uploads/ can be resized with a ?w= query, used to cap
// the wallpaper to UHD and to get a light thumbnail; images hosted elsewhere
// (images-assets.nasa.gov "~large" files) are used as they are.

var MAX_WIDTH = 3840;
var THUMB_WIDTH = 640;

function buildUrl(market) {
    return "https://www.nasa.gov/feeds/iotd-feed/";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function decodeEntities(s) {
    return s
        .replace(/&#0?38;/g, "&")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#0?39;/g, "'")
        .replace(/&#8217;/g, "’")
        .replace(/&#8216;/g, "‘")
        .replace(/&#8220;/g, "“")
        .replace(/&#8221;/g, "”")
        .replace(/&hellip;/g, "…")
        .replace(/&nbsp;/g, " ");
}

function tagContent(item, tag) {
    var match = item.match(new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)</" + tag + ">"));
    if (!match) {
        return "";
    }
    var cdataMatch = match[1].match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
    return cdataMatch ? cdataMatch[1] : match[1];
}

function plainText(html) {
    // Entities first: an escaped description only becomes markup once decoded.
    return stripHtml(decodeEntities(html)).replace(/\s+/g, " ").trim();
}

function parseItem(item) {
    var enclosure = item.match(/<enclosure[^>]*>/);
    if (!enclosure) {
        return null;
    }
    var urlMatch = enclosure[0].match(/url="([^"]+)"/);
    var typeMatch = enclosure[0].match(/type="([^"]+)"/);
    if (!urlMatch || (typeMatch && typeMatch[1].indexOf("image/") !== 0)) {
        return null;
    }
    var original = decodeEntities(urlMatch[1]);

    var imageUrl = original;
    var thumbnailUrl = original;
    if (/^https:\/\/www\.nasa\.gov\/wp-content\/uploads\//.test(original) && original.indexOf("?") === -1) {
        imageUrl = original + "?w=" + MAX_WIDTH;
        thumbnailUrl = original + "?w=" + THUMB_WIDTH;
    }

    var description = plainText(tagContent(item, "description"));

    var copyright = "NASA";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        title: plainText(tagContent(item, "title")),
        description: description,
        copyright: copyright,
        copyrightLink: tagContent(item, "link").trim() || "https://www.nasa.gov/image-of-the-day/",
        copyrightText: copyright
    };
}

function parseResponse(responseText, isPortrait) {
    // Items are newest first: take the most recent one with an image.
    var items = responseText.match(/<item>[\s\S]*?<\/item>/g);
    if (!items) {
        return null;
    }
    for (var i = 0; i < items.length; i++) {
        var result = parseItem(items[i]);
        if (result) {
            return result;
        }
    }
    return null;
}

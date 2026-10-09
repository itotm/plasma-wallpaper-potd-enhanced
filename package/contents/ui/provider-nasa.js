// NASA Astronomy Picture of the Day — RSS feed on science.nasa.gov.
// apod.nasa.gov now redirects to science.nasa.gov/apod/, and the APOD endpoint
// of api.nasa.gov is unreliable (timeouts, 503 "upstream connect error").
//
// Each <item> carries the picture in <apod:hdurl>, a resizable URL:
//   https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/...?w=..&h=..
// (older pictures use /content/dam/science/... instead). The query string is
// replaced with our own size, capped to UHD: some originals exceed 8000 px and
// 25 MB.
//
// The feed has no media type: on video days hdurl is just a small still, so
// items whose declared width is below MIN_WIDTH are skipped.

var MAX_SIZE = 3840;
var THUMB_SIZE = 640;
var MIN_WIDTH = 800;

function buildUrl(market) {
    return "https://science.nasa.gov/feed/apod-basic/";
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

// Content of the first <tag>...</tag> in item, with any CDATA wrapper removed.
function tagContent(item, tag) {
    var match = item.match(new RegExp("<" + tag + "[^>]*>([\\s\\S]*?)</" + tag + ">"));
    if (!match) {
        return "";
    }
    var cdataMatch = match[1].match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
    return cdataMatch ? cdataMatch[1] : match[1];
}

function plainText(html) {
    return decodeEntities(stripHtml(html)).replace(/\s+/g, " ").trim();
}

// Caps the credit line, which can list a dozen people and institutions.
function truncate(text) {
    if (text.length > 200) {
        return text.substring(0, 200).replace(/\s+\S*$/, "") + "…";
    }
    return text;
}

function sizedUrl(base, size) {
    return base + "?w=" + size + "&h=" + size + "&fit=clip";
}

// Returns a wallpaper entry for a single <item>, or null when it carries no
// usable still image (video days).
function parseItem(item) {
    var hdurl = decodeEntities(tagContent(item, "apod:hdurl")).trim();
    if (!hdurl) {
        return null;
    }

    // w=0 means "unknown": only skip when a small width is actually declared.
    var widthMatch = hdurl.match(/[?&]w=(\d+)/);
    if (widthMatch) {
        var width = parseInt(widthMatch[1], 10);
        if (width > 0 && width < MIN_WIDTH) {
            return null;
        }
    }

    var base = hdurl.split("?")[0].replace("/content/dam/", "/dynamicimage/assets/");
    if (!/\.(jpe?g|png|gif|webp)$/i.test(base)) {
        return null;
    }

    var description = plainText(tagContent(item, "apod:explanation")).replace(/^Explanation:\s*/i, "");

    var copyright = plainText(tagContent(item, "apod:copyright"));
    if (!copyright) {
        copyright = plainText(tagContent(item, "apod:credit"));
    }
    copyright = truncate(copyright);

    return {
        imageUrl: sizedUrl(base, MAX_SIZE),
        thumbnailUrl: sizedUrl(base, THUMB_SIZE),
        title: plainText(tagContent(item, "title")),
        description: description,
        copyright: copyright,
        copyrightLink: tagContent(item, "link").trim() || "https://science.nasa.gov/apod/",
        copyrightText: copyright
    };
}

function parseResponse(responseText, isPortrait) {
    // Items are newest first: take the most recent one with a still image.
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

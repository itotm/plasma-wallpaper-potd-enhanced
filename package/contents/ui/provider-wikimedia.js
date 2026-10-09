.import "text.js" as TextUtils

function padZero(n) {
    return n < 10 ? "0" + n : String(n);
}

function buildUrl(market) {
    var lang = market.split("-")[0];
    var now = new Date();
    var date = now.getFullYear() + "-" + padZero(now.getMonth() + 1) + "-" + padZero(now.getDate());

    return "https://commons.wikimedia.org/w/api.php?action=query"
        + "&generator=images&titles=Template:Potd/" + encodeURIComponent(date)
        + "&prop=imageinfo&iiprop=url|extmetadata"
        + "&iiurlwidth=1920"
        + "&iiextmetadatalanguage=" + encodeURIComponent(lang)
        + "&format=json";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function decodeEntities(s) {
    return s
        .replace(/&quot;/g, '"')
        .replace(/&#0?39;/g, "'")
        .replace(/&nbsp;/g, " ")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&");
}

function parseResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data.query || !data.query.pages) {
        return null;
    }

    var pages = data.query.pages;
    var page = null;
    for (var id in pages) {
        if (pages[id].imageinfo) {
            page = pages[id];
            break;
        }
    }
    if (!page) {
        return null;
    }

    var info = page.imageinfo[0];
    var imageUrl = info.thumburl || info.url;
    var thumbnailUrl = imageUrl;

    var ext = info.extmetadata || {};

    // Title and description both come from the localized ImageDescription:
    // the title is its beginning, up to the end of the first sentence or the
    // first comma or parenthesis; the description is the rest of the text.
    // Without an ImageDescription, the title comes from ObjectName and there
    // is no description.
    var title = "";
    var description = "";
    if (ext.ImageDescription && ext.ImageDescription.value) {
        var text = decodeEntities(stripHtml(ext.ImageDescription.value)).replace(/\s+/g, " ").trim();
        title = TextUtils.firstSentence(text).replace(/[.!?]$/, "");
        var titleCut = title.search(/[,(]/);
        if (titleCut > 0) {
            title = title.substring(0, titleCut).trim();
        }
        description = text.substring(title.length).replace(/^[\s,.;:!?\u2013\u2014-]+/, "");
    } else if (ext.ObjectName && ext.ObjectName.value) {
        title = stripHtml(ext.ObjectName.value);
        var cutoff = title.search(/[,(]/);
        if (cutoff > 0) {
            title = title.substring(0, cutoff).trim();
        }
    } else if (page.title) {
        title = page.title.replace(/^File:/, "").replace(/\.[^.]+$/, "").replace(/_/g, " ");
    }

    // Copyright: attribution + license
    var copyright = "";
    if (ext.Attribution && ext.Attribution.value) {
        copyright = stripHtml(ext.Attribution.value);
    } else if (ext.Artist && ext.Artist.value) {
        copyright = stripHtml(ext.Artist.value);
    }
    if (ext.LicenseShortName && ext.LicenseShortName.value) {
        var license = ext.LicenseShortName.value;
        if (copyright) {
            copyright = copyright + " (" + license + ")";
        } else {
            copyright = license;
        }
    }

    var copyrightLink = info.descriptionurl || "";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        copyright: copyright,
        copyrightLink: copyrightLink,
        copyrightText: copyright
    };
}

// Shared parsing for the sites built on djangoplicity: ESO, ESA/Hubble,
// ESA/Webb and NOIRLab. Their image feeds have the same layout:
//   <item>
//     <title>, <link>https://<site>/images/<id>/</link>
//     <description> entity-escaped HTML (sometimes CDATA): an <img>, then <p>s
//     <enclosure url="https://<cdn>/.../screen/<id>.jpg">
// The "large" size of the image lives next to the "screen" one.

function decodeEntities(s) {
    return s
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#x([0-9a-f]+);/gi, function(m, hex) { return String.fromCharCode(parseInt(hex, 16)); })
        .replace(/&#(\d+);/g, function(m, dec) { return String.fromCharCode(parseInt(dec, 10)); })
        .replace(/&hellip;/g, "…")
        .replace(/&nbsp;/g, " ")
        .replace(/&amp;/g, "&");
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function unwrapCdata(s) {
    var cdataMatch = s.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
    return cdataMatch ? cdataMatch[1] : s;
}

// Returns a wallpaper entry for a single <item>, or null when it has no still
// image (occasional videos).
function parseItem(item, copyright) {
    var enclosureMatch = item.match(/<enclosure[^>]*url="([^"]+)"/);
    if (!enclosureMatch) {
        return null;
    }
    var screenUrl = enclosureMatch[1];
    if (!/\.(jpg|jpeg|png)$/i.test(screenUrl)) {
        return null;
    }

    var title = "";
    var titleMatch = item.match(/<title>([\s\S]*?)<\/title>/);
    if (titleMatch) {
        title = decodeEntities(unwrapCdata(titleMatch[1])).replace(/\s+/g, " ").trim();
    }

    // First paragraph of the description. The HTML is entity-escaped, and
    // its text may contain entities of its own: decode before and after
    // stripping the tags.
    var description = "";
    var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
    if (descMatch) {
        var pMatch = decodeEntities(unwrapCdata(descMatch[1])).match(/<p>([\s\S]*?)<\/p>/);
        if (pMatch) {
            description = decodeEntities(stripHtml(pMatch[1])).replace(/\s+/g, " ").trim();
        }
    }

    // Some feeds still publish http:// links
    var link = "";
    var linkMatch = item.match(/<link>([^<]+)<\/link>/);
    if (linkMatch) {
        link = linkMatch[1].trim().replace(/^http:\/\//, "https://");
    }

    return {
        imageUrl: screenUrl.replace("/screen/", "/large/"),
        thumbnailUrl: screenUrl,
        title: title,
        description: description,
        copyright: copyright,
        copyrightLink: link,
        copyrightText: copyright
    };
}

// Latest usable item of a feed. linkPattern (optional) keeps only the items
// whose <link> matches, to pick e.g. the Picture of the Month out of a feed
// with all the images of the site.
function parseFeed(responseText, copyright, linkPattern) {
    var items = responseText.match(/<item>[\s\S]*?<\/item>/g);
    if (!items) {
        return null;
    }
    for (var i = 0; i < items.length; i++) {
        if (linkPattern) {
            var linkMatch = items[i].match(/<link>([^<]+)<\/link>/);
            if (!linkMatch || !linkPattern.test(linkMatch[1])) {
                continue;
            }
        }
        var result = parseItem(items[i], copyright);
        if (result) {
            return result;
        }
    }
    return null;
}

// Fallback for an HTML listing page (e.g. /images/potw/): only the id of the
// latest image can be extracted, so there is no title or description.
//   idPattern:  regex whose first group is the image id, e.g. /\/(potw\d{4}[a-z])\//
//   imagesBase: CDN folder containing the large/ and screen/ sizes
//   pageBase:   site folder of the image pages
function parseListing(responseText, idPattern, imagesBase, pageBase, copyright) {
    var match = responseText.match(idPattern);
    if (!match) {
        return null;
    }
    var id = match[1];
    return {
        imageUrl: imagesBase + "large/" + id + ".jpg",
        thumbnailUrl: imagesBase + "screen/" + id + ".jpg",
        title: "",
        description: "",
        copyright: copyright,
        copyrightLink: pageBase + id + "/",
        copyrightText: copyright
    };
}

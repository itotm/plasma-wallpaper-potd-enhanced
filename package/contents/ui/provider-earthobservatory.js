// NASA Earth Observatory — Image of the Day
// Feed: https://science.nasa.gov/feed/earth-observatory/image-of-the-day
// Items contain <content:encoded> with HTML including a download link to the
// full-resolution image under assets.science.nasa.gov/content/dam/science/esd/eo/...
//
// Not every Image of the Day is a still: some entries are videos (<video> /
// <media:player>, only an .mp4 under content/dam) and carry no downloadable
// image at all. Those entries are skipped and the next one is used instead.

function buildUrl(market) {
    return "https://science.nasa.gov/feed/earth-observatory/image-of-the-day";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function decodeEntities(s) {
    return s
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

function escapeRegExp(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Returns a wallpaper entry for a single <item>, or null when the item carries
// no usable full-resolution still (video entries, teaser-only entries).
function parseItem(item) {
    // Extract full content block for image URLs
    var contentHtml = "";
    var contentMatch = item.match(/<content:encoded>([\s\S]*?)<\/content:encoded>/);
    if (contentMatch) {
        contentHtml = contentMatch[1];
        var ccData = contentHtml.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
        if (ccData) {
            contentHtml = ccData[1];
        }
    }

    // The large JPEG from the Downloads section:
    //   https://assets.science.nasa.gov/content/dam/science/esd/eo/images/iotd/.../<name>_lrg.jpg
    // This is the only reliable full-resolution asset; if it is absent the item
    // is not usable as a wallpaper and the caller moves on to the next one.
    var largeMatch = contentHtml.match(/https:\/\/assets\.science\.nasa\.gov\/content\/dam\/science\/esd\/eo\/images\/iotd\/[^"'\s]+?_lrg\.(?:jpg|jpeg|png)/i);
    if (!largeMatch) {
        return null;
    }
    var imageUrl = decodeEntities(largeMatch[0]);

    // Thumbnail: a dynamicimage variant of the SAME article. Restricting the
    // search to the article slug matters because the content block also embeds
    // "related articles" thumbnails belonging to completely different stories.
    var thumbnailUrl = imageUrl;
    var slugMatch = imageUrl.match(/\/iotd\/(.+)\/[^\/]+$/);
    if (slugMatch) {
        var thumbRe = new RegExp(
            "https://assets\\.science\\.nasa\\.gov/dynamicimage/assets/science/esd/eo/images/iotd/"
            + escapeRegExp(slugMatch[1])
            + "/[^\"'\\s?]+\\.(?:jpg|jpeg|png)", "i");
        var thumbMatch = contentHtml.match(thumbRe);
        if (thumbMatch) {
            thumbnailUrl = thumbMatch[0];
        }
    }

    // Extract title
    var title = "";
    var titleMatch = item.match(/<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/);
    if (titleMatch) {
        title = decodeEntities(titleMatch[1]).replace(/\s+/g, " ").trim();
    }

    // Extract link
    var link = "";
    var linkMatch = item.match(/<link>([^<]+)<\/link>/);
    if (linkMatch) {
        link = linkMatch[1].trim();
    }

    // Extract short description from <description>
    var description = "";
    var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
    if (descMatch) {
        var descHtml = descMatch[1];
        var cdataMatch = descHtml.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
        if (cdataMatch) {
            descHtml = cdataMatch[1];
        }
        var pMatch = descHtml.match(/<p>([\s\S]*?)<\/p>/);
        if (pMatch) {
            description = decodeEntities(stripHtml(pMatch[1])).replace(/\s+/g, " ").trim();
            if (description.length > 200) {
                description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
            }
        }
    }

    var copyright = "NASA Earth Observatory";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        copyright: copyright,
        copyrightLink: link,
        copyrightText: copyright
    };
}

function parseResponse(responseText, isPortrait) {
    // The feed mixes Earth Observatory and Photojournal items, so keep only the
    // ones categorised as "Earth Observatory", then take the most recent of
    // those that actually provides a still image.
    var allItems = responseText.match(/<item>[\s\S]*?<\/item>/g);
    if (!allItems) {
        return null;
    }

    for (var i = 0; i < allItems.length; i++) {
        if (allItems[i].indexOf("Earth Observatory") === -1) {
            continue;
        }
        var result = parseItem(allItems[i]);
        if (result) {
            return result;
        }
    }
    return null;
}

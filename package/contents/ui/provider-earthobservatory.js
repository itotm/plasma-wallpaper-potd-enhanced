// NASA Earth Observatory — Image of the Day
// Feed: https://science.nasa.gov/feed/earth-observatory/image-of-the-day
// Items contain <content:encoded> with HTML including a download link to the
// full-resolution image under assets.science.nasa.gov/content/dam/science/esd/eo/...

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
        .replace(/&#039;/g, "'")
        .replace(/&#8217;/g, "’")
        .replace(/&#8216;/g, "‘")
        .replace(/&#8220;/g, "“")
        .replace(/&#8221;/g, "”")
        .replace(/&hellip;/g, "…")
        .replace(/&nbsp;/g, " ");
}

function parseResponse(responseText, isPortrait) {
    // Extract the first <item> block (newest image of the day)
    var itemMatch = responseText.match(/<item>([\s\S]*?)<\/item>/);
    if (!itemMatch) {
        return null;
    }
    var item = itemMatch[1];

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

    // Prefer the large JPEG from the Downloads section:
    //   https://assets.science.nasa.gov/content/dam/science/esd/eo/images/iotd/.../<name>_lrg.jpg
    var imageUrl = "";
    var largeMatch = contentHtml.match(/https:\/\/assets\.science\.nasa\.gov\/content\/dam\/science\/esd\/eo\/images\/iotd\/[^"'\s]+?_lrg\.(?:jpg|jpeg|png)/i);
    if (largeMatch) {
        imageUrl = largeMatch[0];
    }

    // Thumbnail: first dynamicimage URL in the content (crop off query string for a clean URL)
    var thumbnailUrl = "";
    var thumbMatch = contentHtml.match(/https:\/\/assets\.science\.nasa\.gov\/dynamicimage\/assets\/science\/esd\/eo\/images\/iotd\/[^"'\s?]+\.(?:jpg|jpeg|png)/i);
    if (thumbMatch) {
        thumbnailUrl = thumbMatch[0];
    }

    // Fallback: derive from the large URL if thumbnail missing
    if (!thumbnailUrl && imageUrl) {
        thumbnailUrl = imageUrl;
    }
    // Fallback: if large missing but thumbnail present, try deriving an _lrg variant
    if (!imageUrl && thumbnailUrl) {
        imageUrl = thumbnailUrl.replace(/\.(jpg|jpeg|png)$/i, "_lrg.$1");
    }

    if (!imageUrl) {
        return null;
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

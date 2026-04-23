function buildUrl(market) {
    return "https://feeds.feedburner.com/esahubble/images/potw/";
}

function buildFallbackUrl(market) {
    return "https://esahubble.org/images/potw/";
}

function parseFallbackResponse(responseText, isPortrait) {
    // Extract the latest PotW image ID from the HTML listing page
    var match = responseText.match(/\/(potw\d{4}a)\//);
    if (!match) return null;

    var id = match[1];
    var imageUrl = "https://cdn.esahubble.org/archives/images/large/" + id + ".jpg";
    var thumbnailUrl = "https://cdn.esahubble.org/archives/images/screen/" + id + ".jpg";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        title: "",
        description: "",
        copyright: "ESA/Hubble",
        copyrightLink: "https://esahubble.org/images/" + id + "/",
        copyrightText: "ESA/Hubble"
    };
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function parseResponse(responseText, isPortrait) {
    // Extract the first <item> block (latest PotW)
    var itemMatch = responseText.match(/<item>([\s\S]*?)<\/item>/);
    if (!itemMatch) {
        return null;
    }
    var item = itemMatch[1];

    // Extract image URL from <enclosure> tag (screen size)
    var enclosureMatch = item.match(/<enclosure[^>]*url="([^"]+)"/);
    if (!enclosureMatch) {
        return null;
    }
    var screenUrl = enclosureMatch[1];

    // Use "large" size for wallpaper, "screen" for thumbnail
    var imageUrl = screenUrl.replace("/screen/", "/large/");
    var thumbnailUrl = screenUrl;

    // Extract title
    var title = "";
    var titleMatch = item.match(/<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/);
    if (titleMatch) {
        title = titleMatch[1].replace(/\s+/g, " ").trim();
    }

    // Extract first text paragraph from description for short description
    var description = "";
    var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
    if (descMatch) {
        var descHtml = descMatch[1];
        // Unwrap CDATA if present
        var cdataMatch = descHtml.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
        if (cdataMatch) {
            descHtml = cdataMatch[1];
        }
        // Get first <p> tag content (skip the <img> tag)
        var pMatch = descHtml.match(/<p>([\s\S]*?)<\/p>/);
        if (pMatch) {
            description = stripHtml(pMatch[1]).replace(/\s+/g, " ").trim();
            if (description.length > 200) {
                description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
            }
        }
    }

    // Extract link
    var link = "";
    var linkMatch = item.match(/<link>([^<]+)<\/link>/);
    if (linkMatch) {
        link = linkMatch[1].trim();
    }

    var copyright = "ESA/Hubble";

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

// Chandra X-ray Observatory Photo Album RSS feed.
// The feed does not include image enclosures, so we derive image URLs from
// the item link using the Chandra Photo Album slug convention:
//   link:      https://chandra.harvard.edu/photo/<year>/<slug>/
//   small jpg: https://chandra.harvard.edu/photo/<year>/<slug>/<slug>.jpg
//   large jpg: https://chandra.harvard.edu/photo/<year>/<slug>/<slug>_lg.jpg

function buildUrl(market) {
    return "https://chandra.harvard.edu/photo/xml/photo.xml";
}

function buildFallbackUrl(market) {
    return "https://chandra.si.edu/photo/xml/photo.xml";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function parseResponse(responseText, isPortrait) {
    // Extract the first <item> block (latest release)
    var itemMatch = responseText.match(/<item>([\s\S]*?)<\/item>/);
    if (!itemMatch) {
        return null;
    }
    var item = itemMatch[1];

    // Extract link
    var link = "";
    var linkMatch = item.match(/<link>([^<]+)<\/link>/);
    if (linkMatch) {
        link = linkMatch[1].trim();
    }
    if (!link) {
        var guidMatch = item.match(/<guid[^>]*>([^<]+)<\/guid>/);
        if (guidMatch) {
            link = guidMatch[1].trim();
        }
    }
    if (!link) {
        return null;
    }

    // Derive slug from link: .../photo/<year>/<slug>/
    var slugMatch = link.match(/\/photo\/\d{4}\/([^\/]+)\/?$/);
    if (!slugMatch) {
        return null;
    }
    var slug = slugMatch[1];
    var base = link.replace(/\/?$/, "/");

    var imageUrl = base + slug + "_lg.jpg";
    var thumbnailUrl = base + slug + ".jpg";

    // Extract title
    var title = "";
    var titleMatch = item.match(/<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/);
    if (titleMatch) {
        title = titleMatch[1].replace(/\s+/g, " ").trim();
    }

    // Extract description (plain text, HTML may appear raw in this feed)
    var description = "";
    var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
    if (descMatch) {
        var descText = descMatch[1];
        var cdataMatch = descText.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
        if (cdataMatch) {
            descText = cdataMatch[1];
        }
        description = stripHtml(descText).replace(/\s+/g, " ").trim();
        if (description.length > 200) {
            description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }
    }

    var copyright = "NASA/CXC";

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

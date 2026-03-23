function buildUrl(market) {
    return "https://apod.com/feed.rss";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function parseResponse(responseText, isPortrait) {
    // Extract the first <item> block (today's APOD)
    var itemMatch = responseText.match(/<item>([\s\S]*?)<\/item>/);
    if (!itemMatch) {
        return null;
    }
    var item = itemMatch[1];

    // Extract image URL from <enclosure> tag
    var enclosureMatch = item.match(/<enclosure\s[^>]*url="([^"]+)"/);
    if (!enclosureMatch) {
        return null;
    }
    var imageUrl = enclosureMatch[1];

    // Extract title from CDATA
    var title = "";
    var titleMatch = item.match(/<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>/);
    if (titleMatch) {
        title = titleMatch[1].replace(/\s+/g, " ").trim();
    }

    // Extract short description from CDATA
    var description = "";
    var descMatch = item.match(/<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>/);
    if (descMatch) {
        description = stripHtml(descMatch[1]).replace(/\s+/g, " ").trim();
        // Truncate long descriptions
        if (description.length > 200) {
            description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }
    }

    // Extract copyright from dc:creator tags, filtering out editors
    var creators = [];
    var creatorRegex = /<dc:creator>([^<]+)<\/dc:creator>/g;
    var creatorMatch;
    while ((creatorMatch = creatorRegex.exec(item)) !== null) {
        var creator = creatorMatch[1].trim();
        if (creator.indexOf("Robert Nemiroff") === -1 &&
            creator.indexOf("Jerry Bonnell") === -1) {
            creators.push(creator);
        }
    }
    var copyright = creators.join(", ");

    // Extract link for copyright URL
    var link = "";
    var linkMatch = item.match(/<link>([^<]+)<\/link>/);
    if (linkMatch) {
        link = linkMatch[1].trim();
    }

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        title: title,
        description: description,
        copyright: copyright,
        copyrightLink: link,
        copyrightText: copyright
    };
}

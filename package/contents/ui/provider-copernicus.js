function buildUrl(market) {
    return "https://www.copernicus.eu/en/rss.xml";
}

function parseResponse(responseText, isPortrait) {
    var items = responseText.match(/<item>[\s\S]*?<\/item>/g);
    if (!items) return null;

    for (var i = 0; i < items.length; i++) {
        var item = items[i];

        // Only consider image-of-the-day gallery entries
        var linkMatch = item.match(/<link>([^<]+)<\/link>/);
        if (!linkMatch || linkMatch[1].indexOf("/media/image-day-gallery/") === -1)
            continue;

        var link = linkMatch[1].trim();

        var title = "";
        var titleMatch = item.match(/<title>([^<]+)<\/title>/);
        if (titleMatch)
            title = titleMatch[1].trim();

        var descBlock = "";
        var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
        if (descMatch)
            descBlock = descMatch[1].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, '"');

        // Full-size image URL from image_of_the_day style path with itok
        var imgMatch = descBlock.match(/\/system\/files\/styles\/image_of_the_day\/private\/[^\s"<>&]+\?itok=[^\s"<>&]+/);
        if (!imgMatch)
            continue;

        var imageUrl = "https://www.copernicus.eu" + imgMatch[0];

        // Description from the ec-content div
        var description = "";
        var contentMatch = descBlock.match(/<div class="ec-content">([\s\S]*?)<\/div>/);
        if (contentMatch) {
            description = contentMatch[1].replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
            if (description.length > 200)
                description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }

        // Credit line
        var creditMatch = descBlock.match(/European Union[^<\n]+/);
        var copyright = creditMatch ? creditMatch[0].trim() : "European Union, Copernicus";

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

    return null;
}

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
        if (!linkMatch || linkMatch[1].indexOf("/media/image-day") === -1)
            continue;

        var link = linkMatch[1].trim();

        var title = "";
        var titleMatch = item.match(/<title>(?:<!\[CDATA\[)?([^<\]]+)(?:\]\]>)?<\/title>/);
        if (titleMatch)
            title = titleMatch[1].trim();

        var descBlock = "";
        var descMatch = item.match(/<description>([\s\S]*?)<\/description>/);
        if (descMatch)
            descBlock = descMatch[1].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, '"');

        // Try multiple patterns to find the image URL, ordered from most to least specific:
        var imageUrl = "";

        // 1. image_of_the_day style path with itok (inside or outside HTML)
        var imgMatch = descBlock.match(/\/system\/files\/styles\/image_of_the_day\/private\/[^\s"<>&]+\?itok=[^\s"<>&]+/);
        if (imgMatch) {
            imageUrl = "https://www.copernicus.eu" + imgMatch[0];
        }

        // 2. Any /system/files/ path with image extension
        if (!imageUrl) {
            imgMatch = descBlock.match(/\/system\/files\/[^\s"<>&]+\.(?:png|jpg|jpeg)[^\s"<>&]*/);
            if (imgMatch)
                imageUrl = "https://www.copernicus.eu" + imgMatch[0];
        }

        // 3. Full URL to copernicus.eu image
        if (!imageUrl) {
            imgMatch = descBlock.match(/https:\/\/www\.copernicus\.eu\/[^\s"<>]+\.(?:png|jpg|jpeg)[^\s"<>]*/);
            if (imgMatch)
                imageUrl = imgMatch[0];
        }

        // 4. Any <img src="..."> in the description
        if (!imageUrl) {
            imgMatch = descBlock.match(/<img[^>]+src="([^"]+)"/);
            if (imgMatch)
                imageUrl = imgMatch[1];
        }

        if (!imageUrl)
            continue;

        // Description from the ec-content div
        var description = "";
        var contentMatch = descBlock.match(/<div class="ec-content">([\s\S]*?)<\/div>/);
        if (contentMatch) {
            description = contentMatch[1].replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
            if (description.length > 200)
                description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }

        // Credit line: try specific pattern first, then fallback
        var copyright = "European Union, Copernicus";
        var creditMatch = descBlock.match(/European Union[^<\n]{0,100}/);
        if (creditMatch)
            copyright = creditMatch[0].trim();

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

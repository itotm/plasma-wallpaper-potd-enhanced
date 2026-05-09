function buildUrl(market) {
    return "https://eu-space.europa.eu/explore-euspace/images";
}

function parseResponse(responseText, isPortrait) {
    // Find the first image card on the eu-space.europa.eu listing page
    var imgMatch = responseText.match(/<img\s+src="(https:\/\/eu-space\.europa\.eu\/sites\/default\/files\/styles\/search_style\/public\/[^"]+)"/);
    if (!imgMatch) return null;

    var thumbnailUrl = imgMatch[1].replace(/&amp;/g, "&");

    // Derive full-resolution URL by removing the style path and itok param
    var imageUrl = thumbnailUrl
        .replace(/\/styles\/search_style\/public/, "")
        .replace(/\?itok=[^&]+/, "")
        .replace(/&itok=[^&]+/, "");

    // Extract title from card__title
    var title = "";
    var titleMatch = responseText.match(/<div class="card__title">\s*<a[^>]*>\s*([\s\S]*?)\s*<\/a>/);
    if (titleMatch)
        title = titleMatch[1].replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();

    // Extract description from card__text
    var description = "";
    var descMatch = responseText.match(/<div class="card__text">([\s\S]*?)<\/div>/);
    if (descMatch) {
        description = descMatch[1].replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
        if (description.length > 200)
            description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
    }

    // Extract detail page link
    var link = "https://eu-space.europa.eu/explore-euspace/images";
    var linkMatch = responseText.match(/<a\s+href="(\/node\/\d+)"\s*>/);
    if (linkMatch)
        link = "https://eu-space.europa.eu" + linkMatch[1];

    var copyright = "Explore EU Space";

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

function buildUrl(market) {
    return "https://eu-space.europa.eu/explore-euspace/images/recent";
}

function parseResponse(responseText, isPortrait) {
    // Find the first card
    var articleMatch = responseText.match(/<article class="card">[\s\S]*?<\/article>/);
    if (!articleMatch) return null;

    var article = articleMatch[0];

    // --- Image ---
    var imgMatch = article.match(/<img[^>]+src="([^"]+)"/);
    if (!imgMatch) return null;

    var imageUrl = imgMatch[1];

    // Convert from styled URL → original file
    imageUrl = imageUrl.replace(/\/styles\/[^\/]+\/public\//, "/");

    // Optional: remove ?itok
    imageUrl = imageUrl.split("?")[0];

    // --- Title ---
    var title = "";
    var titleMatch = article.match(/<div class="card__title">[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/);
    if (titleMatch) {
        title = titleMatch[1].replace(/\s+/g, " ").trim();
    }

    // --- Description ---
    var description = "";
    var descMatch = article.match(/<div class="card__text">([\s\S]*?)<\/div>/);
    if (descMatch) {
        description = descMatch[1]
            .replace(/\s+/g, " ")
            .trim();

        if (description.length > 200) {
            description =
                description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }
    }

    // --- Link ---
    var link = "";
    var linkMatch = article.match(/<a href="([^"]+)"/);
    if (linkMatch) {
        link = "https://eu-space.europa.eu" + linkMatch[1];
    }

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        title: title,
        description: description,
        copyright: "European Union",
        copyrightLink: link,
        copyrightText: "European Union"
    };
}

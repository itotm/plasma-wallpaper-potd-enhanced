function buildUrl(market) {
    return "https://bpod.org.uk/feed";
}


function parseResponse(responseText, isPortrait) {
    var items = responseText.match(/<entry>[\s\S]*?<\/entry>/g);
    if (!items || items.length === 0) return null;

    var item = items[0]; // latest entry

    // --- Title ---
    var title = "";
    var titleMatch = item.match(/<title[^>]*>([\s\S]*?)<\/title>/);
    if (titleMatch) {
        title = titleMatch[1].replace(/\s+/g, " ").trim();
    }

    // --- Link ---
    var link = "";
    var linkMatch = item.match(/<link[^>]+href="([^"]+)"/);
    if (linkMatch) {
        link = linkMatch[1];
    }

    // --- CONTENT (this is the important part) ---
    var contentMatch = item.match(/<content[^>]*>([\s\S]*?)<\/content>/);
    if (!contentMatch) return null;

    var content = contentMatch[1];

    // Decode HTML entities (CRITICAL)
    content = content
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"');

    // --- Image (FIRST img only, avoid thumbnail) ---
    var imageUrl = "";
    var imgMatch = content.match(/<img[^>]+src="([^"]+)"/);
    if (imgMatch) {
        imageUrl = imgMatch[1];
    }

    if (!imageUrl) return null;

    // --- Description (first <p>) ---
    var description = "";
    var pMatch = content.match(/<p>([\s\S]*?)<\/p>/);
    if (pMatch) {
        description = pMatch[1]
            .replace(/<[^>]*>/g, "") // strip links etc
            .replace(/\s+/g, " ")
            .trim();

        if (description.length > 200) {
            description =
                description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }
    }

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        title: title,
        description: description,
        copyright: "BPoD",
        copyrightLink: link,
        copyrightText: "BPoD"
    };
}

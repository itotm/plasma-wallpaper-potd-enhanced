function buildUrl(market) {
    var today = new Date();
    var weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    function formatDate(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }

    return "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&start_date=" + formatDate(weekAgo) + "&end_date=" + formatDate(today);
}

function parseResponse(responseText, isPortrait) {
    var entries = JSON.parse(responseText);

    // Walk backwards (newest first) to find the most recent image
    for (var i = entries.length - 1; i >= 0; i--) {
        var data = entries[i];
        if (data.media_type !== "image") {
            continue;
        }

        var imageUrl = data.hdurl || data.url;
        var thumbnailUrl = data.url || imageUrl;

        var description = data.explanation || "";
        if (description.length > 200) {
            description = description.substring(0, 200).replace(/\s+\S*$/, "") + "…";
        }

        var copyright = (data.copyright || "").replace(/\n/g, ", ").trim();

        return {
            imageUrl: imageUrl,
            thumbnailUrl: thumbnailUrl,
            title: data.title || "",
            description: description,
            copyright: copyright,
            copyrightLink: "https://apod.nasa.gov/apod/",
            copyrightText: copyright
        };
    }

    return null;
}

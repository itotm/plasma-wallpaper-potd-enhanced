
function buildUrl() {
    return "https://epic.gsfc.nasa.gov/api/natural";
}

function parseResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);

    if (!data || data.length === 0) {
        return null;
    }

    // Pick most recent image (last entry is usually latest)
    var image = data[data.length - 1];

    if (!image.image || !image.date) {
        return null;
    }

    // Extract date parts (YYYY/MM/DD)
    var dateParts = image.date.split(" ")[0].split("-");
    var year = dateParts[0];
    var month = dateParts[1];
    var day = dateParts[2];

    // Construct archive URL
    var imageUrl = "https://epic.gsfc.nasa.gov/archive/natural/"
        + year + "/" + month + "/" + day
        + "/jpg/" + image.image + ".jpg";

    // Build caption with timestamp
    var caption = image.caption || "Earth image from DSCOVR";

    // Append date + time
    var fullDescription = caption + " (" + image.date + " UTC)";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl, // no thumbnails available
        title: "DSCOVR Earth",
        description: fullDescription,
        copyright: "NASA EPIC / DSCOVR",
        copyrightLink: "https://epic.gsfc.nasa.gov/",
        copyrightText: "NASA EPIC"
    };
}

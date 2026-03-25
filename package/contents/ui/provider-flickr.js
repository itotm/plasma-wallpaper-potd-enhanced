// Flickr Interestingness - scrapes the Flickr Explore page
// No API key needed

function buildUrl(market) {
    return "https://www.flickr.com/explore";
}

// Deterministic pick based on current date (same photo all day)
function _seededIndex(max) {
    var epoch = new Date(2022, 1, 3); // Feb 3 2022 (Plasma 5.24.0 release)
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var seed = Math.floor((today - epoch) / 86400000);
    seed = ((seed * 1103515245 + 12345) & 0x7fffffff);
    return seed % max;
}

function parseResponse(responseText, isPortrait) {
    // Match photo entries: thumbnail URL, photo page URL, title, author
    var photos = [];
    var re = /\!\[Image\]\((https:\/\/live\.staticflickr\.com\/[^\)]+)\)[\s\S]*?\[([^\]]*)\]\((https:\/\/www\.flickr\.com\/photos\/[^\/]+\/[^\/]+\/[^\)]*)\)(?:\[by ([^\]]*)\])?/g;
    var match;

    while ((match = re.exec(responseText)) !== null) {
        var thumbUrl = match[1];
        var title = match[2];
        var photoPage = match[3];
        var author = match[4] || "";

        // Skip non-photo entries
        if (thumbUrl.indexOf("staticflickr.com") === -1) continue;

        // Upgrade thumbnail to large size: replace _w, _n, _z, _c, _m suffixes with _b (1024px)
        var imageUrl = thumbUrl.replace(/_[wnzcm]\.jpg$/, "_b.jpg");

        photos.push({
            imageUrl: imageUrl,
            title: title,
            photoPage: photoPage,
            author: author
        });
    }

    if (photos.length === 0) return null;

    var idx = _seededIndex(photos.length);
    var photo = photos[idx];

    var copyright = photo.author ? photo.author : "Flickr";

    return {
        imageUrl: photo.imageUrl,
        thumbnailUrl: photo.imageUrl,
        title: photo.title,
        description: "",
        copyright: copyright,
        copyrightLink: photo.photoPage,
        copyrightText: copyright
    };
}

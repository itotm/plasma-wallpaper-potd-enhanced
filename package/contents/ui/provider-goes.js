// NOAA GOES GeoColor full-disk imagery (NOAA STAR / CIRA), a new frame every
// 10 minutes. The CDN also has fixed "latest" file names, but a fixed URL would
// never look like a new image to the refresh logic (nor to the pixmap cache):
// the STAR full-disk page links the timestamped file of the latest frame,
//   https://cdn.star.nesdis.noaa.gov/GOES19/ABI/FD/GEOCOLOR/<YYYYDDDHHMM>_GOES19-ABI-FD-GEOCOLOR-1808x1808.jpg
// whose name is unique per frame. The fallback is the CDN directory listing,
// which contains the same names (the most recent one is picked).
//
// 1808x1808 is used for the wallpaper: the next size up (5424x5424) is ~17 MB.

var SATELLITES = {
    east: { cdn: "GOES19", page: "G19", name: "GOES-East" },
    west: { cdn: "GOES18", page: "G18", name: "GOES-West" }
};
var IMAGE_SIZE = "1808x1808";
var THUMB_SIZE = "678x678";

function cdnDir(sat) {
    return "https://cdn.star.nesdis.noaa.gov/" + sat.cdn + "/ABI/FD/GEOCOLOR/";
}

function pageUrl(sat) {
    return "https://www.star.nesdis.noaa.gov/GOES/fulldisk.php?sat=" + sat.page;
}

function buildUrl(position) {
    return pageUrl(SATELLITES[position]);
}

function buildFallbackUrl(position) {
    return cdnDir(SATELLITES[position]);
}

// YYYYDDDHHMM (day of year) -> "YYYY-MM-DD HH:MM UTC"
function formatTimestamp(ts) {
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    var d = new Date(Date.UTC(parseInt(ts.substring(0, 4), 10), 0, parseInt(ts.substring(4, 7), 10)));
    return d.getUTCFullYear() + "-" + pad(d.getUTCMonth() + 1) + "-" + pad(d.getUTCDate())
        + " " + ts.substring(7, 9) + ":" + ts.substring(9, 11) + " UTC";
}

// Works for both the STAR page and the CDN directory listing.
function parseResponse(responseText, isPortrait, position) {
    var sat = SATELLITES[position];
    var re = new RegExp("(\\d{11})_" + sat.cdn + "-ABI-FD-GEOCOLOR-" + IMAGE_SIZE + "\\.jpg", "g");
    var latest = "";
    var match;
    while ((match = re.exec(responseText)) !== null) {
        if (match[1] > latest) {
            latest = match[1];
        }
    }
    if (!latest) {
        return null;
    }

    var prefix = cdnDir(sat) + latest + "_" + sat.cdn + "-ABI-FD-GEOCOLOR-";
    var copyright = "NOAA/NESDIS/STAR, CIRA";

    return {
        imageUrl: prefix + IMAGE_SIZE + ".jpg",
        thumbnailUrl: prefix + THUMB_SIZE + ".jpg",
        title: sat.name + " Earth",
        description: "Full disk GeoColor (" + formatTimestamp(latest) + ")",
        copyright: copyright,
        copyrightLink: pageUrl(sat),
        copyrightText: copyright
    };
}

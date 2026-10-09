.import "djangoplicity.js" as Djangoplicity

// ESA/Webb Picture of the Month.
//
// The dedicated PotM feeds have no description (just "potm2609 - <title>"),
// so the primary source is the feed with all the images of the site, where
// the PotM appears with its full text; it is picked by its potmNNNNx id. If
// it has already scrolled out of that feed, the FeedBurner PotM feed provides
// the image without a description.

var COPYRIGHT = "ESA/Webb";
var POTM_LINK = /\/images\/potm\d{4}[a-z]\//;

function buildUrl(market) {
    return "https://esawebb.org/images/feed/";
}

function buildFallbackUrl(market) {
    return "https://feeds.feedburner.com/esawebb/potm/";
}

function parseResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT, POTM_LINK);
}

function parseFallbackResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT, POTM_LINK);
}

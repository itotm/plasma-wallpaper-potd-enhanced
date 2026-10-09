.import "djangoplicity.js" as Djangoplicity

// ESA/Hubble Picture of the Month. Hubble moved from a weekly picture to a
// monthly one in 2026 (the last PotW is potw2552a, December 2025).
//
// The dedicated PotM feeds have no description (just "potm2609 - <title>"),
// so the primary source is the feed with all the images of the site, where
// the PotM appears with its full text; it is picked by its potmNNNNx id. If
// it has already scrolled out of that feed, the FeedBurner PotM feed (whose
// URL still says "potw") provides the image without a description.
// esahubble.org/images/potm/feed/ must not be used: it still serves the old
// PotW items.

var COPYRIGHT = "ESA/Hubble";
var POTM_LINK = /\/images\/potm\d{4}[a-z]\//;

function buildUrl(market) {
    return "https://esahubble.org/images/feed/";
}

function buildFallbackUrl(market) {
    return "https://feeds.feedburner.com/esahubble/images/potw/";
}

function parseResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT, POTM_LINK);
}

function parseFallbackResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT, POTM_LINK);
}

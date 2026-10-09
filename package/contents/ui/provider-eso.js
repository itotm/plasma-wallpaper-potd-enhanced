.import "djangoplicity.js" as Djangoplicity

// ESO Picture of the Week.

var COPYRIGHT = "ESO";

function buildUrl(market) {
    return "https://www.eso.org/public/images/potw/feed/";
}

function buildFallbackUrl(market) {
    return "https://www.eso.org/public/images/potw/";
}

function parseResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT);
}

function parseFallbackResponse(responseText, isPortrait) {
    return Djangoplicity.parseListing(responseText, /\/(potw\d{4}[a-z])\//,
        "https://cdn.eso.org/images/", "https://www.eso.org/public/images/", COPYRIGHT);
}

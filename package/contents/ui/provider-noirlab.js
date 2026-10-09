.import "djangoplicity.js" as Djangoplicity

// NSF NOIRLab Image of the Week.

var COPYRIGHT = "NOIRLab/NSF/AURA";

function buildUrl(market) {
    return "https://noirlab.edu/public/images/iotw/feed/";
}

function buildFallbackUrl(market) {
    return "https://noirlab.edu/public/images/iotw/";
}

function parseResponse(responseText, isPortrait) {
    return Djangoplicity.parseFeed(responseText, COPYRIGHT);
}

function parseFallbackResponse(responseText, isPortrait) {
    return Djangoplicity.parseListing(responseText, /\/(iotw\d{4}[a-z])\//,
        "https://storage.noirlab.edu/media/archives/images/", "https://noirlab.edu/public/images/", COPYRIGHT);
}

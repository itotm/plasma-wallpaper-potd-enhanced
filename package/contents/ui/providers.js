.import "provider-bing.js" as BingProvider
.import "provider-spotlight.js" as SpotlightProvider
.import "provider-wikimedia.js" as WikimediaProvider

// To add a new provider:
//   1. Create provider-<name>.js with buildUrl(market) and parseResponse(text, isPortrait)
//   2. Import it at the top of this file
//   3. Add a case to buildUrl() and parseResponse()

function buildUrl(provider, market) {
    switch (provider) {
        case "spotlight":
            return SpotlightProvider.buildUrl(market);
        case "wikimedia":
            return WikimediaProvider.buildUrl(market);
        default:
            return BingProvider.buildUrl(market);
    }
}

function parseResponse(provider, responseText, isPortrait) {
    switch (provider) {
        case "spotlight":
            return SpotlightProvider.parseResponse(responseText, isPortrait);
        case "wikimedia":
            return WikimediaProvider.parseResponse(responseText, isPortrait);
        default:
            return BingProvider.parseResponse(responseText, isPortrait);
    }
}

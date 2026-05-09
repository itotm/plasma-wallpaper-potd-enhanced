.import "provider-bing.js" as BingProvider
.import "provider-bpod.js" as BpodProvider
.import "provider-chandra.js" as ChandraProvider
.import "provider-euspace.js" as EuSpaceProvider
.import "provider-earthobservatory.js" as EarthObservatoryProvider
.import "provider-eso.js" as EsoProvider
.import "provider-hubble.js" as HubbleProvider
.import "provider-nasa.js" as NasaProvider
.import "provider-spotlight.js" as SpotlightProvider
.import "provider-webb.js" as WebbProvider
.import "provider-wikimedia.js" as WikimediaProvider

// To add a new provider:
//   1. Create provider-<name>.js with buildUrl(market) and parseResponse(text, isPortrait)
//   2. Import it at the top of this file
//   3. Add a case to buildUrl() and parseResponse()

function buildUrl(provider, market) {
    switch (provider) {
        case "bpod":
            return BpodProvider.buildUrl(market);
        case "chandra":
            return ChandraProvider.buildUrl(market);
        case "euspace":
            return EuSpaceProvider.buildUrl(market);
        case "earthobservatory":
            return EarthObservatoryProvider.buildUrl(market);
        case "eso":
            return EsoProvider.buildUrl(market);
        case "hubble":
            return HubbleProvider.buildUrl(market);
        case "nasa":
            return NasaProvider.buildUrl(market);
        case "spotlight":
            return SpotlightProvider.buildUrl(market);
        case "webb":
            return WebbProvider.buildUrl(market);
        case "wikimedia":
            return WikimediaProvider.buildUrl(market);
        default:
            return BingProvider.buildUrl(market);
    }
}

function parseResponse(provider, responseText, isPortrait) {
    switch (provider) {
        case "bpod":
            return BpodProvider.parseResponse(responseText, isPortrait);
        case "chandra":
            return ChandraProvider.parseResponse(responseText, isPortrait);
        case "euspace":
            return EuSpaceProvider.parseResponse(responseText, isPortrait);
        case "earthobservatory":
            return EarthObservatoryProvider.parseResponse(responseText, isPortrait);
        case "eso":
            return EsoProvider.parseResponse(responseText, isPortrait);
        case "hubble":
            return HubbleProvider.parseResponse(responseText, isPortrait);
        case "nasa":
            return NasaProvider.parseResponse(responseText, isPortrait);
        case "spotlight":
            return SpotlightProvider.parseResponse(responseText, isPortrait);
        case "webb":
            return WebbProvider.parseResponse(responseText, isPortrait);
        case "wikimedia":
            return WikimediaProvider.parseResponse(responseText, isPortrait);
        default:
            return BingProvider.parseResponse(responseText, isPortrait);
    }
}

function buildFallbackUrl(provider, market) {
    switch (provider) {
        case "chandra":
            return ChandraProvider.buildFallbackUrl(market);
        case "eso":
            return EsoProvider.buildFallbackUrl(market);
        case "hubble":
            return HubbleProvider.buildFallbackUrl(market);
        case "webb":
            return WebbProvider.buildFallbackUrl(market);
        default:
            return null;
    }
}

function parseFallbackResponse(provider, responseText, isPortrait) {
    switch (provider) {
        case "eso":
            return EsoProvider.parseFallbackResponse(responseText, isPortrait);
        case "hubble":
            return HubbleProvider.parseFallbackResponse(responseText, isPortrait);
        default:
            // For providers without a custom fallback parser (e.g. Webb),
            // the fallback feed has the same format as the primary.
            return parseResponse(provider, responseText, isPortrait);
    }
}

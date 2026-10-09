.import "provider-bing.js" as BingProvider
.import "provider-chandra.js" as ChandraProvider
.import "provider-dscovr.js" as DscovrProvider
.import "provider-euspace.js" as EuSpaceProvider
.import "provider-earthobservatory.js" as EarthObservatoryProvider
.import "provider-eso.js" as EsoProvider
.import "provider-goes.js" as GoesProvider
.import "provider-hubble.js" as HubbleProvider
.import "provider-nasa.js" as NasaProvider
.import "provider-nasaiotd.js" as NasaIotdProvider
.import "provider-noirlab.js" as NoirlabProvider
.import "provider-sdo.js" as SdoProvider
.import "provider-spotlight.js" as SpotlightProvider
.import "provider-webb.js" as WebbProvider
.import "provider-wikimedia.js" as WikimediaProvider
.import "text.js" as TextUtils

// To add a new provider:
//   1. Create provider-<name>.js with buildUrl(market) and parseResponse(text, isPortrait)
//      (djangoplicity sites — ESO, ESA/Hubble, ESA/Webb, NOIRLab — can reuse djangoplicity.js)
//   2. Import it at the top of this file
//   3. Add a case to buildUrl() and parseResponse()
//   4. Add it to the provider list in config.qml (and, if relevant, to
//      FULL_DISK_PROVIDERS / HOURLY_PROVIDERS below)

// Providers whose picture is a disk on a black background (Earth, Sun): shown
// whole (PreserveAspectFit) instead of cropped to fill the screen.
var FULL_DISK_PROVIDERS = ["dscovr", "goeseast", "goeswest", "sdo"];

// Providers whose picture changes during the day, so the optional hourly
// auto-refresh is offered.
var HOURLY_PROVIDERS = ["spotlight", "dscovr", "goeseast", "goeswest", "sdo"];

function isFullDisk(provider) {
    return FULL_DISK_PROVIDERS.indexOf(provider) !== -1;
}

function supportsHourlyRefresh(provider) {
    return HOURLY_PROVIDERS.indexOf(provider) !== -1;
}

function buildUrl(provider, market) {
    switch (provider) {
        case "chandra":
            return ChandraProvider.buildUrl(market);
        case "dscovr":
            return DscovrProvider.buildUrl(market);
        case "euspace":
            return EuSpaceProvider.buildUrl(market);
        case "earthobservatory":
            return EarthObservatoryProvider.buildUrl(market);
        case "eso":
            return EsoProvider.buildUrl(market);
        case "goeseast":
            return GoesProvider.buildUrl("east");
        case "goeswest":
            return GoesProvider.buildUrl("west");
        case "hubble":
            return HubbleProvider.buildUrl(market);
        case "nasa":
            return NasaProvider.buildUrl(market);
        case "nasaiotd":
            return NasaIotdProvider.buildUrl(market);
        case "noirlab":
            return NoirlabProvider.buildUrl(market);
        case "sdo":
            return SdoProvider.buildUrl(market);
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

function _parseResponse(provider, responseText, isPortrait) {
    switch (provider) {
        case "chandra":
            return ChandraProvider.parseResponse(responseText, isPortrait);
        case "dscovr":
            return DscovrProvider.parseResponse(responseText, isPortrait);
        case "euspace":
            return EuSpaceProvider.parseResponse(responseText, isPortrait);
        case "earthobservatory":
            return EarthObservatoryProvider.parseResponse(responseText, isPortrait);
        case "eso":
            return EsoProvider.parseResponse(responseText, isPortrait);
        case "goeseast":
            return GoesProvider.parseResponse(responseText, isPortrait, "east");
        case "goeswest":
            return GoesProvider.parseResponse(responseText, isPortrait, "west");
        case "hubble":
            return HubbleProvider.parseResponse(responseText, isPortrait);
        case "nasa":
            return NasaProvider.parseResponse(responseText, isPortrait);
        case "nasaiotd":
            return NasaIotdProvider.parseResponse(responseText, isPortrait);
        case "noirlab":
            return NoirlabProvider.parseResponse(responseText, isPortrait);
        case "sdo":
            return SdoProvider.parseResponse(responseText, isPortrait);
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
        case "goeseast":
            return GoesProvider.buildFallbackUrl("east");
        case "goeswest":
            return GoesProvider.buildFallbackUrl("west");
        case "hubble":
            return HubbleProvider.buildFallbackUrl(market);
        case "noirlab":
            return NoirlabProvider.buildFallbackUrl(market);
        case "webb":
            return WebbProvider.buildFallbackUrl(market);
        default:
            return null;
    }
}

function _parseFallbackResponse(provider, responseText, isPortrait) {
    switch (provider) {
        case "eso":
            return EsoProvider.parseFallbackResponse(responseText, isPortrait);
        case "hubble":
            return HubbleProvider.parseFallbackResponse(responseText, isPortrait);
        case "noirlab":
            return NoirlabProvider.parseFallbackResponse(responseText, isPortrait);
        case "webb":
            return WebbProvider.parseFallbackResponse(responseText, isPortrait);
        default:
            // For providers without a custom fallback parser,
            // the fallback feed has the same format as the primary.
            return _parseResponse(provider, responseText, isPortrait);
    }
}

// Providers return the description as published (often a whole paragraph):
// keep its first sentence, short enough for the overlay to fit on one line.
function _finalize(result) {
    if (result) {
        result.description = TextUtils.shortDescription(result.description, result.title);
    }
    return result;
}

function parseResponse(provider, responseText, isPortrait) {
    return _finalize(_parseResponse(provider, responseText, isPortrait));
}

function parseFallbackResponse(provider, responseText, isPortrait) {
    return _finalize(_parseFallbackResponse(provider, responseText, isPortrait));
}

function isHttpUrl(url) {
    if (!url) {
        return false;
    }
    return url.toString().startsWith("http");
}

function detectMarket() {
    var locale = Qt.locale().name;
    var converted = locale.replace("_", "-");
    var markets = [
        "de-DE", "en-AU", "en-CA", "en-GB", "en-IN", "en-NZ", "en-US",
        "es-ES", "fr-CA", "fr-FR", "it-IT", "ja-JP", "pt-BR", "zh-CN"
    ];
    for (var i = 0; i < markets.length; i++) {
        if (markets[i] === converted) {
            return converted;
        }
    }
    var lang = converted.split("-")[0];
    for (var i = 0; i < markets.length; i++) {
        if (markets[i].indexOf(lang + "-") === 0) {
            return markets[i];
        }
    }
    return "en-US";
}

function parseCopyright(str) {
    if (!str) {
        return { description: "", copyright: "" };
    }
    var match = str.match(/^(.*?)\s*\(©\s*(.*)\)\s*$/);
    if (match) {
        return { description: match[1].trim(), copyright: match[2].trim() };
    }
    match = str.match(/^(.*?)\s*\((.*)\)\s*$/);
    if (match) {
        return { description: match[1].trim(), copyright: match[2].trim() };
    }
    return { description: str, copyright: "" };
}

function buildUrl(market) {
    var country = market.split("-")[1] || "US";
    return "https://fd.api.iris.microsoft.com/v4/api/selection?&placement=88000820&bcnt=1&country="
        + encodeURIComponent(country) + "&locale=" + encodeURIComponent(market) + "&fmt=json";
}

function parseResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data.batchrsp || !data.batchrsp.items || data.batchrsp.items.length === 0) {
        return null;
    }

    var itemWrapper = data.batchrsp.items[0];
    if (!itemWrapper.item) {
        return null;
    }

    var item = JSON.parse(itemWrapper.item);
    if (!item.ad) {
        return null;
    }

    var ad = item.ad;

    var urlField = isPortrait ? "portraitImage" : "landscapeImage";
    var imageUrl = "";
    if (ad[urlField] && ad[urlField].asset) {
        imageUrl = ad[urlField].asset;
    }
    if (!imageUrl) {
        return null;
    }

    var title = "";
    if (ad.iconHoverText) {
        title = ad.iconHoverText.split(/[\r\n]/)[0];
    }
    if (!title && ad.title) {
        title = ad.title;
    }

    var copyright = ad.copyright || "";

    return {
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        title: title,
        description: "",
        copyright: copyright,
        copyrightLink: imageUrl,
        copyrightText: copyright
    };
}

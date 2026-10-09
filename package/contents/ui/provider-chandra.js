// Chandra X-ray Observatory Photo Album.
// The Photo Album RSS feed (photo/xml/photo.xml) stopped being updated in
// February 2026, so the "Images by Date" page of the current year is used
// instead (chronological.html always shows the current year, newest first).
// Each image is a block like:
//   <div class="page_box2">
//     <a href="/photo/<year>/<slug>/"><img src="/photo/<year>/<slug>/<name>_115.jpg" ...></a>
//     <div class="page_gray">08&nbsp;Oct&nbsp;26</div>
//     <div><a href="/photo/<year>/<slug>/">Title</a></div>
//     <div class="page_gray">Short description.</div></div>
// Image URLs follow the Photo Album slug convention:
//   small jpg: https://chandra.harvard.edu/photo/<year>/<slug>/<slug>.jpg
//   large jpg: https://chandra.harvard.edu/photo/<year>/<slug>/<slug>_lg.jpg
// The small one (864 px wide, ~0.5 MB) is used as the wallpaper: the large one
// is the full-resolution original and can reach 9000x9000 px and 64 MB.
// The fallback is the same page on the Smithsonian mirror. Early in January,
// before the first release of the year, the page has no images: the parse
// fails and the previous wallpaper stays on screen.

function buildUrl(market) {
    return "https://chandra.harvard.edu/photo/chronological.html";
}

function buildFallbackUrl(market) {
    return "https://chandra.si.edu/photo/chronological.html";
}

function stripHtml(html) {
    return html.replace(/<[^>]*>/g, "").trim();
}

function decodeEntities(s) {
    return s
        .replace(/&nbsp;/g, " ")
        .replace(/&quot;/g, '"')
        .replace(/&#0?39;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&");
}

function plainText(html) {
    return decodeEntities(stripHtml(html)).replace(/\s+/g, " ").trim();
}

function parseResponse(responseText, isPortrait) {
    // First image block of the page (latest release)
    var blockMatch = responseText.match(/<div class="page_box\d?">[\s\S]*?href="\/photo\/(\d{4})\/([^\/"]+)\/"[\s\S]*?(?=<div class="page_box|<!-- \*{3,}|$)/);
    if (!blockMatch) {
        return null;
    }
    var block = blockMatch[0];
    var slug = blockMatch[2];
    var link = "https://chandra.harvard.edu/photo/" + blockMatch[1] + "/" + slug + "/";

    // Title: the text link (the other link wraps the thumbnail <img>)
    var title = "";
    var titleMatch = block.match(/<div><a href="[^"]*">([\s\S]*?)<\/a><\/div>/);
    if (titleMatch) {
        title = plainText(titleMatch[1]);
    }

    // Description: the last "page_gray" div (the first one is the date)
    var description = "";
    var grays = block.match(/<div class="page_gray">([\s\S]*?)<\/div>/g);
    if (grays && grays.length > 1) {
        description = plainText(grays[grays.length - 1]);
    }

    var copyright = "NASA/CXC";

    return {
        imageUrl: link + slug + ".jpg",
        thumbnailUrl: link + slug + ".jpg",
        title: title,
        description: description,
        copyright: copyright,
        copyrightLink: link,
        copyrightText: copyright
    };
}

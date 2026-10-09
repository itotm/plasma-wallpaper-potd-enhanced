// Solar Dynamics Observatory, AIA 171 Å, through the Helioviewer API.
// The "latest" images on sdo.gsfc.nasa.gov are not reliably updated (they
// were stuck for weeks in 2026), while Helioviewer ingests SDO data in near
// real time. getClosestImage returns the id and date of the most recent
// frame; downloadImage renders it as a JPEG, and the id makes the URL unique
// per frame.

var SOURCE_ID = 10; // SDO AIA 171
var IMAGE_WIDTH = 2048;
var THUMB_WIDTH = 512;

function buildUrl(market) {
    var now = new Date().toISOString().replace(/\.\d+Z$/, "Z");
    return "https://api.helioviewer.org/v2/getClosestImage/?date=" + now + "&sourceId=" + SOURCE_ID;
}

function imageUrl(id, width) {
    return "https://api.helioviewer.org/v2/downloadImage/?id=" + id + "&width=" + width + "&type=jpg";
}

function parseResponse(responseText, isPortrait) {
    var data = JSON.parse(responseText);
    if (!data || !data.id) {
        return null;
    }

    var copyright = "NASA/SDO, AIA (Helioviewer)";

    return {
        imageUrl: imageUrl(data.id, IMAGE_WIDTH),
        thumbnailUrl: imageUrl(data.id, THUMB_WIDTH),
        title: "SDO Sun",
        description: "AIA 171 Å" + (data.date ? " (" + data.date.substring(0, 16) + " UTC)" : ""),
        copyright: copyright,
        copyrightLink: "https://helioviewer.org/",
        copyrightText: copyright
    };
}

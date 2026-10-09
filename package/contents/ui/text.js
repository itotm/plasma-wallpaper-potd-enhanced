// Caption helpers shared by the providers and the overlay.

// Longest overlay line ("title - description") that stays on a single line on
// a Full HD screen: the overlay box is 70% of 1920 px = 1344 px, and the 14 px
// DemiBold text averages ~7 px per character (~190 characters). 150 leaves
// room for wider text and still fits at 125% scaling (1075 px).
var OVERLAY_MAX_CHARS = 150;

// The first sentence of text, with its final punctuation. A period only ends
// the sentence after two lowercase letters or digits (optionally followed by
// a closing bracket or quote), so abbreviations such as "U.S.", "St." or
// "e.g." do not cut it short.
function firstSentence(text) {
    var match = text.match(/[a-z0-9ß-ÿ]{2}[)\]"'’”»]?[.!?](?=\s|$)/);
    if (!match) {
        return text;
    }
    return text.substring(0, match.index + match[0].length);
}

// text shortened to at most maxLen characters, cut at a word boundary and
// ending with an ellipsis.
function ellipsize(text, maxLen) {
    if (text.length <= maxLen) {
        return text;
    }
    if (maxLen < 2) {
        return "";
    }
    var cut = text.substring(0, maxLen - 1);
    var space = cut.lastIndexOf(" ");
    if (space > maxLen * 0.6) {
        cut = cut.substring(0, space);
    }
    return cut.replace(/[\s,;:.\-–—]+$/, "") + "…";
}

// Description as shown in the overlay: its first sentence, shortened so that
// "title - description" fits OVERLAY_MAX_CHARS.
function shortDescription(description, title) {
    var text = (description || "").replace(/\s+/g, " ").trim();
    if (text === "") {
        return "";
    }
    var budget = OVERLAY_MAX_CHARS - (title ? title.length + 3 : 0);
    return ellipsize(firstSentence(text), budget);
}

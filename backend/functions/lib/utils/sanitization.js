"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.escapeHtml = escapeHtml;
exports.sanitizeHTTPSURL = sanitizeHTTPSURL;
function escapeHtml(value) {
    return value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}
function sanitizeHTTPSURL(raw, fallback) {
    try {
        const parsed = new URL(raw);
        if (parsed.protocol !== "https:")
            return fallback;
        return parsed.toString();
    }
    catch {
        return fallback;
    }
}
//# sourceMappingURL=sanitization.js.map
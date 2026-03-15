"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const sanitization_1 = require("./sanitization");
(0, node_test_1.default)("escapeHtml escapes reserved characters", () => {
    const input = `<img src=x onerror="alert('xss')">`;
    const output = (0, sanitization_1.escapeHtml)(input);
    strict_1.default.equal(output, "&lt;img src=x onerror=&quot;alert(&#39;xss&#39;)&quot;&gt;");
});
(0, node_test_1.default)("sanitizeHTTPSURL returns fallback for non-https and invalid URLs", () => {
    const fallback = "https://arrivaluk.app";
    strict_1.default.equal((0, sanitization_1.sanitizeHTTPSURL)("http://example.com", fallback), fallback);
    strict_1.default.equal((0, sanitization_1.sanitizeHTTPSURL)("javascript:alert(1)", fallback), fallback);
    strict_1.default.equal((0, sanitization_1.sanitizeHTTPSURL)("not a url", fallback), fallback);
});
(0, node_test_1.default)("sanitizeHTTPSURL keeps valid https URL", () => {
    const fallback = "https://arrivaluk.app";
    const target = "https://example.com/path?q=1";
    strict_1.default.equal((0, sanitization_1.sanitizeHTTPSURL)(target, fallback), target);
});
//# sourceMappingURL=sanitization.test.js.map
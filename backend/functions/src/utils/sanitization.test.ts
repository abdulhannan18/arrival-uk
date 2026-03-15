import test from "node:test";
import assert from "node:assert/strict";
import { escapeHtml, sanitizeHTTPSURL } from "./sanitization";

test("escapeHtml escapes reserved characters", () => {
  const input = `<img src=x onerror="alert('xss')">`;
  const output = escapeHtml(input);

  assert.equal(
    output,
    "&lt;img src=x onerror=&quot;alert(&#39;xss&#39;)&quot;&gt;"
  );
});

test("sanitizeHTTPSURL returns fallback for non-https and invalid URLs", () => {
  const fallback = "https://arrivaluk.app";

  assert.equal(sanitizeHTTPSURL("http://example.com", fallback), fallback);
  assert.equal(sanitizeHTTPSURL("javascript:alert(1)", fallback), fallback);
  assert.equal(sanitizeHTTPSURL("not a url", fallback), fallback);
});

test("sanitizeHTTPSURL keeps valid https URL", () => {
  const fallback = "https://arrivaluk.app";
  const target = "https://example.com/path?q=1";

  assert.equal(sanitizeHTTPSURL(target, fallback), target);
});


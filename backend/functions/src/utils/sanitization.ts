export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function sanitizeHTTPSURL(raw: string, fallback: string): string {
  try {
    const parsed = new URL(raw);
    if (parsed.protocol !== "https:") return fallback;
    return parsed.toString();
  } catch {
    return fallback;
  }
}


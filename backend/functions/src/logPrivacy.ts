import * as functions from "firebase-functions";
import { createHmac } from "crypto";

const LOG_PSEUDONYMIZATION_KEY = "LOG_PSEUDONYMIZATION_KEY";

export function logPseudonymizationKey(): string | null {
  const configured = (
    process.env[LOG_PSEUDONYMIZATION_KEY] ||
    functions.config()?.logging?.pseudonymization_key
  ) as string | undefined;
  const normalized = configured?.trim() ?? "";
  return normalized.length > 0 ? normalized : null;
}

export function pseudonymizeLogIdentifier(prefix: string, value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  const key = logPseudonymizationKey();
  if (!normalized || !key) return undefined;
  const digest = createHmac("sha256", key).update(normalized).digest("hex");
  return `${prefix}:${digest.slice(0, 12)}`;
}

import * as functions from "firebase-functions";

type AppCheckContext = Pick<functions.https.CallableContext, "app" | "auth">;

type AppCheckPolicyOverride = {
  isEmulator?: boolean;
  allowUnverified?: boolean;
};

type AppCheckRuntimePolicy = {
  isEmulator: boolean;
  allowUnverified: boolean;
  nodeEnv: string;
};

function parseBooleanFlag(value: unknown): boolean {
  if (typeof value !== "string") return false;
  const normalized = value.trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on";
}

function isUnsafeBypassConfiguration(policy: AppCheckRuntimePolicy): boolean {
  const normalizedNodeEnv = policy.nodeEnv.trim().toLowerCase();
  const isProductionNodeEnv = normalizedNodeEnv === "production";
  return policy.allowUnverified && (isProductionNodeEnv || !policy.isEmulator);
}

function assertSafeBypassConfiguration(policy: AppCheckRuntimePolicy): void {
  if (!isUnsafeBypassConfiguration(policy)) return;

  functions.logger.error("unsafe_app_check_bypass_configuration", {
    nodeEnv: policy.nodeEnv || "unknown",
    isEmulator: policy.isEmulator,
  });
  throw new Error(
    "ALLOW_UNVERIFIED_APPCHECK/security.allow_unverified_app_check must never be enabled outside emulator mode"
  );
}

function resolvedPolicy(override?: AppCheckPolicyOverride): { isEmulator: boolean; allowUnverified: boolean } {
  const configAllowUnverified = parseBooleanFlag(functions.config()?.security?.allow_unverified_app_check);

  return {
    isEmulator: override?.isEmulator ?? process.env.FUNCTIONS_EMULATOR === "true",
    allowUnverified: override?.allowUnverified
      ?? (parseBooleanFlag(process.env.ALLOW_UNVERIFIED_APPCHECK) || configAllowUnverified),
  };
}

export function assertCallableAppCheck(
  context: AppCheckContext,
  callableName: string,
  override?: AppCheckPolicyOverride
): void {
  const policy = resolvedPolicy(override);
  if (!override) {
    assertSafeBypassConfiguration({
      isEmulator: policy.isEmulator,
      allowUnverified: policy.allowUnverified,
      nodeEnv: process.env.NODE_ENV ?? "",
    });
  }
  if (policy.isEmulator || policy.allowUnverified) return;

  if (!context.app) {
    functions.logger.warn("callable_missing_app_check", {
      callable: callableName,
      userId: context.auth?.uid ?? null,
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "A valid App Check token is required."
    );
  }
}

assertSafeBypassConfiguration({
  ...resolvedPolicy(),
  nodeEnv: process.env.NODE_ENV ?? "",
});

export const __private__ = {
  parseBooleanFlag,
  resolvedPolicy,
  isUnsafeBypassConfiguration,
  assertSafeBypassConfiguration,
};

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as sgMail from "@sendgrid/mail";
import { createHmac, timingSafeEqual } from "crypto";

admin.initializeApp();

const db = admin.firestore();
const CHAT_PRIMARY_REGION = "europe-west2";
const CHAT_LEGACY_REGION = "us-central1";
const chatCallable = functions.region(CHAT_PRIMARY_REGION, CHAT_LEGACY_REGION).runWith({
  memory: "256MB",
  timeoutSeconds: 60
});
const PAYMENTS_REGION = "us-central1";
const paymentCallable = functions.region(PAYMENTS_REGION).runWith({
  memory: "256MB",
  timeoutSeconds: 60
});
const ukCallable = functions.region(CHAT_PRIMARY_REGION).runWith({
  memory: "512MB",
  timeoutSeconds: 120
});
const LONDON_TIME_ZONE = "Europe/London";
const MONETIZATION_RUNTIME_CONFIG_PATH = "runtimeConfig/monetization";
const MONETIZATION_CONFIG_CACHE_TTL_MS = 60 * 1000;
const DEFAULT_FREE_ACTIVE_ITEMS_LIMIT = 3;
const DEFAULT_FREE_WEEKLY_CONTACTS_LIMIT = 10;
const DEFAULT_SUPPORTER_ACTIVE_ITEMS_LIMIT = 200;
const DEFAULT_SUPPORTER_WEEKLY_CONTACTS_LIMIT = 250;
const DEFAULT_WEEK_START_ISO_DAY = 1;

const CHAT_STATUSES = {
  open: "open",
  closedByOwner: "closed_by_owner",
  archivedUnavailable: "archived_item_unavailable",
  blocked: "blocked"
} as const;

type ContactPreference = "email" | "chat" | "both";
type ChatStatus = (typeof CHAT_STATUSES)[keyof typeof CHAT_STATUSES];

type SupportTier = "free" | "supporter_monthly";
type SupportStatus = "inactive" | "active" | "past_due" | "canceled";
type PlanType = "one_off" | "monthly";

type MonetizationRuntimeFlags = {
  monetizationEnabled: boolean;
  supportUiEnabled: boolean;
  checkoutEnabled: boolean;
  enforcePublishLimit: boolean;
  enforceContactLimit: boolean;
};

type MonetizationRuntimeThresholds = {
  free: {
    publishLimit: number;
    contactLimit: number;
  };
  supporter: {
    publishLimit: number;
    contactLimit: number;
  };
};

type MonetizationRuntimeWindow = {
  timeZone: string;
  weekStartIsoDay: number;
};

type MonetizationRuntimeConfig = {
  flags: MonetizationRuntimeFlags;
  thresholds: MonetizationRuntimeThresholds;
  window: MonetizationRuntimeWindow;
};

type ItemRecord = {
  ownerId?: unknown;
  title?: unknown;
  description?: unknown;
  status?: unknown;
  photoPath?: unknown;
  location?: {
    approxAreaText?: unknown;
  };
  photoUrl?: unknown;
  contactPreference?: unknown;
};

type ConversationRecord = {
  itemId?: unknown;
  itemTitle?: unknown;
  itemPhotoUrl?: unknown;
  itemApproxArea?: unknown;
  ownerId?: unknown;
  interestedUserId?: unknown;
  participants?: unknown;
  status?: unknown;
  ownerUnreadCount?: unknown;
  interestedUnreadCount?: unknown;
  blockedByUserId?: unknown;
};

type ChatRateRecord = {
  lastMessageAt?: unknown;
  minuteWindowStart?: unknown;
  minuteCount?: number;
};

type UsageCounterRecord = {
  currentWeekKey?: string;
  weeklyUniqueContacts?: number;
};

type MonetizationProfileRecord = {
  supportTier?: unknown;
  supportStatus?: unknown;
  supportPeriodEnd?: unknown;
  stripeCustomerId?: unknown;
  stripeSubscriptionId?: unknown;
  stripePriceId?: unknown;
  oneOffDonationCount?: unknown;
  lastOneOffDonationAt?: unknown;
  lastOneOffAmount?: unknown;
};

type UserChatAnonymizationResult = {
  redactedMessages: number;
  anonymizedConversations: number;
};

let monetizationConfigCache: { value: MonetizationRuntimeConfig; loadedAtMs: number } | null = null;

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function defaultMonetizationRuntimeConfig(): MonetizationRuntimeConfig {
  return {
    flags: {
      monetizationEnabled: false,
      supportUiEnabled: false,
      checkoutEnabled: false,
      enforcePublishLimit: false,
      enforceContactLimit: false
    },
    thresholds: {
      free: {
        publishLimit: DEFAULT_FREE_ACTIVE_ITEMS_LIMIT,
        contactLimit: DEFAULT_FREE_WEEKLY_CONTACTS_LIMIT
      },
      supporter: {
        publishLimit: DEFAULT_SUPPORTER_ACTIVE_ITEMS_LIMIT,
        contactLimit: DEFAULT_SUPPORTER_WEEKLY_CONTACTS_LIMIT
      }
    },
    window: {
      timeZone: LONDON_TIME_ZONE,
      weekStartIsoDay: DEFAULT_WEEK_START_ISO_DAY
    }
  };
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function asIntInRange(value: unknown, fallback: number, min: number, max: number): number {
  if (typeof value === "number" && Number.isInteger(value) && value >= min && value <= max) {
    return value;
  }
  return fallback;
}

function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone }).format(new Date());
    return true;
  } catch (_) {
    return false;
  }
}

function parseMonetizationRuntimeConfig(data: unknown): MonetizationRuntimeConfig {
  const defaults = defaultMonetizationRuntimeConfig();
  if (!isObject(data)) {
    return defaults;
  }

  const flagsRaw = isObject(data.flags) ? data.flags : {};
  const thresholdsRaw = isObject(data.thresholds) ? data.thresholds : {};
  const freeRaw = isObject(thresholdsRaw.free) ? thresholdsRaw.free : {};
  const supporterRaw = isObject(thresholdsRaw.supporter) ? thresholdsRaw.supporter : {};
  const windowRaw = isObject(data.window) ? data.window : {};

  const timeZoneCandidate = configValue(windowRaw.timeZone) ?? defaults.window.timeZone;
  const timeZone = isValidTimeZone(timeZoneCandidate)
    ? timeZoneCandidate
    : defaults.window.timeZone;

  return {
    flags: {
      monetizationEnabled: asBoolean(
        flagsRaw.monetizationEnabled,
        defaults.flags.monetizationEnabled
      ),
      supportUiEnabled: asBoolean(flagsRaw.supportUiEnabled, defaults.flags.supportUiEnabled),
      checkoutEnabled: asBoolean(flagsRaw.checkoutEnabled, defaults.flags.checkoutEnabled),
      enforcePublishLimit: asBoolean(
        flagsRaw.enforcePublishLimit,
        defaults.flags.enforcePublishLimit
      ),
      enforceContactLimit: asBoolean(
        flagsRaw.enforceContactLimit,
        defaults.flags.enforceContactLimit
      )
    },
    thresholds: {
      free: {
        publishLimit: asIntInRange(
          freeRaw.publishLimit,
          defaults.thresholds.free.publishLimit,
          1,
          5000
        ),
        contactLimit: asIntInRange(
          freeRaw.contactLimit,
          defaults.thresholds.free.contactLimit,
          1,
          5000
        )
      },
      supporter: {
        publishLimit: asIntInRange(
          supporterRaw.publishLimit,
          defaults.thresholds.supporter.publishLimit,
          1,
          5000
        ),
        contactLimit: asIntInRange(
          supporterRaw.contactLimit,
          defaults.thresholds.supporter.contactLimit,
          1,
          5000
        )
      }
    },
    window: {
      timeZone,
      weekStartIsoDay: asIntInRange(
        windowRaw.weekStartIsoDay,
        defaults.window.weekStartIsoDay,
        1,
        7
      )
    }
  };
}

async function getMonetizationRuntimeConfig(): Promise<MonetizationRuntimeConfig> {
  const nowMs = Date.now();
  const disableCache = process.env.RELOVED_DISABLE_CONFIG_CACHE === "true";
  if (
    !disableCache &&
    monetizationConfigCache &&
    nowMs - monetizationConfigCache.loadedAtMs < MONETIZATION_CONFIG_CACHE_TTL_MS
  ) {
    return monetizationConfigCache.value;
  }

  try {
    const snapshot = await db.doc(MONETIZATION_RUNTIME_CONFIG_PATH).get();
    const parsed = parseMonetizationRuntimeConfig(snapshot.exists ? snapshot.data() : {});
    if (!disableCache) {
      monetizationConfigCache = { value: parsed, loadedAtMs: nowMs };
    }
    return parsed;
  } catch (error) {
    const fallback = defaultMonetizationRuntimeConfig();
    functions.logger.error("monetization runtime config load failed", {
      message: error instanceof Error ? error.message : String(error)
    });
    if (!disableCache) {
      monetizationConfigCache = { value: fallback, loadedAtMs: nowMs };
    }
    return fallback;
  }
}

function effectiveMonetizationFeaturesFromConfig(
  runtimeConfig: MonetizationRuntimeConfig
): MonetizationRuntimeFlags {
  const flags = runtimeConfig.flags;
  const monetizationEnabled = flags.monetizationEnabled;
  return {
    monetizationEnabled,
    supportUiEnabled: monetizationEnabled && flags.supportUiEnabled,
    checkoutEnabled: monetizationEnabled && flags.checkoutEnabled,
    enforcePublishLimit: monetizationEnabled && flags.enforcePublishLimit,
    enforceContactLimit: monetizationEnabled && flags.enforceContactLimit
  };
}

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  return uid;
}

function requireAppCheck(context: functions.https.CallableContext): void {
  if (
    process.env.RELOVED_SKIP_APPCHECK === "true" ||
    Boolean(process.env.FIREBASE_EMULATOR_HUB) ||
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.FUNCTIONS_EMULATOR === "1"
  ) {
    return;
  }
  if (!context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "App integrity check required"
    );
  }
}

function requireNonEmptyString(
  value: unknown,
  fieldName: string,
  minLength = 1,
  maxLength = 1000
): string {
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", `${fieldName} is required`);
  }
  const trimmed = value.trim();
  if (trimmed.length < minLength || trimmed.length > maxLength) {
    throw new functions.https.HttpsError("invalid-argument", `${fieldName} length is invalid`);
  }
  return trimmed;
}

function requirePlanType(value: unknown): PlanType {
  if (value === "one_off" || value === "monthly") {
    return value;
  }
  throw new functions.https.HttpsError("invalid-argument", "planType is invalid");
}

function optionalTrimmedString(value: unknown, maxLength = 1000): string {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().slice(0, maxLength);
}

function requireModerationReason(value: unknown): string {
  const reason = requireNonEmptyString(value, "reason", 1, 40);
  const allowedReasons = ["spam", "inappropriate", "unsafe", "fraud", "other"];
  if (!allowedReasons.includes(reason)) {
    throw new functions.https.HttpsError("invalid-argument", "reason is invalid");
  }
  return reason;
}

function requireUrl(value: unknown, fieldName: string): string {
  const url = requireNonEmptyString(value, fieldName, 8, 2048);
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:" && parsed.protocol !== "reloved:") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `${fieldName} protocol is invalid`
      );
    }
    return parsed.toString();
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError("invalid-argument", `${fieldName} is invalid`);
  }
}

function normalizeContactPreference(value: unknown): ContactPreference {
  if (value === "email" || value === "chat" || value === "both") {
    return value;
  }
  return "both";
}

function emailAllowed(preference: ContactPreference): boolean {
  return preference === "email" || preference === "both";
}

function chatAllowed(preference: ContactPreference): boolean {
  return preference === "chat" || preference === "both";
}

function ensureArrayOfStrings(value: unknown, fieldName: string): string[] {
  if (!Array.isArray(value)) {
    throw new functions.https.HttpsError("failed-precondition", `${fieldName} invalid`);
  }
  const parsed = value.filter((entry): entry is string => typeof entry === "string");
  if (parsed.length !== value.length) {
    throw new functions.https.HttpsError("failed-precondition", `${fieldName} invalid`);
  }
  return parsed;
}

function normalizeParticipants(conversation: ConversationRecord): string[] {
  if (Array.isArray(conversation.participants)) {
    const parsed = conversation.participants.filter((entry): entry is string => typeof entry === "string");
    if (parsed.length > 0) {
      return Array.from(new Set(parsed));
    }
  }

  const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId.trim() : "";
  const interestedUserId =
    typeof conversation.interestedUserId === "string" ? conversation.interestedUserId.trim() : "";
  return Array.from(new Set([ownerId, interestedUserId].filter((entry) => entry.length > 0)));
}

function ensureConversationStatus(value: unknown): ChatStatus {
  if (
    value === CHAT_STATUSES.open ||
    value === CHAT_STATUSES.closedByOwner ||
    value === CHAT_STATUSES.archivedUnavailable ||
    value === CHAT_STATUSES.blocked
  ) {
    return value;
  }
  throw new functions.https.HttpsError("failed-precondition", "conversation status invalid");
}

function requireParticipant(conversation: ConversationRecord, uid: string): string[] {
  const participants = normalizeParticipants(conversation);
  if (participants.length === 0) {
    throw new functions.https.HttpsError("failed-precondition", "participants invalid");
  }
  if (!participants.includes(uid)) {
    throw new functions.https.HttpsError("permission-denied", "Not a conversation participant");
  }
  return participants;
}

function getConversationId(itemId: string, interestedUserId: string): string {
  return `${itemId}_${interestedUserId}`;
}

function getTimestampMs(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (
    value != null &&
    typeof value === "object" &&
    "toMillis" in value &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  return null;
}

function configValue(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function legacyRuntimeConfig(): Record<string, Record<string, unknown>> {
  const configAccessor = (
    functions as unknown as { config?: () => Record<string, Record<string, unknown>> }
  ).config;
  return typeof configAccessor === "function" ? configAccessor() : {};
}

function getStripeSecretKey(): string {
  const fromConfig = configValue(legacyRuntimeConfig().stripe?.secret_key);
  const fromEnv = configValue(process.env.STRIPE_SECRET_KEY);
  const key = fromConfig ?? fromEnv;
  if (!key) {
    throw new functions.https.HttpsError("failed-precondition", "Stripe secret key not configured");
  }
  return key;
}

function getStripeWebhookSecret(): string {
  const fromConfig = configValue(legacyRuntimeConfig().stripe?.webhook_secret);
  const fromEnv = configValue(process.env.STRIPE_WEBHOOK_SECRET);
  const secret = fromConfig ?? fromEnv;
  if (!secret) {
    throw new functions.https.HttpsError("failed-precondition", "Stripe webhook secret not configured");
  }
  return secret;
}

function getStripePriceOneOff(): string {
  const fromConfig = configValue(legacyRuntimeConfig().stripe?.price_one_off_gbp_300);
  const fromEnv = configValue(process.env.STRIPE_PRICE_ONE_OFF_GBP_300);
  const value = fromConfig ?? fromEnv;
  if (!value) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe one-off price not configured"
    );
  }
  return value;
}

function getStripePriceMonthly(): string {
  const fromConfig = configValue(legacyRuntimeConfig().stripe?.price_monthly_gbp_499);
  const fromEnv = configValue(process.env.STRIPE_PRICE_MONTHLY_GBP_499);
  const value = fromConfig ?? fromEnv;
  if (!value) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe monthly price not configured"
    );
  }
  return value;
}

type StripeApiResponse = Record<string, unknown>;

async function stripeApiRequest(
  path: string,
  params: Record<string, string>
): Promise<StripeApiResponse> {
  const body = new URLSearchParams(params).toString();
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${getStripeSecretKey()}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });
  const payload = (await response.json()) as StripeApiResponse;
  if (!response.ok) {
    const stripeError = payload.error as { message?: string } | undefined;
    throw new functions.https.HttpsError(
      "internal",
      stripeError?.message ?? `Stripe API error on ${path}`
    );
  }
  return payload;
}

async function stripeEnsureCustomer(
  uid: string,
  email: string | null
): Promise<string> {
  const billingRef = db.collection("billingCustomers").doc(uid);
  const billingSnap = await billingRef.get();
  const existingCustomerId = billingSnap.exists ? configValue(billingSnap.get("customerId")) : undefined;
  if (existingCustomerId) {
    return existingCustomerId;
  }

  const payload = await stripeApiRequest("customers", {
    "metadata[uid]": uid,
    ...(email ? { email } : {})
  });
  const customerId = configValue(payload.id);
  if (!customerId) {
    throw new functions.https.HttpsError("internal", "Stripe customer ID missing");
  }

  await billingRef.set(
    {
      customerId,
      email: email ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
  return customerId;
}

async function stripeCreateCheckoutSession(params: {
  customerId: string;
  planType: PlanType;
  source: string;
  successUrl: string;
  cancelUrl: string;
  uid: string;
}): Promise<{ id: string; url: string }> {
  const metadata = {
    uid: params.uid,
    planType: params.planType,
    source: params.source
  };

  const body: Record<string, string> = {
    customer: params.customerId,
    mode: params.planType === "monthly" ? "subscription" : "payment",
    success_url: params.successUrl,
    cancel_url: params.cancelUrl,
    "line_items[0][quantity]": "1",
    "line_items[0][price]":
      params.planType === "monthly" ? getStripePriceMonthly() : getStripePriceOneOff(),
    "metadata[uid]": metadata.uid,
    "metadata[planType]": metadata.planType,
    "metadata[source]": metadata.source
  };

  if (params.planType === "monthly") {
    body["subscription_data[metadata][uid]"] = metadata.uid;
    body["subscription_data[metadata][planType]"] = metadata.planType;
    body["subscription_data[metadata][source]"] = metadata.source;
  } else {
    body["payment_intent_data[metadata][uid]"] = metadata.uid;
    body["payment_intent_data[metadata][planType]"] = metadata.planType;
    body["payment_intent_data[metadata][source]"] = metadata.source;
  }

  const payload = await stripeApiRequest("checkout/sessions", body);
  const id = configValue(payload.id);
  const url = configValue(payload.url);
  if (!id || !url) {
    throw new functions.https.HttpsError("internal", "Stripe checkout payload incomplete");
  }
  return { id, url };
}

async function stripeCreateBillingPortalSession(
  customerId: string,
  returnUrl: string
): Promise<string> {
  const payload = await stripeApiRequest("billing_portal/sessions", {
    customer: customerId,
    return_url: returnUrl
  });
  const url = configValue(payload.url);
  if (!url) {
    throw new functions.https.HttpsError("internal", "Stripe billing portal URL missing");
  }
  return url;
}

async function stripeRetrieveSubscription(subscriptionId: string): Promise<StripeApiResponse> {
  const response = await fetch(`https://api.stripe.com/v1/subscriptions/${subscriptionId}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${getStripeSecretKey()}`,
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });
  const payload = (await response.json()) as StripeApiResponse;
  if (!response.ok) {
    const stripeError = payload.error as { message?: string } | undefined;
    throw new functions.https.HttpsError(
      "internal",
      stripeError?.message ?? "Stripe subscription fetch failed"
    );
  }
  return payload;
}

async function stripeCancelSubscription(subscriptionId: string): Promise<void> {
  const response = await fetch(`https://api.stripe.com/v1/subscriptions/${subscriptionId}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${getStripeSecretKey()}`,
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });
  const payload = (await response.json()) as StripeApiResponse;
  if (!response.ok) {
    const stripeError = payload.error as { message?: string } | undefined;
    throw new functions.https.HttpsError(
      "internal",
      stripeError?.message ?? "Stripe subscription cancellation failed"
    );
  }
}

function verifyStripeWebhookSignature(rawBody: Buffer, signatureHeader: string): boolean {
  const secret = getStripeWebhookSecret();
  const parts = signatureHeader
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  const timestampPart = parts.find((entry) => entry.startsWith("t="));
  const signaturePart = parts.find((entry) => entry.startsWith("v1="));
  if (!timestampPart || !signaturePart) {
    return false;
  }
  const timestamp = timestampPart.slice(2);
  const expected = createHmac("sha256", secret)
    .update(`${timestamp}.${rawBody.toString("utf8")}`, "utf8")
    .digest("hex");
  const provided = signaturePart.slice(3);
  const expectedBuffer = Buffer.from(expected, "hex");
  const providedBuffer = Buffer.from(provided, "hex");
  if (expectedBuffer.length !== providedBuffer.length) {
    return false;
  }
  return timingSafeEqual(expectedBuffer, providedBuffer);
}

function supportTierValue(value: unknown): SupportTier {
  return value === "supporter_monthly" ? "supporter_monthly" : "free";
}

function supportStatusValue(value: unknown): SupportStatus {
  if (value === "active" || value === "past_due" || value === "canceled") {
    return value;
  }
  return "inactive";
}

function nowTimestamp(): Date {
  return new Date();
}

function weekKeyForWindow(
  date: Date,
  windowConfig: MonetizationRuntimeWindow
): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: windowConfig.timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);
  const values: Record<string, string> = {};
  for (const part of parts) {
    values[part.type] = part.value;
  }
  const year = Number(values.year);
  const month = Number(values.month);
  const day = Number(values.day);
  const asUtcDate = new Date(Date.UTC(year, month - 1, day));
  const weekStartSundayBased = windowConfig.weekStartIsoDay % 7;
  const daysSinceWeekStart =
    (asUtcDate.getUTCDay() - weekStartSundayBased + 7) % 7;
  const weekStartUtc = new Date(
    asUtcDate.getTime() - daysSinceWeekStart * 24 * 60 * 60 * 1000
  );
  return weekStartUtc.toISOString().slice(0, 10);
}

function contactEventId(uid: string, weekKey: string, itemId: string): string {
  return `${uid}_${weekKey}_${itemId}`;
}

function contactLimitsForTier(
  tier: SupportTier,
  runtimeConfig: MonetizationRuntimeConfig
): { publishLimit: number; contactLimit: number } {
  if (tier === "supporter_monthly") {
    return {
      publishLimit: runtimeConfig.thresholds.supporter.publishLimit,
      contactLimit: runtimeConfig.thresholds.supporter.contactLimit
    };
  }
  return {
    publishLimit: runtimeConfig.thresholds.free.publishLimit,
    contactLimit: runtimeConfig.thresholds.free.contactLimit
  };
}

function hasMonthlyEntitlement(
  supportStatus: SupportStatus,
  supportPeriodEndMs: number | null,
  nowMs: number
): boolean {
  if (!supportPeriodEndMs || supportPeriodEndMs <= nowMs) {
    return false;
  }
  return supportStatus === "active" || supportStatus === "past_due" || supportStatus === "canceled";
}

async function activeItemsCountForUser(uid: string): Promise<number> {
  const snapshot = await db
    .collection("items")
    .where("ownerId", "==", uid)
    .where("status", "in", ["available", "reserved"])
    .get();
  return snapshot.size;
}

async function findUidByStripeCustomerId(customerId: string): Promise<string | null> {
  const snapshot = await db
    .collection("billingCustomers")
    .where("customerId", "==", customerId)
    .limit(1)
    .get();
  if (snapshot.empty) {
    return null;
  }
  return snapshot.docs[0].id;
}

type ContactUsageUpdateResult = {
  incremented: boolean;
  weeklyUniqueContacts: number;
};

async function registerUniqueWeeklyContact(
  tx: FirebaseFirestore.Transaction,
  uid: string,
  itemId: string,
  source: "email" | "chat",
  now: Date,
  windowConfig: MonetizationRuntimeWindow
): Promise<ContactUsageUpdateResult> {
  const weekKey = weekKeyForWindow(now, windowConfig);
  const eventRef = db.collection("usageContactEvents").doc(contactEventId(uid, weekKey, itemId));
  const eventSnap = await tx.get(eventRef);

  const counterRef = db.collection("usageCounters").doc(uid);
  const counterSnap = await tx.get(counterRef);
  const counterData = (counterSnap.data() || {}) as UsageCounterRecord;
  const sameWeek = counterData.currentWeekKey === weekKey;
  let weeklyUniqueContacts = sameWeek
    ? typeof counterData.weeklyUniqueContacts === "number"
      ? counterData.weeklyUniqueContacts
      : 0
    : 0;

  if (!eventSnap.exists) {
    weeklyUniqueContacts += 1;
    tx.set(eventRef, {
      uid,
      itemId,
      weekKey,
      source,
      createdAt: now
    });
    tx.set(
      counterRef,
      {
        currentWeekKey: weekKey,
        weeklyUniqueContacts,
        updatedAt: now
      },
      { merge: true }
    );
    return { incremented: true, weeklyUniqueContacts };
  }

  if (!sameWeek) {
    tx.set(
      counterRef,
      {
        currentWeekKey: weekKey,
        weeklyUniqueContacts,
        updatedAt: now
      },
      { merge: true }
    );
  }

  return { incremented: false, weeklyUniqueContacts };
}

async function registerChatContactUsage(params: {
  interestedUserId: string;
  itemId: string;
  conversationId: string;
}): Promise<void> {
  const now = nowTimestamp();
  const runtimeConfig = await getMonetizationRuntimeConfig();
  await db.runTransaction(async (tx) => {
    await registerUniqueWeeklyContact(
      tx,
      params.interestedUserId,
      params.itemId,
      "chat",
      now,
      runtimeConfig.window
    );
  });
}

async function applySupportStateForUser(params: {
  uid: string;
  supportStatus: SupportStatus;
  supportPeriodEndMs: number | null;
  stripeCustomerId?: string | null;
  stripeSubscriptionId?: string | null;
  stripePriceId?: string | null;
}): Promise<void> {
  const nowMs = Date.now();
  const entitled = hasMonthlyEntitlement(params.supportStatus, params.supportPeriodEndMs, nowMs);
  const supportTier: SupportTier = entitled ? "supporter_monthly" : "free";
  const supportPeriodEnd = params.supportPeriodEndMs
    ? admin.firestore.Timestamp.fromMillis(params.supportPeriodEndMs)
    : null;

  const profileRef = db.collection("monetizationProfiles").doc(params.uid);
  const userRef = db.collection("users").doc(params.uid);

  const profileUpdate: Record<string, unknown> = {
    supportTier,
    supportStatus: params.supportStatus,
    supportPeriodEnd,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  if (params.stripeCustomerId !== undefined) {
    profileUpdate.stripeCustomerId = params.stripeCustomerId;
  }
  if (params.stripeSubscriptionId !== undefined) {
    profileUpdate.stripeSubscriptionId = params.stripeSubscriptionId;
  }
  if (params.stripePriceId !== undefined) {
    profileUpdate.stripePriceId = params.stripePriceId;
  }

  await profileRef.set(profileUpdate, { merge: true });
  await userRef.set(
    {
      supportTier,
      supportStatus: params.supportStatus,
      supportPeriodEnd,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
}

function getUserEmail(context: functions.https.CallableContext): string {
  const email = context.auth?.token?.email;
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError("failed-precondition", "Sender email missing");
  }
  return email;
}

async function getOwnerEmail(ownerId: string): Promise<string> {
  const ownerSnap = await db.collection("users").doc(ownerId).get();
  if (ownerSnap.exists) {
    const ownerData = ownerSnap.data() || {};
    const ownerEmail = ownerData.email;
    if (typeof ownerEmail === "string" && ownerEmail.trim().length > 0) {
      return ownerEmail;
    }
  }

  try {
    const ownerAuth = await admin.auth().getUser(ownerId);
    if (ownerAuth.email && ownerAuth.email.trim().length > 0) {
      return ownerAuth.email;
    }
  } catch (error) {
    const err = error as { message?: string; code?: string };
    functions.logger.error("Owner lookup failed", {
      ownerId,
      message: err?.message,
      code: err?.code
    });
  }

  throw new functions.https.HttpsError("failed-precondition", "Owner email missing");
}

function getItemRecord(snapshot: admin.firestore.DocumentSnapshot): ItemRecord {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "Item not found");
  }
  return (snapshot.data() || {}) as ItemRecord;
}

function ensureItemOwner(item: ItemRecord): string {
  if (typeof item.ownerId !== "string" || item.ownerId.trim().length === 0) {
    throw new functions.https.HttpsError("failed-precondition", "Item owner missing");
  }
  return item.ownerId;
}

function getItemStatus(item: ItemRecord): string {
  return typeof item.status === "string" ? item.status : "available";
}

function getItemContactPreference(item: ItemRecord): ContactPreference {
  return normalizeContactPreference(item.contactPreference);
}

function getItemTitle(item: ItemRecord): string {
  return typeof item.title === "string" && item.title.trim().length > 0
    ? item.title
    : "Untitled item";
}

function getItemArea(item: ItemRecord): string {
  const area = item.location?.approxAreaText;
  return typeof area === "string" && area.trim().length > 0 ? area : "Approximate area";
}

function getItemPhotoUrl(item: ItemRecord): string {
  return typeof item.photoUrl === "string" ? item.photoUrl : "";
}

function getItemPhotoPath(item: ItemRecord): string {
  return typeof item.photoPath === "string" ? item.photoPath.trim() : "";
}

function requireChatStatusOpen(status: ChatStatus): void {
  if (status !== CHAT_STATUSES.open) {
    throw new functions.https.HttpsError("failed-precondition", "Conversation is not open");
  }
}

function isAdmin(context: functions.https.CallableContext): boolean {
  return context.auth?.token?.admin === true;
}

async function archiveConversationsForItem(itemId: string): Promise<number> {
  let archived = 0;
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let query = db
      .collection("conversations")
      .where("itemId", "==", itemId)
      .where("status", "in", [
        CHAT_STATUSES.open,
        CHAT_STATUSES.closedByOwner,
        CHAT_STATUSES.blocked
      ])
      .orderBy("__name__")
      .limit(200);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    const updatedAt = new Date();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        status: CHAT_STATUSES.archivedUnavailable,
        updatedAt
      });
      archived++;
    }

    await batch.commit();
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  return archived;
}

async function anonymizeUserChatDataInternal(
  targetUserId: string
): Promise<UserChatAnonymizationResult> {
  let redactedMessages = 0;
  while (true) {
    const messagesSnap = await db
      .collectionGroup("messages")
      .where("senderId", "==", targetUserId)
      .limit(200)
      .get();
    if (messagesSnap.empty) {
      break;
    }

    const batch = db.batch();
    for (const doc of messagesSnap.docs) {
      batch.update(doc.ref, {
        senderId: "anonymized",
        text: "[message removed]",
        isRedacted: true,
        redactionReason: "account_deleted",
        redactedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      redactedMessages++;
    }
    await batch.commit();
  }

  let anonymizedConversations = 0;
  const convoSnap = await db
    .collection("conversations")
    .where("participants", "array-contains", targetUserId)
    .get();
  if (!convoSnap.empty) {
    const batch = db.batch();
    for (const doc of convoSnap.docs) {
      const conversation = (doc.data() || {}) as ConversationRecord;
      const participants = ensureArrayOfStrings(conversation.participants, "participants").map(
        (entry) => (entry === targetUserId ? "anonymized" : entry)
      );
      const updates: Record<string, unknown> = {
        participants,
        status: CHAT_STATUSES.archivedUnavailable,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        anonymizedUserId: targetUserId
      };
      if (conversation.ownerId === targetUserId) {
        updates.ownerId = "anonymized";
      }
      if (conversation.interestedUserId === targetUserId) {
        updates.interestedUserId = "anonymized";
      }
      batch.update(doc.ref, updates);
      anonymizedConversations++;
    }
    await batch.commit();
  }

  return {
    redactedMessages,
    anonymizedConversations
  };
}

async function deleteQueryDocuments(query: FirebaseFirestore.Query): Promise<number> {
  let deleted = 0;
  while (true) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) {
      break;
    }
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      deleted++;
    }
    await batch.commit();
  }
  return deleted;
}

async function deleteStoragePathIfExists(path: string): Promise<void> {
  if (!path) {
    return;
  }
  try {
    await admin.storage().bucket().file(path).delete({ ignoreNotFound: true });
  } catch (error) {
    functions.logger.warn("deleteStoragePathIfExists failed", {
      path,
      message: error instanceof Error ? error.message : String(error)
    });
  }
}

async function deleteUserOwnedItems(uid: string): Promise<number> {
  let deletedItems = 0;
  while (true) {
    const itemsSnap = await db
      .collection("items")
      .where("ownerId", "==", uid)
      .limit(100)
      .get();
    if (itemsSnap.empty) {
      break;
    }

    const batch = db.batch();
    for (const doc of itemsSnap.docs) {
      const item = (doc.data() || {}) as ItemRecord;
      await deleteStoragePathIfExists(getItemPhotoPath(item));
      batch.delete(doc.ref);
      deletedItems++;
    }
    await batch.commit();
  }

  try {
    await admin.storage().bucket().deleteFiles({ prefix: `itemPhotos/${uid}/` });
  } catch (error) {
    functions.logger.warn("deleteUserOwnedItems storage prefix cleanup failed", {
      uid,
      message: error instanceof Error ? error.message : String(error)
    });
  }

  return deletedItems;
}

async function cancelActiveSupportPlanIfNeeded(uid: string): Promise<void> {
  const profileSnap = await db.collection("monetizationProfiles").doc(uid).get();
  if (!profileSnap.exists) {
    return;
  }
  const profile = (profileSnap.data() || {}) as MonetizationProfileRecord;
  const stripeSubscriptionId = configValue(profile.stripeSubscriptionId);
  if (!stripeSubscriptionId) {
    return;
  }

  const supportStatus = supportStatusValue(profile.supportStatus);
  const supportPeriodEndMs = getTimestampMs(profile.supportPeriodEnd);
  if (!hasMonthlyEntitlement(supportStatus, supportPeriodEndMs, Date.now())) {
    return;
  }

  try {
    await stripeCancelSubscription(stripeSubscriptionId);
  } catch (error) {
    functions.logger.error("cancelActiveSupportPlanIfNeeded failed", {
      uid,
      stripeSubscriptionId,
      message: error instanceof Error ? error.message : String(error)
    });
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Could not cancel your active support plan automatically. Contact support before deleting your account."
    );
  }
}

function supportStatusFromStripeStatus(status: string): SupportStatus {
  if (status === "active" || status === "trialing") {
    return "active";
  }
  if (status === "past_due" || status === "unpaid" || status === "incomplete") {
    return "past_due";
  }
  return "canceled";
}

function toEpochMsFromStripe(value: number | null | undefined): number | null {
  if (!value) {
    return null;
  }
  return value * 1000;
}

export const getMonetizationStatus = paymentCallable.https.onCall(async (_data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const runtimeConfig = await getMonetizationRuntimeConfig();
  const features = effectiveMonetizationFeaturesFromConfig(runtimeConfig);
  const [profileSnap, usageSnap, activeItems] = await Promise.all([
    db.collection("monetizationProfiles").doc(uid).get(),
    db.collection("usageCounters").doc(uid).get(),
    activeItemsCountForUser(uid)
  ]);

  const profile = (profileSnap.data() || {}) as MonetizationProfileRecord;
  const supportStatus = supportStatusValue(profile.supportStatus);
  const supportPeriodEndMs = getTimestampMs(profile.supportPeriodEnd);
  const hasEntitlement = hasMonthlyEntitlement(supportStatus, supportPeriodEndMs, Date.now());
  const supportTier: SupportTier = hasEntitlement
    ? "supporter_monthly"
    : supportTierValue(profile.supportTier);

  const usage = (usageSnap.data() || {}) as UsageCounterRecord;
  const currentWeekKey = weekKeyForWindow(new Date(), runtimeConfig.window);
  const weeklyUniqueContacts =
    usage.currentWeekKey === currentWeekKey && typeof usage.weeklyUniqueContacts === "number"
      ? usage.weeklyUniqueContacts
      : 0;

  const { publishLimit, contactLimit } = contactLimitsForTier(supportTier, runtimeConfig);
  const canPublish = !features.enforcePublishLimit || activeItems < publishLimit;
  const canContact =
    !features.enforceContactLimit || weeklyUniqueContacts < contactLimit;
  const publishOverBy =
    features.enforcePublishLimit && !canPublish ? activeItems - publishLimit + 1 : 0;
  const contactOverBy =
    features.enforceContactLimit && !canContact
      ? weeklyUniqueContacts - contactLimit + 1
      : 0;

  return {
    ok: true,
    supportTier,
    supportStatus,
    supportPeriodEndEpochMs: supportPeriodEndMs,
    activeItems,
    weeklyUniqueContacts,
    publishLimit,
    contactLimit,
    canPublish,
    canContact,
    publishOverBy,
    contactOverBy,
    currentWeekKey,
    features,
    effectiveLimits: {
      publishLimit,
      contactLimit,
      timeZone: runtimeConfig.window.timeZone,
      weekStartIsoDay: runtimeConfig.window.weekStartIsoDay
    }
  };
});

export const createSupportCheckoutSession = paymentCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const runtimeConfig = await getMonetizationRuntimeConfig();
  const features = effectiveMonetizationFeaturesFromConfig(runtimeConfig);
  if (!features.checkoutEnabled) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Support checkout is currently disabled"
    );
  }
  const payload = isObject(data) ? data : {};
  const planType = requirePlanType(payload.planType);
  const source = requireNonEmptyString(payload.source, "source", 1, 80);
  const successUrl = requireUrl(payload.successUrl, "successUrl");
  const cancelUrl = requireUrl(payload.cancelUrl, "cancelUrl");

  const userEmail = context.auth?.token?.email;
  const customerId = await stripeEnsureCustomer(
    uid,
    typeof userEmail === "string" ? userEmail : null
  );

  const session = await stripeCreateCheckoutSession({
    uid,
    planType,
    source,
    successUrl,
    cancelUrl,
    customerId
  });

  functions.logger.info("createSupportCheckoutSession", {
    uid,
    planType,
    source,
    sessionId: session.id
  });

  return {
    ok: true,
    sessionId: session.id,
    url: session.url
  };
});

export const createBillingPortalSession = paymentCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const runtimeConfig = await getMonetizationRuntimeConfig();
  const features = effectiveMonetizationFeaturesFromConfig(runtimeConfig);
  if (!features.checkoutEnabled) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Support checkout is currently disabled"
    );
  }
  const payload = isObject(data) ? data : {};
  const returnUrl = requireUrl(payload.returnUrl, "returnUrl");

  const billingSnap = await db.collection("billingCustomers").doc(uid).get();
  const customerId = billingSnap.exists ? configValue(billingSnap.get("customerId")) : undefined;
  if (!customerId) {
    throw new functions.https.HttpsError("failed-precondition", "Stripe customer not found");
  }

  const url = await stripeCreateBillingPortalSession(customerId, returnUrl);
  return { ok: true, url };
});

export const stripeWebhook = functions.region(PAYMENTS_REGION).https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const signature = req.headers["stripe-signature"];
  if (!signature || Array.isArray(signature)) {
    res.status(400).send("Missing stripe signature");
    return;
  }

  let event: Record<string, unknown>;
  try {
    if (!verifyStripeWebhookSignature(req.rawBody, signature)) {
      throw new Error("Invalid signature");
    }
    event = JSON.parse(req.rawBody.toString("utf8")) as Record<string, unknown>;
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid signature";
    functions.logger.error("stripeWebhook signature error", { message });
    res.status(400).send("Invalid signature");
    return;
  }

  const eventId = configValue(event.id);
  const eventType = configValue(event.type);
  if (!eventId || !eventType) {
    res.status(400).send("Invalid event payload");
    return;
  }

  const eventRef = db.collection("stripeWebhookEvents").doc(eventId);
  if ((await eventRef.get()).exists) {
    res.status(200).send({ ok: true, duplicate: true });
    return;
  }

  try {
    const eventData = isObject(event.data) ? event.data : {};
    const object = isObject(eventData.object) ? eventData.object : {};

    switch (eventType) {
      case "checkout.session.completed": {
        const metadata = isObject(object.metadata) ? object.metadata : {};
        const metadataUid = configValue(metadata.uid);
        const customerId = configValue(object.customer);
        const uid = metadataUid ?? (customerId ? await findUidByStripeCustomerId(customerId) : null);
        if (uid && customerId) {
          await db.collection("billingCustomers").doc(uid).set(
            {
              customerId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            },
            { merge: true }
          );
        }
        if (configValue(object.mode) === "payment" && uid) {
          await db.collection("monetizationProfiles").doc(uid).set(
            {
              oneOffDonationCount: admin.firestore.FieldValue.increment(1),
              lastOneOffDonationAt: admin.firestore.FieldValue.serverTimestamp(),
              lastOneOffAmount: typeof object.amount_total === "number" ? object.amount_total : null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            },
            { merge: true }
          );
        }
        break;
      }
      case "invoice.paid":
      case "invoice.payment_failed":
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        let subscription: Record<string, unknown> | null = null;
        if (
          eventType === "customer.subscription.updated" ||
          eventType === "customer.subscription.deleted"
        ) {
          subscription = object;
        } else {
          const subscriptionId = configValue(object.subscription);
          if (subscriptionId) {
            subscription = await stripeRetrieveSubscription(subscriptionId);
          }
        }

        if (subscription) {
          const customerId = configValue(subscription.customer);
          if (!customerId) {
            break;
          }
          const metadata = isObject(subscription.metadata) ? subscription.metadata : {};
          const metadataUid = configValue(metadata.uid);
          const uid = metadataUid ?? (await findUidByStripeCustomerId(customerId));
          if (uid) {
            const items = isObject(subscription.items) ? subscription.items : {};
            const dataList = Array.isArray(items.data) ? items.data : [];
            let priceId: string | null = null;
            if (dataList.length > 0 && isObject(dataList[0])) {
              const item0 = dataList[0];
              const price = isObject(item0.price) ? item0.price : {};
              priceId = configValue(price.id) ?? null;
            }
            const supportStatus = supportStatusFromStripeStatus(
              configValue(subscription.status) ?? "canceled"
            );
            await applySupportStateForUser({
              uid,
              supportStatus,
              supportPeriodEndMs: toEpochMsFromStripe(
                typeof subscription.current_period_end === "number"
                  ? subscription.current_period_end
                  : null
              ),
              stripeCustomerId: customerId,
              stripeSubscriptionId: configValue(subscription.id) ?? null,
              stripePriceId: priceId
            });
          }
        }
        break;
      }
      default:
        break;
    }

    await eventRef.set({
      eventType,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      livemode: event.livemode === true
    });

    res.status(200).send({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Webhook processing failed";
    functions.logger.error("stripeWebhook processing error", { message, type: eventType });
    res.status(500).send("Webhook processing failed");
  }
});

export const sendContactEmail = functions.https.onCall(async (data, context) => {
  try {
    requireAppCheck(context);
    functions.logger.info("sendContactEmail request", {
      hasAuth: Boolean(context.auth),
      hasAppCheck: Boolean(context.app),
      dataKeys: isObject(data) ? Object.keys(data) : []
    });

    const senderId = requireAuth(context);
    const senderEmail = getUserEmail(context);

    const payload = isObject(data) ? data : {};
    const itemId = requireNonEmptyString(payload.itemId, "itemId", 1, 128);
    const message = requireNonEmptyString(payload.message, "message", 1, 1000);

    const itemRef = db.collection("items").doc(itemId);
    const itemSnap = await itemRef.get();
    const itemData = getItemRecord(itemSnap);

    const ownerId = ensureItemOwner(itemData);
    if (ownerId === senderId) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot contact your own item");
    }

    const contactPreference = getItemContactPreference(itemData);
    if (!emailAllowed(contactPreference)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Owner only accepts chat for this item"
      );
    }

    const recentSnap = await db
      .collection("contactRequests")
      .where("fromUserId", "==", senderId)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();
    if (!recentSnap.empty) {
      const lastCreatedAt = recentSnap.docs[0].get("createdAt");
      const lastMs = getTimestampMs(lastCreatedAt);
      if (lastMs && Date.now() - lastMs < 60 * 1000) {
        throw new functions.https.HttpsError("resource-exhausted", "Too many requests");
      }
    }

    const ownerEmail = await getOwnerEmail(ownerId);

    const isEmulator = Boolean(process.env.FIREBASE_EMULATOR_HUB);
    const runtimeConfig = legacyRuntimeConfig();
    const sendgridKey =
      configValue(runtimeConfig.sendgrid?.key) ??
      (isEmulator ? process.env.SENDGRID_KEY : undefined);
    let sendgridFrom =
      configValue(runtimeConfig.sendgrid?.from) ??
      (isEmulator ? process.env.SENDGRID_FROM : undefined);
    if (!sendgridFrom && isEmulator) {
      sendgridFrom = "noreply@localhost";
    }
    if (!isEmulator && (!sendgridKey || !sendgridFrom)) {
      throw new functions.https.HttpsError("failed-precondition", "SendGrid not configured");
    }

    if (!isEmulator && sendgridKey) {
      sgMail.setApiKey(sendgridKey);
    }

    const title = getItemTitle(itemData);
    const approxArea = getItemArea(itemData);
    const subject = `ReLoved: interesado en "${title}"`;
    const text = [
      `Mensaje de: ${senderEmail}`,
      `Item: ${title}`,
      `Zona: ${approxArea}`,
      "",
      message
    ].join("\n");

    let sent = false;
    let errorMessage: string | null = null;
    if (isEmulator) {
      sent = true;
    } else {
      try {
        await sgMail.send({
          to: ownerEmail,
          from: sendgridFrom!,
          replyTo: senderEmail,
          subject,
          text
        });
        sent = true;
      } catch (error) {
        const err = error as {
          message?: string;
          code?: string;
          response?: { body?: unknown };
        };
        errorMessage = err?.message ?? "Unknown error";
        functions.logger.error("SendGrid send failed", {
          message: err?.message,
          code: err?.code,
          responseBody: err?.response?.body
        });
      }
    }

    await db.collection("contactRequests").add({
      fromUserId: senderId,
      fromEmail: senderEmail,
      toUserId: ownerId,
      toEmail: ownerEmail,
      itemId,
      itemTitle: title,
      itemStatus: getItemStatus(itemData),
      itemApproxArea: approxArea,
      subject,
      message,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sentAt: sent ? admin.firestore.FieldValue.serverTimestamp() : null,
      sent,
      error: errorMessage,
      channel: "email",
      contactPreference
    });

    if (sent) {
      try {
        const now = nowTimestamp();
        const runtimeConfig = await getMonetizationRuntimeConfig();
        await db.runTransaction(async (tx) => {
          await registerUniqueWeeklyContact(
            tx,
            senderId,
            itemId,
            "email",
            now,
            runtimeConfig.window
          );
        });
      } catch (error) {
        functions.logger.error("contact usage counter update failed", {
          senderId,
          itemId,
          message: error instanceof Error ? error.message : "unknown"
        });
      }
    }

    if (!sent) {
      throw new functions.https.HttpsError(
        "internal",
        errorMessage ? `Failed to send email: ${errorMessage}` : "Failed to send email"
      );
    }

    return { ok: true };
  } catch (error) {
    const err = error as {
      message?: string;
      code?: string;
      details?: unknown;
      stack?: string;
    };
    if (error instanceof functions.https.HttpsError) {
      functions.logger.error("sendContactEmail failed (HttpsError)", {
        message: err?.message,
        code: err?.code,
        details: err?.details
      });
      throw error;
    }
    functions.logger.error("sendContactEmail failed (unexpected)", {
      message: err?.message,
      code: err?.code,
      details: err?.details,
      stack: err?.stack
    });
    throw new functions.https.HttpsError("internal", err?.message ?? "Unexpected error");
  }
});

export const upsertItemConversation = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const interestedUserId = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const itemId = requireNonEmptyString(payload.itemId, "itemId", 1, 128);

  const itemRef = db.collection("items").doc(itemId);
  const itemSnap = await itemRef.get();
  const item = getItemRecord(itemSnap);
  const ownerId = ensureItemOwner(item);
  if (ownerId === interestedUserId) {
    throw new functions.https.HttpsError("invalid-argument", "Cannot chat on your own item");
  }

  const status = getItemStatus(item);
  if (status !== "available") {
    throw new functions.https.HttpsError("failed-precondition", "Item is not available");
  }

  const contactPreference = getItemContactPreference(item);
  if (!chatAllowed(contactPreference)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Owner only accepts email for this item"
    );
  }

  const conversationId = getConversationId(itemId, interestedUserId);
  const conversationRef = db.collection("conversations").doc(conversationId);

  const created = await db.runTransaction(async (tx) => {
    const existingSnap = await tx.get(conversationRef);
    if (existingSnap.exists) {
      const existing = (existingSnap.data() || {}) as ConversationRecord;
      const participants = normalizeParticipants(existing);
      if (!participants.includes(ownerId) || !participants.includes(interestedUserId)) {
        throw new functions.https.HttpsError("failed-precondition", "Conversation participants invalid");
      }
      const persistedParticipants = Array.isArray(existing.participants)
        ? existing.participants.filter((entry): entry is string => typeof entry === "string")
        : [];
      const needsRepair =
        persistedParticipants.length !== participants.length ||
        participants.some((participant) => !persistedParticipants.includes(participant));
      if (needsRepair) {
        tx.set(
          conversationRef,
          {
            participants,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          },
          { merge: true }
        );
      }
      return false;
    }

    tx.set(conversationRef, {
      itemId,
      itemTitle: getItemTitle(item),
      itemPhotoUrl: getItemPhotoUrl(item),
      itemApproxArea: getItemArea(item),
      ownerId,
      interestedUserId,
      participants: [ownerId, interestedUserId],
      status: CHAT_STATUSES.open,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageAt: null,
      lastMessageSenderId: null,
      lastMessagePreview: null,
      ownerUnreadCount: 0,
      interestedUnreadCount: 0,
      closedBy: null,
      closedAt: null,
      reopenedAt: null,
      blockedByUserId: null,
      blockedAt: null
    });
    return true;
  });

  functions.logger.info("upsertItemConversation", {
    itemId,
    conversationId,
    ownerId,
    interestedUserId,
    created
  });

  return { ok: true, conversationId, created };
});

export const onConversationCreatedTrackChatUsageUk = functions
  .region(CHAT_PRIMARY_REGION)
  .firestore.document("conversations/{conversationId}")
  .onCreate(async (snapshot, _context) => {
    const conversation = (snapshot.data() || {}) as ConversationRecord;
    const interestedUserId =
      typeof conversation.interestedUserId === "string" ? conversation.interestedUserId : "";
    const itemId = typeof conversation.itemId === "string" ? conversation.itemId : "";
    const conversationId = snapshot.id;

    if (!interestedUserId || !itemId) {
      functions.logger.warn("chat usage counter skipped for invalid conversation payload", {
        conversationId,
        interestedUserId,
        itemId
      });
      return;
    }

    try {
      await registerChatContactUsage({
        interestedUserId,
        itemId,
        conversationId
      });
    } catch (error) {
      functions.logger.error("chat usage counter update failed", {
        interestedUserId,
        itemId,
        conversationId,
        message: error instanceof Error ? error.message : "unknown"
      });
    }
  });

export const sendChatMessage = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const senderId = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);
  const text = requireNonEmptyString(payload.text, "text", 1, 1000);

  functions.logger.info("sendChatMessage requested", {
    senderId,
    conversationId,
    textLength: text.length
  });

  const conversationRef = db.collection("conversations").doc(conversationId);
  const rateRef = db.collection("chatRateLimits").doc(senderId);

  const messageId = await db.runTransaction(async (tx) => {
    const conversationSnap = await tx.get(conversationRef);
    if (!conversationSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Conversation not found");
    }

    const conversation = (conversationSnap.data() || {}) as ConversationRecord;
    requireParticipant(conversation, senderId);
    const status = ensureConversationStatus(conversation.status);
    requireChatStatusOpen(status);

    const blockedByUserId =
      typeof conversation.blockedByUserId === "string" ? conversation.blockedByUserId : null;
    if (blockedByUserId && blockedByUserId === senderId) {
      throw new functions.https.HttpsError("permission-denied", "You cannot send messages in this chat");
    }

    const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId : "";
    const interestedUserId =
      typeof conversation.interestedUserId === "string" ? conversation.interestedUserId : "";
    if (ownerId.length === 0 || interestedUserId.length === 0) {
      throw new functions.https.HttpsError("failed-precondition", "Conversation participants invalid");
    }

    const rateSnap = await tx.get(rateRef);
    const now = new Date();
    const nowMs = now.getTime();
    const rateData = (rateSnap.data() || {}) as ChatRateRecord;
    const lastMessageMs = getTimestampMs(rateData.lastMessageAt);
    if (lastMessageMs && nowMs - lastMessageMs < 2000) {
      throw new functions.https.HttpsError("resource-exhausted", "Sending messages too quickly");
    }

    let minuteWindowStart = rateData.minuteWindowStart;
    let minuteCount = typeof rateData.minuteCount === "number" ? rateData.minuteCount : 0;
    const windowMs = getTimestampMs(minuteWindowStart);
    if (!windowMs || nowMs - windowMs >= 60 * 1000) {
      minuteWindowStart = now;
      minuteCount = 1;
    } else {
      if (minuteCount >= 20) {
        throw new functions.https.HttpsError("resource-exhausted", "Message rate limit exceeded");
      }
      minuteCount += 1;
    }

    const messageRef = conversationRef.collection("messages").doc();
    tx.set(messageRef, {
      senderId,
      text,
      createdAt: now,
      isRedacted: false,
      redactedAt: null,
      redactionReason: null
    });

    const ownerUnreadCount =
      typeof conversation.ownerUnreadCount === "number" ? conversation.ownerUnreadCount : 0;
    const interestedUnreadCount =
      typeof conversation.interestedUnreadCount === "number"
        ? conversation.interestedUnreadCount
        : 0;

    const preview = text.length > 120 ? `${text.substring(0, 117)}...` : text;
    tx.set(
      conversationRef,
      {
        participants: [ownerId, interestedUserId],
        updatedAt: now,
        lastMessageAt: now,
        lastMessageSenderId: senderId,
        lastMessagePreview: preview,
        ownerUnreadCount: senderId === ownerId ? 0 : ownerUnreadCount + 1,
        interestedUnreadCount: senderId === interestedUserId ? 0 : interestedUnreadCount + 1
      },
      { merge: true }
    );

    tx.set(
      rateRef,
      {
        lastMessageAt: now,
        minuteWindowStart,
        minuteCount,
        updatedAt: now
      },
      { merge: true }
    );

    return messageRef.id;
  });

  functions.logger.info("sendChatMessage succeeded", {
    senderId,
    conversationId,
    messageId
  });
  return { ok: true, messageId };
});

export const markConversationRead = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);

  const conversationRef = db.collection("conversations").doc(conversationId);
  const updatedAt = new Date();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(conversationRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Conversation not found");
    }
    const conversation = (snap.data() || {}) as ConversationRecord;
    requireParticipant(conversation, uid);
    const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId : "";
    const interestedUserId =
      typeof conversation.interestedUserId === "string" ? conversation.interestedUserId : "";
    if (uid === ownerId) {
      const ownerUnreadCount =
        typeof conversation.ownerUnreadCount === "number" ? conversation.ownerUnreadCount : 0;
      if (ownerUnreadCount <= 0) {
        return;
      }
      tx.update(conversationRef, {
        ownerUnreadCount: 0,
        updatedAt
      });
      return;
    }
    if (uid === interestedUserId) {
      const interestedUnreadCount =
        typeof conversation.interestedUnreadCount === "number"
          ? conversation.interestedUnreadCount
          : 0;
      if (interestedUnreadCount <= 0) {
        return;
      }
      tx.update(conversationRef, {
        interestedUnreadCount: 0,
        updatedAt
      });
      return;
    }
    throw new functions.https.HttpsError("permission-denied", "Not a conversation participant");
  });

  return { ok: true };
});

export const closeConversationByDonor = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);

  const conversationRef = db.collection("conversations").doc(conversationId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(conversationRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Conversation not found");
    }
    const conversation = (snap.data() || {}) as ConversationRecord;
    const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId : "";
    if (uid !== ownerId) {
      throw new functions.https.HttpsError("permission-denied", "Only owner can close this chat");
    }
    const status = ensureConversationStatus(conversation.status);
    if (status === CHAT_STATUSES.archivedUnavailable) {
      throw new functions.https.HttpsError("failed-precondition", "Archived conversations cannot be closed");
    }
    tx.update(conversationRef, {
      status: CHAT_STATUSES.closedByOwner,
      closedBy: uid,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return { ok: true };
});

export const reopenConversationByDonor = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);

  const conversationRef = db.collection("conversations").doc(conversationId);
  await db.runTransaction(async (tx) => {
    const conversationSnap = await tx.get(conversationRef);
    if (!conversationSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Conversation not found");
    }
    const conversation = (conversationSnap.data() || {}) as ConversationRecord;
    const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId : "";
    if (uid !== ownerId) {
      throw new functions.https.HttpsError("permission-denied", "Only owner can reopen this chat");
    }

    const status = ensureConversationStatus(conversation.status);
    if (status !== CHAT_STATUSES.closedByOwner) {
      throw new functions.https.HttpsError("failed-precondition", "Conversation is not closed by owner");
    }

    const itemId = requireNonEmptyString(conversation.itemId, "itemId", 1, 128);
    const itemSnap = await tx.get(db.collection("items").doc(itemId));
    const item = getItemRecord(itemSnap);
    const itemStatus = getItemStatus(item);
    if (itemStatus === "given") {
      throw new functions.https.HttpsError("failed-precondition", "Cannot reopen chat for unavailable item");
    }

    tx.update(conversationRef, {
      status: CHAT_STATUSES.open,
      reopenedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      blockedByUserId: null,
      blockedAt: null
    });
  });

  return { ok: true };
});

export const blockConversationParticipant = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);
  const blockedUserId = requireNonEmptyString(payload.blockedUserId, "blockedUserId", 1, 128);

  const conversationRef = db.collection("conversations").doc(conversationId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(conversationRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Conversation not found");
    }
    const conversation = (snap.data() || {}) as ConversationRecord;
    const participants = requireParticipant(conversation, uid);
    if (!participants.includes(blockedUserId) || blockedUserId === uid) {
      throw new functions.https.HttpsError("invalid-argument", "blockedUserId must be the other participant");
    }

    tx.update(conversationRef, {
      status: CHAT_STATUSES.blocked,
      blockedByUserId: uid,
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return { ok: true };
});

export const reportConversation = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);
  const reason = requireNonEmptyString(payload.reason, "reason", 1, 40);
  const details =
    typeof payload.details === "string" ? payload.details.trim().slice(0, 1000) : "";

  const allowedReasons = ["spam", "inappropriate", "harassment", "other"];
  if (!allowedReasons.includes(reason)) {
    throw new functions.https.HttpsError("invalid-argument", "reason is invalid");
  }

  const conversationSnap = await db.collection("conversations").doc(conversationId).get();
  if (!conversationSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Conversation not found");
  }
  const conversation = (conversationSnap.data() || {}) as ConversationRecord;
  const participants = requireParticipant(conversation, uid);
  const reportedUserId = participants.find((participant) => participant !== uid) || "";

  await db.collection("chatReports").add({
    conversationId,
    itemId: conversation.itemId,
    reporterUserId: uid,
    reportedUserId,
    reason,
    details,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "open"
  });

  return { ok: true };
});

export const setItemContactPreference = chatCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const itemId = requireNonEmptyString(payload.itemId, "itemId", 1, 128);
  const rawPreference = requireNonEmptyString(payload.contactPreference, "contactPreference", 1, 10);

  if (rawPreference !== "email" && rawPreference !== "chat" && rawPreference !== "both") {
    throw new functions.https.HttpsError("invalid-argument", "contactPreference is invalid");
  }

  const itemRef = db.collection("items").doc(itemId);
  await db.runTransaction(async (tx) => {
    const itemSnap = await tx.get(itemRef);
    const item = getItemRecord(itemSnap);
    const ownerId = ensureItemOwner(item);
    if (ownerId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only owner can change contact preference"
      );
    }

    tx.update(itemRef, {
      contactPreference: rawPreference,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  return { ok: true, contactPreference: rawPreference };
});

export const anonymizeUserChatData = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  if (!isAdmin(context)) {
    throw new functions.https.HttpsError("permission-denied", "Admin role required");
  }

  const payload = isObject(data) ? data : {};
  const targetUserId = requireNonEmptyString(payload.targetUserId, "targetUserId", 1, 128);
  const { redactedMessages, anonymizedConversations } =
    await anonymizeUserChatDataInternal(targetUserId);

  return {
    ok: true,
    redactedMessages,
    anonymizedConversations
  };
});

export const reportListing = ukCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const itemId = requireNonEmptyString(payload.itemId, "itemId", 1, 128);
  const reason = requireModerationReason(payload.reason);
  const details = optionalTrimmedString(payload.details, 1000);

  const itemSnap = await db.collection("items").doc(itemId).get();
  const item = getItemRecord(itemSnap);
  const ownerId = ensureItemOwner(item);
  if (ownerId === uid) {
    throw new functions.https.HttpsError("invalid-argument", "Cannot report your own item");
  }

  await db.collection("listingReports").doc(`${uid}_${itemId}`).set({
    itemId,
    ownerId,
    reporterUserId: uid,
    reason,
    details,
    itemStatus: getItemStatus(item),
    status: "open",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return { ok: true };
});

export const reportUser = ukCallable.https.onCall(async (data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const reportedUserId = requireNonEmptyString(
    payload.reportedUserId,
    "reportedUserId",
    1,
    128
  );
  const reason = requireModerationReason(payload.reason);
  const details = optionalTrimmedString(payload.details, 1000);

  if (reportedUserId === uid) {
    throw new functions.https.HttpsError("invalid-argument", "Cannot report yourself");
  }

  const userSnap = await db.collection("users").doc(reportedUserId).get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError("not-found", "User not found");
  }

  await db.collection("userReports").doc(`${uid}_${reportedUserId}`).set({
    reporterUserId: uid,
    reportedUserId,
    reason,
    details,
    status: "open",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return { ok: true };
});

export const deleteMyAccount = ukCallable.https.onCall(async (_data, context) => {
  requireAppCheck(context);
  const uid = requireAuth(context);

  await cancelActiveSupportPlanIfNeeded(uid);

  const [
    chatAnonymization,
    deletedItems,
    deletedSentContactRequests,
    deletedReceivedContactRequests,
    deletedRatingsAuthored,
    deletedRatingsReceived,
    deletedUsageEvents,
    deletedChatReportsFiled,
    deletedChatReportsAgainst,
    deletedListingReportsFiled,
    deletedListingReportsAgainst,
    deletedUserReportsFiled,
    deletedUserReportsAgainst
  ] = await Promise.all([
    anonymizeUserChatDataInternal(uid),
    deleteUserOwnedItems(uid),
    deleteQueryDocuments(db.collection("contactRequests").where("fromUserId", "==", uid)),
    deleteQueryDocuments(db.collection("contactRequests").where("toUserId", "==", uid)),
    deleteQueryDocuments(db.collection("ratings").where("fromUserId", "==", uid)),
    deleteQueryDocuments(db.collection("ratings").where("toUserId", "==", uid)),
    deleteQueryDocuments(db.collection("usageContactEvents").where("uid", "==", uid)),
    deleteQueryDocuments(db.collection("chatReports").where("reporterUserId", "==", uid)),
    deleteQueryDocuments(db.collection("chatReports").where("reportedUserId", "==", uid)),
    deleteQueryDocuments(db.collection("listingReports").where("reporterUserId", "==", uid)),
    deleteQueryDocuments(db.collection("listingReports").where("ownerId", "==", uid)),
    deleteQueryDocuments(db.collection("userReports").where("reporterUserId", "==", uid)),
    deleteQueryDocuments(db.collection("userReports").where("reportedUserId", "==", uid))
  ]);

  await Promise.all([
    db.collection("billingCustomers").doc(uid).delete().catch(() => undefined),
    db.collection("monetizationProfiles").doc(uid).delete().catch(() => undefined),
    db.collection("usageCounters").doc(uid).delete().catch(() => undefined),
    db.collection("users").doc(uid).delete().catch(() => undefined)
  ]);

  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== "auth/user-not-found") {
      throw error;
    }
  }

  return {
    ok: true,
    deletedItems,
    deletedContactRequests: deletedSentContactRequests + deletedReceivedContactRequests,
    deletedRatings: deletedRatingsAuthored + deletedRatingsReceived,
    deletedReports:
      deletedChatReportsFiled +
      deletedChatReportsAgainst +
      deletedListingReportsFiled +
      deletedListingReportsAgainst +
      deletedUserReportsFiled +
      deletedUserReportsAgainst,
    deletedUsageEvents,
    redactedMessages: chatAnonymization.redactedMessages,
    anonymizedConversations: chatAnonymization.anonymizedConversations
  };
});

export const archiveConversationsForUnavailableItems = functions.firestore
  .document("items/{itemId}")
  .onWrite(async (change, context) => {
    const itemId = context.params.itemId as string;
    const beforeData = (change.before.exists ? change.before.data() : null) as ItemRecord | null;
    const afterData = (change.after.exists ? change.after.data() : null) as ItemRecord | null;

    const beforeStatus = beforeData ? getItemStatus(beforeData) : null;
    const afterStatus = afterData ? getItemStatus(afterData) : null;

    const shouldArchive = !change.after.exists || afterStatus === "given";
    const becameUnavailable = beforeStatus !== afterStatus;
    if (!shouldArchive || !becameUnavailable) {
      return null;
    }

    const archived = await archiveConversationsForItem(itemId);
    functions.logger.info("archiveConversationsForUnavailableItems", {
      itemId,
      archived,
      beforeStatus,
      afterStatus
    });

    return null;
  });

export const purgeOldChatData = functions.pubsub
  .schedule("every 24 hours")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    const cutoffDate = new Date();
    cutoffDate.setMonth(cutoffDate.getMonth() - 24);
    const cutoff = admin.firestore.Timestamp.fromDate(cutoffDate);

    let deletedReports = 0;
    while (true) {
      const reportsSnap = await db
        .collection("chatReports")
        .where("createdAt", "<=", cutoff)
        .limit(200)
        .get();
      if (reportsSnap.empty) {
        break;
      }
      const batch = db.batch();
      for (const doc of reportsSnap.docs) {
        batch.delete(doc.ref);
        deletedReports++;
      }
      await batch.commit();
    }

    let redactedMessages = 0;
    while (true) {
      const messagesSnap = await db
        .collectionGroup("messages")
        .where("createdAt", "<=", cutoff)
        .where("isRedacted", "==", false)
        .limit(200)
        .get();
      if (messagesSnap.empty) {
        break;
      }
      const batch = db.batch();
      for (const doc of messagesSnap.docs) {
        batch.update(doc.ref, {
          text: "[message removed after retention]",
          isRedacted: true,
          redactionReason: "retention_expired",
          redactedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        redactedMessages++;
      }
      await batch.commit();
    }

    functions.logger.info("purgeOldChatData finished", {
      cutoff: cutoff.toDate().toISOString(),
      deletedReports,
      redactedMessages
    });

    return null;
  });

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as sgMail from "@sendgrid/mail";

admin.initializeApp();

const db = admin.firestore();

const CHAT_STATUSES = {
  open: "open",
  closedByOwner: "closed_by_owner",
  archivedUnavailable: "archived_item_unavailable",
  blocked: "blocked"
} as const;

type ContactPreference = "email" | "chat" | "both";
type ChatStatus = (typeof CHAT_STATUSES)[keyof typeof CHAT_STATUSES];

type ItemRecord = {
  ownerId?: unknown;
  title?: unknown;
  description?: unknown;
  status?: unknown;
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
  lastMessageAt?: admin.firestore.Timestamp;
  minuteWindowStart?: admin.firestore.Timestamp;
  minuteCount?: number;
};

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  return uid;
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
  const participants = ensureArrayOfStrings(conversation.participants, "participants");
  if (!participants.includes(uid)) {
    throw new functions.https.HttpsError("permission-denied", "Not a conversation participant");
  }
  return participants;
}

function getConversationId(itemId: string, interestedUserId: string): string {
  return `${itemId}_${interestedUserId}`;
}

function getTimestampMs(value: unknown): number | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  return null;
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
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        status: CHAT_STATUSES.archivedUnavailable,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      archived++;
    }

    await batch.commit();
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  return archived;
}

export const sendContactEmail = functions.https.onCall(async (data, context) => {
  try {
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
    const sendgridKey =
      functions.config().sendgrid?.key ?? (isEmulator ? process.env.SENDGRID_KEY : undefined);
    let sendgridFrom =
      functions.config().sendgrid?.from ?? (isEmulator ? process.env.SENDGRID_FROM : undefined);
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

export const upsertItemConversation = functions.https.onCall(async (data, context) => {
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
      const participants = ensureArrayOfStrings(existing.participants, "participants");
      if (!participants.includes(ownerId) || !participants.includes(interestedUserId)) {
        throw new functions.https.HttpsError("failed-precondition", "Conversation participants invalid");
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

export const sendChatMessage = functions.https.onCall(async (data, context) => {
  const senderId = requireAuth(context);
  const payload = isObject(data) ? data : {};
  const conversationId = requireNonEmptyString(payload.conversationId, "conversationId", 1, 256);
  const text = requireNonEmptyString(payload.text, "text", 1, 1000);

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
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    return messageRef.id;
  });

  return { ok: true, messageId };
});

export const markConversationRead = functions.https.onCall(async (data, context) => {
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
    requireParticipant(conversation, uid);
    const ownerId = typeof conversation.ownerId === "string" ? conversation.ownerId : "";
    const interestedUserId =
      typeof conversation.interestedUserId === "string" ? conversation.interestedUserId : "";
    if (uid === ownerId) {
      tx.update(conversationRef, {
        ownerUnreadCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return;
    }
    if (uid === interestedUserId) {
      tx.update(conversationRef, {
        interestedUnreadCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return;
    }
    throw new functions.https.HttpsError("permission-denied", "Not a conversation participant");
  });

  return { ok: true };
});

export const closeConversationByDonor = functions.https.onCall(async (data, context) => {
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

export const reopenConversationByDonor = functions.https.onCall(async (data, context) => {
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

export const blockConversationParticipant = functions.https.onCall(async (data, context) => {
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

export const reportConversation = functions.https.onCall(async (data, context) => {
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

export const setItemContactPreference = functions.https.onCall(async (data, context) => {
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
    ok: true,
    redactedMessages,
    anonymizedConversations
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

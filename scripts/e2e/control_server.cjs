#!/usr/bin/env node

const http = require("node:http");
const path = require("node:path");
const { createRequire } = require("node:module");

const functionsRequire = createRequire(
  path.join(__dirname, "..", "..", "backend", "functions", "package.json"),
);
const admin = functionsRequire("firebase-admin");

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.E2E_PROJECT_ID ||
  "demo-reloved-e2e";
process.env.GCLOUD_PROJECT = projectId;

const firestoreHost =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const port = Number(process.env.E2E_CONTROL_PORT || "8787");

if (!admin.apps.length) {
  admin.initializeApp({
    projectId,
    storageBucket: `${projectId}.appspot.com`,
  });
}

const db = admin.firestore();
const auth = admin.auth();

const USERS = {
  owner: {
    uid: "owner-e2e",
    email: "owner-e2e@example.com",
    password: "Password123!",
    displayName: "Owner E2E",
  },
  interested: {
    uid: "interested-e2e",
    email: "interested-e2e@example.com",
    password: "Password123!",
    displayName: "Interested E2E",
  },
};

const CHAT_FIXTURE = {
  item: {
    id: "item-chat-e2e",
    title: "Oak Desk",
    description: "Solid oak desk in good condition.",
    status: "available",
    contactPreference: "both",
    approxAreaText: "Central Milton Keynes",
    lat: 52.0406,
    lng: -0.7594,
    geohash: "gcpuvpk44",
  },
  initialMessageText: "Hi, is this still available?",
};

const SEARCH_FIXTURE = {
  item: {
    id: "item-search-e2e",
    title: "Brass Lamp",
    description: "Vintage brass lamp for a bedside table.",
    status: "available",
    contactPreference: "both",
    approxAreaText: "Central Milton Keynes",
    lat: 52.0406,
    lng: -0.7594,
    geohash: "gcpuvpk45",
  },
  searchTerm: "lamp",
};

function conversationIdFor(itemId, interestedUid) {
  return `${itemId}_${interestedUid}`;
}

function uniqueFixtureId(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function jsonResponse(res, statusCode, payload) {
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
  });
  res.end(JSON.stringify(payload));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      if (chunks.length === 0) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

async function ensureResponseOk(response) {
  if (response.ok) {
    return;
  }

  const body = await response.text();
  throw new Error(`Request failed with ${response.status}: ${body}`);
}

async function resetEmulatorState() {
  const firestoreUrl = `http://${firestoreHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`;
  const authUrl = `http://${authHost}/emulator/v1/projects/${projectId}/accounts`;

  await ensureResponseOk(await fetch(firestoreUrl, { method: "DELETE" }));
  await ensureResponseOk(await fetch(authUrl, { method: "DELETE" }));
}

async function ensureAuthUser(user) {
  try {
    await auth.createUser({
      uid: user.uid,
      email: user.email,
      password: user.password,
      displayName: user.displayName,
    });
  } catch (error) {
    if (error && error.code !== "auth/uid-already-exists") {
      throw error;
    }

    await auth.updateUser(user.uid, {
      email: user.email,
      password: user.password,
      displayName: user.displayName,
    });
  }

  await db.collection("users").doc(user.uid).set({
    displayName: user.displayName,
    email: user.email,
    createdAt: new Date("2026-01-01T10:00:00.000Z"),
    ratingAvg: 0,
    ratingCount: 0,
  });
}

function buildItemRecord(user, item) {
  return {
    ownerId: user.uid,
    title: item.title,
    description: item.description,
    photoUrl: "",
    photoPath: "",
    createdAt: new Date("2026-01-01T10:05:00.000Z"),
    status: item.status,
    contactPreference: item.contactPreference,
    location: {
      lat: item.lat,
      lng: item.lng,
      geohash: item.geohash,
      approxAreaText: item.approxAreaText,
    },
  };
}

function buildChatFixtureResponse(item) {
  return {
    owner: USERS.owner,
    interested: USERS.interested,
    item,
    conversation: {
      id: conversationIdFor(item.id, USERS.interested.uid),
      initialMessageText: CHAT_FIXTURE.initialMessageText,
    },
  };
}

function buildSearchFixtureResponse(item) {
  return {
    owner: USERS.owner,
    interested: USERS.interested,
    item,
    searchTerm: SEARCH_FIXTURE.searchTerm,
  };
}

async function seedChatBase() {
  await ensureAuthUser(USERS.owner);
  await ensureAuthUser(USERS.interested);

  const item = {
    ...CHAT_FIXTURE.item,
    id: uniqueFixtureId("item-chat-e2e"),
  };

  await db
    .collection("items")
    .doc(item.id)
    .set(buildItemRecord(USERS.owner, item));

  const conversationId = conversationIdFor(item.id, USERS.interested.uid);
  const conversationRef = db.collection("conversations").doc(conversationId);
  const initialMessageAt = new Date("2026-01-01T10:10:00.000Z");

  await conversationRef.set({
    itemId: item.id,
    itemTitle: item.title,
    itemPhotoUrl: "",
    itemApproxArea: item.approxAreaText,
    ownerId: USERS.owner.uid,
    interestedUserId: USERS.interested.uid,
    participants: [USERS.owner.uid, USERS.interested.uid],
    status: "open",
    createdAt: new Date("2026-01-01T10:09:00.000Z"),
    updatedAt: initialMessageAt,
    lastMessageAt: initialMessageAt,
    lastMessageSenderId: USERS.interested.uid,
    lastMessagePreview: CHAT_FIXTURE.initialMessageText,
    ownerUnreadCount: 1,
    interestedUnreadCount: 0,
    closedBy: null,
    closedAt: null,
    reopenedAt: null,
    blockedByUserId: null,
    blockedAt: null,
  });

  await conversationRef.collection("messages").doc("seed-message-1").set({
    senderId: USERS.interested.uid,
    text: CHAT_FIXTURE.initialMessageText,
    createdAt: initialMessageAt,
    isRedacted: false,
    redactedAt: null,
    redactionReason: null,
  });

  return buildChatFixtureResponse(item);
}

async function seedSearchBase() {
  await ensureAuthUser(USERS.owner);
  await ensureAuthUser(USERS.interested);

  const item = {
    ...SEARCH_FIXTURE.item,
    id: uniqueFixtureId("item-search-e2e"),
  };

  await db
    .collection("items")
    .doc(item.id)
    .set(buildItemRecord(USERS.owner, item));

  return buildSearchFixtureResponse(item);
}

async function appendChatMessage({ conversationId, senderId, text }) {
  if (!conversationId || !senderId || !text) {
    throw new Error("conversationId, senderId and text are required");
  }

  const conversationRef = db.collection("conversations").doc(conversationId);
  const conversationSnap = await conversationRef.get();
  if (!conversationSnap.exists) {
    throw new Error(`Conversation ${conversationId} not found`);
  }

  const conversation = conversationSnap.data() || {};
  const createdAt = new Date();
  const messageRef = conversationRef.collection("messages").doc();
  const ownerId = conversation.ownerId;
  const interestedUserId = conversation.interestedUserId;

  if (!ownerId || !interestedUserId) {
    throw new Error("Conversation participants missing");
  }

  const ownerUnreadCount =
    typeof conversation.ownerUnreadCount === "number"
      ? conversation.ownerUnreadCount
      : 0;
  const interestedUnreadCount =
    typeof conversation.interestedUnreadCount === "number"
      ? conversation.interestedUnreadCount
      : 0;
  const preview = text.length > 120 ? `${text.slice(0, 117)}...` : text;

  await messageRef.set({
    senderId,
    text,
    createdAt,
    isRedacted: false,
    redactedAt: null,
    redactionReason: null,
  });

  await conversationRef.set(
    {
      participants: [ownerId, interestedUserId],
      updatedAt: createdAt,
      lastMessageAt: createdAt,
      lastMessageSenderId: senderId,
      lastMessagePreview: preview,
      ownerUnreadCount: senderId === ownerId ? 0 : ownerUnreadCount + 1,
      interestedUnreadCount:
        senderId === interestedUserId ? 0 : interestedUnreadCount + 1,
    },
    { merge: true },
  );

  return { messageId: messageRef.id };
}

async function handleRoute(req, res) {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);

  if (req.method === "OPTIONS") {
    jsonResponse(res, 204, { ok: true });
    return;
  }

  if (req.method === "GET" && url.pathname === "/health") {
    jsonResponse(res, 200, { ok: true, projectId });
    return;
  }

  if (req.method === "POST" && url.pathname === "/reset") {
    await resetEmulatorState();
    jsonResponse(res, 200, { ok: true });
    return;
  }

  if (req.method === "POST" && url.pathname === "/seed/chat_base") {
    const fixture = await seedChatBase();
    jsonResponse(res, 200, { ok: true, fixture });
    return;
  }

  if (req.method === "POST" && url.pathname === "/seed/search_base") {
    const fixture = await seedSearchBase();
    jsonResponse(res, 200, { ok: true, fixture });
    return;
  }

  if (req.method === "POST" && url.pathname === "/chat/send") {
    const body = await readJson(req);
    const result = await appendChatMessage(body);
    jsonResponse(res, 200, { ok: true, ...result });
    return;
  }

  jsonResponse(res, 404, { ok: false, error: "Not found" });
}

const server = http.createServer(async (req, res) => {
  try {
    await handleRoute(req, res);
  } catch (error) {
    jsonResponse(res, 500, {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(
    `E2E control server listening on http://127.0.0.1:${port} for ${projectId}`,
  );
});

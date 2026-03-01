const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTest = require("firebase-functions-test")();

functionsTest.mockConfig({
  sendgrid: {
    key: "SG.fake",
    from: "noreply@example.com"
  }
});

const {
  sendContactEmail,
  upsertItemConversation,
  sendChatMessage,
  closeConversationByDonor,
  reopenConversationByDonor,
  blockConversationParticipant,
  reportConversation,
  markConversationRead
} = require("../lib/index");

const projectId = "reloved-test";
let db;

const authContext = (uid, email = `${uid}@example.com`, extraToken = {}) => ({
  auth: {
    uid,
    token: {
      email,
      ...extraToken
    }
  }
});

const ensureAdmin = () => {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId });
  }
  db = admin.firestore();
  return db;
};

const clearFirestore = async () => {
  ensureAdmin();
  const collections = await db.listCollections();
  for (const collection of collections) {
    const snapshot = await collection.get();
    for (const doc of snapshot.docs) {
      await doc.ref.delete();
    }
  }
};

const seedOwnerAndItem = async ({
  ownerId = "owner",
  itemId = "item-1",
  contactPreference = "both",
  status = "available"
} = {}) => {
  await db.collection("users").doc(ownerId).set({
    displayName: "Owner",
    email: "owner@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });
  await db.collection("items").doc(itemId).set({
    ownerId,
    title: "Mesa",
    description: "Mesa de madera.",
    photoUrl: "https://example.com/photo.jpg",
    photoPath: `itemPhotos/${ownerId}/${itemId}/photo.jpg`,
    createdAt: new Date(),
    status,
    contactPreference,
    location: {
      lat: 40.4168,
      lng: -3.7038,
      geohash: "ezjmgtc",
      approxAreaText: "Centro"
    }
  });
};

test.after(async () => {
  functionsTest.cleanup();
  if (admin.apps.length) {
    await admin.app().delete();
  }
});

test("chat flow: upsert conversation and send message", async () => {
  ensureAdmin();
  await clearFirestore();
  await seedOwnerAndItem();

  const upsertWrapped = functionsTest.wrap(upsertItemConversation);
  const sendWrapped = functionsTest.wrap(sendChatMessage);
  const readWrapped = functionsTest.wrap(markConversationRead);

  const upsertResult = await upsertWrapped(
    { itemId: "item-1" },
    authContext("sender")
  );
  assert.equal(upsertResult.ok, true);
  assert.equal(typeof upsertResult.conversationId, "string");

  const conversationId = upsertResult.conversationId;
  const conversationRef = db.collection("conversations").doc(conversationId);
  const conversationSnap = await conversationRef.get();
  assert.equal(conversationSnap.exists, true);
  assert.equal(conversationSnap.get("status"), "open");

  const sendResult = await sendWrapped(
    { conversationId, text: "Hola, me interesa." },
    authContext("sender")
  );
  assert.equal(sendResult.ok, true);

  const messagesSnap = await conversationRef.collection("messages").get();
  assert.equal(messagesSnap.size, 1);

  const conversationAfterSend = await conversationRef.get();
  assert.equal(conversationAfterSend.get("ownerUnreadCount"), 1);
  assert.equal(conversationAfterSend.get("interestedUnreadCount"), 0);

  const readResult = await readWrapped(
    { conversationId },
    authContext("owner", "owner@example.com")
  );
  assert.equal(readResult.ok, true);

  const conversationAfterRead = await conversationRef.get();
  assert.equal(conversationAfterRead.get("ownerUnreadCount"), 0);
});

test("chat flow: close and reopen by donor", async () => {
  ensureAdmin();
  await clearFirestore();
  await seedOwnerAndItem();

  const upsertWrapped = functionsTest.wrap(upsertItemConversation);
  const closeWrapped = functionsTest.wrap(closeConversationByDonor);
  const reopenWrapped = functionsTest.wrap(reopenConversationByDonor);
  const sendWrapped = functionsTest.wrap(sendChatMessage);

  const { conversationId } = await upsertWrapped(
    { itemId: "item-1" },
    authContext("sender")
  );

  await assert.rejects(
    () => closeWrapped({ conversationId }, authContext("sender")),
    (error) => {
      assert.equal(error.code, "permission-denied");
      return true;
    }
  );

  const closeResult = await closeWrapped(
    { conversationId },
    authContext("owner", "owner@example.com")
  );
  assert.equal(closeResult.ok, true);

  await assert.rejects(
    () => sendWrapped({ conversationId, text: "Mensaje" }, authContext("sender")),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );

  const reopenResult = await reopenWrapped(
    { conversationId },
    authContext("owner", "owner@example.com")
  );
  assert.equal(reopenResult.ok, true);

  const conversationSnap = await db.collection("conversations").doc(conversationId).get();
  assert.equal(conversationSnap.get("status"), "open");
});

test("chat flow: block and report", async () => {
  ensureAdmin();
  await clearFirestore();
  await seedOwnerAndItem();

  const upsertWrapped = functionsTest.wrap(upsertItemConversation);
  const blockWrapped = functionsTest.wrap(blockConversationParticipant);
  const sendWrapped = functionsTest.wrap(sendChatMessage);
  const reportWrapped = functionsTest.wrap(reportConversation);

  const { conversationId } = await upsertWrapped(
    { itemId: "item-1" },
    authContext("sender")
  );

  const blockResult = await blockWrapped(
    { conversationId, blockedUserId: "sender" },
    authContext("owner", "owner@example.com")
  );
  assert.equal(blockResult.ok, true);

  await assert.rejects(
    () => sendWrapped({ conversationId, text: "Mensaje" }, authContext("sender")),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );

  const reportResult = await reportWrapped(
    {
      conversationId,
      reason: "spam",
      details: "Repeated unwanted messages"
    },
    authContext("sender")
  );
  assert.equal(reportResult.ok, true);

  const reportsSnap = await db.collection("chatReports").get();
  assert.equal(reportsSnap.size, 1);
  assert.equal(reportsSnap.docs[0].get("reason"), "spam");
});

test("email contact blocked when item is chat-only", async () => {
  ensureAdmin();
  await clearFirestore();
  await seedOwnerAndItem({ contactPreference: "chat" });

  const wrapped = functionsTest.wrap(sendContactEmail);

  await assert.rejects(
    () => wrapped({ itemId: "item-1", message: "Hola" }, authContext("sender")),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});

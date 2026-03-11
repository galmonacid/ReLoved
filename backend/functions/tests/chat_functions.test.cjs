const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTest = require("firebase-functions-test")();

process.env.RELOVED_DISABLE_CONFIG_CACHE = "true";
process.env.RELOVED_SKIP_APPCHECK = "true";

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
  reportListing,
  reportUser,
  deleteMyAccount,
  markConversationRead,
  getMonetizationStatus,
  createSupportCheckoutSession,
  createBillingPortalSession
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

const ensureAuthUser = async (uid, email = `${uid}@example.com`) => {
  const auth = admin.auth();
  try {
    await auth.getUser(uid);
  } catch (_) {
    await auth.createUser({ uid, email });
  }
};

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

const weekKeyFor = (timeZone = "Europe/London", weekStartIsoDay = 1) => {
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(now);
  const values = {};
  for (const part of parts) {
    values[part.type] = part.value;
  }
  const d = new Date(Date.UTC(Number(values.year), Number(values.month) - 1, Number(values.day)));
  const weekStartSundayBased = weekStartIsoDay % 7;
  const daysSinceWeekStart = (d.getUTCDay() - weekStartSundayBased + 7) % 7;
  const weekStart = new Date(d.getTime() - daysSinceWeekStart * 24 * 60 * 60 * 1000);
  return weekStart.toISOString().slice(0, 10);
};

const londonWeekKey = () => weekKeyFor("Europe/London", 1);

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

const setRuntimeMonetizationConfig = async (overrides = {}) => {
  const base = {
    flags: {
      monetizationEnabled: false,
      supportUiEnabled: false,
      checkoutEnabled: false,
      enforcePublishLimit: false,
      enforceContactLimit: false
    },
    thresholds: {
      free: {
        publishLimit: 3,
        contactLimit: 10
      },
      supporter: {
        publishLimit: 200,
        contactLimit: 250
      }
    },
    window: {
      timeZone: "Europe/London",
      weekStartIsoDay: 1
    }
  };
  const merged = {
    ...base,
    ...overrides,
    flags: { ...base.flags, ...(overrides.flags || {}) },
    thresholds: {
      ...base.thresholds,
      ...(overrides.thresholds || {}),
      free: {
        ...base.thresholds.free,
        ...((overrides.thresholds && overrides.thresholds.free) || {})
      },
      supporter: {
        ...base.thresholds.supporter,
        ...((overrides.thresholds && overrides.thresholds.supporter) || {})
      }
    },
    window: { ...base.window, ...(overrides.window || {}) }
  };
  await db.doc("runtimeConfig/monetization").set(merged);
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

test("moderation flow: report listing and user", async () => {
  ensureAdmin();
  await clearFirestore();
  await seedOwnerAndItem();

  const reportListingWrapped = functionsTest.wrap(reportListing);
  const reportUserWrapped = functionsTest.wrap(reportUser);

  const listingResult = await reportListingWrapped(
    {
      itemId: "item-1",
      reason: "unsafe",
      details: "Suspicious exchange request."
    },
    authContext("reporter")
  );
  assert.equal(listingResult.ok, true);

  const userResult = await reportUserWrapped(
    {
      reportedUserId: "owner",
      reason: "fraud",
      details: "Asked for payment off-platform."
    },
    authContext("reporter")
  );
  assert.equal(userResult.ok, true);

  const listingReportsSnap = await db.collection("listingReports").get();
  const userReportsSnap = await db.collection("userReports").get();
  assert.equal(listingReportsSnap.size, 1);
  assert.equal(userReportsSnap.size, 1);
});

test("account deletion removes direct data and anonymizes chat", async () => {
  ensureAdmin();
  await clearFirestore();
  await ensureAuthUser("owner", "owner@example.com");
  await ensureAuthUser("sender", "sender@example.com");
  await seedOwnerAndItem({ ownerId: "sender", itemId: "item-owned-by-sender" });
  await db.collection("users").doc("sender").set({
    displayName: "Sender",
    email: "sender@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });
  await db.collection("users").doc("owner").set({
    displayName: "Owner",
    email: "owner@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });
  await db.collection("items").doc("item-target").set({
    ownerId: "owner",
    title: "Lampara",
    description: "Lampara de pie.",
    photoUrl: "https://example.com/lamp.jpg",
    photoPath: "itemPhotos/owner/item-target/photo.jpg",
    createdAt: new Date(),
    status: "available",
    contactPreference: "both",
    location: {
      lat: 51.5074,
      lng: -0.1278,
      geohash: "gcpvj0d",
      approxAreaText: "London"
    }
  });
  await db.collection("ratings").add({
    fromUserId: "sender",
    toUserId: "owner",
    itemId: "item-target",
    stars: 4,
    createdAt: new Date()
  });
  await db.collection("contactRequests").add({
    fromUserId: "sender",
    toUserId: "owner",
    itemId: "item-target",
    createdAt: new Date()
  });

  const upsertWrapped = functionsTest.wrap(upsertItemConversation);
  const sendWrapped = functionsTest.wrap(sendChatMessage);
  const deleteWrapped = functionsTest.wrap(deleteMyAccount);

  const { conversationId } = await upsertWrapped(
    { itemId: "item-target" },
    authContext("sender")
  );
  await sendWrapped(
    { conversationId, text: "Please reserve this." },
    authContext("sender")
  );

  const deleteResult = await deleteWrapped({}, authContext("sender"));
  assert.equal(deleteResult.ok, true);

  const userSnap = await db.collection("users").doc("sender").get();
  assert.equal(userSnap.exists, false);

  const ownedItemSnap = await db.collection("items").doc("item-owned-by-sender").get();
  assert.equal(ownedItemSnap.exists, false);

  const ratingsSnap = await db.collection("ratings").where("fromUserId", "==", "sender").get();
  assert.equal(ratingsSnap.empty, true);

  const contactRequestsSnap = await db
    .collection("contactRequests")
    .where("fromUserId", "==", "sender")
    .get();
  assert.equal(contactRequestsSnap.empty, true);

  const conversationSnap = await db.collection("conversations").doc(conversationId).get();
  assert.equal(conversationSnap.get("status"), "archived_item_unavailable");
  assert.equal(conversationSnap.get("interestedUserId"), "anonymized");

  const messagesSnap = await db
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .get();
  assert.equal(messagesSnap.docs[0].get("senderId"), "anonymized");
  assert.equal(messagesSnap.docs[0].get("isRedacted"), true);
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

test("monetization status: free user over publish and contact limits", async () => {
  ensureAdmin();
  await clearFirestore();
  await setRuntimeMonetizationConfig({
    flags: {
      monetizationEnabled: true,
      supportUiEnabled: true,
      checkoutEnabled: false,
      enforcePublishLimit: true,
      enforceContactLimit: true
    }
  });

  await db.collection("users").doc("u-free").set({
    displayName: "Free User",
    email: "u-free@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });

  await Promise.all([
    db.collection("items").doc("a").set({
      ownerId: "u-free",
      title: "A",
      description: "A",
      photoUrl: "https://example.com/a.jpg",
      photoPath: "itemPhotos/u-free/a/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000000", approxAreaText: "A" }
    }),
    db.collection("items").doc("b").set({
      ownerId: "u-free",
      title: "B",
      description: "B",
      photoUrl: "https://example.com/b.jpg",
      photoPath: "itemPhotos/u-free/b/photo.jpg",
      createdAt: new Date(),
      status: "reserved",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000001", approxAreaText: "B" }
    }),
    db.collection("items").doc("c").set({
      ownerId: "u-free",
      title: "C",
      description: "C",
      photoUrl: "https://example.com/c.jpg",
      photoPath: "itemPhotos/u-free/c/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000002", approxAreaText: "C" }
    })
  ]);

  await db.collection("usageCounters").doc("u-free").set({
    currentWeekKey: londonWeekKey(),
    weeklyUniqueContacts: 10,
    updatedAt: new Date()
  });

  const wrapped = functionsTest.wrap(getMonetizationStatus);
  const result = await wrapped({}, authContext("u-free", "u-free@example.com"));
  assert.equal(result.ok, true);
  assert.equal(result.supportTier, "free");
  assert.equal(result.canPublish, false);
  assert.equal(result.canContact, false);
  assert.equal(result.features.monetizationEnabled, true);
  assert.equal(result.features.enforcePublishLimit, true);
  assert.equal(result.features.enforceContactLimit, true);
});

test("monetization status: defaults fail-open when runtime config missing", async () => {
  ensureAdmin();
  await clearFirestore();

  await db.collection("users").doc("u-default").set({
    displayName: "Default User",
    email: "u-default@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });

  await Promise.all([
    db.collection("items").doc("d1").set({
      ownerId: "u-default",
      title: "D1",
      description: "D1",
      photoUrl: "https://example.com/d1.jpg",
      photoPath: "itemPhotos/u-default/d1/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000010", approxAreaText: "D1" }
    }),
    db.collection("items").doc("d2").set({
      ownerId: "u-default",
      title: "D2",
      description: "D2",
      photoUrl: "https://example.com/d2.jpg",
      photoPath: "itemPhotos/u-default/d2/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000011", approxAreaText: "D2" }
    }),
    db.collection("items").doc("d3").set({
      ownerId: "u-default",
      title: "D3",
      description: "D3",
      photoUrl: "https://example.com/d3.jpg",
      photoPath: "itemPhotos/u-default/d3/photo.jpg",
      createdAt: new Date(),
      status: "reserved",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000012", approxAreaText: "D3" }
    })
  ]);

  await db.collection("usageCounters").doc("u-default").set({
    currentWeekKey: londonWeekKey(),
    weeklyUniqueContacts: 25,
    updatedAt: new Date()
  });

  const wrapped = functionsTest.wrap(getMonetizationStatus);
  const result = await wrapped({}, authContext("u-default", "u-default@example.com"));
  assert.equal(result.ok, true);
  assert.equal(result.canPublish, true);
  assert.equal(result.canContact, true);
  assert.equal(result.publishOverBy, 0);
  assert.equal(result.contactOverBy, 0);
  assert.equal(result.features.monetizationEnabled, false);
  assert.equal(result.features.enforcePublishLimit, false);
  assert.equal(result.features.enforceContactLimit, false);
});

test("monetization status: invalid runtime config values fall back to defaults", async () => {
  ensureAdmin();
  await clearFirestore();
  await db.doc("runtimeConfig/monetization").set({
    flags: {
      monetizationEnabled: "yes",
      enforcePublishLimit: "yes"
    },
    thresholds: {
      free: {
        publishLimit: "x",
        contactLimit: -1
      }
    },
    window: {
      timeZone: "Mars/Olympus",
      weekStartIsoDay: 99
    }
  });

  await db.collection("users").doc("u-invalid").set({
    displayName: "Invalid Config User",
    email: "u-invalid@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });

  const wrapped = functionsTest.wrap(getMonetizationStatus);
  const result = await wrapped({}, authContext("u-invalid", "u-invalid@example.com"));
  assert.equal(result.ok, true);
  assert.equal(result.features.monetizationEnabled, false);
  assert.equal(result.features.enforcePublishLimit, false);
  assert.equal(result.canPublish, true);
  assert.equal(result.canContact, true);
  assert.equal(result.effectiveLimits.timeZone, "Europe/London");
  assert.equal(result.effectiveLimits.weekStartIsoDay, 1);
});

test("monetization status: custom thresholds applied when enforcement enabled", async () => {
  ensureAdmin();
  await clearFirestore();
  await setRuntimeMonetizationConfig({
    flags: {
      monetizationEnabled: true,
      supportUiEnabled: true,
      checkoutEnabled: false,
      enforcePublishLimit: true,
      enforceContactLimit: true
    },
    thresholds: {
      free: {
        publishLimit: 1,
        contactLimit: 2
      }
    },
    window: {
      timeZone: "Europe/Madrid",
      weekStartIsoDay: 7
    }
  });

  await db.collection("users").doc("u-custom").set({
    displayName: "Custom User",
    email: "u-custom@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });

  await Promise.all([
    db.collection("items").doc("c1").set({
      ownerId: "u-custom",
      title: "C1",
      description: "C1",
      photoUrl: "https://example.com/c1.jpg",
      photoPath: "itemPhotos/u-custom/c1/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000020", approxAreaText: "C1" }
    }),
    db.collection("items").doc("c2").set({
      ownerId: "u-custom",
      title: "C2",
      description: "C2",
      photoUrl: "https://example.com/c2.jpg",
      photoPath: "itemPhotos/u-custom/c2/photo.jpg",
      createdAt: new Date(),
      status: "available",
      contactPreference: "both",
      location: { lat: 0, lng: 0, geohash: "s00000021", approxAreaText: "C2" }
    })
  ]);

  await db.collection("usageCounters").doc("u-custom").set({
    currentWeekKey: weekKeyFor("Europe/Madrid", 7),
    weeklyUniqueContacts: 3,
    updatedAt: new Date()
  });

  const wrapped = functionsTest.wrap(getMonetizationStatus);
  const result = await wrapped({}, authContext("u-custom", "u-custom@example.com"));
  assert.equal(result.ok, true);
  assert.equal(result.publishLimit, 1);
  assert.equal(result.contactLimit, 2);
  assert.equal(result.canPublish, false);
  assert.equal(result.canContact, false);
  assert.equal(result.effectiveLimits.timeZone, "Europe/Madrid");
  assert.equal(result.effectiveLimits.weekStartIsoDay, 7);
  assert.equal(result.currentWeekKey, weekKeyFor("Europe/Madrid", 7));
});

test("checkout callables rejected when checkout flag disabled", async () => {
  ensureAdmin();
  await clearFirestore();
  await setRuntimeMonetizationConfig({
    flags: {
      monetizationEnabled: true,
      supportUiEnabled: true,
      checkoutEnabled: false,
      enforcePublishLimit: true,
      enforceContactLimit: true
    }
  });

  const checkoutWrapped = functionsTest.wrap(createSupportCheckoutSession);
  const portalWrapped = functionsTest.wrap(createBillingPortalSession);
  const context = authContext("u-checkout", "u-checkout@example.com");

  await assert.rejects(
    () =>
      checkoutWrapped(
        {
          planType: "one_off",
          source: "test",
          successUrl: "https://example.com/success",
          cancelUrl: "https://example.com/cancel"
        },
        context
      ),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );

  await assert.rejects(
    () =>
      portalWrapped(
        {
          returnUrl: "https://example.com/return"
        },
        context
      ),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});

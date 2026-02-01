const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const functionsTest = require("firebase-functions-test")();
const { sendContactEmail } = require("../lib/index");

const projectId = "reloved-test";
let db;

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

test.after(async () => {
  functionsTest.cleanup();
  if (admin.apps.length) {
    await admin.app().delete();
  }
});

test("flow: publish item then query results", async () => {
  await clearFirestore();
  ensureAdmin();
  await db.collection("items").doc("item-1").set({
    ownerId: "owner",
    title: "Mesa",
    description: "Mesa de madera.",
    photoUrl: "https://example.com/photo.jpg",
    photoPath: "itemPhotos/owner/item-1/photo.jpg",
    createdAt: new Date(),
    status: "available",
    location: {
      lat: 40.4168,
      lng: -3.7038,
      geohash: "ezjmgtc",
      approxAreaText: "Centro"
    }
  });

  const snapshot = await db
    .collection("items")
    .orderBy("createdAt", "desc")
    .limit(10)
    .get();

  assert.equal(snapshot.empty, false);
  assert.equal(snapshot.docs[0].get("title"), "Mesa");
});

test("flow: contact request creates record via function", async () => {
  functionsTest.mockConfig({
    sendgrid: {
      key: "SG.fake",
      from: "noreply@example.com"
    }
  });

  const wrapped = functionsTest.wrap(sendContactEmail);

  await clearFirestore();
  ensureAdmin();
  await db.collection("users").doc("owner").set({
    displayName: "Owner",
    email: "owner@example.com",
    createdAt: new Date(),
    ratingAvg: 0,
    ratingCount: 0
  });
  await db.collection("items").doc("item-1").set({
    ownerId: "owner",
    title: "Mesa",
    description: "Mesa de madera.",
    photoUrl: "https://example.com/photo.jpg",
    photoPath: "itemPhotos/owner/item-1/photo.jpg",
    createdAt: new Date(),
    status: "available",
    location: {
      lat: 40.4168,
      lng: -3.7038,
      geohash: "ezjmgtc",
      approxAreaText: "Centro"
    }
  });

  const result = await wrapped(
    { itemId: "item-1", message: "Hola" },
    {
      auth: {
        uid: "sender",
        token: { email: "sender@example.com" }
      }
    }
  );

  assert.equal(result.ok, true);

  const requests = await db.collection("contactRequests").get();
  assert.equal(requests.size, 1);
  const data = requests.docs[0].data();
  assert.equal(data.itemId, "item-1");
  assert.equal(data.fromUserId, "sender");
  assert.equal(data.toUserId, "owner");
});

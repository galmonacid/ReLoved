const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
const admin = require("firebase-admin");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} = require("@firebase/rules-unit-testing");

const projectId = "reloved-test";
let testEnvPromise;

const readRules = (relativePath) =>
  fs.readFileSync(path.join(__dirname, "..", "..", "..", relativePath), "utf8");

const userData = (email) => ({
  displayName: "Alice",
  email,
  createdAt: new Date(),
  ratingAvg: 0,
  ratingCount: 0
});

const itemData = (ownerId) => ({
  ownerId,
  title: "Silla",
  description: "Silla en buen estado.",
  photoUrl: "https://example.com/photo.jpg",
  photoPath: `itemPhotos/${ownerId}/item-1/photo.jpg`,
  createdAt: new Date(),
  status: "available",
  location: {
    lat: 40.4168,
    lng: -3.7038,
    geohash: "ezjmgtc",
    approxAreaText: "Centro"
  }
});

const getTestEnv = async () => {
  if (!testEnvPromise) {
    testEnvPromise = initializeTestEnvironment({
      projectId,
      firestore: {
        rules: readRules("firebase/firestore.rules")
      },
      storage: {
        rules: readRules("firebase/storage.rules")
      }
    });
  }
  return testEnvPromise;
};

const getAdminDb = () => {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId });
  }
  return admin.firestore();
};

const resetEnv = async () => {
  const env = await getTestEnv();
  if (env.clearFirestore) {
    await env.clearFirestore();
  }
  if (env.clearStorage) {
    await env.clearStorage();
  }
  return env;
};

test.after(async () => {
  if (testEnvPromise) {
    const env = await testEnvPromise;
    await env.cleanup();
  }
  if (admin.apps.length) {
    await Promise.all(admin.apps.map((app) => app.delete()));
  }
});

test("users can create their own profile with valid data", async () => {
  const testEnv = await resetEnv();
  const db = testEnv
    .authenticatedContext("alice", { email: "alice@example.com" })
    .firestore();
  await assertSucceeds(
    db.collection("users").doc("alice").set(userData("alice@example.com"))
  );
});

test("users cannot create another user's profile", async () => {
  const testEnv = await resetEnv();
  const db = testEnv
    .authenticatedContext("alice", { email: "alice@example.com" })
    .firestore();
  await assertFails(
    db.collection("users").doc("bob").set(userData("alice@example.com"))
  );
});

test("users can read their own profile but not other users", async () => {
  const testEnv = await resetEnv();
  const adminDb = getAdminDb();
  await adminDb.collection("users").doc("alice").set(userData("alice@example.com"));
  await adminDb.collection("users").doc("bob").set(userData("bob@example.com"));

  const aliceDb = testEnv
    .authenticatedContext("alice", { email: "alice@example.com" })
    .firestore();
  await assertSucceeds(aliceDb.collection("users").doc("alice").get());
  await assertFails(aliceDb.collection("users").doc("bob").get());
});

test("items can be created by owner only", async () => {
  const testEnv = await resetEnv();
  const db = testEnv.authenticatedContext("owner").firestore();
  await assertSucceeds(
    db.collection("items").doc("item-1").set(itemData("owner"))
  );
});

test("items cannot be created for another owner", async () => {
  const testEnv = await resetEnv();
  const db = testEnv.authenticatedContext("owner").firestore();
  await assertFails(
    db.collection("items").doc("item-1").set(itemData("someone-else"))
  );
});

test("items cannot change ownerId on update", async () => {
  const testEnv = await resetEnv();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("items").doc("item-1").set(itemData("owner"));
  });
  const db = testEnv.authenticatedContext("owner").firestore();
  await assertFails(
    db.collection("items").doc("item-1").update({ ownerId: "new-owner" })
  );
});

test("unauthenticated users can read items", async () => {
  const testEnv = await resetEnv();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("items").doc("item-1").set(itemData("owner"));
  });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(db.collection("items").doc("item-1").get());
});

test("ratings require valid stars and correct fromUserId", async () => {
  const testEnv = await resetEnv();
  const db = testEnv.authenticatedContext("rater").firestore();
  await assertSucceeds(
    db.collection("ratings").doc("rating-1").set({
      fromUserId: "rater",
      toUserId: "owner",
      itemId: "item-1",
      stars: 5,
      createdAt: new Date()
    })
  );

  await assertFails(
    db.collection("ratings").doc("rating-2").set({
      fromUserId: "someone-else",
      toUserId: "owner",
      itemId: "item-1",
      stars: 6,
      createdAt: new Date()
    })
  );
});

test("contactRequests are not writable from client", async () => {
  const testEnv = await resetEnv();
  const db = testEnv.authenticatedContext("alice").firestore();
  await assertFails(
    db.collection("contactRequests").add({
      fromUserId: "alice",
      toUserId: "owner",
      itemId: "item-1",
      message: "Hola",
      createdAt: new Date()
    })
  );
});

test("listing and user reports are not writable from client", async () => {
  const testEnv = await resetEnv();
  const db = testEnv.authenticatedContext("alice").firestore();
  await assertFails(
    db.collection("listingReports").doc("report-1").set({
      reporterUserId: "alice",
      itemId: "item-1",
      reason: "spam",
      createdAt: new Date()
    })
  );
  await assertFails(
    db.collection("userReports").doc("report-1").set({
      reporterUserId: "alice",
      reportedUserId: "bob",
      reason: "fraud",
      createdAt: new Date()
    })
  );
});

test("conversation participant can read conversation and messages", async () => {
  const testEnv = await resetEnv();
  const adminDb = getAdminDb();
  await adminDb.collection("conversations").doc("item-1_alice").set({
    itemId: "item-1",
    ownerId: "owner",
    interestedUserId: "alice",
    participants: ["owner", "alice"],
    status: "open",
    createdAt: new Date()
  });
  await adminDb
    .collection("conversations")
    .doc("item-1_alice")
    .collection("messages")
    .doc("m1")
    .set({
      senderId: "alice",
      text: "Hola",
      createdAt: new Date(),
      isRedacted: false
    });

  const db = testEnv.authenticatedContext("alice").firestore();
  await assertSucceeds(db.collection("conversations").doc("item-1_alice").get());
  await assertSucceeds(
    db
      .collection("conversations")
      .doc("item-1_alice")
      .collection("messages")
      .doc("m1")
      .get()
  );
});

test("non-participant cannot read conversation or messages", async () => {
  const testEnv = await resetEnv();
  const adminDb = getAdminDb();
  await adminDb.collection("conversations").doc("item-1_alice").set({
    itemId: "item-1",
    ownerId: "owner",
    interestedUserId: "alice",
    participants: ["owner", "alice"],
    status: "open",
    createdAt: new Date()
  });
  await adminDb
    .collection("conversations")
    .doc("item-1_alice")
    .collection("messages")
    .doc("m1")
    .set({
      senderId: "alice",
      text: "Hola",
      createdAt: new Date(),
      isRedacted: false
    });

  const db = testEnv.authenticatedContext("bob").firestore();
  await assertFails(db.collection("conversations").doc("item-1_alice").get());
  await assertFails(
    db
      .collection("conversations")
      .doc("item-1_alice")
      .collection("messages")
      .doc("m1")
      .get()
  );
});

test("storage allows image upload by owner", async () => {
  const testEnv = await resetEnv();
  const storage = testEnv.authenticatedContext("alice").storage();
  const ref = storage.ref("itemPhotos/alice/item-1/photo.jpg");
  await assertSucceeds(
    ref.put(Buffer.from("hello"), { contentType: "image/jpeg" })
  );
});

test("storage blocks non-image content types", async () => {
  const testEnv = await resetEnv();
  const storage = testEnv.authenticatedContext("alice").storage();
  const ref = storage.ref("itemPhotos/alice/item-1/readme.txt");
  await assertFails(
    ref.put(Buffer.from("hello"), { contentType: "text/plain" })
  );
});

test("storage blocks uploads to other users", async () => {
  const testEnv = await resetEnv();
  const storage = testEnv.authenticatedContext("alice").storage();
  const ref = storage.ref("itemPhotos/bob/item-1/photo.jpg");
  await assertFails(
    ref.put(Buffer.from("hello"), { contentType: "image/jpeg" })
  );
});

test("storage allows unauthenticated reads", async () => {
  const testEnv = await resetEnv();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminStorage = context.storage();
    const adminRef = adminStorage.ref("itemPhotos/alice/item-1/photo.jpg");
    await adminRef.put(Buffer.from("hello"), { contentType: "image/jpeg" });
  });
  const storage = testEnv.unauthenticatedContext().storage();
  const ref = storage.ref("itemPhotos/alice/item-1/photo.jpg");
  await assertSucceeds(ref.getDownloadURL());
});

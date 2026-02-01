const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
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
  photoUrl: "https://example.com/photo.jpg",
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

test("storage blocks unauthenticated reads", async () => {
  const testEnv = await resetEnv();
  const storage = testEnv.unauthenticatedContext().storage();
  const ref = storage.ref("itemPhotos/alice/item-1/photo.jpg");
  await assertFails(ref.getDownloadURL());
});

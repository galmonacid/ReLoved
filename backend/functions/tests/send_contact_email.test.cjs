const test = require("node:test");
const assert = require("node:assert/strict");
const functionsTest = require("firebase-functions-test")();

process.env.RELOVED_SKIP_APPCHECK = "true";
process.env.SENDGRID_KEY = "SG.fake";
process.env.SENDGRID_FROM = "noreply@example.com";

const { sendContactEmail } = require("../lib/index");

const authedContext = (overrides = {}) => ({
  auth: {
    uid: "user-123",
    token: {
      email: "sender@example.com"
    }
  },
  ...overrides
});

const asWrapped = () => functionsTest.wrap(sendContactEmail);

test.after(() => {
  functionsTest.cleanup();
});

test("sendContactEmail rejects unauthenticated calls", async () => {
  const wrapped = asWrapped();
  await assert.rejects(
    () => wrapped({}, {}),
    (error) => {
      assert.equal(error.code, "unauthenticated");
      return true;
    }
  );
});

test("sendContactEmail requires itemId", async () => {
  const wrapped = asWrapped();
  await assert.rejects(
    () => wrapped({ message: "Hola" }, authedContext()),
    (error) => {
      assert.equal(error.code, "invalid-argument");
      return true;
    }
  );
});

test("sendContactEmail requires message", async () => {
  const wrapped = asWrapped();
  await assert.rejects(
    () => wrapped({ itemId: "item-1" }, authedContext()),
    (error) => {
      assert.equal(error.code, "invalid-argument");
      return true;
    }
  );
});

test("sendContactEmail rejects empty message", async () => {
  const wrapped = asWrapped();
  await assert.rejects(
    () => wrapped({ itemId: "item-1", message: "  " }, authedContext()),
    (error) => {
      assert.equal(error.code, "invalid-argument");
      return true;
    }
  );
});

test("sendContactEmail requires sender email", async () => {
  const wrapped = asWrapped();
  await assert.rejects(
    () =>
      wrapped(
        { itemId: "item-1", message: "Hola" },
        authedContext({ auth: { uid: "user-123", token: {} } })
      ),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});

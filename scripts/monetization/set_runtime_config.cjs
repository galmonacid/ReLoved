#!/usr/bin/env node

const path = require("node:path");
const { createRequire } = require("node:module");

const functionsRequire = createRequire(
  path.join(__dirname, "..", "..", "backend", "functions", "package.json"),
);
const admin = functionsRequire("firebase-admin");

const DOC_PATH = "runtimeConfig/monetization";

function defaults() {
  return {
    flags: {
      monetizationEnabled: false,
      supportUiEnabled: false,
      checkoutEnabled: false,
      enforcePublishLimit: false,
      enforceContactLimit: false,
    },
    thresholds: {
      free: {
        publishLimit: 3,
        contactLimit: 10,
      },
      supporter: {
        publishLimit: 200,
        contactLimit: 250,
      },
    },
    window: {
      timeZone: "Europe/London",
      weekStartIsoDay: 1,
    },
  };
}

function mergeConfig(base, patch) {
  return {
    ...base,
    ...patch,
    flags: { ...base.flags, ...((patch && patch.flags) || {}) },
    thresholds: {
      ...base.thresholds,
      ...((patch && patch.thresholds) || {}),
      free: {
        ...base.thresholds.free,
        ...((patch && patch.thresholds && patch.thresholds.free) || {}),
      },
      supporter: {
        ...base.thresholds.supporter,
        ...((patch && patch.thresholds && patch.thresholds.supporter) || {}),
      },
    },
    window: { ...base.window, ...((patch && patch.window) || {}) },
  };
}

function presetConfig(name) {
  switch (name) {
    case "all-off":
      return defaults();
    case "limits-on":
      return mergeConfig(defaults(), {
        flags: {
          monetizationEnabled: true,
          supportUiEnabled: true,
          checkoutEnabled: false,
          enforcePublishLimit: true,
          enforceContactLimit: true,
        },
      });
    case "full-on":
      return mergeConfig(defaults(), {
        flags: {
          monetizationEnabled: true,
          supportUiEnabled: true,
          checkoutEnabled: true,
          enforcePublishLimit: true,
          enforceContactLimit: true,
        },
      });
    default:
      return null;
  }
}

function usage() {
  console.error(
    [
      "Usage:",
      "  node scripts/monetization/set_runtime_config.cjs show",
      "  node scripts/monetization/set_runtime_config.cjs preset <all-off|limits-on|full-on>",
      "  node scripts/monetization/set_runtime_config.cjs merge-json '<json>'",
      "  node scripts/monetization/set_runtime_config.cjs defaults",
      "",
      "Env:",
      "  GCLOUD_PROJECT or FIREBASE_PROJECT_ID (optional)",
      "  FIRESTORE_EMULATOR_HOST (optional, for emulator)",
    ].join("\n"),
  );
}

async function ensureAdmin() {
  if (admin.apps.length) {
    return;
  }
  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID ||
    process.env.E2E_PROJECT_ID;
  const options = projectId ? { projectId } : {};
  admin.initializeApp(options);
}

async function loadCurrentConfig() {
  const snap = await admin.firestore().doc(DOC_PATH).get();
  return snap.exists ? snap.data() || {} : {};
}

async function writeConfig(value) {
  await admin.firestore().doc(DOC_PATH).set(value, { merge: false });
}

async function main() {
  const command = process.argv[2];
  if (!command) {
    usage();
    process.exit(1);
  }

  await ensureAdmin();

  if (command === "show") {
    const current = await loadCurrentConfig();
    const effective = mergeConfig(defaults(), current);
    console.log(
      JSON.stringify(
        {
          path: DOC_PATH,
          current,
          effective,
        },
        null,
        2,
      ),
    );
    return;
  }

  if (command === "defaults") {
    const value = defaults();
    await writeConfig(value);
    console.log(
      JSON.stringify({ ok: true, path: DOC_PATH, written: value }, null, 2),
    );
    return;
  }

  if (command === "preset") {
    const name = process.argv[3];
    const value = presetConfig(name);
    if (!value) {
      usage();
      process.exit(1);
    }
    await writeConfig(value);
    console.log(
      JSON.stringify(
        { ok: true, path: DOC_PATH, preset: name, written: value },
        null,
        2,
      ),
    );
    return;
  }

  if (command === "merge-json") {
    const raw = process.argv[3];
    if (!raw) {
      usage();
      process.exit(1);
    }
    let patch;
    try {
      patch = JSON.parse(raw);
    } catch (error) {
      console.error(`Invalid JSON: ${error.message}`);
      process.exit(1);
    }
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
      console.error("JSON patch must be an object.");
      process.exit(1);
    }

    const current = await loadCurrentConfig();
    const merged = mergeConfig(mergeConfig(defaults(), current), patch);
    await writeConfig(merged);
    console.log(
      JSON.stringify({ ok: true, path: DOC_PATH, written: merged }, null, 2),
    );
    return;
  }

  usage();
  process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

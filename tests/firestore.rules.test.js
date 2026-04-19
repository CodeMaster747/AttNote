const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

const PROJECT_ID = "attnote-rules-test";

async function run() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
    },
  });

  try {
    // Seed fixture data bypassing rules.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc("studentA").set({
        uid: "studentA",
        role: "student",
        name: "Student A",
      });
      await db.collection("users").doc("staffA").set({
        uid: "staffA",
        role: "staff",
        name: "Staff A",
      });
      await db.collection("users").doc("studentB").set({
        uid: "studentB",
        role: "student",
        name: "Student B",
      });
      await db.collection("joinRequests").doc("req1").set({
        studentId: "studentA",
        ownerId: "staffA",
        status: "pending",
      });
    });

    // 1) Student reads own profile
    {
      const db = testEnv.authenticatedContext("studentA").firestore();
      await assertSucceeds(db.collection("users").doc("studentA").get());
    }

    // 2) Student cannot read another profile
    {
      const db = testEnv.authenticatedContext("studentA").firestore();
      await assertFails(db.collection("users").doc("studentB").get());
    }

    // 3) Staff can update request they own
    {
      const db = testEnv.authenticatedContext("staffA").firestore();
      await assertSucceeds(
        db.collection("joinRequests").doc("req1").update({ status: "approved" })
      );
    }

    // 4) Student cannot update someone else's request
    {
      const db = testEnv.authenticatedContext("studentB").firestore();
      await assertFails(
        db.collection("joinRequests").doc("req1").update({ status: "approved" })
      );
    }

    // 5) Unauthenticated cannot read subjects directory
    {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection("subjects").get());
    }

    console.log("All Firestore security rule tests passed.");
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

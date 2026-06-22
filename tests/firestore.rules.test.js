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
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8"
      ),
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
        email: "a@example.com",
      });
      await db.collection("users").doc("studentB").set({
        uid: "studentB",
        role: "student",
        name: "Student B",
        email: "b@example.com",
      });
      await db.collection("users").doc("staffA").set({
        uid: "staffA",
        role: "staff",
        name: "Staff A",
        email: "staff@example.com",
      });

      // Staff A's source subject, with Student A enrolled.
      await db
        .collection("users").doc("staffA")
        .collection("subjects").doc("sub1")
        .set({
          ownerRole: "staff",
          createdBy: "staffA",
          name: "OS",
          studentIds: ["studentA"],
        });
      await db
        .collection("users").doc("staffA")
        .collection("subjects").doc("sub1")
        .collection("dayPlans").doc("2026-06-22")
        .set({ topic: "Scheduling", notes: "" });

      // Student A's mirrored copy that links back to Staff A.
      await db
        .collection("users").doc("studentA")
        .collection("subjects").doc("sub1")
        .set({
          ownerRole: "student",
          linkedStaffId: "staffA",
          linkedStaffSubjectId: "sub1",
          studentIds: [],
        });
    });

    const asStudentA = () => testEnv.authenticatedContext("studentA").firestore();
    const asStudentB = () => testEnv.authenticatedContext("studentB").firestore();
    const asStaffA = () => testEnv.authenticatedContext("staffA").firestore();
    const anon = () => testEnv.unauthenticatedContext().firestore();

    // Resolve an even-segment path string to a Firestore DocumentReference.
    const ref = (db, p) =>
      p.split("/").reduce(
        (acc, seg, i) => (i % 2 === 0 ? acc.collection(seg) : acc.doc(seg)),
        db
      );

    // 1) Student reads own profile.
    await assertSucceeds(asStudentA().collection("users").doc("studentA").get());

    // 2) Student cannot read another student's profile.
    await assertFails(asStudentA().collection("users").doc("studentB").get());

    // 3) Staff can read a student's profile (email lookup / roster).
    await assertSucceeds(asStaffA().collection("users").doc("studentB").get());

    // 4) Enrolled student can read the staff's source subject.
    await assertSucceeds(ref(asStudentA(), "users/staffA/subjects/sub1").get());

    // 5) Non-enrolled student cannot read the staff's subject.
    await assertFails(ref(asStudentB(), "users/staffA/subjects/sub1").get());

    // 6) Enrolled student can read staff course content; others cannot.
    await assertSucceeds(
      ref(asStudentA(), "users/staffA/subjects/sub1/dayPlans/2026-06-22").get()
    );
    await assertFails(
      ref(asStudentB(), "users/staffA/subjects/sub1/dayPlans/2026-06-22").get()
    );

    // 7) Staff can create a mirrored subject in a student's collection.
    await assertSucceeds(
      ref(asStaffA(), "users/studentB/subjects/sub1").set({
        ownerRole: "student",
        linkedStaffId: "staffA",
        linkedStaffSubjectId: "sub1",
        studentIds: [],
      })
    );

    // 8) A student cannot create a subject in another student's collection.
    await assertFails(
      ref(asStudentB(), "users/studentA/subjects/hack").set({ name: "x" })
    );

    // 9) Linked staff can write attendance into a student's mirrored subject.
    await assertSucceeds(
      ref(asStaffA(), "users/studentA/subjects/sub1/attendance/att1").set({
        status: "absent",
        sessionNumber: 1,
      })
    );

    // 10) A student cannot read another student's attendance.
    await assertFails(
      ref(asStudentB(), "users/studentA/subjects/sub1/attendance/att1").get()
    );

    // 11) Unauthenticated cannot read profiles.
    await assertFails(anon().collection("users").doc("studentA").get());

    console.log("All Firestore security rule tests passed.");
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

#!/usr/bin/env node
/*
 * Seeds demo student + staff accounts (and supporting cross-account data) for
 * AttNote screenshots.
 *
 * Auth: Firebase Admin SDK via a service account key. Set
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/serviceAccount.json
 * before running, or pass --key=/path/to/serviceAccount.json.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=~/Documents/attnote-sa.json npm run seed:demo
 *   # or
 *   node tools/seed_demo_data.js --key=/abs/path/sa.json
 *
 * Re-runnable: deletes the demo Auth users + their Firestore docs first, then
 * recreates everything. Safe to run multiple times.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// ---------- CLI args ----------
const argv = process.argv.slice(2);
const keyArg = argv.find((a) => a.startsWith('--key='));
if (keyArg) {
  const p = keyArg.slice('--key='.length).replace(/^~/, process.env.HOME || '');
  process.env.GOOGLE_APPLICATION_CREDENTIALS = path.resolve(p);
}
const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!credPath || !fs.existsSync(credPath)) {
  console.error(
    'Missing service account credentials.\n' +
      'Set GOOGLE_APPLICATION_CREDENTIALS=/abs/path/sa.json or pass --key=/abs/path/sa.json.',
  );
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(credPath, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const auth = admin.auth();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ---------- Demo identities ----------
const DEMO_PASSWORD = 'DemoPass123!';

const STAFF = {
  email: 'demo-staff@demo.attnote.com',
  password: DEMO_PASSWORD,
  name: 'Dr. Priya Sharma',
  role: 'staff',
  department: 'Computer Science',
};

const STUDENT = {
  email: 'demo-student@demo.attnote.com',
  password: DEMO_PASSWORD,
  name: 'Arjun Verma',
  role: 'student',
  rollNumber: 'CSE21042',
  studentClass: '5A',
  department: 'Computer Science',
};

// Extra student profiles used to populate class lists, requests, etc.
// They get real Firestore /users docs (so staff can render names) but no
// reusable login is needed for screenshots.
const EXTRA_STUDENTS = [
  { email: 'demo-s1@demo.attnote.com', name: 'Aditi Rao',     rollNumber: 'CSE21011', studentClass: '5A' },
  { email: 'demo-s2@demo.attnote.com', name: 'Kabir Mehta',   rollNumber: 'CSE21023', studentClass: '5A' },
  { email: 'demo-s3@demo.attnote.com', name: 'Sneha Iyer',    rollNumber: 'CSE21036', studentClass: '5A' },
  { email: 'demo-s4@demo.attnote.com', name: 'Rohan Gupta',   rollNumber: 'CSE21055', studentClass: '5A' },
  { email: 'demo-s5@demo.attnote.com', name: 'Megha Nair',    rollNumber: 'CSE21068', studentClass: '5B' },
  { email: 'demo-s6@demo.attnote.com', name: 'Vikram Sinha',  rollNumber: 'CSE21077', studentClass: '5B' },
];

const ALL_DEMO_EMAILS = [
  STAFF.email,
  STUDENT.email,
  ...EXTRA_STUDENTS.map((s) => s.email),
];

// ---------- Helpers ----------
const TS = (d) => admin.firestore.Timestamp.fromDate(d);

function daysAgo(n, hour = 9) {
  const d = new Date();
  d.setHours(hour, 0, 0, 0);
  d.setDate(d.getDate() - n);
  return d;
}

function dateOnly(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function attendanceDocId(date, sessionNumber) {
  return `${dateOnly(date).getTime()}_${sessionNumber}`;
}

async function getOrCreateUser({ email, password, name }) {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.updateUser(existing.uid, { password, displayName: name });
    return existing.uid;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    const created = await auth.createUser({
      email,
      password,
      displayName: name,
      emailVerified: true,
    });
    return created.uid;
  }
}

async function deleteSubcollection(parentRef, name) {
  const snap = await parentRef.collection(name).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  if (snap.size) await batch.commit();
}

async function wipeStudentUser(uid) {
  // Delete attendance under each subject, then subjects, then the user doc.
  const subjectsSnap = await db.collection('users').doc(uid).collection('subjects').get();
  for (const subj of subjectsSnap.docs) {
    await deleteSubcollection(subj.ref, 'attendance');
    await subj.ref.delete();
  }
  await db.collection('users').doc(uid).delete().catch(() => {});
}

async function wipeStaffUser(uid) {
  const classesSnap = await db.collection('users').doc(uid).collection('classes').get();
  for (const cls of classesSnap.docs) {
    await deleteSubcollection(cls.ref, 'students');
    await deleteSubcollection(cls.ref, 'schedules');
    await cls.ref.delete();
  }
  await db.collection('users').doc(uid).delete().catch(() => {});
}

async function wipeWhereField(collection, field, value) {
  const snap = await db.collection(collection).where(field, '==', value).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  if (snap.size) await batch.commit();
}

// ---------- Main seed ----------
async function main() {
  console.log(`Using project: ${serviceAccount.project_id}`);
  console.log('Step 1/6  Creating / refreshing Firebase Auth users…');

  const staffUid   = await getOrCreateUser(STAFF);
  const studentUid = await getOrCreateUser(STUDENT);
  const extraUids  = [];
  for (const s of EXTRA_STUDENTS) {
    extraUids.push(
      await getOrCreateUser({ email: s.email, password: DEMO_PASSWORD, name: s.name }),
    );
  }

  console.log('Step 2/6  Wiping existing demo data…');
  await wipeStaffUser(staffUid);
  await wipeStudentUser(studentUid);
  for (const uid of extraUids) await wipeStudentUser(uid);

  // Global subjects created by this staff
  await wipeWhereField('subjects', 'createdBy', staffUid);
  // Synthetic faculty global subjects (seeded for student search)
  for (let i = 1; i <= 10; i++) {
    await wipeWhereField('subjects', 'createdBy', `demo-faculty-${i}`);
  }
  // Join + attendance requests touching this staff
  await wipeWhereField('joinRequests', 'ownerId', staffUid);
  await wipeWhereField('attendanceRequests', 'staffId', staffUid);

  console.log('Step 3/6  Writing user profile docs…');
  const now = FieldValue.serverTimestamp();

  await db.collection('users').doc(staffUid).set({
    uid: staffUid,
    name: STAFF.name,
    email: STAFF.email,
    role: 'staff',
    department: STAFF.department,
    rollNumber: '',
    studentClass: '',
    downloadCount: 7,
    createdAt: now,
  });

  // Demo student — assignedFaculty filled in after we know class staffIds (it's just staffUid).
  await db.collection('users').doc(studentUid).set({
    uid: studentUid,
    name: STUDENT.name,
    email: STUDENT.email,
    role: 'student',
    rollNumber: STUDENT.rollNumber,
    studentClass: STUDENT.studentClass,
    department: STUDENT.department,
    downloadCount: 3,
    createdAt: now,
    autoAttendance: false,
    assignedFaculty: {
      'Data Structures':  staffUid,
      'Operating Systems': staffUid,
    },
  });

  for (let i = 0; i < EXTRA_STUDENTS.length; i++) {
    const s = EXTRA_STUDENTS[i];
    await db.collection('users').doc(extraUids[i]).set({
      uid: extraUids[i],
      name: s.name,
      email: s.email,
      role: 'student',
      rollNumber: s.rollNumber,
      studentClass: s.studentClass,
      department: STAFF.department,
      downloadCount: 0,
      createdAt: now,
    });
  }

  console.log('Step 4/6  Creating staff classes + global subjects…');

  const termStart = daysAgo(60);
  const termEnd   = daysAgo(-60); // 60 days in the future

  const CLASSES = [
    {
      subjectName: 'Data Structures',
      department: STAFF.department,
      className: '5A',
      timetable: { Monday: 1, Wednesday: 1, Friday: 1 },
    },
    {
      subjectName: 'Operating Systems',
      department: STAFF.department,
      className: '5A',
      timetable: { Tuesday: 1, Thursday: 1 },
    },
    {
      subjectName: 'Database Systems',
      department: STAFF.department,
      className: '5B',
      timetable: { Monday: 1, Wednesday: 1 },
    },
  ];

  const created = []; // { classId, globalId, ...meta }

  for (const c of CLASSES) {
    const attendanceParts = [
      { name: 'Mid 1', startDate: TS(termStart),                   endDate: TS(daysAgo(20)) },
      { name: 'Mid 2', startDate: TS(daysAgo(19)),                  endDate: TS(termEnd)    },
    ];

    // Global subject (the one students search/join)
    const globalRef = await db.collection('subjects').add({
      name: c.subjectName,
      isGlobal: true,
      createdBy: staffUid,
      staffName: STAFF.name,
      department: c.department,
      section: c.className,
      attendanceParts,
      timetable: c.timetable,
    });

    // Local staff class doc
    const classRef = await db.collection('users').doc(staffUid).collection('classes').add({
      subjectName: c.subjectName,
      department: c.department,
      className: c.className,
      attendanceParts,
      isGlobal: true,
      globalSubjectId: globalRef.id,
    });

    created.push({ ...c, classId: classRef.id, globalId: globalRef.id, attendanceParts });
  }

  // Enroll students in the staff's classes (students subcollection)
  // Demo student is enrolled in DS (5A) and OS (5A).
  // Extras in 5A go into DS + OS; extras in 5B go into Database Systems.
  for (const cls of created) {
    const studentsToEnroll = [];
    if (cls.subjectName === 'Data Structures' || cls.subjectName === 'Operating Systems') {
      studentsToEnroll.push(studentUid);
      EXTRA_STUDENTS.forEach((s, i) => {
        if (s.studentClass === '5A') studentsToEnroll.push(extraUids[i]);
      });
    } else if (cls.subjectName === 'Database Systems') {
      EXTRA_STUDENTS.forEach((s, i) => {
        if (s.studentClass === '5B') studentsToEnroll.push(extraUids[i]);
      });
    }

    for (const sid of studentsToEnroll) {
      await db
        .collection('users')
        .doc(staffUid)
        .collection('classes')
        .doc(cls.classId)
        .collection('students')
        .doc(sid)
        .set({
          joinedAt: FieldValue.serverTimestamp(),
          approved: true,
        });
    }

    // Add session schedules with topics so the topic-revision screen has plenty to work with.
    const scheduleDates = [daysAgo(35), daysAgo(28), daysAgo(21), daysAgo(14), daysAgo(7), daysAgo(2)];
    const topicMap = {
      'Data Structures':   ['Arrays & Strings', 'Stacks & Queues', 'Linked Lists', 'Binary Trees', 'AVL Trees', 'Hash Tables'],
      'Operating Systems': ['Processes', 'Threads & Sync', 'Scheduling', 'Deadlocks', 'Page Replacement', 'Semaphores'],
      'Database Systems':  ['ER Models', 'Relational Algebra', 'SQL DDL', 'SQL DML', 'Normalization', 'Indexing'],
    };
    for (let i = 0; i < scheduleDates.length; i++) {
      const d = dateOnly(scheduleDates[i]);
      await db
        .collection('users')
        .doc(staffUid)
        .collection('classes')
        .doc(cls.classId)
        .collection('schedules')
        .doc(`${d.getTime()}`)
        .set({
          staffId: staffUid,
          classId: cls.classId,
          subjectName: cls.subjectName,
          date: TS(d),
          numberOfSessions: 1,
          sessionTopics: { '1': topicMap[cls.subjectName][i] },
          createdAt: FieldValue.serverTimestamp(),
        });
    }
  }

  console.log('Step 5/6  Writing demo student subjects + attendance history…');

  // Helper: write a subject doc into student's local subjects collection.
  async function setStudentSubject(uid, name, payload) {
    const docId = name.trim().toLowerCase();
    await db
      .collection('users')
      .doc(uid)
      .collection('subjects')
      .doc(docId)
      .set(payload);
    return docId;
  }

  // Helper: write a single attendance record under a student's subject.
  async function writeAttendance(uid, subjectDocId, { date, status, sessionNumber = 1, topic }) {
    const d = dateOnly(date);
    const id = attendanceDocId(d, sessionNumber);
    await db
      .collection('users')
      .doc(uid)
      .collection('subjects')
      .doc(subjectDocId)
      .collection('attendance')
      .doc(id)
      .set({
        subjectId: subjectDocId,
        date: TS(d),
        status,
        sessionNumber,
        ...(topic ? { topic } : {}),
      });
  }

  // Student's local mirror of the two staff-led subjects (mirrors what the
  // approve-join flow writes).
  const dsClass = created.find((c) => c.subjectName === 'Data Structures');
  const osClass = created.find((c) => c.subjectName === 'Operating Systems');

  await setStudentSubject(studentUid, 'Data Structures', {
    name: 'Data Structures',
    isGlobal: true,
    createdBy: staffUid,
    staffName: STAFF.name,
    department: STAFF.department,
    section: '5A',
    attendanceParts: dsClass.attendanceParts,
    timetable: dsClass.timetable,
    globalId: dsClass.globalId,
  });

  await setStudentSubject(studentUid, 'Operating Systems', {
    name: 'Operating Systems',
    isGlobal: true,
    createdBy: staffUid,
    staffName: STAFF.name,
    department: STAFF.department,
    section: '5A',
    attendanceParts: osClass.attendanceParts,
    timetable: osClass.timetable,
    globalId: osClass.globalId,
  });

  // Personal subjects (no staff assigned → student manages directly).
  await setStudentSubject(studentUid, 'Algorithms', {
    name: 'Algorithms',
    isGlobal: false,
    createdBy: '',
    staffName: '',
    department: STAFF.department,
    section: '5A',
    attendanceParts: [],
    timetable: { Tuesday: 1, Friday: 1 },
  });

  await setStudentSubject(studentUid, 'Mathematics', {
    name: 'Mathematics',
    isGlobal: false,
    createdBy: '',
    staffName: '',
    department: STAFF.department,
    section: '5A',
    attendanceParts: [],
    timetable: { Monday: 1, Thursday: 1 },
  });

  await setStudentSubject(studentUid, 'Computer Networks', {
    name: 'Computer Networks',
    isGlobal: false,
    createdBy: '',
    staffName: '',
    department: STAFF.department,
    section: '5A',
    attendanceParts: [],
    timetable: { Wednesday: 1, Saturday: 1 },
  });

  await setStudentSubject(studentUid, 'Software Engineering', {
    name: 'Software Engineering',
    isGlobal: false,
    createdBy: '',
    staffName: '',
    department: STAFF.department,
    section: '5A',
    attendanceParts: [],
    timetable: { Tuesday: 1, Thursday: 1 },
  });

  // Attendance history — ~60 days of records spread roughly every other day.
  // Patterns are deterministic so analytics renders a realistic, varied mix.
  // P = present, A = absent, C = cancelled.
  const PATTERNS = {
    'Data Structures':     ['P','P','A','P','P','P','C','P','A','P','P','P','P','A','P','P','C','P','P','A','P','P','P','P','P','P','A','P','P','P'],
    'Operating Systems':   ['P','A','P','P','P','C','P','P','A','P','P','P','A','P','P','C','P','P','P','A','P','P','P','P','P','A','P','P'],
    'Algorithms':          ['P','P','P','A','P','P','P','C','P','P','A','P','P','P','P','A','P','P','C','P','P','P','A','P','P','P','P','P'],
    'Mathematics':         ['P','P','A','P','P','P','P','A','P','P','C','P','A','P','P','P','P','A','P','P','P','C','P','P','P','A','P','P','P'],
    'Computer Networks':   ['P','P','P','A','P','P','C','P','P','P','A','P','P','P','P','A','P','P','C','P','P','P','P','A','P','P'],
    'Software Engineering':['P','P','P','P','A','P','P','P','C','P','P','A','P','P','P','P','A','P','P','C','P','P','P','P','A','P','P','P'],
  };
  const STATUS_MAP = {
    P: 'present',
    A: 'absent',
    C: 'cancelled',
  };
  const TOPICS_BY_SUBJECT = {
    'Data Structures':     ['Arrays', 'Linked Lists', 'Stacks', 'Queues', 'Recursion', 'Trees Intro', 'Binary Trees', 'BST', 'AVL Trees', 'Red-Black Trees', 'Heaps', 'Priority Queues', 'Hash Tables', 'Tries', 'Graph Repn', 'BFS', 'DFS', 'Topological Sort', 'MST', "Kruskal's", "Prim's", 'Shortest Paths', 'Dijkstra', 'Bellman-Ford', 'Floyd-Warshall', 'Disjoint Sets', 'Segment Trees', 'Fenwick Trees', 'Suffix Arrays', 'String Matching'],
    'Operating Systems':   ['OS Overview', 'Processes', 'Threads', 'Context Switch', 'CPU Scheduling', 'FCFS / SJF', 'Priority Sched', 'Round Robin', 'Synchronization', 'Mutex & Locks', 'Semaphores', 'Monitors', 'Deadlocks', 'Banker Algo', 'Memory Mgmt', 'Paging', 'Segmentation', 'Virtual Memory', 'Page Replacement', 'Thrashing', 'File Systems', 'Inodes', 'FAT vs NTFS', 'Disk Scheduling', 'I/O Systems', 'RAID', 'Security', 'Virtualization'],
    'Algorithms':          ['Big-O Notation', 'Insertion Sort', 'Merge Sort', 'Quick Sort', 'Heap Sort', 'Counting Sort', 'Radix Sort', 'Linear Search', 'Binary Search', 'Ternary Search', 'Recursion', 'Divide & Conquer', 'Greedy Intro', 'Huffman Coding', 'Activity Selection', 'DP Intro', 'Fibonacci DP', 'Knapsack 0/1', 'LCS', 'LIS', 'Matrix Chain', 'Coin Change', 'Backtracking', 'N-Queens', 'Sudoku Solver', 'Branch & Bound', 'NP-Completeness', 'Approximation'],
    'Mathematics':         ['Set Theory', 'Logic & Proofs', 'Functions', 'Relations', 'Combinatorics', 'Permutations', 'Binomial Coeff', 'Pigeonhole', 'Probability Intro', 'Conditional Prob', 'Bayes Theorem', 'Random Variables', 'Distributions', 'Graph Theory', 'Connectivity', 'Trees', 'Number Theory', 'GCD & LCM', 'Modular Arithmetic', 'Fermat & Euler', 'Linear Algebra', 'Matrices', 'Determinants', 'Eigenvalues', 'Vector Spaces', 'Calculus Recap', 'Limits', 'Derivatives', 'Integrals'],
    'Computer Networks':   ['Network Topologies', 'OSI Model', 'TCP/IP Stack', 'Physical Layer', 'Data Link Layer', 'Ethernet', 'Wi-Fi', 'Switches & Bridges', 'Network Layer', 'IPv4 vs IPv6', 'Subnetting', 'Routing Algorithms', 'OSPF', 'BGP', 'Transport Layer', 'TCP Handshake', 'UDP', 'Congestion Control', 'Application Layer', 'HTTP / HTTPS', 'DNS', 'SMTP & POP3', 'TLS / SSL', 'DHCP', 'NAT', 'CDNs'],
    'Software Engineering':['SDLC Overview', 'Waterfall', 'Agile Manifesto', 'Scrum Framework', 'Kanban', 'Requirements', 'Use Cases', 'UML Class Diagrams', 'UML Sequence', 'Design Principles', 'SOLID', 'DRY & KISS', 'Design Patterns', 'Singleton', 'Factory', 'Observer', 'MVC vs MVVM', 'Testing Pyramid', 'Unit Testing', 'Integration Testing', 'CI/CD', 'Git Workflows', 'Code Review', 'Tech Debt', 'Refactoring', 'Microservices', 'Monoliths', 'Deployment'],
  };

  for (const subjectName of Object.keys(PATTERNS)) {
    const docId = subjectName.trim().toLowerCase();
    const pattern = PATTERNS[subjectName];
    const topics  = TOPICS_BY_SUBJECT[subjectName];
    for (let i = 0; i < pattern.length; i++) {
      // Sessions roughly every other day, newest at i=last.
      const dayOffset = i * 2;
      const date      = daysAgo(pattern.length * 2 - dayOffset - 1);
      const status    = STATUS_MAP[pattern[i]];
      const topic     = topics[i % topics.length];
      await writeAttendance(studentUid, docId, {
        date,
        status,
        sessionNumber: 1,
        topic,
      });
    }
  }

  console.log('Step 6/7  Writing cross-account requests…');

  const dbClass = created.find((c) => c.subjectName === 'Database Systems');
  const requesters5A = [];
  EXTRA_STUDENTS.forEach((s, i) => {
    if (s.studentClass === '5A') requesters5A.push({ uid: extraUids[i], name: s.name });
  });

  // Pending JOIN requests on Database Systems (5B) — using 5A extras who are
  // NOT already enrolled, so the staff "Join Requests" screen has clean
  // pending rows for screenshots. All 4 of the 5A extras request the class.
  for (const r of requesters5A) {
    await db.collection('joinRequests').add({
      studentId: r.uid,
      studentName: r.name,
      subjectId: dbClass.globalId,
      subjectName: dbClass.subjectName,
      ownerId: staffUid,
      department: STAFF.department,
      studentClass: '5B',
      status: 'pending',
      requestedAt: FieldValue.serverTimestamp(),
    });
  }

  // Pending ATTENDANCE requests on Data Structures across the last few days —
  // 4 requests spanning 4 different dates and a mix of present/absent.
  const dsRequestPlan = [
    { dayOffset: 1, attendanceStatus: 'present' },
    { dayOffset: 2, attendanceStatus: 'present' },
    { dayOffset: 4, attendanceStatus: 'absent'  },
    { dayOffset: 5, attendanceStatus: 'present' },
  ];
  for (let i = 0; i < dsRequestPlan.length && i < requesters5A.length; i++) {
    const r = requesters5A[i];
    const { dayOffset, attendanceStatus } = dsRequestPlan[i];
    await db.collection('attendanceRequests').add({
      studentId: r.uid,
      studentName: r.name,
      staffId: staffUid,
      subjectId: 'Data Structures',
      subjectName: 'Data Structures',
      date: TS(dateOnly(daysAgo(dayOffset))),
      sessionNumber: 1,
      attendanceStatus,
      status: 'pending',
      requestedAt: FieldValue.serverTimestamp(),
    });
  }

  console.log('Step 7/7  Adding discoverable global subjects (search screen)…');

  // A handful of extra global subjects owned by hypothetical other faculty, so
  // the student's "Search subjects" screen returns realistic results. These
  // have no real `users/{ownerId}` doc — join requests against them would
  // queue with no staff to approve, but they look right in search.
  const otherFaculty = [
    { staffName: 'Prof. Ramesh Kumar',  subjectName: 'Machine Learning',       department: STAFF.department, section: '7A', timetable: { Monday: 1, Wednesday: 1 } },
    { staffName: 'Prof. Anita Desai',    subjectName: 'Compiler Design',        department: STAFF.department, section: '6A', timetable: { Tuesday: 1, Thursday: 1 } },
    { staffName: 'Dr. Karthik Subbu',    subjectName: 'Discrete Mathematics',   department: STAFF.department, section: '3A', timetable: { Monday: 1, Friday: 1 } },
    { staffName: 'Dr. Lavanya Pillai',   subjectName: 'Artificial Intelligence',department: STAFF.department, section: '7B', timetable: { Wednesday: 1, Friday: 1 } },
  ];
  // Synthetic non-existent staff UIDs (deterministic, demo-only).
  let synthIdx = 0;
  for (const f of otherFaculty) {
    const syntheticUid = `demo-faculty-${++synthIdx}`;
    await db.collection('subjects').add({
      name: f.subjectName,
      isGlobal: true,
      createdBy: syntheticUid,
      staffName: f.staffName,
      department: f.department,
      section: f.section,
      attendanceParts: [
        { name: 'Mid 1', startDate: TS(termStart), endDate: TS(daysAgo(20)) },
        { name: 'Mid 2', startDate: TS(daysAgo(19)), endDate: TS(termEnd) },
      ],
      timetable: f.timetable,
    });
  }

  console.log('');
  console.log('Done.');
  console.log('-----------------------------------------------------------');
  console.log(`Staff   login : ${STAFF.email}   password: ${DEMO_PASSWORD}`);
  console.log(`Student login : ${STUDENT.email} password: ${DEMO_PASSWORD}`);
  console.log('-----------------------------------------------------------');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  });

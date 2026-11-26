/**
 * Auto-fetches Banking PO / Clerk Quant Mock Tests TWICE A MONTH directly into Firestore `mockTests`
 * under the `Banking PO/Clerk` folder (Homescreen > Mock Tests > Banking PO/Clerk > Quant > 4 Sub-Folders).
 *
 * Schedule (fetch-banking-quant-mocks.yml):
 *   - Runs in the 1st and 3rd week of every month (Monday 9:30 AM IST, retries Wed & Fri).
 *   - Generates 4 bilingual tests per run (15 Moderate-to-Hard PO-level questions each):
 *       1) Quant / Speed Maths
 *       2) Quant / Arithmetic  (includes trending Variable-Based PO questions)
 *       3) Quant / Advanced Maths
 *       4) Quant / Data Interpretation  (3 graph-backed DI sets with crisp zoomable PNG chart images)
 *   - Timer & marking: reads Admin Panel saved settings from `appConfig/bankingQuant`
 *     (overridable per run via DURATION_MINUTES / MARKS_PER_QUESTION / NEGATIVE_MARKS),
 *     falling back to 15 minutes, +1 mark, -0.25 negative marking.
 *   - Retention: auto-generated Quant mocks older than 2 months are automatically removed (manual tests are untouched).
 */
const core = require("./fetch-free-mcqs.js");
const { resolveWeek, shiftWeek } = require("./fetch-free-english.js");
const { weekLabel } = require("./fetch-free-weekly.js");
const gen = require("./banking-quant-generator.js");

const { callGemini, istDateStr, dateMinusMonths, oneLine, sleep } = core;
const { QUANT_SUBFOLDERS, QUESTIONS_PER_SUBFOLDER, generateQuantSubfolder } = gen;

const DEFAULT_FOLDER_NAME = process.env.QUANT_FOLDER_NAME || "Banking PO/Clerk";
const KEEP_MONTHS = process.env.QUANT_KEEP_MONTHS !== undefined ? Number(process.env.QUANT_KEEP_MONTHS) : 2;
const PREVIOUS_WEEKS = 6;
const PAUSE_BETWEEN_TESTS_MS = 4000;
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const DEFAULT_SETTINGS = {
  durationMinutes: 15,
  marksPerQuestion: 1,
  negativeMarks: 0.25,
};

const docIdFor = (subfolderId, weekKey) => `auto_banking_quant_${subfolderId}_${weekKey}`;

/** Parses optional numeric env override; returns null when blank or invalid. */
function parseOptionalNumber(raw, { min = 0, max = 1000, integer = false } = {}) {
  const s = String(raw == null ? "" : raw).trim();
  if (!s) return null;
  const n = Number(s);
  if (!Number.isFinite(n) || n < min || n > max) return null;
  return integer ? Math.round(n) : n;
}

/** Resolves exam settings: GitHub workflow input > Firestore appConfig/bankingQuant > DEFAULT_SETTINGS. */
async function loadTestSettings(db) {
  let saved = {};
  try {
    const snap = await db.collection("appConfig").doc("bankingQuant").get();
    if (snap.exists && snap.data()) saved = snap.data();
  } catch (err) {
    console.warn("Could not read appConfig/bankingQuant (using defaults):", err.message);
  }

  const savedDur = parseOptionalNumber(saved.durationMinutes, { min: 0, max: 300, integer: true });
  const savedMarks = parseOptionalNumber(saved.marksPerQuestion, { min: 0.25, max: 100 });
  const savedNeg = parseOptionalNumber(saved.negativeMarks, { min: 0, max: 100 });

  const envDur = parseOptionalNumber(process.env.DURATION_MINUTES, { min: 0, max: 300, integer: true });
  const envMarks = parseOptionalNumber(process.env.MARKS_PER_QUESTION, { min: 0.25, max: 100 });
  const envNeg = parseOptionalNumber(process.env.NEGATIVE_MARKS, { min: 0, max: 100 });

  const durationMinutes = envDur !== null ? envDur : savedDur !== null ? savedDur : DEFAULT_SETTINGS.durationMinutes;
  const marksPerQuestion = envMarks !== null ? envMarks : savedMarks !== null ? savedMarks : DEFAULT_SETTINGS.marksPerQuestion;
  const rawNeg = envNeg !== null ? envNeg : savedNeg !== null ? savedNeg : DEFAULT_SETTINGS.negativeMarks;
  const negativeMarks = Math.min(rawNeg, marksPerQuestion);

  return { durationMinutes, marksPerQuestion, negativeMarks };
}

/** "Speed Maths · Week 48 · 23 Nov – 29 Nov 2026" — matches Free MCQs / Mock Tests tile format. */
function formatTestTitle(subfolderName, week) {
  const fmt = (d, withYear) => {
    const [y, m, day] = d.split("-").map(Number);
    return `${day} ${SHORT_MONTHS[m - 1]}${withYear ? ` ${y}` : ""}`;
  };
  const sameYear = week.periodStart.slice(0, 4) === week.periodEnd.slice(0, 4);
  const wNum = Number(/W(\d+)$/.exec(week.weekKey)[1]);
  const range = `${fmt(week.periodStart, !sameYear)} – ${fmt(week.periodEnd, true)}`;
  return `${subfolderName} · Week ${wNum} · ${range}`;
}

/** Finds the existing free "Banking PO/Clerk" folder in mockTestFolders (or creates it if missing). */
async function ensureBankingFolder(db, admin, folderName = DEFAULT_FOLDER_NAME) {
  const targetKey = folderName.trim().toLowerCase();
  const snap = await db.collection("mockTestFolders").get();
  const freeMatches = [];
  const anyMatches = [];

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const name = String(data.examName || "").trim().toLowerCase();
    if (name === targetKey) {
      const batchIds = Array.isArray(data.batchIds) ? data.batchIds : [];
      if (batchIds.length === 0) freeMatches.push(doc);
      else anyMatches.push(doc);
    }
  }

  if (freeMatches.length) {
    console.log(`Found FREE Mock Tests folder "${folderName}" (id=${freeMatches[0].id}).`);
    return freeMatches[0].id;
  }
  if (anyMatches.length) {
    console.log(`Found Mock Tests folder "${folderName}" (id=${anyMatches[0].id}).`);
    return anyMatches[0].id;
  }

  const ref = await db.collection("mockTestFolders").add({
    examName: folderName.trim(),
    batchIds: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Created FREE Mock Tests folder "${folderName}" (id=${ref.id}).`);
  return ref.id;
}

/** Deletes only auto-generated Banking Quant mocks older than KEEP_MONTHS (manual tests untouched). */
async function purgeOldQuantMocks(db) {
  if (!KEEP_MONTHS || KEEP_MONTHS <= 0) return 0;
  const cutoff = dateMinusMonths(istDateStr(0), KEEP_MONTHS);
  const snap = await db.collection("mockTests").where("autoSource", "==", "banking_quant").get();
  const stale = snap.docs.filter((d) => {
    const start = String((d.data() || {}).periodStart || "");
    return start && start < cutoff;
  });
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    stale.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  if (stale.length) {
    console.log(`Deleted ${stale.length} auto Banking Quant mock(s) older than ${cutoff}: ${stale.map((d) => d.id).join(", ")}`);
  }
  return stale.length;
}

/** Reads previous 6 weeks' question texts for one sub-folder to avoid repeats. */
async function loadPreviousTexts(db, subfolderId, week) {
  const refs = [];
  for (let k = 1; k <= PREVIOUS_WEEKS; k++) {
    refs.push(db.collection("mockTests").doc(docIdFor(subfolderId, shiftWeek(week, -k).weekKey)));
  }
  const snaps = await db.getAll(...refs);
  const out = [];
  for (const s of snaps) {
    if (!s.exists) continue;
    for (const q of s.data().questions || []) {
      const t = oneLine(q && q.text);
      if (t) out.push(t);
    }
  }
  return out.slice(0, 40);
}

async function main() {
  const week = resolveWeek(process.env.WEEK);
  const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
  const IMAGE_TOKEN = process.env.IMAGE_UPLOAD_TOKEN || "";
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  const admin = require("firebase-admin");
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();

  const force = process.env.FORCE === "true";
  const notify = process.env.QUANT_NOTIFY !== "false";
  const onlySub = String(process.env.ONLY_SUBFOLDER || "").trim().toLowerCase();
  const label = weekLabel(week);
  const settings = await loadTestSettings(db);

  console.log(
    `Building Banking PO/Clerk Quant Mocks for ${week.weekKey} (${week.periodStart} to ${week.periodEnd}) | ` +
      `Settings: ${settings.durationMinutes} min, +${settings.marksPerQuestion} / -${settings.negativeMarks}.`
  );

  // 0) Retention cleanup (only auto-generated Banking Quant mocks older than KEEP_MONTHS).
  await purgeOldQuantMocks(db);

  // 1) Resolve target Mock Tests folder ("Banking PO/Clerk").
  const folderId = await ensureBankingFolder(db, admin);

  // 2) Select sub-folders to build.
  const targets = onlySub
    ? QUANT_SUBFOLDERS.filter((s) => s.id === onlySub)
    : QUANT_SUBFOLDERS;
  if (!targets.length) {
    console.error(`Unknown ONLY_SUBFOLDER="${onlySub}". Use one of: ${QUANT_SUBFOLDERS.map((s) => s.id).join(", ")}`);
    process.exit(1);
  }

  let newTests = 0;
  let failed = 0;

  for (const sub of targets) {
    const id = docIdFor(sub.id, week.weekKey);
    const ref = db.collection("mockTests").doc(id);
    if (!force) {
      const snap = await ref.get();
      if (snap.exists) {
        console.log(`${id}: already exists, skipped.`);
        continue;
      }
    }

    if (sub.id === "data_interpretation" && !IMAGE_TOKEN) {
      console.error("IMAGE_UPLOAD_TOKEN secret is missing: required to upload DI Graph PNG images to ysh-images.");
      failed++;
      continue;
    }

    console.log(`${id} (${sub.subject}): generating ${QUESTIONS_PER_SUBFOLDER} bilingual PO-level questions...`);
    const previous = await loadPreviousTexts(db, sub.id, week);
    const questions = await generateQuantSubfolder({
      subfolder: sub,
      periodKey: week.weekKey,
      periodLabel: label,
      previous,
      key: GEMINI_KEY,
      callGemini,
      imageToken: IMAGE_TOKEN,
    });

    if (questions.length < QUESTIONS_PER_SUBFOLDER) {
      failed++;
      console.error(`${id}: only ${questions.length}/${QUESTIONS_PER_SUBFOLDER} verified question(s) — not published.`);
      continue;
    }

    await ref.set({
      folderId,
      title: formatTestTitle(sub.name, week),
      subject: sub.subject,
      examStage: "",
      durationMinutes: settings.durationMinutes,
      marksPerQuestion: settings.marksPerQuestion,
      negativeMarks: settings.negativeMarks,
      questions,
      autoGenerated: true,
      autoSource: "banking_quant",
      subfolderId: sub.id,
      weekKey: week.weekKey,
      periodStart: week.periodStart,
      periodEnd: week.periodEnd,
      level: "Moderate to Hard (Banking PO)",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    newTests++;
    console.log(`${id}: published (${questions.length} verified bilingual questions).`);
    await sleep(PAUSE_BETWEEN_TESTS_MS);
  }

  // 3) Light up the "Mock Tests" red dot on Homescreen + queue bilingual push notification.
  if (newTests > 0) {
    try {
      await db.collection("appConfig").doc("main").set(
        { newMocksAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
      console.log("Updated appConfig/main.newMocksAt.");
    } catch (err) {
      console.warn("Could not update appConfig/main.newMocksAt:", err.message);
    }

    if (notify) {
      try {
        await db.collection("notifications").add({
          title: "🧮 New Banking PO Quant Mocks! / नए Banking PO Quant मॉक्स!",
          body: "New Moderate-to-Hard Speed Maths, Arithmetic (Variable-Based), Advanced Maths & Graph DI mocks (15 Qs each) are live in Mock Tests > Banking PO/Clerk > Quant.",
          sent: false,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log("Queued Banking PO Quant push notification.");
      } catch (err) {
        console.warn("Notification skipped:", err.message);
      }
    }
  }

  console.log(`Done: ${newTests} new Quant mock(s) published for ${week.weekKey}, ${failed} failed.`);
  return failed;
}

module.exports = { docIdFor, formatTestTitle, ensureBankingFolder, purgeOldQuantMocks, loadTestSettings, parseOptionalNumber, DEFAULT_SETTINGS };

if (require.main === module) {
  main()
    .then((failed) => process.exit(failed > 0 ? 1 : 0))
    .catch((err) => {
      console.error("fetch-banking-quant-mocks failed:", err.message);
      process.exit(1);
    });
}

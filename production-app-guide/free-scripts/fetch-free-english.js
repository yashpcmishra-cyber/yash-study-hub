/**
 * WEEKLY English set for the "English" folder of Free MCQs (free: GitHub Actions + free Gemini key).
 *
 * Every Monday (8:00 AM IST) it builds ONE set of 25 Banking PO / Clerk English MCQs for the week that starts
 * that day (ISO week, Monday to Sunday). The questions mix EASY (Clerk), MODERATE (PO Prelims) and HARD
 * (PO Mains) level. How they are written and checked lives in free-mcq-english.js.
 *
 * Firestore output (read by the app, same collections as the monthly job):
 *   freeMcqSets/english_english_{yyyy-Www}
 *       { examId:"english", subjectId:"english", monthKey, weekKey, periodStart, periodEnd, count, source,
 *         level, license, licenseUrl, sources[], questions[], createdAt }
 *   freeMcqIndex/current   (shared with the monthly job; weekly sets carry weekKey + periodStart)
 *
 * RETENTION
 *   - Firestore : an English set is deleted once its week started more than 2 months ago (ENGLISH_KEEP_MONTHS).
 *   - The app   : a set a student has opened stays on that phone for 3 months, even after Firestore deleted it.
 *
 * Re-runs are cheap: a week that already has its set is skipped (FORCE=true rebuilds it).
 *
 * Env: FIREBASE_SERVICE_ACCOUNT, GEMINI_API_KEY   (GitHub secrets)
 *      WEEK=yyyy-Www | yyyy-MM-dd   optional, default = the current week (IST); any date inside a week works
 *      FORCE=true                   optional, rebuild the set even if it exists
 *      FREE_MCQ_NOTIFY=false        optional, skip the "New English MCQs" push
 *      GEMINI_GAP_MS=3000           optional, pause before every Gemini call (free-tier rate limit)
 */
const english = require("./free-mcq-english.js");
const core = require("./fetch-free-mcqs.js");

const {
  EXAMS,
  ENGLISH_EXAM,
  ENGLISH_KEEP_MONTHS,
  STATIC_LICENSE,
  MIN_QUESTIONS,
  callGemini,
  applyExamsFromFirestore,
  ensureEnglishFolder,
  writeIndex,
  istDateStr,
  currentMonthIST,
  shiftMonth,
  dateMinusMonths,
  setId,
} = core;

const DAY_MS = 86400000;
const ENGLISH_SOURCE = "Banking PO/Clerk pattern, AI-checked";
const ENGLISH_LEVEL_LABEL = "Easy + moderate + hard mix";
const PREVIOUS_WEEKS = 4; // question texts and passages of the last 4 weeks are never repeated
const pad2 = (n) => String(n).padStart(2, "0");

// ------------------------------------------------------------------ weeks (ISO, Monday to Sunday)

const utcDay = (dateStr) => {
  const [y, m, d] = dateStr.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
};
const dayStr = (ms) => new Date(ms).toISOString().slice(0, 10);

/** The week that contains `dateStr` (yyyy-MM-dd): { weekKey: "2026-W44", periodStart: Monday, periodEnd: Sunday }. */
function weekInfo(dateStr) {
  const t = utcDay(dateStr);
  const mondayMs = t - ((new Date(t).getUTCDay() + 6) % 7) * DAY_MS;
  const thursday = new Date(mondayMs + 3 * DAY_MS); // the ISO year/week belong to the Thursday
  const isoYear = thursday.getUTCFullYear();
  const jan4 = Date.UTC(isoYear, 0, 4);
  const week1Monday = jan4 - ((new Date(jan4).getUTCDay() + 6) % 7) * DAY_MS;
  const week = Math.round((mondayMs - week1Monday) / (7 * DAY_MS)) + 1;
  return { weekKey: `${isoYear}-W${pad2(week)}`, periodStart: dayStr(mondayMs), periodEnd: dayStr(mondayMs + 6 * DAY_MS) };
}

/** The week `delta` weeks away from `info` (negative = earlier). */
function shiftWeek(info, delta) {
  return weekInfo(dayStr(utcDay(info.periodStart) + delta * 7 * DAY_MS));
}

/** Env WEEK -> week. Accepts "2026-W44" or any date "2026-10-28". Empty = this week in India. */
function resolveWeek(input) {
  const v = String(input || "").trim();
  if (!v) return weekInfo(istDateStr(0));
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return weekInfo(v);
  const m = /^(\d{4})-W(\d{2})$/i.exec(v);
  if (!m) throw new Error(`WEEK must look like 2026-W44 or 2026-10-28, got "${v}"`);
  const year = Number(m[1]);
  const week = Number(m[2]);
  if (week < 1 || week > 53) throw new Error(`WEEK number must be 1-53, got "${v}"`);
  const jan4 = Date.UTC(year, 0, 4);
  const week1Monday = jan4 - ((new Date(jan4).getUTCDay() + 6) % 7) * DAY_MS;
  return weekInfo(dayStr(week1Monday + (week - 1) * 7 * DAY_MS)); // weekInfo() also fixes a non-existent week 53
}

// ------------------------------------------------------------------ Firestore helpers

/** Deletes English sets whose week started more than ENGLISH_KEEP_MONTHS months ago, and old monthly English sets. */
async function purgeOldEnglishSets(db) {
  const cutoff = dateMinusMonths(istDateStr(0), ENGLISH_KEEP_MONTHS);
  const snap = await db.collection("freeMcqSets").where("examId", "==", ENGLISH_EXAM.id).get();
  const stale = snap.docs.filter((d) => {
    const start = String((d.data() || {}).periodStart || "");
    return !start || start < cutoff; // no periodStart = an old monthly English set
  });
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    stale.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  if (stale.length) console.log(`Deleted ${stale.length} English set(s) older than ${cutoff}: ${stale.map((d) => d.id).join(", ")}`);
  return new Set(stale.map((d) => d.id));
}

/** Question texts and passage openings of the last weeks (up to 4 reads). */
async function loadPreviousWeeks(db, week) {
  const ids = [];
  for (let k = 1; k <= PREVIOUS_WEEKS; k++) ids.push(setId(ENGLISH_EXAM.id, ENGLISH_EXAM.id, shiftWeek(week, -k).weekKey));
  const snaps = await db.getAll(...ids.map((id) => db.collection("freeMcqSets").doc(id)));
  const docs = snaps.filter((s) => s.exists).map((s) => s.data());
  return english.previousFromSets(docs).slice(0, 80);
}

// ------------------------------------------------------------------ main

async function main() {
  const week = resolveWeek(process.env.WEEK);
  const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  const admin = require("firebase-admin");
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();
  await applyExamsFromFirestore(db);
  ensureEnglishFolder();

  const force = process.env.FORCE === "true";
  const notify = process.env.FREE_MCQ_NOTIFY !== "false";
  const id = setId(ENGLISH_EXAM.id, ENGLISH_EXAM.id, week.weekKey);
  const monthOfWeek = week.periodStart.slice(0, 7);
  const meta = {
    id,
    examId: ENGLISH_EXAM.id,
    subjectId: ENGLISH_EXAM.id,
    monthKey: monthOfWeek,
    weekKey: week.weekKey,
    periodStart: week.periodStart,
    count: 0,
    source: ENGLISH_SOURCE,
  };
  console.log(`Building the English set for ${week.weekKey} (${week.periodStart} to ${week.periodEnd}).`);

  // 1) Retention: remove English sets older than 2 months (and old monthly English sets).
  const purged = await purgeOldEnglishSets(db);

  // 2) Is this week's set already there?
  const built = [];
  let newSets = 0;
  let failed = 0;
  const existing = force ? null : await db.collection("freeMcqSets").doc(id).get();
  if (existing && existing.exists) {
    built.push({ ...meta, count: Number(existing.data().count) || 0 });
    console.log(`${id}: already there, skipped.`);
  } else {
    // 3) Build it: 25 questions, written and checked by free-mcq-english.js.
    console.log(`${id}: generating...`);
    const previous = await loadPreviousWeeks(db, week);
    const questions = await english.generateEnglishSet({ periodKey: week.weekKey, previous, key: GEMINI_KEY, callGemini });
    if (questions.length < MIN_QUESTIONS) {
      failed++;
      console.error(`${id}: only ${questions.length} verified question(s) - not published.`);
    } else {
      await db.collection("freeMcqSets").doc(id).set({
        examId: ENGLISH_EXAM.id,
        subjectId: ENGLISH_EXAM.id,
        monthKey: monthOfWeek,
        weekKey: week.weekKey,
        periodStart: week.periodStart,
        periodEnd: week.periodEnd,
        count: questions.length,
        source: ENGLISH_SOURCE,
        level: ENGLISH_LEVEL_LABEL,
        license: STATIC_LICENSE,
        licenseUrl: "",
        sources: [],
        questions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      built.push({ ...meta, count: questions.length });
      newSets++;
    }
  }

  // 4) Index (shared with the monthly job). Also applies the retention rules to the index.
  await writeIndex(db, admin, shiftMonth(currentMonthIST(), -1), built, purged);

  // 5) One push when a new week is published.
  if (newSets > 0 && notify) {
    try {
      await db.collection("notifications").add({
        title: "\u{1F4DD} New English MCQs! / नए English MCQs!",
        body: "This week's 25 Banking PO / Clerk English MCQs are in Free MCQs. / इस हफ़्ते के 25 English MCQs फ़्री MCQs में हैं।",
        sent: false,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("Queued the 'New English MCQs' notification.");
    } catch (err) {
      console.warn("Notification skipped:", err.message);
    }
  }

  console.log(`Done: ${newSets} new set(s), ${failed} failed. EXAMS in the index: ${EXAMS.map((e) => e.id).join(", ")}.`);
  return failed;
}

module.exports = { weekInfo, shiftWeek, resolveWeek, purgeOldEnglishSets, loadPreviousWeeks, ENGLISH_SOURCE };

if (require.main === module) {
  main()
    .then((failed) => process.exit(failed > 0 ? 1 : 0))
    .catch((err) => {
      console.error("fetch-free-english failed:", err.message);
      process.exit(1);
    });
}

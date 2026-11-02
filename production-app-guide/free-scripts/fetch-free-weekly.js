/**
 * WEEKLY sets for every Free MCQs folder except English (free: GitHub Actions + free Gemini key).
 *
 * Every Monday (9:00 AM IST) it builds ONE set of 25 MCQs per exam x subject (for example SSC / UPSSSC / Railway
 * x Static GK / General Science / General Studies, and any exam folder you add in the Admin Panel) for the week
 * that starts that day (ISO week, Monday to Sunday). This is the same weekly rhythm as the English folder, which is
 * built by fetch-free-english.js. The questions, the accuracy checks (fact-check, blind re-solve, Hindi-English
 * match) and the Gemini calls are the ones from fetch-free-mcqs.js.
 *
 * Firestore output (read by the app):
 *   freeMcqSets/{examId}_{subjectId}_{yyyy-Www}
 *       { examId, subjectId, monthKey, weekKey, periodStart, periodEnd, count, source, license, licenseUrl,
 *         sources[], questions[], createdAt }
 *   freeMcqIndex/current   (shared with the English job; weekly sets carry weekKey + periodStart)
 *
 * RETENTION (automatic, every run)
 *   - Firestore : a set is deleted once its week started more than 2 months ago (KEEP_MONTHS), including old
 *                 monthly sets. Orphan documents that are not in the index are removed too.
 *   - The app   : sets older than 2 months are removed from the student's phone (free_mcq_service.dart).
 *
 * Re-runs are cheap: a week that already has its set is skipped (FORCE=true rebuilds it).
 *
 * Env: FIREBASE_SERVICE_ACCOUNT, GEMINI_API_KEY   (GitHub secrets)
 *      WEEK=yyyy-Www | yyyy-MM-dd   optional, default = the current week (IST); any date inside a week works
 *      FORCE=true                   optional, rebuild sets that already exist
 *      FREE_MCQ_NOTIFY=false        optional, skip the "New weekly MCQs" push
 *      GEMINI_GAP_MS=3000           optional, pause before every Gemini call (free-tier rate limit)
 */
const core = require("./fetch-free-mcqs.js");
const topics = require("./free-mcq-topics.js");
const { weekInfo, shiftWeek, resolveWeek } = require("./fetch-free-english.js");

const {
  EXAMS,
  ENGLISH_EXAM,
  KEEP_MONTHS,
  STATIC_LICENSE,
  PAUSE_BETWEEN_SETS_MS,
  MIN_QUESTIONS,
  applyExamsFromFirestore,
  ensureEnglishFolder,
  subjectsFor,
  generateSet,
  writeIndex,
  purgeLegacyLicensedSets,
  purgeRemovedExamSets,
  purgeRemovedSubjectSets,
  istDateStr,
  dateMinusMonths,
  oneLine,
  setId,
  sleep,
} = core;

const PREVIOUS_WEEKS = 4; // questions of the last 4 weeks are never repeated
const MAX_PREVIOUS_TEXTS = 40; // shown to Gemini as "do not repeat" (keeps the prompt small)
const SOURCE_LABEL = "Syllabus-based, AI-checked";
const SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "week 45: 2 Nov to 8 Nov 2026" - the week line of the Gemini prompt. */
function weekLabel(week) {
  const fmt = (d) => {
    const [y, m, day] = d.split("-").map(Number);
    return `${day} ${SHORT_MONTHS[m - 1]} ${y}`;
  };
  const n = Number(/W(\d+)$/.exec(week.weekKey)[1]);
  return `week ${n}: ${fmt(week.periodStart)} to ${fmt(week.periodEnd)}`;
}

// ------------------------------------------------------------------ retention

/**
 * Deletes every set (any folder) whose period started before the 2-month cutoff, whether or not the index lists it.
 * Weekly sets are judged by periodStart, old monthly sets by the first day of their month.
 * Returns the set of deleted ids, so writeIndex() leaves them out of the index.
 */
async function purgeOldSets(db) {
  const cutoff = dateMinusMonths(istDateStr(0), KEEP_MONTHS);
  const cutoffMonth = cutoff.slice(0, 7);
  // Only a month key at or before the cutoff month can be old; the exact day is checked below.
  const snap = await db.collection("freeMcqSets").where("monthKey", "<=", cutoffMonth).select("periodStart", "monthKey").get();
  const stale = snap.docs.filter((d) => {
    const data = d.data() || {};
    const start = String(data.periodStart || `${data.monthKey}-01`);
    return start < cutoff;
  });
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    stale.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  if (stale.length) console.log(`Deleted ${stale.length} set(s) older than ${cutoff}: ${stale.map((d) => d.id).join(", ")}`);
  return new Set(stale.map((d) => d.id));
}

// ------------------------------------------------------------------ previous questions

/** Question texts of the last weeks for every set to build (one batched read). Map: setId -> [text]. */
async function loadPreviousByPair(db, pairs, week) {
  const wanted = []; // [{pairId, docId}]
  for (const { exam, subject } of pairs) {
    for (let k = 1; k <= PREVIOUS_WEEKS; k++) {
      wanted.push({ pairId: setId(exam.id, subject.id, week.weekKey), docId: setId(exam.id, subject.id, shiftWeek(week, -k).weekKey) });
    }
  }
  const out = new Map();
  if (!wanted.length) return out;
  const snaps = await db.getAll(...wanted.map((w) => db.collection("freeMcqSets").doc(w.docId)));
  snaps.forEach((s, i) => {
    if (!s.exists) return;
    const list = out.get(wanted[i].pairId) || [];
    for (const q of s.data().questions || []) {
      const t = oneLine(q && q.text);
      if (t) list.push(t);
    }
    out.set(wanted[i].pairId, list);
  });
  return out;
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
  const monthOfWeek = week.periodStart.slice(0, 7);
  const label = weekLabel(week);
  console.log(`Building the weekly Free MCQs for ${week.weekKey} (${week.periodStart} to ${week.periodEnd}).`);

  // 0) Retention: nothing older than 2 months stays in the database. Sets built from CC-licensed text,
  //    of removed exams or of removed subjects go too.
  const purged = await purgeOldSets(db);
  for (const id of await purgeLegacyLicensedSets(db)) purged.add(id);
  for (const id of await purgeRemovedExamSets(db)) purged.add(id);
  for (const id of await purgeRemovedSubjectSets(db)) purged.add(id);

  // 1) Every exam x subject of this week (English has its own weekly job).
  const pairs = [];
  for (const exam of EXAMS) {
    if (exam.id === ENGLISH_EXAM.id) continue;
    for (const subject of subjectsFor(exam)) pairs.push({ exam, subject, id: setId(exam.id, subject.id, week.weekKey) });
  }

  // 2) Which of them already exist? One batched read, skipped when FORCE=true.
  const existing = new Map(); // id -> count
  if (!force && pairs.length) {
    const snaps = await db.getAll(...pairs.map((p) => db.collection("freeMcqSets").doc(p.id)));
    for (const s of snaps) if (s.exists) existing.set(s.id, Number(s.data().count) || 0);
  }
  const todo = pairs.filter((p) => !existing.has(p.id));
  const previousByPair = todo.length ? await loadPreviousByPair(db, todo, week) : new Map();

  // 3) Build every missing set.
  const built = [];
  let newSets = 0;
  let failed = 0;
  for (const { exam, subject, id } of pairs) {
    const meta = { id, examId: exam.id, subjectId: subject.id, monthKey: monthOfWeek, weekKey: week.weekKey, periodStart: week.periodStart, count: 0, source: SOURCE_LABEL };
    if (existing.has(id)) {
      built.push({ ...meta, count: existing.get(id) });
      console.log(`${id}: already there, skipped.`);
      continue;
    }

    const topicList = topics.pickTopics({ subjectId: subject.id, examId: exam.id, periodKey: week.weekKey });
    if (topicList.length < 5) {
      console.warn(`${id}: no topics configured for this subject.`);
      failed++;
      continue;
    }

    console.log(`${id}: generating...`);
    const previous = (previousByPair.get(id) || []).slice(0, MAX_PREVIOUS_TEXTS);
    const questions = await generateSet({ exam, subject, monthKey: monthOfWeek, periodLabel: label, ctx: { topicList }, previous, key: GEMINI_KEY });
    if (questions.length < MIN_QUESTIONS) {
      failed++;
      console.error(`${id}: only ${questions.length} verified question(s) - not published.`);
      continue;
    }

    await db.collection("freeMcqSets").doc(id).set({
      examId: exam.id,
      subjectId: subject.id,
      monthKey: monthOfWeek,
      weekKey: week.weekKey,
      periodStart: week.periodStart,
      periodEnd: week.periodEnd,
      count: questions.length,
      source: SOURCE_LABEL,
      license: STATIC_LICENSE,
      licenseUrl: "",
      sources: [],
      questions,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    built.push({ ...meta, count: questions.length });
    newSets++;
    try {
      await writeIndex(db, admin, monthOfWeek, built, purged);
    } catch (err) {
      console.warn("Index update skipped for now:", err.message);
    }
    await sleep(PAUSE_BETWEEN_SETS_MS);
  }

  // 4) Final index rebuild (also done after every new set, so a timeout cannot leave it stale).
  await writeIndex(db, admin, monthOfWeek, built, purged);

  // 5) One push when something new was published.
  if (newSets > 0 && notify) {
    try {
      await db.collection("notifications").add({
        title: "\u{1F4DD} New weekly MCQs! / नए साप्ताहिक MCQs!",
        body: "This week's Static GK, General Science and General Studies MCQs are in Free MCQs. / इस हफ़्ते के Static GK, General Science और General Studies MCQs फ़्री MCQs में हैं।",
        sent: false,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("Queued the 'New weekly MCQs' notification.");
    } catch (err) {
      console.warn("Notification skipped:", err.message);
    }
  }

  console.log(`Done: ${newSets} new set(s), ${built.length} set(s) for ${week.weekKey}, ${failed} failed.`);
  return failed;
}

module.exports = { weekLabel, purgeOldSets, loadPreviousByPair, weekInfo };

if (require.main === module) {
  main()
    .then((failed) => process.exit(failed > 0 ? 1 : 0))
    .catch((err) => {
      console.error("fetch-free-weekly failed:", err.message);
      process.exit(1);
    });
}

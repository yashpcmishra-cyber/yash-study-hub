/**
 * Monthly Free MCQs (free: GitHub Actions + free Gemini key, no Blaze needed).
 *
 * For every exam x subject it builds ONE practice set of 20 MCQs for the previous
 * calendar month (or the month in env MONTH=yyyy-MM).
 *
 * SOURCES (all free to reuse, see free-mcq-sources.js for the licence notes):
 *   - Current Affairs  : PIB lines archived by fetch-daily-ca.js in caArchive/{yyyy-MM-dd}
 *   - Static GK / General Science / General Studies : Wikipedia articles (CC BY-SA 4.0),
 *     picked from SSC / Railway / UPSSSC syllabus pools. NCERT is deliberately NOT used (its terms forbid it).
 *
 * HOW A SET IS MADE (so facts come from the source text, not from the AI's memory):
 *   1) Gemini writes 24 questions ONLY from the numbered source texts, in its own words.
 *   2) A second Gemini pass checks every question against the same text and removes any whose
 *      answer is not clearly supported, or that could have two correct options.
 *   3) The first 20 surviving questions are saved. If the check cannot run, the set is NOT
 *      published (the retry run on the 3rd of the month tries again).
 *
 * Firestore output (read by the app):
 *   freeMcqSets/{examId}_{subjectId}_{yyyy-MM}
 *       { examId, subjectId, monthKey, count, source, license, licenseUrl, sources[{title,url}], questions[], createdAt }
 *   freeMcqIndex/current
 *       { exams[], subjects[], sets[ {id, examId, subjectId, monthKey, count, source} ], updatedAt }
 *
 * Storage: only the last KEEP_MONTHS months are kept; caArchive older than ARCHIVE_DAYS is deleted.
 * Re-runs are cheap: a set that already exists is skipped (FORCE=true rebuilds all).
 *
 * Env: FIREBASE_SERVICE_ACCOUNT, GEMINI_API_KEY   (GitHub secrets)
 *      MONTH=yyyy-MM          optional, default = previous month (IST)
 *      FORCE=true             optional, rebuild sets that already exist
 *      DRY_RUN=true           optional, only checks the Wikipedia source pools (no Gemini, no Firebase)
 *      FREE_MCQ_NOTIFY=false  optional, skip the "Free MCQs ready" push
 */
const sources = require("./free-mcq-sources.js");

const QUESTIONS_PER_SET = 20; // saved per set
const QUESTIONS_ASKED = 24; // asked from Gemini, so the check can remove a few and 20 still remain
const MIN_QUESTIONS = 15; // fewer verified questions than this = set not published
const MIN_CA_LINES = 15; // PIB lines needed before the Current Affairs set is built
const MAX_CA_LINES = 60; // keeps the prompt small
const KEEP_MONTHS = 3; // this month + 2 earlier months stay in Firestore
const ARCHIVE_DAYS = 40; // caArchive docs older than this are deleted
const PREV_QUESTIONS_IN_PROMPT = 30; // earlier questions shown to Gemini as "do not repeat"
const PAUSE_BETWEEN_SETS_MS = 4000; // gentle on Gemini's free-tier rate limit

const PIB_SOURCE = { title: "PIB - Press Information Bureau, Government of India", url: "https://pib.gov.in/" };

const MODERATE_LEVEL = "Moderate competitive-exam level (SSC / Railway / UPSSSC): clear, factual, not tricky.";

// Exam folders. `focus` is the exam-wise emphasis (2026) given to Gemini.
const EXAMS = [
  { id: "ssc", name: "SSC (CGL / CHSL / MTS)", emoji: "🧾", level: MODERATE_LEVEL, focus: "SSC General Awareness: Indian history, geography, polity, economy, general science, static GK and current affairs of national importance. Quick factual questions." },
  { id: "railway", name: "Railway (RRB NTPC / Group D)", emoji: "🚆", level: MODERATE_LEVEL, focus: "Railway General Awareness and General Science at school level: science, history, geography, polity, economy, sports, awards and current affairs." },
  { id: "up_state", name: "UPSSSC (PET / Junior Assistant etc.)", emoji: "🏛️", level: MODERATE_LEVEL, focus: "UPSSSC General Awareness with special reference to Uttar Pradesh: UP history, geography, culture, districts, government schemes and economy, plus Indian history, geography, polity, general science and current affairs. Clear factual questions, not tricky." },
];

const SUBJECTS = [
  { id: "ca", name: "Current Affairs", emoji: "📰", syllabus: "Current events of national and international importance" },
  { id: "gk", name: "Static GK", emoji: "🗿", syllabus: "History of India and the national movement; India and world geography; art, culture, awards and sports; Uttar Pradesh special (for UP exams)" },
  { id: "science", name: "General Science", emoji: "🔬", syllabus: "Physics, chemistry and biology as met in everyday life; human health and diseases; space and everyday technology" },
  { id: "gs", name: "General Studies", emoji: "🧭", syllabus: "Indian polity and governance; economic and social development; environment, ecology, biodiversity and climate change; international organisations; Uttar Pradesh special (for UP exams)" },
];

const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const GEMINI_MODELS_DEFAULT = ["gemini-3.5-flash", "gemini-flash-latest", "gemini-3.1-flash-lite", "gemini-flash-lite-latest"];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const pad2 = (n) => String(n).padStart(2, "0");
const oneLine = (s) => String(s == null ? "" : s).replace(/\s+/g, " ").trim();
const hasDevanagari = (s) => /[\u0900-\u097F]/.test(s);

// ------------------------------------------------------------------ dates (IST)

/** Date string yyyy-MM-dd for `offsetDays` days ago, in India time. */
const istDateStr = (offsetDays = 0) =>
  new Date(Date.now() + 5.5 * 3600 * 1000 - offsetDays * 86400000).toISOString().slice(0, 10);

function currentMonthIST() {
  return istDateStr(0).slice(0, 7);
}

/** Month key moved by `delta` months (negative = earlier). */
function shiftMonth(key, delta) {
  const [y, m] = key.split("-").map(Number);
  const d = new Date(Date.UTC(y, m - 1 + delta, 1));
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}`;
}

/** First day (inclusive) and first day of the next month (exclusive), yyyy-MM-dd. */
function monthRange(key) {
  return { start: `${key}-01`, end: `${shiftMonth(key, 1)}-01` };
}

function monthLabel(key) {
  const [y, m] = key.split("-").map(Number);
  return `${MONTH_NAMES[m - 1]} ${y}`;
}

const setId = (examId, subjectId, monthKey) => `${examId}_${subjectId}_${monthKey}`;

// ------------------------------------------------------------------ prompts

/** Output rules shared by every set. */
function outputRules(n) {
  return `OUTPUT RULES:
- Write exactly ${n} multiple-choice questions.
- Exactly 4 options. Exactly ONE option is correct. The 3 wrong options must be plausible but clearly wrong, and must NOT also be true.
- Mix question types (who / what / which / where / how many). Do not ask two questions about the same fact. Spread the questions over different sources.
- Each question must make sense on its own (name the subject in the question). Never write "according to the text" or "as per the source".
- Write the questions and explanations in YOUR OWN WORDS. Never copy a sentence from the sources.
- "text": the question in English (max 35 words). "textHi": the same question in clear Hindi (Devanagari). Keep proper names and numbers as they are.
- "options": 4 short English options. "optionsHi": the same 4 options in the same order, in Hindi (Devanagari).
- "correctIndex": number 0-3, the position of the correct option.
- "explanation": one English sentence (max 30 words) stating the fact. "explanationHi": the same in Hindi (Devanagari).
- "src": the number of the SOURCE the question comes from (for example 3 for [S3]).
- Return ONLY a JSON array of ${n} objects with keys: text, textHi, options, optionsHi, correctIndex, explanation, explanationHi, src. No markdown.`;
}

function sourceBlock(blocks) {
  return blocks.map((b, i) => `[S${i + 1}] ${b.label}\n${b.text}`).join("\n\n");
}

/** Earlier questions (from the last 2 months) that must not come back. */
function avoidBlock(previous) {
  if (!previous.length) return "";
  return `\n\nDO NOT repeat or closely paraphrase these earlier questions:\n${previous.map((t) => `- ${t}`).join("\n")}`;
}

/** The generation prompt. `blocks` = [{label, text}] (Wikipedia articles, or PIB lines for Current Affairs). */
function buildPrompt({ exam, subject, monthKey, blocks, previous = [], n = QUESTIONS_ASKED }) {
  const isCa = subject.id === "ca";
  return `You write a monthly practice set of multiple-choice questions for Indian competitive-exam students.

EXAM: ${exam.name}
EXAM FOCUS (2026 syllabus): ${exam.focus}
SUBJECT: ${subject.name} (${subject.syllabus})
MONTH: ${monthLabel(monthKey)}
LEVEL: ${exam.level}

${isCa ? "The sources below are verified current-affairs facts from PIB (Government of India)." : "The sources below are encyclopedia articles."}
Write the questions ONLY from the SOURCES.
- Every question must be answerable from one source. Never add outside knowledge, guesses, or dates/numbers that are not in the source.
- Prefer facts that matter for the exam. Skip trivia, long lists and anything that looks outdated or disputed.
- If a source does not give enough clear facts, ask fewer questions about it.

${outputRules(n)}${avoidBlock(previous)}

SOURCES:
${sourceBlock(blocks)}`;
}

/** The checking prompt: a second pass over the same sources. */
function buildVerifyPrompt({ blocks, questions }) {
  const letters = ["A", "B", "C", "D"];
  const list = questions
    .map((q, i) => {
      const opts = q.options.map((o, k) => `${letters[k]}) ${o}`).join("  ");
      return `Q${i + 1} [S${q.src}] ${q.text}\n   ${opts}\n   Marked correct: ${letters[q.correctIndex]}`;
    })
    .join("\n");
  return `You are a strict fact-checker for exam questions. Check each question against its SOURCE text only.

REMOVE a question if ANY of these is true:
- the marked correct option is not clearly stated or directly implied by the cited source;
- another option is also correct or arguably correct;
- the question is ambiguous, depends on information the source does not give, or may be outdated;
- the question is answered by something the source says only vaguely.
KEEP the question otherwise.

Return ONLY a JSON object like {"remove":[3,7]} listing the question numbers to remove ({"remove":[]} if none). No markdown.

SOURCES:
${sourceBlock(blocks)}

QUESTIONS:
${list}`;
}

// ------------------------------------------------------------------ Gemini

async function callGemini(prompt, key, temperature) {
  const models = [];
  if (process.env.GEMINI_MODEL) models.push(process.env.GEMINI_MODEL);
  models.push(...GEMINI_MODELS_DEFAULT);
  let lastErr = new Error("No Gemini model worked");
  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    for (let attempt = 0; attempt < 2; attempt++) {
      let res;
      try {
        res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": key },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: { temperature, responseMimeType: "application/json", maxOutputTokens: 20000 },
          }),
        });
      } catch (err) {
        lastErr = err;
        await sleep(5000);
        continue;
      }
      if (res.ok) {
        const json = await res.json();
        const parts = (json.candidates && json.candidates[0] && json.candidates[0].content && json.candidates[0].content.parts) || [];
        const text = parts.map((p) => p.text || "").join("");
        if (text.trim()) return text;
        lastErr = new Error(`${model}: empty answer`);
        break;
      }
      const body = (await res.text()).slice(0, 200);
      lastErr = new Error(`${model} HTTP ${res.status}: ${body}`);
      if (res.status === 429 || res.status >= 500) {
        await sleep(20000 * (attempt + 1));
        continue;
      }
      break; // 400/403/404: try the next model name
    }
  }
  throw lastErr;
}

// ------------------------------------------------------------ validation

function stripFences(text) {
  return String(text).trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
}

function parseAnswer(text) {
  const t = stripFences(text);
  const a = t.indexOf("[");
  const b = t.lastIndexOf("]");
  if (a < 0 || b <= a) throw new Error("Gemini answer is not a JSON array");
  const arr = JSON.parse(t.slice(a, b + 1));
  return Array.isArray(arr) ? arr : [];
}

/** The checker's answer -> list of 1-based question numbers to remove. Throws if unreadable. */
function parseVerify(text) {
  const t = stripFences(text);
  let value;
  try {
    value = JSON.parse(t);
  } catch (_) {
    const a = t.indexOf("{");
    const b = t.lastIndexOf("}");
    if (a < 0 || b <= a) throw new Error("Checker answer is not JSON");
    value = JSON.parse(t.slice(a, b + 1));
  }
  const list = Array.isArray(value) ? value : value && Array.isArray(value.remove) ? value.remove : null;
  if (!list) throw new Error("Checker answer has no 'remove' list");
  return list.map(Number).filter((n) => Number.isInteger(n) && n >= 1);
}

function shuffleInPlace(arr, rnd) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** A clean question object (with `src` for the checker), or null if anything is wrong with it. */
function cleanQuestion(raw, { rnd = Math.random, maxSrc = 0 } = {}) {
  if (!raw || typeof raw !== "object") return null;
  const text = oneLine(raw.text);
  const textHi = oneLine(raw.textHi);
  const explanation = oneLine(raw.explanation);
  const explanationHi = oneLine(raw.explanationHi);
  if (!Array.isArray(raw.options) || !Array.isArray(raw.optionsHi)) return null;
  const options = raw.options.map(oneLine);
  const optionsHi = raw.optionsHi.map(oneLine);
  const ci = Number(raw.correctIndex);
  const src = Number(raw.src);

  if (text.length < 10 || text.length > 320 || hasDevanagari(text)) return null;
  if (textHi.length < 8 || textHi.length > 450 || !hasDevanagari(textHi)) return null;
  if (explanation.length < 5 || explanation.length > 400 || hasDevanagari(explanation)) return null;
  if (explanationHi.length < 5 || explanationHi.length > 550 || !hasDevanagari(explanationHi)) return null;
  if (options.length !== 4 || optionsHi.length !== 4) return null;
  if (options.some((o) => o.length < 1 || o.length > 120)) return null;
  if (optionsHi.some((o) => o.length < 1 || o.length > 160)) return null;
  if (new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  if (!Number.isInteger(ci) || ci < 0 || ci > 3) return null;
  if (maxSrc > 0 && (!Number.isInteger(src) || src < 1 || src > maxSrc)) return null; // must point at a real source

  // AI often puts the right answer in the same position, so shuffle (Hindi options follow the same order).
  const order = shuffleInPlace([0, 1, 2, 3], rnd);
  return {
    text,
    textHi,
    options: order.map((i) => options[i]),
    optionsHi: order.map((i) => optionsHi[i]),
    correctIndex: order.indexOf(ci),
    explanation,
    explanationHi,
    src: Number.isInteger(src) ? src : 0,
  };
}

/** Cleans a list. `exclude` = lowercase question texts that must not appear (earlier months). */
function cleanQuestions(rawList, { exclude = new Set(), rnd = Math.random, want = QUESTIONS_ASKED, maxSrc = 0 } = {}) {
  const out = [];
  const seen = new Set(exclude);
  for (const raw of rawList) {
    const q = cleanQuestion(raw, { rnd, maxSrc });
    if (!q) continue;
    const key = q.text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(q);
    if (out.length >= want) break;
  }
  return out;
}

/** What is saved in Firestore: the question without the internal `src` field. */
function toStored(q) {
  const { src, ...rest } = q; // eslint-disable-line no-unused-vars
  return rest;
}

/** Drops the questions the checker rejected. Out-of-range numbers are ignored. */
function applyVerification(questions, removeNumbers) {
  const drop = new Set(removeNumbers);
  return questions.filter((_, i) => !drop.has(i + 1));
}

// ------------------------------------------------------------ Firestore reads

/** Current Affairs lines archived during `monthKey` (newest first, capped). */
async function loadCaLines(db, admin, monthKey) {
  const { start, end } = monthRange(monthKey);
  const docId = admin.firestore.FieldPath.documentId();
  const snap = await db.collection("caArchive").where(docId, ">=", start).where(docId, "<", end).get();
  const seen = new Set();
  const lines = [];
  for (const doc of snap.docs) {
    const items = Array.isArray(doc.data().items) ? doc.data().items : [];
    for (const it of items) {
      const en = oneLine(it && it.en);
      const id = String((it && it.id) || en);
      if (!en || seen.has(id)) continue;
      seen.add(id);
      lines.push({ id, topic: it.topic, en, sortKey: Number(it.sortKey) || 0 });
    }
  }
  lines.sort((a, b) => b.sortKey - a.sortKey);
  return lines.slice(0, MAX_CA_LINES);
}

/** Question texts of the same exam+subject from the 2 earlier months (2 reads). */
async function loadPreviousTexts(db, examId, subjectId, monthKey) {
  const texts = [];
  for (const back of [1, 2]) {
    const snap = await db.collection("freeMcqSets").doc(setId(examId, subjectId, shiftMonth(monthKey, -back))).get();
    if (!snap.exists) continue;
    for (const q of snap.data().questions || []) {
      const t = oneLine(q && q.text);
      if (t) texts.push(t);
    }
  }
  return texts.slice(0, PREV_QUESTIONS_IN_PROMPT);
}

// ------------------------------------------------------------ generation

/** Writes the questions, then checks them against the same sources. Returns the final (<= 20) list. */
async function generateSet({ exam, subject, monthKey, blocks, previous, key }) {
  const exclude = new Set(previous.map((t) => t.toLowerCase()));
  const prompt = buildPrompt({ exam, subject, monthKey, blocks, previous });
  const temperature = subject.id === "ca" ? 0.2 : 0.3;

  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const cleaned = cleanQuestions(parseAnswer(await callGemini(prompt, key, temperature)), { exclude, maxSrc: blocks.length });
      console.log(`  attempt ${attempt}: ${cleaned.length} well-formed question(s).`);
      if (cleaned.length < MIN_QUESTIONS) continue;

      const verifyPrompt = buildVerifyPrompt({ blocks, questions: cleaned });
      const remove = parseVerify(await callGemini(verifyPrompt, key, 0));
      const verified = applyVerification(cleaned, remove).slice(0, QUESTIONS_PER_SET);
      console.log(`  attempt ${attempt}: checker removed ${cleaned.length - applyVerification(cleaned, remove).length}, ${verified.length} kept.`);
      if (verified.length >= MIN_QUESTIONS) return verified.map(toStored);
    } catch (err) {
      console.warn(`  attempt ${attempt} failed: ${err.message}`);
    }
  }
  return [];
}

// ------------------------------------------------------------ dry run

/** Checks that the Wikipedia pools work. Needs no Gemini key and no Firebase. */
async function dryRun(monthKey) {
  const titles = sources.allPoolTitles();
  console.log(`DRY RUN: checking ${titles.length} Wikipedia article(s) in the source pools...`);
  const missing = [];
  for (const t of titles) {
    const p = await sources.fetchPage(t);
    if (!p) missing.push(t);
  }
  console.log(`Usable: ${titles.length - missing.length} / ${titles.length}.`);
  if (missing.length) console.log(`Missing or too short (skipped automatically, you may fix the title):\n  - ${missing.join("\n  - ")}`);

  let bad = 0;
  for (const exam of EXAMS) {
    for (const subject of SUBJECTS) {
      if (subject.id === "ca") continue;
      const pages = await sources.pickPages({ subjectId: subject.id, examId: exam.id, monthKey });
      const ok = pages.length >= sources.MIN_PAGES;
      if (!ok) bad++;
      console.log(`${ok ? "OK  " : "FAIL"} ${setId(exam.id, subject.id, monthKey)}: ${pages.length} article(s): ${pages.map((p) => p.title).join(" | ")}`);
    }
  }
  return bad;
}

// ------------------------------------------------------------------ main

async function main() {
  const monthKey = (process.env.MONTH || "").trim() || shiftMonth(currentMonthIST(), -1);
  if (!/^\d{4}-\d{2}$/.test(monthKey)) throw new Error(`MONTH must look like 2026-10, got "${monthKey}"`);

  if (process.env.DRY_RUN === "true") return dryRun(monthKey);

  const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  const admin = require("firebase-admin");
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();

  const force = process.env.FORCE === "true";
  const notify = process.env.FREE_MCQ_NOTIFY !== "false";
  console.log(`Building free MCQs for ${monthLabel(monthKey)} (${monthKey}).`);

  // 1) Which sets already exist? One read per set, skipped entirely when FORCE=true.
  const allIds = [];
  for (const exam of EXAMS) for (const subject of SUBJECTS) allIds.push(setId(exam.id, subject.id, monthKey));
  const existing = new Map(); // id -> count
  if (!force) {
    const snaps = await db.getAll(...allIds.map((id) => db.collection("freeMcqSets").doc(id)));
    for (const s of snaps) if (s.exists) existing.set(s.id, Number(s.data().count) || 0);
  }

  // 2) Current Affairs source: the PIB lines archived during this month.
  const caLines = await loadCaLines(db, admin, monthKey);
  console.log(`PIB archive has ${caLines.length} current-affairs line(s) for ${monthKey}.`);

  // 3) Build every missing set.
  const built = [];
  let newSets = 0;
  let failed = 0;
  for (const exam of EXAMS) {
    for (const subject of SUBJECTS) {
      const id = setId(exam.id, subject.id, monthKey);
      const isCa = subject.id === "ca";
      const sourceLabel = isCa ? "PIB archive" : `Wikipedia · ${sources.LICENSE}`;
      const meta = { id, examId: exam.id, subjectId: subject.id, monthKey, count: 0, source: sourceLabel };

      if (existing.has(id)) {
        built.push({ ...meta, count: existing.get(id) });
        console.log(`${id}: already there, skipped.`);
        continue;
      }

      // Source texts for this set.
      let blocks;
      let setSources;
      if (isCa) {
        if (caLines.length < MIN_CA_LINES) {
          console.warn(`${id}: only ${caLines.length} PIB line(s), need ${MIN_CA_LINES}. Skipped for now (next run will retry).`);
          continue;
        }
        blocks = caLines.map((l) => ({ label: `(PIB, ${l.topic || "misc"})`, text: l.en }));
        setSources = [PIB_SOURCE];
      } else {
        const pages = await sources.pickPages({ subjectId: subject.id, examId: exam.id, monthKey });
        if (pages.length < sources.MIN_PAGES) {
          console.warn(`${id}: only ${pages.length} usable article(s), need ${sources.MIN_PAGES}. Skipped for now (next run will retry).`);
          failed++;
          continue;
        }
        blocks = pages.map((p) => ({ label: `${p.title} (Wikipedia)`, text: p.text }));
        setSources = pages.map((p) => ({ title: p.title, url: p.url }));
      }

      console.log(`${id}: generating from ${blocks.length} source(s)...`);
      const previous = await loadPreviousTexts(db, exam.id, subject.id, monthKey);
      const questions = await generateSet({ exam, subject, monthKey, blocks, previous, key: GEMINI_KEY });
      if (questions.length < MIN_QUESTIONS) {
        failed++;
        console.error(`${id}: only ${questions.length} verified question(s) - not published.`);
        continue;
      }
      await db.collection("freeMcqSets").doc(id).set({
        examId: exam.id,
        subjectId: subject.id,
        monthKey,
        count: questions.length,
        source: sourceLabel,
        license: isCa ? "Source: PIB, Government of India" : sources.LICENSE,
        licenseUrl: isCa ? "https://pib.gov.in/" : sources.LICENSE_URL,
        sources: setSources,
        questions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      built.push({ ...meta, count: questions.length });
      newSets++;
      await sleep(PAUSE_BETWEEN_SETS_MS);
    }
  }

  // 4) Rebuild the index (1 read + 1 write). Drop sets older than KEEP_MONTHS.
  const idxRef = db.collection("freeMcqIndex").doc("current");
  const oldSets = ((await idxRef.get()).data() || {}).sets || [];
  const all = new Map();
  for (const s of [...oldSets, ...built]) if (s && s.id) all.set(s.id, s);
  const minKey = shiftMonth(monthKey, -(KEEP_MONTHS - 1));
  const kept = [];
  const dropped = [];
  for (const s of all.values()) (String(s.monthKey) >= minKey ? kept : dropped).push(s);
  if (dropped.length) {
    const batch = db.batch();
    dropped.forEach((s) => batch.delete(db.collection("freeMcqSets").doc(s.id)));
    await batch.commit();
    console.log(`Deleted ${dropped.length} set(s) older than ${minKey}.`);
  }
  kept.sort((a, b) => (a.monthKey === b.monthKey ? String(a.id).localeCompare(String(b.id)) : a.monthKey < b.monthKey ? 1 : -1));
  await idxRef.set({
    exams: EXAMS.map(({ id, name, emoji }) => ({ id, name, emoji })),
    subjects: SUBJECTS.map(({ id, name, emoji }) => ({ id, name, emoji })),
    sets: kept.map(({ id, examId, subjectId, monthKey: mk, count, source }) => ({ id, examId, subjectId, monthKey: mk, count, source })),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 5) Trim the PIB archive (1 query).
  try {
    const cutoff = istDateStr(ARCHIVE_DAYS);
    const snap = await db.collection("caArchive").where(admin.firestore.FieldPath.documentId(), "<", cutoff).limit(400).get();
    if (!snap.empty) {
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      console.log(`Deleted ${snap.size} old PIB archive day(s) (before ${cutoff}).`);
    }
  } catch (err) {
    console.warn("Archive cleanup skipped:", err.message);
  }

  // 6) One push when something new was published.
  if (newSets > 0 && notify) {
    try {
      await db.collection("notifications").add({
        title: "\u{1F4DD} Free MCQs ready! / फ़्री MCQs तैयार हैं!",
        body: `${monthLabel(monthKey)} MCQs are in Free MCQs. / ${monthLabel(monthKey)} के MCQs फ़्री MCQs में हैं।`,
        sent: false,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("Queued the 'Free MCQs ready' notification.");
    } catch (err) {
      console.warn("Notification skipped:", err.message);
    }
  }

  console.log(`Done: ${newSets} new set(s), ${built.length} set(s) in the index, ${failed} failed.`);
  return failed;
}

module.exports = {
  EXAMS,
  SUBJECTS,
  QUESTIONS_PER_SET,
  QUESTIONS_ASKED,
  MIN_QUESTIONS,
  cleanQuestion,
  cleanQuestions,
  parseAnswer,
  parseVerify,
  applyVerification,
  toStored,
  buildPrompt,
  buildVerifyPrompt,
  generateSet,
  shiftMonth,
  monthRange,
  monthLabel,
  setId,
};

if (require.main === module) {
  main()
    .then((failed) => process.exit(failed > 0 ? 1 : 0))
    .catch((err) => {
      console.error("fetch-free-mcqs failed:", err.message);
      process.exit(1);
    });
}

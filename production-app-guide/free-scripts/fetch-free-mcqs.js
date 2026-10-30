/**
 * Monthly Free MCQs (free: GitHub Actions + free Gemini key, no Blaze needed).
 *
 * For every exam x subject it builds ONE practice set of 25 MCQs for the previous
 * calendar month (or the month in env MONTH=yyyy-MM).
 *
 * LICENCE POLICY (no copyleft, no copied text):
 *   - Current Affairs : written ONLY from PIB lines archived by fetch-daily-ca.js (caArchive).
 *     PIB's copyright policy allows free reproduction if the source is acknowledged, so EVERY
 *     Current Affairs question carries "Source: PIB, Government of India" inside its explanation.
 *     That credit travels with the question, also when an admin copies it into a Mock Test.
 *   - Static GK / General Science / General Studies : Gemini writes ORIGINAL questions on our own
 *     syllabus topic list (free-mcq-topics.js). No website or book text is used, so there is
 *     nothing to licence. (Gemini API terms: Google does not claim ownership of the output.)
 *   - No Wikipedia / CC BY-SA content. No NCERT content.
 *   - Any older set that was built from CC-licensed text is deleted automatically (step 0).
 *
 * ACCURACY (static sets have no source text, so they are checked twice):
 *   1) Gemini writes 36 questions (English + Hindi, with explanations) on stable, textbook-level facts only.
 *      A local check rejects a question if a number in English is missing in Hindi.
 *   2) Check A: a fact-checker removes questions that are doubtful, ambiguous or have 2 right options,
 *      or whose explanation does not support the marked answer.
 *   3) Check B: a blind solver answers every question WITHOUT seeing the marked answer.
 *      A question survives only if the solver is sure and picks the same option.
 *   4) Check C: an English-Hindi checker removes questions whose Hindi differs from the English in
 *      meaning, number, name or option order.
 *   5) Survivors are collected over up to 3 rounds until 25 are there. A set with fewer than 25 is NOT
 *      published (the retry run on the 3rd of the month tries again). If a check cannot run, the round is lost.
 *   Current Affairs sets get Check A against the PIB lines, plus Check C.
 *
 * ENGLISH FOLDER (built in, always built, cannot be removed from the app):
 *   One extra folder "English" holds ONE set of 25 English MCQs per month in the Banking PO / Clerk pattern
 *   (Cloze, Reading Comprehension, Error Spotting, Fill in the Blanks, Para Jumbles, Sentence Improvement ...),
 *   moderate to hard, English only (no GK / Science / GS). It lives in free-mcq-english.js and is checked twice
 *   (grammar checker + blind solver). Other exam folders are NOT touched: they still get Static GK, General
 *   Science and General Studies only. Set id: english_english_yyyy-MM.
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
 *      FREE_MCQ_NOTIFY=false  optional, skip the "Free MCQs ready" push
 *      GEMINI_GAP_MS=3000     optional, pause before every Gemini call (free-tier rate limit)
 */
const topics = require("./free-mcq-topics.js");
const english = require("./free-mcq-english.js");

const QUESTIONS_PER_SET = 25; // saved per set
const QUESTIONS_ASKED = 36; // asked from Gemini in round 1, so the checks can remove some and 25 still remain
const MAX_ROUNDS = 3; // write + check rounds per set (later rounds only top up what is missing)
const MIN_QUESTIONS = QUESTIONS_PER_SET; // fewer verified questions than this = set not published
const MIN_CA_LINES = 30; // PIB lines needed before the Current Affairs set is built
const MAX_CA_LINES = 80; // keeps the prompt small
const KEEP_MONTHS = 3; // this month + 2 earlier months stay in Firestore
const ARCHIVE_DAYS = 40; // caArchive docs older than this are deleted
const PREV_QUESTIONS_IN_PROMPT = 30; // earlier questions shown to Gemini as "do not repeat"
const PAUSE_BETWEEN_SETS_MS = 3000;

const PIB_SOURCE = { title: "PIB - Press Information Bureau, Government of India", url: "https://pib.gov.in/" };
const PIB_CREDIT = { en: " (Source: PIB, Government of India)", hi: " (स्रोत: PIB, भारत सरकार)" };
const STATIC_LICENSE = "Original questions";

const MODERATE_LEVEL = "Moderate competitive-exam level (SSC / Railway / UPSSSC): clear, factual, not tricky.";

// Exam folders. `focus` is the exam-wise emphasis (2026) given to Gemini.
const EXAMS = [
  { id: "ssc", name: "SSC (CGL / CHSL / MTS)", emoji: "🧾", level: MODERATE_LEVEL, focus: "SSC General Awareness: Indian history, geography, polity, economy, general science, static GK and current affairs of national importance. Quick factual questions." },
  { id: "upsssc", name: "UPSSSC (PET / Lekhpal / Junior Assistant etc.)", emoji: "🏛️", level: MODERATE_LEVEL, focus: "UPSSSC PET and group C exams: Indian history, culture, geography, polity, economy, general science, current affairs and static GK, with special reference to Uttar Pradesh. Clear factual questions." },
  { id: "railway", name: "Railway (RRB NTPC / Station Master / Group D)", emoji: "🚆", level: MODERATE_LEVEL, focus: "Railway General Awareness and General Science at school level (RRB NTPC including Station Master, and Group D): science, history, geography, polity, economy, sports, awards and current affairs." },
];

// The built-in English folder (Banking PO / Clerk pattern). It has ONE subject: english.
const ENGLISH_LEVEL = "Moderate to hard: IBPS PO / SBI PO (Prelims + Mains) standard, with Clerk-level warm-up items.";
const ENGLISH_EXAM = {
  id: "english",
  name: "English",
  emoji: "\u{1F4D6}",
  level: ENGLISH_LEVEL,
  focus: "Banking PO / Clerk English Language: Reading Comprehension, Cloze Test, Error Spotting, Fill in the Blanks, Para Jumbles, Sentence Improvement, connectors and para completion.",
  subjectIds: ["english"],
};
EXAMS.push({ ...ENGLISH_EXAM });

// Current Affairs is NOT built any more (the monthly quiz was never reliably created), so it is not listed here.
// Its code paths below stay for reference; purgeRemovedSubjectSets() deletes any old "ca" set.
const SUBJECTS = [
  { id: "gk", name: "Static GK", emoji: "🗿", syllabus: "History of India and the national movement; India and world geography; art, culture, awards and sports" },
  { id: "science", name: "General Science", emoji: "🔬", syllabus: "Physics, chemistry and biology as met in everyday life; human health and diseases; space and everyday technology" },
  { id: "gs", name: "General Studies", emoji: "🧭", syllabus: "Indian polity and governance; economic and social development; environment, ecology, biodiversity and climate change; international organisations" },
];

const ENGLISH_SUBJECT = {
  id: "english",
  name: "English",
  emoji: "\u{1F4D6}",
  syllabus: "Banking PO / Clerk English Language: reading comprehension, cloze test, error spotting, fill in the blanks, para jumbles, sentence improvement",
};
// Every subject that can exist. SUBJECTS (GK / Science / GS) stay the default for every normal exam folder.
const ALL_SUBJECTS = [...SUBJECTS, ENGLISH_SUBJECT];

/** The subjects an exam folder gets: its own `subjectIds` (English folder) or the 3 default subjects. */
function subjectsFor(exam) {
  if (Array.isArray(exam.subjectIds) && exam.subjectIds.length) return ALL_SUBJECTS.filter((x) => exam.subjectIds.includes(x.id));
  return SUBJECTS;
}

const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const GEMINI_MODELS_DEFAULT = ["gemini-3.5-flash", "gemini-flash-latest", "gemini-3.1-flash-lite", "gemini-flash-lite-latest"];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const pad2 = (n) => String(n).padStart(2, "0");
const oneLine = (s) => String(s == null ? "" : s).replace(/\s+/g, " ").trim();
const hasDevanagari = (s) => /[\u0900-\u097F]/.test(s);
const geminiGapMs = () => (process.env.GEMINI_GAP_MS !== undefined ? Number(process.env.GEMINI_GAP_MS) || 0 : 3000);

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

/** Output rules shared by every set. `refText` explains the "src" field. */
function outputRules(n, refText) {
  return `OUTPUT RULES:
- Write exactly ${n} multiple-choice questions.
- Exactly 4 options. Exactly ONE option is correct. The 3 wrong options must be plausible but clearly wrong, and must NOT also be true.
- Mix question types (who / what / which / where / how many). Do not ask two questions about the same fact.
- Each question must make sense on its own (name the subject in the question). Never write "according to the text" or "as per the source".
- Write everything in YOUR OWN WORDS. Never copy sentences from any source.
- "text": the question in English (max 35 words). "textHi": the same question in clear, standard exam-paper Hindi (Devanagari). Keep proper names as they are.
- Write every number, year and date as digits (1857, 3, 42, 2026) in BOTH languages, never as words. Write ordinals as words (first, second / पहला, दूसरा).
- The Hindi must mean exactly what the English means: same facts, same numbers, same names. Do not add or drop anything.
- "options": 4 short English options. "optionsHi": the same 4 options in the same order, in Hindi (Devanagari).
- "correctIndex": number 0-3, the position of the correct option.
- "explanation": 1-2 English sentences (max 45 words) that state the fact and say why the correct option is right. It must agree with "correctIndex". "explanationHi": the same in Hindi (Devanagari).
- "src": ${refText}
- Return ONLY a JSON array of ${n} objects with keys: text, textHi, options, optionsHi, correctIndex, explanation, explanationHi, src. No markdown.`;
}

function sourceBlock(blocks) {
  return blocks.map((b, i) => `[S${i + 1}] ${b.label}\n${b.text}`).join("\n\n");
}

function topicBlock(topicList) {
  return topicList.map((t, i) => `[T${i + 1}] ${t}`).join("\n");
}

/** Earlier questions (from the last 2 months) that must not come back. */
function avoidBlock(previous) {
  if (!previous.length) return "";
  return `\n\nDO NOT repeat or closely paraphrase these earlier questions:\n${previous.map((t) => `- ${t}`).join("\n")}`;
}

function header({ exam, subject, monthKey }) {
  return `EXAM: ${exam.name}
EXAM FOCUS (2026 syllabus): ${exam.focus}
SUBJECT: ${subject.name} (${subject.syllabus})
MONTH: ${monthLabel(monthKey)}
LEVEL: ${exam.level}`;
}

/** Current Affairs: questions ONLY from the PIB lines. `blocks` = [{label, text}]. */
function buildCaPrompt({ exam, subject, monthKey, blocks, previous = [], n = QUESTIONS_ASKED }) {
  return `You write a monthly practice set of multiple-choice questions for Indian competitive-exam students.

${header({ exam, subject, monthKey })}

The sources below are verified current-affairs facts from PIB (Government of India).
Write the questions ONLY from the SOURCES.
- Every question must be answerable from one source. Never add outside knowledge, guesses, or dates/numbers that are not in the source.
- Prefer facts that matter for the exam. Skip routine announcements.

${outputRules(n, "the number of the SOURCE the question comes from (for example 3 for [S3]).")}${avoidBlock(previous)}

SOURCES:
${sourceBlock(blocks)}`;
}

/** Static subjects: original questions on stable, textbook-level facts about the listed topics. */
function buildStaticPrompt({ exam, subject, monthKey, topicList, previous = [], n = QUESTIONS_ASKED }) {
  return `You write a monthly practice set of multiple-choice questions for Indian competitive-exam students.

${header({ exam, subject, monthKey })}

Write ORIGINAL questions on the TOPICS below, using standard textbook-level knowledge.

ACCURACY RULES (most important):
- Use only facts that are stable, widely agreed and found in standard school textbooks and standard reference books.
- If you are not 100% sure a fact is correct, do not use it.
- Never ask about things that change or are disputed: current office holders, populations, rankings, records, "latest" or "recent" events, exact figures that differ between sources.
- Avoid "first / largest / only / oldest" claims unless they are universally settled.
- Never invent dates, numbers, names or places.
- Spread the questions over the topics, at most 3 per topic.

${outputRules(n, "the number of the TOPIC the question is about (for example 3 for [T3]).")}${avoidBlock(previous)}

TOPICS:
${topicBlock(topicList)}`;
}

const LETTERS = ["A", "B", "C", "D"];

function questionLines(questions, withAnswer, refPrefix) {
  return questions
    .map((q, i) => {
      const opts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join("  ");
      const ref = refPrefix && q.src ? ` [${refPrefix}${q.src}]` : "";
      const ans = withAnswer ? `\n   Marked correct: ${LETTERS[q.correctIndex]}\n   Explanation: ${q.explanation}` : "";
      return `Q${i + 1}${ref} ${q.text}\n   ${opts}${ans}`;
    })
    .join("\n");
}

/**
 * Check A. Grounded (Current Affairs): against the PIB lines.
 * Not grounded (static): against standard textbook knowledge, strictly.
 */
function buildVerifyPrompt({ blocks, topicList, questions }) {
  if (blocks) {
    return `You are a strict fact-checker for exam questions. Check each question against its SOURCE text only.

REMOVE a question if ANY of these is true:
- the marked correct option is not clearly stated or directly implied by the cited source;
- the explanation says something the source does not say, or does not match the marked correct option;
- another option is also correct or arguably correct;
- the question is ambiguous, depends on information the source does not give, or may be outdated;
- the question is answered by something the source says only vaguely.
KEEP the question otherwise.

Return ONLY a JSON object like {"remove":[3,7]} listing the question numbers to remove ({"remove":[]} if none). No markdown.

SOURCES:
${sourceBlock(blocks)}

QUESTIONS:
${questionLines(questions, true, "S")}`;
  }
  return `You are a strict fact-checker for Indian competitive-exam questions. Judge each question with standard school-textbook knowledge.

REMOVE a question if ANY of these is true:
- you are not fully certain that the marked correct option is right;
- the explanation contains a wrong or doubtful fact, or does not match the marked correct option;
- another option is also correct or arguably correct;
- the question is ambiguous, disputed among historians or scientists, or time-sensitive (it may have changed);
- it depends on a number, ranking or record that differs between sources.
When in doubt, REMOVE. KEEP the question only if you are sure.

Return ONLY a JSON object like {"remove":[3,7]} listing the question numbers to remove ({"remove":[]} if none). No markdown.

TOPICS:
${topicBlock(topicList)}

QUESTIONS:
${questionLines(questions, true, "T")}`;
}

/** Check B (static only): a blind solver answers WITHOUT seeing the marked answer. */
function buildSolvePrompt({ questions }) {
  return `You are an expert on Indian competitive exams. Answer each multiple-choice question using standard school-textbook knowledge.
For each question give the letter of the best option and say whether you are SURE (true) or not sure (false).
Say sure=false if two options could be right, the question is ambiguous, or you are not certain.

Return ONLY a JSON object like {"answers":[{"q":1,"answer":"C","sure":true}]} with one entry per question. No markdown.

QUESTIONS:
${questionLines(questions, false, "")}`;
}

/** Check C (all sets): English and Hindi must say exactly the same thing. */
function buildBilingualPrompt({ questions }) {
  const lines = questions
    .map((q, i) => {
      const en = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join("  ");
      const hi = q.optionsHi.map((o, k) => `${LETTERS[k]}) ${o}`).join("  ");
      return `Q${i + 1}\n   EN: ${q.text}\n   EN options: ${en}\n   EN explanation: ${q.explanation}\n   HI: ${q.textHi}\n   HI options: ${hi}\n   HI explanation: ${q.explanationHi}\n   Marked correct: ${LETTERS[q.correctIndex]}`;
    })
    .join("\n");
  return `You are a strict English-Hindi proofreader for exam questions. Compare the English and Hindi version of each question.

REMOVE a question if ANY of these is true:
- the Hindi question, a Hindi option or the Hindi explanation does not mean exactly what the English one means;
- a number, year, date, unit or proper name is different, wrong or missing in Hindi;
- the Hindi options are not in the same order as the English options;
- the explanation (English or Hindi) contradicts or does not support the marked correct option;
- the Hindi has a spelling, grammar or wording mistake that could confuse a student.
KEEP the question otherwise.

Return ONLY a JSON object like {"remove":[3,7]} listing the question numbers to remove ({"remove":[]} if none). No markdown.

QUESTIONS:
${lines}`;
}

// ------------------------------------------------------------------ Gemini

async function callGemini(prompt, key, temperature) {
  const gap = geminiGapMs();
  if (gap > 0) await sleep(gap);
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

function parseJsonObject(text, what) {
  const t = stripFences(text);
  try {
    return JSON.parse(t);
  } catch (_) {
    const a = t.indexOf("{");
    const b = t.lastIndexOf("}");
    if (a < 0 || b <= a) throw new Error(`${what} answer is not JSON`);
    return JSON.parse(t.slice(a, b + 1));
  }
}

/** Check A answer -> list of 1-based question numbers to remove. Throws if unreadable. */
function parseVerify(text) {
  const value = parseJsonObject(text, "Checker");
  const list = Array.isArray(value) ? value : value && Array.isArray(value.remove) ? value.remove : null;
  if (!list) throw new Error("Checker answer has no 'remove' list");
  return list.map(Number).filter((n) => Number.isInteger(n) && n >= 1);
}

/** Check B answer -> Map(questionNumber -> {letter, sure}). Throws if unreadable. */
function parseSolve(text) {
  const value = parseJsonObject(text, "Solver");
  const list = Array.isArray(value) ? value : value && Array.isArray(value.answers) ? value.answers : null;
  if (!list) throw new Error("Solver answer has no 'answers' list");
  const map = new Map();
  for (const e of list) {
    const q = Number(e && e.q);
    const letter = String((e && e.answer) || "").trim().toUpperCase().charAt(0);
    if (Number.isInteger(q) && q >= 1 && LETTERS.includes(letter)) map.set(q, { letter, sure: e.sure === true });
  }
  return map;
}

/** Question numbers the blind solver did NOT confirm: other letter, not sure, or missing. */
function solveRejections(questions, answers) {
  const bad = [];
  questions.forEach((q, i) => {
    const a = answers.get(i + 1);
    if (!a || !a.sure || a.letter !== LETTERS[q.correctIndex]) bad.push(i + 1);
  });
  return bad;
}

function shuffleInPlace(arr, rnd) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

const DEVANAGARI_DIGITS = "\u0966\u0967\u0968\u0969\u096A\u096B\u096C\u096D\u096E\u096F";

/** All numbers in a text as plain strings (Devanagari digits and thousand separators normalised). */
function numbersIn(text) {
  const t = String(text)
    .replace(/[\u0966-\u096F]/g, (c) => String(DEVANAGARI_DIGITS.indexOf(c)))
    .replace(/(\d),(?=\d)/g, "$1");
  return t.match(/\d+(?:\.\d+)?/g) || [];
}

/** True when every number of the English text also appears in the Hindi text. */
function numbersCovered(en, hi) {
  const have = new Set(numbersIn(hi));
  return numbersIn(en).every((n) => have.has(n));
}

/** A clean question object (with `src` for the checkers), or null if anything is wrong with it. */
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
  if (!numbersCovered(text, textHi) || !numbersCovered(explanation, explanationHi)) return null; // a number differs in Hindi
  if (options.some((o, i) => !numbersCovered(o, optionsHi[i]))) return null;
  if (maxSrc > 0 && (!Number.isInteger(src) || src < 1 || src > maxSrc)) return null; // must point at a real source / topic

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

/** Drops the questions at the given 1-based numbers. Out-of-range numbers are ignored. */
function applyVerification(questions, removeNumbers) {
  const drop = new Set(removeNumbers);
  return questions.filter((_, i) => !drop.has(i + 1));
}

/** PIB wants its source acknowledged: put the credit inside the explanation, so it travels with the question. */
function withCredit(q, credit) {
  return { ...q, explanation: `${q.explanation}${credit.en}`, explanationHi: `${q.explanationHi}${credit.hi}` };
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

/** English folder: questions and passage openings of the 2 earlier months (2 reads), so nothing comes back. */
async function loadPreviousEnglish(db, examId, subjectId, monthKey) {
  const docs = [];
  for (const back of [1, 2]) {
    const snap = await db.collection("freeMcqSets").doc(setId(examId, subjectId, shiftMonth(monthKey, -back))).get();
    if (snap.exists) docs.push(snap.data());
  }
  return english.previousFromSets(docs).slice(0, 40);
}

/** Step 0: delete every set that was built from CC-licensed text (an older version of this job). */
async function purgeLegacyLicensedSets(db) {
  const snap = await db.collection("freeMcqSets").where("license", ">=", "CC").where("license", "<", "CD").get();
  const ids = new Set(snap.docs.map((d) => d.id));
  if (ids.size) {
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`Deleted ${ids.size} older set(s) that used CC-licensed text: ${[...ids].join(", ")}`);
  }
  return ids;
}

/** Delete every set of an exam that is no longer in EXAMS (e.g. banking, upsc, the old up_state). Returns the deleted ids. */
async function purgeRemovedExamSets(db) {
  const keep = new Set(EXAMS.map((e) => e.id));
  const snap = await db.collection("freeMcqSets").get();
  const stale = snap.docs.filter((d) => !keep.has(String((d.data() || {}).examId || "")));
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    stale.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  if (stale.length) console.log(`Deleted ${stale.length} set(s) of removed exams: ${stale.map((d) => d.id).join(", ")}`);
  return new Set(stale.map((d) => d.id));
}

/** Delete every set whose subject is no longer in SUBJECTS (e.g. the removed Current Affairs). Returns the deleted ids. */
async function purgeRemovedSubjectSets(db) {
  const keep = new Set(ALL_SUBJECTS.map((s) => s.id));
  const snap = await db.collection("freeMcqSets").get();
  const stale = snap.docs.filter((d) => {
    const data = d.data() || {};
    const subjectId = String(data.subjectId || "");
    if (!keep.has(subjectId)) return true;
    // A subject that does not belong to its exam folder (e.g. GK inside English) is not kept either.
    const exam = EXAMS.find((e) => e.id === String(data.examId || ""));
    return exam ? !subjectsFor(exam).some((x) => x.id === subjectId) : false;
  });
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    stale.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  if (stale.length) console.log(`Deleted ${stale.length} set(s) of removed subjects: ${stale.map((d) => d.id).join(", ")}`);
  return new Set(stale.map((d) => d.id));
}

// ------------------------------------------------------------ generation

/**
 * Writes the questions, then checks them (A, B, C). Collects survivors over up to MAX_ROUNDS rounds until
 * `perSet` (default QUESTIONS_PER_SET) are there. Returns the final list, or [] if the set must not be published.
 * `ctx` is { blocks } for Current Affairs (PIB lines) or { topicList } for static subjects.
 */
async function generateSet({ exam, subject, monthKey, ctx, previous, key, perSet = QUESTIONS_PER_SET, asked = QUESTIONS_ASKED }) {
  const grounded = Array.isArray(ctx.blocks);
  const maxSrc = grounded ? ctx.blocks.length : ctx.topicList.length;
  const temperature = grounded ? 0.2 : 0.3;
  const kept = [];

  for (let round = 1; round <= MAX_ROUNDS && kept.length < perSet; round++) {
    try {
      const need = perSet - kept.length;
      const n = round === 1 ? asked : Math.min(asked, need + 10);
      const avoid = [...previous, ...kept.map((q) => q.text)]; // earlier months + what this set already has
      const exclude = new Set(avoid.map((t) => t.toLowerCase()));
      const prompt = grounded
        ? buildCaPrompt({ exam, subject, monthKey, blocks: ctx.blocks, previous: avoid, n })
        : buildStaticPrompt({ exam, subject, monthKey, topicList: ctx.topicList, previous: avoid, n });

      const cleaned = cleanQuestions(parseAnswer(await callGemini(prompt, key, temperature)), { exclude, maxSrc, want: n });
      console.log(`  round ${round}: ${cleaned.length} well-formed question(s) (asked ${n}).`);
      if (!cleaned.length) continue;

      // Check A: fact-check (against the PIB lines, or against textbook knowledge).
      const removeA = parseVerify(await callGemini(buildVerifyPrompt({ ...ctx, questions: cleaned }), key, 0));
      const drop = new Set(removeA);
      let removeB = [];
      if (!grounded) {
        // Check B: blind solve, only for static questions.
        const answers = parseSolve(await callGemini(buildSolvePrompt({ questions: cleaned }), key, 0));
        removeB = solveRejections(cleaned, answers);
        removeB.forEach((n2) => drop.add(n2));
      }
      // Check C: English and Hindi must match (all sets).
      const removeC = parseVerify(await callGemini(buildBilingualPrompt({ questions: cleaned }), key, 0));
      removeC.forEach((n2) => drop.add(n2));

      const survivors = applyVerification(cleaned, [...drop]);
      console.log(`  round ${round}: check A removed ${new Set(removeA).size}, check B removed ${removeB.length}, check C removed ${new Set(removeC).size}, ${survivors.length} survive.`);
      kept.push(...survivors);
    } catch (err) {
      console.warn(`  round ${round} failed: ${err.message}`);
    }
  }
  if (kept.length < perSet) return [];
  return kept.slice(0, perSet).map(toStored);
}

/**
 * The exam folders are managed from the app (Admin Panel > Free MCQs tab) and stored in
 * freeMcqIndex/current.exams. When that list exists, it REPLACES the built-in EXAMS above for
 * this run (so exams added in the app get sets, and exams removed in the app are not rebuilt).
 * Built-in exams keep their own focus/level; a new exam gets a generic General Awareness focus.
 * If the list is missing or empty, the built-in EXAMS are used unchanged.
 */
async function applyExamsFromFirestore(db) {
  const snap = await db.collection("freeMcqIndex").doc("current").get();
  const raw = snap.exists ? (snap.data() || {}).exams : null;
  if (!Array.isArray(raw)) return;
  const list = [];
  const seen = new Set();
  for (const e of raw) {
    const id = String((e && e.id) || "").trim();
    const name = oneLine(e && e.name);
    if (!id || !name || seen.has(id)) continue;
    seen.add(id);
    const builtIn = EXAMS.find((x) => x.id === id);
    list.push({
      id,
      name,
      emoji: oneLine(e && e.emoji) || "📘",
      level: builtIn ? builtIn.level : MODERATE_LEVEL,
      subjectIds: builtIn ? builtIn.subjectIds : undefined,
      focus: builtIn
        ? builtIn.focus
        : `${name}: General Awareness and General Studies for this exam: Indian history, culture, geography, polity, economy, general science, static GK and current affairs, at the level usually asked in ${name}. Clear factual questions.`,
    });
  }
  if (!list.length) return;
  EXAMS.length = 0;
  EXAMS.push(...list);
  console.log(`Exam folders from the app: ${list.map((x) => x.id).join(", ")}`);
}

/** The English folder is built in: it is always there, even if the app's exam list does not mention it. */
function ensureEnglishFolder() {
  if (!EXAMS.some((e) => e.id === ENGLISH_EXAM.id)) EXAMS.push({ ...ENGLISH_EXAM });
}

/** Rebuilds freeMcqIndex/current (1 read + 1 write). Drops purged sets and sets older than KEEP_MONTHS. */
async function writeIndex(db, admin, monthKey, built, purged) {
  const idxRef = db.collection("freeMcqIndex").doc("current");
  const keepExams = new Set(EXAMS.map((e) => e.id));
  const keepSubjects = new Set(ALL_SUBJECTS.map((x) => x.id));
  const oldSets = (((await idxRef.get()).data() || {}).sets || []).filter((s) => s && !purged.has(s.id) && keepExams.has(s.examId) && keepSubjects.has(s.subjectId));
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
    subjects: ALL_SUBJECTS.map(({ id, name, emoji }) => ({ id, name, emoji })),
    sets: kept.map(({ id, examId, subjectId, monthKey: mk, count, source }) => ({ id, examId, subjectId, monthKey: mk, count, source })),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ------------------------------------------------------------------ main

async function main() {
  const monthKey = (process.env.MONTH || "").trim() || shiftMonth(currentMonthIST(), -1);
  if (!/^\d{4}-\d{2}$/.test(monthKey)) throw new Error(`MONTH must look like 2026-10, got "${monthKey}"`);

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
  console.log(`Building free MCQs for ${monthLabel(monthKey)} (${monthKey}).`);

  // 0) No set built from CC-licensed text may stay in the database.
  const purged = await purgeLegacyLicensedSets(db);
  for (const id of await purgeRemovedExamSets(db)) purged.add(id);
  for (const id of await purgeRemovedSubjectSets(db)) purged.add(id);

  // 1) Which sets already exist? One read per set, skipped entirely when FORCE=true.
  const allIds = [];
  for (const exam of EXAMS) for (const subject of subjectsFor(exam)) allIds.push(setId(exam.id, subject.id, monthKey));
  const existing = new Map(); // id -> count
  if (!force) {
    const snaps = await db.getAll(...allIds.map((id) => db.collection("freeMcqSets").doc(id)));
    for (const s of snaps) if (s.exists) existing.set(s.id, Number(s.data().count) || 0);
  }

  // 2) Current Affairs source: only read when a "ca" subject is configured (it is not, now).
  const caLines = SUBJECTS.some((x) => x.id === "ca") ? await loadCaLines(db, admin, monthKey) : [];
  if (caLines.length) console.log(`PIB archive has ${caLines.length} current-affairs line(s) for ${monthKey}.`);

  // 3) Build every missing set.
  const built = [];
  let newSets = 0;
  let failed = 0;
  for (const exam of EXAMS) {
    for (const subject of subjectsFor(exam)) {
      const id = setId(exam.id, subject.id, monthKey);
      const isCa = subject.id === "ca";
      const isEnglish = subject.id === "english";
      const sourceLabel = isCa ? "PIB archive" : isEnglish ? "Banking PO/Clerk pattern, AI-checked" : "Syllabus-based, AI-checked";
      const meta = { id, examId: exam.id, subjectId: subject.id, monthKey, count: 0, source: sourceLabel };

      if (existing.has(id)) {
        built.push({ ...meta, count: existing.get(id) });
        console.log(`${id}: already there, skipped.`);
        continue;
      }

      if (isEnglish) {
        // English folder: 25 Banking PO / Clerk style English MCQs (own generator, English only, no Hindi).
        console.log(`${id}: generating English set...`);
        const previous = await loadPreviousEnglish(db, exam.id, subject.id, monthKey);
        const englishQs = await english.generateEnglishSet({ monthKey, previous, key: GEMINI_KEY, callGemini });
        if (englishQs.length < MIN_QUESTIONS) {
          failed++;
          console.error(`${id}: only ${englishQs.length} verified question(s) - not published.`);
          continue;
        }
        await db.collection("freeMcqSets").doc(id).set({
          examId: exam.id,
          subjectId: subject.id,
          monthKey,
          count: englishQs.length,
          source: sourceLabel,
          license: STATIC_LICENSE,
          licenseUrl: "",
          sources: [],
          questions: englishQs,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        built.push({ ...meta, count: englishQs.length });
        newSets++;
        try {
          await writeIndex(db, admin, monthKey, built, purged);
        } catch (err) {
          console.warn("Index update skipped for now:", err.message);
        }
        await sleep(PAUSE_BETWEEN_SETS_MS);
        continue;
      }

      let ctx;
      if (isCa) {
        if (caLines.length < MIN_CA_LINES) {
          console.warn(`${id}: only ${caLines.length} PIB line(s), need ${MIN_CA_LINES}. Skipped for now (next run will retry).`);
          continue;
        }
        ctx = { blocks: caLines.map((l) => ({ label: `(PIB, ${l.topic || "misc"})`, text: l.en })) };
      } else {
        ctx = { topicList: topics.pickTopics({ subjectId: subject.id, examId: exam.id, monthKey }) };
        if (ctx.topicList.length < 5) {
          console.warn(`${id}: no topics configured for this subject.`);
          failed++;
          continue;
        }
      }

      console.log(`${id}: generating...`);
      const previous = await loadPreviousTexts(db, exam.id, subject.id, monthKey);
      let questions = await generateSet({ exam, subject, monthKey, ctx, previous, key: GEMINI_KEY });
      if (questions.length < MIN_QUESTIONS) {
        failed++;
        console.error(`${id}: only ${questions.length} verified question(s) - not published.`);
        continue;
      }
      if (isCa) questions = questions.map((q) => withCredit(q, PIB_CREDIT));

      await db.collection("freeMcqSets").doc(id).set({
        examId: exam.id,
        subjectId: subject.id,
        monthKey,
        count: questions.length,
        source: sourceLabel,
        license: isCa ? "Source: PIB, Government of India" : STATIC_LICENSE,
        licenseUrl: isCa ? PIB_SOURCE.url : "",
        sources: isCa ? [PIB_SOURCE] : [],
        questions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      built.push({ ...meta, count: questions.length });
      newSets++;
      try {
        await writeIndex(db, admin, monthKey, built, purged);
      } catch (err) {
        console.warn("Index update skipped for now:", err.message);
      }
      await sleep(PAUSE_BETWEEN_SETS_MS);
    }
  }

  // 4) Final index rebuild (also done after every new set, so a timeout cannot leave it stale).
  await writeIndex(db, admin, monthKey, built, purged);

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
  ALL_SUBJECTS,
  subjectsFor,
  ensureEnglishFolder,
  QUESTIONS_PER_SET,
  QUESTIONS_ASKED,
  MIN_QUESTIONS,
  PIB_CREDIT,
  cleanQuestion,
  cleanQuestions,
  parseAnswer,
  callGemini,
  oneLine,
  parseVerify,
  parseSolve,
  solveRejections,
  applyVerification,
  toStored,
  withCredit,
  buildCaPrompt,
  buildStaticPrompt,
  buildVerifyPrompt,
  buildSolvePrompt,
  buildBilingualPrompt,
  numbersCovered,
  generateSet,
  purgeLegacyLicensedSets,
  purgeRemovedSubjectSets,
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

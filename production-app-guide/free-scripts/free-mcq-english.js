/**
 * Monthly ENGLISH set for the "English" folder of Free MCQs.
 *
 * Pattern: Banking PO / Clerk English Language (IBPS PO, SBI PO, IBPS Clerk, SBI Clerk).
 * Level  : moderate to hard. English only, no Static GK / Science / GS.
 * Size   : 25 MCQs per month, in these sections (the same blueprint every month):
 *
 *     Fill in the Blanks (single + double blank) ...... 4
 *     Error Spotting (3 parts + "No error") ........... 4
 *     Sentence Improvement ............................ 2
 *     Para Jumbles (5 sentences) ...................... 2
 *     Connectors / Para Completion / Common Word ...... 3
 *     Cloze Test (one passage, 5 blanks) .............. 5
 *     Reading Comprehension (one passage) ............. 5
 *
 * Every question is ORIGINAL (written by Gemini, no book / website / exam-paper text) and is checked twice:
 *   Check A: a strict grammar checker removes doubtful items (two right options, disputed usage, wrong key ...).
 *   Check B: a blind solver answers every item WITHOUT seeing the key; an item stays only if the solver is
 *            sure and picks the same option.
 * Para Jumbles are built in code: Gemini writes the 5 sentences in the CORRECT order, the code shuffles them
 * and works out the answer itself, so the key can never be mis-typed.
 *
 * No Hindi is stored (it is an English-language folder), so the app hides its Hindi switch for these sets.
 * Passage questions (RC / Cloze) carry their own copy of the passage in `passage`, which the app already shows.
 */
const { seededRandom } = require("./free-mcq-topics.js");

const LETTERS = ["A", "B", "C", "D"];
const SET_SIZE = 25;
const MAX_ROUNDS = 4;
const ENGLISH_TEMPERATURE = 0.4;

// `target` = questions kept in the set, `ask` = questions asked from Gemini in round 1.
const SECTIONS = [
  { id: "fib", label: "Fill in the Blanks", target: 4, ask: 6 },
  { id: "error", label: "Error Spotting", target: 4, ask: 6 },
  { id: "improve", label: "Sentence Improvement", target: 2, ask: 4 },
  { id: "jumble", label: "Para Jumbles", target: 2, ask: 4 },
  { id: "misc", label: "Connectors, Para Completion and Common Word", target: 3, ask: 5 },
  { id: "cloze", label: "Cloze Test", target: 5, ask: 5, passage: true },
  { id: "rc", label: "Reading Comprehension", target: 5, ask: 6, passage: true },
];

const MISC_TYPES = ["connector", "paracomp", "common"];

// ---------------------------------------------------------------- themes (our own outline)

const PASSAGE_THEMES = [
  "digital payments and everyday banking",
  "financial literacy and household savings",
  "the gig economy and changing jobs",
  "climate change and green finance",
  "urbanisation and public transport",
  "artificial intelligence at the workplace",
  "rural entrepreneurship and microfinance",
  "education and online learning",
  "healthcare access in small towns",
  "cyber-security awareness",
  "consumer spending and rising prices",
  "renewable energy adoption",
  "sustainable agriculture and food supply chains",
  "tourism and local economies",
  "remote work and work-life balance",
  "water conservation",
  "start-ups and innovation",
  "e-commerce and small shopkeepers",
  "an ageing population and pensions",
  "women in the workforce",
  "global trade and supply chains",
  "public libraries and reading habits",
  "waste management and recycling",
  "mobile technology in villages",
];

const RC_STYLES = [
  "analytical, with a balanced argument",
  "descriptive, with a gradual build-up and a clear conclusion",
  "an opinion-style essay that presents a problem and a possible solution",
  "a factual narrative about a trend, in a formal tone",
];

const GRAMMAR_AREAS = [
  "subject-verb agreement",
  "tense consistency and sequence of tenses",
  "prepositions",
  "articles",
  "pronoun-antecedent agreement and pronoun case",
  "conditionals",
  "adjectives and adverbs, comparatives and superlatives",
  "parallel structure",
  "misplaced or dangling modifiers",
  "conjunctions and correlative pairs (not only ... but also, hardly ... when, no sooner ... than)",
  "countable and uncountable nouns, quantifiers and determiners",
  "active and passive voice",
  "gerund and infinitive usage",
  "wrong word forms and redundancy",
];

const VOCAB_AREAS = [
  "precise word choice in formal writing",
  "collocations",
  "commonly confused words",
  "phrasal verbs",
  "idiomatic expressions",
  "prepositions that go with particular verbs and adjectives",
  "tense and grammar inside the sentence",
];

// ---------------------------------------------------------------- small helpers

function shuffled(arr, rnd) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const hasDevanagari = (s) => /[\u0900-\u097F]/.test(s);

/** Trim every line and collapse spaces, but KEEP line breaks (jumbles and passages need them). */
function tidy(s) {
  return String(s == null ? "" : s)
    .replace(/\r/g, "")
    .split("\n")
    .map((l) => l.replace(/[ \t]+/g, " ").trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

const oneLineText = (s) => String(s == null ? "" : s).replace(/\s+/g, " ").trim();

function parseJsonLoose(text) {
  const t = String(text).trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  try {
    return JSON.parse(t);
  } catch (_) {
    const a = t.search(/[[{]/);
    if (a < 0) throw new Error("Gemini answer is not JSON");
    const close = t[a] === "[" ? "]" : "}";
    const b = t.lastIndexOf(close);
    if (b <= a) throw new Error("Gemini answer is not JSON");
    return JSON.parse(t.slice(a, b + 1));
  }
}

/** What to write about this month: different themes and grammar areas every month and every round. */
function pickPlan(seedKey) {
  const rnd = seededRandom(`english|${seedKey}`);
  const themes = shuffled(PASSAGE_THEMES, rnd);
  return {
    rcTheme: themes[0],
    clozeTheme: themes[1],
    jumbleThemes: themes.slice(2, 6),
    rcStyle: shuffled(RC_STYLES, rnd)[0],
    errorAreas: shuffled(GRAMMAR_AREAS, rnd).slice(0, 5),
    fibAreas: shuffled(VOCAB_AREAS, rnd).slice(0, 4),
    improveAreas: shuffled(GRAMMAR_AREAS, rnd).slice(0, 3),
  };
}

// ---------------------------------------------------------------- prompts

const COMMON_RULES = `You are a senior question-setter for the English Language section of Indian bank exams (IBPS PO, SBI PO, IBPS Clerk, SBI Clerk).
LEVEL: moderate to hard (PO Prelims / Mains standard): about 40% moderate and 60% hard. Hard questions need careful reading: close options, subtle errors, inference instead of direct look-up. Do not write easy, one-glance questions.

RULES (most important first):
1. Accuracy: every marked answer must be correct under standard English grammar and usage on which all standard grammar books agree. Never use disputed points (split infinitives, "data is/are", "different from/than", "less/fewer" debates, serial commas, British/American spelling differences). If you are not 100% sure, do not use it.
2. Exactly 4 options. Exactly ONE is correct. The 3 wrong options must be plausible but clearly wrong, and NO other option may also be acceptable.
3. Never use options like "Both A and B", "All of the above", "None of the above" or any option that refers to another option.
4. Write in English only. Write ORIGINAL text; never copy a passage, sentence or question from any book, website or exam paper.
5. Keep the content neutral: no politics, religion, caste, real people or real statistics.
6. "explanation": 1-2 sentences, at most 50 words, naming the rule or idea that decides the answer.
7. Spread the position of the correct option over 0-3 ("correctIndex"); do not always use the same position.
8. Return ONLY the JSON asked for. No markdown.`;

function avoidBlock(avoid) {
  if (!avoid || !avoid.length) return "";
  return `\n\nDO NOT repeat these earlier items, or their sentences, passages and themes:\n${avoid.map((t) => `- ${t}`).join("\n")}`;
}

function fibPrompt({ n, plan, avoid }) {
  return `${COMMON_RULES}

SECTION: Fill in the Blanks. Write exactly ${n} questions: about half single-blank, half double-blank (single-blank first).
- Single blank: one sentence of 20-35 words with ONE blank written as _____ . Options: 4 words or short phrases.
- Double blank: one sentence of 25-40 words with TWO blanks written as _____ and _____ . Each option is a pair written "word1, word2". Only ONE pair fits both blanks in meaning and grammar; every other pair must clearly fail at least one blank.
- Test these skills (spread the questions over them): ${plan.fibAreas.join("; ")}.
- Distractors must be close in meaning or form, so that students have to think.

Return a JSON array of ${n} objects: {"text": "<the sentence with the blank(s)>", "options": [4 strings], "correctIndex": 0-3, "explanation": "..."}${avoidBlock(avoid)}`;
}

function errorPrompt({ n, plan, avoid }) {
  const noError = n >= 4 ? 1 : 0;
  return `${COMMON_RULES}

SECTION: Error Spotting. Write exactly ${n} questions. Each is ONE sentence of 18-32 words, cut into exactly 3 parts. Either exactly one part has a grammatical error, or the sentence has no error.
- Exactly ${noError} of the ${n} must be a fully correct sentence ("no error"); every other sentence has exactly ONE clear grammatical error, in part 1, in part 2 or in part 3 (spread them over the three parts).
- The error must be a real grammar error on these areas: ${plan.errorAreas.join("; ")}. Never use punctuation, capitalisation, spelling or style as the error.
- Do not label the parts. Joined with single spaces, the 3 parts must read as the full sentence.
- "correctIndex": 0, 1 or 2 = the part with the error; 3 = no error.

Return a JSON array of ${n} objects: {"parts": ["part 1", "part 2", "part 3"], "correctIndex": 0-3, "explanation": "..."}${avoidBlock(avoid)}`;
}

function improvePrompt({ n, plan, avoid }) {
  return `${COMMON_RULES}

SECTION: Sentence Improvement. Write exactly ${n} questions. Each has ONE sentence of 18-30 words in which a part of 2-8 words is written inside [square brackets].
- Options: exactly 3 alternative phrases that could replace the bracketed part, plus the 4th option exactly "No improvement required".
- In all questions except at most one, the bracketed part has a grammar or usage error, and exactly ONE of the 3 phrases corrects it (the other two keep or add an error, and "No improvement required" is wrong).
- In at most one question the bracketed part is already correct; then the answer is "No improvement required".
- Test these areas: ${plan.improveAreas.join("; ")}.

Return a JSON array of ${n} objects: {"sentence": "<sentence with [bracketed part]>", "options": [3 phrases, then "No improvement required"], "correctIndex": 0-3, "explanation": "..."}${avoidBlock(avoid)}`;
}

function jumblePrompt({ n, plan, avoid }) {
  return `${COMMON_RULES}

SECTION: Para Jumbles. Write exactly ${n} paragraphs of exactly 5 sentences each (10-25 words per sentence), written IN THE CORRECT ORDER.
- The order must be forced by clear logic: a general opening sentence, "this / such / these / they" that point back to an earlier sentence, connectors (however, as a result, for instance), cause before effect, chronology.
- Only ONE sensible order may exist: no two sentences may be swappable.
- Sentence 1 must be a general opener that does NOT depend on any earlier sentence.
- Do not number or label the sentences. Themes (one per paragraph, in any order): ${plan.jumbleThemes.join("; ")}.
- "explanation": 1-2 sentences naming the logical links IN WORDS. Never use letters or numbers to name sentences (the app shuffles and labels them later).

Return a JSON array of ${n} objects: {"sentences": ["s1", "s2", "s3", "s4", "s5"], "explanation": "..."}${avoidBlock(avoid)}`;
}

const MISC_SPEC = {
  connector: `"connector": two related sentences (I) and (II) of 15-25 words each with a clear logical relationship (contrast, cause and effect, addition or condition). The question asks which connector joins them meaningfully. Options: 4 connectors or short connecting phrases; exactly ONE gives the correct meaning, the others reverse or break the logic. Put (I) and (II) on separate lines (use \\n).`,
  paracomp: `"paracomp": a paragraph of exactly 3 sentences (45-70 words) whose last sentence is missing (end the paragraph with "..."). The question asks which sentence best completes the paragraph. Options: 4 complete sentences of at most 25 words; only ONE continues and completes the idea logically, the others are off-topic, repeat an earlier sentence or contradict the paragraph.`,
  common: `"common": two sentences (I) and (II), each with one blank written as _____ . ONE word fits BOTH blanks in meaning and grammar (a word with several meanings, e.g. a noun in one sentence and a verb in the other). Options: 4 single words; none of the three wrong words may fit both blanks. Put (I) and (II) on separate lines (use \\n).`,
};

function miscPrompt({ kinds, avoid }) {
  const specs = [...new Set(kinds)].map((k) => `- ${MISC_SPEC[k]}`).join("\n");
  return `${COMMON_RULES}

SECTION: Connectors, Para Completion and Common Word. Write exactly ${kinds.length} questions, of these types in this order: ${kinds.join(", ")}.
${specs}
Write the full question text including the instruction line (for example "Which of the following can join sentences (I) and (II) meaningfully?").

Return a JSON array of ${kinds.length} objects: {"type": "connector" | "paracomp" | "common", "text": "...", "options": [4 strings], "correctIndex": 0-3, "explanation": "..."}${avoidBlock(avoid)}`;
}

function rcPrompt({ n, plan, avoid }) {
  return `${COMMON_RULES}

SECTION: Reading Comprehension. Write ONE original passage of ${n >= 5 ? "190-240" : "120-170"} words (one or two paragraphs, separated by a blank line).
Theme: ${plan.rcTheme}. Style: ${plan.rcStyle}.
The passage must be self-contained and formal, with a clear line of argument and enough detail for inference questions. No real statistics, names or dates.
Then write exactly ${n} questions on it. Spread them over: main idea or best title; inference (what can be concluded); vocabulary in context (quote a word from the passage and ask for its synonym or antonym as used there); the author's tone, attitude or purpose; a statement question ("Which of the following is true / NOT true according to the passage?").
- Every question must be answerable from the passage alone, and at least 3 must need inference instead of direct look-up.
- Options are at most 15 words. No two questions on the same sentence. Never write "according to the text" in a way that hides the question; each question must be clear on its own.

Return a JSON object: {"passage": "...", "questions": [{"text": "...", "options": [4 strings], "correctIndex": 0-3, "explanation": "..."}]}${avoidBlock(avoid)}`;
}

function clozePrompt({ n, plan, avoid }) {
  const words = n >= 5 ? "110-150" : "60-100";
  return `${COMMON_RULES}

SECTION: Cloze Test. Write ONE original passage of ${words} words on the theme: ${plan.clozeTheme}.
- The passage has exactly ${n} blanks, written in order as (1) _____ , (2) _____ ${n > 2 ? "..." : ""} (${n}) _____ .
- Write exactly ${n} questions: question k is about blank (k) and its text is "Select the most appropriate word for blank (k)."
- The blanks must test different things: vocabulary in context, collocation or preposition, tense or grammar, connector or logic.
- Only ONE option fits both grammar and meaning; the other options must clearly fail. With the correct words filled in, the passage must read naturally.

Return a JSON object: {"passage": "...", "questions": [{"text": "...", "options": [4 strings], "correctIndex": 0-3, "explanation": "..."}]}${avoidBlock(avoid)}`;
}

function buildSectionPrompt({ section, n, plan, avoid, kinds }) {
  switch (section.id) {
    case "fib":
      return fibPrompt({ n, plan, avoid });
    case "error":
      return errorPrompt({ n, plan, avoid });
    case "improve":
      return improvePrompt({ n, plan, avoid });
    case "jumble":
      return jumblePrompt({ n, plan, avoid });
    case "misc":
      return miscPrompt({ kinds, avoid });
    case "cloze":
      return clozePrompt({ n, plan, avoid });
    case "rc":
      return rcPrompt({ n, plan, avoid });
    default:
      throw new Error(`Unknown English section: ${section.id}`);
  }
}

// ---------------------------------------------------------------- checks (A and B)

/** Lines for the checkers. A passage is printed once, before the questions that share it. */
function itemLines(items, withAnswer) {
  const out = [];
  let lastPassage = "";
  items.forEach((it, i) => {
    const q = it.q;
    if (q.passage && q.passage !== lastPassage) out.push(`\n[PASSAGE for the questions below]\n${q.passage}\n`);
    lastPassage = q.passage || "";
    const opts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join("   ");
    let line = `Q${i + 1} [${it.section}] ${q.text}\n   ${opts}`;
    if (withAnswer) line += `\n   Marked correct: ${LETTERS[q.correctIndex]}\n   Explanation: ${q.explanation}`;
    out.push(line);
  });
  return out.join("\n");
}

function buildCheckPrompt(items) {
  return `You are a strict checker of English Language questions for Indian bank exams (IBPS / SBI PO and Clerk). Judge each question with standard grammar-book rules.
Options are listed as A) B) C) D) in the order given.

REMOVE a question if ANY of these is true:
- the marked correct option is wrong, or is not clearly the BEST answer;
- another option is also correct or acceptable (in any standard style of English);
- the question depends on disputed usage, British/American variation, or punctuation or style preference;
- the explanation is wrong, or does not match the marked option;
- the question is ambiguous or has a typing mistake that is not meant to be the test;
- passage questions: the marked answer is not supported by the passage, or the passage itself contains an unintended error;
- cloze: the marked word does not fit the blank in BOTH meaning and grammar, or another option also fits;
- [jumble]: more than one sentence order makes sense, or the marked order is not the most logical one;
- [error]: the marked part has no real grammar error, another part also has an error, or "No error" is marked although the sentence has an error (Part (A), (B), (C) = parts 1, 2, 3 of the sentence).
When in doubt, REMOVE. KEEP a question only if you are sure.

Return ONLY a JSON object like {"remove":[3,7]} listing the question numbers to remove ({"remove":[]} if none). No markdown.

QUESTIONS:
${itemLines(items, true)}`;
}

function buildSolvePrompt(items) {
  return `You are an expert in English for Indian bank exams (IBPS / SBI PO and Clerk). Answer each multiple-choice question.
For each question give the letter of the best option (A, B, C or D) and say whether you are SURE (true) or not (false).
Say sure=false if two options could be right, the question is ambiguous, or you are not certain.

Return ONLY a JSON object like {"answers":[{"q":1,"answer":"C","sure":true}]} with one entry per question. No markdown.

QUESTIONS:
${itemLines(items, false)}`;
}

function parseRemove(text) {
  const value = parseJsonLoose(text);
  const list = Array.isArray(value) ? value : value && Array.isArray(value.remove) ? value.remove : null;
  if (!list) throw new Error("Checker answer has no 'remove' list");
  return list.map(Number).filter((n) => Number.isInteger(n) && n >= 1);
}

function parseSolve(text) {
  const value = parseJsonLoose(text);
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

/** Question numbers the blind solver did NOT confirm (other letter, not sure, or missing). */
function solveRejections(items, answers) {
  const bad = [];
  items.forEach((it, i) => {
    const a = answers.get(i + 1);
    if (!a || !a.sure || a.letter !== LETTERS[it.q.correctIndex]) bad.push(i + 1);
  });
  return bad;
}

// ---------------------------------------------------------------- cleaning

const BAD_OPTION = /(of the above|^both\b.*\band\b|^(a|b|c|d)\s*(and|&|,)\s*(a|b|c|d)$|^only\s+[a-d]\b|^all\s+(of\s+)?(these|them)\b|^none\s+of\s+(these|them)\b)/i;
const NO_IMPROVEMENT = /^no (improvement|correction|change)/i;

function cleanOptions(rawOptions, { allowSame = false } = {}) {
  if (!Array.isArray(rawOptions) || rawOptions.length !== 4) return null;
  const options = rawOptions.map(oneLineText);
  if (options.some((o) => o.length < 1 || o.length > 180 || hasDevanagari(o) || BAD_OPTION.test(o))) return null;
  if (!allowSame && new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  return options;
}

function cleanExplanation(raw) {
  const e = oneLineText(raw);
  return e.length >= 5 && e.length <= 450 && !hasDevanagari(e) ? e : null;
}

function cleanIndex(raw) {
  const i = Number(raw);
  return Number.isInteger(i) && i >= 0 && i <= 3 ? i : -1;
}

/** Shuffles the options (the explanation never names an option letter). "No improvement required" stays last. */
function shuffleOptions(options, correctIndex, rnd) {
  const idx = shuffled([0, 1, 2, 3], rnd);
  const pinned = idx.filter((i) => NO_IMPROVEMENT.test(options[i]));
  const order = [...idx.filter((i) => !pinned.includes(i)), ...pinned];
  return { options: order.map((i) => options[i]), correctIndex: order.indexOf(correctIndex) };
}

/** A generic question {text, options, correctIndex, explanation}. */
function cleanGeneric(raw, { minText = 12, maxText = 700, rnd, shuffle = true } = {}) {
  if (!raw || typeof raw !== "object") return null;
  const text = tidy(raw.text);
  const options = cleanOptions(raw.options);
  const ci = cleanIndex(raw.correctIndex);
  const explanation = cleanExplanation(raw.explanation);
  if (text.length < minText || text.length > maxText || hasDevanagari(text)) return null;
  if (!options || ci < 0 || !explanation) return null;
  const mixed = shuffle ? shuffleOptions(options, ci, rnd) : { options, correctIndex: ci };
  return { text, explanation, ...mixed };
}

function cleanFib(raw, rnd) {
  const q = cleanGeneric(raw, { minText: 25, maxText: 400, rnd });
  if (!q || !/_{3,}/.test(q.text)) return null;
  return q;
}

const ERROR_DIRECTION = "Find the part of the sentence that has an error. If there is no error, choose 'No error'.";

function cleanError(raw) {
  if (!raw || !Array.isArray(raw.parts) || raw.parts.length !== 3) return null;
  const parts = raw.parts.map((p) => oneLineText(p).replace(/^\(?[A-Ca-c1-3][).]\s+/, ""));
  if (parts.some((p) => p.length < 2 || p.length > 160 || hasDevanagari(p))) return null;
  const ci = cleanIndex(raw.correctIndex);
  const explanation = cleanExplanation(raw.explanation);
  if (ci < 0 || !explanation) return null;
  const sentence = parts.join(" ");
  if (sentence.length < 50 || sentence.length > 320) return null;
  return {
    text: `${ERROR_DIRECTION}\n\n(A) ${parts[0]}\n(B) ${parts[1]}\n(C) ${parts[2]}`,
    options: ["Part (A)", "Part (B)", "Part (C)", "No error"], // fixed order: letters point at the parts
    correctIndex: ci,
    explanation,
  };
}

const IMPROVE_DIRECTION =
  "Replace the part in [square brackets] with the best alternative so that the sentence becomes grammatically correct and meaningful. If no change is needed, choose 'No improvement required'.";

function cleanImprove(raw, rnd) {
  if (!raw || typeof raw !== "object") return null;
  const sentence = oneLineText(raw.sentence);
  if (sentence.length < 40 || sentence.length > 300 || hasDevanagari(sentence)) return null;
  if (!/\[[^\]]{2,80}\]/.test(sentence)) return null;
  const options = cleanOptions(raw.options);
  const ci = cleanIndex(raw.correctIndex);
  const explanation = cleanExplanation(raw.explanation);
  if (!options || ci < 0 || !explanation) return null;
  if (options.filter((o) => NO_IMPROVEMENT.test(o)).length !== 1) return null;
  return { text: `${IMPROVE_DIRECTION}\n\n${sentence}`, explanation, ...shuffleOptions(options, ci, rnd) };
}

/** Builds a jumble question in code: shuffles the sentences and works out the answer itself. */
function cleanJumble(raw, rnd) {
  if (!raw || !Array.isArray(raw.sentences) || raw.sentences.length !== 5) return null;
  const sentences = raw.sentences.map((s) => oneLineText(s).replace(/^\(?[A-Ea-e1-5][).]\s+/, ""));
  if (sentences.some((s) => s.length < 25 || s.length > 220 || hasDevanagari(s))) return null;
  if (new Set(sentences.map((s) => s.toLowerCase())).size !== 5) return null;
  const explanation = cleanExplanation(raw.explanation);
  if (!explanation) return null;

  // shown[k] = index (in the correct order) of the sentence shown with label k.
  let shown = shuffled([0, 1, 2, 3, 4], rnd);
  for (let tries = 0; tries < 20 && shown.every((v, k) => v === k); tries++) shown = shuffled([0, 1, 2, 3, 4], rnd);
  if (shown.every((v, k) => v === k)) return null;
  const labels = ["A", "B", "C", "D", "E"];
  const correct = [0, 1, 2, 3, 4].map((sentenceIdx) => labels[shown.indexOf(sentenceIdx)]);

  // Wrong options: the correct order with two neighbouring sentences swapped (close, so students must think).
  const wrong = [];
  for (const i of shuffled([0, 1, 2, 3], rnd)) {
    const seq = correct.slice();
    [seq[i], seq[i + 1]] = [seq[i + 1], seq[i]];
    wrong.push(seq.join(""));
    if (wrong.length === 3) break;
  }
  const correctStr = correct.join("");
  const mixed = shuffled([correctStr, ...wrong], rnd);
  const lines = shown.map((sentenceIdx, k) => `${labels[k]}. ${sentences[sentenceIdx]}`).join("\n");
  return {
    text: `Rearrange the following sentences A, B, C, D and E to form a meaningful and coherent paragraph. Choose the correct order.\n\n${lines}`,
    options: mixed,
    correctIndex: mixed.indexOf(correctStr),
    explanation: `${explanation} Correct order: ${correct.join(" → ")}.`,
  };
}

function cleanMisc(raw, rnd) {
  const type = String((raw && raw.type) || "").toLowerCase();
  if (!MISC_TYPES.includes(type)) return null;
  const q = cleanGeneric(raw, { minText: 30, maxText: 650, rnd });
  if (!q) return null;
  if (type === "common" && (q.text.match(/_{3,}/g) || []).length < 2) return null;
  if (type === "connector" && !(/\(I\)/.test(q.text) && /\(II\)/.test(q.text))) return null;
  return { ...q, subtype: type };
}

/** One passage group (RC or Cloze): {passage, questions[]} -> { passage, items[], blanks[] } or null. */
function cleanGroup(raw, section, expected, rnd) {
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.questions)) return null;
  const passage = tidy(raw.passage);
  const isCloze = section.id === "cloze";
  if (passage.length < (isCloze ? 200 : 450) || passage.length > 2000 || hasDevanagari(passage)) return null;

  const items = [];
  for (let i = 0; i < raw.questions.length; i++) {
    const q = cleanGeneric(raw.questions[i], { minText: 10, maxText: 260, rnd });
    if (!q) {
      if (isCloze) return null; // a cloze passage needs a question for every blank
      continue; // an RC question that is badly formed is simply left out
    }
    items.push(q);
  }

  if (isCloze) {
    if (items.length !== expected) return null;
    const blanks = [];
    for (let k = 1; k <= expected; k++) {
      if (!new RegExp(`\\(${k}\\)`).test(passage)) return null;
      const q = items[k - 1];
      if (!new RegExp(`blank\\s*\\(${k}\\)`, "i").test(q.text)) return null;
      blanks.push(k);
    }
    return { passage, items, blanks };
  }
  return items.length >= Math.min(3, expected) ? { passage, items, blanks: [] } : null;
}

/** Cloze: a blank whose question was removed is filled with its marked answer, so no unanswered blank stays in the passage. */
function fillBlank(passage, blankNo, word) {
  const re = new RegExp(`\\(${blankNo}\\)\\s*_{2,}`);
  return re.test(passage) ? passage.replace(re, word) : passage;
}

// ---------------------------------------------------------------- one section, one round

/**
 * Asks Gemini for one section and returns the cleaned items:
 * [{ section, subtype?, groupId?, blankNo?, q: {text, options, correctIndex, explanation, passage?} }]
 */
async function writeSection({ section, n, plan, avoid, kinds, key, callGemini, rnd, groupBase }) {
  const prompt = buildSectionPrompt({ section, n, plan, avoid, kinds });
  const raw = parseJsonLoose(await callGemini(prompt, key, ENGLISH_TEMPERATURE));
  const out = [];

  if (section.passage) {
    const group = cleanGroup(raw, section, n, rnd);
    if (!group) return out;
    group.items.slice(0, section.id === "rc" ? n : group.items.length).forEach((q, i) => {
      out.push({ section: section.id, groupId: groupBase, blankNo: section.id === "cloze" ? i + 1 : 0, q: { ...q, passage: group.passage } });
    });
    return out;
  }

  const list = Array.isArray(raw) ? raw : [];
  for (const r of list) {
    let q = null;
    let subtype = "";
    if (section.id === "fib") q = cleanFib(r, rnd);
    else if (section.id === "error") q = cleanError(r);
    else if (section.id === "improve") q = cleanImprove(r, rnd);
    else if (section.id === "jumble") q = cleanJumble(r, rnd);
    else if (section.id === "misc") {
      const m = cleanMisc(r, rnd);
      if (m) {
        subtype = m.subtype;
        const { subtype: _s, ...rest } = m; // eslint-disable-line no-unused-vars
        q = rest;
      }
    }
    if (q) out.push({ section: section.id, subtype, q });
  }
  return out;
}

// ---------------------------------------------------------------- the whole set

const DIRECTION_START = /^(Find the part|Replace the part|Rearrange the following)/i;

/** Passage questions share generic wording ("Select the most appropriate word for blank (1)"), so the passage is part of the key. */
function dedupeKey(q) {
  return `${oneLineText(q.passage).slice(0, 80)}|${oneLineText(q.text)}`.toLowerCase();
}

/** A short label of an item for the "do not repeat" list (never the generic direction line). */
function avoidLabel(q) {
  if (q.passage) return `Passage starting: "${oneLineText(q.passage).slice(0, 90)}..."`;
  const lines = q.text.split("\n").filter((l) => l.trim());
  const body = lines.filter((l, i) => !(i === 0 && DIRECTION_START.test(l)));
  return oneLineText(body.join(" ")).slice(0, 110);
}

/**
 * Builds the 25-question English set. Returns the questions in their final order, or [] when fewer than 25
 * checked questions could be collected (the set is then NOT published; the retry run tries again).
 *
 *   previous: texts / passage openings of the last two months (never repeated)
 *   callGemini(prompt, key, temperature) -> text   (injected, so this file needs no network by itself)
 */
async function generateEnglishSet({ monthKey, previous = [], key, callGemini, rnd = Math.random, log = console }) {
  const kept = Object.fromEntries(SECTIONS.map((s) => [s.id, []]));
  const seenTexts = new Set(previous.map((t) => t.toLowerCase())); // plain texts of earlier months; passage questions use dedupeKey()
  let groupCounter = 0;

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    const needy = SECTIONS.filter((s) => kept[s.id].length < s.target);
    if (!needy.length) break;
    const plan = pickPlan(`${monthKey}|round${round}`);
    const avoid = [...new Set([...previous, ...Object.values(kept).flat().map((it) => avoidLabel(it.q))])].slice(0, 40);
    const pending = [];

    for (const section of needy) {
      const need = section.target - kept[section.id].length;
      let n = round === 1 ? section.ask : Math.min(section.ask, need + 2);
      let kinds;
      if (section.id === "misc") {
        const missing = MISC_TYPES.filter((t) => !kept.misc.some((it) => it.subtype === t));
        kinds = round === 1 ? [...MISC_TYPES, "connector", "paracomp"] : [...missing, ...MISC_TYPES].slice(0, Math.max(need + 1, 2));
        n = kinds.length;
      }
      if (section.id === "cloze") n = Math.min(section.ask, need); // exactly as many blanks as questions still missing
      try {
        const items = await writeSection({ section, n, plan, avoid, kinds, key, callGemini, rnd, groupBase: ++groupCounter });
        let fresh = 0;
        for (const it of items) {
          const k = it.q.passage ? dedupeKey(it.q) : oneLineText(it.q.text).toLowerCase();
          if (seenTexts.has(k)) continue;
          seenTexts.add(k);
          pending.push(it);
          fresh++;
        }
        log.log(`  round ${round}: ${section.id}: ${fresh} well-formed question(s) (asked ${n}).`);
      } catch (err) {
        log.warn(`  round ${round}: ${section.id} failed: ${err.message}`);
      }
    }
    if (!pending.length) continue;

    try {
      const removeA = parseRemove(await callGemini(buildCheckPrompt(pending), key, 0));
      const answers = parseSolve(await callGemini(buildSolvePrompt(pending), key, 0));
      const removeB = solveRejections(pending, answers);
      const drop = new Set([...removeA, ...removeB]);
      log.log(`  round ${round}: check A removed ${new Set(removeA).size}, check B removed ${removeB.length}, ${pending.length - drop.size} of ${pending.length} survive.`);

      // Cloze repair: fill the blanks whose question was removed, in every question of that passage.
      const clozeGroups = new Map();
      pending.forEach((it, i) => {
        if (it.section !== "cloze") return;
        const g = clozeGroups.get(it.groupId) || { passage: it.q.passage, filled: new Set() };
        if (drop.has(i + 1)) {
          g.passage = fillBlank(g.passage, it.blankNo, it.q.options[it.q.correctIndex]);
          g.filled.add(it.blankNo);
        }
        clozeGroups.set(it.groupId, g);
      });

      pending.forEach((it, i) => {
        if (drop.has(i + 1)) return;
        if (it.section === "cloze") it.q = { ...it.q, passage: clozeGroups.get(it.groupId).passage };
        kept[it.section].push(it);
      });
    } catch (err) {
      log.warn(`  round ${round}: checks failed, round lost: ${err.message}`);
    }
  }

  return assemble(kept);
}

/** Takes `target` questions per section, tops up from leftovers of other sections, and returns stored questions. */
function assemble(kept) {
  const chosen = [];
  const leftovers = [];
  for (const s of SECTIONS) {
    chosen.push(...kept[s.id].slice(0, s.target).map((it) => ({ section: s.id, it })));
    leftovers.push(...kept[s.id].slice(s.target).map((it) => ({ section: s.id, it })));
  }
  // Prefer self-contained leftovers (no passage) when a section is short.
  leftovers.sort((a, b) => Number(Boolean(a.it.q.passage)) - Number(Boolean(b.it.q.passage)));
  for (const l of leftovers) {
    if (chosen.length >= SET_SIZE) break;
    chosen.push(l);
  }
  if (chosen.length < SET_SIZE) return [];

  const order = SECTIONS.map((s) => s.id);
  chosen.sort((a, b) => order.indexOf(a.section) - order.indexOf(b.section)); // stable: keeps passage questions together
  return chosen.slice(0, SET_SIZE).map(({ it }) => toStored(it.q));
}

function toStored(q) {
  const out = { text: q.text, options: q.options, correctIndex: q.correctIndex, explanation: q.explanation };
  if (q.passage) out.passage = q.passage;
  return out;
}

/** Strings from earlier English sets that the new set must not repeat (first line of each question + passage openings). */
function previousFromSets(setDocs) {
  const texts = [];
  const seenPassages = new Set();
  for (const data of setDocs) {
    for (const q of (data && data.questions) || []) {
      const p = oneLineText(q && q.passage).slice(0, 90);
      if (p) {
        if (!seenPassages.has(p)) {
          seenPassages.add(p);
          texts.push(`Passage starting: "${p}..."`);
        }
        continue; // the question wording of a passage question is generic; the passage is what must not come back
      }
      const t = oneLineText(q && q.text);
      if (t) texts.push(t);
    }
  }
  return texts;
}

module.exports = {
  SECTIONS,
  SET_SIZE,
  MAX_ROUNDS,
  generateEnglishSet,
  previousFromSets,
  buildSectionPrompt,
  buildCheckPrompt,
  buildSolvePrompt,
  pickPlan,
  cleanFib,
  cleanError,
  cleanImprove,
  cleanJumble,
  cleanMisc,
  cleanGroup,
  parseRemove,
  parseSolve,
  solveRejections,
  fillBlank,
  assemble,
};

/**
 * Bilingual Banking PO / Clerk Quantitative Aptitude mock generator (Moderate to Hard, PO exam level).
 *
 * Generates 15 verified bilingual (English + Hindi) MCQs per sub-folder inside Mock Tests > Banking PO/Clerk > Quant:
 *   1. Speed Maths          (5 Wrong/Missing Number Series + 5 Quadratic Equations + 5 Approximation/Simplification)
 *   2. Arithmetic           (15 PO-level word problems, Quantity I vs II, Data Sufficiency)
 *   3. Advanced Maths       (15 PO Mains / Regulatory level Mensuration, Number System, Algebra, P&C/Probability, AP/GP)
 *   4. Data Interpretation  (3 distinct DI sets x 5 questions = 15 Qs: Tabular/Missing-Value, Caselet, Mixed/Variable)
 *
 * Every question goes through 3 accuracy checks before it can be published:
 *   - Local structural + digit-parity validation (EN/HI numbers, 4 unique options, Devanagari check)
 *   - Check A: Strict Math Auditor (checks calculations, uniqueness of answer, explanation alignment)
 *   - Check B: Blind Math Re-Solver (solves independently WITHOUT seeing the answer key)
 *   - Check C: Bilingual EN-HI Proofreader (meaning, numbers, units, option order match)
 */
const { seededRandom } = require("./free-mcq-topics.js");

const LETTERS = ["A", "B", "C", "D"];
const QUESTIONS_PER_SUBFOLDER = 15;
const MAX_ROUNDS = 4;
const QUANT_TEMPERATURE = 0.35;
const DEVANAGARI_DIGITS = "\u0966\u0967\u0968\u0969\u096A\u096B\u096C\u096D\u096E\u096F";

const QUANT_SUBFOLDERS = [
  {
    id: "speed_maths",
    name: "Speed Maths",
    subject: "Quant / Speed Maths",
    emoji: "⚡",
    description: "Wrong & Missing Number Series, Quadratic Equations (Root Comparison), Approximation & Simplification — IBPS PO / SBI PO Moderate to Hard",
  },
  {
    id: "arithmetic",
    name: "Arithmetic",
    subject: "Quant / Arithmetic",
    emoji: "🧮",
    description: "PO Prelims & Mains Word Problems: Profit-Loss, CI/SI, Time & Work, TSD, Mixture, Partnership, Ratio, Probability, Quantity I vs II",
  },
  {
    id: "advanced_maths",
    name: "Advanced Maths",
    subject: "Quant / Advanced Maths",
    emoji: "📐",
    description: "PO Mains Level Mensuration 2D/3D, Number System & Divisibility, Algebra, Surds & Indices, AP/GP, P&C, Probability & Geometry",
  },
  {
    id: "data_interpretation",
    name: "Data Interpretation",
    subject: "Quant / Data Interpretation",
    emoji: "📊",
    description: "3 PO-level DI Sets (5 Qs each): Tabular / Missing-Value DI, Caselet DI, and Mixed Percentage-Ratio-Variable DI",
  },
];

const ARITHMETIC_TOPICS = [
  "Profit, Loss, Marked Price and Successive Discounts",
  "Compound Interest and Simple Interest (difference, instalments, variable rates)",
  "Time and Work (efficiency ratios, alternate days, leaving before completion)",
  "Pipes and Cisterns (inlet/outlet leaks and fractional capacity)",
  "Time, Speed and Distance (relative speed, trains, stoppages)",
  "Boats and Streams (upstream/downstream multi-trip equations)",
  "Mixture and Alligation (successive replacement and concentration)",
  "Partnership (time-weighted capital and active partner salary/commission)",
  "Ratio, Proportion and Ages (multi-year shifts and weighted ratios)",
  "Percentage, Election, Income-Expenditure and Population",
  "Averages and Weighted Averages (replacement and group splits)",
  "Quantity I vs Quantity II comparison (banking PO Mains arithmetic)",
  "Data Sufficiency (2 statements — banking PO arithmetic)",
];

const ADVANCED_TOPICS = [
  "Mensuration 2D (composite shapes: inscribed circles, paths, sectors, trapezium)",
  "Mensuration 3D (melting and recasting with wastage: cylinder, cone, sphere, frustum, hollow prism)",
  "Number System (divisibility rules, remainders, unit digit, factors, HCF/LCM conditions)",
  "Algebra and Quadratic/Cubic Identities (symmetric expressions, roots relationship)",
  "Surds, Indices and Exponential Equations",
  "Arithmetic Progression (AP) and Geometric Progression (GP) word problems",
  "Permutation and Combination (conditional arrangements, committee selection, circular seating)",
  "Probability (cards, balls without replacement, conditional and complementary events)",
  "Coordinate Geometry and Geometry basics (triangles, circles, chords, tangents)",
];

const DI_SET_SPECS = [
  {
    id: "tabular",
    label: "Tabular / Missing-Value DI",
    promptHint: "Create a structured Tabular Data Interpretation set (4 to 5 bank branches, companies, or years; 2 to 3 columns such as Total Units, Percentage of Category A, Ratio of B:C, or Revenue/Expenditure). Format the table neatly using clean plain-text lines (e.g. 'Branch A: Total = 480, Savings = 62.5%, Active = 80%') so it reads clearly on a mobile screen in both English and Hindi. Include multi-step percentage change, weighted average, ratio, and conditional difference questions.",
  },
  {
    id: "caselet",
    label: "Caselet DI (Ratio, Percentage & Venn Logic)",
    promptHint: "Create a crisp PO-level Caselet Data Interpretation paragraph (80 to 130 words) about 3 departments, products, or exam shifts with exact linked ratios, percentages, and totals that resolve cleanly to whole numbers. Every derived number must be an exact integer. Ask 5 moderate-to-hard questions requiring students to first decode the full table from the caselet.",
  },
  {
    id: "mixed",
    label: "Mixed Variable & Comparative DI",
    promptHint: "Create a PO Mains-style Data Interpretation set combining summary data (e.g. 4 quarterly periods or 5 stores with Total Sales, Profit %, and Male:Female or Online:Offline split, including 1 derived variable x whose value is uniquely fixed by a given total or average). Format cleanly line-by-line for mobile screens. Ask 5 moderate-to-hard analytical questions.",
  },
];

// ---------------------------------------------------------------- helpers

const hasDevanagari = (s) => /[\u0900-\u097F]/.test(String(s || ""));
const oneLine = (s) => String(s == null ? "" : s).replace(/\s+/g, " ").trim();

function tidyMultiline(s) {
  return String(s == null ? "" : s)
    .replace(/\r/g, "")
    .split("\n")
    .map((l) => l.replace(/[ \t]+/g, " ").trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function shuffled(arr, rnd) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function numbersIn(text) {
  const t = String(text || "")
    .replace(/[\u0966-\u096F]/g, (c) => String(DEVANAGARI_DIGITS.indexOf(c)))
    .replace(/(\d),(?=\d)/g, "$1");
  return t.match(/\d+(?:\.\d+)?/g) || [];
}

function numbersCovered(en, hi) {
  const have = new Set(numbersIn(hi));
  return numbersIn(en).every((n) => have.has(n));
}

function parseJsonLoose(text) {
  const t = String(text || "")
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/, "")
    .trim();
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

function avoidBlock(previous) {
  if (!previous || !previous.length) return "";
  return `\n\nDO NOT repeat or closely paraphrase these earlier questions:\n${previous.slice(0, 40).map((t) => `- ${t}`).join("\n")}`;
}

// ---------------------------------------------------------------- prompts

const QUANT_COMMON_RULES = `You are a senior Quantitative Aptitude question-setter for Indian Banking PO exams (IBPS PO, SBI PO, RRB PO Prelims & Mains).
DIFFICULTY LEVEL: Strictly MODERATE TO HARD (IBPS PO / SBI PO exam standard). Avoid trivial school-level one-liners; every question should require 2 to 4 clear logical/calculation steps and feel genuinely exam-oriented.

ACCURACY & FORMAT RULES (most important):
1. Mathematical perfection: solve every problem completely BEFORE writing options. Double-check every arithmetic step, percentage, ratio, sign, and unit. All final answers must be exact (clean integers, exact fractions, or clearly stated rounded decimals).
2. Exactly 4 options ("options" in English, "optionsHi" in Hindi, in the EXACT SAME ORDER). Exactly ONE option is correct. The 3 distractors must be plausible calculation traps, NEVER equal to the correct answer.
3. Never use "All of the above", "Both A and B", or options referring to other option letters.
4. Write all numbers, percentages, ratios, and symbols in standard Arabic digits (0-9) in BOTH English and Hindi (e.g., 16, 62.5%, 7 : 5, ₹4,800). Never write numbers as words in one language and digits in the other.
5. "text": English question (clear, exam-style, no Devanagari). "textHi": exact, natural exam-paper Hindi translation in Devanagari script with identical numbers, variable names (x, y, A, B), and meaning.
6. "explanation": concise step-by-step English solution (max 85 words) showing the exact math leading to "correctIndex". "explanationHi": exact Hindi translation of the step-by-step solution (max 110 words).
7. Spread "correctIndex" (0-3) across all four positions.
8. Return ONLY valid JSON. No markdown fences or commentary.`;

function buildSpeedMathsPrompt({ n, periodLabel, previous }) {
  const s1 = Math.ceil(n / 3);
  const s2 = Math.ceil((n - s1) / 2);
  const s3 = n - s1 - s2;
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Speed Maths (${periodLabel})
Write exactly ${n} bilingual questions split cleanly as:
- ${s1} questions on Wrong Number Series or Missing Number Series (PO Moderate-to-Hard patterns: decimal multipliers like ×0.5+2, ×1.5+3; double-difference cubes/squares; alternating prime/power operations). Every term must follow one unambiguous rule.
- ${s2} questions on Quadratic Equations (given two equations I in x and II in y with moderately large or decimal/fractional coefficients, ask the relationship between x and y). The 4 options must be exact standard comparisons (e.g. "x > y", "x < y", "x >= y", "x <= y or no relation established" / matching Hindi). Verify both roots of both equations carefully!
- ${s3} questions on Approximation & Simplification (multi-step BODMAS with percentages, squares/cubes, square roots, fractions — PO exam level). For approximation questions, clearly state "Find the approximate value of ?" and ensure distractors are spaced far enough apart that only ONE option is indisputably closest.

Return ONLY a JSON array of ${n} objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(previous)}`;
}

function buildArithmeticPrompt({ n, periodLabel, topicList, previous }) {
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Arithmetic (${periodLabel})
Write exactly ${n} original Moderate-to-Hard Banking PO word problems spread across these topics (at most 2 questions per topic):
${topicList.map((t, i) => `${i + 1}. ${t}`).join("\n")}

REQUIREMENTS:
- Mix multi-concept PO Prelims & Mains style problems (e.g. mixture with two replacements, CI-SI with variable rates, efficiency ratio + time & work, boat + relative speed, and 2–3 Quantity I vs Quantity II or Data Sufficiency questions).
- Ensure every word problem has a unique, clean mathematical solution with zero ambiguity.

Return ONLY a JSON array of ${n} objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(previous)}`;
}

function buildAdvancedMathsPrompt({ n, periodLabel, topicList, previous }) {
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Advanced Maths (${periodLabel})
Write exactly ${n} original Moderate-to-Hard Banking PO Mains / Regulatory-exam level Quantitative questions spread across these topics (at most 2 questions per topic):
${topicList.map((t, i) => `${i + 1}. ${t}`).join("\n")}

REQUIREMENTS:
- Use π = 22/7 where needed and state it if required, or express cleanly so results are exact integers or exact fractions.
- Keep notation clean in plain Unicode (², ³, √, π, ≥, ≤) without LaTeX backslashes so it renders cleanly in mobile app text.

Return ONLY a JSON array of ${n} objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(previous)}`;
}

function buildDiSetPrompt({ spec, periodLabel, previous, n = 5 }) {
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Data Interpretation (${spec.label}, ${periodLabel})
TASK:
1. ${spec.promptHint}
2. Write "passage" (English directions + structured data) and "passageHi" (exact Hindi Devanagari translation with identical numbers, branch/item labels, and structure). Use newline characters (\\n) for clean line breaks.
3. Write exactly ${n} Moderate-to-Hard Banking PO questions strictly answerable from this passage alone. Mix ratio, percentage more/less, average, conditional change, and difference questions.
4. Keep every question self-contained with the passage (students see the passage box right above each question).

Return ONLY a JSON object:
{
  "passage": "...",
  "passageHi": "...",
  "questions": [
    { "text": "...", "textHi": "...", "options": [4 strings], "optionsHi": [4 strings], "correctIndex": 0-3, "explanation": "...", "explanationHi": "..." }
  ]
}${avoidBlock(previous)}`;
}

// ---------------------------------------------------------------- verification prompts (Check A, B, C)

function formatQuestionsForCheck(questions, { withAnswer = false, withPassage = false } = {}) {
  return questions
    .map((q, i) => {
      const opts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join("  |  ");
      const p = withPassage && q.passage ? `\n   Data/Directions:\n   ${q.passage.replace(/\n/g, "\n   ")}` : "";
      const ans = withAnswer ? `\n   Marked correct: ${LETTERS[q.correctIndex]}\n   Explanation: ${q.explanation}` : "";
      return `Q${i + 1}:${p}\n   Question: ${q.text}\n   Options: ${opts}${ans}`;
    })
    .join("\n\n");
}

function buildMathAuditPrompt(questions) {
  return `You are a ruthless Banking PO Quantitative Aptitude auditor. Re-calculate EVERY question below from scratch.

REMOVE a question if ANY of these is true:
- there is ANY arithmetic, algebraic, formula, rounding, or logical error in the solution or marked answer;
- the marked correct option does NOT match the true mathematical result;
- more than one option could be considered correct, or none of the 4 options matches;
- a Number Series rule is forced/ambiguous, or Quadratic roots/comparison are wrong;
- a Data Interpretation question contradicts the given data or requires unstated assumptions;
- the question uses broken LaTeX syntax (like \\frac or \\sqrt) instead of clean readable text.
When in doubt, REMOVE. KEEP only mathematically airtight questions.

Return ONLY JSON: {"remove": [1, 4]} (or {"remove": []} if all are 100% correct). No markdown.

QUESTIONS:
${formatQuestionsForCheck(questions, { withAnswer: true, withPassage: true })}`;
}

function buildBlindMathSolvePrompt(questions) {
  return `You are a Banking PO Quantitative Aptitude topper. Solve EVERY question below independently from scratch WITHOUT guessing.
For each question, pick the letter (A, B, C, or D) of the exact answer and set "sure": true ONLY if your step-by-step calculation matches that option uniquely and unambiguously. Set "sure": false if the data is inconsistent, ambiguous, or does not match any option cleanly.

Return ONLY JSON: {"answers": [{"q": 1, "answer": "B", "sure": true}]} with one entry per question. No markdown.

QUESTIONS:
${formatQuestionsForCheck(questions, { withAnswer: false, withPassage: true })}`;
}

function buildBilingualQuantCheckPrompt(questions) {
  const lines = questions
    .map((q, i) => {
      const enOpts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const hiOpts = q.optionsHi.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const pass = q.passage ? `\n   EN Data: ${q.passage}\n   HI Data: ${q.passageHi}` : "";
      return `Q${i + 1}:${pass}\n   EN: ${q.text}\n   EN Options: ${enOpts}\n   EN Exp: ${q.explanation}\n   HI: ${q.textHi}\n   HI Options: ${hiOpts}\n   HI Exp: ${q.explanationHi}\n   Marked: ${LETTERS[q.correctIndex]}`;
    })
    .join("\n\n");

  return `You are a strict English-Hindi proofreader for Indian Banking PO Quant exam papers.
REMOVE a question if ANY of these is true:
- the Hindi question, Hindi data/passage, Hindi option, or Hindi explanation differs in meaning, mathematical condition, ratio, unit, or number from the English version;
- the Hindi options are not in the exact same order as the English options;
- the Hindi has unnatural/broken phrasing that could mislead a math student.
KEEP the question otherwise.

Return ONLY JSON: {"remove": [2]} (or {"remove": []} if none). No markdown.

QUESTIONS:
${lines}`;
}

// ---------------------------------------------------------------- local cleaning

function cleanQuantQuestion(raw, { passage = "", passageHi = "", rnd = Math.random } = {}) {
  if (!raw || typeof raw !== "object") return null;
  const text = tidyMultiline(raw.text);
  const textHi = tidyMultiline(raw.textHi);
  const explanation = oneLine(raw.explanation);
  const explanationHi = oneLine(raw.explanationHi);
  const pEn = tidyMultiline(passage || raw.passage || "");
  const pHi = tidyMultiline(passageHi || raw.passageHi || "");

  if (!Array.isArray(raw.options) || !Array.isArray(raw.optionsHi)) return null;
  const options = raw.options.map(oneLine);
  const optionsHi = raw.optionsHi.map(oneLine);
  const ci = Number(raw.correctIndex);

  if (text.length < 10 || text.length > 750 || hasDevanagari(text)) return null;
  if (textHi.length < 8 || textHi.length > 950 || !hasDevanagari(textHi)) return null;
  if (explanation.length < 10 || explanation.length > 700 || hasDevanagari(explanation)) return null;
  if (explanationHi.length < 10 || explanationHi.length > 900 || !hasDevanagari(explanationHi)) return null;
  if (options.length !== 4 || optionsHi.length !== 4) return null;
  if (options.some((o) => o.length < 1 || o.length > 140)) return null;
  if (optionsHi.some((o) => o.length < 1 || o.length > 180)) return null;
  if (new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  if (!Number.isInteger(ci) || ci < 0 || ci > 3) return null;

  // Reject raw LaTeX backslashes that look ugly in Flutter plain Text widgets.
  const combined = `${text} ${options.join(" ")} ${explanation} ${pEn}`;
  if (/\\(?:frac|sqrt|times|div|le|ge|pi|cdot)\b/.test(combined)) return null;

  // Digit parity between English and Hindi.
  if (!numbersCovered(text, textHi) || !numbersCovered(explanation, explanationHi)) return null;
  if (options.some((o, i) => !numbersCovered(o, optionsHi[i]))) return null;
  if (pEn) {
    if (!pHi || hasDevanagari(pEn) || !hasDevanagari(pHi)) return null;
    if (!numbersCovered(pEn, pHi)) return null;
  }

  // Shuffle options randomly so answer keys are evenly distributed across A-D.
  const order = shuffled([0, 1, 2, 3], rnd);
  const out = {
    text,
    textHi,
    options: order.map((i) => options[i]),
    optionsHi: order.map((i) => optionsHi[i]),
    correctIndex: order.indexOf(ci),
    explanation,
    explanationHi,
  };
  if (pEn) {
    out.passage = pEn;
    out.passageHi = pHi;
  }
  return out;
}

// ---------------------------------------------------------------- verification runner

async function verifyBatch(candidates, { key, callGemini }) {
  if (!candidates.length) return [];

  // Check A: Math & Logic Audit
  const auditRaw = await callGemini(buildMathAuditPrompt(candidates), key, 0.0);
  const auditObj = parseJsonLoose(auditRaw);
  const dropA = new Set((Array.isArray(auditObj?.remove) ? auditObj.remove : []).map(Number));
  let list = candidates.filter((_, i) => !dropA.has(i + 1));
  if (!list.length) return [];

  // Check B: Blind Math Re-Solve
  const solveRaw = await callGemini(buildBlindMathSolvePrompt(list), key, 0.0);
  const solveObj = parseJsonLoose(solveRaw);
  const ansList = Array.isArray(solveObj?.answers) ? solveObj.answers : [];
  const ansMap = new Map();
  for (const e of ansList) {
    const qNum = Number(e?.q);
    const letter = String(e?.answer || "").trim().toUpperCase().charAt(0);
    if (Number.isInteger(qNum) && LETTERS.includes(letter)) {
      ansMap.set(qNum, { letter, sure: e?.sure === true });
    }
  }
  list = list.filter((q, i) => {
    const a = ansMap.get(i + 1);
    return a && a.sure && a.letter === LETTERS[q.correctIndex];
  });
  if (!list.length) return [];

  // Check C: Bilingual EN-HI Proofread
  const biRaw = await callGemini(buildBilingualQuantCheckPrompt(list), key, 0.0);
  const biObj = parseJsonLoose(biRaw);
  const dropC = new Set((Array.isArray(biObj?.remove) ? biObj.remove : []).map(Number));
  return list.filter((_, i) => !dropC.has(i + 1));
}

// ---------------------------------------------------------------- public generators

async function generateStandaloneSubfolder({ subfolder, periodKey, periodLabel, previous = [], key, callGemini, target = QUESTIONS_PER_SUBFOLDER }) {
  const rnd = seededRandom(`banking_quant|${subfolder.id}|${periodKey}`);
  const kept = [];
  const seen = new Set(previous.map((t) => oneLine(t).toLowerCase()));

  for (let round = 1; round <= MAX_ROUNDS && kept.length < target; round++) {
    const need = target - kept.length;
    const ask = round === 1 ? Math.max(need + 7, 22) : Math.min(20, need + 6);
    const avoid = [...previous, ...kept.map((q) => q.text)];
    const roundRnd = seededRandom(`banking_quant|${subfolder.id}|${periodKey}|r${round}`);

    let prompt;
    if (subfolder.id === "speed_maths") {
      prompt = buildSpeedMathsPrompt({ n: ask, periodLabel, previous: avoid });
    } else if (subfolder.id === "arithmetic") {
      const topicList = shuffled(ARITHMETIC_TOPICS, roundRnd).slice(0, 10);
      prompt = buildArithmeticPrompt({ n: ask, periodLabel, topicList, previous: avoid });
    } else {
      const topicList = shuffled(ADVANCED_TOPICS, roundRnd).slice(0, 9);
      prompt = buildAdvancedMathsPrompt({ n: ask, periodLabel, topicList, previous: avoid });
    }

    try {
      const rawText = await callGemini(prompt, key, QUANT_TEMPERATURE);
      const parsed = parseJsonLoose(rawText);
      const arr = Array.isArray(parsed) ? parsed : Array.isArray(parsed?.questions) ? parsed.questions : [];
      const cleaned = [];
      for (const item of arr) {
        const q = cleanQuantQuestion(item, { rnd });
        if (!q) continue;
        const k = q.text.toLowerCase();
        if (seen.has(k)) continue;
        seen.add(k);
        cleaned.push(q);
      }
      if (!cleaned.length) continue;

      const verified = await verifyBatch(cleaned, { key, callGemini });
      for (const q of verified) {
        if (kept.length < target) kept.push(q);
      }
      console.log(`  [${subfolder.id}] round ${round}: cleaned=${cleaned.length}, verified=${verified.length}, total=${kept.length}/${target}`);
    } catch (err) {
      console.warn(`  [${subfolder.id}] round ${round} failed: ${err.message}`);
    }
  }

  return kept.length >= target ? kept.slice(0, target) : [];
}

async function generateDiSubfolder({ periodKey, periodLabel, previous = [], key, callGemini, target = QUESTIONS_PER_SUBFOLDER }) {
  const rnd = seededRandom(`banking_quant|data_interpretation|${periodKey}`);
  const allQuestions = [];
  const perSet = 5;

  for (let sIdx = 0; sIdx < DI_SET_SPECS.length && allQuestions.length < target; sIdx++) {
    const spec = DI_SET_SPECS[sIdx];
    let setQuestions = [];

    for (let round = 1; round <= MAX_ROUNDS && setQuestions.length < perSet; round++) {
      try {
        const avoid = [...previous, ...allQuestions.map((q) => q.text)];
        const prompt = buildDiSetPrompt({ spec, periodLabel, previous: avoid, n: perSet + 2 });
        const rawText = await callGemini(prompt, key, QUANT_TEMPERATURE);
        const parsed = parseJsonLoose(rawText);
        const passage = tidyMultiline(parsed?.passage || "");
        const passageHi = tidyMultiline(parsed?.passageHi || "");
        const rawQs = Array.isArray(parsed?.questions) ? parsed.questions : [];
        if (!passage || !passageHi || rawQs.length < perSet) continue;

        const cleaned = [];
        const seen = new Set(avoid.map((t) => oneLine(t).toLowerCase()));
        for (const item of rawQs) {
          const q = cleanQuantQuestion(item, { passage, passageHi, rnd });
          if (!q) continue;
          const k = q.text.toLowerCase();
          if (seen.has(k)) continue;
          seen.add(k);
          cleaned.push(q);
        }
        if (cleaned.length < perSet) continue;

        const verified = await verifyBatch(cleaned, { key, callGemini });
        console.log(`  [data_interpretation/${spec.id}] round ${round}: cleaned=${cleaned.length}, verified=${verified.length}/${perSet}`);
        if (verified.length >= perSet) {
          setQuestions = verified.slice(0, perSet);
        }
      } catch (err) {
        console.warn(`  [data_interpretation/${spec.id}] round ${round} failed: ${err.message}`);
      }
    }

    if (setQuestions.length < perSet) {
      console.error(`  [data_interpretation/${spec.id}] could not verify ${perSet} questions; aborting DI set.`);
      return [];
    }
    allQuestions.push(...setQuestions);
  }

  return allQuestions.length >= target ? allQuestions.slice(0, target) : [];
}

async function generateQuantSubfolder({ subfolder, periodKey, periodLabel, previous = [], key, callGemini }) {
  if (subfolder.id === "data_interpretation") {
    return generateDiSubfolder({ periodKey, periodLabel, previous, key, callGemini });
  }
  return generateStandaloneSubfolder({ subfolder, periodKey, periodLabel, previous, key, callGemini });
}

module.exports = {
  QUANT_SUBFOLDERS,
  QUESTIONS_PER_SUBFOLDER,
  ARITHMETIC_TOPICS,
  ADVANCED_TOPICS,
  DI_SET_SPECS,
  numbersIn,
  numbersCovered,
  cleanQuantQuestion,
  parseJsonLoose,
  generateQuantSubfolder,
};

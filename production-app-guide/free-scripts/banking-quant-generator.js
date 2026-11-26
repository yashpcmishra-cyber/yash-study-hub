/**
 * Bilingual Banking PO / Clerk Quantitative Aptitude mock generator (Moderate to Hard, PO exam level).
 *
 * Generates 15 verified bilingual (English + Hindi) MCQs per sub-folder inside Mock Tests > Banking PO/Clerk > Quant:
 *   1. Speed Maths          (5 Wrong/Missing Number Series + 5 Quadratic Equations + 5 Approximation/Simplification)
 *   2. Arithmetic           (15 PO-level word problems INCLUDING 5+ trending Variable-Based PO questions, Quantity I vs II & DS)
 *   3. Advanced Maths       (15 PO Mains / Regulatory level Mensuration, Number System, Algebra, P&C/Probability, AP/GP)
 *   4. Data Interpretation  (3 distinct DI sets x 5 questions = 15 Qs: Grouped Bar Graph, Line/Pie Graph, Variable/Missing Table)
 *                           Each DI set renders a crisp high-DPI PNG graph/table image (`passageImage`) alongside bilingual Directions!
 *
 * Every question goes through 4 strict cross-checks before publishing:
 *   - Local validator: 4 unique options, EN/HI digit parity, Devanagari check, no raw LaTeX, strict DI chart JSON validation
 *   - Check A: Ruthless Math, Data & Logic Auditor (audits chart + passage + variable constraints + step-by-step calculation)
 *   - Check B: Independent Blind Math Re-Solver (solves from scratch WITHOUT seeing answer key or explanation)
 *   - Check C: Bilingual EN-HI Language & Data Proofreader (grammar, terminology, variable names, numbers, option order)
 */
const { seededRandom } = require("./free-mcq-topics.js");
const { validateChartSpec, chartToTextSummary, renderChartPng, uploadDiChartPng } = require("./di-chart-renderer.js");

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
    description: "PO Prelims & Mains Word Problems + Trending Variable-Based Questions (x, y, P, k): Profit-Loss, CI/SI, Time & Work, TSD, Mixture, Partnership, Ratio, Quantity I vs II",
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
    description: "3 Graph-Backed PO DI Sets (5 Qs each): Grouped Bar Graph DI, Line/Pie Graph DI, and Variable/Missing-Value Table DI with Zoomable Chart Images",
  },
];

const ARITHMETIC_TOPICS = [
  "Variable-based Profit, Loss, Marked Price & Discount (e.g. CP in terms of x, markup (x+10)%, find x or expression)",
  "Variable-based Compound & Simple Interest (variable Principal P, variable Rate R% or Time T, SI-CI difference)",
  "Variable-based Mixture & Replacement (initial quantity or x litres replaced, final ratio given, find x)",
  "Variable-based Time & Work / Pipes (efficiency ratio (x+2):x or variable days d, alternate work)",
  "Variable-based Time, Speed, Distance / Trains & Boats (variable speed v or length L, relative speed)",
  "Variable-based Partnership & Ages (variable investment/months or present age in terms of x)",
  "Profit, Loss & Successive Discounts (multi-stage PO Prelims/Mains word problem)",
  "Compound Interest & Simple Interest (instalments, half-yearly/variable annual rates)",
  "Time & Work and Pipes & Cisterns (leaving before completion, efficiency changes)",
  "Boats & Streams and Trains (upstream/downstream multi-trip equations)",
  "Ratio, Proportion, Percentage & Election / Income-Expenditure",
  "Averages & Weighted Averages (replacement and group splits)",
  "Quantity I vs Quantity II comparison (banking PO Mains arithmetic with variables)",
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

function getDiSetSpecs(periodKey) {
  const weekNum = Number((/W(\d+)$/.exec(String(periodKey || "")) || [])[1]) || 1;
  const secondType = weekNum % 2 === 0 ? "pie" : "line";
  return [
    {
      id: "grouped_bar",
      chartType: "grouped_bar",
      label: "Grouped Bar Graph DI",
      promptHint: `Create a PO Moderate-to-Hard Grouped Bar Graph DI across 4 or 5 Bank Branches/Companies/Years with exactly 2 numeric series (e.g., "Savings Accounts" and "Current Accounts", or "Male Employees" and "Female Employees", or "Target" and "Achieved").
Return a valid "chart" JSON object:
{ "type": "grouped_bar", "title": "<clear English chart title>", "titleHi": "<exact Hindi title>", "subtitle": "<unit or note, e.g. Values in hundreds / संख्या सैकड़ों में>", "yLabel": "<Y-axis label>", "unit": "", "labels": ["Branch A", "Branch B", ...], "series": [{"name": "Series 1", "values": [num, ...]}, {"name": "Series 2", "values": [num, ...]}] }
Keep all values clean integers that divide cleanly in percentages and ratios.`,
    },
    {
      id: secondType,
      chartType: secondType,
      label: secondType === "pie" ? "Pie Chart DI" : "Multi-Line Graph DI",
      promptHint:
        secondType === "pie"
          ? `Create a PO Moderate-to-Hard Pie Chart DI showing percentage distribution across 5 categories (e.g., 5 Bank Branches, 5 Loan Categories, or 5 Exam Centres). The 5 percentage values MUST sum to EXACTLY 100. State the exact Total value (e.g. Total Loans = 4,800) clearly in both "subtitle" and "passage"/"passageHi" (plus any secondary ratio per category if needed for multi-step PO Mains questions).
Return a valid "chart" JSON object:
{ "type": "pie", "title": "<English title>", "titleHi": "<Hindi title>", "subtitle": "Total = <exact integer>", "yLabel": "", "unit": "%", "labels": ["Cat A", "Cat B", "Cat C", "Cat D", "Cat E"], "series": [{"name": "Share", "values": [p1, p2, p3, p4, p5]}] }`
          : `Create a PO Moderate-to-Hard Multi-Line Graph DI across 5 consecutive Years or Months with 2 numeric series (e.g., "Revenue (₹ Lakh)" and "Expenditure (₹ Lakh)", or "Online Sales" and "Offline Sales").
Return a valid "chart" JSON object:
{ "type": "line", "title": "<English title>", "titleHi": "<Hindi title>", "subtitle": "<units note>", "yLabel": "<Y-axis label>", "unit": "", "labels": ["2021", "2022", "2023", "2024", "2025"], "series": [{"name": "Series 1", "values": [n1, n2, n3, n4, n5]}, {"name": "Series 2", "values": [m1, m2, m3, m4, m5]}] }`,
    },
    {
      id: "variable_table",
      chartType: "table",
      label: "Variable / Missing-Value Table DI",
      promptHint: `Create a PO Mains-style Variable / Missing-Value Table DI across 4 or 5 entities (Branches, Stores, or Shifts) and 3 or 4 columns (e.g., Entity, Total Units, % of Category A, Ratio A:B). Include 1 or 2 missing/variable cells (like "x" or "—") whose values are uniquely determined from a clean Total/Average note in "passage" and "passageHi".
Return a valid "chart" JSON object:
{ "type": "table", "title": "<English title>", "titleHi": "<Hindi title>", "subtitle": "<short note>", "headers": ["Branch", "Total", "Savings %", "Active Ratio"], "rows": [["A", "480", "62.5%", "3 : 2"], ...] }`,
    },
  ];
}

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


const SUP_MAP = { "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻", "+": "⁺", "n": "ⁿ", "x": "ˣ" };

/** Converts ASCII math shorthand (^2, ^3, sqrt, cbrt, *, >=, <=, !=) into clean textbook math symbols. */
function formatMathText(str) {
  let s = String(str == null ? "" : str);
  if (!s) return s;
  s = s.replace(/\bsqrt\s*\(/gi, "√(").replace(/\bcbrt\s*\(/gi, "∛(");
  // Convert ^2, ^3, ^-1, ^n -> real Unicode superscripts when simple
  s = s.replace(/\^(-?[0-9]+|[nx])(?![0-9a-zA-Z])/g, (_, exp) =>
    exp.split("").map((c) => SUP_MAP[c] || c).join("")
  );
  s = s.replace(/>=/g, "≥").replace(/<=/g, "≤").replace(/!=/g, "≠");
  s = s.replace(/([\d\)\]xXyY²³⁴⁵⁶⁷⁸⁹⁰¹])\s*\*\s*([\d\(\[xXyY√∛])/g, "$1 × $2");
  s = s.replace(/([\d\)\]²³⁴⁵⁶⁷⁸⁹⁰¹])\s+\/\s+([\d\(\[√∛xXyY])/g, "$1 ÷ $2");
  return s;
}

function numbersIn(text) {
  const t = String(text || "")
    .replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]/g, (c) => String("⁰¹²³⁴⁵⁶⁷⁸⁹".indexOf(c)))
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
1. Mathematical perfection: solve every problem completely BEFORE writing options. Double-check every arithmetic step, variable constraint, percentage, ratio, sign, and unit. All final answers must be exact (clean integers, exact fractions, or clearly stated rounded decimals).
2. Exactly 4 options ("options" in English, "optionsHi" in Hindi, in the EXACT SAME ORDER). Exactly ONE option is correct. The 3 distractors must be plausible calculation traps, NEVER equal to the correct answer.
3. Never use "All of the above", "Both A and B", or options referring to other option letters.
4. Write all numbers, percentages, ratios, and symbols in standard Arabic digits (0-9) in BOTH English and Hindi (e.g., 16, 62.5%, 7 : 5, ₹4,800). Keep variable names (x, y, P, k, m, n, A, B) identical in BOTH English and Hindi.
5. "text": English question (clear, natural exam-style, no Devanagari). "textHi": exact, natural exam-paper Hindi translation in Devanagari script with identical numbers, variables, conditions, and meaning.
6. "explanation": concise step-by-step English solution (max 95 words) showing the exact math leading to "correctIndex". "explanationHi": exact Hindi translation of the step-by-step solution (max 120 words).
7. Spread "correctIndex" (0-3) across all four positions.
8. ALWAYS write real textbook math symbols: ², ³, √(625), ∛(729), ×, ÷, −, π, ≥, ≤, ≠, and clean fractions like 3/4 or (x+2)/5. NEVER write ASCII ^2, ^3, sqrt(), cbrt(), *, >=, <=, or LaTeX backslashes.
9. Return ONLY valid JSON. No markdown fences or commentary.`;

function buildSpeedMathsPrompt({ n, periodLabel, previous }) {
  const s1 = Math.ceil(n / 3);
  const s2 = Math.ceil((n - s1) / 2);
  const s3 = n - s1 - s2;
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Speed Maths (${periodLabel})
Write exactly ${n} bilingual questions split cleanly as:
- ${s1} questions on Wrong Number Series or Missing Number Series (PO Moderate-to-Hard patterns: decimal multipliers like ×0.5+2, ×1.5+3; double-difference cubes/squares; alternating prime/power operations). Every term must follow one unambiguous rule.
- ${s2} questions on Quadratic Equations (given two equations I in x and II in y with moderately large or decimal/fractional coefficients, ask the relationship between x and y). The 4 options must be exact standard comparisons (e.g. "x > y", "x < y", "x ≥ y", "x ≤ y or no relation established" / matching Hindi). Verify both roots of both equations carefully!
- ${s3} questions on Approximation & Simplification (multi-step BODMAS with percentages, squares/cubes, square roots, fractions — PO exam level). For approximation questions, clearly state "Find the approximate value of ?" and ensure distractors are spaced far enough apart that only ONE option is indisputably closest.

Return ONLY a JSON array of ${n} objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(previous)}`;
}

function buildArithmeticPrompt({ n, periodLabel, topicList, previous }) {
  const varCount = Math.max(5, Math.round(n * 0.38));
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Arithmetic (${periodLabel})
Write exactly ${n} original Moderate-to-Hard Banking PO word problems spread across these topics (at most 2 questions per topic):
${topicList.map((t, i) => `${i + 1}. ${t}`).join("\n")}

MANDATORY TRENDING PO MIX:
- At least ${varCount} of the ${n} questions MUST be **trending Variable-Based Banking PO questions** (IBPS PO / SBI PO 2025–2026 pattern) using variables like x, y, P, k, m, or n (for example: cost price/marked price in terms of x, variable rate R% or time T in CI/SI, x litres replaced in a mixture, efficiency ratio (x+2):x, or finding an expression like (2x + 5) once x is solved).
- Remaining questions should cover multi-concept PO Prelims & Mains word problems plus 2 Quantity I vs Quantity II or Data Sufficiency questions.
- Verify every variable equation has a unique, positive, realistic solution with zero ambiguity or negative lengths/ages/quantities.

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
- Include variable-based Mensuration / Algebra / Number System questions where appropriate.

Return ONLY a JSON array of ${n} objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(previous)}`;
}

function buildDiSetPrompt({ spec, periodLabel, previous, n = 5 }) {
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Data Interpretation (${spec.label}, ${periodLabel})
TASK:
1. ${spec.promptHint}
2. Write "passage" (English Directions + any Total/Note needed to decode the graph/table) and "passageHi" (exact Hindi Devanagari translation with identical numbers, labels, and conditions). Do NOT contradict a single number in "chart"! Keep directions crisp and exam-oriented ("Study the following graph/table carefully and answer the questions given below.").
3. Write exactly ${n} Moderate-to-Hard Banking PO questions strictly answerable from "chart" + "passage" alone. Mix ratio, percentage more/less, weighted average, conditional change, and difference questions.

Return ONLY a JSON object:
{
  "chart": { ... },
  "passage": "...",
  "passageHi": "...",
  "questions": [
    { "text": "...", "textHi": "...", "options": [4 strings], "optionsHi": [4 strings], "correctIndex": 0-3, "explanation": "...", "explanationHi": "..." }
  ]
}${avoidBlock(previous)}`;
}

function buildDiTopupPrompt({ spec, periodLabel, chartSummary, passage, passageHi, existingQuestions = [], n = 6 }) {
  return `${QUANT_COMMON_RULES}

SUB-FOLDER: Banking PO Quant — Data Interpretation (${spec.label}, ${periodLabel})
TASK:
Using the EXACT verified DI chart and directions below (do NOT change a single number or label), write ${n} NEW Moderate-to-Hard Banking PO questions strictly answerable from this chart + directions alone.
Mix ratio, percentage more/less, weighted average, conditional change, and difference questions. Every question must be completely distinct from the existing questions listed below.

VERIFIED CHART DATA:
${chartSummary}

ENGLISH DIRECTIONS:
${passage}

HINDI DIRECTIONS:
${passageHi}

Return ONLY a JSON array of ${n} question objects with keys:
text, textHi, options, optionsHi, correctIndex, explanation, explanationHi${avoidBlock(existingQuestions)}`;
}

// ---------------------------------------------------------------- verification prompts (Check A, B, C)

function formatQuestionsForCheck(questions, { withAnswer = false, withPassage = false, chartSummary = "" } = {}) {
  const header = chartSummary ? `${chartSummary}\n\n` : "";
  return (
    header +
    questions
      .map((q, i) => {
        const opts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join("  |  ");
        const p = withPassage && q.passage ? `\n   Directions:\n   ${q.passage.replace(/\n/g, "\n   ")}` : "";
        const ans = withAnswer ? `\n   Marked correct: ${LETTERS[q.correctIndex]}\n   Explanation: ${q.explanation}` : "";
        return `Q${i + 1}:${p}\n   Question: ${q.text}\n   Options: ${opts}${ans}`;
      })
      .join("\n\n")
  );
}

function buildMathAuditPrompt(questions, chartSummary = "") {
  const header = chartSummary ? `${chartSummary}\n\n` : "";
  const lines = questions
    .map((q, i) => {
      const enOpts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const hiOpts = q.optionsHi.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const pass = q.passage ? `\n   EN Directions: ${q.passage}\n   HI Directions: ${q.passageHi}` : "";
      return `Q${i + 1}:${pass}\n   EN: ${q.text}\n   EN Options: ${enOpts}\n   EN Exp: ${q.explanation}\n   HI: ${q.textHi}\n   HI Options: ${hiOpts}\n   HI Exp: ${q.explanationHi}\n   Marked: ${LETTERS[q.correctIndex]}`;
    })
    .join("\n\n");

  return `You are a ruthless Banking PO Quantitative Aptitude auditor and EN-HI bilingual proofreader. Cross-check MATH, DATA, LOGIC, STEP-BY-STEP SOLUTION, and ENGLISH-HINDI PARITY for EVERY question below from scratch.

REMOVE a question if ANY of these is true:
- there is ANY arithmetic, algebraic, variable, formula, rounding, or logical error in the solution or marked answer;
- the marked correct option does NOT match the true mathematical result;
- more than one option could be considered correct, or none of the 4 options matches;
- a variable equation yields negative/impossible values (like negative age, speed, or items) or has multiple valid roots without a constraint;
- a Number Series rule is forced/ambiguous, or Quadratic roots/comparison are wrong;
- a Data Interpretation question contradicts the given DI graph/table data or requires unstated assumptions;
- the Hindi question, Hindi directions, Hindi option, or Hindi explanation differs in meaning, mathematical condition, variable name, ratio, unit, or number from English, or Hindi options are not in the exact same order;
- the English or Hindi wording is ambiguous, awkward, or uses broken LaTeX syntax (like \\frac or \\sqrt).
When in doubt, REMOVE. KEEP only 100% mathematically airtight, exam-grade bilingual questions.

Return ONLY JSON: {"remove": [1, 4]} (or {"remove": []} if all are 100% correct). No markdown.

${header}QUESTIONS:
${lines}`;
}

function buildBlindMathSolvePrompt(questions, chartSummary = "") {
  return `You are a Banking PO Quantitative Aptitude topper. Solve EVERY question below independently from scratch WITHOUT guessing.
For each question, pick the letter (A, B, C, or D) of the exact answer and set "sure": true ONLY if your step-by-step calculation matches that option uniquely and unambiguously. Set "sure": false if the data is inconsistent, ambiguous, or does not match any option cleanly.

Return ONLY JSON: {"answers": [{"q": 1, "answer": "B", "sure": true}]} with one entry per question. No markdown.

QUESTIONS:
${formatQuestionsForCheck(questions, { withAnswer: false, withPassage: true, chartSummary })}`;
}

function buildBilingualQuantCheckPrompt(questions, chartSummary = "") {
  const header = chartSummary ? `${chartSummary}\n\n` : "";
  const lines = questions
    .map((q, i) => {
      const enOpts = q.options.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const hiOpts = q.optionsHi.map((o, k) => `${LETTERS[k]}) ${o}`).join(" | ");
      const pass = q.passage ? `\n   EN Directions: ${q.passage}\n   HI Directions: ${q.passageHi}` : "";
      return `Q${i + 1}:${pass}\n   EN: ${q.text}\n   EN Options: ${enOpts}\n   EN Exp: ${q.explanation}\n   HI: ${q.textHi}\n   HI Options: ${hiOpts}\n   HI Exp: ${q.explanationHi}\n   Marked: ${LETTERS[q.correctIndex]}`;
    })
    .join("\n\n");

  return `You are a strict English-Hindi proofreader for Indian Banking PO Quant exam papers.
REMOVE a question if ANY of these is true:
- the Hindi question, Hindi directions, Hindi option, or Hindi explanation differs in meaning, mathematical condition, variable name (x, y, P), ratio, unit, or number from the English version;
- the Hindi options are not in the exact same order as the English options;
- the English or Hindi wording has grammar/translation mistakes that could confuse a math student;
- the explanation contradicts the marked correct option.
KEEP the question otherwise.

Return ONLY JSON: {"remove": [2]} (or {"remove": []} if none). No markdown.

${header}QUESTIONS:
${lines}`;
}

// ---------------------------------------------------------------- local cleaning

function cleanQuantQuestion(raw, { passage = "", passageHi = "", passageImage = "", rnd = Math.random } = {}) {
  if (!raw || typeof raw !== "object") return null;
  const text = formatMathText(tidyMultiline(raw.text));
  const textHi = formatMathText(tidyMultiline(raw.textHi));
  const explanation = formatMathText(oneLine(raw.explanation));
  const explanationHi = formatMathText(oneLine(raw.explanationHi));
  const pEn = formatMathText(tidyMultiline(passage || raw.passage || ""));
  const pHi = formatMathText(tidyMultiline(passageHi || raw.passageHi || ""));
  const pImg = String(passageImage || raw.passageImage || "").trim();

  if (!Array.isArray(raw.options) || !Array.isArray(raw.optionsHi)) return null;
  const options = raw.options.map((o) => formatMathText(oneLine(o)));
  const optionsHi = raw.optionsHi.map((o) => formatMathText(oneLine(o)));
  const ci = Number(raw.correctIndex);

  if (text.length < 10 || text.length > 780 || hasDevanagari(text)) return null;
  if (textHi.length < 8 || textHi.length > 980 || !hasDevanagari(textHi)) return null;
  if (explanation.length < 10 || explanation.length > 750 || hasDevanagari(explanation)) return null;
  if (explanationHi.length < 10 || explanationHi.length > 950 || !hasDevanagari(explanationHi)) return null;
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
  if (pImg) {
    out.passageImage = pImg;
  }
  return out;
}

// ---------------------------------------------------------------- verification runner

async function verifyBatch(candidates, { key, callGemini, chartSummary = "" }) {
  if (!candidates.length) return [];

  // Check A + C (combined): Ruthless Math, Data, Logic & Bilingual EN-HI Audit
  const auditRaw = await callGemini(buildMathAuditPrompt(candidates, chartSummary), key, 0.0);
  const auditObj = parseJsonLoose(auditRaw);
  const dropA = new Set((Array.isArray(auditObj?.remove) ? auditObj.remove : []).map(Number));
  let list = candidates.filter((_, i) => !dropA.has(i + 1));
  if (!list.length) return [];

  // Check B: Independent Blind Math Re-Solve
  const solveRaw = await callGemini(buildBlindMathSolvePrompt(list, chartSummary), key, 0.0);
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
  return list.filter((q, i) => {
    const a = ansMap.get(i + 1);
    return a && a.sure && a.letter === LETTERS[q.correctIndex];
  });
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
      // Always include variable-based topics at the top of the mix so trending PO variable questions are guaranteed.
      const varTopics = shuffled(ARITHMETIC_TOPICS.slice(0, 6), roundRnd).slice(0, 5);
      const otherTopics = shuffled(ARITHMETIC_TOPICS.slice(6), roundRnd).slice(0, 6);
      prompt = buildArithmeticPrompt({ n: ask, periodLabel, topicList: [...varTopics, ...otherTopics], previous: avoid });
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

async function generateDiSubfolder({
  periodKey,
  periodLabel,
  previous = [],
  key,
  callGemini,
  imageToken = "",
  chartRenderer = renderChartPng,
  chartUploader = uploadDiChartPng,
  target = QUESTIONS_PER_SUBFOLDER,
}) {
  const rnd = seededRandom(`banking_quant|data_interpretation|${periodKey}`);
  const specs = getDiSetSpecs(periodKey);
  const allQuestions = [];
  const perSet = 5;

  for (let sIdx = 0; sIdx < specs.length && allQuestions.length < target; sIdx++) {
    const spec = specs[sIdx];
    const setQuestions = [];
    let verifiedChart = null;
    let verifiedPassage = "";
    let verifiedPassageHi = "";
    let verifiedSummary = "";
    const seen = new Set([...previous, ...allQuestions.map((q) => q.text)].map((t) => oneLine(t).toLowerCase()));

    for (let round = 1; round <= MAX_ROUNDS && setQuestions.length < perSet; round++) {
      try {
        const need = perSet - setQuestions.length;
        let rawQs = [];

        if (!verifiedChart) {
          // Generate chart + 10 candidate questions in one shot so 5+ easily pass verification on Round 1.
          const ask = Math.max(perSet + 5, 10);
          console.log(`  [data_interpretation/${spec.id}] round ${round}: generating chart + ${ask} candidates...`);
          const avoid = [...previous, ...allQuestions.map((q) => q.text)];
          const prompt = buildDiSetPrompt({ spec, periodLabel, previous: avoid, n: ask });
          const rawText = await callGemini(prompt, key, QUANT_TEMPERATURE);
          const parsed = parseJsonLoose(rawText);
          const chart = validateChartSpec(parsed?.chart);
          const passage = tidyMultiline(parsed?.passage || "");
          const passageHi = tidyMultiline(parsed?.passageHi || "");
          rawQs = Array.isArray(parsed?.questions) ? parsed.questions : [];
          if (!chart || !passage || !passageHi || rawQs.length < perSet) {
            console.warn(`  [data_interpretation/${spec.id}] round ${round}: invalid chart/passage/questions (${rawQs.length}), retrying.`);
            continue;
          }
          verifiedChart = chart;
          verifiedPassage = passage;
          verifiedPassageHi = passageHi;
          verifiedSummary = chartToTextSummary(chart);
        } else {
          // Keep the already-verified chart & questions; only top up the remaining needed questions!
          const ask = Math.min(10, need + 4);
          console.log(`  [data_interpretation/${spec.id}] round ${round}: topping up ${ask} more candidates for verified chart (have ${setQuestions.length}/${perSet})...`);
          const existing = setQuestions.map((q) => q.text);
          const prompt = buildDiTopupPrompt({
            spec,
            periodLabel,
            chartSummary: verifiedSummary,
            passage: verifiedPassage,
            passageHi: verifiedPassageHi,
            existingQuestions: existing,
            n: ask,
          });
          const rawText = await callGemini(prompt, key, QUANT_TEMPERATURE);
          const parsed = parseJsonLoose(rawText);
          rawQs = Array.isArray(parsed) ? parsed : Array.isArray(parsed?.questions) ? parsed.questions : [];
        }

        const cleaned = [];
        for (const item of rawQs) {
          const q = cleanQuantQuestion(item, { passage: verifiedPassage, passageHi: verifiedPassageHi, rnd });
          if (!q) continue;
          const k = q.text.toLowerCase();
          if (seen.has(k)) continue;
          seen.add(k);
          cleaned.push(q);
        }
        if (!cleaned.length) {
          console.warn(`  [data_interpretation/${spec.id}] round ${round}: 0 clean candidates, retrying.`);
          continue;
        }

        console.log(`  [data_interpretation/${spec.id}] round ${round}: verifying ${cleaned.length} candidates...`);
        const verified = await verifyBatch(cleaned, { key, callGemini, chartSummary: verifiedSummary });
        for (const q of verified) {
          if (setQuestions.length < perSet) setQuestions.push(q);
        }
        console.log(`  [data_interpretation/${spec.id}] round ${round}: cleaned=${cleaned.length}, verified=${verified.length}, total=${setQuestions.length}/${perSet}`);
      } catch (err) {
        console.warn(`  [data_interpretation/${spec.id}] round ${round} failed: ${err.message}`);
      }
    }

    if (setQuestions.length < perSet || !verifiedChart) {
      console.error(`  [data_interpretation/${spec.id}] could not verify ${perSet} questions; aborting DI set.`);
      return [];
    }

    // Render & upload crisp DI graph PNG image for this verified set!
    let imageUrl = "";
    if (imageToken) {
      try {
        const pngBuf = chartRenderer(verifiedChart);
        const repoPath = `di-charts/banking-quant/${periodKey}/set${sIdx + 1}-${spec.id}.png`;
        imageUrl = await chartUploader(pngBuf, repoPath, imageToken);
        console.log(`  [data_interpretation/${spec.id}] chart image uploaded: ${imageUrl}`);
      } catch (err) {
        console.error(`  [data_interpretation/${spec.id}] DI chart render/upload failed: ${err.message}`);
        return []; // Do not publish a graph DI set without its graph image!
      }
    } else {
      console.warn(`  [data_interpretation/${spec.id}] IMAGE_UPLOAD_TOKEN not set; skipping graph image upload.`);
    }

    for (const q of setQuestions) {
      if (imageUrl) q.passageImage = imageUrl;
      allQuestions.push(q);
    }
  }

  return allQuestions.length >= target ? allQuestions.slice(0, target) : [];
}

async function generateQuantSubfolder({
  subfolder,
  periodKey,
  periodLabel,
  previous = [],
  key,
  callGemini,
  imageToken = "",
  chartRenderer,
  chartUploader,
}) {
  if (subfolder.id === "data_interpretation") {
    return generateDiSubfolder({
      periodKey,
      periodLabel,
      previous,
      key,
      callGemini,
      imageToken,
      ...(chartRenderer ? { chartRenderer } : {}),
      ...(chartUploader ? { chartUploader } : {}),
    });
  }
  return generateStandaloneSubfolder({ subfolder, periodKey, periodLabel, previous, key, callGemini });
}

module.exports = {
  QUANT_SUBFOLDERS,
  QUESTIONS_PER_SUBFOLDER,
  ARITHMETIC_TOPICS,
  ADVANCED_TOPICS,
  getDiSetSpecs,
  formatMathText,
  numbersIn,
  numbersCovered,
  cleanQuantQuestion,
  parseJsonLoose,
  generateQuantSubfolder,
};

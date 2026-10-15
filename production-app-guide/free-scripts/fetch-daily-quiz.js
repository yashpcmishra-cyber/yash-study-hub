/**
 * Daily Quiz (free: GitHub Actions + free Gemini key, no Blaze needed).
 *
 * Creates a small quiz from the same PIB current-affairs lines that
 * fetch-daily-ca.js already keeps in Firestore
 * (dailyCA/{yyyy-MM-dd}.items). No new website / API is needed.
 *
 * Output: ONE Firestore document   dailyCA/quiz_{yyyy-MM-dd}
 *   { qdate, kind: "quiz", questions: [ {text, textHi, options[4], optionsHi[4],
 *     correctIndex, explanation, explanationHi} ], createdAt }
 * (Same collection as the current-affairs lines, so the same Firestore rule that
 * lets students read dailyCA also lets them read the quiz.)
 * App roz sirf 1 read se ise padhta hai.
 *
 * Storage: quiz documents jo 30 din se purane hain, ye script hata deta hai
 * (field "qdate" se). Purani current-affairs lines ko ye script nahi chhuta.
 *
 * Safe to run many times a day: agar aaj ka quiz bana hua hai to kuch nahi karta
 * (FORCE=true set karoge to dobara banayega).
 *
 * Env: FIREBASE_SERVICE_ACCOUNT, GEMINI_API_KEY   (dono pehle se GitHub secrets me hain)
 *      QUIZ_NOTIFY=false  -> "Daily Quiz ready" push notification band
 */
const QUESTIONS_WANTED = 10; // app shows the first 5 or all 10, as per the student's Daily goal
const MIN_QUESTIONS = 5; // isse kam valid sawal bane to quiz publish nahi hota (agli run phir try karegi)
const MIN_SOURCE_ITEMS = 6; // quiz banane ke liye kam se kam itni current-affairs lines chahiye
const MAX_SOURCE_ITEMS = 25;
const LOOKBACK_DAYS = 3; // aaj + pichhle 3 din ki lines
const KEEP_DAYS = 30; // 1 mahine baad quiz Firestore se delete

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const istDate = (offsetDays = 0) =>
  new Date(Date.now() + 5.5 * 3600 * 1000 - offsetDays * 86400000).toISOString().slice(0, 10);
const hasDevanagari = (s) => /[ऀ-ॿ]/.test(s);
const oneLine = (s) => String(s == null ? "" : s).replace(/\s+/g, " ").trim();

// ---------------------------------------------------------------- prompt

function buildPrompt(items) {
  const lines = items.map((it, i) => `${i + 1}. [${it.topic || "misc"}] ${it.en}`).join("\n");
  return `You write a daily quiz for Indian competitive-exam students (SSC, Banking, UPSC, State PCS).
Below are verified current-affairs facts from PIB (Government of India). Write exactly ${QUESTIONS_WANTED} multiple-choice questions based ONLY on these facts.

STRICT RULES:
- Every question must be answerable from one of the facts below. Never add outside knowledge, guesses, or dates/numbers that are not given.
- Each question must make sense on its own (name the scheme / person / place / event in the question). Never write "according to the text" or "as per the passage".
- Exactly 4 options. Exactly ONE option is correct. The 3 wrong options must be plausible but clearly wrong (use other real names/places/numbers of the same type), and must NOT also be true according to the facts.
- Mix question types (who / what / where / which / how many). Do not ask two questions about the same fact.
- "text": the question in English (max 35 words). "textHi": the same question in clear Hindi (Devanagari).
- "options": 4 short English options. "optionsHi": the same 4 options in the same order, in Hindi (Devanagari; keep proper names, numbers and abbreviations as they are).
- "correctIndex": number 0-3, the position of the correct option.
- "explanation": one sentence in English (max 30 words) stating the fact. "explanationHi": the same in Hindi (Devanagari).
- Return ONLY a JSON array of ${QUESTIONS_WANTED} objects (no markdown), each with keys: text, textHi, options, optionsHi, correctIndex, explanation, explanationHi.

FACTS:
${lines}`;
}

// ---------------------------------------------------------------- Gemini

async function callGemini(prompt, key) {
  const models = [];
  if (process.env.GEMINI_MODEL) models.push(process.env.GEMINI_MODEL);
  models.push("gemini-3.5-flash", "gemini-flash-latest", "gemini-3.1-flash-lite", "gemini-flash-lite-latest");
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
            generationConfig: { temperature: 0.4, responseMimeType: "application/json" },
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
      break; // 400/403/404: next model name
    }
  }
  throw lastErr;
}

// ------------------------------------------------------------ validation

function parseAnswer(text) {
  const t = String(text).trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  const a = t.indexOf("[");
  const b = t.lastIndexOf("]");
  if (a < 0 || b <= a) throw new Error("Gemini answer is not a JSON array");
  const arr = JSON.parse(t.slice(a, b + 1));
  return Array.isArray(arr) ? arr : [];
}

function shuffleInPlace(arr, rnd) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** Returns a clean question object, or null if anything is wrong with it. */
function cleanQuestion(raw, rnd = Math.random) {
  if (!raw || typeof raw !== "object") return null;
  const text = oneLine(raw.text);
  const textHi = oneLine(raw.textHi);
  const explanation = oneLine(raw.explanation);
  const explanationHi = oneLine(raw.explanationHi);
  if (!Array.isArray(raw.options) || !Array.isArray(raw.optionsHi)) return null;
  const options = raw.options.map(oneLine);
  const optionsHi = raw.optionsHi.map(oneLine);
  const ci = Number(raw.correctIndex);

  if (text.length < 10 || text.length > 320 || hasDevanagari(text)) return null;
  if (textHi.length < 8 || textHi.length > 450 || !hasDevanagari(textHi)) return null;
  if (explanation.length < 5 || explanation.length > 400 || hasDevanagari(explanation)) return null;
  if (explanationHi.length < 5 || explanationHi.length > 550 || !hasDevanagari(explanationHi)) return null;
  if (options.length !== 4 || optionsHi.length !== 4) return null;
  if (options.some((o) => o.length < 1 || o.length > 120)) return null;
  if (optionsHi.some((o) => o.length < 1 || o.length > 160)) return null;
  if (new Set(options.map((o) => o.toLowerCase())).size !== 4) return null;
  if (!Number.isInteger(ci) || ci < 0 || ci > 3) return null;

  // Options ko shuffle karo (AI aksar sahi jawab ek hi position par rakhta hai),
  // Hindi options ko bhi usi order me.
  const order = shuffleInPlace([0, 1, 2, 3], rnd);
  return {
    text,
    textHi,
    options: order.map((i) => options[i]),
    optionsHi: order.map((i) => optionsHi[i]),
    correctIndex: order.indexOf(ci),
    explanation,
    explanationHi,
  };
}

function cleanQuestions(rawList, rnd = Math.random) {
  const out = [];
  const seen = new Set();
  for (const raw of rawList) {
    const q = cleanQuestion(raw, rnd);
    if (!q) continue;
    const key = q.text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(q);
    if (out.length >= QUESTIONS_WANTED) break;
  }
  return out;
}

// ----------------------------------------------------------------- main

async function loadSourceItems(db) {
  const items = [];
  const seen = new Set();
  for (let off = 0; off <= LOOKBACK_DAYS && items.length < MAX_SOURCE_ITEMS; off++) {
    const snap = await db.collection("dailyCA").doc(istDate(off)).get();
    const list = (snap.exists && Array.isArray(snap.data().items) && snap.data().items) || [];
    list.sort((a, b) => (b.sortKey || 0) - (a.sortKey || 0));
    for (const it of list) {
      const en = oneLine(it && it.en);
      const id = String((it && it.id) || en);
      if (!en || seen.has(id)) continue;
      seen.add(id);
      items.push({ id, topic: it.topic, en });
      if (items.length >= MAX_SOURCE_ITEMS) break;
    }
  }
  return items;
}

async function deleteOldQuizzes(db) {
  const cutoff = istDate(KEEP_DAYS);
  const snap = await db.collection("dailyCA").where("qdate", "<", cutoff).limit(400).get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  console.log(`Deleted ${snap.size} quiz document(s) older than ${KEEP_DAYS} days.`);
}

async function main() {
  const admin = require("firebase-admin");
  const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();

  // Purane quiz hamesha hatao (quiz banne ya na banne se alag).
  try {
    await deleteOldQuizzes(db);
  } catch (err) {
    console.warn("Old-quiz cleanup skipped:", err.message);
  }

  const today = istDate();
  const ref = db.collection("dailyCA").doc(`quiz_${today}`);
  if (process.env.FORCE !== "true" && (await ref.get()).exists) {
    console.log(`Quiz for ${today} already exists. Nothing to do.`);
    return;
  }

  const items = await loadSourceItems(db);
  console.log(`Found ${items.length} current-affairs lines to build the quiz from.`);
  if (items.length < MIN_SOURCE_ITEMS) {
    console.log(`Need at least ${MIN_SOURCE_ITEMS} lines. Skipping - the next scheduled run will try again.`);
    return;
  }

  let questions = [];
  for (let attempt = 1; attempt <= 2 && questions.length < MIN_QUESTIONS; attempt++) {
    try {
      questions = cleanQuestions(parseAnswer(await callGemini(buildPrompt(items), GEMINI_KEY)));
    } catch (err) {
      console.warn(`Attempt ${attempt} failed: ${err.message}`);
    }
    console.log(`Attempt ${attempt}: ${questions.length} valid question(s).`);
  }
  if (questions.length < MIN_QUESTIONS) {
    console.error(`Only ${questions.length} valid question(s) - quiz not published.`);
    process.exit(1);
  }

  await ref.set({
    kind: "quiz",
    qdate: today,
    questions,
    source: "PIB",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Saved quiz_${today} with ${questions.length} questions.`);

  if (process.env.QUIZ_NOTIFY !== "false") {
    try {
      // Same shape the admin panel uses; send-notifications.js delivers it to everyone.
      await db.collection("notifications").add({
        title: "\u{1F9E0} Daily Quiz ready! / डेली क्विज़ तैयार है!",
        body: "Try today\u2019s current-affairs questions and grow your streak \u{1F525} / आज के करेंट अफेयर्स सवाल हल करें और अपनी स्ट्रीक बढ़ाएँ \u{1F525}",
        sent: false,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("Queued the 'Daily Quiz ready' notification.");
    } catch (err) {
      console.warn("Notification skipped:", err.message);
    }
  }
}

module.exports = { cleanQuestion, cleanQuestions, buildPrompt, parseAnswer };

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("fetch-daily-quiz failed:", err.message);
      process.exit(1);
    });
}

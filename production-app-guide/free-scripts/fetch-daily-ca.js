/**
 * Daily Current Affairs one-liners (free: GitHub Actions + free Gemini key).
 *
 * Source: PIB (Press Information Bureau, Government of India). PIB allows its
 * content to be reproduced free of charge with the source acknowledged, and
 * the app shows "Source: PIB" under every line.
 *
 * Each run:
 *  1) reads PIB's English press-release RSS feed (latest ~20 releases),
 *  2) skips releases already handled (kept in dailyCAState/processed),
 *  3) downloads each new release's text,
 *  4) asks Gemini to pick only exam-relevant ones and write a short English
 *     one-liner + a Hindi version, using ONLY facts present in the release,
 *  5) saves them into ONE Firestore document per day, dailyCA/{yyyy-MM-dd}
 *     (field "items"), so the app needs just 1 read per day it shows, and
 *     deletes days older than 10 days to keep Firestore storage small.
 *
 * If Gemini fails, nothing is marked as handled, so the next run retries.
 */
const admin = require("firebase-admin");
const Parser = require("rss-parser");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const parser = new Parser();

const FEED_URL = "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3";
// Browser-like identity: PIB's firewall blocks obvious bot User-Agents with HTTP 403.
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36";
const BROWSER_HEADERS = {
  "User-Agent": UA,
  Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
  "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
  Referer: "https://pib.gov.in/",
  "Upgrade-Insecure-Requests": "1",
  "Sec-Fetch-Dest": "document",
  "Sec-Fetch-Mode": "navigate",
  "Sec-Fetch-Site": "same-origin",
};
// Optional: URL of your own free Cloudflare Worker that fetches PIB for you (see notes).
// Used ONLY if direct requests keep getting 403.
const PIB_PROXY_URL = process.env.PIB_PROXY_URL || "";
const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
const TOPICS = ["national", "international", "economy", "defence", "science_tech", "sports", "awards", "environment", "polity", "schemes", "appointments", "misc"];
const BATCH_SIZE = 10;
const KEEP_DAYS = 10; // today + the previous 9 days are kept
const MAX_PER_DAY = 40; // keeps each day's document small
const MAX_PROCESSED = 500;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const istDate = (offsetDays = 0) => new Date(Date.now() + 5.5 * 3600 * 1000 - offsetDays * 86400000).toISOString().slice(0, 10);

function prOf(link) {
  const m = /PRID=(\d+)/i.exec(link || "");
  return m ? m[1] : null;
}

function htmlToText(html) {
  return String(html || "")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#?\w+;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function getText(url) {
  let lastStatus = 0;
  // 1) direct, with browser-like headers, retried a few times
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, { headers: BROWSER_HEADERS, redirect: "follow" });
      if (res.ok) return res.text();
      lastStatus = res.status;
      if (res.status !== 403 && res.status !== 429 && res.status < 500) break; // e.g. 404: retry is useless
    } catch (err) {
      console.warn(`Network error for ${url}: ${err.message}`);
    }
    await sleep(3000 * attempt);
  }
  // 2) optional fallback through your own proxy
  if (PIB_PROXY_URL) {
    const res = await fetch(`${PIB_PROXY_URL}${PIB_PROXY_URL.includes("?") ? "&" : "?"}url=${encodeURIComponent(url)}`);
    if (res.ok) return res.text();
    lastStatus = res.status;
  }
  throw new Error(`HTTP ${lastStatus} for ${url}`);
}

async function readFeed() {
  const xml = (await getText(FEED_URL)).replace(/^\uFEFF/, "").trim();
  const feed = await parser.parseString(xml);
  const out = [];
  for (const it of feed.items || []) {
    const prid = prOf(it.link);
    const title = String(it.title || "").trim();
    if (!prid || !title || title === "Press Release") continue;
    out.push({ prid, title });
  }
  return out;
}

async function readRelease(item) {
  const url = `https://pib.gov.in/PressReleaseIframePage.aspx?PRID=${item.prid}`;
  try {
    let text = htmlToText(await getText(url));
    const at = text.indexOf(item.title.slice(0, 25));
    if (at >= 0) text = text.slice(at);
    return text.slice(0, 1800);
  } catch (err) {
    console.warn(`Could not read release ${item.prid}: ${err.message}`);
    return "";
  }
}

function buildPrompt(batch) {
  const list = batch
    .map((b) => `ID: ${b.prid}\nTITLE: ${b.title}\nTEXT: ${b.text || "(not available)"}`)
    .join("\n\n---\n\n");
  return `You write daily current-affairs one-liners for Indian competitive-exam students (SSC, Banking, UPSC, State PCS).
Below are official PIB press releases. For each one decide whether it holds a fact worth remembering for exams (new scheme/policy, agreement/MoU, appointment, award, ranking, launch, major statistic, defence acquisition/exercise, science/space milestone, important event with a date).
SKIP routine items: ceremonies, meeting reviews, visits without outcomes, cleanliness drives, speeches, greetings, "press release" placeholders.

For every release you keep, return one object with:
- "id": the exact ID given
- "topic": one of ${TOPICS.join(", ")}
- "en": ONE factual sentence in English, max 30 words
- "hi": the same sentence in clear Hindi (Devanagari), max 40 words

STRICT RULES:
- Use ONLY facts that appear in that release's TITLE or TEXT. Never add outside knowledge, guesses or dates that are not given.
- Keep names, numbers, amounts and dates exactly as written.
- If the TEXT is not available, use the title only if it states a clear fact; otherwise skip it.
- Return ONLY a JSON array (no markdown). Return [] if nothing is worth keeping.

RELEASES:

${list}`;
}

async function callGemini(prompt) {
  const models = [];
  if (process.env.GEMINI_MODEL) models.push(process.env.GEMINI_MODEL);
  models.push("gemini-flash-latest", "gemini-2.5-flash", "gemini-flash-lite-latest", "gemini-2.5-flash-lite");
  let lastErr = new Error("No Gemini model worked");
  for (const model of models) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    for (let attempt = 0; attempt < 2; attempt++) {
      let res;
      try {
        res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_KEY },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.2, responseMimeType: "application/json" },
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

function parseAnswer(text) {
  let t = String(text).trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  const a = t.indexOf("[");
  const b = t.lastIndexOf("]");
  if (a < 0 || b <= a) throw new Error("Gemini answer is not a JSON array");
  const arr = JSON.parse(t.slice(a, b + 1));
  return Array.isArray(arr) ? arr : [];
}

const hasDevanagari = (s) => /[\u0900-\u097F]/.test(s);

function clean(entry, ids) {
  if (!entry || typeof entry !== "object") return null;
  const id = String(entry.id || "").trim();
  const en = String(entry.en || "").replace(/\s+/g, " ").trim();
  const hi = String(entry.hi || "").replace(/\s+/g, " ").trim();
  if (!ids.has(id) || en.length < 15 || en.length > 400 || hi.length < 10 || hi.length > 600) return null;
  if (!hasDevanagari(hi) || hasDevanagari(en)) return null;
  const topic = TOPICS.includes(entry.topic) ? entry.topic : "misc";
  return { id, en, hi, topic };
}

async function cleanupOld() {
  const cutoff = istDate(KEEP_DAYS - 1);
  const snap = await db.collection("dailyCA").where("date", "<", cutoff).limit(400).get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  console.log(`Deleted ${snap.size} old day(s) (before ${cutoff}).`);
}

// Adds new lines to today's single document (skips ones already there).
async function addToDay(date, newItems) {
  const ref = db.collection("dailyCA").doc(date);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = (snap.exists && Array.isArray(snap.data().items) && snap.data().items) || [];
    const have = new Set(existing.map((x) => x.id));
    const merged = existing.slice();
    let added = 0;
    for (const it of newItems) {
      if (have.has(it.id) || merged.length >= MAX_PER_DAY) continue;
      merged.push(it);
      added++;
    }
    if (added > 0) tx.set(ref, { date, items: merged, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return added;
  });
}

async function main() {
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  const stateRef = db.collection("dailyCAState").doc("processed");
  const stateSnap = await stateRef.get();
  const processed = new Set((stateSnap.exists && stateSnap.data().ids) || []);

  const feedItems = await readFeed();
  const fresh = feedItems.filter((i) => !processed.has(i.prid));
  console.log(`Feed has ${feedItems.length} releases, ${fresh.length} new.`);

  let geminiFailed = false;
  let saved = 0;
  const today = istDate();

  for (let i = 0; i < fresh.length; i += BATCH_SIZE) {
    const batch = fresh.slice(i, i + BATCH_SIZE);
    for (const item of batch) {
      item.text = await readRelease(item);
      await sleep(400);
    }
    let kept;
    try {
      kept = parseAnswer(await callGemini(buildPrompt(batch)));
    } catch (err) {
      console.error("Gemini step failed:", err.message);
      geminiFailed = true;
      continue; // not marked as processed, so the next run tries again
    }
    const ids = new Set(batch.map((b) => b.prid));
    const lines = [];
    for (const raw of kept) {
      const e = clean(raw, ids);
      if (!e) continue;
      lines.push({
        id: e.id,
        topic: e.topic,
        en: e.en,
        hi: e.hi,
        source: "PIB",
        link: `https://pib.gov.in/PressReleasePage.aspx?PRID=${e.id}`,
        sortKey: Date.now() + lines.length,
      });
    }
    if (lines.length > 0) saved += await addToDay(today, lines);
    batch.forEach((b) => processed.add(b.prid));
  }

  const keep = Array.from(processed).slice(-MAX_PROCESSED);
  await stateRef.set({ ids: keep, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  console.log(`Saved ${saved} one-liners.`);

  try {
    await cleanupOld();
  } catch (err) {
    console.warn("Cleanup skipped:", err.message);
  }
  if (geminiFailed) process.exit(1);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("fetch-daily-ca failed:", err.message);
    process.exit(1);
  });

/**
 * Monthly auto MCQ PDFs for the FREE PDF folders (PDF Library > Free).
 *
 * For every FREE PDF folder (every exam folder the admin made) and every subject
 * (Static GK, General Science, General Studies) it makes ONE PDF with 20 bilingual
 * (English + Hindi) MCQs for the previous calendar month (or env MONTH=yyyy-MM),
 * and adds it to that folder, so students see it in PDF Library > Free > <exam folder>.
 *
 * Questions: the same writer + 3 accuracy checks as the Free MCQs job (fetch-free-mcqs.js):
 * Gemini writes original questions on our own syllabus topic list, a fact-checker, a blind
 * solver and an English-Hindi checker remove doubtful ones. A PDF is NOT made unless all 20
 * questions survive (the retry run tries again).
 *
 * PDF: the page is written as HTML and printed to PDF by headless Chrome (installed on the
 * GitHub runner), because Chrome shapes Hindi (Devanagari) correctly with the Noto fonts
 * that the workflow installs.
 *
 * Hosting: the PDF is committed into the same free GitHub images repo the app already uses
 * (secret IMAGE_UPLOAD_TOKEN, "Contents: Read and write") and served through jsDelivr with
 * the commit id in the link, so the link never changes or goes stale. No Firebase Storage
 * / Blaze plan is needed.
 *
 * Firestore output (read by the app, nothing new to read):
 *   pdfs/auto_{folderId}_{subjectId}_{yyyy-MM}   same fields as an admin-added PDF
 *       { title, iconUrl:null, driveLink, folderId, batchId:null, createdAt, autoMonthly:true, monthKey, subjectId, count }
 *   autoPdfQuestions/{folderId}_{subjectId}_{yyyy-MM}   { texts[] }  (only so next month does not repeat questions)
 *
 * A folder can be skipped by the admin (Admin > PDFs > folder > "Monthly auto MCQ PDFs" switch off,
 * field pdfFolders/{id}.autoMonthlyMcq = false).
 *
 * Env: FIREBASE_SERVICE_ACCOUNT, GEMINI_API_KEY, IMAGE_UPLOAD_TOKEN   (GitHub secrets)
 *      MONTH=yyyy-MM          optional, default = previous month (IST)
 *      FORCE=true             optional, rebuild PDFs that already exist
 *      ONLY_FOLDER=<name>     optional, only the folder with this exact name (testing)
 *      PDF_NOTIFY=false       optional, skip the "PDFs ready" push
 *      CHROME_BIN=...         optional, path of Chrome / Chromium
 *      GEMINI_GAP_MS=3000     optional, pause before every Gemini call
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const fm = require("./fetch-free-mcqs.js");
const topics = require("./free-mcq-topics.js");

const PDF_QUESTIONS = 20; // MCQs in every PDF
const PDF_ASKED = 30; // asked from Gemini in round 1 so the checks can remove some and 20 still remain
const TOPICS_PER_PDF = 12; // at most 3 questions per topic
const PAUSE_BETWEEN_SETS_MS = 3000;
const PREV_QUESTIONS_IN_PROMPT = 30;

const REPO_OWNER = process.env.PDF_REPO_OWNER || "yashpcmishra-cyber";
const REPO_NAME = process.env.PDF_REPO_NAME || "ysh-images";
const REPO_BRANCH = process.env.PDF_REPO_BRANCH || "main";

const MODERATE_LEVEL = "Moderate competitive-exam level: clear, factual, not tricky.";
const LETTERS = ["A", "B", "C", "D"];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ------------------------------------------------------------------ small helpers

function escapeHtml(v) {
  return String(v == null ? "" : v)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** "SSC CGL / Prelims" -> "ssc-cgl-prelims" (ASCII only, safe in a file path). */
function slug(name) {
  const s = String(name || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return s || "folder";
}

const docIdFor = (folderId, subjectId, monthKey) => `auto_${folderId}_${subjectId}_${monthKey}`;
const questionsDocIdFor = (folderId, subjectId, monthKey) => `${folderId}_${subjectId}_${monthKey}`;

/** The exam description given to Gemini for any folder name the admin typed. */
function examFor(folder) {
  return {
    id: folder.id,
    name: folder.name,
    level: MODERATE_LEVEL,
    focus: `General Awareness / General Studies section of the "${folder.name}" competitive exam in India: Indian history, geography, polity, economy, general science, art and culture, static GK. Clear factual questions.`,
  };
}

// ------------------------------------------------------------------ the PDF page (HTML)

/**
 * The whole PDF as one HTML string. Questions first (English line, Hindi line, 4 options with
 * English / Hindi), then the answer key with explanations in both languages.
 */
function buildHtml({ folderName, subjectName, monthLabelText, questions }) {
  const qHtml = questions
    .map((q, i) => {
      const opts = q.options
        .map(
          (o, k) =>
            `<li><span class="L">${LETTERS[k]}</span><span class="o"><span class="en">${escapeHtml(o)}</span><span class="hi">${escapeHtml(q.optionsHi[k])}</span></span></li>`
        )
        .join("");
      return `<div class="q"><div class="qn">Q${i + 1}.</div><div class="qb"><div class="qt en">${escapeHtml(q.text)}</div><div class="qt hi">${escapeHtml(q.textHi)}</div><ul>${opts}</ul></div></div>`;
    })
    .join("\n");

  const key = questions.map((q, i) => `<span class="k">${i + 1}-${LETTERS[q.correctIndex]}</span>`).join("");

  const exp = questions
    .map(
      (q, i) =>
        `<div class="e"><b>Q${i + 1}. Answer: ${LETTERS[q.correctIndex]}) ${escapeHtml(q.options[q.correctIndex])} / ${escapeHtml(q.optionsHi[q.correctIndex])}</b><div class="en">${escapeHtml(q.explanation)}</div><div class="hi">${escapeHtml(q.explanationHi)}</div></div>`
    )
    .join("\n");

  return `<!DOCTYPE html>
<html lang="hi"><head><meta charset="utf-8"><title>${escapeHtml(subjectName)} - ${escapeHtml(monthLabelText)}</title>
<style>
  @page { size: A4; margin: 14mm 13mm 16mm 13mm; }
  * { box-sizing: border-box; }
  body { font-family: "Noto Sans Devanagari", "Noto Sans", "Lohit Devanagari", "DejaVu Sans", Arial, sans-serif; font-size: 11.5px; line-height: 1.45; color: #111; margin: 0; }
  .head { border-bottom: 2px solid #1a237e; padding-bottom: 8px; margin-bottom: 12px; }
  .head h1 { font-size: 20px; margin: 0 0 2px 0; color: #1a237e; }
  .head .sub { font-size: 12.5px; color: #333; }
  .head .meta { font-size: 11px; color: #666; margin-top: 2px; }
  .q { display: flex; gap: 8px; margin: 0 0 11px 0; page-break-inside: avoid; break-inside: avoid; }
  .qn { font-weight: bold; min-width: 30px; color: #1a237e; }
  .qb { flex: 1; }
  .qt { font-weight: 600; }
  .qt.hi { color: #222; margin-top: 1px; }
  ul { list-style: none; margin: 5px 0 0 0; padding: 0; }
  li { display: flex; gap: 6px; margin: 2px 0; }
  .L { font-weight: bold; min-width: 16px; }
  .o .en { display: block; }
  .o .hi { display: block; color: #333; }
  h2 { font-size: 15px; color: #1a237e; margin: 14px 0 8px 0; border-bottom: 1px solid #c5cae9; padding-bottom: 3px; page-break-after: avoid; }
  .keys { display: flex; flex-wrap: wrap; gap: 4px 12px; margin-bottom: 8px; }
  .k { font-weight: bold; }
  .e { margin: 0 0 8px 0; page-break-inside: avoid; break-inside: avoid; }
  .e .hi { color: #333; }
  .pb { page-break-before: always; break-before: page; }
  .foot { margin-top: 14px; font-size: 10px; color: #777; border-top: 1px solid #ddd; padding-top: 5px; }
</style></head><body>
<div class="head">
  <h1>${escapeHtml(subjectName)} &mdash; ${escapeHtml(monthLabelText)}</h1>
  <div class="sub">${escapeHtml(folderName)}</div>
  <div class="meta">${questions.length} MCQs &bull; English + Hindi / अंग्रेज़ी + हिन्दी &bull; Yash Study Hub</div>
</div>
${qHtml}
<div class="pb"></div>
<h2>Answer Key / उत्तर कुंजी</h2>
<div class="keys">${key}</div>
<h2>Explanations / व्याख्या</h2>
${exp}
<div class="foot">Original practice questions written for Yash Study Hub from standard syllabus topics and checked for accuracy. Please verify important facts from your textbook. / ये अभ्यास प्रश्न हैं; ज़रूरी तथ्य अपनी पाठ्यपुस्तक से ज़रूर जाँच लें।</div>
</body></html>`;
}

// ------------------------------------------------------------------ HTML -> PDF (headless Chrome)

function findChrome() {
  const candidates = [process.env.CHROME_BIN, "google-chrome", "google-chrome-stable", "chromium", "chromium-browser"].filter(Boolean);
  for (const c of candidates) {
    try {
      execFileSync(c, ["--version"], { stdio: "ignore", timeout: 20000 });
      return c;
    } catch (_) {
      // try the next one
    }
  }
  throw new Error("Chrome / Chromium not found. Install it or set CHROME_BIN.");
}

function renderPdf(html, outFile) {
  const chrome = findChrome();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ysh-pdf-"));
  const htmlFile = path.join(dir, "page.html");
  fs.writeFileSync(htmlFile, html, "utf8");
  try {
    execFileSync(
      chrome,
      [
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--no-pdf-header-footer",
        `--user-data-dir=${path.join(dir, "profile")}`,
        `--print-to-pdf=${outFile}`,
        `file://${htmlFile}`,
      ],
      { stdio: "pipe", timeout: 120000 }
    );
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  const buf = fs.readFileSync(outFile);
  if (buf.length < 5000 || buf.slice(0, 4).toString() !== "%PDF") throw new Error("Chrome did not produce a valid PDF.");
  return buf;
}

// ------------------------------------------------------------------ upload to the GitHub images repo

/** Commits the PDF and returns a permanent jsDelivr link (commit id in the link). */
async function uploadPdf(buf, repoPath, token) {
  const api = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${repoPath.split("/").map(encodeURIComponent).join("/")}`;
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "yash-study-hub-monthly-pdfs",
  };
  // A file with this name may already exist (FORCE rebuild): GitHub then needs its sha.
  let sha;
  const head = await fetch(`${api}?ref=${encodeURIComponent(REPO_BRANCH)}`, { headers });
  if (head.ok) sha = (await head.json()).sha;

  for (let attempt = 1; attempt <= 3; attempt++) {
    const res = await fetch(api, {
      method: "PUT",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ message: `Monthly MCQ PDF: ${repoPath}`, content: buf.toString("base64"), branch: REPO_BRANCH, ...(sha ? { sha } : {}) }),
    });
    if (res.ok) {
      const json = await res.json();
      const commit = json && json.commit && json.commit.sha;
      if (!commit) throw new Error("GitHub did not return a commit id.");
      return `https://cdn.jsdelivr.net/gh/${REPO_OWNER}/${REPO_NAME}@${commit}/${repoPath}`;
    }
    const body = (await res.text()).slice(0, 200);
    if ((res.status === 409 || res.status >= 500) && attempt < 3) {
      await sleep(4000 * attempt); // parallel commit conflict / GitHub hiccup
      continue;
    }
    throw new Error(`GitHub upload failed (HTTP ${res.status}): ${body}`);
  }
  throw new Error("GitHub upload failed.");
}

// ------------------------------------------------------------------ Firestore

async function loadPreviousTexts(db, folderId, subjectId, monthKey) {
  const texts = [];
  for (const back of [1, 2]) {
    const snap = await db.collection("autoPdfQuestions").doc(questionsDocIdFor(folderId, subjectId, fm.shiftMonth(monthKey, -back))).get();
    if (!snap.exists) continue;
    for (const t of snap.data().texts || []) if (t) texts.push(String(t));
  }
  return texts.slice(0, PREV_QUESTIONS_IN_PROMPT);
}

async function loadFreeFolders(db, onlyName) {
  const snap = await db.collection("pdfFolders").where("type", "==", "free").get();
  const folders = [];
  for (const d of snap.docs) {
    const data = d.data() || {};
    const name = String(data.name || "").trim();
    if (!name) continue;
    if (data.autoMonthlyMcq === false) {
      console.log(`Folder "${name}": automatic PDFs are switched off by the admin, skipped.`);
      continue;
    }
    if (onlyName && name !== onlyName) continue;
    folders.push({ id: d.id, name, order: Number.isFinite(data.order) ? data.order : 9999 });
  }
  folders.sort((a, b) => a.order - b.order || a.name.localeCompare(b.name));
  return folders;
}

// ------------------------------------------------------------------ main

async function main() {
  const monthKey = (process.env.MONTH || "").trim() || fm.shiftMonth(new Date(Date.now() + 5.5 * 3600 * 1000).toISOString().slice(0, 7), -1);
  if (!/^\d{4}-\d{2}$/.test(monthKey)) throw new Error(`MONTH must look like 2026-10, got "${monthKey}"`);

  const GEMINI_KEY = process.env.GEMINI_API_KEY || "";
  const TOKEN = process.env.IMAGE_UPLOAD_TOKEN || "";
  if (!GEMINI_KEY) {
    console.error("GEMINI_API_KEY secret is missing. Add it in GitHub: Settings > Secrets and variables > Actions.");
    process.exit(1);
  }
  if (!TOKEN) {
    console.error("IMAGE_UPLOAD_TOKEN secret is missing (the same token the app uses for images: Contents read + write on the images repo).");
    process.exit(1);
  }
  findChrome(); // fail early, before any Gemini call

  const admin = require("firebase-admin");
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const db = admin.firestore();

  const force = process.env.FORCE === "true";
  const notify = process.env.PDF_NOTIFY !== "false";
  const label = fm.monthLabel(monthKey);
  console.log(`Building monthly MCQ PDFs for ${label} (${monthKey}).`);

  const folders = await loadFreeFolders(db, (process.env.ONLY_FOLDER || "").trim());
  console.log(`${folders.length} free folder(s) x ${fm.SUBJECTS.length} subject(s).`);

  let created = 0;
  let failed = 0;
  for (const folder of folders) {
    for (const subject of fm.SUBJECTS) {
      const docId = docIdFor(folder.id, subject.id, monthKey);
      const tag = `${folder.name} / ${subject.name}`;
      try {
        if (!force && (await db.collection("pdfs").doc(docId).get()).exists) {
          console.log(`${tag}: already there, skipped.`);
          continue;
        }
        const exam = examFor(folder);
        const topicList = topics.pickTopics({ subjectId: subject.id, examId: folder.id, monthKey, n: TOPICS_PER_PDF });
        if (topicList.length < 5) {
          console.warn(`${tag}: no topics configured for this subject.`);
          failed++;
          continue;
        }
        console.log(`${tag}: generating ${PDF_QUESTIONS} MCQs...`);
        const previous = await loadPreviousTexts(db, folder.id, subject.id, monthKey);
        const questions = await fm.generateSet({ exam, subject, monthKey, ctx: { topicList }, previous, key: GEMINI_KEY, perSet: PDF_QUESTIONS, asked: PDF_ASKED });
        if (questions.length < PDF_QUESTIONS) {
          failed++;
          console.error(`${tag}: only ${questions.length} verified question(s) - PDF not made (retry run will try again).`);
          continue;
        }

        const tmpPdf = path.join(os.tmpdir(), `${docId}.pdf`);
        const buf = renderPdf(buildHtml({ folderName: folder.name, subjectName: subject.name, monthLabelText: label, questions }), tmpPdf);
        fs.rmSync(tmpPdf, { force: true });

        const repoPath = `pdfs/monthly/${monthKey}/${slug(folder.name)}-${folder.id.slice(0, 6)}-${subject.id}.pdf`;
        const link = await uploadPdf(buf, repoPath, TOKEN);

        await db.collection("pdfs").doc(docId).set({
          title: `${subject.name} MCQs \u2013 ${label} (${PDF_QUESTIONS} MCQs, Hindi + English)`,
          iconUrl: null,
          driveLink: link,
          batchId: null,
          folderId: folder.id,
          autoMonthly: true,
          monthKey,
          subjectId: subject.id,
          count: questions.length,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await db.collection("autoPdfQuestions").doc(questionsDocIdFor(folder.id, subject.id, monthKey)).set({ texts: questions.map((q) => fm.oneLine(q.text)) });
        created++;
        console.log(`${tag}: PDF added (${link}).`);
        // The "new PDFs" red dot on the Home grid.
        await db.collection("appConfig").doc("main").set({ newPdfsAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true }).catch(() => {});
        await sleep(PAUSE_BETWEEN_SETS_MS);
      } catch (err) {
        failed++;
        console.error(`${tag}: failed - ${err.message}`);
      }
    }
  }

  if (created > 0 && notify) {
    try {
      await db.collection("notifications").add({
        title: "\u{1F4C4} New monthly MCQ PDFs! / नए मंथली MCQ PDF!",
        body: `${label} MCQ PDFs are in PDF Library > Free. / ${label} के MCQ PDF फ़्री PDF लाइब्रेरी में हैं।`,
        sent: false,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log("Queued the 'PDFs ready' notification.");
    } catch (err) {
      console.warn("Notification skipped:", err.message);
    }
  }
  console.log(`Done: ${created} new PDF(s), ${failed} failed.`);
  return failed;
}

module.exports = { PDF_QUESTIONS, buildHtml, renderPdf, slug, escapeHtml, docIdFor, examFor };

if (require.main === module) {
  main()
    .then((failed) => process.exit(failed > 0 ? 1 : 0))
    .catch((err) => {
      console.error("generate-monthly-pdfs failed:", err.message);
      process.exit(1);
    });
}

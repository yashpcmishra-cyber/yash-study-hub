/**
 * Source text for the Free MCQs (Static GK / General Science / General Studies).
 *
 * WHY THESE SOURCES (checked 21 Oct 2026):
 *  - Wikipedia text is licensed CC BY-SA 4.0: free to reuse and adapt with attribution
 *    (link to the article) and the same licence on the adapted material.
 *  - NCERT textbooks are NOT used: NCERT forbids using them in digital content packages / software.
 *  - Current Affairs come from PIB (see fetch-daily-ca.js), not from here.
 *
 * Pools follow the UPPCS Prelims GS-I syllabus: history & national movement, geography,
 * polity & governance, economic & social development, environment / ecology / climate change,
 * general science, "with special reference to Uttar Pradesh".
 *
 * Titles that do not exist (or are renamed) are skipped automatically.
 * Run the workflow with dry_run=true to see which titles are missing.
 */

const LICENSE = "CC BY-SA 4.0";
const LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/";
const WIKI_API = "https://en.wikipedia.org/w/api.php";

const PAGES_PER_SET = 8; // articles given to Gemini per set
const MIN_PAGES = 5; // fewer usable articles than this = set skipped
const PAGE_CHARS = 2800; // characters kept from each article
const MIN_PAGE_CHARS = 400; // shorter stubs are useless for questions

// `exams`: only used for these exams (omit = every exam).
const POOLS = {
  gk: [
    {
      label: "Ancient and medieval India",
      titles: ["Indus Valley Civilisation", "Vedic period", "Maurya Empire", "Ashoka", "Gupta Empire", "Harsha", "Chola dynasty", "Delhi Sultanate", "Mughal Empire", "Akbar", "Sher Shah Suri", "Maratha Empire", "Vijayanagara Empire", "Buddhism", "Jainism", "Bhakti movement", "First Battle of Panipat", "Battle of Haldighati"],
    },
    {
      label: "Modern India and the national movement",
      titles: ["Battle of Plassey", "Battle of Buxar", "Indian Rebellion of 1857", "Indian National Congress", "Swadeshi movement", "Partition of Bengal (1905)", "Jallianwala Bagh massacre", "Non-cooperation movement", "Civil Disobedience Movement", "Salt March", "Quit India Movement", "Champaran Satyagraha", "Cabinet Mission", "Indian Independence Act 1947", "Government of India Act 1935", "Regulating Act 1773", "Permanent Settlement", "Subhas Chandra Bose", "Bhagat Singh", "Chauri Chaura incident", "Kakori train robbery"],
    },
    {
      label: "Geography of India and the world",
      titles: ["Geography of India", "Himalayas", "Western Ghats", "Eastern Ghats", "Deccan Plateau", "Thar Desert", "Indo-Gangetic Plain", "Climate of India", "List of rivers of India", "Brahmaputra River", "Godavari River", "Narmada River", "Kaveri", "Chilika Lake", "Sundarbans", "Plate tectonics", "Amazon River", "Nile", "Sahara", "Pacific Ocean"],
    },
    {
      label: "Art, culture, awards and sports",
      titles: ["Bharat Ratna", "Padma Awards", "Jnanpith Award", "Sahitya Akademi Award", "Arjuna Award", "Dronacharya Award", "Major Dhyan Chand Khel Ratna", "Indian classical dance", "List of World Heritage Sites in India", "Languages of India", "Classical languages of India", "National symbols of India", "Olympic Games", "Commonwealth Games", "Asian Games", "FIFA World Cup", "Cricket World Cup"],
    },
    {
      label: "Uttar Pradesh",
      exams: ["up_state"],
      titles: ["Uttar Pradesh", "History of Uttar Pradesh", "Geography of Uttar Pradesh", "Culture of Uttar Pradesh", "Tourism in Uttar Pradesh", "Lucknow", "Varanasi", "Prayagraj", "Agra", "Ayodhya", "Mathura", "Kanpur", "Jhansi", "Awadh", "Taj Mahal", "Fatehpur Sikri", "Sarnath", "Kushinagar", "Dudhwa National Park", "Gomti River", "Chambal River", "Ganges", "Yamuna", "Banaras Hindu University", "Aligarh Muslim University", "Chikankari", "Kathak"],
    },
  ],

  science: [
    {
      label: "Physics",
      titles: ["Newton's laws of motion", "Gravity", "Refraction", "Total internal reflection", "Lens", "Electric current", "Ohm's law", "Electromagnetic spectrum", "Sound", "Doppler effect", "Archimedes' principle", "Bernoulli's principle", "Nuclear fission", "Nuclear fusion", "Radioactive decay", "Magnetism", "Transformer", "Laser", "Semiconductor", "Optical fiber"],
    },
    {
      label: "Chemistry",
      titles: ["Periodic table", "Acid", "Base (chemistry)", "PH", "Chemical bond", "Allotropes of carbon", "Alloy", "Corrosion", "Ozone layer", "Polymer", "Fertilizer", "Soap", "Petroleum", "Liquefied petroleum gas", "Isotope", "Catalyst", "Hard water", "Biofuel"],
    },
    {
      label: "Biology and human health",
      titles: ["Human digestive system", "Circulatory system", "Respiratory system", "Endocrine system", "Human brain", "Vitamin", "Photosynthesis", "Cell (biology)", "DNA", "Gene", "Blood type", "Immune system", "Vaccine", "Malaria", "Tuberculosis", "Dengue fever", "Antibiotic", "Virus", "Bacteria", "Diabetes"],
    },
    {
      label: "Space, defence and everyday technology",
      titles: ["Indian Space Research Organisation", "Chandrayaan-3", "Mars Orbiter Mission", "Aditya-L1", "Gaganyaan", "Defence Research and Development Organisation", "Agni (missile)", "Artificial intelligence", "5G", "Internet", "Nanotechnology", "Biotechnology", "Genetically modified organism", "Global Positioning System", "NavIC"],
    },
  ],

  gs: [
    {
      label: "Indian polity and governance",
      titles: ["Constitution of India", "Preamble to the Constitution of India", "Fundamental rights in India", "Directive Principles", "Fundamental Duties of India", "Parliament of India", "Lok Sabha", "Rajya Sabha", "President of India", "Prime Minister of India", "Supreme Court of India", "Election Commission of India", "Comptroller and Auditor General of India", "Union Public Service Commission", "Finance Commission of India", "NITI Aayog", "Panchayati raj", "Seventy-third Amendment of the Constitution of India", "Right to Information Act, 2005", "Lokpal", "Basic structure doctrine", "Kesavananda Bharati v. State of Kerala"],
    },
    {
      label: "Economic and social development",
      titles: ["Economy of India", "Five-year plans of India", "Union budget of India", "Inflation", "Gross domestic product", "Reserve Bank of India", "Securities and Exchange Board of India", "Goods and Services Tax (India)", "National Bank for Agriculture and Rural Development", "Green Revolution in India", "Operation Flood", "Make in India", "Digital India", "Pradhan Mantri Jan Dhan Yojana", "Mahatma Gandhi National Rural Employment Guarantee Act, 2005", "Swachh Bharat Mission", "Ayushman Bharat", "National Education Policy 2020", "Unified Payments Interface", "Human Development Index", "Census of India", "Sustainable Development Goals"],
    },
    {
      label: "Environment, ecology, biodiversity and climate change",
      titles: ["Climate change", "Global warming", "Greenhouse gas", "Paris Agreement", "Kyoto Protocol", "Montreal Protocol", "Ramsar Convention", "Convention on Biological Diversity", "Biodiversity hotspot", "Project Tiger", "Wild Life (Protection) Act, 1972", "Biosphere reserve", "Environment (Protection) Act, 1986", "Eutrophication", "Acid rain", "Wetland", "Mangrove", "Coral reef", "Ecosystem", "IUCN Red List", "Chipko movement", "National Green Tribunal", "International Solar Alliance"],
    },
    {
      label: "International organisations",
      titles: ["United Nations", "World Bank", "International Monetary Fund", "World Trade Organization", "Asian Development Bank", "BRICS", "G20", "SAARC", "ASEAN", "Shanghai Cooperation Organisation", "Quadrilateral Security Dialogue", "NATO", "OPEC", "Non-Aligned Movement", "Commonwealth of Nations"],
    },
    {
      label: "Uttar Pradesh governance and economy",
      exams: ["up_state"],
      titles: ["Economy of Uttar Pradesh", "Demographics of Uttar Pradesh", "Government of Uttar Pradesh", "Uttar Pradesh Legislative Assembly", "Education in Uttar Pradesh", "Transport in Uttar Pradesh", "List of districts of Uttar Pradesh", "Chief Minister of Uttar Pradesh", "Governor of Uttar Pradesh", "Allahabad High Court", "Uttar Pradesh Public Service Commission"],
    },
  ],
};

// ---------------------------------------------------------------- helpers

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Small deterministic random generator, so the same exam+subject+month always picks the same pages. */
function seededRandom(seedText) {
  let h = 1779033703 ^ seedText.length;
  for (let i = 0; i < seedText.length; i++) {
    h = Math.imul(h ^ seedText.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = (h ^ (h >>> 16)) >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled(arr, rnd) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Candidate titles for one set: round-robin over the topic groups, each group shuffled. */
function candidateTitles({ subjectId, examId, monthKey }) {
  const groups = (POOLS[subjectId] || []).filter((g) => !g.exams || g.exams.includes(examId));
  const rnd = seededRandom(`${examId}|${subjectId}|${monthKey}`);
  const lists = shuffled(groups, rnd).map((g) => shuffled(g.titles, rnd));
  const out = [];
  const seen = new Set();
  for (let round = 0; ; round++) {
    let any = false;
    for (const list of lists) {
      if (round < list.length) {
        any = true;
        if (!seen.has(list[round])) {
          seen.add(list[round]);
          out.push(list[round]);
        }
      }
    }
    if (!any) break;
  }
  return out;
}

function allPoolTitles() {
  const set = new Set();
  for (const groups of Object.values(POOLS)) for (const g of groups) g.titles.forEach((t) => set.add(t));
  return [...set];
}

// ---------------------------------------------------------------- Wikipedia

function userAgent() {
  const repo = process.env.GITHUB_REPOSITORY;
  const contact = process.env.WIKI_CONTACT || (repo ? `https://github.com/${repo}` : "https://github.com/");
  return `YashStudyHubMCQBot/1.0 (${contact}; monthly educational MCQ generator)`;
}

/** Plain text of an article without the reference sections. */
function cleanExtract(raw) {
  let text = String(raw || "").replace(/\r/g, "");
  const cut = /^==+\s*(See also|References|External links|Notes|Further reading|Bibliography|Citations|Sources|Footnotes|Gallery)\s*==+\s*$/im.exec(text);
  if (cut) text = text.slice(0, cut.index);
  text = text
    .replace(/^==+\s*(.*?)\s*==+\s*$/gm, "$1:") // "== History ==" -> "History:"
    .replace(/\[\d+\]/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (text.length > PAGE_CHARS) {
    const slice = text.slice(0, PAGE_CHARS);
    const lastStop = slice.lastIndexOf(". ");
    text = lastStop > PAGE_CHARS * 0.6 ? slice.slice(0, lastStop + 1) : slice;
  }
  return text;
}

/** One article, or null if it is missing, a disambiguation page or too short. Cached per run. */
const pageCache = new Map();
async function fetchPage(title) {
  if (pageCache.has(title)) return pageCache.get(title);
  const url =
    `${WIKI_API}?action=query&format=json&formatversion=2&redirects=1&prop=extracts%7Cinfo` +
    `&explaintext=1&inprop=url&titles=${encodeURIComponent(title)}`;
  let page = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, { headers: { "User-Agent": userAgent(), "Accept": "application/json" } });
      if (res.status === 429 || res.status >= 500) {
        await sleep(4000 * attempt);
        continue;
      }
      if (!res.ok) break;
      const json = await res.json();
      const p = json && json.query && json.query.pages && json.query.pages[0];
      if (p && !p.missing && !p.invalid && p.extract) {
        const text = cleanExtract(p.extract);
        const isDisambig = /may refer to|may also refer to/i.test(text.slice(0, 250));
        if (text.length >= MIN_PAGE_CHARS && !isDisambig) {
          page = { title: p.title, url: p.fullurl || `https://en.wikipedia.org/wiki/${encodeURIComponent(p.title.replace(/ /g, "_"))}`, text };
        }
      }
      break;
    } catch (_) {
      await sleep(2500 * attempt);
    }
  }
  pageCache.set(title, page);
  await sleep(250); // be polite to Wikipedia
  return page;
}

/** Up to PAGES_PER_SET usable articles for one exam + subject + month. */
async function pickPages({ subjectId, examId, monthKey }) {
  const pages = [];
  const seenTitles = new Set();
  for (const title of candidateTitles({ subjectId, examId, monthKey })) {
    if (pages.length >= PAGES_PER_SET) break;
    const p = await fetchPage(title);
    if (!p || seenTitles.has(p.title)) continue;
    seenTitles.add(p.title);
    pages.push(p);
  }
  return pages;
}

module.exports = {
  LICENSE,
  LICENSE_URL,
  PAGES_PER_SET,
  MIN_PAGES,
  POOLS,
  candidateTitles,
  allPoolTitles,
  cleanExtract,
  fetchPage,
  pickPages,
  seededRandom,
};

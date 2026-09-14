/**
 * Free RSS auto-fetch script (no Blaze/billing needed).
 * Same logic as functions/index.js, but runs as a plain Node.js script via
 * GitHub Actions instead of a Firebase Cloud Function — so no billing
 * account is required at all.
 *
 * Needs one thing: a Firebase service account key (free, from Firebase
 * Console > Project Settings > Service Accounts > Generate new private key),
 * saved as a GitHub encrypted secret named FIREBASE_SERVICE_ACCOUNT.
 */
const admin = require("firebase-admin");
const Parser = require("rss-parser");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const parser = new Parser({
  customFields: { item: [["media:content", "mediaContent"], ["media:thumbnail", "mediaThumbnail"]] },
});

const FEEDS = [
  { category: "banking", label: "Banking Exams", url: "https://news.google.com/rss/search?q=banking+exam+notification+India&hl=en-IN&gl=IN&ceid=IN:en", hasImages: false },
  { category: "ssc", label: "SSC Exams", url: "https://news.google.com/rss/search?q=SSC+exam+notification&hl=en-IN&gl=IN&ceid=IN:en", hasImages: false },
  { category: "up_state", label: "UP State Exams", url: "https://news.google.com/rss/search?q=UPSSSC+OR+UPPSC+exam+notification&hl=en-IN&gl=IN&ceid=IN:en", hasImages: false },
  { category: "sports", label: "Sports", url: "https://timesofindia.indiatimes.com/rssfeeds/2886704.cms", hasImages: true },
  { category: "technology", label: "Technology", url: "https://timesofindia.indiatimes.com/rssfeeds/1898274.cms", hasImages: true },
  { category: "space", label: "Space", url: "https://news.google.com/rss/search?q=ISRO+OR+space+India&hl=en-IN&gl=IN&ceid=IN:en", hasImages: false },
  { category: "defence", label: "Defence", url: "https://news.google.com/rss/search?q=India+defence+OR+DRDO+OR+armed+forces&hl=en-IN&gl=IN&ceid=IN:en", hasImages: false },
  { category: "national", label: "National Affairs", url: "https://timesofindia.indiatimes.com/rssfeeds/1898272.cms", hasImages: true },
  { category: "hindi_news", label: "Hindi News", url: "https://navbharattimes.indiatimes.com/rssfeedsdefault.cms", hasImages: true },
  { category: "hindi_ca", label: "Hindi Current Affairs", url: "https://news.google.com/rss/search?q=%E0%A4%95%E0%A4%B0%E0%A5%87%E0%A4%82%E0%A4%9F%20%E0%A4%85%E0%A4%AB%E0%A5%87%E0%A4%AF%E0%A4%B0%E0%A5%8D%E0%A4%B8&hl=hi&gl=IN&ceid=IN:hi", hasImages: false },
];

function extractRssImage(item) {
  if (item.enclosure && item.enclosure.url) return item.enclosure.url;
  if (item.mediaContent && item.mediaContent.$ && item.mediaContent.$.url) return item.mediaContent.$.url;
  if (item.mediaThumbnail && item.mediaThumbnail.$ && item.mediaThumbnail.$.url) return item.mediaThumbnail.$.url;
  const m = (item.content || item["content:encoded"] || "").match(/<img[^>]+src="([^">]+)"/i);
  return m ? m[1] : null;
}

async function fetchOgImage(url) {
  try {
    const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    const html = await res.text();
    const match = html.match(/<meta[^>]+property="og:image"[^>]+content="([^">]+)"/i);
    return match ? match[1] : null;
  } catch (e) {
    return null;
  }
}

async function fetchCategory(feed) {
  const parsed = await parser.parseURL(feed.url);
  const items = parsed.items.slice(0, 15);
  const batch = db.batch();
  for (const item of items) {
    let image = extractRssImage(item);
    if (!image && !feed.hasImages && item.link) image = await fetchOgImage(item.link);
    const docId = Buffer.from(item.link || item.guid || item.title).toString("base64").slice(0, 120);
    const ref = db.collection("newsItems").doc(`${feed.category}_${docId}`);
    batch.set(ref, {
      category: feed.category,
      categoryLabel: feed.label,
      title: item.title || "",
      link: item.link || "",
      image: image || null,
      pubDate: item.pubDate ? new Date(item.pubDate) : admin.firestore.FieldValue.serverTimestamp(),
      fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  console.log(`[${feed.category}] saved ${items.length} items`);
}

(async () => {
  for (const feed of FEEDS) {
    try {
      await fetchCategory(feed);
    } catch (err) {
      console.error(`Failed ${feed.category}:`, err.message);
    }
  }
  process.exit(0);
})();

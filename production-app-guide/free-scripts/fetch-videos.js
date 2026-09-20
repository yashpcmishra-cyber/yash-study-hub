/**
 * Free YouTube auto-fetch script (no Blaze/billing needed).
 * Runs as a GitHub Actions script (same free pattern as fetch-news.js)
 * instead of a paid Cloud Function.
 *
 * Uses the YouTube Data API v3's channels.list + playlistItems.list calls,
 * NOT search.list — this matters a lot for cost: search.list costs 100
 * quota units per call, while channels.list + playlistItems.list cost only
 * 1 unit each. The free daily quota is 10,000 units, so running this every
 * hour costs ~48 units/day — nowhere close to the limit.
 *
 * What it writes:
 *   - videos/{videoId}            one document per video (free Video Classes)
 *   - appConfig/latestVideos      a ready-made list of the newest 10 videos,
 *                                 which the Home screen strip reads (one tiny
 *                                 read, always the newest, no index needed)
 *
 * Videos that the admin "hid" in the app (Admin > Videos) have hidden: true.
 * They are never brought back and never put in the latest-10 list.
 *
 * Needs THREE things, saved as GitHub encrypted secrets:
 *   - FIREBASE_SERVICE_ACCOUNT: same one fetch-news.js / send-notifications.js
 *     already use (Firebase Console > Project Settings > Service Accounts).
 *   - YOUTUBE_API_KEY: free, from Google Cloud Console > APIs & Services >
 *     Credentials > Create Credentials > API key, after enabling
 *     "YouTube Data API v3" for the project.
 *   - YOUTUBE_CHANNEL_ID: the channel's ID (starts with UC...), not its @handle
 *     — see FREE_AUTOMATION_GUIDE.md for how to find it.
 */
const admin = require("firebase-admin");

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const API_KEY = process.env.YOUTUBE_API_KEY;
const CHANNEL_ID = process.env.YOUTUBE_CHANNEL_ID;
const MAX_VIDEOS = 15;
const LATEST_COUNT = 10;

async function getJson(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
  return res.json();
}

async function getUploadsPlaylistId() {
  const url = `https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=${CHANNEL_ID}&key=${API_KEY}`;
  const data = await getJson(url);
  if (data.error) throw new Error(`channels.list failed: ${data.error.message}`);
  const item = data.items && data.items[0];
  if (!item) throw new Error("Channel not found - check YOUTUBE_CHANNEL_ID");
  return item.contentDetails.relatedPlaylists.uploads;
}

async function getLatestVideos(playlistId) {
  const url = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${playlistId}&maxResults=${MAX_VIDEOS}&key=${API_KEY}`;
  const data = await getJson(url);
  if (data.error) throw new Error(`playlistItems.list failed: ${data.error.message}`);
  return data.items || [];
}

async function getHiddenIds() {
  try {
    const snap = await db.collection("videos").where("hidden", "==", true).get();
    return new Set(snap.docs.map((d) => d.id));
  } catch (err) {
    console.error("Could not read hidden videos (continuing):", err.message);
    return new Set();
  }
}

(async () => {
  if (!API_KEY || !CHANNEL_ID) {
    console.error("Missing YOUTUBE_API_KEY or YOUTUBE_CHANNEL_ID - see the comment at the top of this file.");
    process.exit(1);
  }
  try {
    const hidden = await getHiddenIds();
    const playlistId = await getUploadsPlaylistId();
    const items = await getLatestVideos(playlistId);
    const batch = db.batch();
    const latest = [];
    let count = 0;
    for (const item of items) {
      const videoId = item.snippet && item.snippet.resourceId && item.snippet.resourceId.videoId;
      if (!videoId) continue;
      // Deleted/private videos still show a placeholder snippet with this
      // title - skip them instead of showing a broken card in the app.
      if (item.snippet.title === "Deleted video" || item.snippet.title === "Private video") continue;
      // Hidden by the admin: leave it alone (do not touch, do not list).
      if (hidden.has(videoId)) continue;
      const thumb = item.snippet.thumbnails || {};
      const thumbUrl = (thumb.high || thumb.medium || thumb.default || {}).url || null;
      const publishedIso = item.snippet.publishedAt || new Date().toISOString();
      const youtubeLink = `https://www.youtube.com/watch?v=${videoId}`;
      // Doc id = video id itself (not auto-generated) so re-running this
      // script never creates duplicates - it just re-writes the same doc.
      const ref = db.collection("videos").doc(videoId);
      batch.set(ref, {
        title: item.snippet.title || "",
        thumbUrl,
        youtubeLink,
        batchId: null,
        folderId: null,
        source: "youtube_auto",
        publishedAt: new Date(publishedIso),
        fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      latest.push({ id: videoId, title: item.snippet.title || "", thumbUrl, youtubeLink, publishedAt: publishedIso });
      count++;
    }
    await batch.commit();

    latest.sort((a, b) => String(b.publishedAt).localeCompare(String(a.publishedAt)));
    await db.collection("appConfig").doc("latestVideos").set({
      items: latest.slice(0, LATEST_COUNT),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Saved ${count} videos from channel uploads (latest list updated).`);
    process.exit(0);
  } catch (err) {
    console.error("Failed:", err.message);
    process.exit(1);
  }
})();

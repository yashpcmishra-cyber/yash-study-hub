/**
 * Crisp, deterministic DI Graph / Table PNG renderer + GitHub ysh-images uploader.
 *
 * Renders structured JSON chart specs (bar, grouped_bar, line, pie, table) into
 * high-DPI PNG images using headless Chrome (preinstalled on ubuntu-24.04 runners),
 * then commits them to the app's free GitHub images repo (ysh-images) via IMAGE_UPLOAD_TOKEN
 * and returns a permanent jsDelivr CDN URL for `MockQuestion.passageImage`.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const REPO_OWNER = process.env.DI_REPO_OWNER || process.env.PDF_REPO_OWNER || "yashpcmishra-cyber";
const REPO_NAME = process.env.DI_REPO_NAME || process.env.PDF_REPO_NAME || "ysh-images";
const REPO_BRANCH = process.env.DI_REPO_BRANCH || process.env.PDF_REPO_BRANCH || "main";

const PALETTE = ["#1E3A8A", "#0F766E", "#D97706", "#7C3AED", "#BE123C", "#0369A1"];
const VALID_TYPES = new Set(["bar", "grouped_bar", "line", "pie", "table"]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function escapeHtml(v) {
  return String(v == null ? "" : v)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
  ].filter(Boolean);
  for (const bin of candidates) {
    try {
      execFileSync(bin, ["--version"], { stdio: "pipe", timeout: 10000 });
      return bin;
    } catch (_) {
      // try next
    }
  }
  throw new Error("Headless Chrome/Chromium not found for DI chart rendering.");
}

/**
 * Validates a structured chart JSON spec returned by Gemini.
 * Returns a clean normalized chart object, or null if invalid.
 */
function validateChartSpec(raw) {
  if (!raw || typeof raw !== "object") return null;
  const type = String(raw.type || "").trim().toLowerCase();
  if (!VALID_TYPES.has(type)) return null;

  const title = String(raw.title || "").trim();
  const titleHi = String(raw.titleHi || "").trim();
  const subtitle = String(raw.subtitle || "").trim();
  const yLabel = String(raw.yLabel || "").trim();
  const unit = String(raw.unit || "").trim();
  if (!title || title.length > 140) return null;

  if (type === "table") {
    const headers = Array.isArray(raw.headers) ? raw.headers.map((h) => String(h || "").trim()).filter(Boolean) : [];
    const rows = Array.isArray(raw.rows) ? raw.rows : [];
    if (headers.length < 2 || headers.length > 6) return null;
    if (rows.length < 3 || rows.length > 7) return null;
    const cleanRows = [];
    for (const r of rows) {
      if (!Array.isArray(r) || r.length !== headers.length) return null;
      cleanRows.push(r.map((c) => String(c == null ? "" : c).trim()));
    }
    return { type, title, titleHi, subtitle, headers, rows: cleanRows };
  }

  const labels = Array.isArray(raw.labels) ? raw.labels.map((l) => String(l || "").trim()).filter(Boolean) : [];
  if (labels.length < 3 || labels.length > 6) return null;

  const rawSeries = Array.isArray(raw.series) ? raw.series : [];
  if (rawSeries.length < 1 || rawSeries.length > 3) return null;
  if (type === "pie" && rawSeries.length !== 1) return null;

  const series = [];
  for (const s of rawSeries) {
    const name = String((s && s.name) || "").trim() || "Value";
    const vals = Array.isArray(s && s.values) ? s.values.map(Number) : [];
    if (vals.length !== labels.length) return null;
    if (vals.some((v) => !Number.isFinite(v) || v < 0)) return null;
    series.push({ name, values: vals });
  }

  if (type === "pie") {
    const sum = series[0].values.reduce((a, b) => a + b, 0);
    if (sum <= 0) return null;
    // If percentages, ensure sum is ~100
    if (unit === "%" && Math.abs(sum - 100) > 0.6) return null;
  }

  return { type, title, titleHi, subtitle, yLabel, unit, labels, series };
}

/** Converts a validated chart spec into a clean human-readable summary for Math Audit / Blind Re-Solve prompts. */
function chartToTextSummary(chart) {
  if (!chart) return "";
  if (chart.type === "table") {
    const head = chart.headers.join(" | ");
    const body = chart.rows.map((r) => r.join(" | ")).join("\n   ");
    return `DI TABLE (${chart.title}):\n   ${head}\n   ${body}`;
  }
  const unit = chart.unit ? ` (${chart.unit})` : "";
  const lines = chart.labels.map((lbl, idx) => {
    const vals = chart.series.map((s) => `${s.name}: ${s.values[idx]}${chart.unit === "%" ? "%" : ""}`).join(", ");
    return `${lbl} -> ${vals}`;
  });
  return `DI ${chart.type.toUpperCase()} GRAPH (${chart.title}${unit}):\n   ${lines.join("\n   ")}`;
}

function fmtNum(v, unit = "") {
  const s = Number.isInteger(v) ? String(v) : String(Number(v.toFixed(2)));
  return unit === "%" ? `${s}%` : s;
}

// ---------------------------------------------------------------- SVG builders

function buildBarSvg(chart) {
  const W = 860, H = 400;
  const padL = 72, padR = 30, padT = 36, padB = 64;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;

  const allVals = chart.series.flatMap((s) => s.values);
  const rawMax = Math.max(...allVals, 1);
  const niceStep = Math.pow(10, Math.floor(Math.log10(rawMax / 4))) *
    (rawMax / Math.pow(10, Math.floor(Math.log10(rawMax / 4))) > 20 ? 5 :
      rawMax / Math.pow(10, Math.floor(Math.log10(rawMax / 4))) > 8 ? 2 : 1);
  const maxVal = Math.ceil((rawMax * 1.15) / niceStep) * niceStep;

  const yOf = (v) => padT + plotH - (v / maxVal) * plotH;
  const gridLines = [];
  for (let i = 0; i <= 5; i++) {
    const val = (maxVal / 5) * i;
    const y = yOf(val);
    gridLines.push(
      `<line x1="${padL}" y1="${y.toFixed(1)}" x2="${W - padR}" y2="${y.toFixed(1)}" stroke="#E2E8F0" stroke-width="1"/>` +
      `<text x="${padL - 10}" y="${(y + 4).toFixed(1)}" text-anchor="end" font-size="13" fill="#475569">${fmtNum(Math.round(val * 100) / 100, chart.unit)}</text>`
    );
  }

  const nGroups = chart.labels.length;
  const nSeries = chart.series.length;
  const groupW = plotW / nGroups;
  const barGap = 8;
  const barW = Math.min(54, Math.max(22, (groupW * 0.72 - barGap * (nSeries - 1)) / nSeries));
  const bars = [];

  chart.labels.forEach((lbl, gi) => {
    const cx = padL + groupW * (gi + 0.5);
    const totalBarsW = nSeries * barW + (nSeries - 1) * barGap;
    const startX = cx - totalBarsW / 2;

    chart.series.forEach((s, si) => {
      const val = s.values[gi];
      const x = startX + si * (barW + barGap);
      const y = yOf(val);
      const h = Math.max(2, padT + plotH - y);
      const color = PALETTE[si % PALETTE.length];
      bars.push(
        `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${barW.toFixed(1)}" height="${h.toFixed(1)}" rx="4" fill="${color}"/>` +
        `<text x="${(x + barW / 2).toFixed(1)}" y="${(y - 7).toFixed(1)}" text-anchor="middle" font-size="13" font-weight="700" fill="#0F172A">${escapeHtml(fmtNum(val, chart.unit))}</text>`
      );
    });

    bars.push(
      `<text x="${cx.toFixed(1)}" y="${padT + plotH + 26}" text-anchor="middle" font-size="14" font-weight="600" fill="#0F172A">${escapeHtml(lbl)}</text>`
    );
  });

  const yAxisTitle = chart.yLabel
    ? `<text x="18" y="${padT + plotH / 2}" text-anchor="middle" font-size="13" font-weight="600" fill="#334155" transform="rotate(-90 18 ${padT + plotH / 2})">${escapeHtml(chart.yLabel)}</text>`
    : "";

  return `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
    ${gridLines.join("\n")}
    <line x1="${padL}" y1="${padT}" x2="${padL}" y2="${padT + plotH}" stroke="#64748B" stroke-width="1.5"/>
    <line x1="${padL}" y1="${padT + plotH}" x2="${W - padR}" y2="${padT + plotH}" stroke="#64748B" stroke-width="1.5"/>
    ${yAxisTitle}
    ${bars.join("\n")}
  </svg>`;
}

function buildLineSvg(chart) {
  const W = 860, H = 400;
  const padL = 72, padR = 46, padT = 40, padB = 64;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;

  const allVals = chart.series.flatMap((s) => s.values);
  const rawMax = Math.max(...allVals, 1);
  const rawMin = Math.min(...allVals, 0);
  const minVal = rawMin > 0 && rawMin > rawMax * 0.4 ? Math.floor(rawMin * 0.85) : 0;
  const maxVal = Math.ceil(rawMax * 1.15);
  const span = Math.max(1, maxVal - minVal);

  const xOf = (i) => padL + (chart.labels.length === 1 ? plotW / 2 : (plotW / (chart.labels.length - 1)) * i);
  const yOf = (v) => padT + plotH - ((v - minVal) / span) * plotH;

  const gridLines = [];
  for (let i = 0; i <= 5; i++) {
    const val = minVal + (span / 5) * i;
    const y = yOf(val);
    gridLines.push(
      `<line x1="${padL}" y1="${y.toFixed(1)}" x2="${W - padR}" y2="${y.toFixed(1)}" stroke="#E2E8F0" stroke-width="1"/>` +
      `<text x="${padL - 10}" y="${(y + 4).toFixed(1)}" text-anchor="end" font-size="13" fill="#475569">${fmtNum(Math.round(val * 10) / 10, chart.unit)}</text>`
    );
  }

  const xLabels = chart.labels
    .map((lbl, i) => `<text x="${xOf(i).toFixed(1)}" y="${padT + plotH + 28}" text-anchor="middle" font-size="14" font-weight="600" fill="#0F172A">${escapeHtml(lbl)}</text>`)
    .join("\n");

  const linesSvg = chart.series
    .map((s, si) => {
      const color = PALETTE[si % PALETTE.length];
      const pts = s.values.map((v, i) => `${xOf(i).toFixed(1)},${yOf(v).toFixed(1)}`).join(" ");
      const dots = s.values
        .map((v, i) => {
          const x = xOf(i);
          const y = yOf(v);
          const dy = si % 2 === 0 ? -12 : 20;
          return (
            `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="5.5" fill="#FFFFFF" stroke="${color}" stroke-width="3"/>` +
            `<text x="${x.toFixed(1)}" y="${(y + dy).toFixed(1)}" text-anchor="middle" font-size="13" font-weight="700" fill="${color}">${escapeHtml(fmtNum(v, chart.unit))}</text>`
          );
        })
        .join("\n");
      return `<polyline fill="none" stroke="${color}" stroke-width="3" points="${pts}"/>\n${dots}`;
    })
    .join("\n");

  const yAxisTitle = chart.yLabel
    ? `<text x="18" y="${padT + plotH / 2}" text-anchor="middle" font-size="13" font-weight="600" fill="#334155" transform="rotate(-90 18 ${padT + plotH / 2})">${escapeHtml(chart.yLabel)}</text>`
    : "";

  return `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
    ${gridLines.join("\n")}
    <line x1="${padL}" y1="${padT}" x2="${padL}" y2="${padT + plotH}" stroke="#64748B" stroke-width="1.5"/>
    <line x1="${padL}" y1="${padT + plotH}" x2="${W - padR}" y2="${padT + plotH}" stroke="#64748B" stroke-width="1.5"/>
    ${yAxisTitle}
    ${linesSvg}
    ${xLabels}
  </svg>`;
}

function buildPieSvg(chart) {
  const W = 860, H = 380;
  const cx = 230, cy = 190, r = 148;
  const vals = chart.series[0].values;
  const total = vals.reduce((a, b) => a + b, 0);
  let startAngle = -Math.PI / 2;
  const slices = [];
  const legend = [];

  vals.forEach((v, i) => {
    const frac = v / total;
    const sweep = frac * Math.PI * 2;
    const endAngle = startAngle + sweep;
    const x1 = cx + r * Math.cos(startAngle);
    const y1 = cy + r * Math.sin(startAngle);
    const x2 = cx + r * Math.cos(endAngle);
    const y2 = cy + r * Math.sin(endAngle);
    const largeArc = sweep > Math.PI ? 1 : 0;
    const color = PALETTE[i % PALETTE.length];
    const mid = startAngle + sweep / 2;
    const lx = cx + r * 0.65 * Math.cos(mid);
    const ly = cy + r * 0.65 * Math.sin(mid);

    slices.push(
      `<path d="M ${cx} ${cy} L ${x1.toFixed(1)} ${y1.toFixed(1)} A ${r} ${r} 0 ${largeArc} 1 ${x2.toFixed(1)} ${y2.toFixed(1)} Z" fill="${color}" stroke="#FFFFFF" stroke-width="2.5"/>` +
      (frac >= 0.06
        ? `<text x="${lx.toFixed(1)}" y="${(ly + 5).toFixed(1)}" text-anchor="middle" font-size="14" font-weight="700" fill="#FFFFFF">${escapeHtml(fmtNum(v, chart.unit))}</text>`
        : "")
    );

    const lyRow = 62 + i * 44;
    legend.push(
      `<rect x="445" y="${lyRow - 14}" width="18" height="18" rx="4" fill="${color}"/>` +
      `<text x="474" y="${lyRow}" font-size="15" font-weight="600" fill="#0F172A">${escapeHtml(chart.labels[i])}</text>` +
      `<text x="820" y="${lyRow}" text-anchor="end" font-size="15" font-weight="700" fill="${color}">${escapeHtml(fmtNum(v, chart.unit))}</text>` +
      `<line x1="445" y1="${lyRow + 14}" x2="820" y2="${lyRow + 14}" stroke="#E2E8F0" stroke-width="1"/>`
    );

    startAngle = endAngle;
  });

  return `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
    ${slices.join("\n")}
    ${legend.join("\n")}
  </svg>`;
}

function buildChartHtml(chart) {
  const legendHtml =
    chart.type !== "pie" && chart.type !== "table" && chart.series.length > 1
      ? `<div class="legend">${chart.series
          .map((s, i) => `<span class="leg-item"><span class="swatch" style="background:${PALETTE[i % PALETTE.length]}"></span>${escapeHtml(s.name)}</span>`)
          .join("")}</div>`
      : "";

  let bodyHtml = "";
  if (chart.type === "table") {
    const ths = chart.headers.map((h) => `<th>${escapeHtml(h)}</th>`).join("");
    const trs = chart.rows
      .map((row) => {
        const tds = row
          .map((cell, ci) => {
            const isVar = /^[?—\-]$|\bx\b|\by\b/i.test(cell);
            return `<td class="${ci === 0 ? "row-lbl" : "num"}${isVar ? " var-cell" : ""}">${escapeHtml(cell)}</td>`;
          })
          .join("");
        return `<tr>${tds}</tr>`;
      })
      .join("");
    bodyHtml = `<table><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`;
  } else if (chart.type === "line") {
    bodyHtml = buildLineSvg(chart);
  } else if (chart.type === "pie") {
    bodyHtml = buildPieSvg(chart);
  } else {
    bodyHtml = buildBarSvg(chart);
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 920px;
    background: #FFFFFF;
    color: #0F172A;
    font-family: "Noto Sans", "Noto Sans Devanagari", "Lohit Devanagari", Arial, sans-serif;
    padding: 22px 26px 24px;
  }
  .head { border-bottom: 2px solid #1E3A8A; padding-bottom: 10px; margin-bottom: 14px; }
  .title { font-size: 19px; font-weight: 700; color: #0F172A; line-height: 1.3; }
  .title-hi { font-size: 16px; font-weight: 600; color: #334155; margin-top: 3px; }
  .sub { font-size: 13px; color: #475569; margin-top: 4px; }
  .legend { display: flex; flex-wrap: wrap; gap: 18px; margin-bottom: 10px; font-size: 14px; font-weight: 600; color: #1E293B; }
  .leg-item { display: inline-flex; align-items: center; gap: 7px; }
  .swatch { width: 14px; height: 14px; border-radius: 3px; display: inline-block; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 16px; }
  thead th { background: #1E3A8A; color: #FFFFFF; padding: 12px 14px; text-align: center; font-weight: 700; border: 1px solid #1E3A8A; }
  thead th:first-child { text-align: left; }
  tbody td { padding: 12px 14px; border: 1px solid #CBD5E1; text-align: center; color: #0F172A; }
  tbody tr:nth-child(even) { background: #F8FAFC; }
  tbody td.row-lbl { text-align: left; font-weight: 700; color: #0F172A; }
  tbody td.var-cell { background: #FEF3C7; color: #92400E; font-weight: 700; }
  svg { display: block; width: 100%; height: auto; }
</style>
</head>
<body>
  <div class="head">
    <div class="title">${escapeHtml(chart.title)}</div>
    ${chart.titleHi ? `<div class="title-hi">${escapeHtml(chart.titleHi)}</div>` : ""}
    ${chart.subtitle ? `<div class="sub">${escapeHtml(chart.subtitle)}</div>` : ""}
  </div>
  ${legendHtml}
  ${bodyHtml}
</body>
</html>`;
}

/** Renders a validated chart spec to a crisp PNG Buffer using headless Chrome. */
function renderChartPng(chart) {
  const chrome = findChrome();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ysh-di-"));
  const htmlFile = path.join(dir, "chart.html");
  const outPng = path.join(dir, "chart.png");
  fs.writeFileSync(htmlFile, buildChartHtml(chart), "utf8");

  const height = chart.type === "table" ? Math.max(320, 175 + chart.rows.length * 48) : 540;
  try {
    execFileSync(
      chrome,
      [
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--hide-scrollbars",
        "--no-first-run",
        "--disable-extensions",
        "--disable-background-networking",
        "--virtual-time-budget=2000",
        "--force-device-scale-factor=2",
        `--window-size=920,${height}`,
        `--user-data-dir=${path.join(dir, "profile")}`,
        `--screenshot=${outPng}`,
        `file://${htmlFile}`,
      ],
      { stdio: "pipe", timeout: 60000 }
    );
    const buf = fs.readFileSync(outPng);
    if (buf.length < 3000 || buf[0] !== 0x89 || buf[1] !== 0x50 || buf[2] !== 0x4e || buf[3] !== 0x47) {
      throw new Error("Chrome did not produce a valid PNG image.");
    }
    return buf;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/** Uploads the DI chart PNG to ysh-images and returns a permanent jsDelivr URL. */
async function uploadDiChartPng(buf, repoPath, token) {
  const api = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${repoPath.split("/").map(encodeURIComponent).join("/")}`;
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "yash-study-hub-di-charts",
  };

  let sha;
  const head = await fetch(`${api}?ref=${encodeURIComponent(REPO_BRANCH)}`, { headers });
  if (head.ok) sha = (await head.json()).sha;

  for (let attempt = 1; attempt <= 3; attempt++) {
    const res = await fetch(api, {
      method: "PUT",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: `DI chart: ${repoPath}`,
        content: buf.toString("base64"),
        branch: REPO_BRANCH,
        ...(sha ? { sha } : {}),
      }),
    });
    if (res.ok) {
      const json = await res.json();
      const commit = json && json.commit && json.commit.sha;
      if (!commit) throw new Error("GitHub did not return a commit id for DI chart.");
      return `https://cdn.jsdelivr.net/gh/${REPO_OWNER}/${REPO_NAME}@${commit}/${repoPath}`;
    }
    const body = (await res.text()).slice(0, 200);
    if ((res.status === 409 || res.status >= 500) && attempt < 3) {
      await sleep(4000 * attempt);
      continue;
    }
    throw new Error(`DI chart upload failed (HTTP ${res.status}): ${body}`);
  }
  throw new Error("DI chart upload failed.");
}

module.exports = {
  validateChartSpec,
  chartToTextSummary,
  buildChartHtml,
  renderChartPng,
  uploadDiChartPng,
  findChrome,
};

const sources = [
  ['广西人事考试网', 'https://www.gxpta.com.cn/'],
  ['广西人力资源和社会保障厅', 'http://rst.gxzf.gov.cn/'],
  ['广西人才网', 'https://www.gxrc.com/'],
  ['南宁市人社局', 'https://rsj.nanning.gov.cn/'],
  ['柳州市人社局', 'http://rsj.liuzhou.gov.cn/'],
  ['桂林市人社局', 'https://rsj.guilin.gov.cn/'],
  ['梧州市人社局', 'http://rsj.wuzhou.gov.cn/'],
  ['北海市人社局', 'http://www.beihai.gov.cn/xxgkbm/bhsrlzyhshbzj/'],
  ['防城港市政府', 'https://www.fcgs.gov.cn/'],
  ['钦州市政府', 'http://www.qinzhou.gov.cn/'],
  ['贵港市人社局', 'http://rsj.gxgg.gov.cn/'],
  ['玉林市人社局', 'http://rsj.yulin.gov.cn/'],
  ['百色市政府', 'http://www.baise.gov.cn/'],
  ['贺州市政府', 'http://www.gxhz.gov.cn/'],
  ['河池市人社局', 'http://rsj.hechi.gov.cn/'],
  ['来宾市人社局', 'http://www.laibin.gov.cn/rsj/'],
  ['崇左市人社局', 'http://rsj.chongzuo.gov.cn/'],
  ['柳州人才网', 'https://lz.gxrc.com/'],
  ['桂林人才网', 'https://gl.gxrc.com/'],
  ['梧州人才网', 'https://wz.gxrc.com/'],
  ['北海人才网', 'https://www.bhrc.cn/'],
  ['防城港人才网', 'https://fcg.gxrc.com/'],
  ['钦州人才网', 'https://qz.gxrc.com/'],
  ['贵港人才网', 'https://gg.gxrc.com/'],
  ['玉林人才网', 'https://yl.gxrc.com/'],
  ['百色人才网', 'https://bs.gxrc.com/'],
  ['贺州人才网', 'https://hz.gxrc.com/'],
  ['河池人才网', 'https://hc.gxrc.com/'],
  ['来宾人才网', 'https://lb.gxrc.com/'],
  ['崇左人才网', 'https://cz.gxrc.com/'],
];

const beijingParts = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).formatToParts(new Date()).reduce((acc, part) => {
  if (part.type !== 'literal') acc[part.type] = part.value;
  return acc;
}, {});
const beijingTodayUtc = Date.UTC(
  Number(beijingParts.year),
  Number(beijingParts.month) - 1,
  Number(beijingParts.day),
);
const windowDates = [2, 1, 0].map(offset => {
  const date = new Date(beijingTodayUtc - offset * 86400000);
  return {
    year: date.getUTCFullYear(),
    month: String(date.getUTCMonth() + 1).padStart(2, '0'),
    day: String(date.getUTCDate()).padStart(2, '0'),
  };
});
const targetDates = windowDates.flatMap(({ year, month, day }) => [
  `${year}-${month}-${day}`,
  `${year}/${month}/${day}`,
  `${year}年${Number(month)}月${Number(day)}日`,
  `${month}-${day}`,
]);
const windowLabel = `${windowDates[0].year}-${windowDates[0].month}-${windowDates[0].day}..${windowDates[2].year}-${windowDates[2].month}-${windowDates[2].day}`;
const keywordRe = /(招聘|招录|聘用|编外|劳务派遣|辅警|教师|医院|国企|见习|资格审查|资格复审|面试|体检|考察|拟录用|拟聘用|递补|补录|公示)/;

function stripHtml(s) {
  return s.replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

function detectCharset(bytes) {
  const ascii = Buffer.from(bytes).subarray(0, 4096).toString('latin1');
  const match = ascii.match(/charset\s*=\s*["']?([a-zA-Z0-9_-]+)/i);
  const label = (match?.[1] || 'utf-8').toLowerCase();
  return /gbk|gb2312|gb18030/.test(label) ? 'gb18030' : 'utf-8';
}

function extractCandidates(html, base) {
  const out = [];
  const anchorRe = /<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  for (const match of html.matchAll(anchorRe)) {
    const text = stripHtml(match[2]);
    if (!text || !keywordRe.test(text)) continue;
    const start = Math.max(0, match.index - 220);
    const end = Math.min(html.length, match.index + match[0].length + 220);
    const context = stripHtml(html.slice(start, end));
    const dates = targetDates.filter(d => context.includes(d));
    let href;
    try { href = new URL(match[1], base).href; } catch { continue; }
    out.push({ text: text.slice(0, 120), href, dates });
  }
  const seen = new Set();
  return out.filter(x => {
    const key = `${x.text}|${x.href}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).sort((a, b) => b.dates.length - a.dates.length).slice(0, 40);
}

async function fetchOne([name, url]) {
  const started = Date.now();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(url, {
      redirect: 'follow',
      signal: controller.signal,
      headers: { 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/138 Safari/537.36' },
    });
    const bytes = new Uint8Array(await response.arrayBuffer());
    const charset = detectCharset(bytes);
    const html = new TextDecoder(charset).decode(bytes);
    const title = stripHtml(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || '');
    const candidates = extractCandidates(html, response.url);
    const dated = candidates.filter(x => x.dates.length);
    return { name, input_url: url, final_url: response.url, ok: response.ok, status: response.status, charset, bytes: bytes.length, title, dated_candidates: dated, keyword_candidates: candidates.length, elapsed_ms: Date.now() - started };
  } catch (error) {
    return { name, input_url: url, ok: false, error: String(error?.message || error), elapsed_ms: Date.now() - started };
  } finally {
    clearTimeout(timer);
  }
}

const results = [];
for (let i = 0; i < sources.length; i += 6) {
  results.push(...await Promise.all(sources.slice(i, i + 6).map(fetchOne)));
}

process.stdout.write(JSON.stringify({ scanned_at: new Date().toISOString(), window: windowLabel, source_count: sources.length, results }, null, 2));

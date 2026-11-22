// ==UserScript==
// @name         无界翻译 UnboundTranslate
// @name:en      UnboundTranslate
// @namespace    https://github.com/unbound-translate
// @version      0.6.2
// @description  整页批量翻译 + 段落模式 + 划词翻译。点段落即翻、选中文字出气泡，支持双语对照。
// @description:en Batch whole-page translation with click-to-translate paragraphs. Bilingual reading, dynamic content.
// @author       UnboundTranslate
// @license      MIT
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @grant        GM_getValue
// @grant        GM_setValue
// @connect      translate.googleapis.com
// @connect      edge.microsoft.com
// @connect      api.mymemory.translated.net
// @connect      *
// @run-at       document-idle
// @noframes
// ==/UserScript==

(function () {
  'use strict';

  /* =========================================================================
 * 第一部分：常量 / 配置 / 存储 / 网络
 * ========================================================================= */

const UB = {
  VERSION: '0.1.0',
  NAME: '无界翻译',
  // 本脚本自己产生的 DOM 标记，扫描时一律跳过
  ATTR: 'data-wp-trans',
  SKIP_SEL: [
    'script', 'style', 'noscript', 'template', 'code', 'pre', 'kbd', 'samp',
    'textarea', 'input', 'select', 'option', 'svg', 'math', 'canvas',
    'iframe', 'video', 'audio', 'object', 'embed'
  ].join(','),
  CONCURRENCY: 4,
  CHUNK_CHARS: 1200,
  TIMEOUT_MS: 20000,
};

/* ---------------- 默认配置 ---------------- */

const DEFAULT_SETTINGS = {
  provider: 'google',
  sourceLang: 'auto',
  targetLang: 'zh-CN',
  displayMode: 'bilingual',        // replace | bilingual | bilingual-accent
  autoTranslate: false,
  autoTranslateSites: [],
  excludeSelectors: [],
  disabledSites: [],               // 不翻译的网站（域名），命中则不整页翻译
  selectionTranslate: true,
  paragraphMode: false,            // 段落模式：点一下段落就翻，再点还原
  translateAttributes: true,       // 图片 alt / title 等属性文本也翻（悬停显示译文）
  floatingBall: true,
  theme: 'auto',
  accent: '#4f8cff',
  // 各服务自己的凭据
  services: {
    google: {},
    microsoft: {},
    mymemory: {},
    openai: {
      baseURL: 'https://api.deepseek.com/v1',
      apiKey: '',
      model: 'deepseek-chat',
      systemPrompt:
        '你是专业翻译。把用户给出的文本翻译成目标语言。' +
        '只输出译文本身，不要解释、不要引号、不要添加原文。' +
        '保持原文的分段数量和顺序，每行原文对应一行译文。' +
        '保留数字、专有名词、代码、URL 和占位符 {{0}} {{1}} 等格式标记不变。'
    }
  }
};

/* ---------------- 设置读写 ---------------- */

let settings = null;

function deepMerge(base, patch) {
  if (!patch || typeof patch !== 'object') return base;
  const out = Array.isArray(base) ? base.slice() : { ...base };
  for (const key of Object.keys(patch)) {
    const bv = base ? base[key] : undefined;
    const pv = patch[key];
    if (pv && typeof pv === 'object' && !Array.isArray(pv) && bv && typeof bv === 'object' && !Array.isArray(bv)) {
      out[key] = deepMerge(bv, pv);
    } else if (pv !== undefined) {
      out[key] = pv;
    }
  }
  return out;
}

function loadSettings() {
  let saved = null;
  try {
    saved = typeof GM_getValue === 'function' ? GM_getValue('ubt.settings', null) : null;
  } catch (_) { saved = null; }
  if (typeof saved === 'string') {
    try { saved = JSON.parse(saved); } catch (_) { saved = null; }
  }
  return deepMerge(DEFAULT_SETTINGS, saved || {});
}

function saveSettings() {
  setValue('ubt.settings', settings);
}

function setValue(key, value) {
  try {
    if (typeof GM_setValue === 'function') { GM_setValue(key, value); return; }
  } catch (_) { /* 回退到 localStorage */ }
  try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) { /* 忽略 */ }
}

function getValue(key, fallback) {
  try {
    if (typeof GM_getValue === 'function') {
      const v = GM_getValue(key, fallback);
      return v === undefined ? fallback : v;
    }
  } catch (_) { /* 回退 */ }
  try {
    const raw = localStorage.getItem(key);
    return raw === null ? fallback : JSON.parse(raw);
  } catch (_) { return fallback; }
}

/* ---------------- 站点禁用（不翻译指定网站） ---------------- */

/** 当前域名（小写，不含端口）；拿不到返回空串 */
function currentHost() {
  try {
    const h = (typeof location !== 'undefined' && location.hostname) || '';
    return String(h).toLowerCase();
  } catch (_) { return ''; }
}

/**
 * 归一化用户输入的站点：去掉协议 / 路径 / 端口 / 前导点 / www.
 * 这样「https://www.example.com/a/b?x=1」和「example.com」会被当成同一个站。
 */
function normalizeSite(input) {
  let s = String(input || '').trim().toLowerCase();
  if (!s) return '';
  s = s.replace(/^[a-z][a-z0-9+.-]*:\/\//, '');  // 协议
  s = s.replace(/[/?#].*$/, '');                  // 路径 / 查询 / 锚点
  s = s.replace(/:\d+$/, '');                    // 端口
  s = s.replace(/^\*\./, '');                    // *.example.com
  s = s.replace(/^\.+/, '');                     // 前导点
  s = s.replace(/^www\./, '');                   // www 不区分
  return s;
}

/** host 是否命中 site（支持子域：a.example.com 命中 example.com） */
function hostMatches(host, site) {
  const h = normalizeSite(host);
  const s = normalizeSite(site);
  if (!h || !s) return false;
  return h === s || h.endsWith('.' + s);
}

/** 当前网站是否被设为「不翻译」 */
function isSiteDisabled() {
  const host = currentHost();
  if (!host) return false;
  const list = settings && Array.isArray(settings.disabledSites) ? settings.disabledSites : [];
  return list.some((s) => hostMatches(host, s));
}

/* ---------------- 翻译缓存（页内 + 持久化） ---------------- */

const cacheKey = (provider, from, to, text) => provider + '|' + from + '|' + to + '|' + text;
const memoryCache = new Map();
let diskCache = null;

function getDiskCache() {
  if (diskCache) return diskCache;
  diskCache = getValue('ubt.cache', {}) || {};
  return diskCache;
}

function cacheGet(k) {
  if (memoryCache.has(k)) return memoryCache.get(k);
  const d = getDiskCache();
  if (Object.prototype.hasOwnProperty.call(d, k)) {
    memoryCache.set(k, d[k]);
    return d[k];
  }
  return undefined;
}

function cacheSet(k, v) {
  memoryCache.set(k, v);
  const d = getDiskCache();
  d[k] = v;
  const keys = Object.keys(d);
  if (keys.length > 3000) {
    for (const old of keys.slice(0, keys.length - 3000)) delete d[old];
  }
  scheduleCacheFlush();
}

let cacheFlushTimer = null;
function scheduleCacheFlush() {
  if (cacheFlushTimer) return;
  cacheFlushTimer = setTimeout(() => {
    cacheFlushTimer = null;
    setValue('ubt.cache', diskCache);
  }, 1500);
}

/* ---------------- 取消域 ----------------
 * 整页翻译可能持续数秒，用户需要能中途叫停。
 * 做法：翻译开始时开一个 scope，把在途请求的 abort 函数登记进去，
 * 取消时统一中断；所有渲染 / 写页面的地方都要先检查 isCancelled()，
 * 避免取消之后迟到的响应又把页面写脏。
 */
let activeCancelScope = null;

function createCancelScope() {
  return { cancelled: false, aborts: new Set() };
}

function attachCancelScope(scope) {
  activeCancelScope = scope;
  return scope;
}

function detachCancelScope(scope) {
  if (activeCancelScope === scope) activeCancelScope = null;
}

/** 中断当前取消域里的所有在途请求；返回是否真的取消了 */
function cancelActiveScope() {
  const scope = activeCancelScope;
  if (!scope || scope.cancelled) return false;
  scope.cancelled = true;
  for (const fn of Array.from(scope.aborts)) {
    try { fn(); } catch (_) { /* 忽略 */ }
  }
  scope.aborts.clear();
  return true;
}

/** 当前是否处于已取消状态（没有取消域时恒为 false） */
function isCancelled() {
  return !!(activeCancelScope && activeCancelScope.cancelled);
}

/* ---------------- 网络：GM_xmlhttpRequest 封装 ---------------- */

/**
 * 统一请求入口。油猴脚本里直接用 fetch 会被 CORS 挡住，
 * 这里优先走 GM_xmlhttpRequest（跨域豁免），不可用时回退 fetch。
 */
function request(opts) {
  const { url, method = 'GET', headers = {}, body = null, timeout = UB.TIMEOUT_MS, responseType = 'text' } = opts;

  return new Promise((resolve, reject) => {
    const scope = activeCancelScope;
    // 登记取消回调，请求结束（成功或失败）后注销，避免集合无限增长
    let unregister = null;
    const track = (abortFn) => {
      if (!scope || scope.cancelled) return;
      scope.aborts.add(abortFn);
      unregister = () => scope.aborts.delete(abortFn);
    };
    const untrack = () => { if (unregister) { unregister(); unregister = null; } };

    if (typeof GM_xmlhttpRequest === 'function') {
      let settled = false;
      const done = (fn, arg) => {
        if (settled) return;
        settled = true;
        untrack();
        fn(arg);
      };
      try {
        const handle = GM_xmlhttpRequest({
          method,
          url,
          headers,
          data: body || undefined,
          timeout,
          responseType,
          onload: (res) => done(resolve, {
            ok: res.status >= 200 && res.status < 300,
            status: res.status,
            statusText: res.statusText || '',
            text: typeof res.responseText === 'string' ? res.responseText
              : (typeof res.response === 'string' ? res.response : ''),
          }),
          onerror: () => done(reject, new Error('网络请求失败（无法连接该服务）')),
          ontimeout: () => done(reject, new Error('请求超时')),
          onabort: () => done(reject, new Error('请求已取消')),
        });
        if (handle && typeof handle.abort === 'function') {
          track(() => { try { handle.abort(); } catch (_) { /* 忽略 */ } });
        }
      } catch (err) {
        done(reject, err);
      }
      return;
    }

    // fetch 回退（同源或不校验 CORS 的服务能用）
    const controller = new AbortController();
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; controller.abort(); }, timeout);
    track(() => { try { controller.abort(); } catch (_) { /* 忽略 */ } });

    fetch(url, { method, headers, body: body || undefined, signal: controller.signal })
      .then(async (res) => {
        const text = await res.text();
        clearTimeout(timer);
        untrack();
        resolve({ ok: res.ok, status: res.status, statusText: res.statusText, text });
      })
      .catch((err) => {
        clearTimeout(timer);
        untrack();
        // 区分「用户取消」和「真的超时」，前者不该弹错误提示
        if (err && err.name === 'AbortError') {
          reject(new Error(timedOut ? '请求超时' : '请求已取消'));
          return;
        }
        reject(err);
      });
  });
}

async function requestJson(url, init) {
  const res = await request({ url, responseType: 'text', ...init });
  if (!res.ok) {
    let detail = '';
    try {
      const j = JSON.parse(res.text);
      detail = (j.error && (j.error.message || j.error.code)) || j.message || j.msg || '';
    } catch (_) { detail = (res.text || '').slice(0, 200); }
    throw new Error(`服务返回 ${res.status}${detail ? '：' + detail : ''}`);
  }
  try {
    return JSON.parse(res.text);
  } catch (_) {
    throw new Error('服务返回的不是 JSON（可能被限流或需要登录）');
  }
}

/* ---------------- 工具 ---------------- */

function withConcurrency(items, limit, worker) {
  return new Promise((resolve, reject) => {
    const results = new Array(items.length);
    let index = 0, running = 0, done = 0, failed = false;
    if (!items.length) return resolve(results);
    const next = () => {
      if (failed) return;
      // 已取消：不再派发新任务，直接把已有结果交回去（由调用方决定丢弃）
      if (isCancelled()) return resolve(results);
      if (done === items.length) return resolve(results);
      while (running < limit && index < items.length) {
        const i = index++;
        running += 1;
        Promise.resolve()
          .then(() => worker(items[i], i))
          .then((v) => {
            results[i] = v;
            running -= 1; done += 1;
            next();
          })
          .catch((err) => {
            // 取消导致的请求中断不算失败
            if (isCancelled()) return resolve(results);
            failed = true;
            reject(err);
          });
      }
    };
    next();
  });
}

function decodeEntities(value) {
  const named = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", '#39': "'", nbsp: '\u00a0' };
  return String(value).replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (m, e) => {
    if (e.startsWith('#x') || e.startsWith('#X')) {
      const p = parseInt(e.slice(2), 16);
      return p >= 0 && p <= 0x10ffff ? String.fromCodePoint(p) : m;
    }
    if (e.startsWith('#')) {
      const p = parseInt(e.slice(1), 10);
      return p >= 0 && p <= 0x10ffff ? String.fromCodePoint(p) : m;
    }
    return named[e] !== undefined ? named[e] : m;
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /* =========================================================================
 * 第二部分：翻译服务适配器
 * 各服务的接口调用方式为自行实测整理，
 * 免费服务（无需密钥）：google / microsoft / mymemory
 * 需要密钥：openai 兼容（DeepSeek、智谱、Ollama、各类中转站）
 * ========================================================================= */

/* 语言代码在各服务之间不通用，分别归一化 */

function googleLang(code) {
  if (!code || code === 'auto') return 'auto';
  const map = {
    'zh-CN': 'zh-CN', 'zh-TW': 'zh-TW', 'zh': 'zh-CN',
    'ja': 'ja', 'ko': 'ko', 'en': 'en', 'fr': 'fr', 'de': 'de',
    'es': 'es', 'ru': 'ru', 'pt': 'pt', 'it': 'it', 'ar': 'ar',
  };
  return map[code] || code;
}

function microsoftLang(code) {
  if (!code || code === 'auto') return '';
  return googleLang(code);
}

function openAiLangName(code) {
  const map = {
    'zh-CN': '简体中文', 'zh-TW': '繁體中文', 'ja': '日语', 'ko': '韩语',
    'en': '英语', 'fr': '法语', 'de': '德语', 'es': '西班牙语',
    'ru': '俄语', 'pt': '葡萄牙语', 'it': '意大利语', 'ar': '阿拉伯语',
  };
  if (!code || code === 'auto') return '原文语言';
  return map[code] || code;
}

/* ---------- Google 网页接口（免费、无需密钥） ----------
 * 性能要点：q 参数只认一个值（传多个也只返回第一条），
 * 但可以在一次请求里用换行把多条文本拼起来一起翻译。
 * 注意返回的 segments 并不是「一行一段」——Google 会把一行拆成
 * 「译文」+「换行符」等多个片段，所以必须先拼回整串，再按换行切分。
 * 实测 40 条约 2s，比逐条快 10 倍以上。
 * ---------- */

const GOOGLE_BATCH_CHARS = 2000;   // 单次请求的字符上限
const GOOGLE_SEP = '\n';

async function translateGoogle(texts, sourceLang, targetLang) {
  const out = new Array(texts.length);

  // 按字符上限切成若干批，每批一次请求
  const batches = [];
  let cur = [];
  let curLen = 0;
  for (let i = 0; i < texts.length; i += 1) {
    const len = texts[i].length + 1;
    if (cur.length && curLen + len > GOOGLE_BATCH_CHARS) {
      batches.push(cur);
      cur = [];
      curLen = 0;
    }
    cur.push(i);
    curLen += len;
  }
  if (cur.length) batches.push(cur);

  // 批次之间并发，既快又不过度冲击免费接口
  await withConcurrency(batches, Math.min(4, batches.length), async (indexes) => {
    const joined = indexes.map((i) => texts[i].replace(/\s*\n+\s*/g, ' ')).join(GOOGLE_SEP);
    const lines = await googleTranslateLines(joined, indexes.length, sourceLang, targetLang);

    if (lines.length === indexes.length) {
      indexes.forEach((idx, j) => { out[idx] = lines[j].trim(); });
      return;
    }

    // 行数对不上（译文把多行合并了）：这一小批退回逐条翻译，保证正确性
    for (const idx of indexes) {
      out[idx] = await googleTranslateSingle(texts[idx], sourceLang, targetLang);
    }
  });
  return out;
}

/** 拼接整串后按换行切回各行，尽量还原出 expect 条 */
async function googleTranslateLines(joined, expect, sourceLang, targetLang) {
  const raw = await googleTranslateRaw(joined, sourceLang, targetLang);
  const whole = raw.join('');
  const lines = whole.split('\n');
  // 末尾常有多余空行，去掉
  while (lines.length > expect && lines[lines.length - 1].trim() === '') lines.pop();
  return lines;
}

/** 发送一次请求，返回原始 segments 文本数组 */
async function googleTranslateRaw(q, sourceLang, targetLang) {
  const url = new URL('https://translate.googleapis.com/translate_a/single');
  url.searchParams.set('client', 'gtx');
  url.searchParams.set('sl', googleLang(sourceLang));
  url.searchParams.set('tl', googleLang(targetLang));
  url.searchParams.set('dt', 't');
  url.searchParams.set('q', q);
  const payload = await requestJsonWithRetry(url.toString());
  if (!Array.isArray(payload) || !Array.isArray(payload[0])) {
    throw new Error('Google 返回格式异常');
  }
  return payload[0].map((seg) => (Array.isArray(seg) && typeof seg[0] === 'string' ? seg[0] : ''));
}

async function googleTranslateSingle(text, sourceLang, targetLang) {
  const segs = await googleTranslateRaw(text, sourceLang, targetLang);
  return segs.join('').trim();
}

/**
 * Google 免费接口在高频请求下会返回 429 / 5xx。
 * 这里做有限次退避重试；仍失败则抛出可直接展示给用户的错误。
 */
async function requestJsonWithRetry(url) {
  const delays = [400, 1200, 2400];
  let lastErr = null;
  for (let attempt = 0; attempt <= delays.length; attempt += 1) {
    try {
      return await requestJson(url);
    } catch (err) {
      lastErr = err;
      const msg = String(err && err.message || '');
      const retryable = /返回 (429|500|502|503|504)/.test(msg);
      if (!retryable || attempt === delays.length) break;
      await sleep(delays[attempt]);
    }
  }
  const msg = String(lastErr && lastErr.message || '');
  if (/返回 429/.test(msg)) {
    throw new Error('Google 免费接口被限流，请稍后重试，或切换到 Microsoft / MyMemory');
  }
  throw lastErr;
}

/* ---------- Microsoft Edge 网页接口（免费、无需密钥） ----------
 * 这个接口支持真正的批量：一次 POST 一个字符串数组即可（实测 50 条约 1.7s），
 * 所以整页翻译通常只需要一两次请求。
 * ---------- */

const MICROSOFT_BATCH_SIZE = 40;   // 单次请求的条数上限

async function translateMicrosoft(texts, sourceLang, targetLang) {
  const out = new Array(texts.length);
  const batches = [];
  for (let i = 0; i < texts.length; i += MICROSOFT_BATCH_SIZE) {
    batches.push(texts.slice(i, i + MICROSOFT_BATCH_SIZE).map((text, k) => i + k));
  }

  // 并发 2 批，既快又不至于触发限流
  await withConcurrency(batches, 2, async (indexes) => {
    const batch = indexes.map((k) => texts[k]);
    const res = await requestMicrosoftBatch(batch, sourceLang, targetLang);
    indexes.forEach((srcIndex, j) => { out[srcIndex] = res[j]; });
  });
  return out;
}

async function requestMicrosoftBatch(texts, sourceLang, targetLang) {
  const url = new URL('https://edge.microsoft.com/translate/translatetext');
  url.searchParams.set('from', microsoftLang(sourceLang));
  url.searchParams.set('to', microsoftLang(targetLang));

  const send = () => request({
    url: url.toString(),
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': 'https://edge.microsoft.com' },
    // Edge 接口按 HTML 解析尖括号，先转义
    body: JSON.stringify(texts.map((t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'))),
  });

  let res = await send();
  if (res.status === 429 || res.status >= 500) {
    await sleep(800);
    res = await send();
  }
  if (!res.ok) throw new Error(`Microsoft 返回 ${res.status}`);

  let payload;
  try { payload = JSON.parse(res.text); } catch (_) { throw new Error('Microsoft 返回格式异常'); }
  if (!Array.isArray(payload)) throw new Error('Microsoft 返回格式异常');
  if (payload.length !== texts.length) {
    throw new Error(`Microsoft 返回条数不符（原文 ${texts.length}，返回 ${payload.length}）`);
  }
  // 实际结构：[{ detectedLanguage, translations: [{ text, to }] }]
  // 少数情况下也可能直接是字符串，两种都兼容
  return payload.map((item) => {
    if (typeof item === 'string') return decodeEntities(item);
    if (item && Array.isArray(item.translations) && item.translations.length) {
      return decodeEntities(String(item.translations[0].text || ''));
    }
    throw new Error('Microsoft 返回格式异常');
  });
}

/* ---------- MyMemory（免费、有匿名额度） ---------- */

async function translateMyMemory(texts, sourceLang, targetLang) {
  const out = [];
  for (const text of texts) {
    const url = new URL('https://api.mymemory.translated.net/get');
    url.searchParams.set('q', text);
    url.searchParams.set('langpair', `${sourceLang && sourceLang !== 'auto' ? sourceLang : 'en'}|${targetLang}`);
    const payload = await requestJson(url.toString());
    const t = payload && payload.responseData && payload.responseData.translatedText;
    if (typeof t !== 'string') throw new Error('MyMemory 返回格式异常');
    out.push(decodeEntities(t));
  }
  return out;
}

/* ---------- OpenAI 兼容接口（DeepSeek / 智谱 / Ollama / 中转站） ---------- */

async function translateOpenAI(texts, sourceLang, targetLang) {
  const cfg = settings.services.openai || {};
  if (!cfg.baseURL) throw new Error('请先在设置里填写接口地址');
  if (!cfg.model) throw new Error('请先在设置里填写模型名');

  const base = cfg.baseURL.replace(/\/+$/, '');
  const url = /\/chat\/completions$/.test(base) ? base : base + '/chat/completions';

  // 编号后一次性提交，模型更容易保持行数对应
  const numbered = texts.map((t, i) => `[${i + 1}] ${t}`).join('\n');
  const userPrompt =
    `把下面每一行编号文本翻译成${openAiLangName(targetLang)}，` +
    `严格保持 ${texts.length} 行，每行以 [编号] 开头：\n\n${numbered}`;

  const headers = { 'Content-Type': 'application/json' };
  if (cfg.apiKey) headers['Authorization'] = 'Bearer ' + cfg.apiKey;

  const payload = await requestJson(url, {
    method: 'POST',
    headers,
    timeout: 90000,
    body: JSON.stringify({
      model: cfg.model,
      temperature: 0.2,
      messages: [
        { role: 'system', content: cfg.systemPrompt || '你是专业翻译，只输出译文。' },
        { role: 'user', content: userPrompt },
      ],
    }),
  });

  const content = payload && payload.choices && payload.choices[0] &&
    payload.choices[0].message && payload.choices[0].message.content;
  if (typeof content !== 'string') throw new Error('模型返回格式异常');

  const lines = content.split('\n').filter((l) => l.trim() !== '');
  const parsed = [];
  for (const line of lines) {
    const m = line.match(/^\s*\[(\d+)\]\s*(.*)$/);
    if (m) parsed[parseInt(m[1], 10) - 1] = m[2];
  }
  if (parsed.length !== texts.length || parsed.some((v) => typeof v !== 'string')) {
    // 行数对不上就整体返回原文，交给上层标记失败，不乱写页面
    throw new Error(`译文行数与原文不一致（原文 ${texts.length} 行，返回 ${customCount(parsed)} 行）`);
  }
  return parsed;
}

function customCount(arr) {
  let n = 0;
  for (let i = 0; i < arr.length; i += 1) if (typeof arr[i] === 'string') n += 1;
  return n;
}

/* ---------- 服务注册表 ---------- */

const PROVIDERS = {
  google: { label: 'Google（免费）', fn: translateGoogle, limit: 4 },
  microsoft: { label: 'Microsoft（免费）', fn: translateMicrosoft, limit: 1 },
  mymemory: { label: 'MyMemory（免费）', fn: translateMyMemory, limit: 1 },
  openai: { label: 'OpenAI 兼容 / DeepSeek', fn: translateOpenAI, limit: 2 },
};

/**
 * 翻译一批文本。带缓存；缓存未命中的部分才真正请求。
 * @returns {Promise<string[]>} 与输入等长的译文数组
 */
async function translateTexts(texts) {
  if (!settings) settings = loadSettings(); // 兜底：正常由 init() 赋值
  const provider = PROVIDERS[settings.provider] ? settings.provider : 'google';
  const from = settings.sourceLang;
  const to = settings.targetLang;

  const keys = texts.map((t) => cacheKey(provider, from, to, t));
  const results = new Array(texts.length);
  const missing = [];

  for (let i = 0; i < texts.length; i += 1) {
    const hit = cacheGet(keys[i]);
    if (typeof hit === 'string') results[i] = hit;
    else missing.push(i);
  }
  if (!missing.length) return results;

  const pending = missing.map((i) => texts[i]);
  const translated = await PROVIDERS[provider].fn(pending, from, to);

  if (translated.length !== pending.length) {
    throw new Error('译文数量与原文不一致');
  }
  missing.forEach((srcIndex, j) => {
    results[srcIndex] = translated[j];
    cacheSet(keys[srcIndex], translated[j]);
  });
  return results;
}

/** 划词单条翻译 */
async function translateOne(text) {
  const [v] = await translateTexts([text]);
  return v;
}

/**
 * 整页翻译入口：先查缓存，未命中的部分整批交给服务层（服务内部自行分批并发）。
 * onProgress(done, total) 用于刷新进度。
 * @returns {Promise<string[]>} 与输入等长的译文数组
 */
async function translateAll(texts, onProgress) {
  if (!settings) settings = loadSettings();
  const provider = PROVIDERS[settings.provider] ? settings.provider : 'google';
  const from = settings.sourceLang;
  const to = settings.targetLang;

  const keys = texts.map((t) => cacheKey(provider, from, to, t));
  const results = new Array(texts.length);
  const missing = [];

  for (let i = 0; i < texts.length; i += 1) {
    const hit = cacheGet(keys[i]);
    if (typeof hit === 'string') results[i] = hit;
    else missing.push(i);
  }

  const total = texts.length;
  if (onProgress) onProgress(texts.length - missing.length, total);
  if (!missing.length) return results;

  const pending = missing.map((i) => texts[i]);
  const translated = await PROVIDERS[provider].fn(pending, from, to);

  if (translated.length !== pending.length) {
    throw new Error('译文数量与原文不一致');
  }
  missing.forEach((srcIndex, j) => {
    results[srcIndex] = translated[j];
    cacheSet(keys[srcIndex], translated[j]);
  });

  if (onProgress) onProgress(total, total);
  return results;
}

  /* =========================================================================
 * 第三部分：页面扫描 + 内联翻译 + 双语渲染 + 还原原文
 *
 * 思路：
 * 1. TreeWalker 遍历文本节点，过滤掉脚本/代码/输入框等不该翻的区域；
 * 2. 发现 Shadow DOM（开放）也进去扫；
 * 3. 按文本节点收集，批量送翻译，再按设定模式渲染；
 * 4. 每个被翻的节点都记录原文，支持随时还原。
 * ========================================================================= */

const state = {
  running: false,
  translated: false,
  filling: false,        // 正在补翻动态内容，防止重入
  records: [],           // { node, original, holder }
  observer: null,
  paragraphs: new Map(), // 段落容器 -> 该段产生的渲染记录
  paragraphBusy: false,  // 段落翻译进行中
  cancelScope: null,     // 当前整页翻译的取消域
};

/* ---------------- 文本过滤 ---------------- */

const CJK_RE = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af]/g;

/**
 * 判断一段文字是否已经是目标语言（是的话就不用翻）。
 * 目标语言为中文时：中文字符数 >= 拉丁字母数的 1.5 倍，就认为它主要是中文。
 * 这样「这是 Vue 3 的例子，演示组合式 API 的用法」不会被当成英文去翻，
 * 而「Vue 3 is great，真的很棒」这种以英文为主的段落仍然会翻。
 */
function isProbablyTargetLang(text) {
  if (!settings.targetLang.startsWith('zh')) return false;
  const cjk = (text.match(CJK_RE) || []).length;
  if (cjk === 0) return false;
  const latin = (text.match(/[A-Za-z]/g) || []).length;
  return cjk >= latin * 1.5;
}

function isTranslatableText(text) {
  const t = text.trim();
  if (t.length < 2) return false;
  if (!/[A-Za-z\u00c0-\u024f\u0400-\u04ff]/.test(t)) return false; // 里面得有拉丁/西里尔字母
  if (/^[\d\s\p{P}\p{S}]+$/u.test(t)) return false;
  if (/^(https?:\/\/|www\.)/i.test(t)) return false;
  return true;
}

function isExcludedNode(node) {
  let el = node.parentElement;
  while (el) {
    if (el.hasAttribute && el.hasAttribute(UB.ATTR)) return true;
    if (el.matches && el.matches(UB.SKIP_SEL)) return true;
    if (el.isContentEditable) return true;
    el = el.parentElement;
  }
  for (const sel of settings.excludeSelectors) {
    if (!sel) continue;
    try {
      let p = node.parentElement;
      while (p) {
        if (p.matches && p.matches(sel)) return true;
        p = p.parentElement;
      }
    } catch (_) { /* 选择器写错就忽略 */ }
  }
  return false;
}

/**
 * 判断元素是否可见。
 * 注意：只依据样式判断「是否被明确隐藏」，不要求尺寸大于 0。
 * 因为页面刚加载、布局还没完成时尺寸可能全是 0，
 * 早期版本严格要求尺寸会导致整页扫不到内容（表现为「没有找到需要翻译的内容」）。
 */
function isVisible(el) {
  if (!el || !el.isConnected) return false;
  let style;
  try {
    style = getComputedStyle(el);
  } catch (_) {
    return true;
  }
  if (!style) return true;
  if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') return false;
  if (style.opacity === '0') return false;
  // 显式隐藏的属性
  if (el.hasAttribute && (el.hasAttribute('hidden') || el.getAttribute('aria-hidden') === 'true')) return false;
  return true;
}

/* ---------------- 扫描 ---------------- */

function collectTextNodes(root) {
  const found = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT, {
    acceptNode(node) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        // 开放 Shadow DOM 也要进去
        if (node.shadowRoot) {
          found.push(...collectTextNodes(node.shadowRoot));
        }
        return NodeFilter.FILTER_SKIP;
      }
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  let node = walker.nextNode();
  while (node) {
    const text = node.nodeValue;
    if (text && isTranslatableText(text) && !isExcludedNode(node) && isVisible(node.parentElement) && !isProbablyTargetLang(text)) {
      found.push({ node, text });
    }
    node = walker.nextNode();
  }
  return found;
}

function splitIntoChunks(items, maxChars) {
  const chunks = [];
  let cur = [];
  let len = 0;
  for (const item of items) {
    const l = item.text.length;
    if (cur.length && len + l > maxChars) {
      chunks.push(cur);
      cur = [];
      len = 0;
    }
    cur.push(item);
    len += l;
  }
  if (cur.length) chunks.push(cur);
  return chunks;
}

/* ---------------- 渲染 ---------------- */

/**
 * 判断文本节点当前是否落在视口内（含一屏缓冲）。
 * 用于「先翻看得见的部分」，让用户几乎立刻看到结果。
 */
function isNodeInViewport(node, buffer) {
  const el = node.parentElement;
  if (!el || typeof el.getBoundingClientRect !== 'function') return false;
  let rect;
  try { rect = el.getBoundingClientRect(); } catch (_) { return false; }
  if (!rect || (!rect.width && !rect.height)) return false;
  const vh = window.innerHeight || 768;
  const pad = typeof buffer === 'number' ? buffer : vh * 0.5;
  // 节点与 [−pad, vh+pad] 有交集即视为「附近」
  return rect.bottom > -pad && rect.top < vh + pad;
}

/**
 * 把待翻节点分成「视口附近」和「其余」两组，视口组保持文档顺序。
 * 视口组翻完就能覆盖用户当前看到的全部内容。
 */
function partitionByViewport(items) {
  const near = [];
  const rest = [];
  for (const it of items) {
    if (isNodeInViewport(it.node)) near.push(it);
    else rest.push(it);
  }
  return { near, rest };
}

function clearRendered() {
  for (const rec of state.records) {
    // 属性翻译：把原属性值写回去
    if (rec.kind === 'attr') {
      if (rec.el && rec.el.setAttribute && rec.el.getAttribute(rec.attr) === rec.translated) {
        rec.el.setAttribute(rec.attr, rec.original);
      }
      if (rec.el && rec.el.removeAttribute) rec.el.removeAttribute(ATTR_TRANS_FLAG);
      continue;
    }
    // 双语模式插进去的译文节点
    if (rec.holder && rec.holder.parentNode) rec.holder.parentNode.removeChild(rec.holder);
    // 替换模式恢复原文
    if (rec.node && rec.node.nodeValue !== rec.original) rec.node.nodeValue = rec.original;
  }
  state.records = [];
}

/* ---------------- 属性翻译（图片 alt / title 等） ----------------
 * 图片里画出来的文字需要 OCR，本脚本不做；
 * 但 <img alt="..."> 这类属性里的文字是真实文本，可以翻。
 * 做法：直接把译文写回属性，鼠标悬停时浏览器的原生 tooltip 就显示译文。
 * 额外把原文存到 data-ub-orig-alt，方便还原和悬停时对照。
 */

const ATTR_TRANS_FLAG = 'data-ub-attr-trans';

/** 需要翻译的属性名（按优先级） */
const TRANSLATABLE_ATTRS = ['alt', 'title', 'aria-label', 'placeholder'];

/** 收集页面上可翻译的属性文本 */
function collectAttrItems(root) {
  if (!settings.translateAttributes) return [];
  const found = [];
  const scope = root && root.querySelectorAll ? root : document;
  let els;
  try {
    els = scope.querySelectorAll('img[alt], [title], [aria-label], input[placeholder], textarea[placeholder]');
  } catch (_) { return []; }

  for (const el of els) {
    // 已经翻过的不重复收集
    if (el.hasAttribute && el.hasAttribute(ATTR_TRANS_FLAG)) continue;
    if (!isVisible(el)) continue;

    for (const attr of TRANSLATABLE_ATTRS) {
      if (!el.hasAttribute || !el.hasAttribute(attr)) continue;
      const raw = el.getAttribute(attr);
      if (!raw) continue;
      const text = raw.trim();
      if (!isTranslatableText(text)) continue;
      if (isProbablyTargetLang(text)) continue;
      // 属性文本通常很短，跳过纯文件名 / 尺寸串
      if (/^[\w\-.]+\.(png|jpe?g|gif|webp|svg|bmp)$/i.test(text)) continue;

      found.push({ kind: 'attr', el, attr, text });
      break;   // 同一个元素只翻第一个命中的属性，避免重复请求
    }
  }
  return found;
}

/** 把译文写回属性 */
function renderAttrs(pairs) {
  let n = 0;
  for (const p of pairs) {
    const { el, attr, text, translated } = p;
    if (!el || !el.isConnected) continue;
    if (!el.setAttribute) continue;
    // 保留原文，便于还原与悬停对照
    if (!el.hasAttribute('data-ub-orig-' + attr)) {
      el.setAttribute('data-ub-orig-' + attr, text);
    }
    el.setAttribute(attr, translated);
    el.setAttribute(ATTR_TRANS_FLAG, '1');
    state.records.push({ kind: 'attr', el, attr, original: text, translated });
    n += 1;
  }
  return n;
}

/**
 * 按当前显示模式渲染。
 * pairs: [{ node, text, translated }]
 */
function renderAll(pairs) {
  // pairs: [{node, text, translated}]
  for (const p of pairs) {
    const { node, text, translated } = p;
    if (!node.isConnected) continue;

    if (settings.displayMode === 'replace') {
      node.nodeValue = translated;
      state.records.push({ node, original: text, holder: null });
      continue;
    }

    const parent = node.parentElement;
    if (!parent) continue;

    const holder = document.createElement('span');
    holder.setAttribute(UB.ATTR, 'target');
    holder.className = 'ub-trans-inline';
    if (settings.displayMode === 'bilingual-accent') holder.classList.add('ub-accent');
    holder.textContent = translated;

    // 插在原文文本节点后面
    if (node.nextSibling) parent.insertBefore(holder, node.nextSibling);
    else parent.appendChild(holder);

    state.records.push({ node, original: text, holder });
  }
}

/* ---------------- 主流程 ---------------- */

/** 单次批量提交的条数上限，控制「边翻边渲染」的粒度 */
const RENDER_CHUNK_SIZE = 50;

/**
 * 分批翻译并边翻边渲染。
 * 每翻完一小批就立刻写回页面，用户不用等整页翻完。
 * @returns {Promise<{rendered:number, cancelled:boolean}>}
 */
async function translateInChunks(items, progress) {
  let rendered = 0;
  let done = 0;
  const total = items.length;

  for (let i = 0; i < items.length; i += RENDER_CHUNK_SIZE) {
    if (isCancelled()) return { rendered, cancelled: true };

    const slice = items.slice(i, i + RENDER_CHUNK_SIZE);
    const translated = await translateAll(slice.map((c) => c.text.trim()));

    // 取消后迟到的响应一律丢弃，不写页面
    if (isCancelled()) return { rendered, cancelled: true };

    const pairs = [];
    slice.forEach((c, k) => {
      if (typeof translated[k] === 'string' && translated[k]) {
        pairs.push({ node: c.node, text: c.text, translated: translated[k] });
      }
    });
    if (pairs.length) {
      renderAll(pairs);
      rendered += pairs.length;
    }

    done += slice.length;
    if (progress) progress(done, total, rendered);
  }
  return { rendered, cancelled: false };
}

async function translatePage() {
  if (state.running) return;
  state.running = true;
  setStatus('translating');
  const startedAt = Date.now();

  // 开一个取消域：翻译期间点悬浮球可以随时叫停
  const scope = attachCancelScope(createCancelScope());
  state.cancelScope = scope;

  try {
    const items = collectTextNodes(document.body || document.documentElement);
    const attrCount = settings.translateAttributes ? collectAttrItems(document).length : 0;
    if (!items.length && !attrCount) {
      setStatus('done-empty');
      toast('没有找到需要翻译的内容');
      return;
    }

    // 先翻视口附近的内容，再补齐剩下的
    const { near, rest } = partitionByViewport(items);
    const total = items.length;
    let rendered = 0;

    if (near.length) {
      const r1 = await translateInChunks(near, (done, _t, r) => {
        setStatus('progress', { done, total });
        rendered = r;
      });
      if (r1.cancelled) return;
      rendered = r1.rendered;
      // 视口部分已就绪：立即标记为已翻译，让用户能马上还原 / 交互
      if (rendered) {
        state.translated = true;
        setStatus('done');
      }
    }

    if (rest.length) {
      if (near.length) setStatus('translating');
      const base = near.length;
      const r2 = await translateInChunks(rest, (done, _t, r) => {
        setStatus('progress', { done: base + done, total });
        rendered = (near.length ? rendered : 0) + r;
      });
      if (r2.cancelled) return;
      rendered = (near.length ? rendered : 0) + r2.rendered;
    }

    // 属性文本（图片 alt / title 等）不参与整页批量，单独走一遍，
    // 因为它们通常很短、数量少，且不进 DOM 文本节点。
    if (settings.translateAttributes) {
      const attrItems = collectAttrItems(document);
      if (attrItems.length) {
        const at = await translateAll(attrItems.map((a) => a.text));
        if (isCancelled()) return;
        const attrPairs = [];
        attrItems.forEach((a, i) => {
          if (typeof at[i] === 'string' && at[i]) {
            attrPairs.push({ el: a.el, attr: a.attr, text: a.text, translated: at[i] });
          }
        });
        if (attrPairs.length) rendered += renderAttrs(attrPairs);
      }
    }

    if (rendered) {
      state.translated = true;
      setStatus('done');
      enableObserver();
      setupAutoRescan();
      const secs = ((Date.now() - startedAt) / 1000).toFixed(1);
      toast(`已翻译 ${rendered} 处，用时 ${secs} 秒`);
    } else {
      setStatus('idle');
    }
  } catch (err) {
    // 用户主动取消导致的请求中断，不弹错误
    if (isCancelled() || /请求已取消/.test(String(err && err.message))) {
      return;
    }
    console.error('[无界翻译] 翻译失败', err);
    toast('翻译失败：' + (err && err.message ? err.message : '未知错误'), 'error');
    setStatus('idle');
  } finally {
    detachCancelScope(scope);
    if (state.cancelScope === scope) state.cancelScope = null;
    state.running = false;
  }
}

/** 取消正在进行的整页翻译，并保留已经渲染出来的部分 */
async function cancelTranslate() {
  const scope = state.cancelScope;
  if (!scope) return false;
  scope.cancelled = true;
  cancelActiveScope();
  // 已渲染的内容保留为「部分翻译」状态，用户可继续看或还原
  if (state.records.length) {
    state.translated = true;
    setStatus('done');
    enableObserver();
    setupAutoRescan();
  } else {
    setStatus('idle');
  }
  toast('已取消翻译');
  return true;
}

function restorePage() {
  // 在途翻译先取消，否则迟到的响应会把译文又插回来
  if (state.cancelScope) {
    state.cancelScope.cancelled = true;
    cancelActiveScope();
  }
  // 先清段落模式翻过的部分，再清整页记录
  if (typeof restoreAllParagraphs === 'function') restoreAllParagraphs();
  clearRendered();
  state.translated = false;
  disableObserver();
  stopAutoRescan();
  setStatus('idle');
}

/* 动态内容补翻：DOM 变化后延迟再扫一遍新节点 */
function enableObserver() {
  if (state.observer) return;
  if (typeof MutationObserver === 'undefined') return; // 环境不支持就只靠定时补扫
  let timer = null;
  state.observer = new MutationObserver((mutations) => {
    if (!state.translated) return;
    let hasNewText = false;
    for (const m of mutations) {
      if (m.type === 'childList' && m.addedNodes.length) { hasNewText = true; break; }
      if (m.type === 'characterData') { hasNewText = true; break; }
    }
    if (!hasNewText) return;
    clearTimeout(timer);
    timer = setTimeout(() => { translateNewOnly().catch(() => undefined); }, 800);
  });
  try {
    state.observer.observe(document.body || document.documentElement, {
      childList: true, subtree: true, characterData: true,
    });
  } catch (_) {
    state.observer = null;
  }
}

function disableObserver() {
  if (state.observer) { state.observer.disconnect(); state.observer = null; }
}

/** 只翻新出现、还没翻过的节点 */
async function translateNewOnly() {
  if (!state.translated || state.filling) return;
  state.filling = true;
  try {
    const known = new Set(state.records.map((r) => r.node));
    const items = collectTextNodes(document.body || document.documentElement)
      .filter((it) => !known.has(it.node));

    // 新增的属性文本也一并补翻（已翻过的带 ATTR_TRANS_FLAG，不会被重复收集）
    const attrItems = collectAttrItems(document);
    if (!items.length && !attrItems.length) return;

    if (items.length) {
      // 新内容通常不多，整批一次交给服务层（它内部会自行分批并发）
      const translated = await translateAll(items.map((c) => c.text.trim()));
      const pairs = [];
      items.forEach((c, i) => {
        if (typeof translated[i] === 'string' && translated[i]) {
          pairs.push({ node: c.node, text: c.text, translated: translated[i] });
        }
      });
      renderAll(pairs);
    }

    if (attrItems.length) {
      const at = await translateAll(attrItems.map((a) => a.text));
      const attrPairs = [];
      attrItems.forEach((a, i) => {
        if (typeof at[i] === 'string' && at[i]) {
          attrPairs.push({ el: a.el, attr: a.attr, text: a.text, translated: at[i] });
        }
      });
      renderAttrs(attrPairs);
    }
  } finally {
    state.filling = false;
  }
}

let autoRescanTimer = null;
function setupAutoRescan() {
  // 有些站点用虚拟列表/滚动加载，这里兜底每 5 秒补一次（只在已翻译状态）
  if (autoRescanTimer) return;
  autoRescanTimer = setInterval(() => {
    if (!state.translated) { stopAutoRescan(); return; }
    if (!state.running) translateNewOnly().catch(() => undefined);
  }, 5000);
}

/** 停止定时补扫（还原原文时调用，避免定时器空转） */
function stopAutoRescan() {
  if (autoRescanTimer) {
    clearInterval(autoRescanTimer);
    autoRescanTimer = null;
  }
}

  /* =========================================================================
 * 第五部分：段落模式
 *
 * 电脑：Ctrl + 左键点击段落 → 翻译该段；再点一次 → 还原
 * 手机：开启段落模式后，直接点段落就能翻（触屏没有 Ctrl 键）
 *
 * 「段落」的判定：从点击的节点向上找最近的可读块级容器
 * （p / li / blockquote / td / h1-h6 / article / section / div），
 * 收集它内部的所有可翻文本，作为一个整体提交翻译。
 * ========================================================================= */

/* 什么元素算「一个段落」：优先这些语义块 */
const PARA_TAGS = ['p', 'li', 'blockquote', 'dd', 'dt', 'figcaption', 'td', 'th', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'];

/* 向上找段落容器时，最多爬这么多层，避免把整个 body 当成一段 */
const PARA_MAX_DEPTH = 12;

/** 从点击位置找到「这一段」的容器元素 */
function findParagraphElement(start) {
  let el = start;
  let depth = 0;
  let fallback = null;

  while (el && el.nodeType === 1 && el !== document.body && el !== document.documentElement) {
    const tag = el.tagName.toLowerCase();

    if (PARA_TAGS.includes(tag)) return el;

    // div/article/section 这类容器：只有当它「文本不太长」时才算一段，
    // 否则继续往上找更合适的祖先
    if (!fallback && ['div', 'article', 'section', 'main'].includes(tag)) {
      const text = (el.textContent || '').trim();
      if (text.length > 3 && text.length <= 1500 && el.querySelectorAll('p,li,div').length <= 2) {
        fallback = el;
      }
    }

    el = el.parentElement;
    depth += 1;
    if (depth > PARA_MAX_DEPTH) break;
  }
  return fallback;
}

/** 收集某个段落容器内所有可翻译的文本节点 */
function collectTextsIn(element) {
  if (!element) return [];
  const items = [];
  const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const text = node.nodeValue;
      if (!text || !isTranslatableText(text)) return NodeFilter.FILTER_REJECT;
      if (isExcludedNode(node)) return NodeFilter.FILTER_REJECT;
      if (isProbablyTargetLang(text)) return NodeFilter.FILTER_REJECT;
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  let node = walker.nextNode();
  while (node) {
    items.push({ node, text: node.nodeValue });
    node = walker.nextNode();
  }
  return items;
}

/**
 * 翻译指定段落。已翻译过的段落再调用一次就是还原。
 * @returns {Promise<'translated'|'restored'|'empty'|'busy'>}
 */
async function toggleParagraph(element) {
  if (!element) return 'empty';

  // 已翻过 → 还原
  const own = state.paragraphs.get(element);
  if (own) {
    restoreParagraph(element);
    return 'restored';
  }

  const items = collectTextsIn(element);
  if (!items.length) return 'empty';
  if (state.paragraphBusy) return 'busy';

  state.paragraphBusy = true;
  try {
    const translated = await translateAll(items.map((c) => c.text.trim()));
    const pairs = [];
    items.forEach((c, i) => {
      if (typeof translated[i] === 'string' && translated[i]) {
        pairs.push({ node: c.node, text: c.text, translated: translated[i] });
      }
    });
    if (!pairs.length) return 'empty';

    // 记录这个段落新产生的渲染记录，便于整段还原
    const before = state.records.length;
    renderAll(pairs);
    const added = state.records.slice(before);
    state.paragraphs.set(element, added);

    // 给容器加个类，方便样式和「已翻译」提示
    if (element.classList) element.classList.add('ub-para-done');
    return 'translated';
  } finally {
    state.paragraphBusy = false;
  }
}

/** 还原某一段落 */
function restoreParagraph(element) {
  const added = state.paragraphs.get(element);
  if (!added) return false;
  for (const rec of added) {
    if (rec.holder && rec.holder.parentNode) rec.holder.parentNode.removeChild(rec.holder);
    else if (rec.node && rec.node.nodeValue !== rec.original) rec.node.nodeValue = rec.original;
  }
  // 从总记录里移除，避免 restorePage 时重复处理
  state.records = state.records.filter((r) => !added.includes(r));
  state.paragraphs.delete(element);
  if (element.classList) element.classList.remove('ub-para-done');
  return true;
}

/** 还原所有已翻译段落（整页还原时调用） */
function restoreAllParagraphs() {
  for (const element of Array.from(state.paragraphs.keys())) restoreParagraph(element);
  state.paragraphs.clear();
}

/* ---------------- 事件绑定 ---------------- */

/** 判断是否触屏为主的设备 */
function isTouchPrimary() {
  return (typeof matchMedia !== 'undefined' && matchMedia('(pointer: coarse)').matches)
    || (typeof navigator !== 'undefined' && /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent || ''));
}

/* 点了这些元素不算「点段落」，避免干扰正常交互 */
const PARA_IGNORE_SEL = [
  'a', 'button', 'input', 'textarea', 'select', 'label', 'summary', 'option',
  'audio', 'video', 'canvas', 'img', 'svg',
  '[role="button"]', '[role="link"]', '[role="tab"]', '[role="menuitem"]',
  '[contenteditable="true"]', '[onclick]',
  '.ub-bubble', '.ub-ball', '.ub-menu', '.ub-panel-mask', '.ub-toast',
  '.ub-trans-inline', '[data-ub-trans]',
].join(',');

/**
 * 绑定段落模式的点击事件。
 * 电脑和手机统一为「点一下段落就翻译」，再点一下还原。
 *
 * 为了避免误触，以下情况不触发：
 * - 点在链接、按钮、输入框、媒体元素、可编辑区上
 * - 选区不为空（用户正在选文字，交给划词翻译）
 * - 点击落在纯空白处
 */
function bindParagraphMode() {
  document.addEventListener('click', (e) => {
    if (!settings.paragraphMode) return;

    const targetEl = e.target && e.target.nodeType === 1 ? e.target : (e.target && e.target.parentElement);
    if (!targetEl) return;

    // 交互元素、翻译自身 UI：一律放过
    if (targetEl.closest && targetEl.closest(PARA_IGNORE_SEL)) return;

    // 用户正在选中文字：不翻段落（那是划词翻译的场景）
    const sel = window.getSelection && window.getSelection();
    if (sel && !sel.isCollapsed) return;

    // 点在元素的空白区域（不是文字上）也不翻，减少误触
    if (typeof isPointOnText === 'function' && !isPointOnText(e)) return;

    const para = findParagraphElement(targetEl);
    if (!para) return;

    e.preventDefault();
    e.stopPropagation();

    toggleParagraph(para)
      .then((result) => {
        if (result === 'empty') toast('这一段没有可翻译的内容');
        else if (result === 'busy') toast('正在翻译，请稍候');
        else if (result === 'restored') toast('已还原');
      })
      .catch((err) => {
        toast('翻译失败：' + (err && err.message ? err.message : '未知错误'), 'error');
      });
  }, true);

  // 触屏上长按已翻译段落时，别弹系统菜单
  document.addEventListener('contextmenu', (e) => {
    if (!settings.paragraphMode || !isTouchPrimary()) return;
    const el = e.target && e.target.nodeType === 1 ? e.target : e.target.parentElement;
    if (el && el.closest && el.closest('.ub-para-done')) e.preventDefault();
  });
}

/** 判断点击位置是否真的落在文字上（而不是元素内部的空白） */
function isPointOnText(e) {
  if (typeof e.clientX !== 'number' || typeof e.clientY !== 'number') return true;
  try {
    // 临时移开可能挡住指针的浮层不现实，这里直接用 caretRangeFromPoint
    if (document.caretRangeFromPoint) {
      const range = document.caretRangeFromPoint(e.clientX, e.clientY);
      if (!range) return false;
      const offset = range.startOffset;
      const node = range.startContainer;
      // 落在文本节点内部 → 是文字
      if (node && node.nodeType === 3) return true;
      // 落在元素上且这个元素有文本，也算点了文字
      return !!(node && node.textContent && node.textContent.trim());
    }
    if (document.caretPositionFromPoint) {
      const pos = document.caretPositionFromPoint(e.clientX, e.clientY);
      if (!pos) return false;
      return pos.offsetNode && pos.offsetNode.nodeType === 3;
    }
  } catch (_) { /* 忽略 */ }
  return true;
}

  /* =========================================================================
 * 第四部分：界面
 * - 悬浮球（拖动、点击展开菜单）
 * - 划词翻译气泡
 * - 设置面板
 * - 状态提示 toast
 * ========================================================================= */

const UI_ID = 'ub-ui-root';

/* ---------------- 样式 ---------------- */

function injectStyles() {
  if (document.getElementById('ub-style')) return;
  const style = document.createElement('style');
  style.id = 'ub-style';
  style.textContent = `
  #ub-ui-root, #ub-ui-root * { box-sizing: border-box; font-family: -apple-system, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif; }

  .ub-trans-inline {
    color: var(--ub-accent, #4f8cff);
    margin-left: .35em;
    display: inline;
  }
  .ub-trans-inline.ub-accent { color: #ff7043; }

  .ub-ball {
    position: fixed; z-index: 2147483400; width: 44px; height: 44px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center; cursor: pointer;
    background: var(--ub-accent, #4f8cff); color: #fff; font-size: 15px; font-weight: 700;
    box-shadow: 0 4px 14px rgba(0,0,0,.28); user-select: none; -webkit-user-select: none;
    touch-action: none; -webkit-touch-callout: none;
    transition: transform .15s ease, opacity .2s ease; opacity: .92;
  }
  .ub-ball:hover { transform: scale(1.06); opacity: 1; }
  .ub-ball[data-state="translating"] { animation: ub-pulse 1s infinite; }
  @keyframes ub-pulse { 0%,100%{opacity:.85} 50%{opacity:.45} }
  /* 点击反馈：一次性缩放 + 光环，700ms 内自动结束 */
  .ub-ball.ub-ball-pulse { animation: ub-ball-pulse .45s ease; }
  @keyframes ub-ball-pulse {
    0%   { transform: scale(1);    box-shadow: 0 4px 14px rgba(0,0,0,.28), 0 0 0 0 rgba(79,140,255,.55); }
    45%  { transform: scale(1.18); box-shadow: 0 4px 14px rgba(0,0,0,.28), 0 0 0 12px rgba(79,140,255,0); }
    100% { transform: scale(1);    box-shadow: 0 4px 14px rgba(0,0,0,.28), 0 0 0 0 rgba(79,140,255,0); }
  }


  .ub-bubble {
    /* fixed：气泡坐标来自 getBoundingClientRect（视口坐标），
       用 absolute 会被页面滚动量抵消，滚动后气泡会跑到视口外 */
    position: fixed; z-index: 2147483500; max-width: 340px; padding: 10px 12px 8px;
    background: #fff; color: #222; border-radius: 10px; font-size: 13px; line-height: 1.55;
    box-shadow: 0 8px 28px rgba(0,0,0,.25); border: 1px solid rgba(0,0,0,.08);
  }
  .ub-bubble.ub-dark { background: #26282e; color: #e8e8e8; }
  .ub-bubble .ub-src {
    opacity: .6; font-size: 12px; margin-bottom: 6px; word-break: break-word;
    max-height: 3.6em; overflow: hidden;
  }
  .ub-bubble .ub-dst { font-size: 14px; word-break: break-word; white-space: pre-wrap; }
  .ub-bubble-actions {
    display: flex; gap: 6px; justify-content: flex-end; align-items: center;
    margin-top: 8px; padding-top: 6px; border-top: 1px solid rgba(128,128,128,.18);
  }
  .ub-bubble-btn {
    border: none; background: rgba(128,128,128,.16); color: inherit; cursor: pointer;
    font-size: 11px; padding: 3px 9px; border-radius: 6px; line-height: 1.6;
  }
  .ub-bubble-btn:hover { background: rgba(128,128,128,.3); }

  .ub-toast {
    position: fixed; left: 50%; bottom: 32px; transform: translateX(-50%);
    z-index: 2147483600; padding: 9px 16px; border-radius: 8px; font-size: 13px;
    background: rgba(30,30,34,.92); color: #fff; max-width: 80vw;
  }
  .ub-toast[data-level="error"] { background: rgba(190,45,45,.95); }

  .ub-panel-mask {
    position: fixed; inset: 0; z-index: 2147483700; background: rgba(0,0,0,.45);
    display: flex; align-items: center; justify-content: center;
  }
  .ub-panel {
    width: min(420px, 92vw); max-height: 84vh; overflow: auto; background: #fff; color: #222;
    border-radius: 14px; padding: 18px 18px 14px; font-size: 13px;
    box-shadow: 0 16px 48px rgba(0,0,0,.35);
  }
  .ub-panel.ub-dark { background: #26282e; color: #e8e8e8; }
  .ub-panel h3 { margin: 0 0 14px; font-size: 15px; }
  .ub-row { margin-bottom: 12px; }
  .ub-row label { display: block; margin-bottom: 5px; opacity: .75; font-size: 12px; }
  .ub-row select, .ub-row input[type="text"], .ub-row input[type="password"], .ub-row textarea {
    width: 100%; padding: 7px 9px; border-radius: 7px; font-size: 13px;
    border: 1px solid rgba(128,128,128,.35); background: rgba(255,255,255,.95); color: #222;
  }
  .ub-panel.ub-dark .ub-row select, .ub-panel.ub-dark .ub-row input, .ub-panel.ub-dark .ub-row textarea {
    background: #1e2025; color: #e8e8e8; border-color: rgba(255,255,255,.15);
  }
  .ub-row textarea { min-height: 60px; resize: vertical; }
  .ub-check { display: flex; align-items: center; gap: 8px; }
  .ub-check input { width: auto; }
  .ub-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 16px; }
  .ub-btn {
    padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; font-size: 13px;
    background: rgba(128,128,128,.18); color: inherit;
  }
  .ub-btn.ub-primary { background: var(--ub-accent, #4f8cff); color: #fff; }
  .ub-hint { opacity: .55; font-size: 11px; margin-top: 4px; line-height: 1.5; }
  .ub-ai-group[hidden] { display: none !important; }
  .ub-panel-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; }
  .ub-panel-head h3 { margin: 0; font-size: 15px; }
  .ub-panel-close {
    width: 28px; height: 28px; border: none; border-radius: 8px; cursor: pointer;
    background: rgba(128,128,128,.15); color: inherit; font-size: 18px; line-height: 1;
  }
  .ub-panel-close:hover { background: rgba(128,128,128,.28); }
  .ub-quick { display: flex; gap: 8px; }
  .ub-quick .ub-btn { flex: 1; padding: 9px 12px; }
  .ub-btn:disabled { opacity: .4; cursor: not-allowed; }
  .ub-sep { height: 1px; margin: 14px 0; background: rgba(128,128,128,.2); }
  `.trim();
  document.documentElement.appendChild(style);
}

/* ---------------- 主题 ---------------- */

function isDark() {
  if (settings.theme === 'dark') return true;
  if (settings.theme === 'light') return false;
  return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
}

/* ---------------- toast ---------------- */

let toastEl = null;
function toast(message, level) {
  if (!toastEl) {
    toastEl = document.createElement('div');
    toastEl.className = 'ub-toast';
    document.documentElement.appendChild(toastEl);
  }
  toastEl.textContent = message;
  toastEl.setAttribute('data-level', level || 'info');
  toastEl.style.display = 'block';
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { if (toastEl) toastEl.style.display = 'none'; }, 3200);
}

/* ---------------- 悬浮球 ---------------- */

let ballEl = null;
// 小菜单已移除，长按/右键直接打开设置面板

function setStatus(kind, info) {
  if (!ballEl) return;
  if (kind === 'translating') {
    ballEl.textContent = '译…';
    ballEl.setAttribute('data-state', 'translating');
    ballEl.title = '正在翻译，点击可取消';
  } else if (kind === 'progress' && info) {
    ballEl.textContent = Math.min(99, Math.round((info.done / info.total) * 100)) + '%';
    ballEl.setAttribute('data-state', 'translating');
    ballEl.title = '正在翻译，点击可取消';
  } else if (kind === 'done') {
    ballEl.textContent = '原';
    ballEl.setAttribute('data-state', 'done');
    ballEl.title = '已翻译，点击还原原文';
  } else if (kind === 'done-empty') {
    ballEl.textContent = '译';
    ballEl.setAttribute('data-state', 'idle');
    ballEl.title = '无界翻译：点击翻译/还原，长按或右键打开菜单';
  } else {
    ballEl.textContent = '译';
    ballEl.setAttribute('data-state', 'idle');
    ballEl.title = '无界翻译：点击翻译/还原，长按或右键打开菜单';
  }
  pulseBall(kind === 'translating' || kind === 'progress');
}

/**
 * 给悬浮球一个可见的瞬时反馈（缩放 + 光环），
 * 用于「点了但有反馈」——尤其是设置保存、已处于目标状态等无状态变化的情况。
 */
let pulseTimer = null;
function pulseBall(on) {
  if (!ballEl) return;
  clearTimeout(pulseTimer);
  if (!on) { ballEl.classList.remove('ub-ball-pulse'); return; }
  // 重新触发动画：先移除再强制重排
  ballEl.classList.remove('ub-ball-pulse');
  void ballEl.offsetWidth;
  ballEl.classList.add('ub-ball-pulse');
  pulseTimer = setTimeout(() => {
    if (ballEl) ballEl.classList.remove('ub-ball-pulse');
  }, 700);
}

function createBall() {
  if (ballEl) { ballEl.style.display = 'flex'; return; }
  ballEl = document.createElement('div');
  ballEl.className = 'ub-ball';
  ballEl.title = '无界翻译：点击翻译/还原，长按或右键打开菜单';
  ballEl.textContent = '译';

  const saved = getValue('ubt.ballPos', { right: 18, bottom: 110 });
  ballEl.style.right = saved.right + 'px';
  ballEl.style.bottom = saved.bottom + 'px';

  document.documentElement.appendChild(ballEl);
  makeDraggable(ballEl);

  // 左键单击 → 直接翻译 / 还原 / 取消
  ballEl.addEventListener('click', (e) => {
    if (consumeStaleFlag(ballEl)) return;
    e.stopPropagation();
    pulseBall(true);   // 无论后续做什么，先给一个可见反馈
    quickToggle();
  });

  // 右键 → 菜单
  ballEl.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    e.stopPropagation();
    markGesture(ballEl, '_longPressed');
    toggleMenu();
  });

  bindBallLongPress(ballEl);
}

/** 左键点悬浮球：没翻就整页翻译，翻过就还原，翻译中就取消 */
function quickToggle() {
  // 翻译中再点 → 取消（这是用户最自然的预期）
  if (state.running) {
    cancelTranslate();
    return;
  }

  // 保底：如果当前有选中文字，优先翻译选区（手机上很好用，兜住系统事件差异）
  const selected = typeof getSelectedText === 'function' ? getSelectedText() : '';
  if (selected) {
    const pos = getSelectionAnchor();
    createBubble(pos.x, pos.y, pos.top);
    runSelectionTranslation(selected);
    return;
  }

  if (state.translated) {
    restorePage();
    toast('已还原原文');
  } else {
    // 手动点击始终能翻。站点禁用只作用于「自动翻译」，
    // 因为用户主动点悬浮球本身就是明确意图，不该被拦。
    translatePage();
  }
}

/**
 * 手势标记的寿命。
 * 之前直接写成布尔值靠「浏览器补发的 click」来消费，
 * 但触屏上长按 / 右键之后浏览器往往不补发 click，标记就永久挂着，
 * 导致关掉面板后的第一次点击被吞（表现为「点了没反应」）。
 * 现在给标记加一个短时效：超过这个时间就自动失效。
 */
const GESTURE_FLAG_TTL = 800;

function markGesture(el, flag) {
  el[flag] = true;
  clearTimeout(el[flag + '_t']);
  el[flag + '_t'] = setTimeout(() => { el[flag] = false; }, GESTURE_FLAG_TTL);
}

/** 消费一个仍然有效的手势标记；已过期则当作普通点击 */
function consumeStaleFlag(el) {
  let hit = false;
  for (const flag of ['_dragged', '_longPressed']) {
    if (el[flag]) {
      hit = true;
      el[flag] = false;
      clearTimeout(el[flag + '_t']);
    }
  }
  return hit;
}
function bindBallLongPress(el) {
  let timer = null;
  let startX = 0;
  let startY = 0;
  let active = false;
  const LONG_PRESS_MS = 500;
  const MOVE_TOLERANCE = 8;   // 手指轻微抖动不算拖动

  const clear = () => {
    if (timer) { clearTimeout(timer); timer = null; }
    active = false;
  };

  el.addEventListener('pointerdown', (e) => {
    if (e.button !== undefined && e.button !== 0) return;
    clear();
    active = true;
    startX = e.clientX || 0;
    startY = e.clientY || 0;
    el._dragMoved = false;

    timer = setTimeout(() => {
      timer = null;
      if (!active || el._dragMoved) return;
      markGesture(el, '_longPressed');
      toggleMenu();
    }, LONG_PRESS_MS);
  });

  // 只有真正移动超过阈值才取消长按；
  // 之前用 pointerleave 太敏感，鼠标按住轻微抖动或触屏滚动都会误取消
  el.addEventListener('pointermove', (e) => {
    if (!active) return;
    const dx = Math.abs((e.clientX || 0) - startX);
    const dy = Math.abs((e.clientY || 0) - startY);
    if (dx > MOVE_TOLERANCE || dy > MOVE_TOLERANCE) {
      el._dragMoved = true;
      clear();
    }
  });

  el.addEventListener('pointerup', clear);
  el.addEventListener('pointercancel', clear);
}

function makeDraggable(el) {
  let startX = 0, startY = 0, origRight = 0, origBottom = 0, moved = false, pressed = false;
  // 与长按共用同一套拖动手势判定：超过 DRAG_TOLERANCE 才算拖动
  const DRAG_TOLERANCE = 8;

  el.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    pressed = true;
    moved = false;
    el._dragMoved = false;
    startX = e.clientX; startY = e.clientY;
    origRight = parseInt(el.style.right, 10) || 18;
    origBottom = parseInt(el.style.bottom, 10) || 110;
    // 特性检测：部分环境（jsdom / 旧内核）没有指针捕获
    if (typeof el.setPointerCapture === 'function') {
      try { el.setPointerCapture(e.pointerId); } catch (_) { /* 忽略 */ }
    }
  });

  el.addEventListener('pointermove', (e) => {
    if (!pressed) return;
    const dx = startX - e.clientX;
    const dy = startY - e.clientY;
    if (Math.abs(dx) > DRAG_TOLERANCE || Math.abs(dy) > DRAG_TOLERANCE) {
      moved = true;
      el._dragMoved = true;   // 通知长按逻辑取消
    }
    if (!moved) return;
    const right = Math.max(4, Math.min(window.innerWidth - 52, origRight + dx));
    const bottom = Math.max(4, Math.min(window.innerHeight - 52, origBottom + dy));
    el.style.right = right + 'px';
    el.style.bottom = bottom + 'px';
  });

  el.addEventListener('pointerup', (e) => {
    pressed = false;
    if (typeof el.hasPointerCapture === 'function' && typeof el.releasePointerCapture === 'function'
        && el.hasPointerCapture(e.pointerId)) {
      try { el.releasePointerCapture(e.pointerId); } catch (_) { /* 忽略 */ }
    }
    if (moved) {
      markGesture(el, '_dragged');
      setValue('ubt.ballPos', {
        right: parseInt(el.style.right, 10),
        bottom: parseInt(el.style.bottom, 10),
      });
    }
    // 松手后清掉拖动标记，避免影响下一次点击判定
    setTimeout(() => { el._dragMoved = false; }, 0);
  });
}

/** 打开设置面板（长按 / 右键悬浮球都走这里） */
function toggleMenu() {
  // 不再使用小菜单，统一打开完整设置面板
  if (document.querySelector('.ub-panel-mask')) return;
  openPanel();
}

/** 保留空实现，供键盘 Esc 等旧调用点使用 */
function closeMenu() {
  const mask = document.querySelector('.ub-panel-mask');
  if (mask) mask.remove();
}

function displayModeLabel() {
  return {
    bilingual: '原色对照',
    replace: '译文替换',
    'bilingual-accent': '双色对照',
  }[settings.displayMode] || '原色对照';
}

/* ---------------- 划词翻译 ---------------- */


let bubbleEl = null;
let bubbleToken = 0;          // 防止旧请求覆盖新结果
const lastPointer = { x: 0, y: 0 };   // 触屏气泡定位用
let lastSelectionText = '';   // 已处理过的选区文本，避免重复弹气泡
let selectionTimer = null;    // 选区检查的防抖定时器

const MAX_SELECTION_CHARS = 3000;

/** 判断选中的文字是否值得翻译 */
function getSelectedText() {
  const sel = window.getSelection && window.getSelection();
  if (!sel || sel.isCollapsed) return '';
  const text = sel.toString().replace(/\s+/g, ' ').trim();
  if (!text || text.length < 1) return '';
  // 至少要有字母或西里尔文，纯数字标点不翻
  if (!/[A-Za-z\u00c0-\u024f\u0400-\u04ff\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]/.test(text)) return '';
  return text;
}

/** 选区是否位于可编辑区域（输入框、contenteditable）内，是的话不当作划词 */
function isSelectionInEditable() {
  try {
    const sel = window.getSelection && window.getSelection();
    if (!sel || !sel.rangeCount) return false;
    let node = sel.getRangeAt(0).startContainer;
    if (node && node.nodeType === 3) node = node.parentElement;
    if (!node || node.nodeType !== 1) return false;
    return !!(node.closest && node.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])'));
  } catch (_) { return false; }
}

/**
 * 计算选区锚点（视口坐标）。
 * 跨行选区时 getBoundingClientRect 的 left 来自第一行、bottom 来自最后一行，
 * 直接用会定位到两行之间的空白处，所以取「最后一个矩形」的 left/bottom。
 * 返回值里的 top 用于气泡向下放不下时向上翻转。
 */
function getSelectionAnchor() {
  try {
    const sel = window.getSelection();
    if (sel && sel.rangeCount) {
      const range = sel.getRangeAt(0);
      const rects = range.getClientRects ? range.getClientRects() : null;
      let rect = null;
      if (rects && rects.length) rect = rects[rects.length - 1];
      if (!rect || !(rect.width || rect.height)) rect = range.getBoundingClientRect();
      if (rect && (rect.width || rect.height)) {
        return { x: rect.left, y: rect.bottom, top: rect.top };
      }
    }
  } catch (_) { /* 忽略 */ }
  return { x: lastPointer.x, y: lastPointer.y, top: lastPointer.y - 20 };
}

/**
 * 创建译文气泡。
 * 会自动避让屏幕边缘：靠右时向左展开，靠下时向上翻转。
 */
function createBubble(x, y, anchorTop) {
  removeBubble();
  bubbleEl = document.createElement('div');
  bubbleEl.className = 'ub-bubble' + (isDark() ? ' ub-dark' : '');

  const MAX_W = 340;
  const margin = 10;
  const vw = window.innerWidth || 1024;
  const vh = window.innerHeight || 768;

  // 水平：超右就往左挪
  const left = Math.max(margin, Math.min(x, vw - MAX_W - margin));
  // 垂直：默认放在选区下方
  const top = Math.max(margin, Math.min(y + 10, vh - margin));

  bubbleEl.style.maxWidth = Math.min(MAX_W, vw - margin * 2) + 'px';
  bubbleEl.style.left = left + 'px';
  bubbleEl.style.top = top + 'px';   // fixed 定位，坐标即视口坐标

  bubbleEl.innerHTML =
    '<div class="ub-bubble-body">' +
      '<div class="ub-src"></div>' +
      '<div class="ub-dst">翻译中…</div>' +
    '</div>' +
    '<div class="ub-bubble-actions">' +
      '<button class="ub-bubble-btn" data-act="copy" title="复制译文">复制</button>' +
      '<button class="ub-bubble-btn" data-act="retry" title="重试">重试</button>' +
      '<button class="ub-bubble-btn" data-act="close" title="关闭">×</button>' +
    '</div>';

  document.documentElement.appendChild(bubbleEl);

  // 按钮行为
  bubbleEl.querySelector('[data-act="close"]').addEventListener('click', (e) => {
    e.stopPropagation();
    removeBubble();
  });
  bubbleEl.querySelector('[data-act="retry"]').addEventListener('click', (e) => {
    e.stopPropagation();
    const src = bubbleEl && bubbleEl.querySelector('.ub-src').textContent;
    if (src) runSelectionTranslation(src);
  });
  bubbleEl.querySelector('[data-act="copy"]').addEventListener('click', (e) => {
    e.stopPropagation();
    const dst = bubbleEl && bubbleEl.querySelector('.ub-dst').textContent;
    if (!dst) return;
    copyText(dst).then((ok) => toast(ok ? '已复制译文' : '复制失败'));
  });

  // 垂直方向避让：气泡若超出视口底部，翻到选区上方；上方也放不下就贴底
  requestAnimationFrame(() => {
    if (!bubbleEl) return;
    const rect = bubbleEl.getBoundingClientRect();
    if (rect.bottom <= vh - margin) return;
    const baseTop = typeof anchorTop === 'number' ? anchorTop : y;
    const above = baseTop - rect.height - 10;
    bubbleEl.style.top = (above > margin ? above : Math.max(margin, vh - rect.height - margin)) + 'px';
  });
}

function fillBubble(src, dst, error) {
  if (!bubbleEl) return;
  bubbleEl.querySelector('.ub-src').textContent = src;
  const dstEl = bubbleEl.querySelector('.ub-dst');
  dstEl.textContent = error ? '翻译失败：' + error : dst;
  dstEl.style.color = error ? '#e05757' : '';
  const retry = bubbleEl.querySelector('[data-act="retry"]');
  if (retry) retry.style.display = error ? '' : 'none';
  const copy = bubbleEl.querySelector('[data-act="copy"]');
  if (copy) copy.style.display = error ? 'none' : '';
}

function removeBubble() {
  if (bubbleEl && bubbleEl.parentNode) bubbleEl.parentNode.removeChild(bubbleEl);
  bubbleEl = null;
  lastSelectionText = '';   // 气泡关掉后，同一段文字重新选中应能再弹
}

/** 复制文本，兼容不支持 navigator.clipboard 的环境 */
function copyText(text) {
  return new Promise((resolve) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => resolve(true)).catch(() => resolve(fallbackCopy(text)));
        return;
      }
    } catch (_) { /* 走回退 */ }
    resolve(fallbackCopy(text));
  });
}

function fallbackCopy(text) {
  try {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0;';
    document.documentElement.appendChild(ta);
    ta.select();
    const ok = document.execCommand && document.execCommand('copy');
    document.documentElement.removeChild(ta);
    return !!ok;
  } catch (_) { return false; }
}

/** 对一段文字执行翻译并填入气泡 */
async function runSelectionTranslation(text) {
  const token = ++bubbleToken;
  if (bubbleEl) fillBubble(text, '', null);
  try {
    const out = await translateOne(text);
    if (token !== bubbleToken) return;   // 已有更新的请求
    fillBubble(text, out, null);
  } catch (err) {
    if (token !== bubbleToken) return;
    fillBubble(text, '', err && err.message ? err.message : '未知错误');
  }
}

/** 处理当前选区：有选中就翻译 */
async function handleSelection(anchor) {
  const text = getSelectedText();
  if (!text) return;

  // 超长选区：明确告知而不是静默不翻
  if (text.length > MAX_SELECTION_CHARS) {
    toast('选中内容过长（' + text.length + ' 字），请控制在 ' + MAX_SELECTION_CHARS + ' 字以内', 'error');
    return;
  }

  lastSelectionText = text;
  const pos = anchor || getSelectionAnchor();
  createBubble(pos.x, pos.y, pos.top);
  await runSelectionTranslation(text);
}

/** 记录最后一次指针 / 触摸位置 */
function trackPointer() {
  const record = (x, y) => { lastPointer.x = x; lastPointer.y = y + 12; };
  document.addEventListener('mousedown', (e) => record(e.clientX, e.clientY), true);
  document.addEventListener('mouseup', (e) => record(e.clientX, e.clientY), true);
  document.addEventListener('touchstart', (e) => {
    const t = e.touches && e.touches[0];
    if (t) record(t.clientX, t.clientY);
  }, { passive: true, capture: true });
  document.addEventListener('touchend', (e) => {
    const t = e.changedTouches && e.changedTouches[0];
    if (t) record(t.clientX, t.clientY);
  }, { passive: true, capture: true });
}

/**
 * 绑定划词翻译。
 * - 电脑：选中文字后松手（mouseup）触发
 * - 手机：长按选中文字后（touchend）延迟触发，因为系统选区要稍后才就绪
 */
function bindSelectionTranslate() {
  trackPointer();

  const isFromBubble = (e) => !!(bubbleEl && e && e.target && bubbleEl.contains(e.target));
  const isFromInteractionEl = (e) => {
    const el = e && e.target;
    if (!el || el.nodeType !== 1) return false;
    return !!(el.closest && el.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"])'));
  };

  /** 选区检查（防抖后执行）：同一段文字且气泡还在，就不重复弹 */
  const runSelectionCheck = () => {
    if (!settings.selectionTranslate) return;
    // 输入框 / 可编辑区里选文字不算划词
    if (isSelectionInEditable()) return;
    const text = getSelectedText();
    if (!text) return;
    if (text === lastSelectionText && bubbleEl) return;
    handleSelection().catch(() => undefined);
  };

  const scheduleSelectionCheck = (delay) => {
    clearTimeout(selectionTimer);
    selectionTimer = setTimeout(runSelectionCheck, delay);
  };

  /* -------- 1. 电脑：鼠标松手 -------- */
  // 用 capture 阶段，避开页面自己的 stopPropagation 拦截
  document.addEventListener('mouseup', (e) => {
    if (isTouchPrimary()) return;          // 触屏设备交给下面的逻辑
    if (!settings.selectionTranslate) return;
    if (isFromBubble(e) || isFromInteractionEl(e)) return;
    // 松手后选区可能还没稳定（双击选词、拖选），延一帧再读
    scheduleSelectionCheck(10);
  }, true);

  /* -------- 2. 全平台通用：监听选区变化 --------
   * 这是手机上最可靠的信号。长按选词时 touchend 未必派发，
   * 但选区一旦建立，selectionchange 一定会触发。 */
  document.addEventListener('selectionchange', () => {
    if (!settings.selectionTranslate) return;

    if (bubbleEl) {
      const text = getSelectedText();
      // 选区被清空（用户点了别处）就收起
      if (!text) {
        setTimeout(() => { if (!getSelectedText()) removeBubble(); }, 350);
        return;
      }
      // 改选了另一段文字：允许直接重新翻译，不必先关气泡再选
      if (text !== lastSelectionText) {
        scheduleSelectionCheck(isTouchPrimary() ? 400 : 120);
      }
      return;
    }

    // 选区建立：移动端要等系统菜单稳定，延迟稍长
    scheduleSelectionCheck(isTouchPrimary() ? 400 : 120);
  });

  /* -------- 3. 触屏：长按松手后补一次检查 --------
   * 有些浏览器 selectionchange 触发很早，此时选区还没最终确定，
   * 所以在 touchend 之后再做一次补充检查。 */
  let touchStartXY = null;

  document.addEventListener('touchstart', (e) => {
    const t = e.touches && e.touches[0];
    if (t) touchStartXY = { x: t.clientX, y: t.clientY, time: Date.now() };
    // 点在气泡以外的区域时关掉气泡（点在气泡上不关）
    if (bubbleEl && !isFromBubble(e)) removeBubble();
  }, { passive: true, capture: true });

  document.addEventListener('touchend', (e) => {
    if (!settings.selectionTranslate) return;
    if (isFromBubble(e)) return;
    if (isFromInteractionEl(e)) return;

    // 长按选词：按住超过 250ms 且几乎没移动
    const t = e.changedTouches && e.changedTouches[0];
    if (touchStartXY && t) {
      const held = Date.now() - touchStartXY.time;
      const moved = Math.abs(t.clientX - touchStartXY.x) + Math.abs(t.clientY - touchStartXY.y);
      // 不是长按也照样检查一次：普通点选/双击也可能选中了文字
      scheduleSelectionCheck(held > 250 && moved < 20 ? 400 : 450);
      return;
    }
    scheduleSelectionCheck(400);
  }, { passive: true });

  /* -------- 4. 关闭时机 -------- */
  // 电脑：点击空白处关闭
  document.addEventListener('mousedown', (e) => {
    if (bubbleEl && !isFromBubble(e)) removeBubble();
  }, true);

  // 滚动时：气泡用 fixed 定位，不会跟着选区走。
  // 滚动后重新贴到当前选区；选区没了或已滚出视口就收起。
  // （之前只要发生滚动就无条件移除，气泡刚弹出就被清掉，看起来像「选中后不翻译」）
  let scrollTimer = null;
  const onScroll = () => {
    if (!bubbleEl) return;
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(() => {
      if (!bubbleEl) return;
      if (!getSelectedText()) { removeBubble(); return; }
      const pos = getSelectionAnchor();
      const vh = window.innerHeight || 768;
      const vw = window.innerWidth || 1024;
      if (pos.y < 0 || pos.y > vh) { removeBubble(); return; }
      const width = bubbleEl.offsetWidth || 0;
      bubbleEl.style.left = Math.max(10, Math.min(pos.x, vw - width - 10)) + 'px';
      bubbleEl.style.top = Math.max(10, Math.min(pos.y + 10, vh - 10)) + 'px';
    }, 150);
  };
  document.addEventListener('scroll', onScroll, { passive: true, capture: true });

}

/* ---------------- 设置面板 ---------------- */

function openPanel() {
  removeBubble();
  const mask = document.createElement('div');
  mask.className = 'ub-panel-mask';
  const panel = document.createElement('div');
  panel.className = 'ub-panel' + (isDark() ? ' ub-dark' : '');
  mask.appendChild(panel);

  const langs = [
    ['auto', '自动检测'], ['zh-CN', '简体中文'], ['zh-TW', '繁體中文'],
    ['en', '英语'], ['ja', '日语'], ['ko', '韩语'], ['fr', '法语'],
    ['de', '德语'], ['es', '西班牙语'], ['ru', '俄语'], ['pt', '葡萄牙语'], ['it', '意大利语'],
  ];

  panel.innerHTML = `
    <div class="ub-panel-head">
      <h3>无界翻译</h3>
      <button class="ub-panel-close" data-act="x" aria-label="关闭">×</button>
    </div>
    <div class="ub-row">
      <label>快捷操作</label>
      <div class="ub-quick">
        <button class="ub-btn" data-act="translate">${state.translated ? '重新翻译' : '翻译此页'}</button>
        <button class="ub-btn" data-act="restore" ${state.translated ? '' : 'disabled'}>恢复原文</button>
      </div>
    </div>
    <div class="ub-sep"></div>
    <div class="ub-row">
      <label>翻译服务</label>
      <select data-k="provider">
        ${Object.entries(PROVIDERS).map(([k, v]) => `<option value="${k}">${v.label}</option>`).join('')}
      </select>
    </div>
    <div class="ub-row">
      <label>源语言</label>
      <select data-k="sourceLang">
        ${langs.map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}
      </select>
    </div>
    <div class="ub-row">
      <label>目标语言</label>
      <select data-k="targetLang">
        ${langs.filter(([v]) => v !== 'auto').map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}
      </select>
    </div>
    <div class="ub-row">
      <label>显示模式</label>
      <select data-k="displayMode">
        <option value="bilingual">原色对照（原文 + 译文）</option>
        <option value="bilingual-accent">双色对照（译文高亮）</option>
        <option value="replace">译文替换</option>
      </select>
    </div>
    <div class="ub-row ub-check">
      <input type="checkbox" data-k="selectionTranslate" id="ub-sel">
      <label for="ub-sel" style="margin:0">划词翻译</label>
    </div>
    <div class="ub-row ub-check">
      <input type="checkbox" data-k="paragraphMode" id="ub-para">
      <label for="ub-para" style="margin:0">段落模式（点一下段落翻译，再点还原）</label>
    </div>
    <div class="ub-hint" style="margin:-6px 0 12px 24px">开启后点正文文字即可翻译该段；链接、按钮、输入框不受影响</div>
    <div class="ub-row ub-check">
      <input type="checkbox" data-k="translateAttributes" id="ub-attr">
      <label for="ub-attr" style="margin:0">翻译图片 alt / 悬停提示文字</label>
    </div>
    <div class="ub-hint" style="margin:-6px 0 12px 24px">图片里画出来的文字需要 OCR，本脚本不支持；此项只翻 alt、title 这类属性文本</div>
    <div class="ub-row ub-check">
      <input type="checkbox" data-k="floatingBall" id="ub-ball">
      <label for="ub-ball" style="margin:0">显示悬浮球</label>
    </div>
    <div class="ub-row ub-check">
      <input type="checkbox" data-k="autoTranslate" id="ub-auto">
      <label for="ub-auto" style="margin:0">打开页面自动翻译</label>
    </div>
    <div class="ub-row">
      <label>当前网站（只影响自动翻译）</label>
      <div class="ub-quick">
        <button class="ub-btn" data-act="toggle-site"></button>
      </div>
      <div class="ub-hint" data-site-hint></div>
    </div>
    <div class="ub-row">
      <label>不翻译的区域（CSS 选择器，每行一个）</label>
      <textarea data-k="excludeSelectors" placeholder=".no-translate&#10;nav.sidebar"></textarea>
    </div>
    <div class="ub-row">
      <label>关闭自动翻译的网站（每行一个域名）</label>
      <textarea data-k="disabledSites" placeholder="example.com&#10;news.ycombinator.com"></textarea>
      <div class="ub-hint">这些网站不自动翻译，但仍可手动点击悬浮球翻译；子域名也生效</div>
    </div>
    <div class="ub-ai-group" data-ai-group hidden>
      <div class="ub-row">
        <label>OpenAI 兼容接口地址</label>
        <input type="text" data-k2="baseURL" placeholder="https://api.deepseek.com/v1">
        <div class="ub-hint">可填 DeepSeek、智谱、Ollama(http://localhost:11434/v1) 或中转站</div>
      </div>
      <div class="ub-row">
        <label>API Key</label>
        <input type="password" data-k2="apiKey" placeholder="sk-...">
      </div>
      <div class="ub-row">
        <label>模型名</label>
        <input type="text" data-k2="model" placeholder="deepseek-chat">
      </div>
    </div>
    <div class="ub-actions">
      <button class="ub-btn" data-act="close">关闭</button>
      <button class="ub-btn ub-primary" data-act="save">保存</button>
    </div>
  `;

  // 回填
  panel.querySelectorAll('[data-k]').forEach((el) => {
    const k = el.getAttribute('data-k');
    if (el.type === 'checkbox') el.checked = !!settings[k];
    else if (k === 'excludeSelectors') el.value = (settings.excludeSelectors || []).join('\n');
    else if (k === 'disabledSites') el.value = (settings.disabledSites || []).join('\n');
    else el.value = settings[k];
  });
  panel.querySelectorAll('[data-k2]').forEach((el) => {
    el.value = (settings.services.openai && settings.services.openai[el.getAttribute('data-k2')]) || '';
  });

  // 只有选中 OpenAI 兼容服务时才显示接口地址 / Key / 模型
  const aiGroup = panel.querySelector('[data-ai-group]');
  const providerSelect = panel.querySelector('[data-k="provider"]');
  const syncAiGroup = () => {
    if (!aiGroup || !providerSelect) return;
    aiGroup.hidden = providerSelect.value !== 'openai';
  };
  syncAiGroup();
  if (providerSelect) providerSelect.addEventListener('change', syncAiGroup);

  panel.querySelector('[data-act="close"]').addEventListener('click', () => mask.remove());
  panel.querySelector('[data-act="x"]').addEventListener('click', () => mask.remove());
  mask.addEventListener('click', (e) => { if (e.target === mask) mask.remove(); });

  /* -------- 不翻译当前网站 -------- */
  const siteBtn = panel.querySelector('[data-act="toggle-site"]');
  const siteHint = panel.querySelector('[data-site-hint]');
  const sitesArea = panel.querySelector('[data-k="disabledSites"]');
  const host = currentHost();

  /** 把文本框里的内容解析成归一化后的域名数组 */
  const readSites = () => {
    if (!sitesArea) return [];
    const seen = new Set();
    return sitesArea.value.split('\n')
      .map(normalizeSite)
      .filter((s) => s && !seen.has(s) && (seen.add(s), true));
  };

  /** 把域名数组写回文本框 */
  const writeSites = (arr) => { if (sitesArea) sitesArea.value = arr.join('\n'); };

  const syncSiteBtn = () => {
    if (!siteBtn) return;
    const sites = readSites();
    const on = !!host && sites.some((s) => hostMatches(host, s));
    siteBtn.textContent = on ? '已关闭自动翻译（点击恢复）' : '关闭本站自动翻译';
    siteBtn.classList.toggle('ub-primary', on);
    siteBtn.disabled = !host;
    if (siteHint) {
      siteHint.textContent = host
        ? (on ? `当前网站 ${host} 不会自动翻译，手动点击仍可翻` : `当前网站：${host}`)
        : '当前环境拿不到域名（本地文件等）';
    }
  };

  if (siteBtn) {
    siteBtn.addEventListener('click', () => {
      if (!host) return;
      const sites = readSites();
      const idx = sites.findIndex((s) => hostMatches(host, s));
      if (idx >= 0) {
        sites.splice(idx, 1);
        writeSites(sites);
        toast('已恢复翻译 ' + host);
      } else {
        // 用归一化后的当前域名，避免把 www. 或端口写进去
        sites.push(normalizeSite(host));
        writeSites(sites);
        toast('已设为不翻译 ' + host);
      }
      syncSiteBtn();
    });
  }

  // 用户手改文本框时，按钮文案跟着变
  if (sitesArea) sitesArea.addEventListener('input', syncSiteBtn);
  syncSiteBtn();

  // 快捷操作
  const quickTranslate = panel.querySelector('[data-act="translate"]');
  const quickRestore = panel.querySelector('[data-act="restore"]');
  if (quickTranslate) {
    quickTranslate.addEventListener('click', () => {
      mask.remove();
      // 翻译中再点 → 取消，与悬浮球行为一致
      if (state.running) { cancelTranslate(); return; }
      if (state.translated) { restorePage(); translatePage(); } else translatePage();
    });
  }
  if (quickRestore) {
    quickRestore.addEventListener('click', () => {
      mask.remove();
      restorePage();
      toast('已还原原文');
    });
  }

  // Esc 关闭
  const onKey = (e) => {
    if (e.key === 'Escape') { mask.remove(); document.removeEventListener('keydown', onKey, true); }
  };
  document.addEventListener('keydown', onKey, true);

  panel.querySelector('[data-act="save"]').addEventListener('click', (e) => {
    const btn = e.currentTarget;
    panel.querySelectorAll('[data-k]').forEach((el) => {
      const k = el.getAttribute('data-k');
      if (el.type === 'checkbox') settings[k] = el.checked;
      else if (k === 'excludeSelectors') {
        settings[k] = el.value.split('\n').map((s) => s.trim()).filter(Boolean);
      } else if (k === 'disabledSites') {
        // 归一化 + 去重，避免用户手写 https:// 或重复行
        const seen = new Set();
        settings[k] = el.value.split('\n')
          .map(normalizeSite)
          .filter((s) => s && !seen.has(s) && (seen.add(s), true));
      } else settings[k] = el.value;
    });
    panel.querySelectorAll('[data-k2]').forEach((el) => {
      settings.services.openai[el.getAttribute('data-k2')] = el.value.trim();
    });
    saveSettings();

    // 保存反馈：按钮文案先变「已保存 ✓」，再关面板，避免用户怀疑没生效
    if (btn) {
      btn.textContent = '已保存 ✓';
      btn.disabled = true;
    }
    applySettings();
    pulseBall(true);   // 悬浮球同步给一个可见的动效

    // 站点禁用只影响「以后是否自动翻译」，不动当前页面内容：
    // 用户手动翻出来的译文不应该因为保存设置就被抹掉。
    if (isSiteDisabled()) {
      toast('设置已保存：' + currentHost() + ' 不再自动翻译（仍可手动点击翻译）');
    } else {
      toast('设置已保存');
    }

    setTimeout(() => {
      mask.remove();
      // 关掉面板后，若悬浮球在页面上，让用户看到它已就绪
      if (ballEl) {
        ballEl.textContent = state.translated ? '原' : '译';
        ballEl.setAttribute('data-state', state.translated ? 'done' : 'idle');
      }
    }, 260);
  });

  document.documentElement.appendChild(mask);
}

function applySettings() {
  document.documentElement.style.setProperty('--ub-accent', settings.accent || '#4f8cff');
  if (settings.floatingBall) createBall();
  else if (ballEl) { ballEl.style.display = 'none'; }
}

/* ---------------- 快捷键 ---------------- */

function bindShortcuts() {
  // 快捷键挂到 document 上，比 window 兼容性更好
  document.addEventListener('keydown', (e) => {
    // Alt+Shift+Y 翻译全文 / 取消 / 还原
    if (e.altKey && e.shiftKey && (e.key === 'Y' || e.key === 'y')) {
      e.preventDefault();
      if (state.running) cancelTranslate();
      else if (state.translated) restorePage();
      else translatePage();
    }
    if (e.key === 'Escape') { removeBubble(); closeMenu(); }
  }, true);
}

/* ---------------- 初始化 ---------------- */

function shouldAutoTranslate() {
  if (!settings.autoTranslate) return false;
  const host = location.hostname;
  const sites = settings.autoTranslateSites || [];
  if (!sites.length) return true;
  return sites.some((s) => host === s || host.endsWith('.' + s));
}

function init() {
  settings = loadSettings();

  // 各步骤独立保护：任何一步失败都不该让整个脚本罢工
  const step = (name, fn) => {
    try { fn(); } catch (err) { console.error('[无界翻译] 初始化步骤失败：' + name, err); }
  };

  step('样式', injectStyles);
  step('应用设置', applySettings);
  step('快捷键', bindShortcuts);
  step('划词翻译', bindSelectionTranslate);
  step('段落模式', bindParagraphMode);
  step('段落提示', updateParaHint);

  // 页面语言已是目标语言就不自动翻
  if (shouldAutoTranslate() && !isSiteDisabled()) {
    const htmlLang = (document.documentElement.lang || '').toLowerCase();
    if (!(settings.targetLang.startsWith('zh') && htmlLang.startsWith('zh'))) {
      setTimeout(() => { translatePage().catch(() => undefined); }, 600);
    }
  }
}

/** 段落模式开启时，让可点击的文字有轻微的手型提示 */
function updateParaHint() {
  let styleEl = document.getElementById('ub-para-hint');
  if (settings.paragraphMode) {
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.id = 'ub-para-hint';
      styleEl.textContent = 'body.ub-para-mode p, body.ub-para-mode li, body.ub-para-mode blockquote { cursor: pointer; }';
      document.documentElement.appendChild(styleEl);
    }
    if (document.body) document.body.classList.add('ub-para-mode');
  } else {
    if (styleEl && styleEl.parentNode) styleEl.parentNode.removeChild(styleEl);
    if (document.body) document.body.classList.remove('ub-para-mode');
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init, { once: true });
} else {
  init();
}

})();

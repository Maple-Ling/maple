// ==UserScript==
// @name         无界油猴录制·回放助手 (Recorder & Replayer)
// @namespace    https://pi.local/userscript
// @version      1.0.0
// @description  长按浮动按钮打开菜单：录制页面点击/输入/滚动，按录制时的真实间隔回放，支持定时循环执行。适配手机与电脑 UI。
// @author       pi
// @match        *://*/*
// @grant        none
// @run-at       document-idle
// @noframes
// ==/UserScript==

(function () {
  'use strict';

  // 防止重复注入
  if (window.__TM_REC_PLUGIN__) return;
  window.__TM_REC_PLUGIN__ = true;

  /* ============================================================
   * 常量 & 状态
   * ============================================================ */
  const HOST_ID = 'tm-rec-host';
  const KEY_STEPS = 'tmrec:steps:' + location.hostname; // 按域名隔离
  const KEY_CFG = 'tmrec:cfg';
  const KEY_POS = 'tmrec:pos';
  const KEY_RUN = 'tmrec:run:' + location.hostname;    // 执行进度（用于刷新后续跑）

  const RUN_TTL = 10 * 60 * 1000; // 进度超过 10 分钟视为过期
  const MAX_RESUME = 25;          // 同一轮最多续跑次数，防止「刷新→执行→刷新」死循环

  const DEFAULTS = {
    loopGap: 3,          // 轮间隔（秒）：一轮录制序列跑完后等多久进入下一轮
    rounds: 0,           // 执行次数，0 = 无限
    stepGap: 0,          // 步骤间隔（**秒**，可小数），0 = 使用录制时的真实间隔
    resumeMode: 'continue' // 刷新后：continue=断点续跑 / restart=从头重跑 / off=不自动执行
  };

  const S = {
    steps: [],
    recording: false,
    playing: false,
    stop: false,
    round: 0,
    resumeCount: 0,
    resumePending: false,
    waitUntil: 0,
    lastTs: 0,
    pendingInput: new Map(),
    scrollTimer: null
  };

  const C = Object.assign({}, DEFAULTS, load(KEY_CFG, {}));

  // 配置健壮性校验：localStorage 里的脏数据（null / 字符串 / 负数）会让间隔直接失效
  ['loopGap', 'rounds', 'stepGap'].forEach(function (k) {
    const v = Number(C[k]);
    C[k] = (isNaN(v) || v < 0) ? DEFAULTS[k] : v;
  });
  if (['continue', 'restart', 'off'].indexOf(C.resumeMode) === -1) C.resumeMode = 'continue';
  S.steps = load(KEY_STEPS, []);

  /* ============================================================
   * 存储工具
   * ============================================================ */
  function load(key, dflt) {
    try {
      const raw = localStorage.getItem(key);
      return raw == null ? dflt : JSON.parse(raw);
    } catch (e) { return dflt; }
  }
  function save(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch (e) {}
  }

  let stepsSaveTimer = null;
  function saveSteps() {
    clearTimeout(stepsSaveTimer);
    stepsSaveTimer = setTimeout(() => save(KEY_STEPS, S.steps), 250);
  }

  /* ============================================================
   * DOM 定位工具
   * ============================================================ */
  function esc(s) {
    if (window.CSS && CSS.escape) return CSS.escape(s);
    return String(s).replace(/([^\w-])/g, '\\$1');
  }

  /** 生成尽量稳定的 CSS 选择器 */
  function cssPath(el) {
    if (!el || el.nodeType !== 1) return '';
    const parts = [];
    let cur = el;
    let depth = 0;
    while (cur && cur.nodeType === 1 && depth < 12) {
      const tag = cur.tagName.toLowerCase();
      if (cur === document.documentElement) { parts.unshift('html'); break; }
      if (cur === document.body) { parts.unshift('body'); break; }

      const id = cur.getAttribute('id');
      if (id && /^[A-Za-z][\w:.-]*$/.test(id)) {
        let unique = false;
        try { unique = document.querySelectorAll('#' + esc(id)).length === 1; } catch (e) {}
        if (unique) { parts.unshift('#' + esc(id)); break; }
      }

      let sel = tag;
      const cls = (cur.getAttribute('class') || '').trim().split(/\s+/)
        .filter(c => /^[A-Za-z_-][\w-]*$/.test(c)).slice(0, 2);
      if (cls.length) sel += '.' + cls.map(esc).join('.');

      const parent = cur.parentElement;
      if (parent) {
        const sibs = Array.prototype.filter.call(parent.children, c => c.tagName === cur.tagName);
        if (sibs.length > 1) sel += ':nth-of-type(' + (sibs.indexOf(cur) + 1) + ')';
      }
      parts.unshift(sel);
      cur = cur.parentElement;
      depth++;
    }
    return parts.join(' > ');
  }

  /** 生成 XPath 兜底 */
  function xpathOf(el) {
    if (!el || el.nodeType !== 1) return '';
    const segs = [];
    let cur = el;
    while (cur && cur.nodeType === 1) {
      let i = 1;
      let sib = cur.previousElementSibling;
      while (sib) { if (sib.tagName === cur.tagName) i++; sib = sib.previousElementSibling; }
      segs.unshift(cur.tagName.toLowerCase() + '[' + i + ']');
      cur = cur.parentElement;
    }
    return '/' + segs.join('/');
  }

  /** 四级兜底查找元素 */
  function findEl(step) {
    if (step.sel) {
      try { const el = document.querySelector(step.sel); if (el) return el; } catch (e) {}
    }
    if (step.xp) {
      try {
        const r = document.evaluate(step.xp, document, null,
          XPathResult.FIRST_ORDERED_NODE_TYPE, null);
        if (r.singleNodeValue) return r.singleNodeValue;
      } catch (e) {}
    }
    if (step.text) {
      try {
        const list = document.querySelectorAll(step.tag || '*');
        let found = null;
        for (let i = 0; i < list.length; i++) {
          const el = list[i];
          const tx = ((el.innerText || el.value || '') + '').trim().slice(0, 40);
          if (tx && tx === step.text) found = el; // 取最深的那个
        }
        if (found) return found;
      } catch (e) {}
    }
    return null;
  }

  /* ============================================================
   * 事件派发（回放用）
   * ============================================================ */
  function fireClick(el, cx, cy) {
    if (!el) return;
    const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : { left: 0, top: 0, width: 0, height: 0 };
    const x = (cx != null && cx > 0) ? cx : rect.left + rect.width / 2;
    const y = (cy != null && cy > 0) ? cy : rect.top + rect.height / 2;

    const base = {
      bubbles: true, cancelable: true, composed: true, view: window,
      clientX: x, clientY: y, screenX: x, screenY: y, button: 0, buttons: 1
    };
    const ptr = { pointerId: 1, pointerType: 'mouse', isPrimary: true, width: 1, height: 1 };

    try { el.dispatchEvent(new PointerEvent('pointerdown', Object.assign({}, base, ptr))); } catch (e) {}
    el.dispatchEvent(new MouseEvent('mousedown', base));
    try { el.dispatchEvent(new PointerEvent('pointerup', Object.assign({}, base, ptr, { buttons: 0 }))); } catch (e) {}
    el.dispatchEvent(new MouseEvent('mouseup', Object.assign({}, base, { buttons: 0 })));
    el.dispatchEvent(new MouseEvent('click', Object.assign({}, base, { buttons: 0 })));
  }

  /** 兼容 React / Vue 受控组件地写入值 */
  function setNativeValue(el, val) {
    const proto = Object.getPrototypeOf(el);
    const desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) desc.set.call(el, val);
    else el.value = val;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function sleep(ms) {
    return new Promise(resolve => {
      const t0 = Date.now();
      (function tick() {
        if (S.stop || Date.now() - t0 >= ms) return resolve();
        setTimeout(tick, Math.min(100, ms - (Date.now() - t0)));
      })();
    });
  }

  /* ============================================================
   * UI：Shadow DOM
   * ============================================================ */
  const host = document.createElement('div');
  host.id = HOST_ID;
  host.style.cssText =
    'all:initial;position:fixed;inset:0;width:100%;height:100%;' +
    'z-index:2147483647;pointer-events:none;display:block;';

  const shadow = host.attachShadow({ mode: 'open' });

  shadow.innerHTML = `
<style>
  *{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;}
  .fab{
    position:absolute;z-index:2;display:flex;align-items:center;justify-content:center;gap:7px;
    min-width:58px;height:58px;padding:0 16px;border-radius:29px;
    background:rgba(28,30,36,.94);color:#fff;border:2px solid rgba(255,255,255,.16);
    box-shadow:0 4px 18px rgba(0,0,0,.4);
    font-size:20px;line-height:1;
    user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;
    touch-action:none;cursor:pointer;pointer-events:auto;
    transition:background .18s,transform .1s;
  }
  .fab .ico{font-size:20px;line-height:1;display:block;}
  .fab .meta{
    display:none;font-size:12.5px;font-weight:700;letter-spacing:.2px;
    white-space:nowrap;font-variant-numeric:tabular-nums;
  }
  .fab.wide .meta{display:block;}
  .fab.wide{min-width:0;}
  .fab:active{transform:scale(.93);}
  .fab.rec{background:#e5484d;animation:pulse 1.3s infinite;}
  .fab.play{background:#2f9e44;}
  @keyframes pulse{
    0%,100%{box-shadow:0 0 0 0 rgba(229,72,77,.65);}
    50%{box-shadow:0 0 0 12px rgba(229,72,77,0);}
  }
  .panel{
    position:absolute;z-index:1;right:16px;bottom:84px;width:322px;max-width:calc(100vw - 32px);
    background:#16181d;color:#e6e8ec;border-radius:14px;
    border:1px solid rgba(255,255,255,.1);
    box-shadow:0 12px 44px rgba(0,0,0,.55);
    pointer-events:auto;overflow:hidden;font-size:14px;line-height:1.5;
    display:none;
  }
  .panel.open{display:block;}
  .hd{
    display:flex;align-items:center;justify-content:space-between;
    padding:12px 14px;border-bottom:1px solid rgba(255,255,255,.08);
  }
  .ttl{font-size:15px;font-weight:600;letter-spacing:.3px;}
  .x{
    background:transparent;border:0;color:#9aa0aa;font-size:16px;cursor:pointer;
    width:28px;height:28px;border-radius:8px;line-height:1;
  }
  .x:hover{background:rgba(255,255,255,.08);color:#fff;}
  .body{padding:12px 14px 14px;max-height:min(70vh,520px);overflow-y:auto;-webkit-overflow-scrolling:touch;}
  .stat{
    display:flex;align-items:center;justify-content:space-between;
    background:rgba(255,255,255,.05);border-radius:9px 9px 0 0;padding:9px 11px 4px;
    font-size:13px;
  }
  .stat2{
    display:flex;align-items:center;justify-content:space-between;
    background:rgba(255,255,255,.05);border-radius:0 0 9px 9px;
    padding:0 11px 9px;margin-bottom:11px;font-size:12px;color:#8b93a1;
  }
  .stat2 b{color:#e6e8ec;font-weight:700;font-variant-numeric:tabular-nums;}
  .stat2 .wait{color:#51cf66;font-weight:700;font-variant-numeric:tabular-nums;}
  .cfgsum{
    margin-top:10px;padding:8px 10px;border-radius:8px;
    background:rgba(77,159,255,.1);border:1px solid rgba(77,159,255,.25);
    font-size:11.5px;color:#9ecbff;line-height:1.5;
  }
  .dot{color:#8b93a1;font-size:12px;font-weight:600;}
  .dot.red{color:#ff6b6f;}
  .dot.green{color:#51cf66;}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px;}
  .btn{
    appearance:none;border:1px solid rgba(255,255,255,.12);background:rgba(255,255,255,.07);
    color:#e6e8ec;border-radius:9px;padding:10px 6px;font-size:13px;font-weight:600;
    cursor:pointer;touch-action:manipulation;transition:background .15s,opacity .15s;
    white-space:nowrap;
  }
  .btn:hover:not(:disabled){background:rgba(255,255,255,.14);}
  .btn:active:not(:disabled){transform:scale(.97);}
  .btn:disabled{opacity:.32;cursor:not-allowed;}
  .btn.rec{background:rgba(229,72,77,.9);border-color:transparent;color:#fff;}
  .btn.rec:hover:not(:disabled){background:#e5484d;}
  .btn.ok{background:rgba(47,158,68,.9);border-color:transparent;color:#fff;}
  .btn.ok:hover:not(:disabled){background:#2f9e44;}
  .btn.warn{background:rgba(245,165,36,.9);border-color:transparent;color:#14161a;}
  .btn.warn:hover:not(:disabled){background:#f5a524;}
  .btn.ghost{background:transparent;font-weight:500;font-size:12.5px;padding:8px 6px;}
  .btn.save{background:#1c7ed6;border-color:transparent;color:#fff;font-weight:700;}
  .btn.save:hover:not(:disabled){background:#1971c2;}
  .btn.save.dirty{background:#f5a524;color:#14161a;animation:pulse2 1.4s infinite;}
  @keyframes pulse2{
    0%,100%{box-shadow:0 0 0 0 rgba(245,165,36,.55);}
    50%{box-shadow:0 0 0 8px rgba(245,165,36,0);}
  }
  .rows{display:flex;flex-direction:column;gap:9px;margin-bottom:12px;}
  .row{display:flex;align-items:center;gap:8px;font-size:13px;color:#b9c0cc;}
  .row>span{flex:0 0 62px;}
  .row input{
    flex:0 0 68px;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.13);
    color:#fff;border-radius:7px;padding:7px 8px;font-size:13px;outline:none;
    -moz-appearance:textfield;
  }
  .row select{
    flex:1 1 auto;min-width:0;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.13);
    color:#fff;border-radius:7px;padding:7px 8px;font-size:13px;outline:none;
  }
  .row select option{background:#1e2028;color:#fff;}
  .row input:focus,.row select:focus{border-color:#4d9fff;}
  .row em{font-style:normal;font-size:12px;color:#7d8593;}
  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
  .tip{margin-top:11px;font-size:11.5px;color:#6f7787;line-height:1.6;}
  .tip b{color:#98a1b0;font-weight:600;}
  .toast{
    position:absolute;left:50%;bottom:110px;transform:translateX(-50%) translateY(8px);
    background:rgba(20,22,28,.96);color:#fff;padding:9px 16px;border-radius:10px;
    font-size:13px;opacity:0;transition:opacity .2s,transform .2s;
    pointer-events:none;white-space:nowrap;max-width:90vw;
  }
  .toast.show{opacity:1;transform:translateX(-50%) translateY(0);}
  @media (max-width:640px){
    .panel{left:0;right:0;bottom:0;width:auto;max-width:none;border-radius:16px 16px 0 0;border-bottom:0;}
    .body{max-height:78vh;padding-bottom:calc(16px + env(safe-area-inset-bottom));}
    .btn{padding:12px 6px;font-size:13.5px;}
    .row input{padding:9px 8px;}
    .toast{bottom:auto;top:16%;}
  }
</style>

<button class="fab" id="fab" aria-label="录制回放助手">
  <span class="ico" id="fabIco">☰</span>
  <span class="meta" id="fabMeta"></span>
</button>

<div class="panel" id="panel">
  <div class="hd">
    <span class="ttl">录制 · 回放</span>
    <button class="x" id="close" aria-label="关闭">✕</button>
  </div>
  <div class="body">
    <div class="stat">
      <span id="statSteps">未录制</span>
      <span class="dot" id="statLive">待命</span>
    </div>
    <div class="stat2">
      <span>时长 <b id="statTime">00:00</b></span>
      <span id="statWait" class="wait"></span>
      <span>已完成 <b id="statDone">0</b> 轮</span>
    </div>

    <div class="grid">
      <button class="btn rec"  id="btnRecStart">● 开始录制</button>
      <button class="btn"      id="btnRecStop">■ 结束录制</button>
      <button class="btn ok"   id="btnPlayStart">▶ 开始执行</button>
      <button class="btn warn" id="btnPlayStop">■ 停止执行</button>
    </div>

    <div class="rows">
      <label class="row"><span>轮间隔</span><input id="cfgGap" type="number" min="0" step="1"><em>秒</em></label>
      <label class="row"><span>执行次数</span><input id="cfgRounds" type="number" min="0" step="1"><em>次（0=无限）</em></label>
      <label class="row"><span>步骤间隔</span><input id="cfgStep" type="number" min="0" step="0.5"><em>秒（0=原速）</em></label>
      <label class="row"><span>刷新后</span>
        <select id="cfgResume">
          <option value="continue">断点续跑（推荐）</option>
          <option value="restart">从头重跑</option>
          <option value="off">不自动执行</option>
        </select>
      </label>
    </div>

    <div class="grid2" style="margin-bottom:8px;">
      <button class="btn save" id="btnSaveCfg">保存设置</button>
      <button class="btn ghost" id="btnResetCfg">恢复默认</button>
    </div>

    <div class="grid2">
      <button class="btn ghost" id="btnClear">清空录制</button>
      <button class="btn ghost" id="btnResetPos">重置按钮位置</button>
    </div>

    <div class="cfgsum" id="cfgSum"></div>

    <p class="tip">
      <b>步骤间隔</b>：每个动作之间等多久<br>
      <b>轮间隔</b>：一整轮跑完后，等多久再跑下一轮<br>
      短按圆钮：开始 / 停止执行　·　长按圆钮：打开本菜单　·　拖动圆钮：换位置
    </p>
  </div>
</div>
`;

  document.documentElement.appendChild(host);

  const q = (id) => shadow.querySelector('#' + id);
  const fab = q('fab');
  const fabIco = q('fabIco');
  const fabMeta = q('fabMeta');
  const panel = q('panel');
  const statSteps = q('statSteps');
  const statLive = q('statLive');
  const statTime = q('statTime');
  const statDone = q('statDone');
  const statWait = q('statWait');
  const cfgSum = q('cfgSum');
  const btnRecStart = q('btnRecStart');
  const btnRecStop = q('btnRecStop');
  const btnPlayStart = q('btnPlayStart');
  const btnPlayStop = q('btnPlayStop');
  const cfgGap = q('cfgGap');
  const cfgRounds = q('cfgRounds');
  const cfgStep = q('cfgStep');
  const cfgResume = q('cfgResume');

  /* ------------------------------------------------------------
   * 焦点追踪
   * 不能依赖 shadow.activeElement（部分手机 WebView 不支持，
   * 返回 undefined 会让 updateUI 把用户正在输入的 10 改回 3）
   * ------------------------------------------------------------ */
  let focusedCfg = null;
  [cfgGap, cfgRounds, cfgStep, cfgResume].forEach(function (el) {
    el.addEventListener('focus', function () { focusedCfg = el; });
    el.addEventListener('blur', function () { if (focusedCfg === el) focusedCfg = null; });
  });

  /** 把内存里的配置写到输入框（只在启动 / 恢复默认 / 保存时调用） */
  function syncCfgToUI() {
    cfgGap.value = C.loopGap;
    cfgRounds.value = C.rounds;
    cfgStep.value = C.stepGap;
    cfgResume.value = C.resumeMode || 'continue';
  }

  /** 直接读界面上的值，不依赖 C 是否被事件更新过 */
  function uiNum(el, dflt, min) {
    const v = parseFloat(el.value);
    return (isNaN(v) || v < min) ? dflt : v;
  }
  function uiLoopGap() { return uiNum(cfgGap, DEFAULTS.loopGap, 0); }
  function uiStepGap() { return uiNum(cfgStep, DEFAULTS.stepGap, 0); }
  function uiRounds() { return Math.round(uiNum(cfgRounds, DEFAULTS.rounds, 0)); }

  /* ============================================================
   * Toast
   * ============================================================ */
  let toastEl = null, toastTimer = null;
  function toast(msg) {
    if (!toastEl) {
      toastEl = document.createElement('div');
      toastEl.className = 'toast';
      shadow.appendChild(toastEl);
    }
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 1600);
  }

  /* ============================================================
   * UI 状态刷新
   * ============================================================ */
  let tickTimer = null;

  function fmtDur(ms) {
    if (!ms || ms < 0) ms = 0;
    const t = Math.floor(ms / 1000);
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60);
    const s = t % 60;
    const p = n => (n < 10 ? '0' : '') + n;
    return h > 0 ? h + ':' + p(m) + ':' + p(s) : p(m) + ':' + p(s);
  }

  function updateUI() {
    const n = S.steps.length;
    const now = Date.now();
    const total = uiRounds() > 0 ? uiRounds() : '∞';
    const done = S.doneRounds || 0;

    statSteps.textContent = n ? ('已录制 ' + n + ' 步') : '未录制';

    let elapsed = 0;
    if (S.recording) {
      elapsed = S.recStartTs ? now - S.recStartTs : 0;
      statLive.textContent = '● 录制中';
      statLive.className = 'dot red';
    } else if (S.playing) {
      elapsed = S.startTs ? now - S.startTs : 0;
      statLive.textContent = '▶ 执行中 ' + S.round + '/' + total;
      statLive.className = 'dot green';
    } else if (S.resumePending) {
      elapsed = S.startTs ? now - S.startTs : 0;
      statLive.textContent = '⏳ 待续跑 ' + S.round + '/' + total;
      statLive.className = 'dot green';
    } else {
      elapsed = S.lastElapsed || 0;   // 结束后保留上次总时长
      statLive.textContent = '待命';
      statLive.className = 'dot';
    }

    statTime.textContent = fmtDur(elapsed);
    statDone.textContent = String(done);

    // 轮间隔倒计时
    const waitLeft = (S.waitUntil && S.waitUntil > now)
      ? Math.ceil((S.waitUntil - now) / 1000) : 0;
    statWait.textContent = waitLeft > 0 ? ('下轮 ' + waitLeft + 's') : '';

    // 当前生效配置回显（直接读界面，确保和执行时用的一致）
    const sg = uiStepGap();
    const lg = uiLoopGap();
    cfgSum.textContent = '当前生效：步骤间隔 ' + (sg > 0 ? sg + ' 秒' : '按原速') +
      ' · 轮间隔 ' + lg + ' 秒 · 执行 ' + (uiRounds() > 0 ? uiRounds() + ' 次' : '无限次');

    // 圆钮：空闲时是圆点，录制/执行时自动拉宽成胶囊，直接显示计时和次数
    let ico = '☰';
    let meta = '';
    if (S.recording) {
      ico = '●';
      meta = fmtDur(elapsed) + ' · ' + n + '步';
    } else if (S.playing || S.resumePending) {
      ico = S.playing ? '▶' : '⏳';
      meta = fmtDur(elapsed) + ' · ' + done + '/' + total;
      if (waitLeft > 0) meta += ' ⏱' + waitLeft + 's';
    }

    fab.className = 'fab' +
      (S.recording ? ' rec' : (S.playing || S.resumePending) ? ' play' : '') +
      (meta ? ' wide' : '');
    fabIco.textContent = ico;
    fabMeta.textContent = meta;

    btnRecStart.disabled = S.recording;
    btnRecStop.disabled = !S.recording;
    btnPlayStart.disabled = S.playing || n === 0;
    btnPlayStop.disabled = !S.playing && !S.resumePending;

    // 注意：这里故意不再反向同步输入框的值。
    // 以前每秒把 cfgGap.value 改回 C.loopGap，一旦输入事件没触发，
    // 用户刚输入的 10 会被静默改回 3。现在输入框只由用户控制。

    // 每秒刷新一次计时
    const needTick = S.playing || S.recording || S.resumePending;
    if (needTick && !tickTimer) {
      tickTimer = setInterval(updateUI, 1000);
    } else if (!needTick && tickTimer) {
      clearInterval(tickTimer);
      tickTimer = null;
    }
  }

  /* ============================================================
   * 按钮位置（可拖动 + 记忆）
   * ============================================================ */
  function clamp(v, min, max) { return Math.min(Math.max(min, v), max); }

  function applyPos() {
    const size = 58;
    const p = load(KEY_POS, null);
    let left = p && typeof p.left === 'number' ? p.left : window.innerWidth - size - 16;
    let top = p && typeof p.top === 'number' ? p.top : window.innerHeight - size - 16;
    left = clamp(left, 6, window.innerWidth - size - 6);
    top = clamp(top, 6, window.innerHeight - size - 6);
    fab.style.left = left + 'px';
    fab.style.top = top + 'px';
  }
  applyPos();

  window.addEventListener('resize', () => {
    if (panel.classList.contains('open')) return;
    const w = fab.offsetWidth || 58;
    const h = fab.offsetHeight || 58;
    fab.style.left = clamp(parseFloat(fab.style.left) || 0, 6, window.innerWidth - w - 6) + 'px';
    fab.style.top = clamp(parseFloat(fab.style.top) || 0, 6, window.innerHeight - h - 6) + 'px';
  });

  /* ============================================================
   * 面板开关
   * ============================================================ */
  // 手机端面板贴底会盖住圆钮，打开时把圆钮抬到面板上方，关闭后复原
  let fabSavedPos = null;

  function openPanel() {
    panel.classList.add('open');
    updateUI();

    if (window.matchMedia('(max-width: 640px)').matches) {
      requestAnimationFrame(() => {
        const pr = panel.getBoundingClientRect();
        const fh = fab.offsetHeight || 58;
        if (!fabSavedPos) {
          fabSavedPos = { left: fab.style.left, top: fab.style.top };
        }
        fab.style.top = Math.max(6, pr.top - fh - 12) + 'px';
      });
    }
  }

  function closePanel() {
    panel.classList.remove('open');
    if (fabSavedPos) {
      fab.style.left = fabSavedPos.left;
      fab.style.top = fabSavedPos.top;
      fabSavedPos = null;
    }
  }
  /** 长按圆钮：开/关切换 */
  function togglePanel() {
    if (panel.classList.contains('open')) closePanel();
    else openPanel();
  }

  q('close').addEventListener('click', (e) => {
    e.stopPropagation();
    closePanel();
  });

  /* ============================================================
   * FAB 手势：长按开菜单 / 短按切换执行 / 拖动换位置
   * ============================================================ */
  let pressTimer = null, dragging = false, longPressed = false;
  let downPt = null, downPos = null;

  fab.addEventListener('pointerdown', (e) => {
    if (e.button != null && e.button !== 0) return;
    e.preventDefault();
    e.stopPropagation();

    try { fab.setPointerCapture(e.pointerId); } catch (err) {}

    downPt = { x: e.clientX, y: e.clientY };
    downPos = { left: parseFloat(fab.style.left) || 0, top: parseFloat(fab.style.top) || 0 };
    dragging = false;
    longPressed = false;

    pressTimer = setTimeout(() => {
      longPressed = true;
      togglePanel();
      try { if (navigator.vibrate) navigator.vibrate(15); } catch (err) {}
    }, 550);
  });

  fab.addEventListener('pointermove', (e) => {
    if (!downPt) return;
    const dx = e.clientX - downPt.x;
    const dy = e.clientY - downPt.y;

    if (!dragging && Math.sqrt(dx * dx + dy * dy) > 8) {
      dragging = true;
      clearTimeout(pressTimer);
    }
    if (dragging) {
      fabSavedPos = null;   // 用户自己拖了，就不再复原位置
      const w = fab.offsetWidth || 58;
      const h = fab.offsetHeight || 58;
      fab.style.left = clamp(downPos.left + dx, 6, window.innerWidth - w - 6) + 'px';
      fab.style.top = clamp(downPos.top + dy, 6, window.innerHeight - h - 6) + 'px';
    }
  });

  function endPress(e) {
    clearTimeout(pressTimer);
    if (!downPt) return;

    if (dragging) {
      save(KEY_POS, { left: parseFloat(fab.style.left) || 0, top: parseFloat(fab.style.top) || 0 });
    } else if (!longPressed) {
      // 短按：待续跑时先取消；否则开始 / 停止执行
      if (S.resumePending) cancelResume();
      else if (S.playing) stopPlay();
      else startPlay();
    }
    downPt = null;
    dragging = false;
  }

  fab.addEventListener('pointerup', endPress);
  fab.addEventListener('pointercancel', () => {
    clearTimeout(pressTimer);
    downPt = null;
    dragging = false;
  });

  // 菜单常驻：点页面其他地方不会关闭，只能用长按圆钮或右上角 ✕ 关闭

  /* ============================================================
   * 录制：采集
   * ============================================================ */
  function inOwnUI(e) {
    try {
      return typeof e.composedPath === 'function' && e.composedPath().indexOf(host) !== -1;
    } catch (err) { return false; }
  }

  function push(step) {
    const now = Date.now();
    step.t = S.steps.length ? Math.max(0, now - S.lastTs) : 0;
    S.lastTs = now;
    S.steps.push(step);
    saveSteps();
    updateUI();
  }

  /** 若上一条同类型则合并（滚动、连续输入），避免步数爆炸 */
  function pushMerge(step, same) {
    const last = S.steps[S.steps.length - 1];
    if (last && same(last)) {
      const now = Date.now();
      const dt = Math.max(0, now - S.lastTs);
      S.lastTs = now;
      const t = (last.t || 0) + dt;
      Object.assign(last, step);
      last.t = t;
      saveSteps();
      updateUI();
      return;
    }
    push(step);
  }

  function describe(el) {
    return {
      sel: cssPath(el),
      xp: xpathOf(el),
      tag: el.tagName.toLowerCase(),
      text: ((el.innerText || el.value || '') + '').trim().slice(0, 40)
    };
  }

  function onDocClick(e) {
    if (!S.recording || inOwnUI(e)) return;
    const el = e.target;
    if (!el || el.nodeType !== 1) return;
    if (el.closest && el.closest('#' + HOST_ID)) return;

    const d = describe(el);
    const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
    push({
      type: 'click',
      sel: d.sel, xp: d.xp, tag: d.tag, text: d.text,
      x: Math.round(e.clientX || (rect ? rect.left + rect.width / 2 : 0)),
      y: Math.round(e.clientY || (rect ? rect.top + rect.height / 2 : 0)),
      scrollX: Math.round(window.scrollX),
      scrollY: Math.round(window.scrollY)
    });
  }

  function onDocInput(e) {
    if (!S.recording || inOwnUI(e)) return;
    const el = e.target;
    if (!el || el.nodeType !== 1) return;
    if (!/^(INPUT|TEXTAREA)$/.test(el.tagName)) return;
    if (/^(checkbox|radio|file|submit|button|image|range|color)$/i.test(el.type || '')) return;

    const key = (el.getAttribute('name') || '') + '|' + cssPath(el);
    clearTimeout(S.pendingInput.get(key));
    S.pendingInput.set(key, setTimeout(() => {
      S.pendingInput.delete(key);
      if (!S.recording) return;
      const d = describe(el);
      push({ type: 'input', sel: d.sel, xp: d.xp, tag: d.tag, text: d.text, value: el.value });
    }, 500));
  }

  function onDocChange(e) {
    if (!S.recording || inOwnUI(e)) return;
    const el = e.target;
    if (!el || el.nodeType !== 1) return;
    if (el.tagName !== 'SELECT') return;
    const d = describe(el);
    push({ type: 'input', sel: d.sel, xp: d.xp, tag: d.tag, text: d.text, value: el.value });
  }

  function onDocScroll(e) {
    if (!S.recording) return;
    const t = e.target;

    if (t && t.nodeType === 1 && t !== document.documentElement && t !== document.body) {
      if (inOwnUI(e)) return;
      const el = t;
      clearTimeout(S.scrollTimer);
      S.scrollTimer = setTimeout(() => {
        if (!S.recording) return;
        const d = describe(el);
        pushMerge({
          type: 'scrollEl', sel: d.sel, xp: d.xp,
          top: Math.round(el.scrollTop), left: Math.round(el.scrollLeft)
        }, (l) => l.type === 'scrollEl' && l.sel === d.sel);
      }, 220);
    } else {
      clearTimeout(S.scrollTimer);
      S.scrollTimer = setTimeout(() => {
        if (!S.recording) return;
        pushMerge({
          type: 'scroll',
          x: Math.round(window.scrollX),
          y: Math.round(window.scrollY)
        }, (l) => l.type === 'scroll');
      }, 220);
    }
  }

  document.addEventListener('click', onDocClick, true);
  document.addEventListener('input', onDocInput, true);
  document.addEventListener('change', onDocChange, true);
  document.addEventListener('scroll', onDocScroll, true);

  /** 把防抖中的输入立即落盘 */
  function flushInputs() {
    S.pendingInput.forEach((timer, key) => {
      clearTimeout(timer);
      S.pendingInput.delete(key);
    });
    const active = document.activeElement;
    if (active && /^(INPUT|TEXTAREA|SELECT)$/.test(active.tagName)) {
      const last = S.steps[S.steps.length - 1];
      const d = describe(active);
      const exists = last && last.type === 'input' && last.sel === d.sel && last.value === active.value;
      if (!exists) push({ type: 'input', sel: d.sel, xp: d.xp, tag: d.tag, text: d.text, value: active.value });
    }
  }

  /* ============================================================
   * 录制：开始 / 结束
   * ============================================================ */
  function startRec() {
    if (S.recording) return;
    if (S.playing) stopPlay();
    if (S.steps.length && !confirm('当前已有 ' + S.steps.length + ' 步录制，开始新录制会清空，继续吗？')) return;

    S.steps = [];
    S.lastTs = Date.now();
    S.recStartTs = Date.now();
    S.recording = true;
    save(KEY_STEPS, []);
    updateUI();
    closePanel();
    toast('开始录制，操作页面即可');
  }

  function stopRec() {
    if (!S.recording) return;
    flushInputs();
    S.recording = false;
    clearTimeout(S.scrollTimer);
    save(KEY_STEPS, S.steps);
    updateUI();
    toast('录制结束，共 ' + S.steps.length + ' 步');
  }

  /* ============================================================
   * 回放
   * ============================================================ */
  /* ============================================================
   * 执行进度持久化：解决「点击导致页面刷新 → 脚本重载 → 回放中断」
   * ============================================================ */
  function saveRun(round, next, resumeCount) {
    try {
      localStorage.setItem(KEY_RUN, JSON.stringify({
        round: round,
        next: next,
        resumeCount: resumeCount || 0,
        startTs: S.startTs || Date.now(),
        done: S.doneRounds || 0,
        ts: Date.now()
      }));
    } catch (e) {}
  }

  function clearRun() {
    try { localStorage.removeItem(KEY_RUN); } catch (e) {}
  }

  /** 等待元素出现（刷新后页面可能还没渲染完） */
  async function waitForEl(step, timeout) {
    if (step.type === 'scroll') return null;
    let el = findEl(step);
    if (el) return el;
    const t0 = Date.now();
    while (Date.now() - t0 < timeout) {
      if (S.stop) return null;
      await sleep(200);
      el = findEl(step);
      if (el) return el;
    }
    return null;
  }

  async function execStep(s) {
    if (s.type === 'scroll') {
      window.scrollTo({ left: s.x || 0, top: s.y || 0, behavior: 'auto' });
      return;
    }
    if (s.type === 'scrollEl') {
      const el = await waitForEl(s, 3000);
      if (el) {
        el.scrollTop = s.top || 0;
        el.scrollLeft = s.left || 0;
      }
      return;
    }

    const el = await waitForEl(s, s.type === 'input' ? 4000 : 5000);

    if (s.type === 'input') {
      if (el) {
        try { el.focus(); } catch (e) {}
        setNativeValue(el, s.value == null ? '' : s.value);
      }
      return;
    }

    // click
    if (el) {
      try { el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'auto' }); } catch (e) {
        try { el.scrollIntoView(); } catch (e2) {}
      }
      fireClick(el, null, null);
    } else {
      // 坐标兜底
      if (s.scrollY != null) {
        try { window.scrollTo({ left: s.scrollX || 0, top: s.scrollY || 0, behavior: 'auto' }); } catch (e) {}
      }
      const target = document.elementFromPoint(s.x || 0, s.y || 0);
      if (target) fireClick(target, s.x, s.y);
    }
  }

  async function playOnce(startIndex, round) {
    const steps = S.steps;
    for (let i = startIndex; i < steps.length; i++) {
      if (S.stop) return false;
      const s = steps[i];

      // 【关键】执行本步之前，先把「下一步索引」写进 localStorage。
      // 如果本步点击会触发页面刷新，新页面加载后就能从这里接着跑，不会重头再来。
      saveRun(round, i + 1, S.resumeCount);

      // 步骤间隔：配置里是「秒」，这里换算成毫秒（支持 0.5 这类小数）
      const stepMs = Math.round(uiStepGap() * 1000);

      let wait;
      if (i === startIndex && startIndex > 0) {
        wait = 200;                       // 续跑时不要傻等
      } else if (i === 0) {
        wait = stepMs > 0 ? stepMs : 300;
      } else if (stepMs > 0) {
        wait = stepMs;
      } else {
        wait = s.t || 0;
      }
      wait = Math.min(wait, 120000);      // 单步最长等 2 分钟，避免设太大卡死

      if (wait > 0) await sleep(wait);
      if (S.stop) return false;

      try { await execStep(s); } catch (e) { console.warn('[录制回放] 步骤执行失败', s, e); }
    }
    return true;
  }

  /**
   * 等待轮间隔。不是一次性 sleep，而是每 300ms 检查一次配置，
   * 这样执行过程中改「轮间隔」能立即重新计时，不用等下一轮才生效。
   */
  async function waitRoundGap() {
    // 直接读界面上的「轮间隔」，不依赖 C 是否被事件更新过
    let lastGap = uiLoopGap();
    let end = Date.now() + lastGap * 1000;
    S.waitUntil = end;
    updateUI();
    console.log('[录制回放] 轮间隔等待 ' + lastGap + ' 秒（读自界面输入框）');

    while (!S.stop && Date.now() < end) {
      await sleep(300);
      if (S.stop) break;
      const g = uiLoopGap();
      if (g !== lastGap) {
        lastGap = g;
        end = Date.now() + g * 1000;
        S.waitUntil = end;
        updateUI();
        console.log('[录制回放] 轮间隔已改为 ' + g + ' 秒，重新计时');
      }
    }

    S.waitUntil = 0;
    updateUI();
  }

  async function runLoop(startRound, startIndex, resumeCount) {
    S.playing = true;
    S.resumePending = false;
    S.stop = false;
    S.round = Math.max(1, startRound || 1);
    S.resumeCount = resumeCount || 0;
    if (!S.startTs) S.startTs = Date.now();
    updateUI();

    let idx = Math.max(0, startIndex || 0);

    // 刷新续跑且正好落在新一轮起点（next=0, round>1）：
    // 说明刷新发生在轮间隔等待中，这里要重新等待，不能立即开跑。
    if (idx === 0 && (startRound || 1) > 1) {
      await waitRoundGap();
      if (S.stop) {
        S.playing = false;
        S.stop = false;
        clearRun();
        updateUI();
        return;
      }
    }

    while (!S.stop) {
      // 续跑点已越过末尾 → 上一轮在刷新前就跑完了。
      // 这里必须先补上「轮间隔」，否则「点击→刷新→续跑」会立即开跑，
      // 表现出来的就是轮间隔完全没生效（只剩页面加载那几秒）。
      if (idx >= S.steps.length) {
        if (uiRounds() > 0 && S.round >= uiRounds()) break;
        S.round++;
        idx = 0;
        saveRun(S.round, 0, S.resumeCount);
        await waitRoundGap();
        if (S.stop) break;
      }

      updateUI();
      const ok = await playOnce(idx, S.round);
      if (!ok || S.stop) break;

      S.doneRounds = (S.doneRounds || 0) + 1;
      updateUI();

      if (uiRounds() > 0 && S.round >= uiRounds()) break;

      S.round++;
      idx = 0;
      saveRun(S.round, 0, S.resumeCount);

      await waitRoundGap();
    }

    const finished = !S.stop;
    S.lastElapsed = S.startTs ? (Date.now() - S.startTs) : 0;
    S.playing = false;
    S.stop = false;
    clearRun();
    updateUI();
    if (finished) toast('执行结束，共完成 ' + (S.doneRounds || 0) + ' 轮');
  }

  function startPlay() {
    if (S.playing) return;
    if (!S.steps.length) { toast('还没有录制内容'); return; }
    if (S.recording) stopRec();
    if (S.resumePending) cancelResume();

    // 【关键】开始前强制从界面读取一次配置。
    // 手机上数字键盘有时不触发 input 事件，只靠自动保存会让 C.loopGap 停在默认值 3。
    readCfgFromUI();
    save(KEY_CFG, C);

    closePanel();
    S.stop = false;
    S.resumeCount = 0;
    S.doneRounds = 0;
    S.startTs = Date.now();

    // 把实际生效的配置回显出来，避免「以为设了其实没生效」
    const sg = uiStepGap();
    const lg = uiLoopGap();
    toast('开始执行 · 步骤间隔 ' + (sg > 0 ? sg + '秒' : '按原速') + ' · 轮间隔 ' + lg + '秒');

    runLoop(1, 0, 0);
  }

  function stopPlay() {
    if (S.resumePending) { cancelResume(); return; }
    if (!S.playing) return;
    S.stop = true;
    clearRun();
    updateUI();
    toast('正在停止…');
  }

  /* ============================================================
   * 刷新后续跑
   * ============================================================ */
  let resumeTimer = null;

  function tryResume() {
    const mode = C.resumeMode || 'continue';
    if (mode === 'off') return;

    const run = load(KEY_RUN, null);
    if (!run || typeof run.next !== 'number') return;
    if (!run.ts || Date.now() - run.ts > RUN_TTL) { clearRun(); return; }
    if (!S.steps.length) { clearRun(); return; }

    if ((run.resumeCount || 0) >= MAX_RESUME) {
      clearRun();
      toast('检测到反复刷新，已停止自动续跑');
      return;
    }

    S.resumePending = true;
    S.round = run.round || 1;
    S.startTs = run.startTs || Date.now();
    S.doneRounds = run.done || 0;
    updateUI();

    const nextStep = Math.min((run.next || 0) + 1, S.steps.length);
    toast('检测到未完成的执行，' +
      (mode === 'restart' ? '将从头重跑' : '将从第 ' + nextStep + ' 步续跑') +
      '（点圆钮取消）');

    clearTimeout(resumeTimer);
    resumeTimer = setTimeout(() => {
      if (!S.resumePending) return;
      S.resumePending = false;

      const fresh = load(KEY_RUN, null);
      if (!fresh) { updateUI(); return; }
      const cnt = (fresh.resumeCount || 0) + 1;

      if (mode === 'restart') runLoop(1, 0, cnt);
      else runLoop(fresh.round || 1, fresh.next || 0, cnt);
    }, 1800);
  }

  function cancelResume() {
    clearTimeout(resumeTimer);
    S.resumePending = false;
    clearRun();
    updateUI();
    toast('已取消自动续跑');
  }

  /* ============================================================
   * 按钮绑定
   * ============================================================ */
  btnRecStart.addEventListener('click', (e) => { e.stopPropagation(); startRec(); });
  btnRecStop.addEventListener('click', (e) => { e.stopPropagation(); stopRec(); });
  btnPlayStart.addEventListener('click', (e) => { e.stopPropagation(); startPlay(); });
  btnPlayStop.addEventListener('click', (e) => { e.stopPropagation(); stopPlay(); });

  q('btnClear').addEventListener('click', (e) => {
    e.stopPropagation();
    if (S.recording) stopRec();
    if (!S.steps.length) { toast('已经是空的了'); return; }
    if (!confirm('确定清空本网站的全部录制（' + S.steps.length + ' 步）？')) return;
    S.steps = [];
    save(KEY_STEPS, []);
    updateUI();
    toast('已清空');
  });

  q('btnResetPos').addEventListener('click', (e) => {
    e.stopPropagation();
    try { localStorage.removeItem(KEY_POS); } catch (err) {}
    applyPos();
    toast('按钮位置已重置');
  });

  function bindCfg(input, key, min, isFloat) {
    // 手机上数字键盘不一定触发 input，change / blur 也要监听，否则设置会丢
    const apply = () => {
      let v = isFloat ? parseFloat(input.value) : parseInt(input.value, 10);
      if (isNaN(v) || v < min) v = min;
      C[key] = v;
      save(KEY_CFG, C);
      updateUI();
    };
    input.addEventListener('input', apply);
    input.addEventListener('change', apply);
    input.addEventListener('blur', () => { apply(); markDirty(false); });
    input.addEventListener('click', (e) => e.stopPropagation());
  }
  bindCfg(cfgGap, 'loopGap', 0);
  bindCfg(cfgRounds, 'rounds', 0);
  bindCfg(cfgStep, 'stepGap', 0, true);   // 步骤间隔支持小数（0.5 秒等）

  /* ---------- 显式保存 / 恢复默认 ---------- */
  const btnSaveCfg = q('btnSaveCfg');

  function readCfgFromUI() {
    const num = (el, dflt, min) => {
      const v = parseFloat(el.value);
      return (isNaN(v) || v < min) ? dflt : v;
    };
    C.loopGap = num(cfgGap, DEFAULTS.loopGap, 0);
    C.rounds = Math.round(num(cfgRounds, DEFAULTS.rounds, 0));
    C.stepGap = num(cfgStep, DEFAULTS.stepGap, 0);
    C.resumeMode = cfgResume.value || 'continue';
  }

  function markDirty(on) {
    if (btnSaveCfg) btnSaveCfg.classList.toggle('dirty', !!on);
  }

  btnSaveCfg.addEventListener('click', (e) => {
    e.stopPropagation();
    readCfgFromUI();
    save(KEY_CFG, C);
    syncCfgToUI();
    markDirty(false);
    updateUI();
    toast('设置已保存 · 轮间隔 ' + C.loopGap + ' 秒 · 步骤间隔 ' +
      (C.stepGap > 0 ? C.stepGap + ' 秒' : '按原速'));
  });

  q('btnResetCfg').addEventListener('click', (e) => {
    e.stopPropagation();
    Object.assign(C, DEFAULTS);
    save(KEY_CFG, C);
    syncCfgToUI();
    markDirty(false);
    updateUI();
    toast('已恢复默认设置');
  });

  // 任一参数被改动就把「保存设置」高亮提醒
  [cfgGap, cfgRounds, cfgStep, cfgResume].forEach((el) => {
    el.addEventListener('input', () => markDirty(true));
    el.addEventListener('change', () => markDirty(true));
  });

  cfgResume.addEventListener('change', () => {
    C.resumeMode = cfgResume.value;
    save(KEY_CFG, C);
    updateUI();
  });
  cfgResume.addEventListener('click', (e) => e.stopPropagation());

  // 面板内的交互不要冒泡到页面。
  // 必须用冒泡阶段（false）：若用捕获阶段，stopPropagation 会阻断事件到达面板内的
  // input / button，导致输入框无法聚焦、按钮点不动。
  ['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click', 'touchstart', 'touchend']
    .forEach(ev => panel.addEventListener(ev, (e) => e.stopPropagation(), false));

  /* ============================================================
   * 启动
   * ============================================================ */
  syncCfgToUI();
  updateUI();

  // 检查是否刚因刷新而中断，是的话自动续跑
  setTimeout(tryResume, 400);

  // 页面卸载时保存
  window.addEventListener('beforeunload', () => {
    if (S.recording) flushInputs();
    save(KEY_STEPS, S.steps);
  });

  console.log('[录制回放助手] 已加载 · 长按右下角圆钮打开菜单');
})();

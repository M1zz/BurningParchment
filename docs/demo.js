// 불타는 내인생 웹 데모: 남은 시간만큼 양피지가 타고, 잠들기 30분 전부터 후 불어 끈다.
// 규칙은 앱과 같다: 기상 7:00 · 취침 23:00 (BedtimeManager 기본값), 불 끄기는 취침 30분 전부터 (blowOutWindowSeconds),
// 입김 세기 → 꺼짐 정도는 BlowDetector 의 값(-50~-12dBFS, 문턱 0.62, 초당 1.4 차오름, 0.25 되살아남).
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const WAKE = 7 * 3600, BED = 23 * 3600, WINDOW = 1800;
  const FLOOR = -50, CEIL = -12, THRESHOLD = 0.62, FILL = 1.4, RECOVER = 0.25;
  const fill = (s, o) => s.replace(/\{(\w+)\}/g, (_, k) => o[k]);
  const lang = document.documentElement.lang;
  const clock = sec => new Intl.DateTimeFormat(lang, { hour: "numeric", minute: "2-digit" })
    .format(new Date(2026, 0, 1, 0, 0, sec));
  const nowSec = () => { const d = new Date(); return d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds(); };
  // 깨어 있는 시간 밖(취침 뒤 · 기상 전)에 열면 바로 불어 볼 수 있게 잠들기 20분 전으로 둔다.
  const LATE = BED - 20 * 60;
  const clampT = s => s < WAKE || s >= BED - 60 ? LATE : s;
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const state = { t: clampT(nowSec()), out: false, keptMin: 0, holding: false, mic: 0, breath: 0, ext: 0 };

  root.innerHTML = `
    <div class="bp-stage">
      <svg viewBox="0 0 300 380" aria-hidden="true">
        <defs><filter id="bp-glow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>
          <linearGradient id="bp-paper" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E9D7B2"/><stop offset="1" stop-color="#C9AE7E"/></linearGradient></defs>
        <polygon class="bp-paper" fill="url(#bp-paper)"/>
        <polyline class="bp-flame bp-wide" filter="url(#bp-glow)"/><polyline class="bp-flame bp-core"/>
      </svg>
      <div class="bp-remain"><span>${T.remain}</span><strong aria-live="off"></strong></div>
    </div>
    <div class="bp-controls">
      <label class="bp-clock"><span>${T.clock} <b></b></span>
        <input type="range" min="${WAKE}" max="${BED - 60}" step="60"></label>
      <div class="bp-chips"><button type="button" class="chip" data-at="now">${T.now}</button>
        <button type="button" class="chip" data-at="late">${T.late}</button></div>
      <p class="muted small bp-range">${fill(T.range, { wake: clock(WAKE), bed: clock(BED) })}</p>
      <button type="button" class="bp-blow"><span>${T.blow}</span><i></i></button>
      <button type="button" class="mic bp-mic" aria-pressed="false">${T.mic}</button>
      <p class="bp-status" aria-live="polite"></p>
      <button type="button" class="chip bp-again" hidden>${T.again}</button>
      <p class="muted small">${T.note}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const svg = $("svg"), blur = $("feGaussianBlur"), paper = $(".bp-paper"), flames = root.querySelectorAll(".bp-flame"), remainEl = $(".bp-remain strong"), remainLabel = $(".bp-remain span");
  const range = $("input"), clockEl = $(".bp-clock b"), blow = $(".bp-blow"), bar = $(".bp-blow i");
  const status = $(".bp-status"), again = $(".bp-again"), micBtn = $(".bp-mic");
  const W = 300, H = 380, N = 22, seed = Array.from({ length: N + 1 }, (_, i) => Math.sin(i * 12.9898) * 43758.5453 % 1);

  const remaining = () => Math.max(0, BED - state.t);
  const canBlow = () => remaining() <= WINDOW && !state.out;

  // 남은 비율 r 만큼 양피지를 남긴다. 타는 선은 왼쪽 아래에서 오른쪽 위로 비스듬히 지나간다.
  function draw(time) {
    const r = state.out ? state.keptR : remaining() / (BED - WAKE), c = 2 * r;
    const lo = Math.max(0, c - 1), hi = Math.min(1, c), edge = [];
    // 불 끄는 때에는 앱의 불 끄기 화면처럼 남은 조각을 크게 본다.
    const k = remaining() <= WINDOW || state.out ? Math.max(hi, Math.min(1, c), 0.004) * 1.15 : 1;
    svg.setAttribute("viewBox", `0 0 ${W * k} ${H * k}`);
    blur.setAttribute("stdDeviation", 6 * k);
    const amp = 7 * k * (1 - state.ext * 0.7), wob = reduce ? 0 : time / 380;
    for (let i = 0; i <= N; i++) {
      const fx = hi - (hi - lo) * i / N, fy = c - fx;
      const n = (seed[i] - 0.5) * amp + Math.sin(i * 1.7 + wob) * amp * 0.35;
      edge.push([fx * W + n, fy * H + n]);
    }
    const corners = [...(c > 1 ? [[0, H]] : []), [0, 0], ...(c > 1 ? [[W, 0]] : [])];
    paper.setAttribute("points", (r <= 0 ? [] : [...edge, ...corners]).map(p => p.join(",")).join(" "));
    const lit = !state.out && r > 0;
    flames.forEach(f => { f.setAttribute("points", lit ? edge.map(p => p.join(",")).join(" ") : "");
      f.style.opacity = lit ? 1 - state.ext * 0.85 : 0; });
  }

  function render() {
    const rem = remaining(), h = Math.floor(rem / 3600), m = Math.floor(rem % 3600 / 60);
    remainEl.textContent = h ? fill(T.hm, { h, m }) : fill(T.m, { m });
    clockEl.textContent = clock(state.t);
    range.value = state.t;
    blow.disabled = !canBlow();
    micBtn.disabled = !canBlow() && !stream || !navigator.mediaDevices;
    bar.style.transform = `scaleX(${state.ext})`;
    again.hidden = !state.out;
    status.textContent = state.out ? fill(T.kept, { m: state.keptMin }) : canBlow() ? "" : T.wait;
    remainLabel.textContent = state.out ? T.out : T.remain;
    root.classList.toggle("is-out", state.out);
  }

  // 입김 세기 → 꺼짐 정도. 앱과 같은 식이다. 셈은 타이머로, 그리기는 화면 주기로.
  let last = performance.now(), tick = 0;
  setInterval(() => {
    const now = performance.now(), dt = Math.min(0.25, (now - last) / 1000); last = now;
    if ((tick += dt) >= 1) { tick -= 1; if (!state.out) state.t = Math.min(BED, state.t + 1); }
    if (!canBlow()) return;
    const level = Math.max(state.holding ? 1 : 0, state.mic);
    state.breath += (level - state.breath) * (level > state.breath ? 0.6 : 0.15);
    if (level > THRESHOLD) state.ext = Math.min(1, state.ext + (0.5 + (level - THRESHOLD) / (1 - THRESHOLD)) * FILL * dt);
    else state.ext = Math.max(0, state.ext - RECOVER * dt);
    if (state.ext >= 1) {
      state.out = true; state.keptR = remaining() / (BED - WAKE); state.keptMin = Math.floor(remaining() / 60);
      state.holding = false; stopMic();
    }
  }, 30);
  function loop(time) { draw(time); render(); requestAnimationFrame(loop); }

  range.addEventListener("input", () => { if (!state.out) { state.t = +range.value; state.ext = 0; } });
  root.addEventListener("click", e => {
    const at = e.target.closest("[data-at]")?.dataset.at;
    if (at && !state.out) { state.t = at === "now" ? clampT(nowSec()) : LATE; state.ext = 0; }
  });
  const hold = on => e => { if (e.type.startsWith("key") && e.key !== " " && e.key !== "Enter") return;
    if (e.type === "keydown") { e.preventDefault(); if (e.repeat) return; } state.holding = on && canBlow(); };
  ["pointerdown", "keydown"].forEach(ev => blow.addEventListener(ev, hold(true)));
  ["pointerup", "pointerleave", "pointercancel", "keyup", "blur"].forEach(ev => blow.addEventListener(ev, hold(false)));
  blow.addEventListener("contextmenu", e => e.preventDefault());
  again.addEventListener("click", () => { state.out = false; state.ext = 0; state.t = LATE; });

  // 마이크: 소리를 녹음하지 않고 음량(RMS)만 본다.
  let stream, actx, raf;
  async function startMic() {
    try { stream = await navigator.mediaDevices.getUserMedia({ audio: true }); }
    catch { micBtn.textContent = T.micNone; return; }
    actx = new (window.AudioContext || window.webkitAudioContext)();
    const an = actx.createAnalyser(); an.fftSize = 1024;
    actx.createMediaStreamSource(stream).connect(an);
    const buf = new Float32Array(an.fftSize);
    (function read() {
      an.getFloatTimeDomainData(buf);
      const rms = Math.sqrt(buf.reduce((s, v) => s + v * v, 0) / buf.length);
      const db = 20 * Math.log10(Math.max(rms, 1e-7));
      state.mic = Math.min(1, Math.max(0, (db - FLOOR) / (CEIL - FLOOR)));
      raf = requestAnimationFrame(read);
    })();
    micBtn.setAttribute("aria-pressed", "true"); micBtn.textContent = T.micOn;
  }
  function stopMic() {
    if (!stream) return;
    cancelAnimationFrame(raf); stream.getTracks().forEach(t => t.stop()); actx.close();
    stream = null; state.mic = 0;
    micBtn.setAttribute("aria-pressed", "false"); micBtn.textContent = T.mic;
  }
  micBtn.addEventListener("click", () => stream ? stopMic() : startMic());

  requestAnimationFrame(loop);
})();

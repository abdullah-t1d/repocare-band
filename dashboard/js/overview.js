// @ts-check
// Overview page UI. Renders whatever DashboardSnapshot the data source sends;
// it holds no readings and runs no sensor algorithms, only formatting.
(() => {
  const $ = (/** @type {string} */ id) => /** @type {HTMLElement} */ (document.getElementById(id));
  const SVGNS = 'http://www.w3.org/2000/svg';
  const HOUR = 3600000;
  const NA = 'غير متاح';
  const NOT_YET = 'غير متاح بعد';
  /** Fields the current data source can deliver; set once the source is created. */
  /** @type {Set<string>} */
  let provided = new Set(Object.keys(METRICS));
  /** "Unavailable right now" for a provided metric, "not available yet" for one the source cannot deliver. */
  const na = (/** @type {string} */ key) => (provided.has(key) ? NA : NOT_YET);

  /** @typedef {keyof typeof METRICS} MetricKey */
  /** @typedef {'heartRate' | 'spo2' | 'skinTemperature' | 'hrv' | 'steps'} NumericKey */

  const ICONS = {
    heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
    drop: '<path d="M12 3s6 6.4 6 11a6 6 0 0 1-12 0c0-4.6 6-11 6-11z"/><path d="M9.5 14.5a2.5 2.5 0 0 0 2.5 2.5"/>',
    thermo: '<path d="M10 14V5a2 2 0 1 1 4 0v9a4 4 0 1 1-4 0z"/><path d="M12 9v7"/>',
    gauge: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="M12 17l3.5-4.5"/>',
    steps: '<path d="M8 3c1.7 0 2.5 2 2.5 4.5S9.5 12 8 12 5.5 10 5.5 7.5 6.3 3 8 3z"/><path d="M6 15h4v2a2 2 0 0 1-4 0z"/><path d="M16 7c1.7 0 2.5 2 2.5 4.5S17.5 16 16 16s-2.5-2-2.5-4.5S14.3 7 16 7z"/><path d="M14 19h4v.5a2 2 0 0 1-4 0z"/>',
    motion: '<circle cx="13.5" cy="4.5" r="1.8"/><path d="M9 21l2.5-6-2.5-3 1.5-4.5 4 3 3 1"/><path d="M11.5 15l3.5 6"/>',
    intensity: '<path d="M5 20v-4M10 20v-8M15 20v-12M20 20V4"/>',
    wave: '<path d="M2 12h4l2-6 3 12 2.5-9 1.5 3h7"/>',
    recover: '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 4v4h-4"/>',
    rest: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/><path d="M8.5 11h2l1-2 1.5 4 1-2h1.5"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>',
  };
  /** @param {keyof typeof ICONS} name @param {string} [color] @param {number} [size] */
  const icon = (name, color = 'currentColor', size = 18) =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;

  /** @param {number | null} v @param {string} unit @param {number} digits */
  const valueHTML = (v, unit, digits) =>
    v === null ? '<span class="num">--</span>' : `<span class="num">${v.toFixed(digits)}</span><span class="unit">${unit}</span>`;
  const fmtInt = (/** @type {number} */ v) => Math.round(v).toLocaleString('en-US');

  /**
   * Compares the latest value with the average of the two hours before it.
   * @param {WearableReading[]} history @param {NumericKey} key
   * @param {number} threshold below this difference the value counts as unchanged
   * @param {string} unit @param {number} digits
   */
  function trendHTML(history, key, threshold, unit, digits) {
    const last = history[history.length - 1];
    if (!last || last[key] === null) return '';
    const prior = history.filter(r => r.timestamp < last.timestamp && r.timestamp >= last.timestamp - 2 * HOUR && r[key] !== null);
    if (prior.length < 3) return '';
    const mean = prior.reduce((s, r) => s + /** @type {number} */ (r[key]), 0) / prior.length;
    const d = /** @type {number} */ (last[key]) - mean;
    const span = 'آخر ' + spanText(last.timestamp - prior[0].timestamp);
    if (Math.abs(d) < threshold) return `<p class="trend-ind"><span aria-hidden="true">≈</span> قريب من متوسط ${span}</p>`;
    const up = d > 0;
    return `<p class="trend-ind"><span aria-hidden="true">${up ? '↑' : '↓'}</span> ${up ? 'أعلى' : 'أقل'} بـ <b class="num">${Math.abs(d).toFixed(digits)} ${unit}</b> من متوسط ${span}</p>`;
  }

  /** "12 دقيقة", "ساعتين"… for a duration in ms. */
  function spanText(/** @type {number} */ ms) {
    if (ms < 90000) return arCount(Math.max(1, Math.round(ms / 1000)), 'ثانية', 'ثانيتين', 'ثوانٍ');
    if (ms < 90 * 60000) return arCount(Math.round(ms / 60000), 'دقيقة', 'دقيقتين', 'دقائق');
    return arCount(Math.round(ms / HOUR), 'ساعة', 'ساعتين', 'ساعات');
  }

  /** How long the current activity state has lasted, from the history. */
  function activitySince(/** @type {WearableReading[]} */ history) {
    const last = history[history.length - 1];
    if (!last || last.activity === null) return '';
    let i = history.length - 1;
    while (i > 0 && history[i - 1].activity === last.activity) i--;
    if (i === 0) return 'طوال الفترة المعروضة';
    const min = Math.round((last.timestamp - history[i].timestamp) / 60000);
    if (min < 1) return 'بدأت الآن';
    return 'منذ ' + (min < 60 ? arCount(min, 'دقيقة', 'دقيقتين', 'دقائق') : arCount(Math.round(min / 60), 'ساعة', 'ساعتين', 'ساعات'));
  }

  /** Steps counted in the last hour, from the cumulative "steps today" history. */
  function stepsLastHour(/** @type {WearableReading[]} */ history) {
    const last = history[history.length - 1];
    if (!last || last.steps === null) return null;
    const before = history.find(r => r.timestamp >= last.timestamp - HOUR && r.steps !== null);
    if (!before || before === last || before.steps === null) return null;
    return last.steps >= before.steps ? last.steps - before.steps : last.steps;   // counter reset at midnight
  }

  /** Signal-quality caveat for PPG-based cards (HR, SpO2, HRV). */
  function trustHTML(/** @type {WearableReading | null} */ r, /** @type {EngineeringInfo | null} */ eng) {
    if (!r) return '';
    const msg = r.sensorContact === 'none' ? 'لا يوجد تلامس مع الجلد'
      : eng?.saturated ? 'الإشارة مشبعة (الإضاءة قوية)، قد لا تكون القراءة دقيقة'
      : r.sensorContact === 'weak' ? 'التلامس ضعيف، قد لا تكون القراءة دقيقة'
      : r.signalQuality === 'poor' ? 'الإشارة ضعيفة، قد لا تكون القراءة دقيقة' : '';
    return msg ? `<p class="warn-line">${icon('alert', 'currentColor', 14)}${msg}</p>` : '';
  }

  /**
   * Step scale (stress, motion); the active step is marked by position and the
   * word above it, colour is only a third cue.
   * @template {string} T
   * @param {ReadonlyArray<T>} steps @param {T | null} active @param {Readonly<Record<T, string>>} labels @param {boolean} status
   */
  const levelsHTML = (steps, active, labels, status) =>
    `<div class="levels" style="--n:${steps.length}" aria-hidden="true">${steps.map(l =>
      `<span class="${l === active ? 'on' + (status ? ' ' + l : '') : ''}">${labels[l]}</span>`).join('')}</div>`;

  /**
   * @param {{key: MetricKey, icon: string, value: string, body: string, stale: boolean, na: boolean, word?: boolean, big?: boolean}} c
   */
  function card(c) {
    if (!isMetricShown(c.key)) return '';
    const m = METRICS[c.key], tag = KIND_TAGS[m.kind];
    return `
    <article class="panel card${c.stale ? ' stale' : ''}" data-metric="${c.key}">
      <div class="card-top">${c.icon}<span>${m.label}</span>${tag ? `<span class="tag">${tag}</span>` : ''}</div>
      <div class="value${c.word ? ' word' : ''}${c.big ? ' big' : ''}${c.na ? ' na' : ''}">${c.value}</div>
      ${c.body}
    </article>`;
  }

  /** @param {DashboardSnapshot} s */
  function renderCards(s) {
    /** @type {WearableReading} */
    const r = s.latest ?? normalizeReading({ timestamp: Date.now() });
    const h = s.history, stale = !!s.latest && !s.device.connected, trust = trustHTML(s.latest, s.engineering);
    const u = (/** @type {MetricKey} */ k) => METRICS[k].unit;

    $('mainCards').innerHTML = [
      card({ key: 'heartRate', icon: icon('heart', 'var(--s-hr)'), value: valueHTML(r.heartRate, u('heartRate'), 0), stale, na: r.heartRate === null,
        body: `<p class="card-status">${r.heartRate === null ? na('heartRate') : r.activity && r.activity !== 'unknown' ? 'قيست أثناء ' + ACTIVITY_LABELS[r.activity] : 'من حساس MAX30102'}</p>${trust}${trendHTML(h, 'heartRate', 3, 'BPM', 0)}` }),
      card({ key: 'spo2', icon: icon('drop', 'var(--s-spo2)'), value: valueHTML(r.spo2, u('spo2'), 0), stale, na: r.spo2 === null,
        body: `<p class="card-status">${r.spo2 === null ? na('spo2') : 'تقدير من السوار، ليس قياسًا طبيًا'}</p>${trust}${trendHTML(h, 'spo2', 1, '%', 0)}` }),
      card({ key: 'skinTemperature', icon: icon('thermo', 'var(--s-temp)'), value: valueHTML(r.skinTemperature, u('skinTemperature'), 1), stale, na: r.skinTemperature === null,
        body: `<p class="card-status">${r.skinTemperature === null ? na('skinTemperature') : 'على سطح المعصم، ليست حرارة الجسم'}</p>${trendHTML(h, 'skinTemperature', 0.2, '°C', 1)}` }),
      card({ key: 'stressLevel', icon: icon('gauge'), word: true, value: r.stressLevel ? STRESS_LABELS[r.stressLevel] : '--', stale, na: r.stressLevel === null,
        body: levelsHTML(STRESS_LEVELS, r.stressLevel, STRESS_LABELS, true) + `<p class="card-status">${r.stressLevel === null ? na('stressLevel') : 'تقدير عام، ليس تشخيصًا'}</p>` }),
    ].join('');

    const lastHour = stepsLastHour(h);
    $('activityCards').innerHTML = [
      card({ key: 'steps', icon: icon('steps', 'var(--s-steps)'), big: true, stale, na: r.steps === null,
        value: r.steps === null ? '<span class="num">--</span>' : `<span class="num">${fmtInt(r.steps)}</span><span class="unit">${u('steps')}</span>`,
        body: `<p class="card-status">${r.steps === null ? na('steps') : lastHour === null ? 'عدّ تجريبي من حساس الحركة' : `في آخر ساعة: <span class="num">${fmtInt(lastHour)}</span> خطوة`}</p>
               <p class="card-status">قيد الاختبار: المشي، الوقوف، الحركة اليومية، وخطوات خاطئة من حركة اليد</p>` }),
      card({ key: 'activity', icon: icon('motion'), word: true, value: r.activity ? ACTIVITY_LABELS[r.activity] : '--', stale, na: r.activity === null,
        body: `<p class="card-status">${r.activity === null ? na('activity') : activitySince(h) || 'من حساس الحركة'}</p>` }),
      card({ key: 'motionIntensity', icon: icon('intensity'), word: true, value: r.motionIntensity ? MOTION_LABELS[r.motionIntensity] : '--', stale, na: r.motionIntensity === null,
        body: levelsHTML(MOTION_LEVELS, r.motionIntensity, MOTION_LABELS, false) +
              `<p class="card-status">${r.motionIntensity === null ? na('motionIntensity') : 'الحركة العالية تضعف دقة النبض والأكسجين'}</p>` }),
    ].join('');

    const rec = r.recoveryScore;
    $('expCards').innerHTML = [
      card({ key: 'hrv', icon: icon('wave', 'var(--s-hrv)'), value: valueHTML(r.hrv, u('hrv'), 0), stale, na: r.hrv === null,
        body: `<p class="card-status">${r.hrv === null ? na('hrv') : 'RMSSD من نبض المعصم (PRV)'}</p>${trust}${trendHTML(h, 'hrv', 4, 'ms', 0)}` }),
      card({ key: 'recoveryScore', icon: icon('recover'), stale, na: rec === null,
        value: rec === null ? '<span class="num">--</span>' : `<span class="num">${Math.round(rec)}<span class="unit">${u('recoveryScore')}</span></span>`,
        body: `<div class="meter" role="meter" aria-label="${METRICS.recoveryScore.label}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${rec ?? 0}"><i style="width:${rec ?? 0}%"></i></div>
               <p class="card-status">${rec === null ? na('recoveryScore') : 'مستوى ' + recoveryBand(rec) + ' · مؤشر تجريبي'}</p>` }),
      card({ key: 'restingHeartRate', icon: icon('rest'), value: valueHTML(r.restingHeartRate, u('restingHeartRate'), 0), stale, na: r.restingHeartRate === null,
        body: `<p class="card-status">${r.restingHeartRate === null ? (provided.has('restingHeartRate') ? NA : 'غير متاح بعد: يُحسب لاحقًا من فترات راحة طويلة') : 'من فترات الراحة الطويلة'}</p>` }),
    ].join('');
  }

  // ---------- Device ----------
  function renderDevice(/** @type {DeviceState} */ d) {
    $('deviceName').textContent = d.deviceName;
    const pill = $('devicePill');
    pill.textContent = d.connected ? 'متصل' : 'غير متصل';
    pill.className = 'pill ' + (d.connected ? 'on' : 'off');
    $('lastSync').textContent = formatSince(d.lastSync);
  }

  // ---------- Trend charts ----------
  // `domain`: the y-axis always covers at least this range, so small integer
  // steps (SpO2 97 → 98) don't look like large swings
  /** @type {{key: NumericKey, color: string, digits: number, type: 'line' | 'steps', domain?: [number, number]}[]} */
  const CHARTS = [
    { key: 'heartRate', color: 'var(--s-hr)', digits: 0, type: 'line' },
    { key: 'spo2', color: 'var(--s-spo2)', digits: 0, type: 'line', domain: [90, 100] },
    { key: 'skinTemperature', color: 'var(--s-temp)', digits: 1, type: 'line' },
    { key: 'hrv', color: 'var(--s-hrv)', digits: 0, type: 'line' },
    { key: 'steps', color: 'var(--s-steps)', digits: 0, type: 'steps' },
  ];
  const shownCharts = CHARTS.filter(c => isMetricShown(c.key));

  const ACTIVITY_FILL = { resting: 'var(--a-resting)', walking: 'var(--a-walking)', active: 'var(--a-active)', unknown: 'none' };
  /** @type {ReadonlyArray<'resting' | 'walking' | 'active'>} */
  const LEGEND_STATES = ['resting', 'walking', 'active'];

  $('charts').innerHTML = shownCharts.map(c => `
    <figure class="panel chart${c.type === 'steps' ? ' wide' : ''}">
      <h3><i style="background:${c.color}"></i>${c.type === 'steps' ? 'الخطوات والنشاط' : METRICS[c.key].label}</h3>
      <p class="sub" data-sub="${c.key}"></p>
      <div class="plot" data-plot="${c.key}"></div>
      ${c.type === 'steps' ? `<div class="legend" aria-hidden="true">${LEGEND_STATES.map(a =>
        `<span><i style="background:${ACTIVITY_FILL[a]}"></i>${ACTIVITY_LABELS[a]}</span>`).join('')}</div>` : ''}
    </figure>`).join('');

  /** 1 / 2 / 5 × 10^k step giving about `count` intervals. */
  function niceStep(/** @type {number} */ range, /** @type {number} */ count) {
    const raw = range / count, p = 10 ** Math.floor(Math.log10(raw)), f = raw / p;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
  }

  /** @param {string} tag @param {Record<string, string | number>} attrs */
  function el(tag, attrs) {
    const n = document.createElementNS(SVGNS, tag);
    for (const k in attrs) n.setAttribute(k, String(attrs[k]));
    return n;
  }

  /** pointer x per chart while hovering, so a redraw can restore the tooltip */
  /** @type {Map<string, number>} */
  const hoverX = new Map();

  /** @param {typeof CHARTS[number]} c @param {WearableReading[]} history */
  function drawChart(c, history) {
    const box = /** @type {HTMLElement} */ (document.querySelector(`[data-plot="${c.key}"]`));
    const sub = /** @type {HTMLElement} */ (document.querySelector(`[data-sub="${c.key}"]`));
    const unit = METRICS[c.key].unit, steps = c.type === 'steps';
    // one point per reading; null = gap (the line breaks instead of bridging it).
    // Steps are drawn per interval: the difference of the cumulative counter.
    const pts = history.map((r, i) => {
      if (!steps) return { t: r.timestamp, v: r[c.key], r };
      const prev = history[i - 1];
      const v = !prev || r.steps === null || prev.steps === null ? null : r.steps >= prev.steps ? r.steps - prev.steps : r.steps;
      return { t: r.timestamp, v, r };
    });
    const vals = /** @type {number[]} */ (pts.map(p => p.v).filter(v => v !== null));
    box.innerHTML = '';
    sub.innerHTML = steps ? 'خطوات لكل فترة' : `<span class="num">${unit}</span>`;
    if (!provided.has(c.key)) { box.innerHTML = `<p class="empty-chart">${NOT_YET}: لم يُضف إلى الفيرموير</p>`; return; }
    if (vals.length < 2) { box.innerHTML = '<p class="empty-chart">لا توجد قراءات كافية بعد</p>'; return; }

    const W = box.clientWidth, H = box.clientHeight, L = 38, R = 10, T = 8, B = steps ? 28 : 20;
    let lo = steps ? 0 : Math.min(...vals, ...(c.domain ? [c.domain[0]] : [])), hi = Math.max(...vals, ...(c.domain ? [c.domain[1]] : []));
    const step = niceStep(Math.max(hi - lo, c.digits ? 0.5 : 5), 3);
    lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
    if (hi === lo) hi = lo + step;
    const t0 = pts[0].t, t1 = pts[pts.length - 1].t;
    const x = (/** @type {number} */ t) => L + ((t - t0) / (t1 - t0)) * (W - L - R);
    const y = (/** @type {number} */ v) => T + (1 - (v - lo) / (hi - lo)) * (H - T - B);

    const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': `${METRICS[c.key].label} خلال آخر ${spanText(t1 - t0)}` });
    for (let v = lo; v <= hi + step / 2; v += step) {
      svg.append(el('line', { x1: L, x2: W - R, y1: y(v), y2: y(v), style: 'stroke:var(--rule)', 'stroke-width': 1 }));
      const label = el('text', { x: L - 6, y: y(v) + 4, 'text-anchor': 'end' });
      label.textContent = steps ? fmtInt(v) : v.toFixed(step < 1 ? 1 : 0);
      svg.append(label);
    }
    // time ticks: the smallest round interval giving at most ~5 labels, aligned to local clock time
    const every = [1, 2, 5, 10, 15, 30, 60, 180, 360].map(m => m * 60000).find(ms => (t1 - t0) / ms <= 5) ?? 6 * HOUR;
    const tz = new Date(t0).getTimezoneOffset() * 60000;
    for (let t = Math.ceil((t0 - tz) / every) * every + tz; t <= t1; t += every) {
      if (x(t) < L + 14 || x(t) > W - R - 14) continue;
      const label = el('text', { x: x(t), y: H - 4, 'text-anchor': 'middle' });
      label.textContent = formatClock(t);
      svg.append(label);
    }

    /** bar i covers the interval (t[i-1], t[i]] */
    const slot = (/** @type {number} */ i) => ({ x0: x(pts[Math.max(i - 1, 0)].t), x1: x(pts[i].t) });
    const mid = (/** @type {number} */ i) => (steps ? (slot(i).x0 + slot(i).x1) / 2 : x(pts[i].t));
    if (steps) {
      pts.forEach((p, i) => {
        if (!i) return;
        const { x0, x1 } = slot(i);
        const fill = p.r.activity ? ACTIVITY_FILL[p.r.activity] : 'none';
        if (fill !== 'none') svg.append(el('rect', { x: x0, y: H - B + 3, width: Math.max(x1 - x0, 1), height: 6, style: `fill:${fill}` }));
        if (p.v === null || p.v <= 0) return;
        const bw = Math.max(x1 - x0 - 2, 3), top = y(p.v), r = Math.min(1.5, (y(0) - top) / 2);
        svg.append(el('path', { d: `M${x0 + 1},${y(0)}V${top + r}q0,${-r} ${r},${-r}h${bw - 2 * r}q${r},0 ${r},${r}V${y(0)}z`, style: `fill:${c.color}` }));
      });
    } else {
      let d = '', pen = false;
      for (const p of pts) {
        if (p.v === null) { pen = false; continue; }
        d += `${pen ? 'L' : 'M'}${x(p.t).toFixed(1)},${y(p.v).toFixed(1)}`; pen = true;
      }
      svg.append(el('path', { d, fill: 'none', style: `stroke:${c.color}`, 'stroke-width': 2, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' }));
      const last = pts[pts.length - 1];
      if (last.v !== null) svg.append(el('circle', { cx: x(last.t), cy: y(last.v), r: 4, style: `fill:${c.color};stroke:var(--sheet)`, 'stroke-width': 2 }));
    }

    // hover / touch: crosshair and tooltip on the nearest reading (or interval)
    const cross = el('line', { y1: T, y2: H - B, style: 'stroke:var(--muted)', 'stroke-width': 1, 'stroke-dasharray': '3 3', visibility: 'hidden' });
    const dot = el('circle', { r: 4, style: `fill:${c.color};stroke:var(--sheet)`, 'stroke-width': 2, visibility: 'hidden' });
    svg.append(cross, dot);
    const tip = document.createElement('div'); tip.className = 'tip'; tip.hidden = true;
    box.append(svg, tip);

    const show = (/** @type {number} */ px) => {
      hoverX.set(c.key, px);
      let i = steps ? 1 : 0;
      for (let j = i; j < pts.length; j++) if (Math.abs(mid(j) - px) < Math.abs(mid(i) - px)) i = j;
      const p = pts[i], bx = mid(i);
      cross.setAttribute('x1', String(bx)); cross.setAttribute('x2', String(bx)); cross.setAttribute('visibility', 'visible');
      if (!steps && p.v !== null) { dot.setAttribute('cx', String(bx)); dot.setAttribute('cy', String(y(p.v))); dot.setAttribute('visibility', 'visible'); }
      else dot.setAttribute('visibility', 'hidden');
      const val = p.v === null ? NA : steps ? `${fmtInt(p.v)} خطوة` : `${p.v.toFixed(c.digits)} ${unit}`;
      const when = steps ? `${formatClock(pts[i - 1].t)}–${formatClock(p.t)}` : formatClock(p.t);
      const extra = steps && p.r.activity ? ' · ' + ACTIVITY_LABELS[p.r.activity] : '';
      tip.innerHTML = `<b class="num">${val}</b>${extra} · <span class="num">${when}</span>`;
      tip.hidden = false;
      tip.style.left = Math.min(Math.max(bx, 80), W - 80) + 'px';
      tip.style.top = (p.v === null ? T : Math.max(y(p.v) - 40, -30)) + 'px';
    };
    const hide = () => { hoverX.delete(c.key); cross.setAttribute('visibility', 'hidden'); dot.setAttribute('visibility', 'hidden'); tip.hidden = true; };
    const fromEvent = (/** @type {PointerEvent} */ e) => show(e.clientX - svg.getBoundingClientRect().left);
    svg.addEventListener('pointermove', fromEvent);
    svg.addEventListener('pointerdown', fromEvent);
    svg.addEventListener('pointerleave', hide);
    const keep = hoverX.get(c.key);
    if (keep !== undefined) show(keep);          // live data redraws every second; keep the tooltip in place

    if (!steps) sub.innerHTML += ` · المدى <span class="num">${Math.min(...vals).toFixed(c.digits)}–${Math.max(...vals).toFixed(c.digits)}</span>`;
  }

  const drawCharts = (/** @type {WearableReading[]} */ history) => shownCharts.forEach(c => drawChart(c, history));

  function renderTable(/** @type {WearableReading[]} */ history) {
    /** @param {number | null} v @param {number} digits */
    const n = (v, digits) => (v === null ? '--' : `<span class="num">${v.toFixed(digits)}</span>`);
    /** @param {string | null} k @param {Readonly<Record<string, string>>} labels */
    const w = (k, labels) => (k === null ? '--' : labels[k]);
    $('historyTable').innerHTML =
      '<thead><tr><th>الوقت</th><th>النبض <span class="num">(BPM)</span></th><th>الأكسجين <span class="num">(%)</span></th><th>حرارة الجلد <span class="num">(°C)</span></th><th>HRV <span class="num">(ms)</span></th><th>الخطوات</th><th>النشاط</th><th>الحركة</th><th>التوتر</th><th>جودة الإشارة</th></tr></thead><tbody>' +
      history.slice(-300).reverse().map(r => `<tr><td class="num">${formatClock(r.timestamp)}</td><td>${n(r.heartRate, 0)}</td><td>${n(r.spo2, 0)}</td><td>${n(r.skinTemperature, 1)}</td><td>${n(r.hrv, 0)}</td><td>${r.steps === null ? '--' : `<span class="num">${fmtInt(r.steps)}</span>`}</td><td>${w(r.activity, ACTIVITY_LABELS)}</td><td>${w(r.motionIntensity, MOTION_LABELS)}</td><td>${w(r.stressLevel, STRESS_LABELS)}</td><td>${w(r.signalQuality, QUALITY_LABELS)}</td></tr>`).join('') +
      '</tbody>';
  }

  // ---------- Engineering / sensor debug ----------
  function renderDebug(/** @type {WearableReading | null} */ r, /** @type {EngineeringInfo | null} */ e) {
    /** @param {string} label @param {string} value */
    const row = (label, value) => `<dt>${label}</dt><dd>${value}</dd>`;
    const raw = (/** @type {number | null | undefined} */ v) => (v == null ? '--' : `<span class="num">${fmtInt(v)}</span>`);
    $('debugList').innerHTML = [
      row(METRICS.rawIR.label, raw(r?.rawIR)),
      row(METRICS.rawRed.label, raw(r?.rawRed)),
      row(METRICS.signalQuality.label, r?.signalQuality ? QUALITY_LABELS[r.signalQuality] : '--'),
      row(METRICS.sensorContact.label, r?.sensorContact ? CONTACT_LABELS[r.sensorContact] : '--'),
      row(METRICS.beatDetected.label, r?.beatDetected == null ? '--' : r.beatDetected ? 'نعم' : 'لا'),
      row(METRICS.motionIntensity.label, r?.motionIntensity ? MOTION_LABELS[r.motionIntensity] : '--'),
      row(METRICS.activity.label, r?.activity ? ACTIVITY_LABELS[r.activity] : '--'),
      row('وقت القراءة', r ? `<span class="num">${formatClock(r.timestamp, true)}</span>` : '--'),
      ...(e ? [
        row('جودة الإشارة (رقمية)', e.qualityPct === null ? '--' : `<span class="num">${e.qualityPct}/100</span>`),
        row('مؤشر التروية (PI)', e.perfusionIndex === null ? '--' : `<span class="num">${e.perfusionIndex.toFixed(2)}%</span>`),
        row('تشبع الإشارة', e.saturated === null ? '--' : e.saturated ? 'نعم، خفّض الإضاءة' : 'لا'),
        row('نبضات محسوبة', e.beatsStored === null ? '--' : `<span class="num">${e.beatsStored}</span>`),
        row('آخر فترة بين نبضتين', e.lastIbiMs === null ? '--' : `<span class="num">${Math.round(e.lastIbiMs)} ms</span>`),
        row('الإضاءة', e.ledLevel === null ? '--' : e.ledLevel === 'auto' ? 'تلقائية' : `مستوى <span class="num">${e.ledLevel}</span>`),
        row('تيار الإضاءة', e.ledCurrentMa === null ? '--' : `<span class="num">${e.ledCurrentMa.toFixed(1)} mA</span>`),
        row('علامة الحركة (فيرموير)', e.motionFlag === null ? '--' : e.motionFlag ? '1' : '0'),
        row('حساس الحرارة AS6221', e.skinSensorReady ? 'جاهز' : 'لم تصل رسالة الجاهزية'),
      ] : []),
    ].join('');
    $('statusLog').innerHTML = e && e.statusLog.length
      ? e.statusLog.map(t => `<li>${t.replace(/[&<>]/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[ch] ?? ch)}</li>`).join('')
      : '<li>--</li>';
  }

  function renderValidationTable() {
    $('validationTable').innerHTML = '<thead><tr><th>المقياس</th><th>الحقل</th><th>المصدر</th><th>النوع</th><th>حالة التحقق</th><th>يرسله المصدر الحالي</th></tr></thead><tbody>' +
      Object.entries(METRICS).map(([k, m]) => `<tr><td>${m.label}</td><td class="num">${k}</td><td>${m.source}</td><td>${KIND_TAGS[m.kind] || 'قياس مباشر'}</td><td>${VALIDATION_LABELS[m.validation]}</td><td>${provided.has(k) ? 'نعم' : 'ليس بعد'}</td></tr>`).join('') +
      '</tbody>';
  }

  /** @param {HTMLCanvasElement} canvas */
  function fit(canvas) {
    const rect = canvas.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    const w = Math.round(rect.width * dpr), h = Math.round(rect.height * dpr);
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    const ctx = /** @type {CanvasRenderingContext2D} */ (canvas.getContext('2d'));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { ctx, w: rect.width, h: rect.height };
  }

  const css = getComputedStyle(document.documentElement);
  const cssVar = (/** @type {string} */ n) => css.getPropertyValue(n).trim();
  let lastBeatAge = Infinity;

  function drawWave(/** @type {PpgWindow | null} */ ppg) {
    const { ctx, w, h } = fit(/** @type {HTMLCanvasElement} */ ($('waveCanvas')));
    ctx.clearRect(0, 0, w, h);
    $('waveEmpty').hidden = !!ppg && ppg.samples.length > 1;
    if (!ppg || ppg.samples.length < 2) return;
    const span = ppg.sampleRate * PPG_WINDOW_S;
    // light grid: one vertical line per second
    ctx.strokeStyle = cssVar('--rule'); ctx.lineWidth = 1;
    for (let s = 1; s < PPG_WINDOW_S; s++) { const gx = (s / PPG_WINDOW_S) * w; ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke(); }

    // newest sample on the right edge, like the live monitor
    const n = ppg.samples.length, xs = (/** @type {number} */ i) => w - ((n - 1 - i) / (span - 1)) * w;
    let mn = Math.min(...ppg.samples), mx = Math.max(...ppg.samples);
    if (mx - mn < 1) { mn -= 1; mx += 1; }
    const pad = (mx - mn) * 0.12, ys = (/** @type {number} */ v) => h - ((v - mn + pad) / (mx - mn + 2 * pad)) * h;
    ctx.strokeStyle = cssVar('--pulse'); ctx.globalAlpha = 0.4; ctx.lineWidth = 2;
    for (const b of ppg.beats) { ctx.beginPath(); ctx.moveTo(xs(b), 0); ctx.lineTo(xs(b), 12); ctx.stroke(); }
    ctx.globalAlpha = 1; ctx.lineJoin = 'round'; ctx.beginPath();
    ppg.samples.forEach((v, i) => (i ? ctx.lineTo(xs(i), ys(v)) : ctx.moveTo(xs(i), ys(v))));
    ctx.stroke();

    // flash the beat dot when a new beat has arrived (the newest beat got younger)
    const age = ppg.beats.length ? n - 1 - ppg.beats[ppg.beats.length - 1] : Infinity;
    if (age < lastBeatAge) { const d = $('beatDot'); d.classList.remove('hit'); void d.offsetWidth; d.classList.add('hit'); }
    lastBeatAge = age;
  }

  // ---------- Wiring ----------
  /** @type {DashboardSnapshot | null} */
  let snapshot = null;
  /** @type {WearableReading[] | null} */ let drawnHistory = null;
  /** @type {WearableReading | null | undefined} */ let drawnLatest;
  /** @type {EngineeringInfo | null | undefined} */ let drawnEngineering;
  let tableStale = true;
  const debug = /** @type {HTMLDetailsElement} */ ($('debug'));
  const tableBox = /** @type {HTMLDetailsElement} */ ($('tableDetails'));
  const connectBtn = /** @type {HTMLButtonElement} */ ($('connectBtn'));

  function render() {
    if (!snapshot) return;
    const { device, latest, history: h } = snapshot;
    renderDevice(device);
    $('staleNote').hidden = !(latest && !device.connected);
    $('notice').hidden = !device.error;
    $('notice').textContent = device.error ?? '';
    connectBtn.textContent = device.connected ? 'قطع الاتصال' : 'اتصال بسوار repoCare';
    connectBtn.classList.toggle('secondary', device.connected);

    if (latest !== drawnLatest || snapshot.engineering !== drawnEngineering) {   // readings ~1/s; the waveform much faster
      if (latest !== drawnLatest) renderCards(snapshot);
      drawnLatest = latest;
      drawnEngineering = snapshot.engineering;
      renderDebug(latest, snapshot.engineering);
    }
    if (h !== drawnHistory) {
      drawnHistory = h;
      drawCharts(h);
      tableStale = true;
      if (tableBox.open) { renderTable(h); tableStale = false; }
      $('trendRange').textContent = h.length > 1 ? 'آخر ' + spanText(h[h.length - 1].timestamp - h[0].timestamp) : 'منذ فتح الصفحة';
    }
    if (debug.open) drawWave(snapshot.ppg);
  }

  (async () => {
    const source = await createDataSource();
    provided = new Set(source.provides);
    renderValidationTable();
    $('mockBadge').hidden = source.kind !== 'mock';
    if (source.connect) {
      connectBtn.hidden = false;
      connectBtn.disabled = source.supported === false;
      connectBtn.addEventListener('click', async () => {
        connectBtn.disabled = true;
        try { await (snapshot?.device.connected ? source.disconnect?.() : source.connect?.()); }
        finally { connectBtn.disabled = source.supported === false; }
      });
    }
    source.subscribe(s => { snapshot = s; render(); });
  })();

  debug.addEventListener('toggle', () => { if (debug.open && snapshot) drawWave(snapshot.ppg); });
  tableBox.addEventListener('toggle', () => { if (tableBox.open && snapshot && tableStale) { renderTable(snapshot.history); tableStale = false; } });
  setInterval(() => { if (snapshot) $('lastSync').textContent = formatSince(snapshot.device.lastSync); }, 30000);
  let resizeTimer = 0;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => { if (snapshot) drawCharts(snapshot.history); }, 120);
  });
})();

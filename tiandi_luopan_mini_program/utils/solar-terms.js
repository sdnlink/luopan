/**
 * solar-terms.js
 * 节气精确推算算法（定气法：二分太阳视黄经法）
 */

const { MOUNTAINS_DATA } = require('./compass-data');

const SOLAR_TERM_NAMES = [
  '小寒', '大寒', '立春', '雨水', '惊蛰', '春分',
  '清明', '谷雨', '立夏', '小满', '芒种', '夏至',
  '小暑', '大暑', '立秋', '处暑', '白露', '秋分',
  '寒露', '霜降', '立冬', '小雪', '大雪', '冬至'
];

const SOLAR_LON = [
  285, 300, 315, 330, 345, 0, 15, 30, 45, 60, 75, 90,
  105, 120, 135, 150, 165, 180, 195, 210, 225, 240, 255, 270
];

const sTermInfo = [
  0, 21208, 42467, 63836, 85337, 107014, 128867, 150921,
  173149, 195551, 218072, 240693, 263343, 285989, 308563, 331033,
  353350, 375494, 397447, 419210, 440795, 462224, 483532, 504758
];

function julianDay(y, m, d, h) {
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  const jdn = d + Math.floor((153 * mm + 2) / 5) + 365 * yy + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
  return jdn + (h - 12) / 24;
}

function sunApparentLon(jd) {
  const T = (jd - 2451545.0) / 36525.0;
  const L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
  const M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T;
  const Mr = M * Math.PI / 180;
  const C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * Math.sin(Mr)
    + (0.019993 - 0.000101 * T) * Math.sin(2 * Mr)
    + 0.000289 * Math.sin(3 * Mr);
  const trueLon = L0 + C;
  const omega = 125.04 - 1934.136 * T;
  const appLon = trueLon - 0.00569 - 0.00478 * Math.sin(omega * Math.PI / 180);
  return ((appLon % 360) + 360) % 360;
}

function unwrap(deg) {
  return ((deg + 540) % 360) - 180;
}

function approxTermJD(year, idx) {
  const offDate = new Date((31556925974.7 * (year - 1900) + sTermInfo[idx] * 60000 + Date.UTC(1900, 0, 6, 2, 5)));
  const day = offDate.getUTCDate();
  const month = Math.floor(idx / 2) + 1;
  return julianDay(year, month, day, 12);
}

function termJD(idx, year) {
  const t = SOLAR_LON[idx];
  const approx = approxTermJD(year, idx);
  let lo = approx - 5, hi = approx + 5;
  for (let i = 0; i < 90; i++) {
    const mid = (lo + hi) / 2;
    if (unwrap(sunApparentLon(mid) - t) > 0) hi = mid; else lo = mid;
  }
  return (lo + hi) / 2;
}

function jdToBeijingDate(jd) {
  const ms = (jd - 2440587.5) * 86400000 + 8 * 3600000; // 北京时间 UTC+8
  const d = new Date(ms);
  return { month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

// 返回当前时刻当令的节气与日期
function currentSolarTerm() {
  const now = new Date();
  const y = now.getFullYear();
  let best = null;
  for (let idx = 0; idx < 24; idx++) {
    const { month, day } = jdToBeijingDate(termJD(idx, y));
    const candidate = new Date(y, month - 1, day);
    if (candidate <= now) {
      best = { index: idx, name: SOLAR_TERM_NAMES[idx], month, day };
    }
  }
  return best;
}

// 节气对应当令之山索引映射
const SOLAR_TO_MT = {};
MOUNTAINS_DATA.forEach((m, i) => {
  SOLAR_TO_MT[m.solar] = i;
});

function getTodayMountainInfo() {
  const ct = currentSolarTerm();
  if (ct && SOLAR_TO_MT[ct.name] !== undefined) {
    const mountainIndex = SOLAR_TO_MT[ct.name];
    const mountain = MOUNTAINS_DATA[mountainIndex];
    return {
      month: ct.month,
      day: ct.day,
      solarName: ct.name,
      mountainIndex,
      mountainName: mountain.name,
      mountain
    };
  }
  return null;
}

module.exports = {
  SOLAR_TERM_NAMES,
  SOLAR_LON,
  termJD,
  jdToBeijingDate,
  currentSolarTerm,
  getTodayMountainInfo
};

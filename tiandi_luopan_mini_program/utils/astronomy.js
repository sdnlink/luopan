/**
 * astronomy.js
 * 真太阳时（Spencer 日行均时差方程）与四柱八字干支历
 * 算法与 Android 版 yiijing_map.html 完全对齐
 */

const { termJD, jdToBeijingDate, currentSolarTerm } = require('./solar-terms');

const TIAN_GAN = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const DI_ZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

function pad2(n) {
  return String(n).padStart(2, '0');
}

/**
 * 真太阳时推算：经度时差 + Spencer(1971) 均时差方程
 * @param {number} longitude 观测点经度（东经为正）
 * @param {Date} date 北京时间
 * @returns {{solarMinutes:number, solarDeg:number, timeStr:string, deltaDesc:string, solarH:number, solarM:number}}
 */
function calculateTrueSolarTime(longitude, date) {
  const now = date || new Date();
  const startOfYear = new Date(now.getFullYear(), 0, 0);
  const diff = now - startOfYear;
  const oneDay = 1000 * 60 * 60 * 24;
  const dayOfYear = Math.floor(diff / oneDay); // N (1..366)

  // 儒略日黄道角（日行角弧度 Γ）
  const gamma = 2 * Math.PI * (dayOfYear - 1) / 365;

  // Spencer 方程推算均时差（Equation of Time，单位：分钟）
  const eotMinutes = 229.18 * (
    0.000075
    + 0.001868 * Math.cos(gamma)
    - 0.032077 * Math.sin(gamma)
    - 0.014615 * Math.cos(2 * gamma)
    - 0.040849 * Math.sin(2 * gamma)
  );

  // 经度时差：每度经度相差 4 分钟（以东经 120° 北京时间标准子午线为基准）
  const lon = (longitude !== undefined && longitude !== null && !isNaN(longitude) && longitude !== 0)
    ? longitude
    : 120.0;
  const lonOffsetMinutes = (lon - 120.0) * 4;

  const stdMinutes = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;
  let solarMinutes = stdMinutes + lonOffsetMinutes + eotMinutes;
  solarMinutes = ((solarMinutes % 1440) + 1440) % 1440;

  const solarH = Math.floor(solarMinutes / 60);
  const solarM = Math.floor(solarMinutes % 60);
  const solarS = Math.floor((solarMinutes * 60) % 60);
  const timeStr = `${pad2(solarH)}:${pad2(solarM)}:${pad2(solarS)}`;

  // 罗盘角度：12时=0°(正南)，0时=180°(正北)，每小时 15°
  const solarDeg = ((solarH - 12 + 24) % 24) * 15 + solarM * 0.25 + (solarS / 60) * 0.25;

  const totalDelta = lonOffsetMinutes + eotMinutes;
  const deltaSign = totalDelta >= 0 ? '+' : '';
  const deltaDesc = `(经度${lon.toFixed(1)}° · 时差${deltaSign}${totalDelta.toFixed(1)}分)`;

  return { solarMinutes, solarDeg, timeStr, deltaDesc, solarH, solarM };
}

/**
 * 四柱八字干支历
 * 年柱以立春定气交节为界；月柱以节气「节」为界；日柱以儒略日连续推算；时柱按五鼠遁（真太阳时）
 * @param {Date} date
 * @param {number} longitude 用于时柱的真太阳时经度修正
 */
function calculateFourPillars(date, longitude) {
  const d = date || new Date();
  const y = d.getFullYear();
  const m = d.getMonth() + 1;
  const day = d.getDate();

  // 1. 年柱：以立春为界
  const lichunJD = termJD(2, y); // 立春
  const lichunDate = jdToBeijingDate(lichunJD);
  const isBeforeLichun = (m < lichunDate.month) || (m === lichunDate.month && day < lichunDate.day);
  const ganYear = isBeforeLichun ? y - 1 : y;
  let yearOffset = (ganYear - 1984) % 60;
  if (yearOffset < 0) yearOffset += 60;
  const yearGan = TIAN_GAN[yearOffset % 10];
  const yearZhi = DI_ZHI[yearOffset % 12];
  const yearPillar = `${yearGan}${yearZhi}年`;

  // 2. 月柱：以节气为界，年上起月五虎遁
  const tigerStems = { '甲': 2, '己': 2, '乙': 4, '庚': 4, '丙': 6, '辛': 6, '丁': 8, '壬': 8, '戊': 0, '癸': 0 };
  const currentTerm = currentSolarTerm();
  const termIdx = currentTerm ? currentTerm.index : 0;
  let monthZhiIdx = Math.floor(termIdx / 2) + 1;
  monthZhiIdx = (monthZhiIdx + 12) % 12;
  const baseStem = tigerStems[yearGan] || 0;
  const monthOffsetFromYin = (monthZhiIdx - 2 + 12) % 12;
  const monthGan = TIAN_GAN[(baseStem + monthOffsetFromYin) % 10];
  const monthZhi = DI_ZHI[monthZhiIdx];
  const monthPillar = `${monthGan}${monthZhi}月`;

  // 3. 日柱：2000-01-01 为戊午日（六十甲子索引 54）
  const msPerDay = 86400000;
  const refDate = Date.UTC(2000, 0, 1);
  const curDate = Date.UTC(y, m - 1, day);
  const dayDiff = Math.floor((curDate - refDate) / msPerDay);
  const dayJiaziIdx = ((54 + dayDiff) % 60 + 60) % 60;
  const dayGan = TIAN_GAN[dayJiaziIdx % 10];
  const dayZhi = DI_ZHI[dayJiaziIdx % 12];
  const dayPillar = `${dayGan}${dayZhi}日`;

  // 4. 时柱：日上起时五鼠遁，时辰按真太阳时判定
  const ratStems = { '甲': 0, '己': 0, '乙': 2, '庚': 2, '丙': 4, '辛': 4, '丁': 6, '壬': 6, '戊': 8, '癸': 8 };
  const solar = calculateTrueSolarTime(longitude, d);
  const zhiIdx = Math.floor((solar.solarH + 1) / 2) % 12;
  const baseHourStem = ratStems[dayGan] || 0;
  const hourGan = TIAN_GAN[(baseHourStem + zhiIdx) % 10];
  const hourZhi = DI_ZHI[zhiIdx];
  const shichenName = DI_ZHI[zhiIdx] + '时';
  const hourPillar = `${hourGan}${hourZhi}时`;

  return {
    fullStr: `${yearPillar} ${monthPillar} ${dayPillar} ${hourPillar} (${shichenName})`,
    yearPillar, monthPillar, dayPillar, hourPillar, shichenName
  };
}

module.exports = {
  TIAN_GAN,
  DI_ZHI,
  calculateTrueSolarTime,
  calculateFourPillars
};

/**
 * fengshui.js
 * 风水立向核心数据与算法：坐向双标、空亡诊断、一百二十分金吉凶
 * 算法与 Android 版 yiijing_map.html 完全对齐
 */

// 六十甲子（一百二十分金由两个完整六十甲子循环组成，每山管 5 位共 15°，每位 3°）
const JIAZI_60 = [
  '甲子', '乙丑', '丙寅', '丁卯', '戊辰', '己巳', '庚午', '辛未', '壬申', '癸酉',
  '甲戌', '乙亥', '丙子', '丁丑', '戊寅', '己卯', '庚辰', '辛巳', '壬午', '癸未',
  '甲申', '乙酉', '丙戌', '丁亥', '戊子', '己丑', '庚寅', '辛卯', '壬辰', '癸巳',
  '甲午', '乙未', '丙申', '丁酉', '戊戌', '己亥', '庚子', '辛丑', '壬寅', '癸卯',
  '甲辰', '乙巳', '丙午', '丁未', '戊申', '己酉', '庚戌', '辛亥', '壬子', '癸丑',
  '甲寅', '乙卯', '丙辰', '丁巳', '戊午', '己未', '庚申', '辛酉', '壬戌', '癸亥'
];

// 二十四山按地理方位角（0°=正北，顺时针）排列的中心线
const MT_AZIMUTH_CENTERS = [
  { name: '子', center: 0, palace: '坎', elem: '水' },
  { name: '癸', center: 15, palace: '坎', elem: '水' },
  { name: '丑', center: 30, palace: '艮', elem: '土' },
  { name: '艮', center: 45, palace: '艮', elem: '土' },
  { name: '寅', center: 60, palace: '艮', elem: '木' },
  { name: '甲', center: 75, palace: '震', elem: '木' },
  { name: '卯', center: 90, palace: '震', elem: '木' },
  { name: '乙', center: 105, palace: '震', elem: '木' },
  { name: '辰', center: 120, palace: '巽', elem: '土' },
  { name: '巽', center: 135, palace: '巽', elem: '木' },
  { name: '巳', center: 150, palace: '巽', elem: '火' },
  { name: '丙', center: 165, palace: '离', elem: '火' },
  { name: '午', center: 180, palace: '离', elem: '火' },
  { name: '丁', center: 195, palace: '离', elem: '火' },
  { name: '未', center: 210, palace: '坤', elem: '土' },
  { name: '坤', center: 225, palace: '坤', elem: '土' },
  { name: '申', center: 240, palace: '坤', elem: '金' },
  { name: '庚', center: 255, palace: '兑', elem: '金' },
  { name: '酉', center: 270, palace: '兑', elem: '金' },
  { name: '辛', center: 285, palace: '兑', elem: '金' },
  { name: '戌', center: 300, palace: '乾', elem: '土' },
  { name: '乾', center: 315, palace: '乾', elem: '金' },
  { name: '亥', center: 330, palace: '乾', elem: '水' },
  { name: '壬', center: 345, palace: '坎', elem: '水' }
];

const DIR_NAMES = ['正北', '东北', '正东', '东南', '正南', '西南', '正西', '西北'];

/**
 * 地理方位名（北=0°，顺时针）
 */
function geoDirName(geo) {
  return DIR_NAMES[Math.round(geo / 45) % 8];
}

/**
 * 坐向双标与空亡 / 兼向全景诊断
 * @param {number} heading 地理朝向（0°=正北，顺时针）
 */
function getSitAndFaceDiagnosis(heading) {
  const h = ((heading % 360) + 360) % 360;
  const sitHeading = (h + 180) % 360;

  function findMountain(deg) {
    const norm = (deg + 7.5) % 360;
    const idx = Math.floor(norm / 15);
    const mt = MT_AZIMUTH_CENTERS[idx];
    let diff = deg - mt.center;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return { mt, diff, idx };
  }

  const faceRes = findMountain(h);
  const sitRes = findMountain(sitHeading);
  const faceMt = faceRes.mt;
  const sitMt = sitRes.mt;
  const dev = faceRes.diff;
  const absDev = Math.abs(dev);

  let statusType = 'pure';
  let statusText = '正针纯清';
  let badgeClass = 'pure';
  let sitFacePattern = `坐${sitMt.name}向${faceMt.name}`;

  if (absDev <= 3.0) {
    statusType = 'pure';
    statusText = `正针纯清 (${absDev < 0.3 ? '正中线' : `偏${dev > 0 ? '右' : '左'}${absDev.toFixed(1)}°`})`;
    badgeClass = 'pure';
    sitFacePattern += ' · 正针';
  } else if (absDev < 6.0) {
    statusType = 'jian';
    badgeClass = 'jian';
    const nextIdx = dev > 0 ? (faceRes.idx + 1) % 24 : (faceRes.idx - 1 + 24) % 24;
    const nextMt = MT_AZIMUTH_CENTERS[nextIdx];
    const nextSitIdx = dev > 0 ? (sitRes.idx + 1) % 24 : (sitRes.idx - 1 + 24) % 24;
    const nextSitMt = MT_AZIMUTH_CENTERS[nextSitIdx];
    statusText = `兼向 (${faceMt.name}兼${nextMt.name} ${absDev.toFixed(1)}°)`;
    sitFacePattern += ` 兼 ${nextSitMt.name}${nextMt.name}`;
  } else {
    const nextIdx = dev > 0 ? (faceRes.idx + 1) % 24 : (faceRes.idx - 1 + 24) % 24;
    const nextMt = MT_AZIMUTH_CENTERS[nextIdx];
    if (nextMt.palace !== faceMt.palace) {
      statusType = 'big_kw';
      statusText = `出卦大空亡 ⛔ (${faceMt.name}/${nextMt.name}两宫缝)`;
      badgeClass = 'big_kw';
      sitFacePattern += ' · 出卦空亡';
    } else {
      statusType = 'small_kw';
      statusText = `小空亡 ⚠️ (${faceMt.name}/${nextMt.name}同宫缝)`;
      badgeClass = 'small_kw';
      sitFacePattern += ' · 差错空亡';
    }
  }

  return {
    faceMt: faceMt.name,
    sitMt: sitMt.name,
    // 向方 / 坐方所属八宫 key（如 '坎'），供居家风水详解取用
    facePalace: faceMt.palace,
    sitPalace: sitMt.palace,
    sitFacePattern,
    statusType,
    statusText,
    badgeClass,
    dev
  };
}

/**
 * 一百二十分金定位与吉凶分析
 * @param {number} heading 地理朝向（0°=正北）
 */
function getFenjinAnalysis(heading) {
  const h = ((heading % 360) + 360) % 360;
  const relAz = (h - 352.5 + 720) % 360;
  const fenjinIdx = Math.floor(relAz / 3) % 120;
  const fenjinName = JIAZI_60[fenjinIdx % 60];
  const stem = fenjinName[0];

  let type = '孤虚';
  let isJewel = false;
  let badgeColor = '#9a9daa';

  if (stem === '丙' || stem === '丁' || stem === '庚' || stem === '辛') {
    type = '旺相珠宝 (吉)';
    isJewel = true;
    badgeColor = '#2ecc71';
  } else if (stem === '戊' || stem === '己') {
    type = '龟甲火坑 (凶)';
    badgeColor = '#ff5252';
  } else if (stem === '甲' || stem === '乙') {
    type = '孤度 (不利)';
    badgeColor = '#e67e22';
  } else {
    type = '虚度 (不利)';
    badgeColor = '#3498db';
  }

  // 该分金所占度数范围
  const startDeg = (352.5 + fenjinIdx * 3) % 360;
  const endDeg = (startDeg + 3) % 360;

  return {
    fenjinIdx,
    name: fenjinName,
    stem,
    type,
    isJewel,
    badgeColor,
    startDeg,
    endDeg,
    displayStr: `${fenjinName}分金 (${type})`
  };
}

module.exports = {
  JIAZI_60,
  MT_AZIMUTH_CENTERS,
  DIR_NAMES,
  geoDirName,
  getSitAndFaceDiagnosis,
  getFenjinAnalysis
};

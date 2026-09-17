/**
 * compass-data.js
 * 易经罗盘二十四山、六十四卦圆图、八宫八卦及五行配置
 */

// 二十四山数据（传统罗盘：0°为正南午山，顺时针排列）
const MOUNTAINS_DATA = [
  // 正南离宫 午为正南0°
  { name: '丙', elem: '火', post: '离', postSym: '☲', pre: '乾', preSym: '☰', solar: '芒种', gua: '乾为天䷀', lines: [1, 1, 1, 1, 1, 1], deg: 345 },
  { name: '午', elem: '火', post: '离', postSym: '☲', pre: '乾', preSym: '☰', solar: '夏至', gua: '天风姤䷫', lines: [0, 1, 1, 1, 1, 1], deg: 0 },
  { name: '丁', elem: '火', post: '离', postSym: '☲', pre: '乾', preSym: '☰', solar: '小暑', gua: '天风姤䷫', lines: [0, 1, 1, 1, 1, 1], deg: 15 },
  // 西南坤宫
  { name: '未', elem: '土', post: '坤', postSym: '☷', pre: '巽', preSym: '☴', solar: '大暑', gua: '天山遁䷠', lines: [0, 0, 1, 1, 1, 1], deg: 30 },
  { name: '坤', elem: '土', post: '坤', postSym: '☷', pre: '巽', preSym: '☴', solar: '立秋', gua: '天山遁䷠', lines: [0, 0, 1, 1, 1, 1], deg: 45 },
  { name: '申', elem: '金', post: '坤', postSym: '☷', pre: '巽', preSym: '☴', solar: '处暑', gua: '天地否䷋', lines: [0, 0, 0, 1, 1, 1], deg: 60 },
  // 正西兑宫
  { name: '庚', elem: '金', post: '兑', postSym: '☱', pre: '坎', preSym: '☵', solar: '白露', gua: '天地否䷋', lines: [0, 0, 0, 1, 1, 1], deg: 75 },
  { name: '酉', elem: '金', post: '兑', postSym: '☱', pre: '坎', preSym: '☵', solar: '秋分', gua: '风地观䷓', lines: [0, 0, 0, 0, 1, 1], deg: 90 },
  { name: '辛', elem: '金', post: '兑', postSym: '☱', pre: '坎', preSym: '☵', solar: '寒露', gua: '风地观䷓', lines: [0, 0, 0, 0, 1, 1], deg: 105 },
  // 西北乾宫
  { name: '戌', elem: '土', post: '乾', postSym: '☰', pre: '艮', preSym: '☶', solar: '霜降', gua: '山地剥䷖', lines: [0, 0, 0, 0, 0, 1], deg: 120 },
  { name: '乾', elem: '金', post: '乾', postSym: '☰', pre: '艮', preSym: '☶', solar: '立冬', gua: '山地剥䷖', lines: [0, 0, 0, 0, 0, 1], deg: 135 },
  { name: '亥', elem: '水', post: '乾', postSym: '☰', pre: '艮', preSym: '☶', solar: '小雪', gua: '坤为地䷁', lines: [0, 0, 0, 0, 0, 0], deg: 150 },
  // 正北坎宫
  { name: '壬', elem: '水', post: '坎', postSym: '☵', pre: '坤', preSym: '☷', solar: '大雪', gua: '坤为地䷁', lines: [0, 0, 0, 0, 0, 0], deg: 165 },
  { name: '子', elem: '水', post: '坎', postSym: '☵', pre: '坤', preSym: '☷', solar: '冬至', gua: '地雷复䷗', lines: [1, 0, 0, 0, 0, 0], deg: 180 },
  { name: '癸', elem: '水', post: '坎', postSym: '☵', pre: '坤', preSym: '☷', solar: '小寒', gua: '地雷复䷗', lines: [1, 0, 0, 0, 0, 0], deg: 195 },
  // 东北艮宫
  { name: '丑', elem: '土', post: '艮', postSym: '☶', pre: '震', preSym: '☳', solar: '大寒', gua: '地泽临䷒', lines: [1, 1, 0, 0, 0, 0], deg: 210 },
  { name: '艮', elem: '土', post: '艮', postSym: '☶', pre: '震', preSym: '☳', solar: '立春', gua: '地泽临䷒', lines: [1, 1, 0, 0, 0, 0], deg: 225 },
  { name: '寅', elem: '木', post: '艮', postSym: '☶', pre: '震', preSym: '☳', solar: '雨水', gua: '地天泰䷊', lines: [1, 1, 1, 0, 0, 0], deg: 240 },
  // 正东震宫
  { name: '甲', elem: '木', post: '震', postSym: '☳', pre: '离', preSym: '☲', solar: '惊蛰', gua: '地天泰䷊', lines: [1, 1, 1, 0, 0, 0], deg: 255 },
  { name: '卯', elem: '木', post: '震', postSym: '☳', pre: '离', preSym: '☲', solar: '春分', gua: '雷天大壮䷡', lines: [1, 1, 1, 1, 0, 0], deg: 270 },
  { name: '乙', elem: '木', post: '震', postSym: '☳', pre: '离', preSym: '☲', solar: '清明', gua: '雷天大壮䷡', lines: [1, 1, 1, 1, 0, 0], deg: 285 },
  // 东南巽宫
  { name: '辰', elem: '土', post: '巽', postSym: '☴', pre: '兑', preSym: '☱', solar: '谷雨', gua: '泽天夬䷪', lines: [1, 1, 1, 1, 1, 0], deg: 300 },
  { name: '巽', elem: '木', post: '巽', postSym: '☴', pre: '兑', preSym: '☱', solar: '立夏', gua: '泽天夬䷪', lines: [1, 1, 1, 1, 1, 0], deg: 315 },
  { name: '巳', elem: '火', post: '巽', postSym: '☴', pre: '兑', preSym: '☱', solar: '小满', gua: '乾为天䷀', lines: [1, 1, 1, 1, 1, 1], deg: 330 }
];

// 后天八卦八宫（0°=南，顺时针；每宫45°，各辖3山）
// key 用于索引居家风水详解库；fengshuiYi/Ji 为盘面宜忌指示环的显示文本
const PALACES_POST = [
  { name: '离宫', label: '正南', symbol: '☲', elem: '火', baseDeg: 0, key: '离', fengshuiRole: '名望·中女', fengshuiYi: '采光明堂', fengshuiJi: '水浸昏暗' },
  { name: '坤宫', label: '西南', symbol: '☷', elem: '土', baseDeg: 45, key: '坤', fengshuiRole: '田宅·女主', fengshuiYi: '主卧田宅', fengshuiJi: '脏污下水' },
  { name: '兑宫', label: '正西', symbol: '☱', elem: '金', baseDeg: 90, key: '兑', fengshuiRole: '财源·少女', fengshuiYi: '会客聚气', fengshuiJi: '火克开裂' },
  { name: '乾宫', label: '西北', symbol: '☰', elem: '金', baseDeg: 135, key: '乾', fengshuiRole: '天门·男主', fengshuiYi: '主房尊位', fengshuiJi: '火烧天门' },
  { name: '坎宫', label: '正北', symbol: '☵', elem: '水', baseDeg: 180, key: '坎', fengshuiRole: '坎水·中男', fengshuiYi: '书房静卧', fengshuiJi: '污厕缺角' },
  { name: '艮宫', label: '东北', symbol: '☶', elem: '土', baseDeg: 225, key: '艮', fengshuiRole: '靠山·少男', fengshuiYi: '儿房静稳', fengshuiJi: '鬼门卫浴' },
  { name: '震宫', label: '正东', symbol: '☳', elem: '木', baseDeg: 270, key: '震', fengshuiRole: '生机·长男', fengshuiYi: '客厅生机', fengshuiJi: '重金冲煞' },
  { name: '巽宫', label: '东南', symbol: '☴', elem: '木', baseDeg: 315, key: '巽', fengshuiRole: '文昌·名利', fengshuiYi: '文昌书房', fengshuiJi: '落厕阴湿' }
];

// 先天八卦八宫（伏羲方位：乾南、坤北、离东、坎西、震东北、巽西南、艮西北、兑东南）
const PALACES_PRE = [
  { name: '乾宫', label: '正南', symbol: '☰', elem: '金', baseDeg: 0, key: '乾', fengshuiRole: '天象·至尊', fengshuiYi: '崇高明朗', fengshuiJi: '晦暗压顶' },
  { name: '巽宫', label: '西南', symbol: '☴', elem: '木', baseDeg: 45, key: '巽', fengshuiRole: '清风·温和', fengshuiYi: '通透整洁', fengshuiJi: '杂物堆积' },
  { name: '坎宫', label: '正西', symbol: '☵', elem: '水', baseDeg: 90, key: '坎', fengshuiRole: '润下·深邃', fengshuiYi: '水木清华', fengshuiJi: '污秽滞留' },
  { name: '艮宫', label: '西北', symbol: '☶', elem: '土', baseDeg: 135, key: '艮', fengshuiRole: '笃实·止息', fengshuiYi: '厚重安宁', fengshuiJi: '动摇破耗' },
  { name: '坤宫', label: '正北', symbol: '☷', elem: '土', baseDeg: 180, key: '坤', fengshuiRole: '坤厚·藏纳', fengshuiYi: '方正敦厚', fengshuiJi: '虚浮空洞' },
  { name: '震宫', label: '东北', symbol: '☳', elem: '木', baseDeg: 225, key: '震', fengshuiRole: '雷动·启行', fengshuiYi: '朝气生机', fengshuiJi: '闭塞死寂' },
  { name: '离宫', label: '正东', symbol: '☲', elem: '火', baseDeg: 270, key: '离', fengshuiRole: '明丽·显耀', fengshuiYi: '光彩夺目', fengshuiJi: '阴湿掩蔽' },
  { name: '兑宫', label: '东南', symbol: '☱', elem: '金', baseDeg: 315, key: '兑', fengshuiRole: '和悦·通达', fengshuiYi: '欢聚喜庆', fengshuiJi: '尖利冲撞' }
];

// 先天六十四卦圆图（乾南0°起，顺时针；每卦5.625°，坤在正北180°）
const HEXAGRAMS_64 = [
  { n: '乾为天', s: '䷀', l: [1, 1, 1, 1, 1, 1] }, { n: '天风姤', s: '䷫', l: [0, 1, 1, 1, 1, 1] },
  { n: '泽风大过', s: '䷛', l: [0, 1, 1, 1, 1, 0] }, { n: '火风鼎', s: '䷱', l: [0, 1, 1, 1, 0, 1] },
  { n: '雷风恒', s: '䷟', l: [0, 1, 1, 0, 0, 1] }, { n: '巽为风', s: '䷸', l: [0, 1, 1, 0, 1, 1] },
  { n: '水风井', s: '䷯', l: [0, 1, 1, 0, 1, 0] }, { n: '山风蛊', s: '䷑', l: [0, 1, 1, 1, 0, 0] },
  { n: '地风升', s: '䷭', l: [0, 1, 1, 0, 0, 0] }, { n: '天水讼', s: '䷅', l: [0, 1, 0, 1, 1, 1] },
  { n: '泽水困', s: '䷮', l: [0, 1, 0, 1, 1, 0] }, { n: '火水未济', s: '䷿', l: [0, 1, 0, 1, 0, 1] },
  { n: '雷水解', s: '䷧', l: [0, 1, 0, 0, 0, 1] }, { n: '风水涣', s: '䷺', l: [0, 1, 0, 0, 1, 1] },
  { n: '坎为水', s: '䷜', l: [0, 1, 0, 0, 1, 0] }, { n: '山水蒙', s: '䷃', l: [0, 1, 0, 1, 0, 0] },
  { n: '地水师', s: '䷆', l: [0, 1, 0, 0, 0, 0] }, { n: '天山遁', s: '䷠', l: [0, 0, 1, 1, 1, 1] },
  { n: '泽山咸', s: '䷞', l: [0, 0, 1, 1, 1, 0] }, { n: '火山旅', s: '䷷', l: [0, 0, 1, 1, 0, 1] },
  { n: '雷山小过', s: '䷽', l: [0, 0, 1, 0, 0, 1] }, { n: '风山渐', s: '䷴', l: [0, 0, 1, 0, 1, 1] },
  { n: '水山蹇', s: '䷦', l: [0, 0, 1, 0, 1, 0] }, { n: '艮为山', s: '䷳', l: [0, 0, 1, 1, 0, 0] },
  { n: '地山谦', s: '䷎', l: [0, 0, 1, 0, 0, 0] }, { n: '天地否', s: '䷋', l: [0, 0, 0, 1, 1, 1] },
  { n: '泽地萃', s: '䷬', l: [0, 0, 0, 1, 1, 0] }, { n: '火地晋', s: '䷢', l: [0, 0, 0, 1, 0, 1] },
  { n: '雷地豫', s: '䷏', l: [0, 0, 0, 0, 0, 1] }, { n: '风地观', s: '䷓', l: [0, 0, 0, 0, 1, 1] },
  { n: '水地比', s: '䷇', l: [0, 0, 0, 0, 1, 0] }, { n: '山地剥', s: '䷖', l: [0, 0, 0, 1, 0, 0] },
  { n: '坤为地', s: '䷁', l: [0, 0, 0, 0, 0, 0] }, { n: '地雷复', s: '䷗', l: [1, 0, 0, 0, 0, 0] },
  { n: '山雷颐', s: '䷚', l: [1, 0, 0, 1, 0, 0] }, { n: '水雷屯', s: '䷂', l: [1, 0, 0, 0, 1, 0] },
  { n: '风雷益', s: '䷩', l: [1, 0, 0, 0, 1, 1] }, { n: '震为雷', s: '䷲', l: [1, 0, 0, 0, 0, 1] },
  { n: '火雷噬嗑', s: '䷔', l: [1, 0, 0, 1, 0, 1] }, { n: '泽雷随', s: '䷐', l: [1, 0, 0, 1, 1, 0] },
  { n: '天雷无妄', s: '䷘', l: [1, 0, 0, 1, 1, 1] }, { n: '地火明夷', s: '䷣', l: [1, 0, 1, 0, 0, 0] },
  { n: '山火贲', s: '䷕', l: [1, 0, 1, 1, 0, 0] }, { n: '水火既济', s: '䷾', l: [1, 0, 1, 0, 1, 0] },
  { n: '风火家人', s: '䷤', l: [1, 0, 1, 0, 1, 1] }, { n: '雷火丰', s: '䷶', l: [1, 0, 1, 0, 0, 1] },
  { n: '离为火', s: '䷝', l: [1, 0, 1, 1, 0, 1] }, { n: '泽火革', s: '䷰', l: [1, 0, 1, 1, 1, 0] },
  { n: '天火同人', s: '䷌', l: [1, 0, 1, 1, 1, 1] }, { n: '地泽临', s: '䷒', l: [1, 1, 0, 0, 0, 0] },
  { n: '山泽损', s: '䷨', l: [1, 1, 0, 1, 0, 0] }, { n: '水泽节', s: '䷻', l: [1, 1, 0, 0, 1, 0] },
  { n: '风泽中孚', s: '䷼', l: [1, 1, 0, 0, 1, 1] }, { n: '雷泽归妹', s: '䷵', l: [1, 1, 0, 0, 0, 1] },
  { n: '火泽睽', s: '䷥', l: [1, 1, 0, 1, 0, 1] }, { n: '兑为泽', s: '䷹', l: [1, 1, 0, 1, 1, 0] },
  { n: '天泽履', s: '䷉', l: [1, 1, 0, 1, 1, 1] }, { n: '地天泰', s: '䷊', l: [1, 1, 1, 0, 0, 0] },
  { n: '山天大畜', s: '䷙', l: [1, 1, 1, 1, 0, 0] }, { n: '水天需', s: '䷄', l: [1, 1, 1, 0, 1, 0] },
  { n: '风天小畜', s: '䷈', l: [1, 1, 1, 0, 1, 1] }, { n: '雷天大壮', s: '䷡', l: [1, 1, 1, 0, 0, 1] },
  { n: '火天大有', s: '䷍', l: [1, 1, 1, 1, 0, 1] }, { n: '泽天夬', s: '䷪', l: [1, 1, 1, 1, 1, 0] }
];

const GUA64_STEP = 360 / 64; // 5.625°
const GUA64_HALF = GUA64_STEP / 2; // 2.8125°

// 五行配色表
const ELEM_COLORS = {
  '水': '#4a90e2', // 水 (黑蓝)
  '木': '#2ecc71', // 木 (青绿)
  '火': '#e74c3c', // 火 (赤红)
  '土': '#f5a623', // 土 (黄褐)
  '金': '#e0e0e0'  // 金 (白银)
};

const ELEM_BG = {
  '水': 'rgba(74, 144, 226, 0.12)',
  '木': 'rgba(46, 204, 113, 0.12)',
  '火': 'rgba(231, 76, 60, 0.12)',
  '土': 'rgba(245, 166, 35, 0.12)',
  '金': 'rgba(224, 224, 224, 0.10)'
};

// 五行扇区暗色底（罗盘环带填充色，与 Android 版 ELEM_COLORS 完全一致）
const ELEM_BG_DARK = {
  '水': '#1b3b5a',
  '木': '#1a4a3a',
  '火': '#5c2424',
  '土': '#534321',
  '金': '#404552'
};

module.exports = {
  MOUNTAINS_DATA,
  PALACES_POST,
  PALACES_PRE,
  HEXAGRAMS_64,
  GUA64_STEP,
  GUA64_HALF,
  ELEM_COLORS,
  ELEM_BG,
  ELEM_BG_DARK
};

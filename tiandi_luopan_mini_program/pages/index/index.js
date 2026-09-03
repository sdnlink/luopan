/**
 * pages/index/index.js
 * 演象 · 时空罗盘 微信小程序主逻辑
 */

const {
  MOUNTAINS_DATA,
  PALACES_POST,
  PALACES_PRE,
  HEXAGRAMS_64,
  GUA64_STEP,
  GUA64_HALF,
  ELEM_COLORS,
  ELEM_BG,
  ELEM_BG_DARK
} = require('../../utils/compass-data');

const { getTodayMountainInfo, currentSolarTerm } = require('../../utils/solar-terms');
const { computeDeclination, formatLocationAndDeclination } = require('../../utils/geomagnetic');

Page({
  data: {
    currentMode: 'post', // 'post'=后天八卦, 'pre'=先天八卦
    currentMountain: MOUNTAINS_DATA[13], // 默认子山 (13)
    currentPalaceName: '坎宫',
    geoDirStr: '正北',
    elemColor: ELEM_COLORS['水'],
    headingDescMag: '正北 0° · 子山',
    headingDescTrue: '正北 0°',
    declSummary: '无偏',
    declinationDetailStr: '正在获取GPS定位…',
    coordsDisplayStr: '正在获取GPS定位…',
    todayLine: '',
    nowTime: '00:00',
    showCalibModal: false,
    calibAccuracyText: '✓ 极高 (已自动校准)',
    calibAccClass: '',
    calibClass: ''
  },

  // 内部绘图与传感器状态
  canvas: null,
  ctx: null,
  dpr: 1,
  canvasW: 450,
  canvasH: 450,
  currentHeading: 0,
  targetHeading: 0,
  isAnimating: false,
  currentDeclination: 0,
  hasDeclination: false,
  currentLatitude: 0,
  currentLongitude: 0,
  currentAltitude: 0,
  hasAltitude: false,
  currentIndex: -1, // 今日当令之山索引
  hoveredIndex: 13, // 当前选中山向索引
  clockTimer: null,
  isCompassRunning: false,

  onLoad() {
    this.initTodayInfo();
    this.startClockTimer();
    this.initLocation();
  },

  onReady() {
    this.initCanvas();
  },

  onShow() {
    if (!this.isCompassRunning && this.canvas) {
      this.startCompassListener();
    }
  },

  onHide() {
    this.stopCompassListener();
  },

  onUnload() {
    this.stopCompassListener();
    if (this.clockTimer) {
      clearInterval(this.clockTimer);
      this.clockTimer = null;
    }
  },

  /**
   * 初始化今日节气与当令之山
   */
  initTodayInfo() {
    const today = getTodayMountainInfo();
    if (today) {
      this.currentIndex = today.mountainIndex;
      this.hoveredIndex = today.mountainIndex;
      this.setData({
        currentMountain: today.mountain,
        todayLine: `今日 ${today.month}月${today.day}日 · 当令节气「${today.solarName}」· 主应 ${today.mountainName}山`
      });
      this.updateMountainDetails(today.mountainIndex);
    } else {
      this.setData({
        todayLine: '—'
      });
    }
    this.updateClock();
  },

  /**
   * 启动时钟定时器
   */
  startClockTimer() {
    this.updateClock();
    this.clockTimer = setInterval(() => {
      this.updateClock();
    }, 1000);
  },

  updateClock() {
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    const nowTime = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    this.setData({ nowTime });
  },

  /**
   * 初始化微信 GPS 定位与地磁偏角计算
   */
  initLocation() {
    wx.getLocation({
      type: 'wgs84',
      altitude: true,
      success: (res) => {
        const { latitude, longitude, altitude } = res;
        this.currentLatitude = latitude;
        this.currentLongitude = longitude;
        this.currentAltitude = altitude || 0;
        this.hasAltitude = !!(altitude && altitude !== 0);

        // 离线高精度计算地磁偏角
        const decl = computeDeclination(latitude, longitude, this.currentAltitude, new Date());
        this.currentDeclination = decl;
        this.hasDeclination = true;

        const info = formatLocationAndDeclination(latitude, longitude, this.currentAltitude, decl);
        this.setData({
          coordsDisplayStr: info.coordsDesc,
          declinationDetailStr: `${Math.abs(decl).toFixed(1)}° (${info.dirStr})`,
          declSummary: info.declText
        });

        this.updateCompassInfo();
        if (this.ctx) this.drawCompass();
      },
      fail: (err) => {
        console.warn('获取用户位置失败或未授权:', err);
        this.setData({
          coordsDisplayStr: '暂未授权定位 (默认使用磁北)',
          declinationDetailStr: '0° (无偏角 · 默认值)',
          declSummary: '无偏'
        });
      }
    });
  },

  /**
   * 初始化 Canvas 2D 绘图上下文
   */
  initCanvas() {
    const query = wx.createSelectorQuery().in(this);
    query.select('#compassCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          console.error('Canvas node not found!');
          return;
        }
        const canvas = res[0].node;
        const ctx = canvas.getContext('2d');
        const sys = wx.getSystemInfoSync();
        const dpr = Math.min(sys.pixelRatio || 2, 3);

        const width = res[0].width;
        const height = res[0].height;

        canvas.width = width * dpr;
        canvas.height = height * dpr;
        ctx.scale(dpr, dpr);

        this.canvas = canvas;
        this.ctx = ctx;
        this.dpr = dpr;
        this.canvasW = width;
        this.canvasH = height;

        this.drawCompass();
        this.startCompassListener();
      });
  },

  /**
   * 启动指南针高频传感器监听
   */
  startCompassListener() {
    this.isCompassRunning = true;
    wx.startCompass({
      interval: 'game',
      success: () => {
        wx.onCompassChange((res) => {
          if (res.direction !== undefined && !isNaN(res.direction)) {
            this.targetHeading = ((res.direction % 360) + 360) % 360;
            if (!this.isAnimating) {
              this.isAnimating = true;
              this.animateCompassStep();
            }
            if (res.accuracy) {
              this.updateAccuracy(res.accuracy);
            }
          }
        });
      },
      fail: (err) => {
        console.warn('wx.startCompass failed:', err);
      }
    });
  },

  stopCompassListener() {
    this.isCompassRunning = false;
    if (typeof wx.stopCompass === 'function') {
      wx.stopCompass();
    }
    // 必须同时解绑回调：wx.stopCompass 只停硬件，不会移除 onCompassChange 监听，
    // 否则每次 onShow/onHide 都会叠加一个监听器与一条动画帧循环。
    if (typeof wx.offCompassChange === 'function') {
      wx.offCompassChange();
    }
  },

  /**
   * 指南针平滑阻尼物理动画帧
   */
  animateCompassStep() {
    let diff = ((this.targetHeading - this.currentHeading + 540) % 360) - 180;
    if (Math.abs(diff) < 0.05) {
      this.currentHeading = this.targetHeading;
      this.isAnimating = false;
    } else {
      this.currentHeading = (this.currentHeading + diff * 0.25 + 360) % 360;
      if (this.canvas && typeof this.canvas.requestAnimationFrame === 'function') {
        this.canvas.requestAnimationFrame(() => this.animateCompassStep());
      } else {
        setTimeout(() => this.animateCompassStep(), 16);
      }
    }
    this.updateCompassInfo();
    this.drawCompass();
  },

  updateAccuracy(acc) {
    let text = '✓ 极高 (已自动校准)';
    let accClass = '';
    let dotClass = '';
    if (acc === 'medium') {
      text = '⚠️ 精度一般 (建议空中画8字)';
      accClass = 'med';
      dotClass = 'med';
    } else if (acc === 'low' || acc === 'unreliable') {
      text = '⚠️ 需校准 (请空中画8字)';
      accClass = 'low';
      dotClass = 'low';
    }
    this.setData({
      calibAccuracyText: text,
      calibAccClass: accClass,
      calibClass: dotClass
    });
  },

  /**
   * 刷新顶部磁北与真北朝向栏文本
   */
  updateCompassInfo() {
    const heading = this.currentHeading;
    const trueHeading = ((heading + this.currentDeclination) % 360 + 360) % 360;

    const dirs = ['正北', '东北', '正东', '东南', '正南', '西南', '正西', '西北'];
    const dirNameMag = dirs[Math.round(heading / 45) % 8];
    const dirNameTrue = dirs[Math.round(trueHeading / 45) % 8];

    // 真实方位转罗盘角度：罗盘0°=正南，真实0°=正北
    const compassDeg = (heading + 180) % 360;
    let nearest = MOUNTAINS_DATA[13], minDiff = 360;
    for (let i = 0; i < 24; i++) {
      let diff = Math.abs(MOUNTAINS_DATA[i].deg - compassDeg);
      diff = Math.min(diff, 360 - diff);
      if (diff < minDiff) {
        minDiff = diff;
        nearest = MOUNTAINS_DATA[i];
      }
    }

    const declAbs = Math.abs(this.currentDeclination).toFixed(1);
    const declText = this.currentDeclination < 0 ? `偏西${declAbs}°` : (this.currentDeclination > 0 ? `偏东${declAbs}°` : '无偏');

    this.setData({
      headingDescMag: `${dirNameMag} ${heading.toFixed(0)}° · ${nearest.name}山`,
      headingDescTrue: `${dirNameTrue} ${trueHeading.toFixed(0)}°`,
      declSummary: declText
    });
  },

  /**
   * 模式切换：后天八卦 / 先天八卦
   */
  onSwitchMode(e) {
    const mode = e.currentTarget.dataset.mode;
    if (mode && mode !== this.data.currentMode) {
      this.setData({ currentMode: mode });
      this.updateMountainDetails(this.hoveredIndex);
      this.drawCompass();
    }
  },

  /**
   * 选中山向详情更新
   */
  updateMountainDetails(idx) {
    const m = MOUNTAINS_DATA[idx];
    const palaces = this.data.currentMode === 'post' ? PALACES_POST : PALACES_PRE;
    // 寻找山向所属宫位
    let palName = '';
    palaces.forEach(p => {
      let diff = ((m.deg - p.baseDeg + 540) % 360) - 180;
      if (Math.abs(diff) <= 23) {
        palName = p.name;
      }
    });

    const geoDeg = (m.deg + 180) % 360;
    const dirs = ['正北', '东北', '正东', '东南', '正南', '西南', '正西', '西北'];
    const geoDirStr = dirs[Math.round(geoDeg / 45) % 8];

    this.setData({
      currentMountain: m,
      currentPalaceName: palName || (this.data.currentMode === 'post' ? m.post + '宫' : m.pre + '宫'),
      geoDirStr,
      elemColor: ELEM_COLORS[m.elem] || '#ffffff'
    });
  },

  /**
   * 触摸交互拾取山向
   */
  handleTouch(e) {
    if (!e.touches || !e.touches[0]) return;
    const touch = e.touches[0];
    const x = touch.x;
    const y = touch.y;
    const CX = this.canvasW / 2;
    const CY = this.canvasH / 2;

    const dx = x - CX;
    const dy = y - CY;
    const dist = Math.sqrt(dx * dx + dy * dy);

    // 半径范围判定：排除天池太极中心区，其余整个圆形视口均可拾取
    if (dist > 20 && dist <= CX) {
      // 计算角度：相对于顶部 (0°=正南)
      let rad = Math.atan2(dy, dx);
      let deg = (rad * 180 / Math.PI + 90 + 360) % 360;

      let bestIdx = 0;
      let minDiff = 360;
      for (let i = 0; i < 24; i++) {
        let diff = Math.abs(MOUNTAINS_DATA[i].deg - deg);
        diff = Math.min(diff, 360 - diff);
        if (diff < minDiff) {
          minDiff = diff;
          bestIdx = i;
        }
      }

      if (bestIdx !== this.hoveredIndex) {
        this.hoveredIndex = bestIdx;
        this.updateMountainDetails(bestIdx);
        this.drawCompass();
      }
    }
  },

  onTouchStart(e) {
    this.handleTouch(e);
  },

  onTouchMove(e) {
    this.handleTouch(e);
  },

  onTouchEnd() {
    // touch end
  },

  /**
   * 打开校准弹窗（来自顶部朝向胶囊栏）
   * 弹窗本体为用时注入组件，此时才会首次进入渲染树并触发注入
   */
  toggleCalibModal(e) {
    const show = e.currentTarget.dataset.show === 'true' || e.currentTarget.dataset.show === true;
    this.setData({ showCalibModal: show });
  },

  /**
   * 用时注入组件 calib-modal 抛出的关闭事件
   */
  onCalibClose() {
    this.setData({ showCalibModal: false });
  },

  /**
   * 用时注入组件 calib-modal 抛出的「重新定位与校准」事件
   */
  onCalibReset() {
    this.initLocation();
    wx.showToast({
      title: '已重置，请画8字',
      icon: 'none',
      duration: 1500
    });
  },

  deg2rad(d) {
    // 0°=正南(画布顶部)、顺时针
    return (d - 90) * Math.PI / 180;
  },

  /**
   * 绘制六爻卦图（初爻在下）
   * @param {CanvasRenderingContext2D} ctx
   * @param {number[]} lines 六爻数组，1=阳爻、0=阴爻，lines[0] 为初爻
   * @param {number} x 卦图中心横坐标
   * @param {number} y 卦图中心纵坐标
   * @param {number} size 卦图宽度（爻长）
   */
  drawHexagram(ctx, lines, x, y, size) {
    const h = size * 0.12;    // 爻厚
    const w = size;           // 爻长
    const gap = size * 0.08;  // 爻间距
    let py = y + ((lines.length - 1) * (h + gap)) / 2; // 自下而上排布
    for (let i = 0; i < lines.length; i++) {
      ctx.fillStyle = lines[i] === 1 ? '#e74c3c' : '#4a90e2';
      if (lines[i] === 1) {
        ctx.fillRect(x - w / 2, py - h / 2, w, h);
      } else {
        const segW = w * 0.42;
        ctx.fillRect(x - w / 2, py - h / 2, segW, h);
        ctx.fillRect(x + w / 2 - segW, py - h / 2, segW, h);
      }
      py -= h + gap;
    }
  },

  /**
   * 完整罗盘 Canvas 2D 高保真渲染
   */
  drawCompass() {
    const ctx = this.ctx;
    if (!ctx) return;

    const W = this.canvasW;
    const H = this.canvasH;
    const CX = W / 2;
    const CY = H / 2;

    // 清屏并铺底色
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#14151f';
    ctx.fillRect(0, 0, W, H);

    // ============ 环径布局 ============
    // 以 900 为设计尺寸（与 Android 版 yiijing_map.html 完全 1:1），scale 为适配系数。
    // 注意：半径必须 = 设计值 × scale，绝不可再乘 2，否则整圈会被圆形视口裁掉。
    const scale = W / 900;
    const R = {
      s: scale,
      taiji: 42 * scale,
      preGuaRing: 90 * scale,
      postGuaRing: 150 * scale,
      mountainRing: 215 * scale,
      solarRing: 280 * scale,
      hexRing: 350 * scale,
      timeIn: 358 * scale,
      timeOut: 392 * scale,
      gua64In: 398 * scale,
      gua64Out: 440 * scale,
      outerBorder: 444 * scale
    };
    // 字号：Android 设计字号等比缩放，并设定可读性下限
    const FS = {
      palaceSym: Math.max(9, Math.round(18 * scale * 1.4)),
      palace: Math.max(8, Math.round(13 * scale * 1.6)),
      mountain: Math.max(11, Math.round(12 * scale * 1.6)),
      solar: Math.max(9, Math.round(11 * scale * 1.6)),
      hexName: Math.max(7, Math.round(10 * scale * 1.6)),
      timeMinor: Math.max(7, Math.round(9 * scale * 1.6)),
      timeMajor: Math.max(8, Math.round(12 * scale * 1.6)),
      gua64: Math.max(4, Math.round(7 * scale * 1.6)),
      label: Math.max(7, Math.round(8 * scale * 1.6))
    };
    const HEX_W_MT = Math.max(9, Math.round(20 * scale * 1.5)); // 消息卦六爻宽度
    const HEX_W_64 = Math.max(7, Math.round(10 * scale * 1.9)); // 六十四卦六爻宽度

    // 1. 底盘黑金深空圆盘
    ctx.beginPath();
    ctx.arc(CX, CY, R.outerBorder, 0, Math.PI * 2);
    ctx.fillStyle = '#14151e';
    ctx.fill();
    ctx.strokeStyle = '#d4af37';
    ctx.lineWidth = 2;
    ctx.stroke();

    // 2. 先天六十四卦圆图
    this.draw64GuaRing(ctx, CX, CY, R, FS, HEX_W_64);

    // 3. 二十四小时制时间刻度环
    this.drawTimeRing(ctx, CX, CY, R, FS);

    // 4. 十二消息卦 + 六爻外环
    this.drawMessageGuaRing(ctx, CX, CY, R, FS, HEX_W_MT);

    // 5. 二十四节气环
    this.drawSolarRing(ctx, CX, CY, R, FS);

    // 6. 二十四山环
    this.drawMountainRing(ctx, CX, CY, R, FS);

    // 7. 八宫环与八卦符号内环
    this.drawPalaceRing(ctx, CX, CY, R, FS);
    this.drawPalaceSymbolRing(ctx, CX, CY, R, FS);

    // 8. 今日当令之山金弧
    this.drawTodayHighlight(ctx, CX, CY, R);

    // 9. 天池太极图
    this.drawTaiji(ctx, CX, CY, R.taiji);

    // 10. 实时时钟红针
    this.drawClockPointer(ctx, CX, CY, R);

    // 11. 【地磁北（绿）与地理真北（金）双指针系统】
    this.drawDualCompassNeedles(ctx, CX, CY, R, FS);
  },

  drawTaiji(ctx, CX, CY, r) {
    ctx.save();
    ctx.translate(CX, CY);

    // 底圆（黑鱼半圆）
    ctx.beginPath();
    ctx.arc(0, 0, r, -Math.PI / 2, Math.PI / 2);
    ctx.fillStyle = '#111118';
    ctx.fill();

    // 底圆（白鱼半圆）
    ctx.beginPath();
    ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2);
    ctx.fillStyle = '#e8e8ea';
    ctx.fill();

    // 白鱼中圆
    ctx.beginPath();
    ctx.arc(0, -r / 2, r / 2, 0, Math.PI * 2);
    ctx.fillStyle = '#e8e8ea';
    ctx.fill();

    // 黑鱼中圆
    ctx.beginPath();
    ctx.arc(0, r / 2, r / 2, 0, Math.PI * 2);
    ctx.fillStyle = '#111118';
    ctx.fill();

    // 黑鱼眼（白鱼内部小黑眼）
    ctx.beginPath();
    ctx.arc(0, -r / 2, r / 6, 0, Math.PI * 2);
    ctx.fillStyle = '#111118';
    ctx.fill();

    // 白鱼眼（黑鱼内部小白眼）
    ctx.beginPath();
    ctx.arc(0, r / 2, r / 6, 0, Math.PI * 2);
    ctx.fillStyle = '#e8e8ea';
    ctx.fill();

    // 金色外边框
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.strokeStyle = '#d4af37';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.restore();
  },

  /**
   * 先天六十四卦圆图（乾南坤北，每卦 5.625°，含六爻卦图）
   */
  draw64GuaRing(ctx, CX, CY, R, FS, hexW) {
    const rIn = R.gua64In;
    const rOut = R.gua64Out;
    const midR = (rIn + rOut) / 2;
    const hexOff = 8 * R.s;    // 局部 +y 指向圆心，正值 = 向内
    const nameOff = 14 * R.s;  // 负值 = 向外

    // 环底
    ctx.beginPath();
    ctx.arc(CX, CY, rOut, 0, Math.PI * 2);
    ctx.arc(CX, CY, rIn, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fillStyle = '#0e0f16';
    ctx.fill();
    ctx.strokeStyle = '#2d3042';
    ctx.lineWidth = 1;
    ctx.stroke();

    for (let i = 0; i < 64; i++) {
      const g = HEXAGRAMS_64[i];
      const deg = i * GUA64_STEP;
      const sRad = this.deg2rad(deg - GUA64_HALF);
      const eRad = this.deg2rad(deg + GUA64_HALF);
      const isYang = (i === 0 || i >= 33); // 阳仪：乾 + 复至夬

      ctx.beginPath();
      ctx.arc(CX, CY, rOut, sRad, eRad);
      ctx.arc(CX, CY, rIn, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = isYang ? '#161822' : '#101118';
      ctx.fill();
      ctx.strokeStyle = '#2a2c3c';
      ctx.lineWidth = 0.5;
      ctx.stroke();

      const midRad = this.deg2rad(deg);
      ctx.save();
      ctx.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
      ctx.rotate(midRad + Math.PI / 2);
      // 六爻卦图（内侧）
      this.drawHexagram(ctx, g.l, 0, hexOff, hexW);
      // 卦名（外侧）
      ctx.fillStyle = isYang ? '#c8b88a' : '#8a8a9a';
      ctx.font = `${FS.gua64}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(g.n, 0, -nameOff);
      ctx.restore();
    }

    // 八宫分界线（每 8 卦一宫，占 45°）
    for (let k = 1; k <= 8; k++) {
      const rad = this.deg2rad(k * 45 - GUA64_HALF);
      ctx.beginPath();
      ctx.moveTo(CX + Math.cos(rad) * rIn, CY + Math.sin(rad) * rIn);
      ctx.lineTo(CX + Math.cos(rad) * rOut, CY + Math.sin(rad) * rOut);
      ctx.strokeStyle = '#4a4d5e';
      ctx.lineWidth = 1.2;
      ctx.stroke();
    }
  },

  /**
   * 二十四小时制时间刻度环（12 时正南 · 0 时正北）
   */
  drawTimeRing(ctx, CX, CY, R, FS) {
    const rIn = R.timeIn;
    const rOut = R.timeOut;

    // 环底
    ctx.beginPath();
    ctx.arc(CX, CY, rOut, 0, Math.PI * 2);
    ctx.arc(CX, CY, rIn, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fillStyle = '#111219';
    ctx.fill();
    ctx.strokeStyle = '#2d3042';
    ctx.lineWidth = 1;
    ctx.stroke();

    // 当前小时扇区高亮
    const now = new Date();
    const nowDeg = (((now.getHours() - 12 + 24) % 24) * 15) + now.getMinutes() * 0.25;
    const hourDeg = (Math.floor(nowDeg / 15) % 24) * 15;
    ctx.beginPath();
    ctx.arc(CX, CY, rOut, this.deg2rad(hourDeg - 7.5), this.deg2rad(hourDeg + 7.5));
    ctx.arc(CX, CY, rIn, this.deg2rad(hourDeg + 7.5), this.deg2rad(hourDeg - 7.5), true);
    ctx.closePath();
    ctx.fillStyle = 'rgba(231, 76, 60, 0.18)';
    ctx.fill();

    for (let h = 0; h < 24; h++) {
      const deg = ((h - 12 + 24) % 24) * 15;
      const rad = this.deg2rad(deg);
      const major = (h % 3 === 0);
      const tickEnd = major ? rOut - 8 * R.s : rOut - 16 * R.s;

      ctx.beginPath();
      ctx.moveTo(CX + Math.cos(rad) * rIn, CY + Math.sin(rad) * rIn);
      ctx.lineTo(CX + Math.cos(rad) * tickEnd, CY + Math.sin(rad) * tickEnd);
      ctx.strokeStyle = major ? '#d4af37' : '#5a5d6e';
      ctx.lineWidth = major ? 2 : 1;
      ctx.stroke();

      const lx = CX + Math.cos(rad) * (rOut - 26 * R.s);
      const ly = CY + Math.sin(rad) * (rOut - 26 * R.s);
      ctx.fillStyle = major ? '#d4af37' : '#9a9daa';
      ctx.font = major ? `bold ${FS.timeMajor}px sans-serif` : `${FS.timeMinor}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(h.toString(), lx, ly);
    }
  },

  /**
   * 十二消息卦 + 六爻外环（二十四山各配一卦）
   */
  drawMessageGuaRing(ctx, CX, CY, R, FS, hexW) {
    const SEG = 7.5;
    const midR = (R.solarRing + R.hexRing) / 2;
    const nameOff = -18 * R.s; // 卦名向外
    const hexOff = 13 * R.s;   // 六爻向内

    for (let i = 0; i < 24; i++) {
      const m = MOUNTAINS_DATA[i];
      const isSel = (i === this.hoveredIndex);
      const sRad = this.deg2rad(m.deg - SEG);
      const eRad = this.deg2rad(m.deg + SEG);

      ctx.beginPath();
      ctx.arc(CX, CY, R.hexRing, sRad, eRad);
      ctx.arc(CX, CY, R.solarRing, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = isSel ? '#2c3e50' : '#171821';
      ctx.fill();
      ctx.strokeStyle = '#383a4c';
      ctx.lineWidth = 1;
      ctx.stroke();

      const midRad = this.deg2rad(m.deg);
      ctx.save();
      ctx.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
      ctx.rotate(midRad + Math.PI / 2);
      ctx.fillStyle = isSel ? '#5dade2' : '#7f8c8d';
      ctx.font = `${FS.hexName}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(m.gua, 0, nameOff);
      this.drawHexagram(ctx, m.lines, 0, hexOff, hexW);
      ctx.restore();
    }
  },

  /**
   * 二十四节气环
   */
  drawSolarRing(ctx, CX, CY, R, FS) {
    const SEG = 7.5;
    const midR = (R.mountainRing + R.solarRing) / 2;

    for (let i = 0; i < 24; i++) {
      const m = MOUNTAINS_DATA[i];
      const isSel = (i === this.hoveredIndex);
      const sRad = this.deg2rad(m.deg - SEG);
      const eRad = this.deg2rad(m.deg + SEG);

      ctx.beginPath();
      ctx.arc(CX, CY, R.solarRing, sRad, eRad);
      ctx.arc(CX, CY, R.mountainRing, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = isSel ? '#d35400' : '#1f202b';
      ctx.fill();
      ctx.strokeStyle = '#383a4c';
      ctx.lineWidth = 1;
      ctx.stroke();

      const midRad = this.deg2rad(m.deg);
      ctx.save();
      ctx.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
      ctx.rotate(midRad + Math.PI / 2);
      ctx.fillStyle = isSel ? '#ffd166' : '#9ca3af';
      ctx.font = `${FS.solar}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(m.solar, 0, 0);
      ctx.restore();
    }
  },

  /**
   * 二十四山环
   */
  drawMountainRing(ctx, CX, CY, R, FS) {
    const SEG = 7.5;
    const midR = (R.postGuaRing + R.mountainRing) / 2;

    for (let i = 0; i < 24; i++) {
      const m = MOUNTAINS_DATA[i];
      const isSel = (i === this.hoveredIndex);
      const sRad = this.deg2rad(m.deg - SEG);
      const eRad = this.deg2rad(m.deg + SEG);

      ctx.beginPath();
      ctx.arc(CX, CY, R.mountainRing, sRad, eRad);
      ctx.arc(CX, CY, R.postGuaRing, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = isSel ? '#e67e22' : '#232533';
      ctx.fill();
      ctx.strokeStyle = '#383a4c';
      ctx.lineWidth = 1;
      ctx.stroke();

      const midRad = this.deg2rad(m.deg);
      ctx.save();
      ctx.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
      ctx.rotate(midRad + Math.PI / 2);
      ctx.fillStyle = isSel ? '#ffffff' : '#d1d5db';
      ctx.font = `bold ${FS.mountain}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(m.name, 0, 0);
      ctx.restore();
    }
  },

  /**
   * 八宫环（五行扇区填色 + 宫名）
   */
  drawPalaceRing(ctx, CX, CY, R, FS) {
    const palaces = this.data.currentMode === 'post' ? PALACES_POST : PALACES_PRE;
    const midR = (R.preGuaRing + R.postGuaRing) / 2;

    palaces.forEach((p) => {
      const sRad = this.deg2rad(p.baseDeg - 22.5);
      const eRad = this.deg2rad(p.baseDeg + 22.5);

      ctx.beginPath();
      ctx.arc(CX, CY, R.postGuaRing, sRad, eRad);
      ctx.arc(CX, CY, R.preGuaRing, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = ELEM_BG_DARK[p.elem] || '#232533';
      ctx.fill();
      ctx.strokeStyle = '#2d3042';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      const midRad = this.deg2rad(p.baseDeg);
      ctx.save();
      ctx.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
      ctx.rotate(midRad + Math.PI / 2);
      ctx.fillStyle = '#ffffff';
      ctx.font = `bold ${FS.palace}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`${p.name} ${p.symbol}`, 0, 0);
      ctx.restore();
    });
  },

  /**
   * 八卦符号内环（太极与八宫之间的金色卦符）
   */
  drawPalaceSymbolRing(ctx, CX, CY, R, FS) {
    const palaces = this.data.currentMode === 'post' ? PALACES_POST : PALACES_PRE;
    const midR = (R.taiji + R.preGuaRing) / 2;

    ctx.save();
    ctx.fillStyle = '#d4af37';
    ctx.font = `${FS.palaceSym}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    palaces.forEach((p) => {
      const rad = this.deg2rad(p.baseDeg);
      ctx.fillText(p.symbol, CX + Math.cos(rad) * midR, CY + Math.sin(rad) * midR);
    });
    ctx.restore();
  },

  /**
   * 今日当令之山金色弧标记
   */
  drawTodayHighlight(ctx, CX, CY, R) {
    if (this.currentIndex < 0 || this.currentIndex >= 24) return;
    const m = MOUNTAINS_DATA[this.currentIndex];
    const sRad = this.deg2rad(m.deg - 7.5);
    const eRad = this.deg2rad(m.deg + 7.5);

    ctx.save();
    ctx.beginPath();
    ctx.arc(CX, CY, R.hexRing + 5 * R.s, sRad, eRad);
    ctx.arc(CX, CY, R.hexRing + 2 * R.s, eRad, sRad, true);
    ctx.closePath();
    ctx.fillStyle = 'rgba(212, 175, 55, 0.35)';
    ctx.fill();
    ctx.strokeStyle = '#d4af37';
    ctx.lineWidth = 2.5;
    ctx.stroke();
    ctx.restore();
  },

  /**
   * 实时时钟红针（12 时正南 · 0 时正北）
   */
  drawClockPointer(ctx, CX, CY, R) {
    const now = new Date();
    const nowDeg = (((now.getHours() - 12 + 24) % 24) * 15)
      + now.getMinutes() * 0.25
      + now.getSeconds() * (0.25 / 60);
    const rad = this.deg2rad(nowDeg);

    const pStart = R.taiji + 4 * R.s;
    const pEnd = R.timeOut - 6 * R.s;

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(rad) * pStart, CY + Math.sin(rad) * pStart);
    ctx.lineTo(CX + Math.cos(rad) * pEnd, CY + Math.sin(rad) * pEnd);
    ctx.strokeStyle = 'rgba(231, 76, 60, 0.85)';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.stroke();

    // 末端指示圆点
    ctx.beginPath();
    ctx.arc(CX + Math.cos(rad) * pEnd, CY + Math.sin(rad) * pEnd, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#e74c3c';
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // 中心轴点
    ctx.beginPath();
    ctx.arc(CX, CY, 4, 0, Math.PI * 2);
    ctx.fillStyle = '#e74c3c';
    ctx.fill();
    ctx.restore();
  },

  /**
   * 核心双指针系统渲染：地磁北（绿）与地理真北（金）
   */
  drawDualCompassNeedles(ctx, CX, CY, R, FS) {
    const heading = this.currentHeading;
    if (heading === null || heading === undefined) return;

    // 1. 地磁北屏幕角（物理地磁实际指向，0°=北）
    const magNorthDeg = (360 - (heading % 360)) % 360;
    const magRad = this.deg2rad(magNorthDeg);

    // 2. 地理真北屏幕角（经度磁偏角校正后地理正北）
    const trueHeading = ((heading + this.currentDeclination) % 360 + 360) % 360;
    const trueNorthDeg = (360 - trueHeading) % 360;
    const trueRad = this.deg2rad(trueNorthDeg);

    // 3. 当存在明显地磁偏角（>=0.2°）时，在两针之间绘制半透明微金虚线弧与数值
    const declDiff = Math.abs(this.currentDeclination);
    if (declDiff >= 0.2) {
      const arcR = 92 * R.s;
      let diffA = trueRad - magRad;
      while (diffA < -Math.PI) diffA += Math.PI * 2;
      while (diffA > Math.PI) diffA -= Math.PI * 2;

      ctx.save();
      ctx.beginPath();
      ctx.arc(CX, CY, arcR, magRad, magRad + diffA, diffA < 0);
      ctx.strokeStyle = 'rgba(241, 196, 15, 0.45)';
      ctx.lineWidth = 1.5;
      if (typeof ctx.setLineDash === 'function') {
        ctx.setLineDash([2, 3]);
      }
      ctx.stroke();
      ctx.restore();

      // 标注偏角度数（如 7.3°）
      const midA = magRad + diffA / 2;
      const textR = arcR + 10 * R.s;
      ctx.fillStyle = '#ffd166';
      ctx.font = `bold ${FS.label}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`${declDiff.toFixed(1)}°`, CX + Math.cos(midA) * textR, CY + Math.sin(midA) * textR);
    }

    const arrowLen = Math.max(10, Math.round(14 * R.s * 1.8));
    const arrowAngle = 0.42;
    const labelBack = arrowLen * 0.62;

    // ---------- 指针南端配重对称尾翼 ----------
    // 磁北南端尾针（青墨色）
    const magSouthRad = magRad + Math.PI;
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(magSouthRad) * (R.taiji + 6 * R.s), CY + Math.sin(magSouthRad) * (R.taiji + 6 * R.s));
    ctx.lineTo(CX + Math.cos(magSouthRad) * (R.taiji + 18 * R.s), CY + Math.sin(magSouthRad) * (R.taiji + 18 * R.s));
    ctx.strokeStyle = 'rgba(39, 174, 96, 0.7)';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.stroke();

    // 真北南端尾针（暗金棕色）
    const trueSouthRad = trueRad + Math.PI;
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(trueSouthRad) * (R.taiji + 6 * R.s), CY + Math.sin(trueSouthRad) * (R.taiji + 6 * R.s));
    ctx.lineTo(CX + Math.cos(trueSouthRad) * (R.taiji + 15 * R.s), CY + Math.sin(trueSouthRad) * (R.taiji + 15 * R.s));
    ctx.strokeStyle = 'rgba(212, 175, 55, 0.6)';
    ctx.lineWidth = 1.5;
    ctx.lineCap = 'round';
    ctx.stroke();

    // ---------- 绘制【磁北针】（苍翠青绿，标“磁”） ----------
    {
      const pStart = R.taiji + 6 * R.s;
      const pEnd = R.postGuaRing - 6 * R.s;
      ctx.beginPath();
      ctx.moveTo(CX + Math.cos(magRad) * pStart, CY + Math.sin(magRad) * pStart);
      ctx.lineTo(CX + Math.cos(magRad) * pEnd, CY + Math.sin(magRad) * pEnd);
      ctx.strokeStyle = 'rgba(46, 204, 113, 0.95)';
      ctx.lineWidth = 3;
      ctx.lineCap = 'round';
      ctx.stroke();

      const ax = CX + Math.cos(magRad) * pEnd;
      const ay = CY + Math.sin(magRad) * pEnd;
      ctx.beginPath();
      ctx.moveTo(ax, ay);
      ctx.lineTo(ax - Math.cos(magRad - arrowAngle) * arrowLen, ay - Math.sin(magRad - arrowAngle) * arrowLen);
      ctx.lineTo(ax - Math.cos(magRad + arrowAngle) * arrowLen, ay - Math.sin(magRad + arrowAngle) * arrowLen);
      ctx.closePath();
      ctx.fillStyle = '#2ecc71';
      ctx.fill();

      // 箭头内“磁”字
      ctx.fillStyle = '#ffffff';
      ctx.font = `bold ${FS.label}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('磁', ax - Math.cos(magRad) * labelBack, ay - Math.sin(magRad) * labelBack);
    }

    // ---------- 绘制【真北针】（曜目金光，标“真”） ----------
    {
      const pStart = R.taiji + 6 * R.s;
      const pEnd = R.postGuaRing - 14 * R.s; // 微缩以防重叠遮挡
      ctx.beginPath();
      ctx.moveTo(CX + Math.cos(trueRad) * pStart, CY + Math.sin(trueRad) * pStart);
      ctx.lineTo(CX + Math.cos(trueRad) * pEnd, CY + Math.sin(trueRad) * pEnd);
      ctx.strokeStyle = 'rgba(241, 196, 15, 0.95)';
      ctx.lineWidth = 2.5;
      ctx.lineCap = 'round';
      ctx.stroke();

      const ax = CX + Math.cos(trueRad) * pEnd;
      const ay = CY + Math.sin(trueRad) * pEnd;
      ctx.beginPath();
      ctx.moveTo(ax, ay);
      ctx.lineTo(ax - Math.cos(trueRad - arrowAngle) * arrowLen, ay - Math.sin(trueRad - arrowAngle) * arrowLen);
      ctx.lineTo(ax - Math.cos(trueRad + arrowAngle) * arrowLen, ay - Math.sin(trueRad + arrowAngle) * arrowLen);
      ctx.closePath();
      ctx.fillStyle = '#f1c40f';
      ctx.fill();

      // 箭头内“真”字
      ctx.fillStyle = '#2c1e02';
      ctx.font = `bold ${FS.label}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('真', ax - Math.cos(trueRad) * labelBack, ay - Math.sin(trueRad) * labelBack);
    }
  }
});

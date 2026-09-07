/**
 * pages/index/index.js
 * 演象 · 时空罗盘 微信小程序主逻辑
 * 与 Android 版 yiijing_map.html 完全对齐
 */

const {
  MOUNTAINS_DATA,
  PALACES_POST,
  PALACES_PRE,
  HEXAGRAMS_64,
  GUA64_STEP,
  GUA64_HALF,
  ELEM_COLORS,
  ELEM_BG_DARK
} = require('../../utils/compass-data');

const { getTodayMountainInfo } = require('../../utils/solar-terms');
const { computeDeclination, formatLocationAndDeclination } = require('../../utils/geomagnetic');
const { calculateTrueSolarTime, calculateFourPillars } = require('../../utils/astronomy');
const {
  JIAZI_60, geoDirName, getSitAndFaceDiagnosis, getFenjinAnalysis
} = require('../../utils/fengshui');

const DEFAULT_LAYERS = {
  bubbleLevel: true,  // 太极双轴电子水准仪气泡
  palaces: true,      // 八卦八宫环
  mountains: true,    // 二十四山
  fenjin: true,       // 一百二十分金
  solarRing: true,    // 二十四节气与消息卦
  timeDial: true,     // 24 小时时间圈与真太阳时针
  hex64: true         // 先天六十四卦圆图
};

Page({
  data: {
    // 模式与选中
    currentMode: 'post',
    currentMountain: MOUNTAINS_DATA[13],
    currentPalaceName: '坎宫',
    geoDirStr: '正北',
    elemColor: ELEM_COLORS['水'],
    modeLabel: '后天',

    // 顶部综合状态栏
    todayLine: '',
    nowTime: '00:00',
    nowSpeed: '0 KM/H',
    nowDir: '正北 0°',

    // 双北指针
    headingDescMag: '正北 0° · 子山',
    headingDescTrue: '正北 0°',
    declSummary: '无偏',

    // 风水立向
    sitFacePattern: '坐午向子 · 正针',
    kongwangText: '正针纯清',
    kongwangClass: 'pure',
    fenjinText: '庚子分金 (旺相珠宝 (吉))',
    fenjinColor: '#2ecc71',
    levelText: '0.0° · 水平良好 ✓',
    levelColor: '#2ecc71',

    // 天文历法
    ganzhiStr: '推算中…',
    solarTimeStr: '计算中…',
    solarTimeDelta: '',

    // 罗盘转动模式与锁定
    compassMode: 'rotateDisk', // 'rotateDisk'=盘随向转, 'fixedDisk'=固定盘面
    isHeadingLocked: false,

    // 强磁预警
    showMagAlert: false,
    magAlertText: '',

    // 定位与地磁
    coordsDisplayStr: '正在获取GPS定位…',
    declinationDetailStr: '正在获取GPS定位…',

    // 弹窗
    showCalibModal: false,
    showLayerModal: false,
    showKongwangModal: false,
    showFenjinModal: false,
    calibAccuracyText: '✓ 极高 (已自动校准)',
    calibAccClass: '',
    calibClass: '',
    magBadgeText: '✓ 正常 (地磁均匀)',
    magBadgeClass: '',

    // 空亡 / 分金详解弹窗内容
    kwHeadingText: '--',
    kwOffsetText: '--',
    kwBadgeText: '正针纯清',
    kwBadgeClass: 'pure',
    fjNameText: '--',
    fjRangeText: '--',
    fjBadgeText: '旺相珠宝',
    fjBadgeColor: '#2ecc71',

    // 圈层图层
    layerConfig: Object.assign({}, DEFAULT_LAYERS)
  },

  // ==================== 内部状态（不参与视图渲染） ====================
  canvas: null,
  ctx: null,
  dialCanvas: null,
  dialCtx: null,
  useOffscreen: false,
  dpr: 1,
  canvasW: 450,
  canvasH: 450,

  currentHeading: 0,
  targetHeading: 0,
  isAnimating: false,
  lockedHeading: 0,
  lastAccuracyLevel: '',
  lastTiltMag: -999,
  currentDeclination: 0,
  hasDeclination: false,
  currentLatitude: 0,
  currentLongitude: 0,
  currentAltitude: 0,
  hasAltitude: false,

  currentPitch: 0,
  currentRoll: 0,
  currentSpeed: 0,

  currentIndex: -1,
  hoveredIndex: 13,
  isTouching: false,

  // 缩放与拖拽平移系统（对齐 Android MIN_SCALE/MAX_SCALE）
  viewScale: 1.0,
  viewTX: 0,
  viewTY: 0,
  MIN_SCALE: 1.0,
  MAX_SCALE: 4.5,
  touchStartDist: 0,
  touchStartScale: 1.0,
  touchStartX: 0,
  touchStartY: 0,
  touchStartTX: 0,
  touchStartTY: 0,
  isDragging: false,
  lastTapTime: 0,

  layerConfig: Object.assign({}, DEFAULT_LAYERS),
  isDialDirty: true,
  isDrawScheduled: false,

  cachedTrueSolarTime: null,
  cachedFourPillars: null,
  lastFengshuiHeading: -999,
  lastCompassInfoHeading: -999,

  clockTimer: null,
  locationTimer: null,
  isCompassRunning: false,
  isMotionRunning: false,

  // ==================== 生命周期 ====================
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
      this.startMotionListener();
    }
  },

  onHide() {
    this.stopCompassListener();
    this.stopMotionListener();
  },

  onUnload() {
    this.stopCompassListener();
    this.stopMotionListener();
    if (this.clockTimer) { clearInterval(this.clockTimer); this.clockTimer = null; }
    if (this.locationTimer) { clearInterval(this.locationTimer); this.locationTimer = null; }
    if (typeof wx.stopLocationUpdate === 'function') {
      wx.stopLocationUpdate();
      if (typeof wx.offLocationChange === 'function') wx.offLocationChange();
    }
  },

  // ==================== 初始化 ====================
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
      this.setData({ todayLine: '—' });
    }
  },

  startClockTimer() {
    this.refreshAstronomicalData();
    this.updateHeaderStatus();
    // 与 Android 一致：每秒刷新天文数据与状态栏
    this.clockTimer = setInterval(() => {
      this.refreshAstronomicalData();
      this.updateHeaderStatus();
    }, 1000);
  },

  /**
   * 天文算力解耦：四柱与真太阳时每秒运算一次并缓存，
   * 避免落入 60Hz 罗盘旋转流重复执行三角函数
   */
  refreshAstronomicalData() {
    try {
      this.cachedFourPillars = calculateFourPillars(new Date(), this.currentLongitude);
      this.cachedTrueSolarTime = calculateTrueSolarTime(this.currentLongitude, new Date());
      this.setData({
        ganzhiStr: this.cachedFourPillars.fullStr,
        solarTimeStr: this.cachedTrueSolarTime.timeStr,
        solarTimeDelta: this.cachedTrueSolarTime.deltaDesc
      });
    } catch (e) {
      console.warn('refreshAstronomicalData error:', e);
    }
  },

  initLocation() {
    const applyLocation = (lat, lon, alt, speed) => {
      this.currentLatitude = lat;
      this.currentLongitude = lon;
      if (alt !== undefined && alt !== null) {
        this.currentAltitude = alt;
        this.hasAltitude = !!(alt && alt !== 0);
      }
      if (speed !== undefined && speed !== null && !isNaN(speed)) {
        this.currentSpeed = Math.max(0, speed);
      }

      const decl = computeDeclination(lat, lon, this.currentAltitude, new Date());
      this.currentDeclination = decl;
      this.hasDeclination = true;

      const info = formatLocationAndDeclination(lat, lon, this.currentAltitude, decl);
      this.setData({
        coordsDisplayStr: info.coordsDesc,
        declinationDetailStr: `${Math.abs(decl).toFixed(1)}° (${info.dirStr})`,
        declSummary: info.declText
      });

      this.refreshAstronomicalData();
      this.updateCompassInfo(true);
      this.updateHeaderStatus();
      if (this.ctx) this.scheduleCompassDraw();
    };

    const onFail = (err) => {
      console.warn('获取用户位置失败或未授权:', err);
      this.setData({
        coordsDisplayStr: '请开启系统位置信息(GPS)',
        declinationDetailStr: '0° (无偏角 · 默认值)',
        declSummary: '无偏'
      });
    };

    wx.getLocation({
      type: 'wgs84',
      altitude: true,
      success: (res) => {
        // wx.getLocation 返回速度为 m/s，转换为 KM/H
        const kmh = (typeof res.speed === 'number' && res.speed >= 0) ? res.speed * 3.6 : 0;
        applyLocation(res.latitude, res.longitude, res.altitude, kmh);
        this.startLocationWatch(applyLocation, onFail);
      },
      fail: onFail
    });
  },

  /**
   * 持续定位监听（实时刷新坐标与速度）；不支持时退化为定时轮询
   */
  startLocationWatch(applyLocation, onFail) {
    if (typeof wx.startLocationUpdate !== 'function' || typeof wx.onLocationChange !== 'function') {
      this.locationTimer = setInterval(() => {
        wx.getLocation({
          type: 'wgs84', altitude: true,
          success: (r) => applyLocation(r.latitude, r.longitude, r.altitude,
            (typeof r.speed === 'number' && r.speed >= 0) ? r.speed * 3.6 : 0),
          fail: () => {}
        });
      }, 10000);
      return;
    }
    wx.startLocationUpdate({
      success: () => {
        wx.onLocationChange((res) => {
          const kmh = (typeof res.speed === 'number' && res.speed >= 0) ? res.speed * 3.6 : 0;
          applyLocation(res.latitude, res.longitude, res.altitude, kmh);
        });
      },
      fail: () => {
        this.locationTimer = setInterval(() => {
          wx.getLocation({
            type: 'wgs84', altitude: true,
            success: (r) => applyLocation(r.latitude, r.longitude, r.altitude,
              (typeof r.speed === 'number' && r.speed >= 0) ? r.speed * 3.6 : 0),
            fail: () => {}
          });
        }, 10000);
      }
    });
  },

  initCanvas() {
    const query = wx.createSelectorQuery().in(this);
    query.select('#compassCanvas').fields({ node: true, size: true }).exec((res) => {
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

      // 离屏缓冲画布：用于预渲染静态盘面（八宫/24山/120分金/节气/消息卦/时间刻度/64卦）
      const dq = wx.createSelectorQuery().in(this);
      dq.select('#dialCanvas').fields({ node: true, size: true }).exec((dres) => {
        if (dres && dres[0] && dres[0].node) {
          const dc = dres[0].node;
          dc.width = width * dpr;
          dc.height = height * dpr;
          const dctx = dc.getContext('2d');
          dctx.scale(dpr, dpr);
          this.dialCanvas = dc;
          this.dialCtx = dctx;
          this.useOffscreen = true;
        } else {
          this.useOffscreen = false;
        }
        this.isDialDirty = true;
        this.drawCompass();
        this.startCompassListener();
        this.startMotionListener();
      });
    });
  },

  // ==================== 传感器 ====================
  startCompassListener() {
    this.isCompassRunning = true;
    wx.startCompass({
      interval: 'game',
      success: () => {
        wx.onCompassChange((res) => {
          if (this.data.isHeadingLocked) return; // 立向已锁定
          if (res.direction !== undefined && !isNaN(res.direction)) {
            this.targetHeading = ((res.direction % 360) + 360) % 360;
            if (!this.isAnimating) {
              this.isAnimating = true;
              this.animateCompassStep();
            }
          }
          if (res.accuracy !== undefined) {
            this.updateAccuracy(res.accuracy);
          }
        });
      },
      fail: (err) => { console.warn('wx.startCompass failed:', err); }
    });
  },

  stopCompassListener() {
    this.isCompassRunning = false;
    if (typeof wx.stopCompass === 'function') wx.stopCompass();
    // 必须同时解绑回调，否则 onShow/onHide 反复切换会叠加监听器与动画帧循环
    if (typeof wx.offCompassChange === 'function') wx.offCompassChange();
  },

  startMotionListener() {
    if (this.isMotionRunning) return;
    this.isMotionRunning = true;
    if (typeof wx.startDeviceMotionListening !== 'function') return;
    wx.startDeviceMotionListening({
      interval: 'game',
      success: () => {
        wx.onDeviceMotionChange((res) => {
          if (res.beta !== undefined && res.gamma !== undefined) {
            this.currentPitch = res.beta;
            this.currentRoll = res.gamma;
            this.updateTiltDisplay();
            if (this.layerConfig.bubbleLevel) this.scheduleCompassDraw();
          }
        });
      },
      fail: (err) => { console.warn('wx.startDeviceMotionListening failed:', err); }
    });
  },

  stopMotionListener() {
    if (!this.isMotionRunning) return;
    this.isMotionRunning = false;
    if (typeof wx.stopDeviceMotionListening === 'function') wx.stopDeviceMotionListening();
    if (typeof wx.offDeviceMotionChange === 'function') wx.offDeviceMotionChange();
  },

  updateAccuracy(acc) {
    // 微信各端 acc 可能为字符串(android)或数值(iOS)，统一归一到等级
    let level = 'high';
    if (typeof acc === 'string') {
      level = acc;
    } else if (typeof acc === 'number') {
      if (acc <= 0) level = 'unreliable';
      else if (acc < 15) level = 'low';
      else if (acc < 45) level = 'medium';
      else level = 'high';
    }

    let text = '✓ 极高 (已自动校准)';
    let accClass = '';
    let dotClass = '';
    if (level === 'medium') {
      text = '⚠️ 精度一般 (建议空中画8字)';
      accClass = 'med'; dotClass = 'med';
    } else if (level === 'low' || level === 'unreliable') {
      text = '⚠️ 需校准 (请空中画8字)';
      accClass = 'low'; dotClass = 'low';
    }

    // 该回调随罗盘高频触发，仅在等级变化时触碰 setData
    if (level === this.lastAccuracyLevel) return;
    this.lastAccuracyLevel = level;

    // 小程序无原始磁通量接口，以传感器精度等级等效判定强磁干扰
    const distorted = (level === 'low' || level === 'unreliable');
    const patch = {
      calibAccuracyText: text,
      calibAccClass: accClass,
      calibClass: dotClass,
      showMagAlert: distorted,
      magAlertText: distorted ? '⚠️ 监测到金属/强磁干扰 · 建议远离铁器或移步室内' : '',
      magBadgeText: distorted ? '⚠️ 强磁干扰' : '✓ 正常 (地磁均匀)',
      magBadgeClass: distorted ? 'low' : ''
    };
    this.setData(patch);
  },

  animateCompassStep() {
    let diff = ((this.targetHeading - this.currentHeading + 540) % 360) - 180;
    if (Math.abs(diff) < 0.08) {
      this.currentHeading = this.targetHeading;
      this.isAnimating = false;
    } else {
      this.currentHeading = (this.currentHeading + diff * 0.55 + 360) % 360;
      if (this.canvas && typeof this.canvas.requestAnimationFrame === 'function') {
        this.canvas.requestAnimationFrame(() => this.animateCompassStep());
      } else {
        setTimeout(() => this.animateCompassStep(), 16);
      }
    }
    this.updateCompassInfo();
    this.updateHeaderStatus();
    this.scheduleCompassDraw();
  },

  updateTiltDisplay() {
    const tiltMag = Math.sqrt(this.currentPitch * this.currentPitch + this.currentRoll * this.currentRoll);
    // 姿态回调同样高频，0.1° 死区，避免每帧 setData
    if (Math.abs(tiltMag - this.lastTiltMag) < 0.1) return;
    this.lastTiltMag = tiltMag;

    if (tiltMag < 2.5) {
      this.setData({ levelText: `${tiltMag.toFixed(1)}° · 水平良好 ✓`, levelColor: '#2ecc71' });
    } else if (tiltMag < 7.0) {
      this.setData({ levelText: `${tiltMag.toFixed(1)}° · 轻微倾斜`, levelColor: '#f39c12' });
    } else {
      this.setData({ levelText: `${tiltMag.toFixed(1)}° · ⚠️ 请放平手机`, levelColor: '#e74c3c' });
    }
  },

  // ==================== 状态刷新 ====================
  getEffectiveHeading() {
    return this.data.isHeadingLocked ? this.lockedHeading : this.currentHeading;
  },

  updateCompassInfo(force) {
    const effectiveHeading = this.data.isHeadingLocked ? (this.lockedHeading || 0) : this.currentHeading;
    if (!force && Math.abs(effectiveHeading - this.lastCompassInfoHeading) < 0.2) return;
    this.lastCompassInfoHeading = effectiveHeading;

    const heading = effectiveHeading;
    const trueHeading = ((heading + this.currentDeclination) % 360 + 360) % 360;
    const dirNameMag = geoDirName(heading);
    const dirNameTrue = geoDirName(trueHeading);

    // 真实方位→罗盘角度：罗盘0°=正南，真实0°=正北
    const compassDeg = (heading + 180) % 360;
    let nearest = MOUNTAINS_DATA[13], minDiff = 360, nearestIdx = 13;
    for (let i = 0; i < 24; i++) {
      let diff = Math.abs(MOUNTAINS_DATA[i].deg - compassDeg);
      diff = Math.min(diff, 360 - diff);
      if (diff < minDiff) { minDiff = diff; nearest = MOUNTAINS_DATA[i]; nearestIdx = i; }
    }

    // 盘随向转模式下，选中山向自动跟随当前朝向
    if (this.data.compassMode === 'rotateDisk' && !this.isTouching && this.hoveredIndex !== nearestIdx) {
      this.hoveredIndex = nearestIdx;
      this.updateMountainDetails(nearestIdx);
    }

    const declAbs = Math.abs(this.currentDeclination).toFixed(1);
    const declText = this.currentDeclination < 0 ? `偏西${declAbs}°` : (this.currentDeclination > 0 ? `偏东${declAbs}°` : '无偏');

    this.setData({
      headingDescMag: `${dirNameMag} ${heading.toFixed(0)}° · ${nearest.name}山`,
      headingDescTrue: `${dirNameTrue} ${trueHeading.toFixed(0)}°`,
      declSummary: declText
    });
    this.updateAllFengshuiStatus(false);
  },

  /**
   * 坐向格局、空亡诊断与分金全景刷新（0.2° 死区防抖，杜绝高频 setData）
   */
  updateAllFengshuiStatus(force) {
    const effectiveHeading = this.data.isHeadingLocked ? (this.lockedHeading || 0) : this.currentHeading;
    if (effectiveHeading === null || isNaN(effectiveHeading)) return;
    if (!force && Math.abs(effectiveHeading - this.lastFengshuiHeading) < 0.2) return;
    this.lastFengshuiHeading = effectiveHeading;

    const diag = getSitAndFaceDiagnosis(effectiveHeading);
    const fj = getFenjinAnalysis(effectiveHeading);

    this.setData({
      sitFacePattern: diag.sitFacePattern,
      kongwangText: diag.statusText,
      kongwangClass: diag.badgeClass,
      fenjinText: fj.displayStr,
      fenjinColor: fj.badgeColor
    });
  },

  updateHeaderStatus() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const speedStr = this.currentSpeed > 0
      ? (this.currentSpeed >= 10 ? this.currentSpeed.toFixed(0) : this.currentSpeed.toFixed(1))
      : '0';
    const effectiveHeading = this.data.isHeadingLocked ? (this.lockedHeading || 0) : this.currentHeading;
    const h = ((effectiveHeading % 360) + 360) % 360;

    this.setData({
      nowTime: `${pad(now.getHours())}:${pad(now.getMinutes())}`,
      nowSpeed: `${speedStr} KM/H`,
      nowDir: `${geoDirName(h)} ${Math.round(h)}°`
    });
    this.updateAllFengshuiStatus(false);
  },

  // ==================== 交互 ====================
  onSwitchMode(e) {
    const mode = e.currentTarget.dataset.mode;
    if (!mode || mode === this.data.currentMode) return;
    this.setData({
      currentMode: mode,
      modeLabel: mode === 'post' ? '后天' : '先天'
    });
    this.isDialDirty = true;
    this.updateMountainDetails(this.hoveredIndex);
    this.scheduleCompassDraw();
  },

  toggleCompassMode() {
    const next = this.data.compassMode === 'rotateDisk' ? 'fixedDisk' : 'rotateDisk';
    this.setData({ compassMode: next });
    this.updateCompassInfo(true);
    this.scheduleCompassDraw();
  },

  toggleHeadingLock() {
    const locked = !this.data.isHeadingLocked;
    if (locked) this.lockedHeading = this.currentHeading;
    this.setData({ isHeadingLocked: locked });
    this.updateCompassInfo(true);
    this.scheduleCompassDraw();
  },

  updateMountainDetails(idx) {
    const m = MOUNTAINS_DATA[idx];
    const palaces = this.data.currentMode === 'post' ? PALACES_POST : PALACES_PRE;
    let palName = '';
    palaces.forEach((p) => {
      const diff = ((m.deg - p.baseDeg + 540) % 360) - 180;
      if (Math.abs(diff) <= 23) palName = p.name;
    });

    this.setData({
      currentMountain: m,
      currentPalaceName: palName || (this.data.currentMode === 'post' ? m.post + '宫' : m.pre + '宫'),
      geoDirStr: geoDirName((m.deg + 180) % 360),
      elemColor: ELEM_COLORS[m.elem] || '#ffffff'
    });
  },

  /**
   * 视图缩放 / 平移变换应用与边界收敛
   */
  applyViewTransform() {
    const maxTranslate = (this.viewScale - 1) * (this.canvasW / 2);
    this.viewTX = Math.max(-maxTranslate, Math.min(maxTranslate, this.viewTX));
    this.viewTY = Math.max(-maxTranslate, Math.min(maxTranslate, this.viewTY));
    if (this.viewScale <= 1.001) {
      this.viewTX = 0;
      this.viewTY = 0;
    }
  },

  setZoom(newScale) {
    this.viewScale = Math.max(this.MIN_SCALE, Math.min(this.MAX_SCALE, newScale));
    this.applyViewTransform();
    this.scheduleCompassDraw();
  },

  resetView() {
    this.viewScale = 1.0;
    this.viewTX = 0;
    this.viewTY = 0;
    this.scheduleCompassDraw();
  },

  /**
   * 屏幕坐标 → 画布坐标（抵消当前缩放与平移）
   */
  toCanvasPoint(sx, sy) {
    const CX = this.canvasW / 2;
    const CY = this.canvasH / 2;
    return {
      x: (sx - CX - this.viewTX) / this.viewScale + CX,
      y: (sy - CY - this.viewTY) / this.viewScale + CY
    };
  },

  handleTouch(e) {
    if (!e.touches || !e.touches[0]) return;
    const p = this.toCanvasPoint(e.touches[0].x, e.touches[0].y);
    const CX = this.canvasW / 2;
    const CY = this.canvasH / 2;
    const dx = p.x - CX;
    const dy = p.y - CY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist <= 20 || dist > CX) return;

    // 盘面角度（0°=正南/画布顶部，顺时针）
    let ang = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;
    // 抵消盘随向转带来的盘面旋转
    if (this.data.compassMode === 'rotateDisk') {
      const effectiveHeading = this.data.isHeadingLocked ? (this.lockedHeading || 0) : this.currentHeading;
      const diskRotDeg = (180 - effectiveHeading + 360) % 360;
      ang = (ang - diskRotDeg + 720) % 360;
    }

    let bestIdx = 0, minDiff = 360;
    for (let i = 0; i < 24; i++) {
      let diff = Math.abs(MOUNTAINS_DATA[i].deg - ang);
      diff = Math.min(diff, 360 - diff);
      if (diff < minDiff) { minDiff = diff; bestIdx = i; }
    }

    if (bestIdx !== this.hoveredIndex) {
      this.hoveredIndex = bestIdx;
      this.updateMountainDetails(bestIdx);
      this.scheduleCompassDraw();
    }
  },

  // 触控交互：单指点击选中 / 单指拖拽平移 / 双指捏合缩放 / 双击切换缩放
  onTouchStart(e) {
    if (!e.touches) return;
    if (e.touches.length === 1) {
      const t = e.touches[0];
      this.touchStartX = t.x;
      this.touchStartY = t.y;
      this.touchStartTX = this.viewTX;
      this.touchStartTY = this.viewTY;
      this.isDragging = false;
      this.isTouching = true;
      this.handleTouch(e);
    } else if (e.touches.length === 2) {
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      const ddx = t2.x - t1.x;
      const ddy = t2.y - t1.y;
      this.isTouching = true;
      this.isDragging = false;
      this.touchStartDist = Math.sqrt(ddx * ddx + ddy * ddy);
      this.touchStartScale = this.viewScale;
      this.touchStartTX = this.viewTX;
      this.touchStartTY = this.viewTY;
    }
  },

  onTouchMove(e) {
    if (!this.isTouching || !e.touches) return;
    if (e.touches.length === 1) {
      const t = e.touches[0];
      const dx = t.x - this.touchStartX;
      const dy = t.y - this.touchStartY;
      if (Math.sqrt(dx * dx + dy * dy) > 8) this.isDragging = true;

      if (this.viewScale > 1.05 && this.isDragging) {
        this.viewTX = this.touchStartTX + dx;
        this.viewTY = this.touchStartTY + dy;
        this.applyViewTransform();
        this.scheduleCompassDraw();
      } else {
        this.handleTouch(e);
      }
    } else if (e.touches.length === 2) {
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      const ddx = t2.x - t1.x;
      const ddy = t2.y - t1.y;
      const curDist = Math.sqrt(ddx * ddx + ddy * ddy);
      if (this.touchStartDist > 0) {
        this.viewScale = Math.max(this.MIN_SCALE, Math.min(this.MAX_SCALE,
          this.touchStartScale * (curDist / this.touchStartDist)));
        this.applyViewTransform();
        this.scheduleCompassDraw();
      }
    }
  },

  onTouchEnd(e) {
    if (!e.touches || e.touches.length === 0) {
      this.isTouching = false;
      if (!this.isDragging) {
        const now = Date.now();
        if (now - this.lastTapTime < 300) {
          // 双击切换缩放
          this.setZoom(this.viewScale > 1.2 ? 1.0 : 2.2);
          this.lastTapTime = 0;
        } else {
          this.lastTapTime = now;
        }
      }
    }
  },

  // ---------- 弹窗 ----------
  toggleCalibModal(e) {
    const show = e.currentTarget.dataset.show === 'true' || e.currentTarget.dataset.show === true;
    this.setData({ showCalibModal: show });
  },
  onCalibClose() { this.setData({ showCalibModal: false }); },
  onCalibReset() {
    this.initLocation();
    wx.showToast({ title: '已重置，请画8字', icon: 'none', duration: 1500 });
  },

  toggleLayerModal(e) {
    const show = e.currentTarget.dataset.show === 'true' || e.currentTarget.dataset.show === true;
    this.setData({ showLayerModal: show });
  },

  onLayerToggle(e) {
    const key = e.currentTarget.dataset.layer;
    if (!key || this.layerConfig[key] === undefined) return;
    this.layerConfig[key] = !this.layerConfig[key];
    this.isDialDirty = true;
    this.setData({ layerConfig: Object.assign({}, this.layerConfig) });
    this.scheduleCompassDraw();
  },

  applyLayerPreset(e) {
    const preset = e.currentTarget.dataset.preset;
    if (preset === 'all') {
      this.layerConfig = Object.assign({}, DEFAULT_LAYERS);
    } else if (preset === 'sanyuan') {
      this.layerConfig = Object.assign({}, DEFAULT_LAYERS, { timeDial: false });
    } else if (preset === 'simple') {
      this.layerConfig = Object.assign({}, DEFAULT_LAYERS, { palaces: false, solarRing: false, timeDial: false, hex64: false });
    }
    this.isDialDirty = true;
    this.setData({ layerConfig: Object.assign({}, this.layerConfig) });
    this.scheduleCompassDraw();
  },

  toggleKongwangModal(e) {
    const show = e.currentTarget.dataset.show === 'true' || e.currentTarget.dataset.show === true;
    if (show) {
      const h = ((this.getEffectiveHeading() % 360) + 360) % 360;
      const diag = getSitAndFaceDiagnosis(h);
      const absDev = Math.abs(diag.dev);
      this.setData({
        kwHeadingText: `${geoDirName(h)} ${h.toFixed(1)}° (${diag.faceMt}山)`,
        kwOffsetText: absDev < 0.3 ? '居中正线 (±0.0°)' : `偏${diag.dev > 0 ? '右' : '左'} ${absDev.toFixed(1)}°`,
        kwBadgeText: diag.statusText,
        kwBadgeClass: diag.badgeClass
      });
    }
    this.setData({ showKongwangModal: show });
  },

  toggleFenjinModal(e) {
    const show = e.currentTarget.dataset.show === 'true' || e.currentTarget.dataset.show === true;
    if (show) {
      const h = ((this.getEffectiveHeading() % 360) + 360) % 360;
      const fj = getFenjinAnalysis(h);
      this.setData({
        fjNameText: `${fj.name}分金 (第${fj.fenjinIdx + 1}分金)`,
        fjRangeText: `${fj.startDeg.toFixed(1)}° ~ ${fj.endDeg.toFixed(1)}° (当前${h.toFixed(1)}°)`,
        fjBadgeText: fj.type,
        fjBadgeColor: fj.badgeColor
      });
    }
    this.setData({ showFenjinModal: show });
  },

  preventBubble() {},

  // ==================== 绘图 ====================
  deg2rad(d) {
    // 0°=正南(画布顶部)、顺时针；canvas 0°=正右，故减 90° 对齐
    return (d - 90) * Math.PI / 180;
  },

  /**
   * 绘制六爻卦图（初爻在下）
   */
  drawHexagram(c, lines, x, y, size) {
    const h = size * 0.12;
    const w = size;
    const gap = size * 0.08;
    let py = y + ((lines.length - 1) * (h + gap)) / 2;
    for (let i = 0; i < lines.length; i++) {
      c.fillStyle = lines[i] === 1 ? '#e74c3c' : '#4a90e2';
      if (lines[i] === 1) {
        c.fillRect(x - w / 2, py - h / 2, w, h);
      } else {
        const segW = w * 0.42;
        c.fillRect(x - w / 2, py - h / 2, segW, h);
        c.fillRect(x + w / 2 - segW, py - h / 2, segW, h);
      }
      py -= h + gap;
    }
  },

  /**
   * 统一计算环径与字号（设计尺寸 900，与 Android 版 1:1）
   */
  computeLayout() {
    const W = this.canvasW;
    const H = this.canvasH;
    const s = W / 900;
    const R = {
      s,
      taiji: 42 * s,
      preGuaRing: 86 * s,
      postGuaRing: 138 * s,
      mountainRing: 198 * s,
      fenjinRing: 242 * s,
      solarRing: 295 * s,
      hexRing: 355 * s,
      timeIn: 363 * s,   // hexRing + 8
      timeOut: 396 * s,
      gua64In: 402 * s,  // timeOuter + 6
      gua64Out: 442 * s
    };
    const FS = {
      palaceSym: Math.max(9, Math.round(17 * s * 1.4)),
      palace: Math.max(8, Math.round(12 * s * 1.6)),
      mountain: Math.max(11, Math.round(12 * s * 1.6)),
      fenjin: Math.max(7, Math.round(8 * s * 1.8)),
      solar: Math.max(9, Math.round(11 * s * 1.6)),
      hexName: Math.max(7, Math.round(10 * s * 1.6)),
      timeMinor: Math.max(7, Math.round(9 * s * 1.6)),
      timeMajor: Math.max(8, Math.round(11 * s * 1.6)),
      gua64: Math.max(4, Math.round(7 * s * 1.6)),
      label: Math.max(7, Math.round(8 * s * 1.6))
    };
    return { W, H, CX: W / 2, CY: H / 2, R, FS };
  },

  scheduleCompassDraw() {
    if (this.isDrawScheduled) return;
    this.isDrawScheduled = true;
    const run = () => { this.isDrawScheduled = false; this.drawCompass(); };
    if (this.canvas && typeof this.canvas.requestAnimationFrame === 'function') {
      this.canvas.requestAnimationFrame(run);
    } else {
      setTimeout(run, 16);
    }
  },

  drawCompass() {
    const ctx = this.ctx;
    if (!ctx) return;
    const { W, H, CX, CY, R, FS } = this.computeLayout();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#14151f';
    ctx.fillRect(0, 0, W, H);

    // 仅在未缩放、未平移时启用离屏位图缓存；
    // 缩放/平移状态下改为直接矢量重绘，保证放大后文字与线条依然锐利
    const useCache = this.useOffscreen && !!this.dialCtx
      && this.viewScale <= 1.001 && this.viewTX === 0 && this.viewTY === 0;

    if (useCache && this.isDialDirty) {
      this.dialCtx.clearRect(0, 0, W, H);
      this.renderStaticDial(this.dialCtx, CX, CY, R, FS);
      this.isDialDirty = false;
    }

    const effectiveHeading = this.data.isHeadingLocked ? (this.lockedHeading || 0) : this.currentHeading;
    let diskRotDeg = 0;
    if (this.data.compassMode === 'rotateDisk' && effectiveHeading !== null) {
      diskRotDeg = (180 - effectiveHeading + 360) % 360;
    }

    // ---------- 视图缩放与平移包裹 ----------
    ctx.save();
    if (this.viewScale > 1.001 || this.viewTX !== 0 || this.viewTY !== 0) {
      ctx.translate(CX + this.viewTX, CY + this.viewTY);
      ctx.scale(this.viewScale, this.viewScale);
      ctx.translate(-CX, -CY);
    }

    ctx.save();
    if (diskRotDeg !== 0) {
      ctx.translate(CX, CY);
      ctx.rotate(diskRotDeg * Math.PI / 180);
      ctx.translate(-CX, -CY);
    }

    // 1. 静态盘面（离屏单次 blit，或直接矢量绘制）
    if (useCache && this.dialCanvas) {
      try {
        ctx.drawImage(this.dialCanvas, 0, 0, W, H);
      } catch (err) {
        this.useOffscreen = false;
        this.renderStaticDial(ctx, CX, CY, R, FS);
      }
    } else {
      this.renderStaticDial(ctx, CX, CY, R, FS);
    }

    // 2. 当前选中山向高光
    if (this.hoveredIndex >= 0 && this.layerConfig.mountains) {
      const m = MOUNTAINS_DATA[this.hoveredIndex];
      const sRad = this.deg2rad(m.deg - 7.5);
      const eRad = this.deg2rad(m.deg + 7.5);
      ctx.save();
      ctx.beginPath();
      ctx.arc(CX, CY, R.mountainRing, sRad, eRad);
      ctx.arc(CX, CY, R.postGuaRing, eRad, sRad, true);
      ctx.closePath();
      ctx.fillStyle = 'rgba(230, 126, 34, 0.85)';
      ctx.fill();
      ctx.strokeStyle = '#f39c12';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      const midRad = this.deg2rad(m.deg);
      ctx.translate(CX + Math.cos(midRad) * ((R.postGuaRing + R.mountainRing) / 2),
        CY + Math.sin(midRad) * ((R.postGuaRing + R.mountainRing) / 2));
      ctx.rotate(midRad + Math.PI / 2);
      ctx.fillStyle = '#ffffff';
      ctx.font = `bold ${FS.mountain}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(m.name, 0, 0);
      ctx.restore();
    }

    // 3. 实时北京时间红针 + 真太阳时金针
    if (this.layerConfig.timeDial) {
      this.drawTimeNeedles(ctx, CX, CY, R, FS);
    }

    // 4. 天池太极图
    this.drawTaiji(ctx, CX, CY, R.taiji);

    ctx.restore(); // 闭合盘面旋转

    // 5. 电子双轴水准仪气泡（屏幕固定参考系）
    if (this.layerConfig.bubbleLevel) {
      this.drawBubbleLevel(ctx, CX, CY, R, FS);
    }

    // 6. 磁北 / 真北双指针系统（屏幕固定参考系）
    this.drawDualCompassNeedles(ctx, CX, CY, R, FS, effectiveHeading);

    ctx.restore(); // 闭合视图缩放/平移
  },

  /**
   * 离屏预渲染静态盘面：八宫、二十四山、一百二十分金、节气、消息卦、时间刻度、六十四卦
   */
  renderStaticDial(c, CX, CY, R, FS) {
    const L = this.layerConfig;
    const HALF_SEG = 7.5;

    // ---- 1. 八卦八宫环与符号内环 ----
    if (L.palaces) {
      const palaces = this.data.currentMode === 'post' ? PALACES_POST : PALACES_PRE;
      for (let i = 0; i < 8; i++) {
        const p = palaces[i];
        const sRad = this.deg2rad(p.baseDeg - 22.5);
        const eRad = this.deg2rad(p.baseDeg + 22.5);
        c.beginPath();
        c.arc(CX, CY, R.postGuaRing, sRad, eRad);
        c.arc(CX, CY, R.preGuaRing, eRad, sRad, true);
        c.closePath();
        c.fillStyle = ELEM_BG_DARK[p.elem] || '#232533';
        c.fill();
        c.strokeStyle = '#2d3042';
        c.lineWidth = 1.5;
        c.stroke();

        const midRad = this.deg2rad(p.baseDeg);
        const tx = CX + Math.cos(midRad) * ((R.preGuaRing + R.postGuaRing) / 2);
        const ty = CY + Math.sin(midRad) * ((R.preGuaRing + R.postGuaRing) / 2);
        c.save();
        c.translate(tx, ty);
        c.rotate(midRad + Math.PI / 2);
        c.fillStyle = '#ffffff';
        c.font = `bold ${FS.palace}px sans-serif`;
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(`${p.name} ${p.symbol}`, 0, 0);
        c.restore();
      }
      // 八卦符号内环
      c.save();
      c.fillStyle = '#d4af37';
      c.font = `${FS.palaceSym}px sans-serif`;
      c.textAlign = 'center'; c.textBaseline = 'middle';
      for (let i = 0; i < 8; i++) {
        const p = palaces[i];
        const midRad = this.deg2rad(p.baseDeg);
        const tr = (R.taiji + R.preGuaRing) / 2;
        c.fillText(p.symbol, CX + Math.cos(midRad) * tr, CY + Math.sin(midRad) * tr);
      }
      c.restore();
    }

    // ---- 2. 二十四山环 ----
    if (L.mountains) {
      c.save();
      c.textAlign = 'center'; c.textBaseline = 'middle';
      for (let i = 0; i < 24; i++) {
        const m = MOUNTAINS_DATA[i];
        const sRad = this.deg2rad(m.deg - HALF_SEG);
        const eRad = this.deg2rad(m.deg + HALF_SEG);
        c.beginPath();
        c.arc(CX, CY, R.mountainRing, sRad, eRad);
        c.arc(CX, CY, R.postGuaRing, eRad, sRad, true);
        c.closePath();
        c.fillStyle = '#232533';
        c.fill();
        c.strokeStyle = '#383a4c'; c.lineWidth = 1; c.stroke();

        const midRad = this.deg2rad(m.deg);
        const tr = (R.postGuaRing + R.mountainRing) / 2;
        c.save();
        c.translate(CX + Math.cos(midRad) * tr, CY + Math.sin(midRad) * tr);
        c.rotate(midRad + Math.PI / 2);
        c.fillStyle = '#d1d5db';
        c.font = `bold ${FS.mountain}px sans-serif`;
        c.fillText(m.name, 0, 0);
        c.restore();
      }
      c.restore();
    }

    // ---- 3. 一百二十分金环（每山 5 分金，每位 3°，共 120 位）----
    if (L.fenjin) {
      const ringW = R.fenjinRing - R.mountainRing;
      c.save();
      c.textAlign = 'center'; c.textBaseline = 'middle';
      for (let k = 0; k < 120; k++) {
        const fDeg = 172.5 + k * 3;
        const sRad = this.deg2rad(fDeg);
        const eRad = this.deg2rad(fDeg + 3);
        const midRad = this.deg2rad(fDeg + 1.5);
        const name = JIAZI_60[k % 60];
        const stem = name[0];
        const isWangXiang = (stem === '丙' || stem === '丁' || stem === '庚' || stem === '辛');
        const isHuoKeng = (stem === '戊' || stem === '己');

        c.beginPath();
        c.arc(CX, CY, R.fenjinRing, sRad, eRad);
        c.arc(CX, CY, R.mountainRing, eRad, sRad, true);
        c.closePath();
        c.fillStyle = isWangXiang ? 'rgba(212, 175, 55, 0.25)' : (isHuoKeng ? 'rgba(192, 57, 43, 0.18)' : '#161823');
        c.fill();
        c.strokeStyle = isWangXiang ? 'rgba(212, 175, 55, 0.6)' : '#2a2c3d';
        c.lineWidth = 0.6;
        c.stroke();

        const tr = (R.mountainRing + R.fenjinRing) / 2;
        c.save();
        c.translate(CX + Math.cos(midRad) * tr, CY + Math.sin(midRad) * tr);
        // 120 分金每格仅占 3°，切向排布必然重叠，故采用径向排布保证可读
        c.rotate(midRad);
        if (isWangXiang) {
          c.fillStyle = '#ffd166';
          c.font = `bold ${FS.fenjin}px sans-serif`;
          c.fillText(name, 0, 0);
          c.beginPath();
          c.arc(-(ringW / 2) + 3, 0, 1.6, 0, Math.PI * 2);
          c.fillStyle = '#f1c40f';
          c.fill();
        } else if (isHuoKeng) {
          c.fillStyle = '#e74c3c';
          c.font = `${FS.fenjin}px sans-serif`;
          c.fillText(name, 0, 0);
        } else {
          c.fillStyle = '#5a5d6e';
          c.font = `${FS.fenjin}px sans-serif`;
          c.fillText(name, 0, 0);
        }
        c.restore();
      }
      c.restore();
    }

    // ---- 4. 二十四节气环与十二消息卦外环 ----
    if (L.solarRing) {
      c.save();
      c.textAlign = 'center'; c.textBaseline = 'middle';
      for (let i = 0; i < 24; i++) {
        const m = MOUNTAINS_DATA[i];
        const sRad = this.deg2rad(m.deg - HALF_SEG);
        const eRad = this.deg2rad(m.deg + HALF_SEG);
        c.beginPath();
        c.arc(CX, CY, R.solarRing, sRad, eRad);
        c.arc(CX, CY, R.fenjinRing, eRad, sRad, true);
        c.closePath();
        c.fillStyle = '#1f202b';
        c.fill();
        c.strokeStyle = '#383a4c'; c.stroke();

        const midRad = this.deg2rad(m.deg);
        const tr = (R.fenjinRing + R.solarRing) / 2;
        c.save();
        c.translate(CX + Math.cos(midRad) * tr, CY + Math.sin(midRad) * tr);
        c.rotate(midRad + Math.PI / 2);
        c.fillStyle = '#9ca3af';
        c.font = `${FS.solar}px sans-serif`;
        c.fillText(m.solar, 0, 0);
        c.restore();
      }

      const hexMid = (R.solarRing + R.hexRing) / 2;
      const nameOff = -18 * R.s; // 卦名向外
      const hexOff = 13 * R.s;   // 六爻向内
      const hexW = Math.max(9, Math.round(20 * R.s * 1.5));
      for (let i = 0; i < 24; i++) {
        const m = MOUNTAINS_DATA[i];
        const sRad = this.deg2rad(m.deg - HALF_SEG);
        const eRad = this.deg2rad(m.deg + HALF_SEG);
        c.beginPath();
        c.arc(CX, CY, R.hexRing, sRad, eRad);
        c.arc(CX, CY, R.solarRing, eRad, sRad, true);
        c.closePath();
        c.fillStyle = '#171821';
        c.fill();
        c.strokeStyle = '#383a4c'; c.stroke();

        const midRad = this.deg2rad(m.deg);
        c.save();
        c.translate(CX + Math.cos(midRad) * hexMid, CY + Math.sin(midRad) * hexMid);
        c.rotate(midRad + Math.PI / 2);
        c.fillStyle = '#7f8c8d';
        c.font = `${FS.hexName}px sans-serif`;
        c.fillText(m.gua, 0, nameOff);
        this.drawHexagram(c, m.lines, 0, hexOff, hexW);
        c.restore();
      }
      c.restore();
    }

    // ---- 5. 24 小时制时间刻度环 ----
    if (L.timeDial) {
      c.beginPath();
      c.arc(CX, CY, R.timeOut, 0, Math.PI * 2);
      c.arc(CX, CY, R.timeIn, 0, Math.PI * 2, true);
      c.closePath();
      c.fillStyle = '#111219';
      c.fill();
      c.strokeStyle = '#2d3042'; c.lineWidth = 1; c.stroke();

      for (let h = 0; h < 24; h++) {
        const deg = ((h - 12 + 24) % 24) * 15;
        const rad = this.deg2rad(deg);
        const major = (h % 3 === 0);
        const tickEnd = major ? R.timeOut - 8 * R.s : R.timeOut - 16 * R.s;
        c.beginPath();
        c.moveTo(CX + Math.cos(rad) * R.timeIn, CY + Math.sin(rad) * R.timeIn);
        c.lineTo(CX + Math.cos(rad) * tickEnd, CY + Math.sin(rad) * tickEnd);
        c.strokeStyle = major ? '#d4af37' : '#5a5d6e';
        c.lineWidth = major ? 2 : 1;
        c.stroke();

        const lr = R.timeOut - 24 * R.s;
        c.fillStyle = major ? '#d4af37' : '#9a9daa';
        c.font = major ? `bold ${FS.timeMajor}px sans-serif` : `${FS.timeMinor}px sans-serif`;
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(h.toString(), CX + Math.cos(rad) * lr, CY + Math.sin(rad) * lr);
      }
    }

    // ---- 6. 先天六十四卦圆图 ----
    if (L.hex64) {
      c.beginPath();
      c.arc(CX, CY, R.gua64Out, 0, Math.PI * 2);
      c.arc(CX, CY, R.gua64In, 0, Math.PI * 2, true);
      c.closePath();
      c.fillStyle = '#0e0f16';
      c.fill();
      c.strokeStyle = '#2d3042'; c.lineWidth = 1; c.stroke();

      const midR = (R.gua64In + R.gua64Out) / 2;
      const hexOff = 8 * R.s;    // 局部 +y 指向圆心
      const nameOff = 14 * R.s;
      const hexW = Math.max(7, Math.round(10 * R.s * 1.9));
      for (let i = 0; i < 64; i++) {
        const g = HEXAGRAMS_64[i];
        const deg = i * GUA64_STEP;
        const sRad = this.deg2rad(deg - GUA64_HALF);
        const eRad = this.deg2rad(deg + GUA64_HALF);
        const isYang = (i === 0 || i >= 33);
        c.beginPath();
        c.arc(CX, CY, R.gua64Out, sRad, eRad);
        c.arc(CX, CY, R.gua64In, eRad, sRad, true);
        c.closePath();
        c.fillStyle = isYang ? '#161822' : '#101118';
        c.fill();
        c.strokeStyle = '#2a2c3c'; c.lineWidth = 0.5; c.stroke();

        const midRad = this.deg2rad(deg);
        c.save();
        c.translate(CX + Math.cos(midRad) * midR, CY + Math.sin(midRad) * midR);
        c.rotate(midRad + Math.PI / 2);
        this.drawHexagram(c, g.l, 0, hexOff, hexW);
        c.fillStyle = isYang ? '#c8b88a' : '#8a8a9a';
        c.font = `${FS.gua64}px sans-serif`;
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(g.n, 0, -nameOff);
        c.restore();
      }
      // 八宫分界线
      for (let k = 1; k <= 8; k++) {
        const rad = this.deg2rad(k * 45 - GUA64_HALF);
        c.beginPath();
        c.moveTo(CX + Math.cos(rad) * R.gua64In, CY + Math.sin(rad) * R.gua64In);
        c.lineTo(CX + Math.cos(rad) * R.gua64Out, CY + Math.sin(rad) * R.gua64Out);
        c.strokeStyle = '#4a4d5e'; c.lineWidth = 1.2; c.stroke();
      }
    }

    // ---- 7. 今日当令之山金色弧 ----
    if (this.currentIndex >= 0 && L.mountains) {
      const m = MOUNTAINS_DATA[this.currentIndex];
      const sRad = this.deg2rad(m.deg - HALF_SEG);
      const eRad = this.deg2rad(m.deg + HALF_SEG);
      c.beginPath();
      c.arc(CX, CY, R.hexRing + 5 * R.s, sRad, eRad);
      c.arc(CX, CY, R.hexRing + 2 * R.s, eRad, sRad, true);
      c.closePath();
      c.fillStyle = 'rgba(212, 175, 55, 0.35)';
      c.fill();
      c.strokeStyle = '#d4af37'; c.lineWidth = 2.5; c.stroke();
    }
  },

  drawTimeNeedles(ctx, CX, CY, R, FS) {
    const now = new Date();
    const pStart = R.taiji + 4 * R.s;
    const pEnd = R.timeOut - 6 * R.s;

    // A. 当前实时北京时间红针
    const nowDeg = (((now.getHours() - 12 + 24) % 24) * 15) + now.getMinutes() * 0.25;
    const nowRad = this.deg2rad(nowDeg);
    const nowHour = Math.floor(nowDeg / 15) % 24;
    const hourDeg = nowHour * 15;
    ctx.beginPath();
    ctx.arc(CX, CY, R.timeOut, this.deg2rad(hourDeg - 7.5), this.deg2rad(hourDeg + 7.5));
    ctx.arc(CX, CY, R.timeIn, this.deg2rad(hourDeg + 7.5), this.deg2rad(hourDeg - 7.5), true);
    ctx.closePath();
    ctx.fillStyle = 'rgba(231, 76, 60, 0.18)';
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(nowRad) * pStart, CY + Math.sin(nowRad) * pStart);
    ctx.lineTo(CX + Math.cos(nowRad) * pEnd, CY + Math.sin(nowRad) * pEnd);
    ctx.strokeStyle = 'rgba(231, 76, 60, 0.85)';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(CX + Math.cos(nowRad) * pEnd, CY + Math.sin(nowRad) * pEnd, 5.5, 0, Math.PI * 2);
    ctx.fillStyle = '#e74c3c';
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // B. 真太阳时金针（读取每秒缓存，避免每帧重复 Spencer 三角函数运算）
    const solarTime = this.cachedTrueSolarTime || calculateTrueSolarTime(this.currentLongitude, now);
    const solarRad = this.deg2rad(solarTime.solarDeg);
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(solarRad) * (pStart + 8 * R.s), CY + Math.sin(solarRad) * (pStart + 8 * R.s));
    ctx.lineTo(CX + Math.cos(solarRad) * (R.timeOut - 4 * R.s), CY + Math.sin(solarRad) * (R.timeOut - 4 * R.s));
    ctx.strokeStyle = 'rgba(241, 196, 15, 0.9)';
    ctx.lineWidth = 1.6;
    if (typeof ctx.setLineDash === 'function') ctx.setLineDash([3, 2]);
    ctx.stroke();
    if (typeof ctx.setLineDash === 'function') ctx.setLineDash([]);

    ctx.beginPath();
    ctx.arc(CX + Math.cos(solarRad) * (R.timeOut - 4 * R.s), CY + Math.sin(solarRad) * (R.timeOut - 4 * R.s),
      4, 0, Math.PI * 2);
    ctx.fillStyle = '#f1c40f';
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();

    // 中心轴点
    ctx.beginPath();
    ctx.arc(CX, CY, 4, 0, Math.PI * 2);
    ctx.fillStyle = '#e74c3c';
    ctx.fill();
  },

  drawTaiji(ctx, CX, CY, r) {
    ctx.save();
    ctx.translate(CX, CY);
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fillStyle = '#f5f5ef';
    ctx.fill();
    ctx.strokeStyle = '#444';
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(0, 0, r, Math.PI / 2, Math.PI * 1.5, true); // 右半为阴
    ctx.closePath();
    ctx.fillStyle = '#141414';
    ctx.fill();

    ctx.beginPath();
    ctx.arc(0, -r / 2, r / 2, 0, Math.PI * 2); // 阳鱼头在上
    ctx.fillStyle = '#f5f5ef';
    ctx.fill();

    ctx.beginPath();
    ctx.arc(0, r / 2, r / 2, 0, Math.PI * 2); // 阴鱼头在下
    ctx.fillStyle = '#141414';
    ctx.fill();

    ctx.beginPath();
    ctx.arc(0, -r / 2, r / 6, 0, Math.PI * 2); // 阳中含阴
    ctx.fillStyle = '#141414';
    ctx.fill();

    ctx.beginPath();
    ctx.arc(0, r / 2, r / 6, 0, Math.PI * 2); // 阴中含阳
    ctx.fillStyle = '#f5f5ef';
    ctx.fill();
    ctx.restore();
  },

  /**
   * 电子双轴太极水准仪气泡（屏幕固定参考系，位于太极天心处）
   */
  drawBubbleLevel(ctx, CX, CY, R, FS) {
    const rTaiji = R.taiji;
    ctx.save();

    // 基准十字微刻线
    ctx.beginPath();
    ctx.moveTo(CX - rTaiji * 0.65, CY); ctx.lineTo(CX + rTaiji * 0.65, CY);
    ctx.moveTo(CX, CY - rTaiji * 0.65); ctx.lineTo(CX, CY + rTaiji * 0.65);
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
    ctx.lineWidth = 0.8;
    ctx.stroke();

    // 2.5° 精密平水合格圈
    ctx.beginPath();
    ctx.arc(CX, CY, rTaiji * 0.38, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(46, 204, 113, 0.55)';
    ctx.lineWidth = 1.2;
    if (typeof ctx.setLineDash === 'function') ctx.setLineDash([2, 2]);
    ctx.stroke();

    // 7.0° 倾角警戒圈
    ctx.beginPath();
    ctx.arc(CX, CY, rTaiji * 0.72, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(241, 196, 15, 0.35)';
    ctx.lineWidth = 1;
    ctx.stroke();
    if (typeof ctx.setLineDash === 'function') ctx.setLineDash([]);

    // 物理倾角映射气泡位移
    const maxTilt = 12;
    const maxOffset = rTaiji * 0.65;
    const bx = CX + Math.max(-1, Math.min(1, this.currentRoll / maxTilt)) * maxOffset;
    const by = CY - Math.max(-1, Math.min(1, this.currentPitch / maxTilt)) * maxOffset;
    const tiltMag = Math.sqrt(this.currentPitch * this.currentPitch + this.currentRoll * this.currentRoll);

    const isPerfect = tiltMag < 2.5;
    const isModerate = tiltMag >= 2.5 && tiltMag < 7.0;
    const bubbleColor = isPerfect ? '#2ecc71' : (isModerate ? '#f39c12' : '#ff5252');

    ctx.beginPath();
    ctx.arc(bx, by, 7.5, 0, Math.PI * 2);
    ctx.fillStyle = isPerfect ? 'rgba(46, 204, 113, 0.35)' : (isModerate ? 'rgba(243, 156, 18, 0.35)' : 'rgba(255, 82, 82, 0.35)');
    ctx.fill();

    ctx.beginPath();
    ctx.arc(bx, by, 5.5, 0, Math.PI * 2);
    ctx.fillStyle = bubbleColor;
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(bx - 1.5, by - 1.5, 1.5, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();

    ctx.fillStyle = bubbleColor;
    ctx.font = `bold ${FS.label}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(isPerfect ? '✓水平' : `${tiltMag.toFixed(1)}°`, CX, CY + rTaiji - 7);

    ctx.restore();
  },

  /**
   * 磁北（绿·磁）与地理真北（金·真）双指针系统
   */
  drawDualCompassNeedles(ctx, CX, CY, R, FS, effectiveHeading) {
    if (effectiveHeading === null || effectiveHeading === undefined) return;

    const magNorthDeg = (360 - (effectiveHeading % 360)) % 360;
    const magRad = this.deg2rad(magNorthDeg);

    const trueHeading = ((effectiveHeading + this.currentDeclination) % 360 + 360) % 360;
    const trueNorthDeg = (360 - trueHeading) % 360;
    const trueRad = this.deg2rad(trueNorthDeg);

    // 地磁偏角虚线弧与度数
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
      if (typeof ctx.setLineDash === 'function') ctx.setLineDash([2, 3]);
      ctx.stroke();
      ctx.restore();

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

    // 磁北南端尾翼
    const magSouthRad = magRad + Math.PI;
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(magSouthRad) * (R.taiji + 6 * R.s), CY + Math.sin(magSouthRad) * (R.taiji + 6 * R.s));
    ctx.lineTo(CX + Math.cos(magSouthRad) * (R.taiji + 18 * R.s), CY + Math.sin(magSouthRad) * (R.taiji + 18 * R.s));
    ctx.strokeStyle = 'rgba(39, 174, 96, 0.7)';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.stroke();

    // 真北南端尾翼
    const trueSouthRad = trueRad + Math.PI;
    ctx.beginPath();
    ctx.moveTo(CX + Math.cos(trueSouthRad) * (R.taiji + 6 * R.s), CY + Math.sin(trueSouthRad) * (R.taiji + 6 * R.s));
    ctx.lineTo(CX + Math.cos(trueSouthRad) * (R.taiji + 15 * R.s), CY + Math.sin(trueSouthRad) * (R.taiji + 15 * R.s));
    ctx.strokeStyle = 'rgba(212, 175, 55, 0.6)';
    ctx.lineWidth = 1.5;
    ctx.lineCap = 'round';
    ctx.stroke();

    // 磁北针（标“磁”）
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

      ctx.fillStyle = '#ffffff';
      ctx.font = `bold ${FS.label}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('磁', ax - Math.cos(magRad) * labelBack, ay - Math.sin(magRad) * labelBack);
    }

    // 真北针（标“真”）
    {
      const pStart = R.taiji + 6 * R.s;
      const pEnd = R.postGuaRing - 14 * R.s;
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

      ctx.fillStyle = '#2c1e02';
      ctx.font = `bold ${FS.label}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('真', ax - Math.cos(trueRad) * labelBack, ay - Math.sin(trueRad) * labelBack);
    }
  }
});

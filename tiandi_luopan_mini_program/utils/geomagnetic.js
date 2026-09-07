/**
 * geomagnetic.js
 * 纯 JS 离线全球地磁模型（与 Android 官方 GeomagneticField.java 100% 算法完全对齐）
 * 基于 NOAA / NGA World Magnetic Model (WMM 2020-2025)
 * 无需联网，输入经纬度、海拔及时间，离线解算：
 *   磁偏角 Declination / 磁倾角 Inclination / 磁场总强度 FieldStrength
 *   水平强度 HorizontalStrength / 北向 X / 东向 Y / 垂直 Z
 */

const G_COEFF = [
  [0.0],
  [-29404.5, -1450.7],
  [-2500.0, 2982.0, 1676.8],
  [1363.9, -2381.0, 1236.2, 525.7],
  [903.1, 809.4, 86.2, -309.4, 47.9],
  [-234.4, 363.1, 187.8, -140.7, -151.2, 13.7],
  [65.9, 65.6, 73.0, -121.5, -36.2, 13.5, -64.7],
  [80.6, -76.8, -8.3, 56.5, 15.8, 6.4, -7.2, 9.8],
  [23.6, 9.8, -17.5, -0.4, -21.1, 15.3, 13.7, -16.5, -0.3],
  [5.0, 8.2, 2.9, -1.4, -1.1, -13.3, 1.1, 8.9, -9.3, -11.9],
  [-1.9, -6.2, -0.1, 1.7, -0.9, 0.6, -0.9, 1.9, 1.4, -2.4, -3.9],
  [3.0, -1.4, -2.5, 2.4, -0.9, 0.3, -0.7, -0.1, 1.4, -0.6, 0.2, 3.1],
  [-2.0, -0.1, 0.5, 1.3, -1.2, 0.7, 0.3, 0.5, -0.2, -0.5, 0.1, -1.1, -0.3]
];

const H_COEFF = [
  [0.0],
  [0.0, 4652.9],
  [0.0, -2991.6, -734.8],
  [0.0, -82.2, 241.8, -542.9],
  [0.0, 282.0, -158.4, 199.8, -350.1],
  [0.0, 47.7, 208.4, -121.3, 32.2, 99.1],
  [0.0, -19.1, 25.0, 52.7, -64.4, 9.0, 68.1],
  [0.0, -51.4, -16.8, 2.3, 23.5, -2.2, -27.2, -1.9],
  [0.0, 8.4, -15.3, 12.8, -11.8, 14.9, 3.6, -6.9, 2.8],
  [0.0, -23.3, 11.1, 9.8, -5.1, -6.2, 7.8, 0.4, -1.5, 9.7],
  [0.0, 3.4, -0.2, 3.5, 4.8, -8.6, -0.1, -4.2, -3.4, -0.1, -8.8],
  [0.0, 0.0, 2.6, -0.5, -0.4, 0.6, -0.2, -1.7, -1.6, -3.0, -2.0, -2.6],
  [0.0, -1.2, 0.5, 1.3, -1.8, 0.1, 0.7, -0.1, 0.6, 0.2, -0.9, 0.0, 0.5]
];

const DELTA_G = [
  [0.0],
  [6.7, 7.7],
  [-11.5, -7.1, -2.2],
  [2.8, -6.2, 3.4, -12.2],
  [-1.1, -1.6, -6.0, 5.4, -5.5],
  [-0.3, 0.6, -0.7, 0.1, 1.2, 1.0],
  [-0.6, -0.4, 0.5, 1.4, -1.4, 0.0, 0.8],
  [-0.1, -0.3, -0.1, 0.7, 0.2, -0.5, -0.8, 1.0],
  [-0.1, 0.1, -0.1, 0.5, -0.1, 0.4, 0.5, 0.0, 0.4],
  [-0.1, -0.2, 0.0, 0.4, -0.3, 0.0, 0.3, 0.0, 0.0, -0.4],
  [0.0, 0.0, 0.0, 0.2, -0.1, -0.2, 0.0, -0.1, -0.2, -0.1, 0.0],
  [0.0, -0.1, 0.0, 0.0, 0.0, -0.1, 0.0, 0.0, -0.1, -0.1, -0.1, -0.1],
  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.1]
];

const DELTA_H = [
  [0.0],
  [0.0, -25.1],
  [0.0, -30.2, -23.9],
  [0.0, 5.7, -1.0, 1.1],
  [0.0, 0.2, 6.9, 3.7, -5.6],
  [0.0, 0.1, 2.5, -0.9, 3.0, 0.5],
  [0.0, 0.1, -1.8, -1.4, 0.9, 0.1, 1.0],
  [0.0, 0.5, 0.6, -0.7, -0.2, -1.2, 0.2, 0.3],
  [0.0, -0.3, 0.7, -0.2, 0.5, -0.3, -0.5, 0.4, 0.1],
  [0.0, -0.3, 0.2, -0.4, 0.4, 0.1, 0.0, -0.2, 0.5, 0.2],
  [0.0, 0.0, 0.1, -0.3, 0.1, -0.2, 0.1, 0.0, -0.1, 0.2, 0.0],
  [0.0, 0.0, 0.1, 0.0, 0.2, 0.0, 0.0, 0.1, 0.0, -0.1, 0.0, 0.0],
  [0.0, 0.0, 0.0, -0.1, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, -0.1]
];

const BASE_TIME = Date.UTC(2020, 0, 1);
const EARTH_SEMI_MAJOR_AXIS_KM = 6378.137;
const EARTH_SEMI_MINOR_AXIS_KM = 6356.7523142;
const EARTH_REFERENCE_RADIUS_KM = 6371.2;

function computeSchmidtQuasiNormFactors(maxN) {
  const factors = [];
  factors[0] = [1.0];
  for (let n = 1; n <= maxN; n++) {
    factors[n] = new Float32Array(n + 1);
    factors[n][0] = factors[n - 1][0] * (2 * n - 1) / n;
    for (let m = 1; m <= n; m++) {
      factors[n][m] = factors[n][m - 1] * Math.sqrt((n - m + 1) * (m === 1 ? 2 : 1) / (n + m));
    }
  }
  return factors;
}

const SCHMIDT_FACTORS = computeSchmidtQuasiNormFactors(G_COEFF.length);

class LegendreTable {
  constructor(maxN, thetaRad) {
    const cos = Math.cos(thetaRad);
    const sin = Math.sin(thetaRad);
    this.mP = [];
    this.mPDeriv = [];
    this.mP[0] = [1.0];
    this.mPDeriv[0] = [0.0];
    for (let n = 1; n <= maxN; n++) {
      this.mP[n] = new Float32Array(n + 1);
      this.mPDeriv[n] = new Float32Array(n + 1);
      for (let m = 0; m <= n; m++) {
        if (n === m) {
          this.mP[n][m] = sin * this.mP[n - 1][m - 1];
          this.mPDeriv[n][m] = cos * this.mP[n - 1][m - 1] + sin * this.mPDeriv[n - 1][m - 1];
        } else if (n === 1 || m === n - 1) {
          this.mP[n][m] = cos * this.mP[n - 1][m];
          this.mPDeriv[n][m] = -sin * this.mP[n - 1][m] + cos * this.mPDeriv[n - 1][m];
        } else {
          const k = ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          this.mP[n][m] = cos * this.mP[n - 1][m] - k * this.mP[n - 2][m];
          this.mPDeriv[n][m] = -sin * this.mP[n - 1][m] + cos * this.mPDeriv[n - 1][m] - k * this.mPDeriv[n - 2][m];
        }
      }
    }
  }
}

function normalizeTimeMillis(timeMillis) {
  if (typeof timeMillis === 'object' && timeMillis !== null && timeMillis.getTime) {
    return timeMillis.getTime();
  }
  return Number(timeMillis);
}

/**
 * 完整解算任意坐标点的地磁七要素
 * @param {number} gdLatitudeDeg 纬度 (-90 ~ 90)
 * @param {number} gdLongitudeDeg 经度 (-180 ~ 180)
 * @param {number} altitudeMeters 海拔 (m)
 * @param {Date|number} timeMillis 评估时间点
 * @returns {{x:number, y:number, z:number, declination:number, inclination:number,
 *            horizontalStrength:number, fieldStrength:number}}
 *          分量单位为 nT；角度单位为度（磁偏角负=西偏，正=东偏）
 */
function computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  timeMillis = normalizeTimeMillis(timeMillis);

  gdLatitudeDeg = Math.min(90.0 - 1e-5, Math.max(-90.0 + 1e-5, Number(gdLatitudeDeg)));
  gdLongitudeDeg = Number(gdLongitudeDeg);
  const altitudeKm = (Number(altitudeMeters) || 0) / 1000.0;

  const a2 = EARTH_SEMI_MAJOR_AXIS_KM * EARTH_SEMI_MAJOR_AXIS_KM;
  const b2 = EARTH_SEMI_MINOR_AXIS_KM * EARTH_SEMI_MINOR_AXIS_KM;
  const gdLatRad = gdLatitudeDeg * Math.PI / 180.0;
  const clat = Math.cos(gdLatRad);
  const slat = Math.sin(gdLatRad);
  const tlat = slat / clat;
  const latRad = Math.sqrt(a2 * clat * clat + b2 * slat * slat);

  const mGcLatitudeRad = Math.atan(tlat * (latRad * altitudeKm + b2) / (latRad * altitudeKm + a2));
  const mGcLongitudeRad = gdLongitudeDeg * Math.PI / 180.0;
  const radSq = altitudeKm * altitudeKm
    + 2 * altitudeKm * Math.sqrt(a2 * clat * clat + b2 * slat * slat)
    + (a2 * a2 * clat * clat + b2 * b2 * slat * slat) / (a2 * clat * clat + b2 * slat * slat);
  const mGcRadiusKm = Math.sqrt(radSq);

  const MAX_N = G_COEFF.length;
  const legendre = new LegendreTable(MAX_N - 1, Math.PI / 2.0 - mGcLatitudeRad);

  const relativeRadiusPower = new Float32Array(MAX_N + 2);
  relativeRadiusPower[0] = 1.0;
  relativeRadiusPower[1] = EARTH_REFERENCE_RADIUS_KM / mGcRadiusKm;
  for (let i = 2; i < relativeRadiusPower.length; ++i) {
    relativeRadiusPower[i] = relativeRadiusPower[i - 1] * relativeRadiusPower[1];
  }

  const sinMLon = new Float32Array(MAX_N);
  const cosMLon = new Float32Array(MAX_N);
  sinMLon[0] = 0.0;
  cosMLon[0] = 1.0;
  sinMLon[1] = Math.sin(mGcLongitudeRad);
  cosMLon[1] = Math.cos(mGcLongitudeRad);
  for (let m = 2; m < MAX_N; ++m) {
    const x = m >> 1;
    sinMLon[m] = sinMLon[m - x] * cosMLon[x] + cosMLon[m - x] * sinMLon[x];
    cosMLon[m] = cosMLon[m - x] * cosMLon[x] - sinMLon[m - x] * sinMLon[x];
  }

  const inverseCosLatitude = 1.0 / Math.cos(mGcLatitudeRad);
  const yearsSinceBase = (timeMillis - BASE_TIME) / (365 * 24 * 60 * 60 * 1000);

  let gcX = 0.0;
  let gcY = 0.0;
  let gcZ = 0.0;

  for (let n = 1; n < MAX_N; n++) {
    for (let m = 0; m <= n; m++) {
      const g = G_COEFF[n][m] + yearsSinceBase * DELTA_G[n][m];
      const h = H_COEFF[n][m] + yearsSinceBase * DELTA_H[n][m];

      gcX += relativeRadiusPower[n + 2]
        * (g * cosMLon[m] + h * sinMLon[m])
        * legendre.mPDeriv[n][m]
        * SCHMIDT_FACTORS[n][m];

      gcY += relativeRadiusPower[n + 2] * m
        * (g * sinMLon[m] - h * cosMLon[m])
        * legendre.mP[n][m]
        * SCHMIDT_FACTORS[n][m]
        * inverseCosLatitude;

      gcZ -= (n + 1) * relativeRadiusPower[n + 2]
        * (g * cosMLon[m] + h * sinMLon[m])
        * legendre.mP[n][m]
        * SCHMIDT_FACTORS[n][m];
    }
  }

  // 地心坐标 → 大地坐标：绕 Y 轴旋转 latDiff 角
  // 严格对齐 AOSP GeomagneticField 构造器：
  //   mX =  gcX*cos(latDiff) + gcZ*sin(latDiff)
  //   mY =  gcY
  //   mZ = -gcX*sin(latDiff) + gcZ*cos(latDiff)
  const latDiffRad = gdLatRad - mGcLatitudeRad;
  const x = gcX * Math.cos(latDiffRad) + gcZ * Math.sin(latDiffRad);
  const y = gcY;
  const z = -gcX * Math.sin(latDiffRad) + gcZ * Math.cos(latDiffRad);

  const horizontalStrength = Math.sqrt(x * x + y * y);
  const fieldStrength = Math.sqrt(x * x + y * y + z * z);

  return {
    x, y, z,                                                       // nT：北向 / 东向 / 垂直向下
    declination: Math.atan2(y, x) * 180.0 / Math.PI,               // 磁偏角（负=西偏）
    inclination: Math.atan2(z, horizontalStrength) * 180.0 / Math.PI, // 磁倾角
    horizontalStrength,
    fieldStrength
  };
}

/**
 * 计算地磁偏角（度，负数=西偏，正数=东偏），保留一位小数
 */
function computeDeclination(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  const f = computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters, timeMillis);
  return Math.round(f.declination * 10) / 10;
}

/**
 * 计算磁场总强度（μT）
 */
function computeFieldStrength(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  const f = computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters, timeMillis);
  return Math.round((f.fieldStrength / 1000) * 10) / 10; // nT → μT
}

/**
 * 格式化输出偏角与坐标描述
 */
function formatLocationAndDeclination(latitude, longitude, altitudeMeters, declination) {
  const lat = Number(latitude);
  const lon = Number(longitude);
  const latStr = `${Math.abs(lat).toFixed(4)}°${lat >= 0 ? 'N' : 'S'}`;
  const lonStr = `${Math.abs(lon).toFixed(4)}°${lon >= 0 ? 'E' : 'W'}`;
  const altStr = (altitudeMeters !== undefined && altitudeMeters !== null && !isNaN(altitudeMeters) && altitudeMeters !== 0)
    ? ` · 海拔 ${Math.round(altitudeMeters)}m`
    : '';
  const dirStr = declination < 0 ? '西偏' : (declination > 0 ? '东偏' : '无偏');
  const declText = `${dirStr}${Math.abs(declination).toFixed(1)}°`;

  return {
    coordsDesc: `${latStr}, ${lonStr}${altStr}`,
    declText,
    dirStr,
    declAbs: Math.abs(declination).toFixed(1)
  };
}

module.exports = {
  computeGeomagneticField,
  computeDeclination,
  computeFieldStrength,
  formatLocationAndDeclination
};

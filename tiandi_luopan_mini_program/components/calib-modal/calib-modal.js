/**
 * components/calib-modal/calib-modal.js
 * 罗盘双针与地磁偏角校准弹窗
 *
 * 该组件被配置为「用时注入」组件（见 pages/index/index.json 的 componentPlaceholder）：
 * 页面通过 wx:if 控制挂载，用户首次点开弹窗前，本组件的代码不会被注入与执行。
 */

Component({
  options: {
    // 允许页面（外部）样式影响组件内部，便于与页面整体暗金风格保持一致
    styleIsolation: 'apply-shared'
  },

  properties: {
    // 地磁传感器精度等级样式后缀：'' | 'med' | 'low'
    accClass: {
      type: String,
      value: ''
    },
    // 地磁传感器精度文案
    accuracyText: {
      type: String,
      value: '✓ 极高 (已自动校准)'
    },
    // 经纬度坐标描述
    coordsDesc: {
      type: String,
      value: '正在获取GPS定位…'
    },
    // 地磁偏角描述
    declDesc: {
      type: String,
      value: '正在获取GPS定位…'
    }
  },

  methods: {
    onClose() {
      this.triggerEvent('close');
    },

    onReset() {
      this.triggerEvent('reset');
    },

    // 阻止点击冒泡到遮罩层导致误关闭
    preventBubble() {}
  }
});

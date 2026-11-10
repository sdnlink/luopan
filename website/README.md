# 官网源码与发布

`website/` 是 sdnlink.cn 的唯一网站源码。网站的六类页面均拆分为八种语言的独立 HTML，并统一引用同一份样式和语言导航脚本。

```text
website/
├── index.html                 旧首页兼容入口
├── appstore-marketing.html    旧产品介绍兼容入口
├── privacy.html               App Store 隐私政策兼容入口
├── subscription-terms.html    App Store EULA 兼容入口
├── support.html               App Store 服务支持兼容入口
├── contact.html               联系我们兼容入口
├── i18n/
│   ├── zh-CN/                 简体中文
│   ├── zh-TW/                 繁体中文
│   ├── en/                    英文
│   ├── ja/                    日文
│   ├── ko/                    韩文
│   ├── vi/                    越南文
│   ├── id/                    印尼文
│   └── th/                    泰文
│       ├── index.html
│       ├── appstore-marketing.html
│       ├── privacy.html
│       ├── subscription-terms.html
│       ├── support.html
│       └── contact.html
├── favicon.ico                浏览器默认图标
└── assets/
    ├── site.css               所有页面及语言共用样式
    ├── site.js                语言链接偏好与旧入口跳转
    ├── icon.png               品牌图标，512 × 512
    ├── icon-192.png           192 × 192 图标
    ├── apple-touch-icon.png   Apple 触屏图标，180 × 180
    ├── favicon-32x32.png      浏览器 PNG 图标
    └── favicon-16x16.png      浏览器 PNG 图标
```

48 个独立语言页面直接包含对应语言的完整内容，关闭 JavaScript 也能阅读和通过语言菜单切换。切换时保留页面类型，例如从英文隐私页切换日文会打开 `/i18n/ja/privacy.html`。导航、页脚、字体、颜色、卡片、文档和响应式布局共用 `assets/site.css`；不要在各语言页复制样式。

六个根地址保留兼容入口：优先使用 `?lang=en` 或旧语言锚点（例如 `#en`），其次使用用户保存的选择，再匹配浏览器语言，不支持的语言默认简体中文。脚本不可用时，入口仍提供八种语言的直接链接。独立语言 URL 不会被浏览器偏好自动改写。顶部导航统一为首页、产品介绍、服务与支持、隐私政策、订阅条款、联系我们；宽屏并排，中等宽度换行，手机按三列两行排列。页脚保留网站和 App 备案号及工信部查询链接。

各页内容范围：

| 页面 | 正文内容 |
| --- | --- |
| 首页 | 公司及应用概览、主要页面入口 |
| 产品介绍 | 产品功能、设备要求和使用范围 |
| 服务与支持 | 操作指引、购买恢复、权限及常见问题 |
| 隐私政策 | 资料、权限、保存、同步与删除政策 |
| 订阅条款 | 购买权益、续期、退款规则、服务条款及 EULA |
| 联系我们 | 邮箱、电话、公司名称和联系地址 |

通用联系方式集中在联系页；隐私政策和 EULA 内的必要开发者联系条款完整保留。

图标按尺寸只保留一份，`favicon.ico` 按浏览器约定放在网站根路径。移动应用自己的 AppIcon 资源和 PWA 图标按各平台打包规则维护。

## 预览和打包

在仓库根目录预览：

```sh
python3 -m http.server 8000 --directory website
```

检查与打包：

```sh
python3 tools/package_website.py --check
python3 -m unittest discover -s tools -p 'test_package_website.py'
python3 tools/package_website.py
```

打包工具检查 48 个语言页面、六个兼容入口、资源、内部链接、语言切换及重复图标，生成 `dist/sdnlink-website.zip`。发布包包含所有网页、共享 CSS/JS、图标、SHA-256 清单及发布说明；开发记录、应用源码和本 README 不会进入网站包。

发布包中的文件权限为 `644`、目录权限为 `755`。解压工具可能保留服务器上已有目录的权限，必要时在服务器网站根目录执行：

```sh
find assets i18n -type d -exec chmod 755 {} +
find assets i18n -type f -exec chmod 644 {} +
chmod 644 *.html favicon.ico
```

## 手动发布

1. 备份服务器上的现有网站文件。
2. 将发布包全部内容解压到 sdnlink.cn 的静态站点根目录，包含 `i18n/` 和 `assets/`。不要在服务器 URL 中增加 `website/` 或 `docs/` 前缀。
3. 核对隐私、订阅、支持旧入口能跳转，独立语言页面及浏览器图标可通过 HTTPS 打开。
4. App Store Connect 继续使用以下正式地址：

| 字段 | 地址 |
| --- | --- |
| 隐私政策 | https://sdnlink.cn/privacy.html |
| 订阅条款 / EULA | https://sdnlink.cn/subscription-terms.html |
| 服务支持 | https://sdnlink.cn/support.html |
| 联系我们 | https://sdnlink.cn/contact.html |

也可在各本地化配置中直接使用相应语言地址，例如 `https://sdnlink.cn/i18n/en/support.html`。

旧版本曾有 `docs/`、根目录 `icon.png`、`apple-touch-icon.png`、`assets/home.js` 和 `assets/home-locales.js` 等镜像或运行时翻译资源。完成备份并确认无其他用途后，可从服务器移除；新页面不再引用它们。

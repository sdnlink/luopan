# 官网源码与发布

`website/` 是 sdnlink.cn 的唯一网站源码。修改网页和网站图标均在此目录完成。

```text
website/
├── index.html                 官网首页
├── appstore-marketing.html    产品介绍
├── privacy.html               隐私政策
├── subscription-terms.html    服务、订阅条款与 EULA
├── support.html               服务支持
├── favicon.ico                浏览器默认图标
└── assets/
    ├── icon.png               品牌图标，512 × 512
    ├── icon-192.png           192 × 192 图标
    ├── apple-touch-icon.png   Apple 触屏图标，180 × 180
    ├── favicon-32x32.png      浏览器 PNG 图标
    └── favicon-16x16.png      浏览器 PNG 图标
```

图标按尺寸只保留一份。页面使用相对路径引用 `assets/`，不再内嵌 base64 favicon。`favicon.ico` 按浏览器默认约定放在网站根路径。移动应用自己的 AppIcon 资源和 PWA 图标按各平台打包规则维护。

## 预览和打包

在仓库根目录预览：

```sh
python3 -m http.server 8000 --directory website
```

检查与打包：

```sh
python3 tools/package_website.py --check
python3 tools/package_website.py
```

打包工具检查页面、资源、内部链接、语言锚点及重复图标，并生成 `dist/sdnlink-website.zip`。发布包包含网页、图片、SHA-256 清单及发布说明；开发记录、应用源码和本 README 不会进入网站包。

## 手动发布

1. 备份服务器上的现有网站文件。
2. 将发布包解压到 sdnlink.cn 的静态站点根目录。上传压缩包内的内容，不要在服务器 URL 中增加 `website/` 或 `docs/` 前缀。
3. 核对隐私、订阅、支持页面及浏览器图标可通过 HTTPS 打开。
4. App Store Connect 使用以下正式地址：

| 字段 | 地址 |
| --- | --- |
| 隐私政策 | https://sdnlink.cn/privacy.html |
| 订阅条款 / EULA | https://sdnlink.cn/subscription-terms.html |
| 服务支持 | https://sdnlink.cn/support.html |

旧版本部署曾包含 `docs/`、根目录 `icon.png` 和 `apple-touch-icon.png` 等镜像文件。确认这些旧副本没有独立用途后，可在服务器备份中归档，不要再作为官网源码维护。根目录图标请求仍由发布包内的 `favicon.ico` 处理。

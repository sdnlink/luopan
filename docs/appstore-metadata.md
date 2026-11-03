# App Store Connect 上架信息

## App 覆盖地区文件

`appstore-coverage.geojson` 是提交给 App Store Connect 的覆盖区域文件，文件顶层只有一个 `MultiPolygon` 几何对象；每个外环使用 `[经度, 纬度]` 坐标并闭合。当前 16 个多边形按 `appstore-availability.csv` 的顺序对应 16 个计划 storefront。`appstore-availability.csv` 仍作为地区代码和语言映射的核对清单。

GeoJSON 地址：`https://sdnlink.cn/appstore-coverage.geojson`

最终是否开放某个地区，应在 App Store Connect 的 **App 可用性** 页面结合当地法律、税务、支付和内容政策确认。若 Apple 审核要求服务边界的测绘级精度，应将这些覆盖包络替换为实际业务边界后再上传。

当前清单覆盖简体中文、繁体中文、英语、日语、韩语、越南语、泰语和印尼语对应的主要地区。

## 可填写的网址

| App Store Connect 字段 | URL |
| --- | --- |
| 营销网址（Marketing URL） | https://sdnlink.cn/appstore-marketing.html |
| 支持网址（Support URL） | https://sdnlink.cn/appstore-marketing.html#support |
| 隐私政策网址（Privacy Policy URL） | https://sdnlink.cn/privacy.html |
| 订阅条款 | https://sdnlink.cn/subscription-terms.html |

营销页已包含产品功能、设备要求、隐私处理、支持邮箱、服务协议和订阅条款入口。部署到 Web 服务器后，请确认上述 HTTPS 地址可从公网访问，并让服务器返回 UTF-8 的 HTML/CSV 内容。

# App Store Connect 上架信息

本地化 App 描述（含每种语言的 EULA 链接）：[`appstore-descriptions.md`](appstore-descriptions.md)

加密合规填写说明：[`appstore-encryption-compliance.md`](appstore-encryption-compliance.md)

## App 覆盖地区文件

`appstore-coverage.geojson` 是提交给 App Store Connect 的覆盖区域文件，文件顶层只有一个 `MultiPolygon` 几何对象；外环使用 `[经度, 纬度]` 坐标并闭合。当前文件使用覆盖全球经纬度范围的单个外环（经度 -180° 至 180°、纬度 -90° 至 90°），表示 App 的覆盖范围为全球。`appstore-availability.csv` 仅作为地区代码和语言映射的内部核对清单，不再与 GeoJSON 中的多边形数量一一对应。

GeoJSON 地址：`https://sdnlink.cn/appstore-coverage.geojson`

最终是否开放某个地区，应在 App Store Connect 的 **App 可用性** 页面结合当地法律、税务、支付和内容政策确认。若 Apple 审核要求服务边界的测绘级精度，应将这些覆盖包络替换为实际业务边界后再上传。

当前 App Store 覆盖边界按全球范围提交；实际开放的 storefront、语言、法律和支付条件仍以 App Store Connect 的 App 可用性设置为准。

## 可填写的网址

| App Store Connect 字段 | URL |
| --- | --- |
| 营销网址（Marketing URL） | https://sdnlink.cn/appstore-marketing.html |
| 支持网址（Support URL） | https://sdnlink.cn/appstore-marketing.html#support |
| 隐私政策网址（Privacy Policy URL） | https://sdnlink.cn/privacy.html |
| 订阅条款 | https://sdnlink.cn/subscription-terms.html |

营销页已包含产品功能、设备要求、隐私处理、支持邮箱、服务协议和订阅条款入口。部署到 Web 服务器后，请确认上述 HTTPS 地址可从公网访问，并让服务器返回 UTF-8 的 HTML/CSV 内容。

## 审核修复步骤

1. 打开 App Store Connect 的 **App 信息 → 描述**，按 `appstore-descriptions.md` 分别更新 zh-Hans、zh-Hant、en、ja、ko、vi、th、id 八个本地化描述。
2. 确认每个描述末尾都保留完整的 `https://sdnlink.cn/subscription-terms.html` 链接。不要只填写应用内协议入口或相对路径。
3. 如果使用自定义 EULA，在 App Store Connect 的 **App 信息 → 许可协议（License Agreement）** 中提交同一个 `subscription-terms.html` 页面；如果选择 Apple 标准 EULA，也仍建议在每个描述中保留该链接。
4. 在提交审核前，用 Safari 的无痕窗口和 iPhone 网络分别打开该 HTTPS 地址，确认页面无需登录、不会 404、不会被 robots 或地区跳转拦截。

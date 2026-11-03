# App Store Connect 加密合规填写说明

## 本项目实际使用的加密功能

- `CryptoKit` 的 HMAC-SHA256 只用于设备本地权益镜像的完整性校验和防篡改；HMAC 是消息认证，不是应用自定义的加密通信协议。
- iOS Keychain 用于保存设备级密钥，数据保护由 Apple 系统提供。
- StoreKit、TLS/HTTPS 和系统服务由 Apple 平台处理。
- 工程没有自定义 AES、ChaCha、RSA、VPN、端到端加密聊天、加密文件传输或其他非标准加密实现。

`ios/TiandiLuopan/Info.plist` 已包含：

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

## App Store Connect 问卷建议

如果页面询问是否使用加密，按页面实际措辞选择：

1. **使用加密功能：是**（应用使用系统 Keychain、StoreKit/TLS，并使用 HMAC 做完整性校验）。
2. **是否仅使用豁免加密或符合豁免条件：是**。
3. **是否使用自定义、专有或非标准加密算法：否**。
4. **是否使用非豁免加密：否**。
5. **加密文稿 / CCATS / 技术说明上传：不需要，留空或选择“不适用”**。

如果当前界面只提供“是否使用非豁免加密”这一项，应选择“否”。如果界面提供“仅使用豁免加密”，应选择“是”。两种填写方式都对应 `ITSAppUsesNonExemptEncryption = false`。

提交前请确认没有在新版本中加入自定义加密、VPN、加密文件传输或其他非豁免功能；若以后加入，需要重新回答问卷并按 Apple 要求提交出口合规材料。

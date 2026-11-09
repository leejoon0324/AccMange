# iOS 构建、签名与安装

当前 1.1.0 交付未签名 IPA，本次已停止签名。生成可以安装的 iPhone 应用需要两步：macOS/Xcode 编译，以及有效的 Apple 签名与设备授权。把 ZIP 改成 IPA 扩展名不能完成这两步。

## 只有 Windows 与 iPhone

可以用 GitHub Actions 的 macOS 构建机编译，再用 Windows 上的 Sideloadly 与自己的免费 Apple ID 签名安装。

1. 使用自己的 GitHub 仓库存放完整项目，包含 `.github/workflows/ios-unsigned.yml`。如果希望由助手操作，需要提供具体仓库并明确允许上传源码。仓库是否公开和 Actions 费用由账号设置决定，不会自动替你创建公开仓库或购买服务。
2. 在仓库 Actions 中手动运行 **iOS unsigned IPA for local signing**，默认使用官方 Flutter stable 分支。
3. 构建完成后，下载 `Twinlock-iOS-unsigned-requires-signing` artifact，解压得到 `Twinlock-1.1.0-unsigned.ipa`。这个文件仍然未签名，不能直接安装。
4. 从 [Sideloadly 官方网站](https://sideloadly.io/) 安装 Windows 版本，并按官方说明安装所需 Apple 设备组件。
5. 使用 USB 连接 iPhone，解锁并信任电脑。将未签名 IPA 放入 Sideloadly，使用自己的 Apple ID 完成签名与安装。Apple ID 密码与验证码应由你在应用中输入，不要发到聊天或提交到源码仓库。
6. 按系统提示信任开发者证书；iOS 16 及以上通常需要开启开发者模式。

免费 Apple ID 的应用签名通常约 7 天有效，需要用同一 Apple ID 与相同应用标识定期重新签名。免费账号的应用数量、App ID 数量和能力受到 Apple 限制，登录或签名也可能被 Apple 要求额外验证。请先导出双钥的加密备份，再处理签名续期或卸载问题。

## 已有可连接的 Mac

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

在 Xcode 的 Runner → Signing & Capabilities 中选择你的 Team，并设置可用的 Bundle Identifier。连接并选择 iPhone，使用 Run 完成签名安装。个人 Apple ID 也可以使用此方式，但通常仍需按免费签名期限刷新。

需要助手继续操作时，提供 Mac 连接方式；Apple 账号登录与验证码由你完成。

## 已有 Apple 开发者证书

可使用有私钥的 `.p12` 证书、证书密码和匹配 Bundle Identifier 的 `.mobileprovision` 描述文件，在 Mac 或经授权的云构建机上导出签名 IPA。开发或 Ad Hoc 描述文件必须包含目标 iPhone 的 UDID，App Store 描述文件不能用于直接安装。

签名文件建议存放在本机 `secrets/ios/`，不提交到 Git，不包含在源码压缩包中。证书密码使用本机受保护输入或授权构建平台的 Secret，不能写入工作流或说明文件。

只有开发者账号、尚无证书和描述文件时，需要先在 Apple Developer 中注册目标设备、创建 App ID 并生成签名材料。未经你的明确授权，不会上传签名密钥到第三方平台。

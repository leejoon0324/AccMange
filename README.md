# AccMange · 双钥 Twinlock

中文离线双重验证认证器与加密密码保险箱，使用 Flutter 开发，支持 Android 和 iOS。

## 安装与交付

- `dist/双验证密码管理器.apk`：签名的 Android 安装包，支持 Android 7.0 及以上。
- `dist/Twinlock-1.0.0-ios-project.zip`：完整 Flutter / iOS 源码工程，支持 iOS 15.5 及以上。
- `dist/使用说明.md`：手机端的使用说明。

安装 Android APK 时，按系统提示允许当前文件管理器安装应用。更新时直接覆盖安装使用同一签名密钥的新版本，不要先卸载。

## 功能

- 相机扫描标准 `otpauth://` 二维码，核对账号后加密保存；也可手动填写 Base32 密钥或粘贴 otpauth 链接。
- TOTP 和 HOTP；支持 SHA1、SHA256、SHA512，6 / 7 / 8 位验证码及自定义 TOTP 周期。
- 实时验证码、倒计时、一键复制；HOTP 在验证码使用后手动推进计数器。
- 多账号管理、搜索、分组、收藏、编辑与删除。
- 独立密码保险箱，默认隐藏密码，支持账号、网站、备注及 20 位随机强密码生成。
- 主密码解锁、可选指纹 / Face ID、离开应用锁定、5 分钟无操作锁定。
- 加密备份导出与合并导入，可以在 Android 和 iOS 之间迁移。

Google Authenticator 的 `otpauth-migration://` 批量迁移二维码暂不支持，请使用服务提供的标准二维码逐个添加。目前不提供系统自动填充或浏览器扩展。

## 数据保护

账号和密码使用 AES-256-GCM 加密到应用私有文件。主密码经 PBKDF2-HMAC-SHA256（210,000 次迭代，随机 16 字节盐）派生 256 位密钥，每次保存使用新的随机 nonce。主密码不保存到磁盘。启用生物识别时，派生密钥保存到 Android Keystore 支持的加密存储或 iOS Keychain，由应用在生物识别成功后读取。

Android 禁止截屏与系统备份；iOS 离开前显示隐私遮罩。由本应用复制的内容在 30 秒后或锁定时尝试清除，仅在内容未被其他应用替换时清除。系统选择文件、分享菜单或生物识别期间，后台锁定最多宽限 2 分钟。

主密码无法找回。请定期导出备份，将备份文件与备份密码分开保管。卸载或更换设备之前先备份。验证码依赖正确的手机时间，建议开启自动设置日期与时间。

## Android 构建

需要 Flutter SDK、JDK 17、Android SDK 36 和 NDK 28.2.13676358。当前 `.toolchain/` 已安装本次构建工具，该目录不包含在交付源码压缩包中。

```powershell
./scripts/build-android.ps1
```

脚本首次运行创建独立 release 签名密钥，并生成 `android/key.properties`。必须保存 `secrets/release-signing.jks` 和 `secrets/signing-password.txt`，以便后续更新覆盖安装。密钥、密码和机器路径不包含在源码压缩包中，也不要提交到 Git。

脚本使用 PowerShell 7。Windows 项目路径含中文时，会使用同级的 `twinlock-build` 目录联接作为构建入口，文件仍在原项目中。其他环境可自行配置 `android/key.properties` 后运行 `flutter build apk --release`。

## iOS 构建与安装

在 Mac 上解压完整工程，安装兼容的 Flutter SDK（本次使用 3.47 stable）、Xcode 和 CocoaPods：

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

在 Xcode 的 Runner → Signing & Capabilities 中选择个人或开发者 Team，将 Bundle Identifier 改为自己可用的标识。相机用途、Face ID 用途、Keychain entitlement 和 iOS 15.5 最低版本已经配置。连接 iPhone，开启开发者模式，选择设备后点击 Run 安装。个人 Team 签名通常需要定期重新签名。

已有适当的 Apple 开发者签名与 provisioning profile 时：

```bash
bash scripts/build-ios.sh
```

脚本默认导出 development IPA，输出在 `build/ios/ipa/`；使用 `--ad-hoc` 可导出匹配开发者分发证书与指定设备描述文件的安装包。`bash scripts/build-ios.sh --unsigned-ipa` 可生成用于后续签名的 IPA 容器，但未签名产物不能直接安装到 iPhone。Windows 无法运行 Xcode，当前仍需构建环境和 Apple 签名授权。

已提供 `.github/workflows/ios-unsigned.yml`，可手动在 GitHub 的 macOS 构建机编译未签名 IPA，再在 Windows 上签名安装。具体步骤见 [iOS安装与签名](docs/iOS安装与签名.md)。

## 开发与验证

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

17 项测试覆盖 RFC 4226 / RFC 6238 标准向量、三种 OTP 算法、大计数器、二维码解析和无效输入、加密数据往返、错误密码及篡改拒绝、备份合并、强密码生成、后台取消解锁与关键界面流程。

`flutter run -d chrome` 可体验界面。浏览器版仅为临时预览，刷新后数据清除，不用于保存真实账号。相机、生物识别与系统分享需要在相应真机上验收。

`lib/core/` 为 OTP 和加密逻辑，`lib/storage/` 为存储与备份传输，`lib/ui/` 为界面，`android/` 与 `ios/` 为原生工程。

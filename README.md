# AccMange · 双钥 Twinlock

中文离线双重验证认证器与加密密码保险箱，使用 Flutter 开发，支持 Android 和 iOS。

## 1.1.0 交付

- `dist/Twinlock-1.1.0-android.apk`：Android 安装包，支持 Android 7.0 及以上。
- `dist/Twinlock-1.1.0-unsigned.ipa`：未签名 iPhone 应用，支持 iOS 15.5 及以上。
- `dist/Twinlock-1.1.0-ios-project.zip`：完整 Flutter / iOS 源码工程。
- `dist/使用说明.md`：手机端使用说明。

启动与返回应用均直接进入主界面，无需创建或输入主密码。Android 使用原 release 签名，可覆盖更新；iOS 本次仅交付未签名 IPA。

## 功能

- 相机扫描标准 `otpauth://` 二维码，核对账号后加密保存；也可手动填写 Base32 密钥或粘贴 otpauth 链接。
- TOTP 和 HOTP；支持 SHA1、SHA256、SHA512，6 / 7 / 8 位验证码及自定义 TOTP 周期。
- 实时验证码、倒计时、一键复制；HOTP 在验证码使用后手动推进计数器。
- 多账号管理、搜索、分组、收藏、编辑与删除。
- 密码保险箱，默认隐藏密码，支持账号、网站、备注及 20 位随机强密码生成。
- 加密备份导出与合并导入，可以在 Android 和 iOS 之间迁移。

Google Authenticator 的 `otpauth-migration://` 批量迁移二维码暂不支持，请使用服务提供的标准二维码逐个添加。目前不提供系统自动填充或浏览器扩展。

## 数据保护与旧版升级

账号和密码使用 AES-256-GCM 加密到应用私有文件。首次启动生成随机 256 位密钥，保存到 Android Keystore 支持的加密存储或 iOS Keychain；每次保存使用新的随机 nonce。应用不要求主密码或生物识别，手机解锁后，能够打开应用的人可以访问记录。独立备份密码仍通过 PBKDF2-HMAC-SHA256（210,000 次迭代）派生密钥，保护导出的文件。

Android 禁止截屏与系统备份；iOS 离开时显示隐私遮罩。由应用复制的内容在 30 秒后或进入后台时尝试清除，仅在内容未被其他应用替换时清除。返回应用直接继续使用。

从 1.0.0 升级时，旧版主密码加密文件保留，新版仍直接进入主界面。点击“发现旧版数据，点此导入”或“安全与备份 → 导入旧版数据”，输入原主密码即可合并记录，此后打开无需再输入。原始旧版文件继续保留。旧版密钥无法凭空恢复，尚未导入的旧数据不会被覆盖。

请定期导出备份，将备份文件与备份密码分开保管。卸载或更换设备之前先备份。验证码依赖正确的手机时间，建议开启自动设置日期与时间。

## Android 构建

需要 Flutter SDK、JDK 17、Android SDK 36 和 NDK 28.2.13676358。当前 `.toolchain/` 中的构建工具不包含在交付源码中。

```powershell
./scripts/build-android.ps1
```

脚本先检查代码并运行测试，再构建签名 APK。必须保存 `secrets/release-signing.jks` 和 `secrets/signing-password.txt`，以便覆盖更新。这些密钥、密码和机器路径均排除在 Git 与源码 ZIP 之外。

脚本使用 PowerShell 7。Windows 项目路径含中文时，会使用同级的 `twinlock-build` 目录联接作为构建入口，文件仍在原项目中。

## iOS 构建

GitHub Actions 工作流 `.github/workflows/ios-unsigned.yml` 使用 macOS、Xcode 和 Flutter stable，检查代码、运行测试并生成未签名 IPA。也可在 Mac 上运行：

```bash
bash scripts/build-ios.sh --unsigned-ipa
```

相机用途、Keychain entitlement 和 iOS 15.5 最低版本已经配置。未签名 IPA 不能直接安装到 iPhone；本次按要求不执行 Apple 签名。日后签名说明见 [iOS安装与签名](docs/iOS安装与签名.md)。

## 开发与验证

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

测试覆盖 RFC 4226 / RFC 6238 向量、二维码解析、加密与篡改拒绝、加密备份、随机密码、首次直接启动、设备密钥持久化、重启恢复、缺失密钥保护、旧版记录迁移、并发保存，以及返回前台和长时间空闲后保持主界面。

`flutter run -d chrome` 可体验界面。浏览器版仅为临时预览，刷新后数据清除，不用于保存真实账号。相机与系统分享需要在相应真机上验收。

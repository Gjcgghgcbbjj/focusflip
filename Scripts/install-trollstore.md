# FocusFlip TrollStore 安装指南

## 前置条件

### iOS 设备端
1. **TrollStore 已安装**（iOS 15.0 – 17.0，部分 17.x 需特殊处理）
   - 安装指南：https://github.com/opa334/TrollStore
2. **设备已越狱或已通过 TrollStore 获得永久签名**（无需越狱，TrollStore 自身即可）

### 构建环境（macOS 或 Linux）
1. **theos** — 跨平台 iOS 构建系统
   ```bash
   # macOS
   brew install ldid
   git clone --recursive https://github.com/theos/theos.git /opt/theos
   export THEOS=/opt/theos

   # Linux
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
   ```
2. **iOS SDK** — iPhoneOS15.6.sdk
   - 放置到 `$THEOS/sdks/iPhoneOS15.6.sdk`
   - 或从 https://github.com/theos/sdks 下载
3. **ldid** — 用于 fake-signing
   - macOS: `brew install ldid`
   - Linux: theos 安装时附带

## 构建步骤

### 方法一：一键脚本

```bash
cd focusflip
chmod +x Scripts/build-ipa.sh
./Scripts/build-ipa.sh
```

构建产物：`build/FocusFlip-1.0.0.ipa`

### 方法二：手动构建

```bash
cd focusflip

# 1. 设置 theos
export THEOS=/opt/theos

# 2. 构建
make clean
make package FINALPACKAGE=1

# 3. 定位 .app
APP_PATH=$(find .theos -name "FocusFlip.app" -type d | head -1)

# 4. Fake-sign（注入 entitlements）
ldid -SFocusFlip.entitlements "$APP_PATH/FocusFlip"

# 5. 打包 IPA
mkdir -p build/Payload
cp -R "$APP_PATH" build/Payload/
cd build
zip -r FocusFlip.ipa Payload/
```

## 安装到 iOS 设备

### 通过 TrollStore 安装

1. **传输 IPA 文件到设备**
   - AirDrop / iCloud Drive / 浏览器下载 / 本地服务器

2. **在 TrollStore 中安装**
   - 打开 TrollStore
   - 点击右上角 **+** 或从文件列表选择 `FocusFlip-1.0.0.ipa`
   - 点击 **Install**
   - 等待安装完成（约 5-10 秒）

3. **信任开发者**（首次安装可能需要）
   - 设置 → 通用 → VPN与设备管理 → 信任 TrollStore 证书

4. **启动 App**
   - 主屏幕出现 **FocusFlip** 图标
   - 点击启动

### 验证 TrollStore 提权功能

安装后，App 屏蔽功能需要 TrollStore 的 platform-application 权限：

1. 打开 FocusFlip → 设置 → 专注模式联动
2. 开启 **App 屏蔽**
3. 选择要屏蔽的 App
4. 开始一个专注会话 → 选定 App 应从主屏幕消失
5. 专注结束 → App 自动恢复

如果屏蔽不生效，请确认：
- ✅ 通过 TrollStore 安装（非 AltStore/Sideloadly）
- ✅ TrollStore 版本 ≥ 2.0
- ✅ iOS 版本在支持范围内（15.0-17.0）
- ✅ `FocusFlip.entitlements` 中的 `platform-application` 已被 TrollStore 签入

## 替代安装方式

### 自签（无 TrollStore）

如果设备不支持 TrollStore，可使用 AltStore / Sideloadly 自签：

1. 用 Xcode 打开 `FocusFlip.xcodeproj`（需自行从 theos 工程转换）
2. 或直接用 Sideloadly 重签名 IPA：
   ```bash
   # 需要 Apple ID
   sideloadly -i FocusFlip.ipa -a "your@email.com" -p "password"
   ```
3. 7 天后需重新签名（免费开发者账号限制）

**注意**：自签方式 **不支持** App 屏蔽功能（无 platform-application 权限）。

### 巨魔 + 自签混合

最推荐的方式：
- 主 App 用 **TrollStore** 安装（获得提权，支持 App 屏蔽）
- Widget / Live Activity 部分用 **自签**（如果 TrollStore 版本不支持 Widget Extension）

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| 构建失败：SDK not found | 确认 `iPhoneOS15.6.sdk` 在 `$THEOS/sdks/` |
| 构建失败：Swift compiler error | 确认 theos 的 Swift 工具链版本 ≥ 5.5 |
| 安装失败：IPA invalid | 检查 `Payload/FocusFlip.app/FocusFlip` 可执行文件存在 |
| App 闪退 | 检查 entitlements 是否正确签入；确认 MinimumOSVersion 匹配设备 |
| App 屏蔽不生效 | 必须通过 TrollStore 安装；检查 entitlements 中的 `platform-application` |
| Live Activity 不显示 | 需 iOS 16.1+；在设置中开启 Live Activity |
| 白噪音不播放 | 检查系统静音开关；确认 AVAudioSession 已激活 |
| 后台计时不准 | 确认后台音频权限已授予（Info.plist 中的 `UIBackgroundModes: audio`） |

## 构建配置说明

### Makefile 关键参数

| 参数 | 说明 |
|------|------|
| `TARGET` | `iphone:clang:15.6:15.0` — SDK 15.6，最低 iOS 15.0 |
| `FocusFlip_FRAMEWORKS` | 链接的系统框架 |
| `FocusFlip_PRIVATE_FRAMEWORKS` | FrontBoard 等（App 屏蔽用） |
| `FocusFlip_ENTITLEMENTS` | TrollStore 提权 plist |

### Entitlements 说明

| Key | 作用 |
|-----|------|
| `platform-application` | 平台应用权限（TrollStore 核心优势） |
| `com.apple.frontboard.launchapplications` | 允许操作其他 App |
| `com.apple.private.security.no-sandbox` | 绕过沙盒（App 屏蔽必需） |
| `com.apple.developer.activitykit.launch-activities` | Live Activity |

## 相关链接

- [TrollStore](https://github.com/opa334/TrollStore)
- [Theos](https://theos.dev)
- [ldid](https://github.com/ProcursusTeam/ldid)
- [iOS SDK 下载](https://github.com/theos/sdks)

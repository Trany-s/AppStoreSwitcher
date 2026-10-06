# App Store 账号管理

一款面向个人本地使用的 macOS 工具，用于安全保存多个 App Store 账号，并辅助在当前已登录账号之间快速切换。

## 当前功能

- 菜单栏入口和独立可视化管理窗口
- 扁平化、支持 macOS 深色模式的账号界面
- 添加、编辑和删除多个 App Store 账号
- 使用 Touch ID 或 macOS 登录密码验证后查看已保存密码
- 使用 macOS Keychain 保存账号密码
- 一键打开 App Store 并辅助执行退出当前账号、登录目标账号
- 支持当前 App Store 已登录和未登录两种状态
- 支持账号备注名称、邮箱和密码修改
- 支持双重认证、验证码和异常登录确认的人工接管

## 安全与隐私

- 应用不连接自建服务器，也不上传账号信息。
- 密码不会写入项目目录、配置文件或明文数据库。
- 密码和账号邮箱保存在 macOS Keychain 中。
- 账号名称、邮箱和账号列表等非敏感元数据保存在 macOS 用户偏好设置中。
- 查看密码前需要通过 macOS 用户身份验证。

Keychain 服务名：

```text
com.local.AppStoreSwitcher.credentials
```

## 安装

从 DMG 安装：

1. 打开 `dist/App Store 账号管理-0.1.0.dmg`。
2. 将「App Store 账号管理」拖入“应用程序”文件夹。
3. 从“应用程序”中启动应用。

由于这是个人本地使用的自签名应用，如果 macOS 提示无法验证开发者，可以右键应用并选择“打开”，或到“系统设置 → 隐私与安全性”中选择允许打开。

## 首次授权

为了控制 App Store 的菜单和登录窗口，需要在系统设置中授权：

- 系统设置 → 隐私与安全性 → 辅助功能 → 允许「App Store 账号管理」
- 系统设置 → 隐私与安全性 → 自动化 → 允许「App Store 账号管理」控制 System Events

应用重新编译或重新安装后，如果权限失效，请删除旧条目并重新添加新应用。

## 从源码运行和打包

需要 macOS、Xcode Command Line Tools 和 Swift 6 或兼容的 Xcode 环境。

直接运行：

```bash
swift run
```

生成本地 `.app`：

```bash
./build-app.sh
open "App Store 账号管理.app"
```

生成 DMG 安装包：

```bash
./package-dmg.sh
open "dist/App Store 账号管理-0.1.0.dmg"
```

## 项目结构

```text
Sources/AppStoreSwitcher/
├── AppStoreSwitcherApp.swift    # SwiftUI 应用入口和菜单栏场景
├── ContentView.swift             # 账号管理界面
├── Models.swift                  # 账号模型、Keychain 和本地数据管理
└── AppStoreAutomation.swift      # App Store 辅助功能自动化
```

## 已知限制

- App Store 没有公开的账号切换 API，本项目通过 macOS 辅助功能和自动化控制官方界面。
- Apple 更改 App Store 界面或菜单名称后，自动化流程可能需要调整。
- 双重认证、验证码、异常登录确认和部分密码验证窗口仍可能需要手动操作。
- 自动化期间请不要同时操作 App Store，避免界面状态变化导致流程中断。
- 本项目面向个人本地使用，不提供云同步，也不建议将源码或 Keychain 数据复制到其他设备。

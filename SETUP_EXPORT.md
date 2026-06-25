# 🚀 星屑割草 — 导出指南（Web / Android）

> **✅ 本机已装好导出模板 + Android SDK + debug keystore，Web 和 Android 均可直接导出！**
> 产物：`export/web/index.html`（Web）、`export/android/starfall.apk`（Android 已签名）。
> 重新导出命令见 §2 / §3。以下为完整环境说明（换机器时参考）。

---

## 0. 当前状态一览

| 项 | 状态 | 说明 |
|----|------|------|
| `export_presets.cfg`（Web + Android 预设）| ✅ | 已配好，arm64-v8a |
| `export/web`、`export/android` 目录 | ✅ | 已建 |
| 导出模板（4.7.stable）| ✅ | 已安装（web / android / windows / linux / macos 全模板）|
| Android SDK | ✅ | `%LOCALAPPDATA%\Android\Sdk`（build-tools 36.1，platform android-36）|
| JDK 21 | ✅ | `C:\Program Files\Java\jdk-21.0.10`（Godot 4.7 需要 ≥JDK 17）|
| Debug Keystore | ✅ | `%APPDATA%\Godot\keystores\debug.keystore` |
| Web 导出 | ✅ | 可执行 |
| Android 导出 | ✅ | 可执行（触屏虚拟摇杆已实现 ✅）|

---

## 1. 安装导出模板（Web 和 Android 都需要）

模板版本必须**精确匹配** `4.7.stable`。

**方式 A（推荐，编辑器一键）**
1. 双击 `Godot.exe` 打开本项目。
2. 顶部菜单 **Editor → Manage Export Templates → Download and Install**。
3. 等待下载完成（约 700MB）。

**方式 B（手动）**
1. 从 https://godotengine.org/download/archive/4.7-stable/ 下载 `Godot_v4.7-stable_export_templates.tpz`。
2. 编辑器 **Manage Export Templates → Install from File** 选该 `.tpz`；
   或解压到：`%APPDATA%\Godot\export_templates\4.7.stable\`

**验证**：该目录下应出现 `web_nothreads_release.zip`、`android_release.apk` 等文件。

---

## 2. Web 导出（HTML5）

```powershell
.\Godot.exe --headless --export-release "Web" export/web/index.html
```

- **产物**：`export/web/` 下的 `index.html` + `.wasm` / `.js` / `.pck` 等。
- **本地测试**（不能直接双击，必须 HTTP 服务）：
  ```powershell
  python -m http.server 8000 --directory export/web
  ```
- **发布到 itch.io**：把 `export/web` 整个目录打包成 zip 上传，勾选 "This file will be played in the browser"。
- 注：当前预设用 **nothreads**（不依赖 SharedArrayBuffer），省去 COOP/COEP 头配置。

---

## 3. Android 导出（APK）

**前置依赖**（本机已配好）：
- JDK ≥ 17 → `C:\Program Files\Java\jdk-21.0.10`
- Android SDK → `%LOCALAPPDATA%\Android\Sdk`
- Debug Keystore → `%APPDATA%\Godot\keystores\debug.keystore`

**导出命令**：
```powershell
.\Godot.exe --headless --export-release "Android" export/android/starfall.apk
# 调试版（更快、可连 adb logcat）：--export-debug
```
- **产物**：`export/android/starfall.apk`
- **安装**：`adb install export/android/starfall.apk`，或拷到手机点击安装。
- 包名 `com.starfall.survivor`，版本 `0.1.0`，架构 `arm64-v8a`。

---

## 4. 触屏虚拟摇杆 ✅

虚拟摇杆已实现：左半屏触控摇杆 + 右上角暂停按钮。`scripts/ui/virtual_joystick.gd` 自动添加（Main._setup_joystick），PC 键盘不受影响。Android 可直接游玩。

---

## 5. 常见问题

- **导出报"未找到导出模板"**：§1 没装或版本不匹配（必须 4.7.stable）。
- **Android 报 JDK 版本错误**：Godot 编辑器设置 → Export → Android → Java SDK Path，指向 JDK ≥ 17。
- **Android 报找不到 SDK**：同上，Android SDK Path 指向 SDK 目录。
- **Web 黑屏/打不开**：没走 HTTP 服务，直接开 index.html 会被浏览器 CORS 拦截。

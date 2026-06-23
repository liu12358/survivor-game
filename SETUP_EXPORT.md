# 🚀 星屑割草 — 导出指南（Web / Android）

> **✅ 本机已装好导出模板 + Android SDK 工具 + debug keystore，Web 和 Android 均已成功导出！**
> 产物：`export/web/index.html`（Web，39.5MB wasm）、`export/android/starfall.apk`（Android，28.5MB 已签名）。
> 重新导出命令见 §2 / §3。以下为完整环境说明（换机器时参考）。
>
> 已安装：导出模板 → `%APPDATA%\Godot\export_templates\4.7.stable\`；Android SDK 工具 → `%USERPROFILE%\android-sdk`（platform-tools + build-tools 34.0.0）；debug keystore → `%USERPROFILE%\.android\debug.keystore`。
> editor settings 与 `project.godot`（ETC2/ASTC 压缩）也已配好。

---

## 0. 当前状态一览

| 项 | 状态 | 你需要做的 |
|----|------|-----------|
| `export_presets.cfg`（Web + Android 预设）| ✅ 已配好 | — |
| `export/web`、`export/android` 目录 | ✅ 已建 | — |
| 导出模板（4.7.stable）| ❌ 未装 | 见 §1（编辑器一键下载，~700MB）|
| Web 导出 | ⏳ 待模板 | 装模板后一条命令（§2）|
| Android SDK / JDK 17 | ❌ 未装 | 见 §3 |
| 触屏虚拟摇杆 | ❌ 未做 | **Android 实际可玩的前置**，见 §4 |

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

模板装好后，命令行（项目根目录）：

```powershell
.\Godot.exe --headless --export-release "Web" export/web/index.html
```

- **产物**：`export/web/` 下的 `index.html` + `.wasm` / `.js` / `.pck` 等。
- **本地测试**（不能直接双击 index.html，必须走 HTTP 服务）：
  ```powershell
  python -m http.server 8000 --directory export/web
  # 浏览器打开 http://localhost:8000
  ```
- **发布到 itch.io**：把 `export/web` 整个目录打包成 zip 上传，勾选 "This file will be played in the browser"。
- 注：当前预设用 **nothreads**（不依赖 SharedArrayBuffer），省去 COOP/COEP 头配置，itch.io 直接可用。若要多线程版，把预设 `thread_support` 改 true 并配置跨域隔离头。

---

## 3. Android 导出（APK）

**前置依赖**：
1. **JDK 17**（当前机器是 JDK 25，Godot 4.7 的 Android 构建需要 **17**）。安装 Temurin JDK 17。
2. **Android SDK**（装 Android Studio 最省事；或单独装 cmdline-tools）。需含 platform-tools、build-tools、platform `android-34`。
3. Godot 编辑器 → **Editor → Editor Settings → Export → Android**：
   - **Java SDK Path** → 指向 JDK 17 目录
   - **Android SDK Path** → 指向 SDK 目录
   - 生成 **Debug Keystore**（Editor Settings 里有按钮，或 Godot 首次会提示自动创建）

**导出命令**：
```powershell
.\Godot.exe --headless --export-release "Android" export/android/starfall.apk
# 调试版（更快、可连 adb logcat）：--export-debug
```
- **产物**：`export/android/starfall.apk`
- **安装**：`adb install export/android/starfall.apk`，或拷到手机点击安装。
- 包名 `com.starfall.survivor`，版本 `0.1.0`，架构 `arm64-v8a`。

---

## 4. ⚠️ Android 实际可玩的前置：触屏虚拟摇杆

当前角色移动靠 **WASD / 方向键**。`project.godot` 已开 `emulate_mouse_from_touch`，但**移动仍需键盘** → **Android 上装好后角色无法移动**（只能看 UI）。

GDD §16.3 的**触屏虚拟摇杆**（左半屏摇杆 + 暂停按钮）尚未实现。**Android 要真正能玩，必须先做这个**——需要时找我，我来实现并接入现有输入系统（`move_*` 动作）。

---

## 5. 常见问题

- **导出报"未找到导出模板"**：§1 没装或版本不匹配（必须 4.7.stable）。
- **Android 报 JDK 版本错误**：用 JDK 17，不是 25。
- **Android 报找不到 SDK**：Editor Settings 里的 Android SDK Path 没配。
- **Web 黑屏/打不开**：没走 HTTP 服务，直接开 index.html 会被浏览器 CORS 拦截。

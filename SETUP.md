# 星屑割草 - 项目搭建指南

## 1. 安装 Godot 4

Godot 4.7 已通过 winget 安装，或直接下载：
- 手动下载：https://godotengine.org/download/windows/
- 将 `Godot_v4.7-stable_win64.exe` 放到项目根目录或任意位置

如果 winget 安装的 Godot 找不到，运行：
```powershell
# 查找 Godot
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "godot*.exe"

# 或直接下载
# 解压 godot.zip 到项目根目录
# cd C:\Users\17393\Desktop\survivor-game
# Expand-Archive godot.zip -DestinationPath .
```

## 2. 打开项目

1. 双击 `Godot_v4.7-stable_win64.exe`
2. 在项目管理器点击「导入」
3. 选择 `C:\Users\17393\Desktop\survivor-game\project.godot`
4. 点击「导入并编辑」

## 3. 验证项目

在 Godot 编辑器中：
1. 打开 `res://scripts/verify_modules.gd`
2. 按 F6 运行 → 终端输出所有模块验证结果
3. 全部通过 = 项目骨架正确

## 4. 运行游戏

1. 打开 `res://scenes/levels/main.tscn`
2. 按 F5 运行
3. WASD 移动，ESC 暂停

## 项目结构

```
survivor-game/
├── project.godot          # 项目配置文件
├── GDD.md                 # 完整设计文档
├── SETUP.md               # 本文件
├── .gitignore
├── scenes/                # 场景文件
│   ├── player/            # 玩家场景
│   ├── enemies/           # 敌人场景
│   ├── weapons/           # 武器场景
│   ├── ui/                # UI场景
│   └── levels/            # 关卡场景
├── scripts/               # GDScript脚本
│   ├── player/            # 玩家逻辑
│   ├── enemies/           # 敌人逻辑
│   ├── weapons/           # 武器逻辑
│   ├── ui/                # UI逻辑
│   └── managers/          # 管理器（单例）
├── assets/                # 资源文件
│   ├── sprites/           # 精灵图
│   ├── audio/             # 音频
│   └── fonts/             # 字体
├── resources/             # Resource数据表
│   ├── weapons/
│   ├── enemies/
│   ├── balance/
│   └── achievements/
├── localization/          # 多语言文本
└── export/                # 导出产物
```

## 已完成模块

| 模块 | 脚本 | 状态 |
|------|------|------|
| EventBus | scripts/managers/event_bus.gd | ✅ |
| GameState | scripts/managers/game_state.gd | ✅ |
| AudioManager | scripts/managers/audio_manager.gd | ✅ |
| ObjectPool | scripts/managers/object_pool.gd | ✅ |
| Main | scripts/managers/main.gd | ✅ |
| Player | scripts/player/player.gd | ✅ |
| BaseWeapon | scripts/weapons/base_weapon.gd | ✅ |
| MagicBolt | scripts/weapons/magic_bolt.gd | ✅ |
| Projectile | scripts/weapons/projectile.gd | ✅ |
| BaseEnemy | scripts/enemies/base_enemy.gd | ✅ |
| ExpGem | scripts/enemies/exp_gem.gd | ✅ |
| EnemySpawner | scripts/enemies/enemy_spawner.gd | ✅ |
| HUD | scripts/ui/hud.gd | ✅ |
| Verify | scripts/verify_modules.gd | ✅ |

## 下一步 (Phase 1.2)

- 在 Godot 编辑器中补全 HUD 的 UI 节点（血量条/经验条/计时器）
- 补全场景节点的碰撞形状/精灵
- 实机测试：移动 → 敌人生成 → 魔法弹射击 → 击杀 → 拾取经验

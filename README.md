# fable-client

Fable AI 小镇模拟的 Godot 4 游戏客户端。

后端由 [Fable](https://github.com/claw-works/fable) 驱动，客户端通过 WebSocket + REST API 与 Fable 实时通信，动态渲染任意世界配置。

## 架构

```
Fable 后端（Go）          fable-client（Godot 4）
  ├── NPC AI 引擎    ←→   FableAPI.gd（HTTP + WebSocket）
  ├── Tick 驱动           GameState.gd（全局状态缓存）
  ├── WebSocket /ws  →    WorldMap.gd（动态生成地图+NPC）
  └── REST API       →    Player.gd（玩家控制）
                          HUD.gd + DialogueUI.gd（UI）
```

## 特性

- **动态渲染**：从 Fable 拉取世界配置，程序化生成地图和 NPC，无需硬编码任何世界内容
- **实时同步**：WebSocket 接收 StreamEvent，NPC 状态实时更新，对话气泡即时显示
- **玩家参与**：WASD 自由移动，进入地点区域自动触发 move action，靠近 NPC 按 E 对话
- **对话系统**：与任意 NPC 展开多轮对话，由 Fable LLM 驱动 NPC 回复

## 快速开始

### 1. 启动 Fable 后端

```bash
cd /path/to/fable
# 编辑 config.yaml 填入 LLM API Key
make run
# 服务启动在 http://localhost:8080
```

### 2. 用 Godot 4 打开项目

- 下载 [Godot 4.3+](https://godotengine.org/download)
- 打开 Godot，选择 Import Project，选择本目录
- 点击运行（F5）

### 3. 自定义服务器地址

默认连接 `localhost:8080`，可通过命令行参数修改：

```bash
godot --host 192.168.1.100 --port 8080
```

## 项目结构

```
fable-client/
├── project.godot
├── scenes/
│   ├── main/Main.tscn          # 主场景
│   ├── world/Location.tscn     # 地点节点（动态实例化）
│   ├── npc/NPC.tscn            # NPC 节点（动态实例化）
│   ├── player/Player.tscn      # 玩家节点
│   └── ui/
│       ├── HUD.tscn            # 游戏 HUD
│       ├── DialogueUI.tscn     # 对话界面
│       └── JoinPanel.tscn      # 角色创建面板
└── scripts/
    ├── autoload/
    │   ├── FableAPI.gd         # 网络通信（HTTP + WebSocket）
    │   ├── GameState.gd        # 全局状态
    │   └── EventBus.gd         # 事件总线
    ├── world/
    │   ├── WorldMap.gd         # 动态地图生成
    │   └── Location.gd         # 地点逻辑
    ├── npc/NPC.gd              # NPC 行为
    ├── player/Player.gd        # 玩家控制
    └── ui/
        ├── HUD.gd
        ├── DialogueUI.gd
        └── JoinPanel.gd
```

## Fable 后端协议

### WebSocket StreamEvent

```json
{ "type": "tick_start", "tick": 5, "game_time": "Day1 10:00" }
{ "type": "tick_end",   "tick": 5, "game_time": "Day1 10:00" }
{ "type": "agent_update", "agent_state": { "agent_id": "lao_chen", "location": "茶馆", "dialogue": "...", ... } }
{ "type": "event", "text": "张铁山在铁匠铺打铁" }
```

### 关键 REST API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/config/world` | 世界配置（含地点坐标/类型） |
| GET | `/api/config/agents` | 角色配置（含 sprite/color） |
| POST | `/api/player/join` | 玩家加入 |
| POST | `/api/player/action` | 提交玩家行动 |
| POST | `/api/conversation/start` | 开始对话 |
| POST | `/api/conversation/say` | 发言并获取 NPC 回复 |
| DELETE | `/api/conversation/end` | 结束对话 |

## 开发路线

- [x] WebSocket 实时同步
- [x] 动态地图生成（按 world.yaml 坐标）
- [x] 动态 NPC 实例化（按 agents.yaml）
- [x] 玩家移动 + 地点触发
- [x] NPC 对话系统
- [ ] 像素风 tilemap（替换色块占位）
- [ ] NPC 精灵动画
- [ ] 摄像机跟随玩家
- [ ] 小地图
- [ ] 存档/读档 UI

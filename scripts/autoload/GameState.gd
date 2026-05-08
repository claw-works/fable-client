## GameState.gd
## 全局游戏状态，缓存从 Fable 拉取的所有数据
extends Node

# 连接配置
var fable_host: String = "localhost"
var fable_port: int = 8080

# 世界配置（从 /api/config/world 拉取）
var world_config: Dictionary = {}
var locations: Array = []          # Location 列表，含坐标/类型
var location_map: Dictionary = {}  # name -> Location dict

# 角色配置（从 /api/config/agents 拉取）
var agents_config: Array = []
var agents_config_map: Dictionary = {}  # id -> AgentConfig dict

# 运行时状态（从 WebSocket 实时更新）
var current_tick: int = 0
var game_time: String = ""
var agent_states: Dictionary = {}   # agent_id -> AgentState dict
var agent_locations: Dictionary = {} # location_name -> [agent_id, ...]

# 玩家状态
var player_config: Dictionary = {}
var player_state: Dictionary = {}
var is_player_joined: bool = false

func _ready() -> void:
	# 从命令行参数读取服务器地址（方便调试）
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--host" and i + 1 < args.size():
			fable_host = args[i + 1]
		elif args[i] == "--port" and i + 1 < args.size():
			fable_port = int(args[i + 1])

func get_fable_base_url() -> String:
	return "http://%s:%d" % [fable_host, fable_port]

func get_fable_ws_url() -> String:
	return "ws://%s:%d/ws" % [fable_host, fable_port]

## 更新 agent 状态（由 FableAPI 调用）
func update_agent_state(state: Dictionary) -> void:
	var agent_id: String = state.get("agent_id", "")
	if agent_id.is_empty():
		return
	agent_states[agent_id] = state

## 从完整世界状态批量更新
func apply_world_state(state: Dictionary) -> void:
	current_tick = state.get("tick", current_tick)
	game_time = state.get("game_time", game_time)

	# 更新 agent 状态
	var agents: Array = state.get("agents", [])
	for a in agents:
		var aid: String = a.get("agent_id", "")
		if not aid.is_empty():
			agent_states[aid] = a

	# 更新位置分布
	agent_locations = state.get("locations", {})

## 缓存世界配置
func apply_world_config(config: Dictionary) -> void:
	world_config = config
	locations = config.get("locations", [])
	location_map.clear()
	for loc in locations:
		location_map[loc["name"]] = loc

## 缓存角色配置
func apply_agents_config(agents: Array) -> void:
	agents_config = agents
	agents_config_map.clear()
	for a in agents:
		agents_config_map[a["id"]] = a

## 获取某地点的所有 agent（运行时）
func get_agents_at_location(location_name: String) -> Array:
	return agent_locations.get(location_name, [])

## 获取 agent 当前位置
func get_agent_location(agent_id: String) -> String:
	var state: Dictionary = agent_states.get(agent_id, {})
	return state.get("location", "")

## 获取 agent 配置（静态）
func get_agent_config(agent_id: String) -> Dictionary:
	return agents_config_map.get(agent_id, {})

## 获取地点配置（含坐标）
func get_location(name: String) -> Dictionary:
	return location_map.get(name, {})

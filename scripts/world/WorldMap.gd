## WorldMap.gd
## 动态生成世界地图：从 GameState 读取地点配置，程序化创建节点
extends Node2D

const LOCATION_SCENE := preload("res://scenes/world/Location.tscn")
const NPC_SCENE := preload("res://scenes/npc/NPC.tscn")

var _location_nodes: Dictionary = {}  # location_name -> LocationNode
var _npc_nodes: Dictionary = {}       # agent_id -> NPCNode
var _connection_lines: Array = []     # 连线节点列表

func _ready() -> void:
	EventBus.world_config_loaded.connect(_on_world_config_loaded)
	EventBus.agents_config_loaded.connect(_on_agents_config_loaded)
	EventBus.agent_updated.connect(_on_agent_updated)

func _on_world_config_loaded(config: Dictionary) -> void:
	_build_map(config)

func _on_agents_config_loaded(agents: Array) -> void:
	_build_npcs(agents)

# ─────────────────────────────────────────
# 地图构建
# ─────────────────────────────────────────

func _build_map(config: Dictionary) -> void:
	# 清理旧节点
	for node in _location_nodes.values():
		node.queue_free()
	_location_nodes.clear()
	for line in _connection_lines:
		line.queue_free()
	_connection_lines.clear()

	var locations: Array = config.get("locations", [])

	# 先画连线（在地点节点下层）
	var drawn_connections: Dictionary = {}
	for loc in locations:
		var from_name: String = loc.get("name", "")
		var from_pos := _location_center(loc)
		for conn in loc.get("connected", []):
			var to_name: String = conn.get("name", "")
			var key := _connection_key(from_name, to_name)
			if drawn_connections.has(key):
				continue
			drawn_connections[key] = true
			var to_loc: Dictionary = GameState.get_location(to_name)
			if to_loc.is_empty():
				continue
			var to_pos := _location_center(to_loc)
			var line := _make_connection_line(from_pos, to_pos, conn.get("distance", 1))
			add_child(line)
			_connection_lines.append(line)

	# 再创建地点节点
	for loc in locations:
		var node: Node2D = LOCATION_SCENE.instantiate()
		node.setup(loc)
		node.position = Vector2(loc.get("x", 0.0), loc.get("y", 0.0))
		add_child(node)
		_location_nodes[loc.get("name", "")] = node

func _location_center(loc: Dictionary) -> Vector2:
	return Vector2(
		loc.get("x", 0.0) + loc.get("width", 120.0) * 0.5,
		loc.get("y", 0.0) + loc.get("height", 100.0) * 0.5
	)

func _connection_key(a: String, b: String) -> String:
	if a < b:
		return a + "|" + b
	return b + "|" + a

func _make_connection_line(from: Vector2, to: Vector2, distance: int) -> Line2D:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 2.0
	# 距离越远颜色越淡
	var alpha := 0.6 - (distance - 1) * 0.15
	line.default_color = Color(0.6, 0.5, 0.3, clampf(alpha, 0.2, 0.6))
	line.z_index = -1
	return line

# ─────────────────────────────────────────
# NPC 构建
# ─────────────────────────────────────────

func _build_npcs(agents: Array) -> void:
	for node in _npc_nodes.values():
		node.queue_free()
	_npc_nodes.clear()

	for agent_cfg in agents:
		var node: Node2D = NPC_SCENE.instantiate()
		node.setup(agent_cfg)
		# 初始位置：放在初始地点中心
		var init_loc: String = agent_cfg.get("init_location", "")
		var loc_data: Dictionary = GameState.get_location(init_loc)
		if not loc_data.is_empty():
			node.position = _location_center(loc_data) + _npc_offset(agent_cfg.get("id", ""))
		add_child(node)
		_npc_nodes[agent_cfg.get("id", "")] = node

## 同地点多个 NPC 错开显示，避免重叠
func _npc_offset(agent_id: String) -> Vector2:
	var hash_val := agent_id.hash()
	var ox := float(hash_val % 60) - 30.0
	var oy := float((hash_val >> 8) % 40) - 20.0
	return Vector2(ox, oy)

# ─────────────────────────────────────────
# 运行时更新
# ─────────────────────────────────────────

func _on_agent_updated(agent_state: Dictionary) -> void:
	var agent_id: String = agent_state.get("agent_id", "")
	if agent_id.is_empty():
		return
	var node: Node2D = _npc_nodes.get(agent_id)
	if node == null:
		return
	# 移动到新地点
	var new_loc: String = agent_state.get("location", "")
	if not new_loc.is_empty():
		var loc_data: Dictionary = GameState.get_location(new_loc)
		if not loc_data.is_empty():
			var target_pos := _location_center(loc_data) + _npc_offset(agent_id)
			node.move_to(target_pos, agent_state)

## 获取指定地点节点（供玩家碰撞检测用）
func get_location_node(name: String) -> Node2D:
	return _location_nodes.get(name)

## 获取指定 NPC 节点
func get_npc_node(agent_id: String) -> Node2D:
	return _npc_nodes.get(agent_id)

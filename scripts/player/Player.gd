## Player.gd
## 玩家控制：WASD 移动，进入地点区域触发 move action，靠近 NPC 按 E 交互
extends CharacterBody2D

const MOVE_SPEED := 180.0

var _current_location: String = ""
var _nearby_npc_id: String = ""
var _nearby_npc_name: String = ""
var _nearby_npcs: Dictionary = {}  # agent_id -> npc_name
var _in_conversation: bool = false
var _active: bool = false
var _menu_open: bool = false

@onready var _sprite: ColorRect = $Sprite
@onready var _name_label: Label = $NameLabel
@onready var _interact_hint: Label = $InteractHint

func _ready() -> void:
	add_to_group("player")
	_sprite.color = Color.WHITE
	_sprite.size = Vector2(28, 36)
	_sprite.position = Vector2(-14, -36)
	_interact_hint.visible = false

	EventBus.player_near_npc.connect(_on_near_npc)
	EventBus.player_left_npc_range.connect(_on_left_npc_range)
	EventBus.player_moved_to_location.connect(_on_entered_location)
	EventBus.conversation_started.connect(_on_conversation_started)
	EventBus.conversation_ended.connect(_on_conversation_ended)
	EventBus.world_config_loaded.connect(_on_world_config_loaded)

func _on_world_config_loaded(config: Dictionary) -> void:
	# 玩家加入后设置初始位置
	if GameState.is_player_joined:
		var init_loc: String = GameState.player_config.get("init_location", "")
		_teleport_to_location(init_loc)
		_name_label.text = GameState.player_config.get("name", "旅人")
		_active = true

func setup(player_config: Dictionary) -> void:
	_name_label.text = player_config.get("name", "旅人")
	var init_loc: String = player_config.get("init_location", "")
	_teleport_to_location(init_loc)
	_active = true
	# 清除可能残留的输入状态
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")

func _teleport_to_location(loc_name: String) -> void:
	var loc: Dictionary = GameState.get_location(loc_name)
	if loc.is_empty():
		return
	position = Vector2(
		loc.get("x", 0.0) + loc.get("width", 120.0) * 0.5,
		loc.get("y", 0.0) + loc.get("height", 100.0) * 0.5
	)

func _physics_process(_delta: float) -> void:
	if not _active or _in_conversation or _menu_open:
		velocity = Vector2.ZERO
		return

	# 文本输入框有焦点时不响应移动
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		velocity = Vector2.ZERO
		return

	# WASD 移动
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1

	velocity = dir.normalized() * MOVE_SPEED
	move_and_slide()

	# 移动后更新最近的 NPC
	if not _nearby_npcs.is_empty():
		_update_nearest_npc()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _in_conversation or _menu_open:
		return
	if event.is_action_pressed("interact"):
		_menu_open = true
		_interact_hint.visible = false
		EventBus.player_interact_pressed.emit(_nearby_npc_id, _nearby_npc_name, _current_location)
		get_viewport().set_input_as_handled()

func _start_conversation(npc_id: String) -> void:
	_in_conversation = true
	await FableAPI.conversation_start(npc_id)

func _on_near_npc(npc_id: String, npc_name: String) -> void:
	_nearby_npcs[npc_id] = npc_name
	_update_nearest_npc()

func _on_left_npc_range() -> void:
	# 信号没带 ID，重新扫描哪些 NPC 还在范围内
	_rebuild_nearby_npcs()
	_update_nearest_npc()

func _rebuild_nearby_npcs() -> void:
	_nearby_npcs.clear()
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.has_method("get_agent_id") and position.distance_to(npc.position) <= 80.0:
			_nearby_npcs[npc.get_agent_id()] = npc.get_agent_name()

func _update_nearest_npc() -> void:
	if _nearby_npcs.is_empty():
		_nearby_npc_id = ""
		_nearby_npc_name = ""
		_interact_hint.visible = false
		return
	# 找最近的
	var best_id := ""
	var best_dist := INF
	for npc_id in _nearby_npcs:
		for npc in get_tree().get_nodes_in_group("npc"):
			if npc.has_method("get_agent_id") and npc.get_agent_id() == npc_id:
				var dist := position.distance_to(npc.position)
				if dist < best_dist:
					best_dist = dist
					best_id = npc_id
				break
	_nearby_npc_id = best_id
	_nearby_npc_name = _nearby_npcs.get(best_id, "")
	_interact_hint.text = "按E交互"
	_interact_hint.visible = true

func _on_entered_location(location_name: String) -> void:
	if location_name == _current_location:
		return
	_current_location = location_name
	# 通知 Fable 后端玩家移动
	FableAPI.player_move(location_name)
	EventBus.show_notification.emit("来到了 %s" % location_name, 2.0)

func _on_conversation_started(_npc_id: String, _npc_name: String) -> void:
	_in_conversation = true
	_interact_hint.visible = false

func _on_conversation_ended() -> void:
	_in_conversation = false
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")

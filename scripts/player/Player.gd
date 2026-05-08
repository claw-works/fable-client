## Player.gd
## 玩家控制：WASD 移动，进入地点区域触发 move action，靠近 NPC 按 E 交互
extends CharacterBody2D

const MOVE_SPEED := 180.0

var _current_location: String = ""
var _nearby_npc_id: String = ""
var _nearby_npc_name: String = ""
var _in_conversation: bool = false

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

func setup(player_config: Dictionary) -> void:
	_name_label.text = player_config.get("name", "旅人")
	var init_loc: String = player_config.get("init_location", "")
	_teleport_to_location(init_loc)

func _teleport_to_location(loc_name: String) -> void:
	var loc: Dictionary = GameState.get_location(loc_name)
	if loc.is_empty():
		return
	position = Vector2(
		loc.get("x", 0.0) + loc.get("width", 120.0) * 0.5,
		loc.get("y", 0.0) + loc.get("height", 100.0) * 0.5
	)

func _physics_process(delta: float) -> void:
	if _in_conversation:
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if not _nearby_npc_id.is_empty() and not _in_conversation:
			_start_conversation()

func _start_conversation() -> void:
	FableAPI.conversation_start(_nearby_npc_id)

func _on_near_npc(npc_id: String, npc_name: String) -> void:
	_nearby_npc_id = npc_id
	_nearby_npc_name = npc_name
	_interact_hint.text = "按 E 与 %s 对话" % npc_name
	_interact_hint.visible = true

func _on_left_npc_range() -> void:
	_nearby_npc_id = ""
	_nearby_npc_name = ""
	_interact_hint.visible = false

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

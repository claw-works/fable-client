## Main.gd
## 主场景入口：初始化 FableAPI，加载世界，协调 UI 交互
extends Node2D

@onready var _loading_label: Label = $UI/LoadingLabel
@onready var _context_menu: Control = $UI/ContextMenu
@onready var _player: CharacterBody2D = $Player

func _ready() -> void:
	_loading_label.text = "正在连接 Fable 服务..."
	_loading_label.visible = true

	EventBus.world_config_loaded.connect(_on_world_loaded)
	EventBus.connection_status_changed.connect(_on_connection_changed)
	EventBus.player_interact_pressed.connect(_on_interact)

	_context_menu.talk_selected.connect(_on_talk_selected)
	_context_menu.act_selected.connect(_on_act_selected)
	_context_menu.menu_closed.connect(_on_menu_closed)

	await FableAPI.initialize()

func _on_world_loaded(_config: Dictionary) -> void:
	_loading_label.visible = false

func _on_connection_changed(connected: bool) -> void:
	if not connected:
		_loading_label.text = "连接断开，重连中..."
		_loading_label.visible = true
	else:
		_loading_label.visible = false

func _on_interact(npc_id: String, npc_name: String, location_name: String) -> void:
	_context_menu.show_menu(npc_id, npc_name, location_name)

func _on_talk_selected(npc_id: String) -> void:
	_player._menu_open = false
	_player._start_conversation(npc_id)

func _on_act_selected(content: String) -> void:
	_player._menu_open = false
	FableAPI.player_act(content)
	EventBus.show_notification.emit("行动: %s" % content, 2.0)

func _on_menu_closed() -> void:
	_player._menu_open = false
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")

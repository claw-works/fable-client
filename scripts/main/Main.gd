## Main.gd
## 主场景入口：初始化 FableAPI，加载世界
extends Node2D

@onready var _world_map: Node2D = $WorldMap
@onready var _player: CharacterBody2D = $Player
@onready var _hud: Control = $UI/HUD
@onready var _dialogue_ui: Control = $UI/DialogueUI
@onready var _loading_label: Label = $UI/LoadingLabel

func _ready() -> void:
	_loading_label.text = "正在连接 Fable 服务..."
	_loading_label.visible = true

	EventBus.world_config_loaded.connect(_on_world_loaded)
	EventBus.connection_status_changed.connect(_on_connection_changed)

	# 初始化：拉配置 + 连 WebSocket
	await FableAPI.initialize()

func _on_world_loaded(_config: Dictionary) -> void:
	_loading_label.visible = false

func _on_connection_changed(connected: bool) -> void:
	if not connected:
		_loading_label.text = "连接断开，重连中..."
		_loading_label.visible = true
	else:
		_loading_label.visible = false

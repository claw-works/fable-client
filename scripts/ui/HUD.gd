## HUD.gd
## 游戏 HUD：时间、当前地点、连接状态、事件日志、模拟控制
extends Control

const MAX_LOG_LINES := 30

var _log_lines: Array[String] = []

@onready var _time_label: Label = $TopBar/TimeLabel
@onready var _location_label: Label = $TopBar/LocationLabel
@onready var _connection_dot: ColorRect = $TopBar/ConnectionDot
@onready var _tick_label: Label = $TopBar/TickLabel
@onready var _event_log: RichTextLabel = $EventLog
@onready var _notification: Label = $Notification
@onready var _start_btn: Button = $ControlBar/StartButton
@onready var _stop_btn: Button = $ControlBar/StopButton
@onready var _tick_btn: Button = $ControlBar/TickButton
@onready var _join_panel: Control = $JoinPanel

var _notification_timer: float = 0.0

func _ready() -> void:
	EventBus.tick_started.connect(_on_tick_started)
	EventBus.tick_ended.connect(_on_tick_ended)
	EventBus.world_event.connect(_on_world_event)
	EventBus.agent_updated.connect(_on_agent_updated)
	EventBus.player_moved_to_location.connect(_on_player_location_changed)
	EventBus.connection_status_changed.connect(_on_connection_changed)
	EventBus.show_notification.connect(_show_notification)
	EventBus.world_config_loaded.connect(_on_world_loaded)

	_start_btn.pressed.connect(_on_start_pressed)
	_stop_btn.pressed.connect(_on_stop_pressed)
	_tick_btn.pressed.connect(_on_tick_pressed)

	_notification.visible = false
	_stop_btn.disabled = true

func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			_notification.visible = false

func _on_world_loaded(_config: Dictionary) -> void:
	# 世界加载完成后显示加入面板
	_join_panel.visible = true

func _on_tick_started(tick: int, game_time: String) -> void:
	_tick_label.text = "Tick %d" % tick
	_time_label.text = game_time
	_add_log("[color=#888888]── Tick %d 开始 ──[/color]" % tick)

func _on_tick_ended(_tick: int, _game_time: String) -> void:
	pass

func _on_world_event(text: String) -> void:
	if not text.is_empty():
		_add_log(text)

func _on_agent_updated(state: Dictionary) -> void:
	var dialogue: Variant = state.get("dialogue")
	if dialogue != null and str(dialogue) != "":
		var name_str: String = state.get("name", "?")
		_add_log("[color=#f0c060]%s：[/color]%s" % [name_str, str(dialogue)])

func _on_player_location_changed(location_name: String) -> void:
	_location_label.text = "📍 " + location_name

func _on_connection_changed(connected: bool) -> void:
	_connection_dot.color = Color.GREEN if connected else Color.RED

func _show_notification(text: String, duration: float) -> void:
	_notification.text = text
	_notification.visible = true
	_notification_timer = duration

func _add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines = _log_lines.slice(_log_lines.size() - MAX_LOG_LINES)
	_event_log.clear()
	for line in _log_lines:
		_event_log.append_text(line + "\n")

func _on_start_pressed() -> void:
	FableAPI.start_simulation()
	_start_btn.disabled = true
	_stop_btn.disabled = false
	_tick_btn.disabled = true

func _on_stop_pressed() -> void:
	FableAPI.stop_simulation()
	_start_btn.disabled = false
	_stop_btn.disabled = true
	_tick_btn.disabled = false

func _on_tick_pressed() -> void:
	FableAPI.tick_once()

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
	# 尝试从本地存档自动加入
	var saved := _load_player_config()
	if not saved.is_empty():
		var ok: bool = await FableAPI.player_join(saved)
		if ok:
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("setup"):
				player.setup(saved)
			return
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
	var name_str: String = state.get("name", "?")

	# 动作
	var action: String = state.get("action", "")
	if not action.is_empty():
		_add_log("[color=#aaaaaa]%s %s[/color]" % [name_str, action])

	# 对话
	var dialogue: Variant = state.get("dialogue")
	if dialogue != null and str(dialogue) != "":
		_add_log("[color=#f0c060]%s：[/color]%s" % [name_str, str(dialogue)])

	# 想法（上帝视角，小字）
	var thought: String = state.get("inner_thought", "")
	if not thought.is_empty():
		_add_log("[font_size=9][color=#666666][i]（%s心想：%s）[/i][/color][/font_size]" % [name_str, thought])

	# 关系变化
	var changes: Array = state.get("relation_changes", [])
	for change in changes:
		var target_id: String = change.get("target_id", "")
		var target_cfg: Dictionary = GameState.get_agent_config(target_id)
		var target_name: String = target_cfg.get("name", change.get("target_name", target_id))
		if target_id == "player":
			target_name = GameState.player_config.get("name", "玩家")
		var delta: int = change.get("delta", 0)
		var reason: String = change.get("reason", "")
		var sign_str := "+" if delta > 0 else ""
		var color := "#88ff88" if delta > 0 else "#ff8888"
		if delta == 0:
			color = "#aaaaaa"
		var text := "[color=%s]💫 %s 对 %s 的好感度 %s%d[/color]" % [color, name_str, target_name, sign_str, delta]
		if not reason.is_empty():
			text += " [font_size=9][color=#888888](%s)[/color][/font_size]" % reason
		_add_log(text)
		if delta != 0:
			EventBus.show_notification.emit("%s → %s %s%d" % [name_str, target_name, sign_str, delta], 3.0)

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

const PLAYER_SAVE_PATH := "user://player_config.json"

func save_player_config(config: Dictionary) -> void:
	var f := FileAccess.open(PLAYER_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config))

func _load_player_config() -> Dictionary:
	if not FileAccess.file_exists(PLAYER_SAVE_PATH):
		return {}
	var f := FileAccess.open(PLAYER_SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	return json.get_data()

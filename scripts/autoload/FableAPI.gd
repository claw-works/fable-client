## FableAPI.gd
## 负责与 Fable 后端的所有通信：HTTP REST + WebSocket
extends Node

var _ws: WebSocketPeer = WebSocketPeer.new()
var _ws_connected: bool = false
var _reconnect_timer: float = 0.0
var _reconnect_interval: float = 3.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_poll_websocket(delta)

# ─────────────────────────────────────────
# 初始化：拉取配置 + 连接 WebSocket
# ─────────────────────────────────────────

func initialize() -> void:
	await _fetch_world_config()
	await _fetch_agents_config()
	_connect_websocket()

# ─────────────────────────────────────────
# WebSocket
# ─────────────────────────────────────────

func _connect_websocket() -> void:
	var url := GameState.get_fable_ws_url()
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("[FableAPI] WebSocket 连接失败: %d, 将在 %.1fs 后重试" % [err, _reconnect_interval])

func _poll_websocket(delta: float) -> void:
	_ws.poll()
	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _ws_connected:
				_ws_connected = true
				_reconnect_timer = 0.0
				EventBus.connection_status_changed.emit(true)
				print("[FableAPI] WebSocket 已连接")
			# 读取所有待处理消息
			while _ws.get_available_packet_count() > 0:
				var raw := _ws.get_packet()
				_handle_ws_message(raw.get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			if _ws_connected:
				_ws_connected = false
				EventBus.connection_status_changed.emit(false)
				print("[FableAPI] WebSocket 断开，准备重连")
			_reconnect_timer += delta
			if _reconnect_timer >= _reconnect_interval:
				_reconnect_timer = 0.0
				_connect_websocket()

func _handle_ws_message(raw: String) -> void:
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_warning("[FableAPI] 无法解析 WS 消息: " + raw.left(100))
		return
	var msg: Dictionary = json.get_data()

	# StreamEvent 格式：有 type 字段
	var msg_type: String = msg.get("type", "")
	if msg_type != "":
		_handle_stream_event(msg_type, msg)
		return

	# 兼容旧格式：完整 WorldState（无 type 字段，有 tick 字段）
	if msg.has("tick"):
		GameState.apply_world_state(msg)
		EventBus.world_state_updated.emit(msg)

func _handle_stream_event(event_type: String, msg: Dictionary) -> void:
	match event_type:
		"tick_start":
			EventBus.tick_started.emit(msg.get("tick", 0), msg.get("game_time", ""))
		"tick_end":
			EventBus.tick_ended.emit(msg.get("tick", 0), msg.get("game_time", ""))
		"agent_update":
			var agent_state: Dictionary = msg.get("agent_state", {})
			if not agent_state.is_empty():
				GameState.update_agent_state(agent_state)
				EventBus.agent_updated.emit(agent_state)
		"event":
			EventBus.world_event.emit(msg.get("text", ""))

# ─────────────────────────────────────────
# HTTP 工具
# ─────────────────────────────────────────

## 发起 GET 请求，返回解析后的 Dictionary/Array，失败返回 null
func _http_get(path: String) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var url := GameState.get_fable_base_url() + path
	var err := http.request(url)
	if err != OK:
		push_warning("[FableAPI] GET %s 失败: %d" % [path, err])
		http.queue_free()
		return null
	var result: Array = await http.request_completed
	http.queue_free()
	# result = [result_code, response_code, headers, body]
	if result[1] != 200:
		push_warning("[FableAPI] GET %s 返回 %d" % [path, result[1]])
		return null
	var json := JSON.new()
	if json.parse(result[3].get_string_from_utf8()) != OK:
		push_warning("[FableAPI] GET %s 解析失败" % path)
		return null
	return json.get_data()

## 发起 POST 请求，body 为 Dictionary，返回解析后的结果
func _http_post(path: String, body: Dictionary = {}) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var url := GameState.get_fable_base_url() + path
	var headers := ["Content-Type: application/json"]
	var body_str := JSON.stringify(body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		push_warning("[FableAPI] POST %s 失败: %d" % [path, err])
		http.queue_free()
		return null
	var result: Array = await http.request_completed
	http.queue_free()
	if result[1] != 200:
		push_warning("[FableAPI] POST %s 返回 %d" % [path, result[1]])
		return null
	var json := JSON.new()
	if json.parse(result[3].get_string_from_utf8()) != OK:
		return null
	return json.get_data()

## 发起 DELETE 请求
func _http_delete(path: String) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var url := GameState.get_fable_base_url() + path
	var err := http.request(url, [], HTTPClient.METHOD_DELETE)
	if err != OK:
		http.queue_free()
		return null
	var result: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	if json.parse(result[3].get_string_from_utf8()) != OK:
		return null
	return json.get_data()

# ─────────────────────────────────────────
# 配置拉取
# ─────────────────────────────────────────

func _fetch_world_config() -> void:
	var data: Variant = await _http_get("/api/config/world")
	if data == null:
		push_error("[FableAPI] 无法获取世界配置，请确认 Fable 服务已启动")
		return
	GameState.apply_world_config(data)
	EventBus.world_config_loaded.emit(data)
	print("[FableAPI] 世界配置已加载: %s，%d 个地点" % [
		data.get("name", "?"),
		data.get("locations", []).size()
	])

func _fetch_agents_config() -> void:
	var data: Variant = await _http_get("/api/config/agents")
	if data == null:
		push_error("[FableAPI] 无法获取角色配置")
		return
	GameState.apply_agents_config(data)
	EventBus.agents_config_loaded.emit(data)
	print("[FableAPI] 角色配置已加载: %d 个角色" % data.size())

# ─────────────────────────────────────────
# 玩家 API
# ─────────────────────────────────────────

func player_join(config: Dictionary) -> bool:
	var result: Variant = await _http_post("/api/player/join", config)
	if result == null:
		return false
	GameState.is_player_joined = true
	GameState.player_config = config
	EventBus.player_joined.emit(config)
	print("[FableAPI] 玩家已加入: %s" % config.get("name", "?"))
	return true

func player_leave() -> void:
	await _http_delete("/api/player/leave")
	GameState.is_player_joined = false

func player_action(action_type: String, params: Dictionary = {}) -> void:
	var body := {"type": action_type}
	body.merge(params)
	await _http_post("/api/player/action", body)

func player_move(location_name: String) -> void:
	await player_action("move", {"location": location_name})

func player_talk(target_id: String, content: String) -> void:
	await player_action("talk", {"target": target_id, "content": content})

func player_act(content: String) -> void:
	await player_action("act", {"content": content})

func player_skip() -> void:
	await player_action("skip")

# ─────────────────────────────────────────
# 对话 API
# ─────────────────────────────────────────

func conversation_start(npc_id: String) -> bool:
	var result: Variant = await _http_post("/api/conversation/start", {"npc_id": npc_id})
	if result == null:
		return false
	var npc_config: Dictionary = GameState.get_agent_config(npc_id)
	EventBus.conversation_started.emit(npc_id, npc_config.get("name", npc_id))
	return true

func conversation_say(content: String) -> String:
	var result: Variant = await _http_post("/api/conversation/say", {"content": content})
	if result == null:
		return ""
	var reply: String = result.get("reply", "")
	return reply

func conversation_end() -> void:
	await _http_delete("/api/conversation/end")
	EventBus.conversation_ended.emit()

# ─────────────────────────────────────────
# 模拟控制
# ─────────────────────────────────────────

func start_simulation() -> void:
	await _http_post("/api/start")

func stop_simulation() -> void:
	await _http_post("/api/stop")

func tick_once() -> void:
	await _http_post("/api/tick")

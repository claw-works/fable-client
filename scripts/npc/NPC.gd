## NPC.gd
## NPC 节点：显示角色、接收 agent_update 驱动移动和对话气泡
extends CharacterBody2D

const MOVE_SPEED := 120.0
const INTERACT_RADIUS := 80.0

var _config: Dictionary = {}
var _agent_id: String = ""
var _current_state: Dictionary = {}
var _target_pos: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _bubble_timer: float = 0.0
var _wander_timer: float = 0.0
var _home_pos: Vector2 = Vector2.ZERO

@onready var _sprite: ColorRect = $Sprite
@onready var _name_label: Label = $NameLabel
@onready var _bubble: Control = $DialogueBubble
@onready var _bubble_label: Label = $DialogueBubble/Label
@onready var _emotion_label: Label = $EmotionLabel
@onready var _interact_area: Area2D = $InteractArea
@onready var _thought_bubble: Control = $ThoughtBubble
@onready var _thought_label: Label = $ThoughtBubble/Label

var _thought_timer: float = 0.0

func setup(agent_config: Dictionary) -> void:
	_config = agent_config
	_agent_id = agent_config.get("id", "")

	# 颜色占位精灵（后期换真实精灵图）
	var color_str: String = agent_config.get("color", "#888888")
	_sprite.color = Color.html(color_str)
	_sprite.size = Vector2(28, 36)
	_sprite.position = Vector2(-14, -36)

	# 名称标签（居中于色块上方）
	_name_label.text = agent_config.get("name", "?")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-30, -52)
	_name_label.size = Vector2(60, 16)

	# 交互区域
	var shape := CircleShape2D.new()
	shape.radius = INTERACT_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	_interact_area.add_child(col)
	_interact_area.body_entered.connect(_on_player_entered)
	_interact_area.body_exited.connect(_on_player_exited)

	_bubble.visible = false
	_emotion_label.visible = false
	add_to_group("npc")
	_wander_timer = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	# 记录初始位置
	if _home_pos == Vector2.ZERO:
		_home_pos = position

	# 平滑移动到目标位置
	if _is_moving:
		var dist := position.distance_to(_target_pos)
		if dist < 4.0:
			position = _target_pos
			_is_moving = false
			velocity = Vector2.ZERO
		else:
			velocity = position.direction_to(_target_pos) * MOVE_SPEED
			move_and_slide()
	else:
		# 空闲漫步
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(3.0, 7.0)
			var offset := Vector2(randf_range(-30, 30), randf_range(-20, 20))
			_target_pos = _home_pos + offset
			_is_moving = true

	# 对话气泡计时消失
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false

	# 想法气泡计时消失
	if _thought_timer > 0.0:
		_thought_timer -= delta
		if _thought_timer <= 0.0:
			_thought_bubble.visible = false

## 接收来自 WorldMap 的移动指令
func move_to(target: Vector2, state: Dictionary) -> void:
	_current_state = state
	_target_pos = target
	_home_pos = target
	_is_moving = true

	# 显示对话气泡
	var dialogue: Variant = state.get("dialogue")
	if dialogue != null and dialogue != "":
		show_bubble(str(dialogue))

	# 显示情绪
	var emotion: String = state.get("emotion", "")
	if not emotion.is_empty():
		_emotion_label.text = _emotion_to_emoji(emotion)
		_emotion_label.visible = true

	# 显示想法气泡
	var thought: String = state.get("inner_thought", "")
	if not thought.is_empty():
		show_thought(thought)

func show_bubble(text: String) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble_timer = 5.0

func show_thought(text: String) -> void:
	_thought_label.text = "💭 " + text
	_thought_bubble.visible = true
	_thought_timer = 4.0

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		EventBus.player_near_npc.emit(_agent_id, _config.get("name", ""))

func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		EventBus.player_left_npc_range.emit()

func get_agent_id() -> String:
	return _agent_id

func get_agent_name() -> String:
	return _config.get("name", "")

func _emotion_to_emoji(emotion: String) -> String:
	# 简单映射，后期可扩展
	var map := {
		"平静": "😐", "高兴": "😊", "开心": "😄", "快乐": "😄",
		"悲伤": "😢", "难过": "😢", "愤怒": "😠", "生气": "😠",
		"担忧": "😟", "焦虑": "😰", "好奇": "🤔", "惊讶": "😲",
		"满足": "😌", "疲惫": "😴", "兴奋": "🤩",
	}
	for key in map:
		if emotion.contains(key):
			return map[key]
	return "💭"

## Location.gd
## 单个地点节点：显示区域背景、名称标签、高亮交互
extends Node2D

# 地点类型对应的颜色（无素材时用色块占位）
const TYPE_COLORS := {
	"teahouse":   Color(0.85, 0.65, 0.30, 0.85),
	"market":     Color(0.40, 0.75, 0.40, 0.85),
	"blacksmith": Color(0.70, 0.35, 0.20, 0.85),
	"school":     Color(0.35, 0.55, 0.80, 0.85),
	"temple":     Color(0.75, 0.45, 0.75, 0.85),
	"dock":       Color(0.30, 0.60, 0.80, 0.85),
}
const DEFAULT_COLOR := Color(0.55, 0.55, 0.55, 0.85)

var _data: Dictionary = {}
var _is_player_inside: bool = false

func setup(location_data: Dictionary) -> void:
	_data = location_data
	var w: float = location_data.get("width", 120.0)
	var h: float = location_data.get("height", 100.0)
	var loc_type: String = location_data.get("type", "")
	var color: Color = TYPE_COLORS.get(loc_type, DEFAULT_COLOR)

	# 背景色块
	var bg: ColorRect = $Background
	bg.size = Vector2(w, h)
	bg.color = color

	# 名称标签
	var lbl: Label = $Label
	lbl.text = location_data.get("name", "?")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, h + 4.0)
	lbl.size = Vector2(w, 20.0)

	# 碰撞区域
	var area: Area2D = $Area2D
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(w * 0.5, h * 0.5)
	area.add_child(col)

	# 连接信号
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_is_player_inside = true
		$Background.color = $Background.color.lightened(0.2)
		EventBus.player_moved_to_location.emit(_data.get("name", ""))

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_is_player_inside = false
		var loc_type: String = _data.get("type", "")
		$Background.color = TYPE_COLORS.get(loc_type, DEFAULT_COLOR)

func get_location_name() -> String:
	return _data.get("name", "")

func get_center() -> Vector2:
	return position + Vector2(
		_data.get("width", 120.0) * 0.5,
		_data.get("height", 100.0) * 0.5
	)

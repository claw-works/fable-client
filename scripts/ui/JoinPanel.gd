## JoinPanel.gd
## 玩家创建角色并加入世界的面板
extends Control

@onready var _name_input: LineEdit = $Panel/VBox/NameInput
@onready var _occupation_input: LineEdit = $Panel/VBox/OccupationInput
@onready var _personality_input: LineEdit = $Panel/VBox/PersonalityInput
@onready var _backstory_input: TextEdit = $Panel/VBox/BackstoryInput
@onready var _location_option: OptionButton = $Panel/VBox/LocationOption
@onready var _join_btn: Button = $Panel/VBox/JoinButton
@onready var _skip_btn: Button = $Panel/VBox/SkipButton

func _ready() -> void:
	_join_btn.pressed.connect(_on_join_pressed)
	_skip_btn.pressed.connect(_on_skip_pressed)
	EventBus.world_config_loaded.connect(_on_world_loaded)

func _on_world_loaded(config: Dictionary) -> void:
	# 填充地点选项
	_location_option.clear()
	for loc in config.get("locations", []):
		_location_option.add_item(loc.get("name", ""))

func _on_join_pressed() -> void:
	var name_str := _name_input.text.strip_edges()
	if name_str.is_empty():
		name_str = "旅人"
	var loc_idx := _location_option.selected
	var init_loc := _location_option.get_item_text(loc_idx) if loc_idx >= 0 else "茶馆"

	var config := {
		"id": name_str,
		"name": name_str,
		"occupation": _occupation_input.text.strip_edges() if not _occupation_input.text.is_empty() else "旅人",
		"personality": _personality_input.text.strip_edges() if not _personality_input.text.is_empty() else "好奇，随和",
		"backstory": _backstory_input.text.strip_edges() if not _backstory_input.text.is_empty() else "一个来自远方的旅人，来到清水镇寻找机缘。",
		"init_location": init_loc,
	}

	var ok: bool = await FableAPI.player_join(config)
	if ok:
		# 保存到本地，下次自动加入
		var hud := get_parent()
		if hud.has_method("save_player_config"):
			hud.save_player_config(config)
		# 通知玩家节点初始化
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("setup"):
			player.setup(config)
		visible = false

func _on_skip_pressed() -> void:
	# 纯观察模式，不加入
	visible = false

## DialogueUI.gd
## 对话界面：显示 NPC 对话，玩家输入回复
extends Control

var _current_npc_id: String = ""
var _current_npc_name: String = ""

@onready var _panel: PanelContainer = $Panel
@onready var _npc_name_label: Label = $Panel/VBox/NPCName
@onready var _dialogue_log: RichTextLabel = $Panel/VBox/DialogueLog
@onready var _input_field: LineEdit = $Panel/VBox/InputRow/InputField
@onready var _send_btn: Button = $Panel/VBox/InputRow/SendButton
@onready var _end_btn: Button = $Panel/VBox/EndButton

func _ready() -> void:
	visible = false
	EventBus.conversation_started.connect(_on_conversation_started)
	EventBus.conversation_ended.connect(_on_conversation_ended)
	_send_btn.pressed.connect(_on_send_pressed)
	_end_btn.pressed.connect(_on_end_pressed)
	_input_field.text_submitted.connect(_on_text_submitted)

func _on_conversation_started(npc_id: String, npc_name: String) -> void:
	_current_npc_id = npc_id
	_current_npc_name = npc_name
	_npc_name_label.text = npc_name
	_dialogue_log.clear()
	_dialogue_log.append_text("[color=#aaaaaa]（与 %s 开始对话）[/color]\n" % npc_name)
	visible = true
	_input_field.grab_focus()

func _on_conversation_ended() -> void:
	_current_npc_id = ""
	visible = false

func _on_send_pressed() -> void:
	_send_message()

func _on_text_submitted(_text: String) -> void:
	_send_message()

func _send_message() -> void:
	var content := _input_field.text.strip_edges()
	if content.is_empty():
		return
	_input_field.text = ""
	_input_field.editable = false
	_send_btn.disabled = true

	# 显示玩家发言
	var player_name: String = GameState.player_config.get("name", "旅人")
	_dialogue_log.append_text("[color=#ffffff][b]%s：[/b][/color]%s\n" % [player_name, content])

	# 等待 NPC 回复
	var reply: String = await FableAPI.conversation_say(content)
	if not reply.is_empty():
		_dialogue_log.append_text("[color=#f0c060][b]%s：[/b][/color]%s\n" % [_current_npc_name, reply])

	_input_field.editable = true
	_send_btn.disabled = false
	_input_field.grab_focus()

func _on_end_pressed() -> void:
	FableAPI.conversation_end()

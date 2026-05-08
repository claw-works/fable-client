## ContextMenu.gd
## E 键弹出的上下文菜单：NPC 附近显示交谈+行动，地点只显示行动
extends Control

signal talk_selected(npc_id: String)
signal act_selected(content: String)
signal menu_closed()

var _npc_id: String = ""
var _npc_name: String = ""
var _location_name: String = ""
var _is_action_mode: bool = false

@onready var _menu_panel: PanelContainer = $MenuPanel
@onready var _menu_box: VBoxContainer = $MenuPanel/VBox
@onready var _title_label: Label = $MenuPanel/VBox/Title
@onready var _talk_btn: Button = $MenuPanel/VBox/TalkButton
@onready var _act_btn: Button = $MenuPanel/VBox/ActButton
@onready var _action_panel: PanelContainer = $ActionPanel
@onready var _action_input: LineEdit = $ActionPanel/VBox/ActionInput
@onready var _action_send: Button = $ActionPanel/VBox/SendButton

func _ready() -> void:
	visible = false
	_menu_panel.visible = false
	_action_panel.visible = false
	_talk_btn.pressed.connect(_on_talk)
	_act_btn.pressed.connect(_on_act)
	_action_send.pressed.connect(_on_action_submit)
	_action_input.text_submitted.connect(func(_t): _on_action_submit())

func show_menu(npc_id: String, npc_name: String, location_name: String) -> void:
	_npc_id = npc_id
	_npc_name = npc_name
	_location_name = location_name
	_is_action_mode = false

	if not npc_id.is_empty():
		_title_label.text = npc_name
		_talk_btn.visible = true
		_act_btn.text = "行动"
	else:
		_title_label.text = location_name
		_talk_btn.visible = false
		_act_btn.text = "行动"

	_menu_panel.visible = true
	_action_panel.visible = false
	visible = true

func hide_menu() -> void:
	visible = false
	_menu_panel.visible = false
	_action_panel.visible = false
	_is_action_mode = false
	menu_closed.emit()

func _on_talk() -> void:
	hide_menu()
	talk_selected.emit(_npc_id)

func _on_act() -> void:
	_menu_panel.visible = false
	_action_panel.visible = true
	_action_input.text = ""
	_action_input.grab_focus()
	_is_action_mode = true

func _on_action_submit() -> void:
	var content := _action_input.text.strip_edges()
	if content.is_empty():
		return
	hide_menu()
	act_selected.emit(content)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("interact") and not _is_action_mode):
		hide_menu()
		get_viewport().set_input_as_handled()

## EventBus.gd
## 全局事件总线，解耦各模块通信
extends Node

# Fable 后端事件
signal world_config_loaded(world_config: Dictionary)
signal agents_config_loaded(agents: Array)
signal world_state_updated(state: Dictionary)
signal agent_updated(agent_state: Dictionary)
signal tick_started(tick: int, game_time: String)
signal tick_ended(tick: int, game_time: String)
signal world_event(text: String)

# 玩家事件
signal player_joined(player_config: Dictionary)
signal player_state_changed(player_state: Dictionary)
signal player_moved_to_location(location_name: String)
signal player_near_npc(npc_id: String, npc_name: String)
signal player_left_npc_range()
signal player_interact_pressed(npc_id: String, npc_name: String, location_name: String)

# 对话事件
signal conversation_started(npc_id: String, npc_name: String)
signal conversation_reply(npc_name: String, content: String)
signal conversation_ended()

# UI 事件
signal show_dialogue_box(npc_name: String, content: String)
signal hide_dialogue_box()
signal show_notification(text: String, duration: float)
signal connection_status_changed(connected: bool)

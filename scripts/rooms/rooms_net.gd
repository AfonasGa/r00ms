class_name RoomsNet
extends Node

## Steam Spacewar (AppID 480) P2P Lobby + ENet Fallback Multiplayer Manager for r00ms.
## Uses dynamic Engine.get_singleton("Steam") access so iOS / Android / headless builds never fail
## if Steam native runtime libraries are unavailable.

signal status_changed(text: String)
signal lobbies_updated(lobbies: Array)
signal door_opened_remote(room_index: int)
signal state_received(peer_key: String, data: Dictionary)
signal peer_disconnected(peer_key: String)

const SPACEWAR_APP_ID := 480
const ENET_PORT := 27480
const LOBBY_FILTER_TAG := "r00ms_spacewar_v1"

var steam_loaded := false
var steam_ready := false
var steam_status_text := "Steam не инициализирован"
var steam_id := 0
var persona_name := "Player"
var current_lobby_id := 0
var is_host := false
var mode := "offline" # "offline" | "steam" | "enet"
var run_seed := 0

var _steam: Object = null
var _peer_steam_ids: Array[int] = []
var _found_lobbies: Array[Dictionary] = []

var _enet: ENetMultiplayerPeer = null
var _enet_connected_ids: Array[int] = []

var _send_accum := 0.0
var _callback_accum := 0.0
var _local_state: Dictionary = {}


func _ready() -> void:
	_init_steam()


func _exit_tree() -> void:
	disconnect_session()


func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		steam_loaded = false
		steam_ready = false
		steam_status_text = "GodotSteam недоступен (ENet тест готов)"
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		return
	steam_loaded = true

	var init_res: Variant = _steam.call("steamInitEx", SPACEWAR_APP_ID, false)
	if init_res is Dictionary:
		var d: Dictionary = init_res
		var st := int(d.get("status", -1))
		var verbal := String(d.get("verbal", ""))
		if st == 0:
			steam_ready = true
			steam_id = int(_steam.call("getSteamID"))
			persona_name = String(_steam.call("getPersonaName"))
			steam_status_text = "Steam Spacewar (480): %s" % persona_name
			_connect_steam_signals()
		else:
			steam_ready = false
			steam_status_text = "Steam клиент не запущен (%s)" % (verbal if not verbal.is_empty() else "code %d" % st)
	else:
		steam_ready = false
		steam_status_text = "Steam инициализация не подтверждена"


func _connect_steam_signals() -> void:
	if _steam == null:
		return
	_safe_connect("lobby_created", _on_steam_lobby_created)
	_safe_connect("lobby_joined", _on_steam_lobby_joined)
	_safe_connect("lobby_match_list", _on_steam_lobby_match_list)
	_safe_connect("lobby_chat_update", _on_steam_lobby_chat_update)
	_safe_connect("p2p_session_request", _on_steam_p2p_session_request)
	_safe_connect("p2p_session_connect_fail", _on_steam_p2p_connect_fail)


func _safe_connect(sig_name: String, cb: Callable) -> void:
	if _steam != null and _steam.has_signal(sig_name) and not _steam.is_connected(sig_name, cb):
		_steam.connect(sig_name, cb)


func is_online() -> bool:
	return mode != "offline"


func get_summary_status() -> String:
	if mode == "steam":
		return "Steam Spacewar (480) | Лобби %d | Игроков: %d%s" % [
			current_lobby_id,
			_peer_steam_ids.size() + 1,
			" [ХОСТ]" if is_host else ""
		]
	elif mode == "enet":
		return "ENet Тест 127.0.0.1:%d | Игроков: %d%s" % [
			ENET_PORT,
			_enet_connected_ids.size() + 1,
			" [ХОСТ]" if is_host else ""
		]
	return steam_status_text


func host_steam_lobby(seed_val: int) -> bool:
	if not steam_ready or _steam == null:
		emit_signal("status_changed", steam_status_text)
		return false
	disconnect_session()
	is_host = true
	run_seed = seed_val
	mode = "steam"
	# 2 = LOBBY_TYPE_PUBLIC, max 4 players
	_steam.call("createLobby", 2, 4)
	emit_signal("status_changed", "Создание Steam-лобби (Spacewar 480)...")
	return true


func search_steam_lobbies() -> bool:
	if not steam_ready or _steam == null:
		emit_signal("status_changed", steam_status_text)
		return false
	_steam.call("addRequestLobbyListStringFilter", "r00ms_tag", LOBBY_FILTER_TAG, 0)
	_steam.call("addRequestLobbyListDistanceFilter", 3) # Worldwide
	_steam.call("requestLobbyList")
	emit_signal("status_changed", "Поиск открытых лобби Spacewar (480)...")
	return true


func join_steam_lobby(lobby_id: int) -> bool:
	if not steam_ready or _steam == null or lobby_id <= 0:
		emit_signal("status_changed", steam_status_text)
		return false
	disconnect_session()
	is_host = false
	mode = "steam"
	_steam.call("joinLobby", lobby_id)
	emit_signal("status_changed", "Подключение к Steam-лобби %d..." % lobby_id)
	return true


func open_steam_invite_overlay() -> void:
	if steam_ready and _steam != null and current_lobby_id > 0:
		_steam.call("activateGameOverlayInviteDialog", current_lobby_id)


func host_enet(seed_val: int, port: int = ENET_PORT) -> Error:
	disconnect_session()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, 8)
	if err != OK:
		emit_signal("status_changed", "Ошибка запуска ENet сервера (%d)" % err)
		return err
	_enet = enet
	multiplayer.multiplayer_peer = enet
	_wire_enet_signals()
	is_host = true
	run_seed = seed_val
	mode = "enet"
	emit_signal("status_changed", "Локальный тест-сервер запущен (порт %d)" % port)
	return OK


func join_enet(ip: String = "127.0.0.1", port: int = ENET_PORT) -> Error:
	disconnect_session()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(ip, port)
	if err != OK:
		emit_signal("status_changed", "Ошибка подключения ENet к %s:%d (%d)" % [ip, port, err])
		return err
	_enet = enet
	multiplayer.multiplayer_peer = enet
	_wire_enet_signals()
	is_host = false
	mode = "enet"
	emit_signal("status_changed", "Подключение к %s:%d..." % [ip, port])
	return OK


func _wire_enet_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_enet_peer_connected):
		multiplayer.peer_connected.connect(_on_enet_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_enet_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_enet_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_enet_connected_to_server):
		multiplayer.connected_to_server.connect(_on_enet_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_enet_connection_failed):
		multiplayer.connection_failed.connect(_on_enet_connection_failed)


func disconnect_session() -> void:
	if mode == "steam" and _steam != null:
		for pid in _peer_steam_ids:
			_steam.call("closeP2PSessionWithUser", pid)
			emit_signal("peer_disconnected", "steam_%d" % pid)
		if current_lobby_id > 0:
			_steam.call("leaveLobby", current_lobby_id)
	elif mode == "enet":
		for eid in _enet_connected_ids:
			emit_signal("peer_disconnected", "enet_%d" % eid)
		if _enet != null:
			_enet.close()
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer = null

	_peer_steam_ids.clear()
	_enet_connected_ids.clear()
	_enet = null
	current_lobby_id = 0
	is_host = false
	mode = "offline"
	emit_signal("status_changed", get_summary_status())


func update_local_state(state_dict: Dictionary) -> void:
	_local_state = state_dict


func broadcast_door_opened(room_index: int) -> void:
	var msg := {"t": "door", "r": room_index}
	if mode == "steam":
		_steam_send_all(msg, 2) # P2P_SEND_RELIABLE
	elif mode == "enet" and multiplayer.has_multiplayer_peer():
		var bytes := var_to_bytes(msg)
		multiplayer.send_bytes(bytes, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func _process(delta: float) -> void:
	if steam_ready and _steam != null:
		_callback_accum += delta
		if _callback_accum >= 0.016:
			_callback_accum = 0.0
			_steam.call("run_callbacks")

	if mode == "steam" and _steam != null and steam_ready:
		_poll_steam_packets()
	elif mode == "enet" and multiplayer.has_multiplayer_peer():
		_poll_enet_packets()

	if mode != "offline":
		_send_accum += delta
		if _send_accum >= 0.05:
			_send_accum = 0.0
			if not _local_state.is_empty():
				var pkt := {
					"t": "st",
					"p": _local_state.get("pos", [0.0, 0.0, 0.0]),
					"y": float(_local_state.get("yaw", 0.0)),
					"pt": float(_local_state.get("pitch", 0.0)),
					"l": bool(_local_state.get("light", false)),
					"h": bool(_local_state.get("hide", false)),
					"r": int(_local_state.get("room", 0)),
					"hp": int(_local_state.get("hp", 100)),
					"n": persona_name,
				}
				if mode == "steam":
					_steam_send_all(pkt, 0) # P2P_SEND_UNRELIABLE
				elif mode == "enet":
					var bytes := var_to_bytes(pkt)
					multiplayer.send_bytes(bytes, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)


func _steam_send_all(data: Dictionary, send_type: int) -> void:
	if _steam == null or _peer_steam_ids.is_empty():
		return
	var bytes := var_to_bytes(data)
	for pid in _peer_steam_ids:
		if pid != steam_id and pid > 0:
			_steam.call("sendP2PPacket", pid, bytes, send_type, 0)


func _poll_steam_packets() -> void:
	var guard := 0
	while guard < 32:
		guard += 1
		var pkt_sz := int(_steam.call("getAvailableP2PPacketSize", 0))
		if pkt_sz <= 0:
			break
		var res: Variant = _steam.call("readP2PPacket", pkt_sz, 0)
		if not (res is Dictionary):
			break
		var d: Dictionary = res
		var sender := int(d.get("remote_steam_id", 0))
		if sender <= 0:
			sender = int(d.get("steam_id_remote", 0))
		var raw_data: Variant = d.get("data", PackedByteArray())
		if raw_data is PackedByteArray:
			var parsed: Variant = bytes_to_var(raw_data as PackedByteArray)
			if parsed is Dictionary:
				_handle_packet("steam_%d" % sender, parsed as Dictionary)


func _poll_enet_packets() -> void:
	# High-level SceneMultiplayer uses MultiplayerPeer.get_packet via signal/polling if needed,
	# handled automatically via peer_packet when connected to SceneMultiplayer.
	pass


func _handle_packet(peer_key: String, msg: Dictionary) -> void:
	var mtype := String(msg.get("t", ""))
	if mtype == "st":
		emit_signal("state_received", peer_key, msg)
	elif mtype == "door":
		emit_signal("door_opened_remote", int(msg.get("r", -1)))


func _on_steam_lobby_created(connect_code: int, lobby_id: int) -> void:
	if connect_code != 1: # k_EResultOK == 1
		emit_signal("status_changed", "Ошибка создания Steam-лобби (%d)" % connect_code)
		mode = "offline"
		return
	current_lobby_id = lobby_id
	_steam.call("setLobbyData", lobby_id, "r00ms_tag", LOBBY_FILTER_TAG)
	_steam.call("setLobbyData", lobby_id, "name", "%s's r00ms" % persona_name)
	_steam.call("setLobbyData", lobby_id, "seed", str(run_seed))
	_refresh_steam_lobby_members()
	emit_signal("status_changed", get_summary_status())


func _on_steam_lobby_joined(lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != 1:
		emit_signal("status_changed", "Не удалось войти в лобби (%d)" % response)
		mode = "offline"
		return
	current_lobby_id = lobby_id
	_refresh_steam_lobby_members()
	emit_signal("status_changed", get_summary_status())


func _on_steam_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change_id: int, _state_flags: int) -> void:
	if lobby_id == current_lobby_id:
		_refresh_steam_lobby_members()
		emit_signal("status_changed", get_summary_status())


func _refresh_steam_lobby_members() -> void:
	if _steam == null or current_lobby_id <= 0:
		return
	var prev := _peer_steam_ids.duplicate()
	_peer_steam_ids.clear()
	var count := int(_steam.call("getNumLobbyMembers", current_lobby_id))
	for i in range(count):
		var mid := int(_steam.call("getLobbyMemberByIndex", current_lobby_id, i))
		if mid > 0 and mid != steam_id:
			_peer_steam_ids.append(mid)
	for old_id in prev:
		if not _peer_steam_ids.has(old_id):
			emit_signal("peer_disconnected", "steam_%d" % old_id)


func _on_steam_lobby_match_list(lobbies: Array) -> void:
	_found_lobbies.clear()
	if _steam == null:
		return
	for lid_raw in lobbies:
		var lid := int(lid_raw)
		var lname := String(_steam.call("getLobbyData", lid, "name"))
		if lname.is_empty():
			lname = "Лобби #%d" % lid
		var members := int(_steam.call("getNumLobbyMembers", lid))
		_found_lobbies.append({"id": lid, "name": lname, "members": members})
	emit_signal("lobbies_updated", _found_lobbies)
	emit_signal("status_changed", "Найдено лобби: %d" % _found_lobbies.size())


func _on_steam_p2p_session_request(remote_id: int) -> void:
	if _steam != null:
		_steam.call("acceptP2PSessionWithUser", remote_id)


func _on_steam_p2p_connect_fail(remote_id: int, _reason: int) -> void:
	emit_signal("peer_disconnected", "steam_%d" % remote_id)


func _on_enet_peer_connected(id: int) -> void:
	if not _enet_connected_ids.has(id):
		_enet_connected_ids.append(id)
	var sm := multiplayer as SceneMultiplayer
	if sm != null and not sm.peer_packet.is_connected(_on_enet_packet_received):
		sm.peer_packet.connect(_on_enet_packet_received)
	emit_signal("status_changed", get_summary_status())


func _on_enet_peer_disconnected(id: int) -> void:
	_enet_connected_ids.erase(id)
	emit_signal("peer_disconnected", "enet_%d" % id)
	emit_signal("status_changed", get_summary_status())


func _on_enet_connected_to_server() -> void:
	var sm := multiplayer as SceneMultiplayer
	if sm != null and not sm.peer_packet.is_connected(_on_enet_packet_received):
		sm.peer_packet.connect(_on_enet_packet_received)
	emit_signal("status_changed", get_summary_status())


func _on_enet_connection_failed() -> void:
	disconnect_session()
	emit_signal("status_changed", "ENet: не удалось подключиться к 127.0.0.1")


func _on_enet_packet_received(id: int, packet: PackedByteArray) -> void:
	var parsed: Variant = bytes_to_var(packet)
	if parsed is Dictionary:
		_handle_packet("enet_%d" % id, parsed as Dictionary)

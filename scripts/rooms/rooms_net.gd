class_name RoomsNet
extends Node

## Steam Spacewar (AppID 480) P2P Lobby + Shift+Tab Invite/Join + ENet Fallback Multiplayer for r00ms.
## Uses dynamic Engine.get_singleton("Steam") access so iOS / Android / headless builds never fail
## if Steam native runtime libraries are unavailable.

signal status_changed(text: String)
signal lobbies_updated(lobbies: Array)
signal door_opened_remote(room_index: int)
signal state_received(peer_key: String, data: Dictionary)
signal peer_disconnected(peer_key: String)
signal invite_received(inviter_name: String, lobby_id: int)
signal session_synced(seed_val: int, room_idx: int)

const SPACEWAR_APP_ID := 480
const ENET_PORT := 27480
const LOBBY_FILTER_TAG := "r00ms_spacewar_v1"
const FRIEND_FLAG_IMMEDIATE := 4

var steam_loaded := false
var steam_ready := false
var steam_status_text := "Steam не инициализирован"
var steam_id := 0
var persona_name := "Player"
var current_lobby_id := 0
var is_host := false
var mode := "offline" # "offline" | "steam" | "enet"
var run_seed := 0
var run_room_idx := 0

var _steam: Object = null
var _peer_steam_ids: Array[int] = []
var _found_lobbies: Array[Dictionary] = []
var _friend_lobby_entries: Array[Dictionary] = []

var _enet: ENetMultiplayerPeer = null
var _enet_connected_ids: Array[int] = []

var _send_accum := 0.0
var _send_tick := 0
var _callback_accum := 0.0
var _local_state: Dictionary = {}
var _pending_open_invite := false
var _pending_startup_lobby := 0
var _last_synced_lobby := 0


func _ready() -> void:
	_init_steam()
	if _pending_startup_lobby > 0 and steam_ready:
		call_deferred("_try_join_startup_lobby")


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
			# Enable Valve relay & initialize relay network so friends behind different NATs/networks can connect
			_steam.call("allowP2PPacketRelay", true)
			_steam.call("initRelayNetworkAccess")
			_connect_steam_signals()
			_pending_startup_lobby = _extract_cmdline_lobby()
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
	_safe_connect("lobby_data_update", _on_steam_lobby_data_update)
	_safe_connect("lobby_chat_update", _on_steam_lobby_chat_update)
	_safe_connect("lobby_invite", _on_steam_lobby_invite)
	_safe_connect("join_requested", _on_steam_join_requested)
	_safe_connect("join_game_requested", _on_steam_join_game_requested)
	_safe_connect("p2p_session_request", _on_steam_p2p_session_request)
	_safe_connect("p2p_session_connect_fail", _on_steam_p2p_connect_fail)


func _safe_connect(sig_name: String, cb: Callable) -> void:
	if _steam != null and _steam.has_signal(sig_name) and not _steam.is_connected(sig_name, cb):
		_steam.connect(sig_name, cb)


func _extract_cmdline_lobby() -> int:
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for i in range(all_args.size()):
		var arg := String(all_args[i])
		if arg == "+connect_lobby" and i + 1 < all_args.size():
			var lid := int(all_args[i + 1])
			if lid > 0:
				return lid
		elif arg.begins_with("+connect_lobby"):
			var lid2 := _parse_connect_lobby(arg)
			if lid2 > 0:
				return lid2
	return 0


func _parse_connect_lobby(connect_str: String) -> int:
	var s := connect_str.strip_edges()
	var idx := s.find("+connect_lobby")
	if idx < 0:
		return 0
	var tail := s.substr(idx + "+connect_lobby".length()).strip_edges()
	var parts := tail.split(" ", false)
	if parts.is_empty():
		return 0
	var tok := String(parts[0]).strip_edges()
	if tok.is_valid_int():
		return int(tok)
	return 0


func _try_join_startup_lobby() -> void:
	if _pending_startup_lobby > 0 and steam_ready:
		var lid := _pending_startup_lobby
		_pending_startup_lobby = 0
		join_steam_lobby(lid)


func is_online() -> bool:
	return mode != "offline"


func get_summary_status() -> String:
	if mode == "steam":
		if current_lobby_id > 0:
			return "Steam Spacewar (480) | Лобби %d | Игроков: %d%s" % [
				current_lobby_id,
				_peer_steam_ids.size() + 1,
				" [ХОСТ]" if is_host else ""
			]
		return "Steam Spacewar (480) | Подключение к лобби..."
	elif mode == "enet":
		return "ENet Тест 127.0.0.1:%d | Игроков: %d%s" % [
			ENET_PORT,
			_enet_connected_ids.size() + 1,
			" [ХОСТ]" if is_host else ""
		]
	return steam_status_text


func host_steam_lobby(seed_val: int, room_idx: int = 0) -> bool:
	if not steam_ready or _steam == null:
		emit_signal("status_changed", steam_status_text)
		return false
	disconnect_session()
	is_host = true
	run_seed = seed_val
	run_room_idx = room_idx
	mode = "steam"
	# 2 = LOBBY_TYPE_PUBLIC, max 4 players (joinable via Shift+Tab & worldwide search)
	_steam.call("createLobby", 2, 4)
	emit_signal("status_changed", "Создание Steam-лобби (Spacewar 480)...")
	return true


func update_lobby_progress(seed_val: int, room_idx: int) -> void:
	run_seed = seed_val
	run_room_idx = room_idx
	if mode != "steam" or _steam == null or not steam_ready or current_lobby_id <= 0:
		return
	if is_host:
		_steam.call("setLobbyData", current_lobby_id, "seed", str(run_seed))
		_steam.call("setLobbyData", current_lobby_id, "room", str(run_room_idx))
	_update_rich_presence()


func _collect_friend_lobbies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not steam_ready or _steam == null:
		return result
	var fc := int(_steam.call("getFriendCount", FRIEND_FLAG_IMMEDIATE))
	var seen: Dictionary = {}
	for i in range(fc):
		var fid := int(_steam.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE))
		if fid <= 0 or fid == steam_id:
			continue
		var fname := String(_steam.call("getFriendPersonaName", fid))
		var flobby := 0
		var fappid := 0
		var fgame: Variant = _steam.call("getFriendGamePlayed", fid)
		if fgame is Dictionary:
			var fd: Dictionary = fgame
			fappid = int(fd.get("id", fd.get("game_id", 0)))
			flobby = int(fd.get("lobby", fd.get("lobby_id", 0)))
		if flobby <= 0:
			var conn := String(_steam.call("getFriendRichPresence", fid, "connect"))
			flobby = _parse_connect_lobby(conn)
		if flobby > 0 and (fappid == 0 or fappid == SPACEWAR_APP_ID) and not seen.has(flobby):
			seen[flobby] = true
			_steam.call("requestLobbyData", flobby)
			var lname := String(_steam.call("getLobbyData", flobby, "name"))
			if lname.is_empty():
				lname = "%s's r00ms" % fname
			var members := maxi(int(_steam.call("getNumLobbyMembers", flobby)), 1)
			result.append({
				"id": flobby,
				"name": lname,
				"friend_name": fname,
				"members": members,
				"is_friend": true,
				"is_self": (flobby == current_lobby_id),
			})
	return result


func _merge_lobby_lists(public_lobbies: Array) -> void:
	_found_lobbies.clear()
	var merged: Dictionary = {}
	for item in _friend_lobby_entries:
		var lid := int(item.get("id", 0))
		if lid > 0:
			merged[lid] = item.duplicate()

	if _steam != null:
		for lid_raw in public_lobbies:
			var lid := int(lid_raw)
			if lid <= 0:
				continue
			var lname := String(_steam.call("getLobbyData", lid, "name"))
			if lname.is_empty():
				lname = "Лобби #%d" % lid
			var members := maxi(int(_steam.call("getNumLobbyMembers", lid)), 1)
			if merged.has(lid):
				var ex: Dictionary = merged[lid]
				if not lname.begins_with("Лобби #"):
					ex["name"] = lname
				ex["members"] = members
			else:
				merged[lid] = {
					"id": lid,
					"name": lname,
					"friend_name": "",
					"members": members,
					"is_friend": false,
					"is_self": (lid == current_lobby_id),
				}

	for lid_key in merged.keys():
		_found_lobbies.append(merged[lid_key])

	# Put friends & other people's lobbies first, current own lobby last
	_found_lobbies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_self := bool(a.get("is_self", false))
		var b_self := bool(b.get("is_self", false))
		if a_self != b_self:
			return not a_self
		var a_fr := bool(a.get("is_friend", false))
		var b_fr := bool(b.get("is_friend", false))
		if a_fr != b_fr:
			return a_fr
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)


func search_steam_lobbies() -> bool:
	if not steam_ready or _steam == null:
		emit_signal("status_changed", steam_status_text)
		return false
	_friend_lobby_entries = _collect_friend_lobbies()
	if not _friend_lobby_entries.is_empty():
		_merge_lobby_lists([])
		emit_signal("lobbies_updated", _found_lobbies)

	_steam.call("addRequestLobbyListDistanceFilter", 3) # LOBBY_DISTANCE_FILTER_WORLDWIDE = 3
	_steam.call("addRequestLobbyListResultCountFilter", 50)
	_steam.call("addRequestLobbyListStringFilter", "r00ms_tag", LOBBY_FILTER_TAG, 0)
	_steam.call("requestLobbyList")
	emit_signal("status_changed", "Поиск лобби друзей и мира Spacewar (480)...")
	return true


func join_steam_lobby(lobby_id: int) -> bool:
	if not steam_ready or _steam == null or lobby_id <= 0:
		emit_signal("status_changed", steam_status_text)
		return false
	if mode == "steam" and current_lobby_id == lobby_id:
		emit_signal("status_changed", get_summary_status())
		return true
	disconnect_session()
	is_host = false
	_last_synced_lobby = 0
	mode = "steam"
	_steam.call("joinLobby", lobby_id)
	emit_signal("status_changed", "Подключение к Steam-лобби %d..." % lobby_id)
	return true


func open_steam_invite_overlay(seed_val: int = 0, room_idx: int = 0) -> void:
	if not steam_ready or _steam == null:
		emit_signal("status_changed", "Запустите Steam, чтобы приглашать через Shift+Tab")
		return
	if current_lobby_id > 0:
		_steam.call("setLobbyJoinable", current_lobby_id, true)
		_update_rich_presence()
		_steam.call("activateGameOverlayInviteDialog", current_lobby_id)
		emit_signal("status_changed", "Открыто окно приглашений Steam (Shift+Tab)")
	else:
		_pending_open_invite = true
		host_steam_lobby(seed_val, room_idx)


func _update_rich_presence() -> void:
	if not steam_ready or _steam == null:
		return
	if mode == "steam" and current_lobby_id > 0:
		_steam.call("setRichPresence", "status", "r00ms A-%03d" % run_room_idx)
		_steam.call("setRichPresence", "connect", "+connect_lobby %d" % current_lobby_id)
	else:
		_steam.call("clearRichPresence")


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
		_steam.call("clearRichPresence")
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
	_last_synced_lobby = 0
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
			_send_tick += 1
			var reliable_hb := (_send_tick % 10 == 0)
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
					_steam_send_all(pkt, 2 if reliable_hb else 0)
				elif mode == "enet":
					var bytes := var_to_bytes(pkt)
					multiplayer.send_bytes(bytes, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable_hb else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)


func _steam_send_all(data: Dictionary, send_type: int) -> void:
	if _steam == null or _peer_steam_ids.is_empty():
		return
	var bytes := var_to_bytes(data)
	for pid in _peer_steam_ids:
		if pid != steam_id and pid > 0:
			_steam.call("sendP2PPacket", pid, bytes, send_type, 0)


func _poll_steam_packets() -> void:
	var guard := 0
	while guard < 128:
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
	pass


func _handle_packet(peer_key: String, msg: Dictionary) -> void:
	var mtype := String(msg.get("t", ""))
	if mtype == "st":
		emit_signal("state_received", peer_key, msg)
	elif mtype == "door":
		emit_signal("door_opened_remote", int(msg.get("r", -1)))
	elif mtype == "hi":
		# Touch P2P session alive; no state needed beyond connection warmup
		pass


func _try_emit_lobby_sync(lobby_id: int) -> void:
	if _steam == null or lobby_id <= 0 or is_host or _last_synced_lobby == lobby_id:
		return
	var seed_str := String(_steam.call("getLobbyData", lobby_id, "seed"))
	if seed_str.is_empty() or not seed_str.is_valid_int():
		return
	var room_str := String(_steam.call("getLobbyData", lobby_id, "room"))
	var room_v := int(room_str) if room_str.is_valid_int() else 0
	_last_synced_lobby = lobby_id
	emit_signal("session_synced", int(seed_str), room_v)


func _on_steam_lobby_created(connect_code: int, lobby_id: int) -> void:
	if connect_code != 1: # k_EResultOK == 1
		_pending_open_invite = false
		emit_signal("status_changed", "Ошибка создания Steam-лобби (%d)" % connect_code)
		mode = "offline"
		return
	current_lobby_id = lobby_id
	is_host = true
	_steam.call("setLobbyJoinable", lobby_id, true)
	_steam.call("setLobbyData", lobby_id, "r00ms_tag", LOBBY_FILTER_TAG)
	_steam.call("setLobbyData", lobby_id, "name", "%s's r00ms" % persona_name)
	_steam.call("setLobbyData", lobby_id, "seed", str(run_seed))
	_steam.call("setLobbyData", lobby_id, "room", str(run_room_idx))
	_refresh_steam_lobby_members()
	_update_rich_presence()
	emit_signal("status_changed", get_summary_status())
	if _pending_open_invite:
		_pending_open_invite = false
		_steam.call("activateGameOverlayInviteDialog", current_lobby_id)


func _on_steam_lobby_joined(lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != 1:
		emit_signal("status_changed", "Не удалось войти в лобби (%d)" % response)
		mode = "offline"
		return
	current_lobby_id = lobby_id
	mode = "steam"
	var owner_id := int(_steam.call("getLobbyOwner", lobby_id))
	is_host = (owner_id == steam_id)
	_refresh_steam_lobby_members()
	_update_rich_presence()
	_steam.call("requestLobbyData", lobby_id)
	_steam_send_all({"t": "hi", "n": persona_name}, 2)
	emit_signal("status_changed", get_summary_status())
	_try_emit_lobby_sync(lobby_id)


func _on_steam_lobby_data_update(success: int, lobby_id: int, _member_id: int) -> void:
	if success == 1 and lobby_id == current_lobby_id:
		_try_emit_lobby_sync(lobby_id)
	elif success == 1 and not _friend_lobby_entries.is_empty():
		var changed := false
		for entry in _friend_lobby_entries:
			if int(entry.get("id", 0)) == lobby_id and _steam != null:
				var lname := String(_steam.call("getLobbyData", lobby_id, "name"))
				if not lname.is_empty():
					entry["name"] = lname
				entry["members"] = maxi(int(_steam.call("getNumLobbyMembers", lobby_id)), 1)
				changed = true
		if changed:
			_merge_lobby_lists([])
			emit_signal("lobbies_updated", _found_lobbies)


func _on_steam_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change_id: int, _state_flags: int) -> void:
	if lobby_id == current_lobby_id:
		var owner_id := int(_steam.call("getLobbyOwner", lobby_id))
		is_host = (owner_id == steam_id)
		_refresh_steam_lobby_members()
		_steam_send_all({"t": "hi", "n": persona_name}, 2)
		emit_signal("status_changed", get_summary_status())


func _on_steam_lobby_invite(inviter_id: int, lobby_id: int, _game_id: int) -> void:
	var inv_name := String(_steam.call("getFriendPersonaName", inviter_id)) if _steam != null else "Друг"
	emit_signal("invite_received", inv_name, lobby_id)
	emit_signal("status_changed", "Приглашение от %s (примите в Shift+Tab)" % inv_name)


func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	if lobby_id > 0:
		join_steam_lobby(lobby_id)


func _on_steam_join_game_requested(_user_id: int, connect_str: String) -> void:
	var lid := _parse_connect_lobby(connect_str)
	if lid > 0:
		join_steam_lobby(lid)


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
			_steam.call("acceptP2PSessionWithUser", mid)
	for old_id in prev:
		if not _peer_steam_ids.has(old_id):
			emit_signal("peer_disconnected", "steam_%d" % old_id)


func _on_steam_lobby_match_list(lobbies: Array) -> void:
	if _steam == null:
		return
	_friend_lobby_entries = _collect_friend_lobbies()
	_merge_lobby_lists(lobbies)
	emit_signal("lobbies_updated", _found_lobbies)
	var others := 0
	for item in _found_lobbies:
		if not bool(item.get("is_self", false)):
			others += 1
	emit_signal("status_changed", "Найдено лобби: %d (других игроков: %d)" % [_found_lobbies.size(), others])


func _on_steam_p2p_session_request(remote_id: int) -> void:
	if _steam != null:
		_steam.call("acceptP2PSessionWithUser", remote_id)


func _on_steam_p2p_connect_fail(remote_id: int, _reason: int) -> void:
	# Never despawn a peer who is still in the Steam lobby; recover P2P / relay session instead
	if _steam != null and _peer_steam_ids.has(remote_id):
		_steam.call("closeP2PSessionWithUser", remote_id)
		_steam.call("acceptP2PSessionWithUser", remote_id)
		var bytes := var_to_bytes({"t": "hi", "n": persona_name})
		_steam.call("sendP2PPacket", remote_id, bytes, 2, 0)


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

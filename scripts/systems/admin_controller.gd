class_name AdminController
extends Node

## Manages Admin Panel permissions, cheat toggles, and guaranteed full reset across runs.

var cheats_used := false
var god_mode := false
var inf_stamina := false
var noclip := false
var speed_mult := 1.0
var inf_battery := false
var granted_by_host := false


func can_use_admin(active_modifiers: Dictionary, net: RoomsNet) -> bool:
	if not bool(active_modifiers.get("admin_panel", false)):
		return false
	if net == null or not net.is_online():
		return true
	return net.is_host or granted_by_host


func is_active(active_modifiers: Dictionary, net: RoomsNet) -> bool:
	return can_use_admin(active_modifiers, net)


func reset_all(player_col: CollisionShape3D = null, revoke_grant: bool = false) -> void:
	god_mode = false
	inf_stamina = false
	noclip = false
	speed_mult = 1.0
	inf_battery = false
	cheats_used = false
	if revoke_grant:
		granted_by_host = false
	Engine.time_scale = 1.0
	if is_instance_valid(player_col):
		player_col.disabled = false


func revoke_host_grant() -> void:
	granted_by_host = false

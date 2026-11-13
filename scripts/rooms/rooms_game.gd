extends "res://scripts/rooms/rooms_entities.gd"

func _ready() -> void:
	_assets = RoomBuilder.create_shared_assets()
	_load_entity_sprites()

	_load_render_settings()
	_apply_audio_settings(false)
	_setup_environment()
	_build_entity_nodes()
	_build_viewmodel()
	_build_net()
	_build_ui()
	_sync_settings_ui()
	_apply_render_quality(_render_quality, false)
	_refresh_mobile_mode()
	_reset_run()

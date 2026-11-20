class_name RoomsI18n
extends RefCounted

## Central RU / EN localization dictionary for r00ms.

static var lang: String = "ru"

const DICT: Dictionary = {
	# Language switcher
	"lang_btn": {"ru": "Язык: Русский", "en": "Language: English"},
	"lang_short": {"ru": "RU", "en": "EN"},

	# Epilepsy / Photosensitivity Disclaimer
	"epilepsy_title": {
		"ru": "⚠  ПРЕДУПРЕЖДЕНИЕ О ФОТОЧУВСТВИТЕЛЬНОСТИ",
		"en": "⚠  PHOTOSENSITIVITY WARNING",
	},
	"epilepsy_body": {
		"ru": "Эта игра содержит яркие вспышки света (A-075), резкие стробоскопические эффекты,\nбыстрое мерцание экрана, помехи и внезапные громкие звуки.\n\nУ небольшого числа людей подобные визуальные эффекты могут вызвать приступ\nфотосенситивной эпилепсии, головокружение или дискомфорт.\nЕсли вы почувствуете недомогание — немедленно прекратите игру.",
		"en": "This game contains intense camera flashes (A-075), sudden strobing effects,\nrapid screen static, flickering lights, and loud horror audio.\n\nA small percentage of people may experience photosensitive seizures,\ndizziness, or discomfort when exposed to certain flashing patterns.\nStop playing immediately if you experience any symptoms.",
	},
	"epilepsy_continue": {"ru": "ПРОДОЛЖИТЬ", "en": "CONTINUE"},
	"epilepsy_hint": {"ru": "Нажмите кнопку, Enter, Пробел или коснитесь экрана", "en": "Click Continue, press Enter / Space, or tap"},

	# Main Menu
	"menu_start": {"ru": "начать", "en": "start"},
	"menu_dummi_face": {"ru": "рожица dummi", "en": "dummi face"},
	"menu_credits": {"ru": "авторы", "en": "credits"},
	"menu_settings": {"ru": "настройки", "en": "settings"},
	"menu_solo": {"ru": "одиночная игра", "en": "solo"},
	"menu_multi": {"ru": "мультиплеер", "en": "multiplayer"},
	"menu_back": {"ru": "назад", "en": "back"},
	"menu_back_arrow": {"ru": "← назад", "en": "← back"},
	"menu_exit": {"ru": "выход", "en": "exit"},
	"menu_invite_steam": {"ru": "пригласить друзей steam", "en": "invite steam friends"},
	"menu_waiting_host": {"ru": "Ожидание хоста...", "en": "Waiting for host..."},
	"menu_lan_host": {"ru": "локальная сеть (хост)", "en": "local network (host)"},
	"menu_hotspot_connect": {"ru": "⚡ Режим модема: войти (%s)", "en": "⚡ Hotspot: Quick Join (%s)"},
	"menu_hotspot_active": {"ru": "📱 Точка доступа активна (Хост: %s:%d)", "en": "📱 Hotspot active (Host: %s:%d)"},
	"toast_hotspot_connecting": {"ru": "Подключение к точке доступа %s...", "en": "Connecting to hotspot %s..."},
	"menu_your_ip": {"ru": "Ваш IP: %s:%d", "en": "Your IP: %s:%d"},
	"menu_copy_ip": {"ru": "скопировать свой IP", "en": "copy my IP"},
	"menu_join": {"ru": "войти", "en": "join"},
	"menu_lan_found_hdr": {"ru": "Серверы в локальной сети:", "en": "LAN servers found:"},
	"menu_lan_searching": {"ru": "Поиск игр в Wi-Fi / LAN...", "en": "Scanning Wi-Fi / LAN..."},
	"menu_lan_join_entry": {"ru": "▶ %s (%s) [%d игр.]", "en": "▶ %s (%s) [%d pl.]"},
	"menu_modifiers": {"ru": "Модификаторы", "en": "Modifiers"},
	"menu_players": {"ru": "Игроки", "en": "Players"},
	"menu_you_waiting": {"ru": "• вы (ожидание подключения)", "en": "• you (waiting for connection)"},
	"menu_you": {"ru": "• вы", "en": "• you"},
	"menu_credits_body": {
		"ru": "r00ms\n\nминималистичный хоррор, Секция A\n\nМонстры: A-60 · A-075 · A-90 · A-120\nТьма\n\nсделано командой r00ms\n\nспрайты, звуки и кофеин",
		"en": "r00ms\n\nminimal horror, section A\n\nMonsters: A-60 · A-075 · A-90 · A-120\nThe Darkness\n\nmade by the r00ms team\n\nsprites, sounds and caffeine",
	},

	# Modifiers
	"mod_admin_panel": {"ru": "Админ-панель", "en": "Admin Panel"},
	"mod_wet_floor": {"ru": "Скользкий пол", "en": "Wet Floor"},
	"mod_bad_time": {"ru": "Тяжёлое время", "en": "Bad Time"},
	"mod_make_haste": {"ru": "Спешка", "en": "Make Haste"},
	"mod_lights_out": {"ru": "Без света", "en": "Lights Out"},
	"mod_sprint_fatigue": {"ru": "Усталость", "en": "Sprint Fatigue"},
	"mod_none": {"ru": "• нет (стандарт)", "en": "• none (default)"},
	"on": {"ru": "ВКЛ", "en": "ON"},
	"off": {"ru": "ВЫКЛ", "en": "OFF"},
	"enabled": {"ru": "ВКЛЮЧЕН", "en": "ENABLED"},
	"disabled": {"ru": "ВЫКЛЮЧЕН", "en": "DISABLED"},

	# Pause / Victory
	"pause_continue": {"ru": "продолжить", "en": "continue"},
	"pause_settings": {"ru": "настройки", "en": "settings"},
	"pause_admin": {"ru": "админ-панель", "en": "admin panel"},
	"pause_exit": {"ru": "в меню", "en": "exit"},
	"pause_modifiers": {"ru": "модификаторы", "en": "modifiers"},
	"victory_desc": {
		"ru": "Секция A пройдена (300 комнат) за %02d:%02d\nпродолжайте бесконечный забег или выйдите.",
		"en": "section A cleared (300 rooms) in %02d:%02d\ncontinue into the endless run, or exit.",
	},

	# Settings
	"set_hdr_audio": {"ru": "звук", "en": "audio"},
	"set_master": {"ru": "Общая громкость", "en": "Master Volume"},
	"set_entities": {"ru": "Монстры", "en": "Entities"},
	"set_sfx": {"ru": "Эффекты и фонарик", "en": "SFX & Flashlight"},
	"set_ambient": {"ru": "Атмосфера", "en": "Ambience"},
	"set_mute_on": {"ru": "Звук: ВЫКЛ [M]", "en": "Audio: MUTED [M]"},
	"set_mute_off": {"ru": "Звук: ВКЛ [M]", "en": "Audio: ON [M]"},
	"set_reset_audio": {"ru": "сбросить звук", "en": "reset audio"},
	"set_output_prefix": {"ru": "Вывод: ", "en": "Output: "},
	"set_input_prefix": {"ru": "Микрофон: ", "en": "Mic: "},
	"set_hdr_controls": {"ru": "камера и управление", "en": "camera & controls"},
	"set_sens": {"ru": "Чувствительность", "en": "Sensitivity"},
	"set_fov": {"ru": "Поле зрения (FOV)", "en": "Field of View (FOV)"},
	"set_head_bob": {"ru": "Покачивание камеры: %s", "en": "Head Bob: %s"},
	"set_hdr_game": {"ru": "игра, язык и рендер", "en": "game, language & render"},
	"set_restart": {"ru": "начать заново (A-000)", "en": "restart run (A-000)"},
	"set_mobile_auto": {"ru": "Сенсорное управление: АВТО", "en": "Touch Controls: AUTO"},
	"set_mobile_on": {"ru": "Сенсорное управление: ВКЛ", "en": "Touch Controls: ON"},
	"set_mobile_off": {"ru": "Сенсорное управление: ВЫКЛ", "en": "Touch Controls: OFF"},
	"set_quality": {"ru": "Графика: %s", "en": "Graphics: %s"},
	"set_backend": {"ru": "Бэкенд: %s%s", "en": "Backend: %s%s"},
	"set_restart_render": {"ru": "перезапустить с новым рендером", "en": "restart with new renderer"},
	"qual_mobile": {"ru": "Мобильный FPS", "en": "Mobile FPS"},
	"qual_medium": {"ru": "Средний", "en": "Medium"},
	"qual_high": {"ru": "Высокий", "en": "High"},

	# Admin Panel
	"adm_title": {"ru": "админ-консоль", "en": "admin console"},
	"adm_sub": {"ru": "[ прогресс и рекорды аннулируются ]", "en": "[ progress & records are voided ]"},
	"adm_host_only": {"ru": "Панель доступна только хосту!", "en": "Admin panel is host-only!"},
	"adm_revive": {"ru": "возродиться", "en": "revive"},
	"adm_kill": {"ru": "убить себя", "en": "kill self"},
	"adm_heal": {"ru": "+50 hp", "en": "+50 hp"},
	"adm_god": {"ru": "бог-режим: %s", "en": "god mode: %s"},
	"adm_stam": {"ru": "беск. выносливость: %s", "en": "infinite stamina: %s"},
	"adm_noclip": {"ru": "noclip / полёт: %s", "en": "noclip / fly: %s"},
	"adm_speed": {"ru": "ускорение: %.1fx", "en": "speed boost: %.1fx"},
	"adm_bat": {"ru": "беск. заряд: %s", "en": "infinite battery: %s"},
	"adm_gummy": {"ru": "выдать трясосвет", "en": "give gummy flashlight"},
	"adm_bats5": {"ru": "+5 батареек", "en": "+5 batteries"},
	"adm_skip5": {"ru": "пропустить +5 комнат", "en": "skip +5 rooms"},
	"adm_skip10": {"ru": "пропустить +10 комнат", "en": "skip +10 rooms"},
	"adm_despawn": {"ru": "убрать всех монстров", "en": "despawn all monsters"},
	"adm_blackout": {"ru": "переключить блэкаут", "en": "toggle blackout"},
	"adm_timescale": {"ru": "скорость игры: %.1fx", "en": "game speed: %.1fx"},
	"adm_revive_all": {"ru": "возродить всех", "en": "revive all peers"},
	"adm_spawn_a60": {"ru": "заспавнить a-60", "en": "spawn a-60"},
	"adm_spawn_a60p": {"ru": "заспавнить a-60 prime", "en": "spawn a-60 prime"},
	"adm_spawn_a075": {"ru": "заспавнить a-075 (затвор)", "en": "spawn a-075 (shutter)"},
	"adm_spawn_a085": {"ru": "заспавнить a-085 (выселитель)", "en": "spawn a-085 (breacher)"},
	"adm_spawn_a160": {"ru": "заспавнить a-160 (двойник)", "en": "spawn a-160 (mimic)"},
	"adm_spawn_a90": {"ru": "заспавнить a-90", "en": "spawn a-90"},
	"adm_spawn_a120": {"ru": "заспавнить a-120", "en": "spawn a-120"},
	"adm_tp_door": {"ru": "тп к следующей двери", "en": "tp to next door"},
	"adm_refill": {"ru": "зарядить фонарики", "en": "refill battery"},
	"adm_grant_all": {"ru": "выдать админку всем", "en": "grant admin to all"},

	# Face Editor
	"fe_title": {"ru": "редактор рожицы dummi", "en": "dummi face editor"},
	"fe_sub": {"ru": "ЛКМ — рисовать · ПКМ — стереть", "en": "LMB — draw · RMB — erase"},
	"fe_color": {"ru": "цвет", "en": "color"},
	"fe_brush": {"ru": "кисть", "en": "brush"},
	"fe_eraser": {"ru": "ластик", "en": "eraser"},
	"fe_undo": {"ru": "отмена", "en": "undo"},
	"fe_clear": {"ru": "очистить", "en": "clear"},
	"fe_save": {"ru": "сохранить", "en": "save face"},

	# HUD Prompts & Labels
	"prompt_exit_desk": {"ru": "[W / S] Вылезти из-под тумбочки", "en": "[W / S] Crawl out from under desk"},
	"prompt_exit_fridge": {"ru": "[W] Выйти вперёд  |  [S] Выйти лицом к холодильнику", "en": "[W] Exit forward  |  [S] Exit facing fridge"},
	"prompt_exit_locker": {"ru": "[W] Выйти вперёд  |  [S] Выйти лицом к шкафу", "en": "[W] Exit forward  |  [S] Exit facing cabinet"},
	"prompt_door_locked": {"ru": "Дверь A-020 (ЗАБЛОКИРОВАНА)", "en": "Door A-020 (LOCKED)"},
	"prompt_door_open": {"ru": "Открыть дверь A-%03d", "en": "Open Door A-%03d"},
	"prompt_occupied": {"ru": "Занято", "en": "Occupied"},
	"prompt_hide": {"ru": "Спрятаться", "en": "Hide"},
	"prompt_hide_locker": {"ru": "Спрятаться в шкаф", "en": "Hide in cabinet"},
	"prompt_hide_fridge": {"ru": "Спрятаться в холодильник", "en": "Hide in fridge"},
	"prompt_hide_desk": {"ru": "Спрятаться под тумбочку", "en": "Hide under desk"},
	"prompt_lever_used": {"ru": "Рычаг (уже опущен)", "en": "Lever (already pulled)"},
	"prompt_lever_pull": {"ru": "Потянуть рычаг (+время)", "en": "Pull lever (+time)"},
	"prompt_pickup": {"ru": "Взять: %s", "en": "Take: %s"},
	"item_battery": {"ru": "Батарейка", "en": "Battery"},
	"item_gummy": {"ru": "Трясосвет", "en": "Shakerlight"},
	"item_medkit": {"ru": "Аптечка (+45 HP)", "en": "Medkit (+45 HP)"},
	"haste_time": {"ru": "[ ВРЕМЯ: %02d:%02d ]", "en": "[ TIME: %02d:%02d ]"},

	# Chat & Spectate
	"chat_placeholder": {"ru": "сообщение... (Enter — отправить, Esc — закрыть)", "en": "message... (Enter to send, Esc to close)"},
	"chat_hint": {"ru": "T — чат · V — голос", "en": "T — chat · V — voice"},
	"chat_readonly": {"ru": "режим наблюдателя: чат только для чтения", "en": "spectator mode: read-only chat"},
	"spec_btn": {"ru": "[НАБЛЮДЕНИЕ]", "en": "[SPECTATE]"},
	"spec_prev": {"ru": "<< Назад", "en": "<< Prev"},
	"spec_next": {"ru": "Вперёд >>", "en": "Next >>"},
	"spec_restart": {"ru": "Рестарт [R]", "en": "Restart [R]"},
	"spec_none": {"ru": "Нет активных игроков — нажмите [R] для рестарта", "en": "No active players — press [R] to restart"},
	"spec_watching": {"ru": "Наблюдение: %s [A-%03d]", "en": "Spectating: %s [A-%03d]"},
	"spec_dead_suffix": {"ru": " (МЁРТВ — [R] Рестарт)", "en": " (DEAD — [R] Restart)"},
	"spec_alive_suffix": {"ru": "   |   A-D — Сменить   |   [R] — Рестарт", "en": "   |   A-D — Switch   |   [R] — Restart"},

	# Architect / Death Report
	"arch_restart": {"ru": "> [R] НАЧАТЬ ЗАНОВО", "en": "> [R] RESTART RUN"},
	"arch_meta": {"ru": "СУЩНОСТЬ: %s  |  СМЕРТЕЙ: #%d  |  РЕКОРД: A-%03d", "en": "ENTITY: %s  |  DEATHS: #%d  |  BEST: A-%03d"},
	"arch_line": {"ru": "СТРОКА %02d / %02d", "en": "LINE %02d / %02d"},
	"arch_report": {
		"ru": "[r00ms отчёт о смерти]\n---------------------------------------------------------\nСущность: %s\nПройдено комнат: %s\nВсего смертей: #%d\nЛучший рекорд: A-%03d\n\nСовет:\n%s\n---------------------------------------------------------",
		"en": "[r00ms death report]\n---------------------------------------------------------\nEntity: %s\nRooms cleared: %s\nTotal deaths: #%d\nBest record: A-%03d\n\nTip:\n%s\n---------------------------------------------------------",
	},
	"arch_admin_void": {"ru": "A-%03d (АДМИНКА — ПРОГРЕСС НЕ ЗАСЧИТАН)", "en": "A-%03d (ADMIN — PROGRESS VOIDED)"},

	# Toasts & Notifications
	"toast_start": {"ru": "Вы в Секции A. Откройте дверь A-001, чтобы начать.", "en": "You are in Section A. Open Door A-001 to begin."},
	"toast_face_saved": {"ru": "Рожица dummi сохранена и синхронизирована!", "en": "dummi face saved and synced!"},
	"toast_audio_reset": {"ru": "Громкость сброшена по умолчанию", "en": "Audio levels reset to defaults"},
	"toast_ip_copied": {"ru": "IP скопирован в буфер обмена!", "en": "IP copied to clipboard!"},
	"toast_lan_started": {"ru": "Сервер запущен! Адрес: %s:%d (друзья увидят в списке LAN)", "en": "Server started! Address: %s:%d (auto-visible on LAN)"},
	"toast_lan_joining": {"ru": "Подключение к %s:%d...", "en": "Connecting to %s:%d..."},
	"toast_lan_bad_ip": {"ru": "Введите корректный IP (например 192.168.1.10)", "en": "Enter a valid IP address (e.g. 192.168.1.10)"},
	"toast_lan_fail": {"ru": "Не удалось подключиться! Проверьте Wi-Fi и брандмауэр (UDP 27480).", "en": "Connection failed! Check Wi-Fi network and firewall (UDP 27480)."},
	"toast_door20": {"ru": "Дверь A-020 заблокирована! Сзади нарастает рёв A-60... Прячьтесь в шкаф!", "en": "Door A-020 is locked! A-60 is roaring behind you... Hide in a cabinet!"},
	"toast_power_flicker": {"ru": "Напряжение в сети нестабильно! Свет бешено искрит...", "en": "Power grid unstable! The lights are flickering wildly..."},
	"toast_power_out": {"ru": "Электричество вырубилось! Дальше света больше не будет...", "en": "Power went out! There will be no lights ahead..."},
	"toast_cp": {"ru": "Контрольная точка A-%03d достигнута!", "en": "Checkpoint A-%03d reached!"},
	"toast_checkpoint_unlocked": {"ru": "Открыт новый чекпоинт A-%03d!", "en": "New checkpoint A-%03d unlocked!"},
	"menu_checkpoint": {"ru": "Чекпоинт: A-%03d", "en": "Checkpoint: A-%03d"},
	"toast_god_dmg": {"ru": "Бог-режим защитил от урона (%s)!", "en": "God mode blocked damage (%s)!"},
	"toast_god_death": {"ru": "Бог-режим защитил от гибели (%s)!", "en": "God mode prevented death (%s)!"},
	"toast_a075_blind": {"ru": "A-075 (Затвор) ОСЛЕПИЛ ВАС!", "en": "A-075 (Shutter) BLINDED YOU!"},
	"toast_a075_spawn": {"ru": "A-075 (Затвор)! Выключите фонарик или зажмите [ПКМ] с Трясосветом и отвернитесь!", "en": "A-075 (Shutter)! Turn off flashlight or hold [RMB] with Shakerlight and look away!"},
	"toast_a085_hit": {"ru": "A-085 сорвал дверь шкафа и выбросил вас! (-90 HP)", "en": "A-085 tore off the locker door and threw you out! (-90 HP)"},
	"toast_a085_spawn": {"ru": "Грохот поезда в коридоре! Не лезьте в шкаф!", "en": "Freight train rumble in the hallway! Do not hide in lockers!"},
	"toast_a160_spawn": {"ru": "A-160 (Двойник) стоит впереди!", "en": "A-160 (The Mimic) is waiting ahead!"},
	"toast_battery_got": {"ru": "Батарейка (+1) — Всего: %d. [R] для зарядки (нужно 2)", "en": "Battery (+1) — Total: %d. Press [R] to recharge (needs 2)"},
	"toast_gummy_got": {"ru": "Выдан Трясосвет! Зажмите [ПКМ] чтобы заряжать.", "en": "Shakerlight equipped! Hold [RMB] to charge."},
	"toast_medkit_got": {"ru": "+45 HP восстановлено", "en": "+45 HP restored"},
	"toast_lever_done": {"ru": "Рычаг уже опущен!", "en": "Lever already pulled!"},
	"toast_lever_bonus": {"ru": "Рычаг активирован! +%d сек к таймеру", "en": "Lever pulled! +%d sec to timer"},
	"toast_flash_empty": {"ru": "Фонарик разряжен! Соберите 2 батарейки и нажмите [R].", "en": "Flashlight depleted! Collect 2 batteries and press [R]."},
	"toast_flash_low": {"ru": "Низкий заряд фонарика! Нажмите [R] с 2 батарейками.", "en": "Flashlight battery low! Press [R] with 2 batteries."},
	"toast_flash_full": {"ru": "Обычный фонарик уже полностью заряжен", "en": "Flashlight is already fully charged"},
	"toast_flash_need2": {"ru": "Нужно 2 батарейки для зарядки (%d/2)", "en": "Need 2 batteries to recharge (%d/2)"},
	"toast_flash_reloaded": {"ru": "Фонарик заряжен (-2 батарейки, осталось: %d)", "en": "Flashlight recharged (-2 batteries, left: %d)"},
	"toast_darkness_repel": {"ru": "Обычный фонарик отпугнул Тьму (слабый режим)!", "en": "Flashlight repelled The Darkness (low-power mode)!"},
	"toast_spot_occupied": {"ru": "Спот занят!", "en": "Hiding spot occupied!"},
	"toast_mute_on": {"ru": "Звук выключен", "en": "Audio muted"},
	"toast_mute_off": {"ru": "Звук включён", "en": "Audio unmuted"},
	"toast_mods_menu_only": {"ru": "Модификаторы настраиваются только до начала игры!", "en": "Modifiers can only be changed before starting!"},
	"toast_mods_host_only": {"ru": "Модификаторы может изменять только хост!", "en": "Only the host can change modifiers!"},
	"toast_host_start_only": {"ru": "Только хост может запустить игру!", "en": "Only the host can start the game!"},
	"toast_quality": {"ru": "Качество рендера: %s", "en": "Render quality: %s"},
	"toast_restart_mobile": {"ru": "Закройте и откройте приложение заново", "en": "Close and reopen the app to apply"},
	"toast_sync": {"ru": "Синхронизация с лобби (A-%03d)", "en": "Synced with lobby (A-%03d)"},
	"toast_admin_granted": {"ru": "Хост предоставил вам доступ к панели администратора!", "en": "Host granted you Admin Panel access!"},
	"toast_revived": {"ru": "Возрождение выполнено!", "en": "Revived!"},
	"toast_revive_none": {"ru": "Возрождения закончились!", "en": "No revives left!"},
	"arch_btn_revive": {"ru": "[ ВОЗРОДИТЬСЯ ]", "en": "[ REVIVE ]"},
	"arch_btn_revive_left": {"ru": "[ ВОЗРОДИТЬСЯ (%d) ]", "en": "[ REVIVE (%d) ]"},
	"arch_btn_revive_inf": {"ru": "[ ВОЗРОДИТЬСЯ (∞) ]", "en": "[ REVIVE (∞) ]"},
	"arch_trying": {"ru": "попробую...", "en": "i'll try..."},
	"voice_talking": {"ru": "ГОЛОС", "en": "VOICE"},
	"btn_mic_on": {"ru": "МИК: ВКЛ", "en": "MIC: ON"},
	"btn_mic_off": {"ru": "МИК: ВЫКЛ", "en": "MIC: OFF"},
	"toast_skipped": {"ru": "Пропущено %d комнат!", "en": "Skipped %d rooms!"},
	"toast_despawned": {"ru": "Все монстры деспавнены!", "en": "All monsters despawned!"},
	"toast_blackout_on": {"ru": "Блэкаут активирован!", "en": "Blackout activated!"},
	"toast_blackout_off": {"ru": "Освещение включено!", "en": "Lights restored!"},
	"toast_steam_invite": {"ru": "Steam: приглашение от %s! Примите в Shift+Tab", "en": "Steam: invite from %s! Accept via Shift+Tab"},
	"toast_lobby_ready": {"ru": "Лобби создано. Нажми «начать» когда все зайдут.", "en": "Lobby created. Press 'start' when everyone joins."},
	"toast_a120_warp": {"ru": "ВАРП! Happy Scribble отбросил вас на %d комн. назад (A-%03d) [-90 HP]", "en": "WARP! Happy Scribble warped you %d rooms back (A-%03d) [-90 HP]"},
	"toast_a120_hit": {"ru": "Happy Scribble (A-120) нанёс 90 урона! (%d HP)", "en": "Happy Scribble (A-120) dealt 90 damage! (%d HP)"},
	"backend_restart": {"ru": "Бэкенд: %s — перезапустите игру для применения", "en": "Backend: %s — restart game to apply"},
	"backend_active": {"ru": "Активный бэкенд: %s", "en": "Active backend: %s"},
}


static func detect_default_lang() -> String:
	var loc := OS.get_locale_language().to_lower()
	if loc.begins_with("ru") or loc.begins_with("uk") or loc.begins_with("be") or loc.begins_with("kk"):
		return "ru"
	return "en"


static func set_lang(code: String) -> void:
	lang = "en" if code.to_lower() == "en" else "ru"


static func toggle_lang() -> String:
	lang = "en" if lang == "ru" else "ru"
	return lang


static func t(key: String, args: Array = []) -> String:
	var entry: Variant = DICT.get(key)
	var txt := key
	if entry is Dictionary:
		var d: Dictionary = entry
		txt = String(d.get(lang, d.get("en", key)))
	if args.is_empty():
		return txt
	return txt % args

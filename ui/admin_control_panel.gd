class_name AdminControlPanel extends VBoxContainer

signal settings_updated(settings: Dictionary, disable_all: bool)
signal weights_updated(weights: Dictionary)
signal disabled_updated(val: bool)
signal disabled_all_updated(val: bool)

const SETTING_KEY := "_admin_APSudoku_Settings"
const HINTGAME_KEY := "_admin_HintGame_Settings"
const DISABLE_ALL_HINTGAME_KEY := "_admin_DisableAllHintGames"

var active_settings: Dictionary = {
	"enabled": true,
	"weights": {
		"Easy": [10, 90, 0],
		"Normal": [40, 60, 0],
		"Hard": [80, 20, 0],
		"Killer": [60, 40, 0],
	}
}

var settings: Dictionary

var active_disable_all_hintgames: bool
var disable_all_hintgames: bool

func on_connect(conn: ConnectionInfo, _json: Dictionary) -> void:
	conn.set_notify(SETTING_KEY, update_settings)
	conn.retrieve(SETTING_KEY, update_settings)

	conn.set_notify(HINTGAME_KEY, update_hintgame_settings)
	conn.retrieve(HINTGAME_KEY, update_hintgame_settings)

func apply_settings() -> void:
	Archipelago.send_command("Set", {
		"key": SETTING_KEY,
		"default": {},
		"want_reply": true,
		"operations": [
			{"operation": "replace", "value": settings}
		]
	})
	if active_disable_all_hintgames != disable_all_hintgames:
		Archipelago.send_command("Set", {
			"key": HINTGAME_KEY,
			"default": {},
			"want_reply": true,
			"operations": [
				{"operation": "update", "value":
					{DISABLE_ALL_HINTGAME_KEY: disable_all_hintgames}}
			]
		})

func revert_settings() -> void:
	settings = active_settings.duplicate(true)
	weights_updated.emit(active_settings.get("weights", {}))
	disabled_updated.emit(not active_settings.get("enabled", true))
	disabled_all_updated.emit(active_disable_all_hintgames)

func update_settings(obj: Variant) -> void:
	if obj is not Dictionary:
		obj = {}
	active_settings.merge(obj, true)
	revert_settings()
	settings_updated.emit(active_settings, active_disable_all_hintgames)
	weights_updated.emit(active_settings.get("weights", {}))
	disabled_updated.emit(not active_settings.get("enabled", true))

func update_hintgame_settings(obj: Variant) -> void:
	if obj is not Dictionary:
		obj = {}
	active_disable_all_hintgames = bool(obj.get(DISABLE_ALL_HINTGAME_KEY, false))
	settings_updated.emit(active_settings, active_disable_all_hintgames)
	disabled_all_updated.emit(active_disable_all_hintgames)

func set_values(values: Array[int], diffname: String) -> void:
	settings["weights"][diffname] = values

func set_sudoku_disabled(val: bool) -> void:
	settings["enabled"] = not val

func set_hintgame_disabled(val: bool) -> void:
	disable_all_hintgames = val

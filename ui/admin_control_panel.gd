class_name AdminControlPanel extends VBoxContainer

signal settings_updated(settings: Dictionary)
signal weights_updated(weights: Dictionary)
signal enabled_updated(val: bool)

const SETTING_KEY := "APSudoku_Settings"

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

func on_connect(conn: ConnectionInfo, _json: Dictionary) -> void:
	conn.set_notify(SETTING_KEY, update_settings)
	conn.retrieve(SETTING_KEY, update_settings)

func apply_settings() -> void:
	Archipelago.send_command("Set", {
		"key": SETTING_KEY,
		"default": {},
		"want_reply": true,
		"operations": [
			{"operation": "replace", "value": settings}
		]
	})

func revert_settings() -> void:
	settings = active_settings.duplicate(true)
	weights_updated.emit(active_settings.get("weights", {}))
	enabled_updated.emit(active_settings.get("enabled", true))

func update_settings(obj: Variant) -> void:
	if obj is not Dictionary:
		obj = {}
	active_settings.merge(obj, true)
	revert_settings()
	settings_updated.emit(active_settings)
	weights_updated.emit(active_settings.get("weights", {}))
	enabled_updated.emit(active_settings.get("enabled", true))


func set_values(values: Array[int], diffname: String) -> void:
	settings["weights"][diffname] = values

func set_sudoku_enabled(val: bool) -> void:
	settings["enabled"] = val

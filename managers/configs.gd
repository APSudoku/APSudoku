class_name SudokuConfigManager extends APConfigManager

var ip: String = "" :
	set(val):
		if val != ip:
			ip = val
			save_cfg()
var port: String = "" :
	set(val):
		if val != port:
			port = val
			save_cfg()
var slot: String = "" :
	set(val):
		if val != slot:
			slot = val
			save_cfg()

var _pause_saving := false

func update_credentials(creds: APCredentials) -> void:
	_pause_saving = true
	ip = creds.ip
	port = creds.port
	slot = creds.slot
	_pause_saving = false
	save_cfg()

func save_cfg() -> void:
	if _pause_saving: return
	super()

func _load_cfg(file: FileAccess) -> void:
	super(file)
	ip = file.get_pascal_string()
	port = file.get_pascal_string()
	slot = file.get_pascal_string()
	Archipelago.creds.update(ip, port, slot, "")
func _save_cfg(file: FileAccess) -> void:
	super(file)
	file.store_pascal_string(ip)
	file.store_pascal_string(port)
	file.store_pascal_string(slot)

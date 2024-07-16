class_name SudokuConfigManager extends APConfigManager

var ip: String = "" :
	set(val):
		if val != ip:
			ip = val
			save_cfg()
			config_changed.emit()
var port: String = "" :
	set(val):
		if val != port:
			port = val
			save_cfg()
			config_changed.emit()
var slot: String = "" :
	set(val):
		if val != slot:
			slot = val
			save_cfg()
			config_changed.emit()
var theme_path: String = "user://themes/theme.sudokutheme.tres" :
	set(val):
		if val != theme_path:
			theme_path = val
			save_cfg()
			config_changed.emit()
var shift_center := false :
	set(val):
		if val != shift_center:
			shift_center = val
			save_cfg()
			config_changed.emit()
var show_invalid := false :
	set(val):
		if val != show_invalid:
			show_invalid = val
			save_cfg()
			config_changed.emit()
var shapes_mode := false :
	set(val):
		if val != shapes_mode:
			shapes_mode = val
			save_cfg()
			config_changed.emit()

func update_credentials(creds: APCredentials) -> void:
	_pause_saving = true
	ip = creds.ip
	port = creds.port
	slot = creds.slot
	_pause_saving = false
	save_cfg()

func _load_cfg(file: FileAccess) -> void:
	super(file)
	ip = file.get_pascal_string()
	port = file.get_pascal_string()
	slot = file.get_pascal_string()
	Archipelago.creds.update(ip, port, slot, "")
	var byte := file.get_8()
	shift_center = byte & (1 << 0)
	show_invalid = byte & (1 << 1)
	shapes_mode = byte & (1 << 2)
	
	theme_path = file.get_pascal_string()
func _save_cfg(file: FileAccess) -> void:
	super(file)
	file.store_pascal_string(ip)
	file.store_pascal_string(port)
	file.store_pascal_string(slot)
	var byte := 0
	if shift_center: byte |= (1 << 0)
	if show_invalid: byte |= (1 << 1)
	if shapes_mode: byte |= (1 << 2)
	file.store_8(byte)
	
	file.store_pascal_string(theme_path)

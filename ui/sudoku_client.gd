@tool extends ConsoleWindowContainer

@onready var settings_subtabs: Control = $Tabs/Settings/Margin/Tabs
@onready var fields: Array[Control] = [%IP, %Port, %Slot, %Password, %Lives, %DeathLink]
@onready var sudoku_grid: SudokuGrid = $Tabs/Sudoku

var deaths_towards_amnesty := 0
var death_amnesty := 0


func _ready():
	#TODO finish gui (radiobuttons, difficulty sel, number pad, info buttons, checkboxes)
	super()
	if Engine.is_editor_hint():
		await get_tree().create_timer(1).timeout
		var q := 0
		for cell in %Sudoku.cells:
			cell.name = "Cell %d" % q
			q += 1
		return
	tabs.move_child(tabs.get_node("Sudoku"), 0)
	tabs.current_tab = tabs.get_tab_idx_from_control($Tabs/Settings)
	settings_subtabs.move_child(settings_subtabs.get_node("Connection"), 0)
	settings_subtabs.current_tab = 0
	Archipelago.load_console(self, false)
	
	Archipelago.connected.connect(on_connect)
	Archipelago.disconnected.connect(on_disconnect)
	Archipelago.connectionrefused.connect(on_connect_reject)
	on_disconnect()
	Archipelago.creds.updated.connect(load_credentials)
	load_credentials(Archipelago.creds)

func on_connect(_conn: ConnectionInfo, _json: Dictionary) -> void:
	%ConnectButton.text = "Disconnect"
	%ConnectButton.tooltip_text = "Disconnect from the Archipelago server. This will forfeit any active puzzles."
	%ErrorLabel.text = ""
	for field in fields:
		if field is LineEdit:
			field.editable = false
		elif field is CheckBox:
			field.disabled = true
func on_disconnect() -> void:
	%ConnectButton.text = "Connect"
	%ConnectButton.tooltip_text = "Connect to the Archipelago server. This will forfeit any active puzzles."
	for field in fields:
		if field is LineEdit:
			field.editable = true
		elif field is CheckBox:
			field.disabled = false
func on_connect_reject(_conn: ConnectionInfo, json: Dictionary) -> void:
	var err_str := "Errors: %s" % str(json["errors"])
	%ErrorLabel.text = err_str

func try_connect() -> void:
	if Archipelago.is_ap_connected(): return
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Connecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.set_tag("DeathLink", %DeathLink.button_pressed)
	death_amnesty = %Lives.get_val()
	Archipelago.ap_connect(%IP.get_val(), %Port.get_val(), %Slot.get_val(), %Password.get_val())
func try_disconnect() -> void:
	if Archipelago.is_not_connected(): return
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Disconnecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.ap_disconnect()
func on_connect_button() -> void:
	if Archipelago.is_not_connected():
		try_connect()
	else:
		try_disconnect()


func load_credentials(creds: APCredentials) -> void:
	Archipelago.config.update_credentials(creds)
	%IP.text = creds.ip
	%Port.text = creds.port
	%Slot.text = creds.slot

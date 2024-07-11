@tool extends ConsoleWindowContainer

@onready var settings_subtabs: Control = $Tabs/Settings/Margin/Tabs
@onready var fields: Array[Control] = [%IP, %Port, %Slot, %Password]

var deaths_towards_amnesty := 0
var death_amnesty := 0


func _ready():
	super()
	if Engine.is_editor_hint(): return
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
		field.editable = false
func on_disconnect() -> void:
	%ConnectButton.text = "Connect"
	%ConnectButton.tooltip_text = "Connect to the Archipelago server. This will forfeit any active puzzles."
	for field in fields:
		field.editable = true
func on_connect_reject(_conn: ConnectionInfo, json: Dictionary) -> void:
	var err_str := "Errors: %s" % str(json["errors"])
	%ErrorLabel.text = err_str

func load_credentials(creds: APCredentials) -> void:
	Archipelago.config.update_credentials(creds)
	%IP.text = creds.ip
	%Port.text = creds.port
	%Slot.text = creds.slot

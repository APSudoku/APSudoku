class_name ConnectButton extends Button

@onready var ip: CustomLineEdit = %IP
@onready var port: CustomLineEdit = %Port
@onready var slot: CustomLineEdit = %Slot
@onready var password: CustomLineEdit = %Password

func _ready():
	pressed.connect(on_press)

func on_press() -> void:
	if text == "Connect":
		on_connect()
	else:
		on_disconnect()
func on_connect() -> void:
	if Archipelago.is_ap_connected(): return
	#TODO If grid is active, popup forfeit confirmation; if yes, clear grid, else return
	Archipelago.ap_connect(ip.get_val(), port.get_val(), slot.get_val(), password.get_val())
func on_disconnect() -> void:
	if Archipelago.is_not_connected(): return
	Archipelago.ap_disconnect()

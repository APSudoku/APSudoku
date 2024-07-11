extends Button

@onready var ip: CustomTextEdit = %IP
@onready var port: CustomTextEdit = %Port
@onready var slot: CustomTextEdit = %Slot
@onready var password: CustomTextEdit = %Password

func _ready():
	pressed.connect(on_connect)

func on_connect() -> void:
	#TODO If grid is active, popup forfeit confirmation; if yes, clear grid, else return
	Archipelago.ap_connect(ip.get_val(), port.get_val(), slot.get_val(), password.get_val())

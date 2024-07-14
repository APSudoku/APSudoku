class_name InfoButton extends Button

@export var title := "Info"
@export_multiline var info: String = ""
@export var format_args: Array[String] = []

func _ready():
	pressed.connect(show_info)

func show_info() -> void:
	var popup := PopupManager.create_popup(info % format_args, title, false)
	var lbl := popup.get_label()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await popup.pop_open()

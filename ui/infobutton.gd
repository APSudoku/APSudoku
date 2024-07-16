class_name InfoButton extends Button

@export var title := "Info"
@export_multiline var info: String = ""
@export var format_args: Array[String] = []

func _ready():
	pressed.connect(show_info)

static func pop_info(dlg_title: String, dlg_info: String) -> void:
	var popup := PopupManager.create_popup(dlg_info, dlg_title, false)
	popup.max_size = PopupManager.get_window().size * 0.8
	var lbl := popup.get_label()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	await popup.pop_open()

func show_info() -> void:
	InfoButton.pop_info(title, info % format_args)

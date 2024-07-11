extends Node
# Autoload 'PopupManager'

var last_return: bool = false

signal popup_closed
func popup_dlg(text: String, title := "Confirm", cancel := true) -> bool:
	var popup = AcceptDialog.new()
	popup.title = title
	popup.dialog_text = text
	popup.keep_title_visible = true
	popup.extend_to_title = true
	popup.transient = true
	popup.popup_window = false
	popup.visible = true
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	if cancel:
		popup.add_cancel_button("Cancel")
	add_child(popup)
	popup.popup_centered()
	get_tree().paused = true
	popup.confirmed.connect(func():
		get_tree().paused = false
		popup.queue_free()
		last_return = true
		popup_closed.emit())
	popup.canceled.connect(func():
		get_tree().paused = false
		popup.queue_free()
		last_return = false
		popup_closed.emit())
	await popup_closed
	return last_return

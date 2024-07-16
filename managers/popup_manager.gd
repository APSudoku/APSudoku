extends Node
# Autoload 'PopupManager'

var last_return: bool = false

class SudokuPopup extends AcceptDialog:
	var _cancel_button: Button
	func pop_open() -> bool:
		return await PopupManager.pop_popup(self)
	func allow_cancel(val: bool) -> void:
		if val:
			if not _cancel_button:
				_cancel_button = add_cancel_button("Cancel")
		else:
			if _cancel_button:
				remove_button(_cancel_button)
				_cancel_button = null
	func get_cancel_button() -> Button:
		return _cancel_button

signal popup_closed
func popup_dlg(text: String, title := "", cancel := true) -> bool:
	return await pop_popup(create_popup(text, title, cancel))
func create_popup(text: String, title := "", cancel := true) -> SudokuPopup:
	if title.is_empty():
		title = "Confirm?" if cancel else "Info"
	var popup = SudokuPopup.new()
	popup.title = title
	popup.dialog_text = text
	popup.keep_title_visible = true
	popup.extend_to_title = true
	popup.transient = true
	popup.popup_window = false
	popup.visible = true
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	popup.allow_cancel(cancel)
	if cancel:
		popup.get_cancel_button().custom_minimum_size.x = 100
	popup.get_ok_button().custom_minimum_size.x = 100
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
	return popup
func pop_popup(popup: SudokuPopup) -> bool:
	popup.popup_centered()
	await popup_closed
	return last_return

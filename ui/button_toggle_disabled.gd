class_name ToggleDisabledButton extends Button

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			disabled = not disabled
			accept_event()

extends GridContainer
var has_mouse := false
var allow_grid_sel := true

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			has_mouse = true
			if Input.get_mouse_button_mask() & (MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT):
				allow_grid_sel = false
			else: allow_grid_sel = true
		NOTIFICATION_MOUSE_EXIT:
			has_mouse = false
			allow_grid_sel = false

func _gui_input(event):
	if event is InputEventMouseButton:
		if not event.pressed and Input.get_mouse_button_mask() == 0:
			allow_grid_sel = true

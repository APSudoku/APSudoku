extends GridContainer
var has_mouse := false
var clicked_grid := false
var allow_grid_sel := true

func _process(_delta):
	if Input.is_action_just_released("mouse_lr"):
		clicked_grid = false
		if not has_mouse:
			allow_grid_sel = false
func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			has_mouse = true
			allow_grid_sel = clicked_grid or not Input.is_action_pressed("mouse_lr")
		NOTIFICATION_MOUSE_EXIT:
			has_mouse = false
			if not Input.is_action_pressed("mouse_lr"):
				allow_grid_sel = false
				clicked_grid = false
			elif allow_grid_sel: clicked_grid = true

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			clicked_grid = true
			allow_grid_sel = true

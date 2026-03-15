class_name SudokuSettingsTab extends MarginContainer

signal try_connect
signal try_disconnect
signal update_shapes_mode(val: bool)

signal theme_save
signal theme_save_as
signal theme_load
signal theme_reset

func on_theme_save() -> void:
	theme_save.emit()
func on_theme_save_as() -> void:
	theme_save_as.emit()
func on_theme_load() -> void:
	theme_load.emit()
func on_theme_reset() -> void:
	theme_reset.emit()

@export var fields: Array[Control]
@export var connect_text: Label
@export var error_text: Label
@export var connect_button: Button
@export var lives: CustomLineEdit
@export var deathlink: CheckBox
@export var deathlink_group: CustomLineEdit

@export var tabs: TabContainer
@export var sudoku_tab: MarginContainer
@export var connection_tab: MarginContainer
@export var theme_tab: MarginContainer

func _ready() -> void:
	tabs.move_child(connection_tab, 0)
	tabs.move_child(sudoku_tab, 1)
	tabs.current_tab = 0
func ap_connect() -> void:
	Archipelago.ap_connect(%IP.get_val(), %Port.get_val(), %Slot.get_val(), %Password.get_val())

func load_credentials(creds: APCredentials) -> void:
	Archipelago.config.update_credentials(creds)
	%IP.text = creds.ip
	%Port.text = creds.port
	%Slot.text = creds.slot

func load_settings() -> void:
	Archipelago.creds.updated.connect(load_credentials)
	load_credentials(Archipelago.creds)
	%ShiftCenter.set_pressed_no_signal(SudokuGrid.config.shift_center)
	%ShowInvalid.set_pressed_no_signal(SudokuGrid.config.show_invalid)
	%ShapesMode.set_pressed_no_signal(SudokuGrid.config.shapes_mode)
	%ThrottleGeneration.set_pressed_no_signal(SudokuGrid.config.throttle_bg_generation)
	%PuzzlesToKeep.set_value_no_signal(SudokuGrid.config.puzzles_to_keep)

func set_puzzles_to_keep(val: float) -> void:
	SudokuGrid.config.puzzles_to_keep = roundi(val)

func set_shift_center(val: bool) -> void:
	SudokuGrid.config.shift_center = val

func set_show_invalid(val: bool) -> void:
	SudokuGrid.config.show_invalid = val

func set_shapes_mode(val: bool) -> void:
	update_shapes_mode.emit(val)

func set_throttle_gen(val: bool) -> void:
	SudokuGrid.config.throttle_bg_generation = val

func attempt_connection() -> void:
	try_connect.emit()

func on_connect_button() -> void:
	match connect_button.text:
		"Connect":
			try_connect.emit()
		"Disconnect":
			connect_button.disabled = true
			try_disconnect.emit()
		"Cancel":
			connect_button.disabled = true
			error_text.text = "Canceled Connection"
			Archipelago.ap_disconnect()

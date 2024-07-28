class_name ConnectDebugSettings extends MarginContainer

@export var toggle_switch: CheckButton
@export var skip_data_packages: ItemList
@export var remove_btn: Button
@export var remove_all_btn: Button
@export var add_field: LineEdit
@export var add_btn: Button

func _ready():
	toggle_switch.set_pressed(%Sudoku.config.debug_connect_settings)
	toggle_switch.toggled.connect(func(b): %Sudoku.config.debug_connect_settings = b)
	var arr: PackedStringArray = %Sudoku.config.skipped_data_packages
	for game in arr:
		skip_data_packages.add_item(game)
	add_field.text_submitted.connect(on_add_game.unbind(1))
	add_btn.pressed.connect(on_add_game)
	skip_data_packages.multi_selected.connect(func(_a,_b):
		remove_btn.disabled = not skip_data_packages.is_anything_selected())
	remove_btn.disabled = true
	remove_all_btn.disabled = skip_data_packages.item_count < 1
	remove_all_btn.pressed.connect(remove_all_skipdatapackage)
	remove_btn.pressed.connect(remove_skipdatapackage)

func rebuild_packages() -> void:
	var arr: PackedStringArray = []
	for q in skip_data_packages.item_count:
		arr.append(skip_data_packages.get_item_text(q))
	remove_btn.disabled = not skip_data_packages.is_anything_selected()
	remove_all_btn.disabled = arr.is_empty()
	%Sudoku.config.skipped_data_packages = arr
	%Sudoku.config.save_cfg()

func on_add_game() -> void:
	var game: String = add_field.text
	for q in skip_data_packages.item_count:
		if skip_data_packages.get_item_text(q) == game:
			return
	skip_data_packages.add_item(game)
	skip_data_packages.sort_items_by_text()
	add_field.text = ""
	rebuild_packages()

func remove_all_skipdatapackage() -> void:
	skip_data_packages.clear()
	rebuild_packages()

func remove_skipdatapackage() -> void:
	var sel: Array = skip_data_packages.get_selected_items()
	if sel.size() == skip_data_packages.item_count:
		return remove_all_skipdatapackage()
	sel.reverse()
	for q in sel:
		skip_data_packages.remove_item(q)
	rebuild_packages()

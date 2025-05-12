@tool extends ConsoleWindowContainer

@export var sudoku_grid: SudokuGrid
@export var settings_tab: SudokuSettingsTab
@export_group("AdminPanel")
@export var admin_panel: MarginContainer
@export var admin_pwd_box: LineEdit
@export var admin_login_panel: Container
@export var admin_control_panel: AdminControlPanel
@export var admin_login_error: Label

var admin_validated: bool = false :
	set(val):
		admin_validated = val
		admin_control_panel.visible = val
		if val:
			admin_login_panel.visible = false
		else:
			admin_login_panel.visible = Archipelago.status == Archipelago.APStatus.PLAYING

var _real_entry_mode: SudokuGrid.EntryMode = SudokuGrid.EntryMode.ANSWER
var _entry_mode: SudokuGrid.EntryMode = SudokuGrid.EntryMode.ANSWER

func _ready():
	super()
	get_window().min_size = Vector2(1050,500)
	get_window().title += " (%s)" % ProjectSettings.get_setting("application/config/version")
	if Engine.is_editor_hint():
		await get_tree().create_timer(1).timeout
		var q := 0
		for cell in %Sudoku.cells:
			cell.name = "Cell %d" % q
			q += 1
		return
	tabs.move_child(sudoku_grid, 0)
	tabs.current_tab = 0 if OS.is_debug_build() else tabs.get_tab_idx_from_control($Tabs/Settings)
	set_entry_mode(SudokuGrid.EntryMode.ANSWER)

	sudoku_grid.modifier_entry_mode.connect(set_fake_entry_mode)
	sudoku_grid.cycle_entry_mode.connect(cycle_entry)
	sudoku_grid.grant_hint.connect(grant_hint)

	Archipelago.load_console(self, false)

	Archipelago.roominfo.connect(on_roominfo)
	Archipelago.connect_step.connect(settings_tab.connect_text.set_text)
	Archipelago.connected.connect(on_connect)
	Archipelago.disconnected.connect(on_disconnect)
	Archipelago.connectionrefused.connect(on_connect_reject)
	Archipelago.printjson.connect(on_printjson)
	on_disconnect()
	settings_tab.load_settings()

var _prog_locs: Array[NetworkItem] = []
var _non_prog_locs: Array[NetworkItem] = []
func refresh_hint_count() -> void:
	if Archipelago.is_not_connected():
		%CountLabel.text = ""
		sudoku_grid.hinted_out = ""
		return
	_prog_locs.clear()
	_non_prog_locs.clear()

	var locs := Archipelago.conn._scout_cache.keys()
	for hint in Archipelago.conn.hints:
		locs.erase(hint.item.loc_id)
	var q := 0
	while q < locs.size():
		if Archipelago.conn.slot_locations[locs[q]]:
			locs.pop_at(q)
		else: q += 1
	for loc in locs:
		var itm: NetworkItem = Archipelago.conn._scout_cache[loc]
		if itm.is_prog():
			_prog_locs.append(itm)
		else: _non_prog_locs.append(itm)
	if admin_control_panel.active_settings.get("enabled", true):
		var use_prog := false
		var use_nonprog := false
		for w in setting_weights.values():
			if w[0] > 0:
				use_prog = true
			if w[1] > 0:
				use_nonprog = true
		var weights: Array[int] = _cur_weights()
		if weights[0] > 0:
			use_prog = true
		if weights[1] > 0:
			use_nonprog = true
		var count := 0
		if use_prog: count += _prog_locs.size()
		if use_nonprog: count += _non_prog_locs.size()
		if weights[0] > 0 != use_prog or weights[1] > 0 != use_nonprog:
			var cur_count := 0
			if weights[0] > 0: cur_count += _prog_locs.size()
			if weights[1] > 0: cur_count += _non_prog_locs.size()
			if count and not cur_count:
				%CountLabel.text = "Change Difficulty!"
				sudoku_grid.hinted_out = "No more hints available at this difficulty due to host settings!"
			elif count:
				%CountLabel.text = "%d [%d] unhinted" % [cur_count, count]
				sudoku_grid.hinted_out = ""
			else:
				%CountLabel.text = "Hinted Out!"
				sudoku_grid.hinted_out = "No more hints available for this slot!"
		elif count:
			%CountLabel.text = "%d unhinted" % count
			sudoku_grid.hinted_out = ""
		else:
			%CountLabel.text = "Hinted Out!"
			sudoku_grid.hinted_out = ""
	else:
		%CountLabel.text = ""
		sudoku_grid.hinted_out = "APSudoku has been disabled by the host. No hints will be earned."

func grant_hint() -> void:
	var weights: Array[int] = _cur_weights()

	if _prog_locs.is_empty():
		weights[0] = 0
	if _non_prog_locs.is_empty():
		weights[1] = 0;
	if weights[0] == 0 and weights[1] == 0:
		await PopupManager.popup_dlg("No hints left to earn, though!", "Correct!", false)
		return
	var max_weight: int = weights.reduce(func(acc, val):
		return acc + val, 0)
	var picked: int = randi_range(0, max_weight-1)
	var itm: NetworkItem
	if picked < weights[0]:
		itm = _prog_locs.pick_random()
	elif picked < weights[0] + weights[1]:
		itm = _non_prog_locs.pick_random()
	else:
		assert(weights[2] > 0)
		await PopupManager.popup_dlg("Unlucky, no hint this time!", "Correct!", false)
		return
	Archipelago.conn.scout(itm.loc_id, 1, Callable())
	Archipelago.conn.on_hint_update.connect(display_hint.bind(itm.loc_id), CONNECT_ONE_SHOT | CONNECT_REFERENCE_COUNTED)
func display_hint(hints: Array[NetworkHint], loc: int) -> void:
	for hint in hints:
		if hint.item.loc_id == loc:
			var s: String = hint.as_plain_string()
			await PopupManager.popup_dlg(s, "Correct!", false)
			return

func on_roominfo(_conn: ConnectionInfo, _json: Dictionary) -> void:
	if SudokuGrid.config.debug_connect_settings:
		for game in SudokuGrid.config.skipped_data_packages:
			Archipelago.datapack_pending.erase(game)
func on_connect(conn: ConnectionInfo, json: Dictionary) -> void:
	admin_validated = false
	admin_login_panel.visible = true
	admin_login_error.text = ""
	admin_control_panel.on_connect(conn, json)

	conn.roomupdate.connect(refresh_hint_count.unbind(1))
	conn.on_hint_update.connect(refresh_hint_count.unbind(1))
	conn.deathlink.connect(%Sudoku.deathlink_recv)
	settings_tab.connect_button.disabled = false
	settings_tab.connect_button.text = "Disconnect"
	settings_tab.connect_button.tooltip_text = "Disconnect from the Archipelago server. This will forfeit any active puzzles."
	settings_tab.error_text.text = ""
	for field in settings_tab.fields:
		if field is LineEdit:
			field.editable = false
		elif field is CheckBox:
			field.disabled = true
	%CountLabel.text = ""
	conn.all_scout_cached.connect(refresh_hint_count, CONNECT_ONE_SHOT)
	conn.force_scout_all()
func on_disconnect() -> void:
	admin_validated = false
	admin_login_panel.visible = false
	admin_login_error.text = ""

	update_setting_label()

	settings_tab.connect_text.text = ""
	settings_tab.connect_button.disabled = false
	settings_tab.connect_button.text = "Connect"
	settings_tab.connect_button.tooltip_text = "Connect to the Archipelago server. This will forfeit any active puzzles."
	%CountLabel.text = ""
	for field in settings_tab.fields:
		if field is LineEdit:
			field.editable = true
		elif field is CheckBox:
			field.disabled = false
func on_connect_reject(_conn: ConnectionInfo, json: Dictionary) -> void:
	var err_str := "Errors: %s" % str(json["errors"])
	settings_tab.error_text.text = err_str

func try_connect() -> void:
	if Archipelago.is_ap_connected(): return
	settings_tab.connect_button.disabled = false
	settings_tab.connect_button.text = "Cancel"
	settings_tab.connect_button.tooltip_text = "Stop trying to connect to the Archipelago server."
	settings_tab.connect_text.text = ""
	settings_tab.error_text.text = ""
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Connecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.set_deathlink(settings_tab.deathlink.button_pressed)
	%Sudoku.death_amnesty = settings_tab.lives.get_val()
	settings_tab.ap_connect()
func try_disconnect() -> void:
	if Archipelago.is_not_connected(): return
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Disconnecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.ap_disconnect()

func select_entry_button(mode: int, from_mod := false) -> void:
	assert(not (SudokuGrid.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER))
	var cboxes = [%RadioAnswer,%RadioCenter,%RadioCorner]
	for q in 3:
		var cbox := cboxes[q] as CheckBox
		if q == SudokuGrid.EntryMode.CENTER and SudokuGrid.config.shapes_mode:
			cbox.disabled = true
			cbox.set_pressed_no_signal(false)
		else:
			cbox.set_pressed_no_signal(q == mode)
			cbox.disabled = from_mod
		cbox.queue_redraw()
func set_fake_entry_mode(mode: int) -> void:
	if mode < 0:
		return set_entry_mode(_real_entry_mode)
	elif mode > 2: return
	if SudokuGrid.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER:
		mode = SudokuGrid.EntryMode.CORNER
	_entry_mode = mode as SudokuGrid.EntryMode
	sudoku_grid.mode = mode as SudokuGrid.EntryMode
	select_entry_button(mode, true)
func cycle_entry() -> void:
	if _entry_mode != _real_entry_mode: return
	set_entry_mode((_real_entry_mode + 1) % SudokuGrid.EntryMode.size())
func set_entry_mode(mode: int, no_button := false) -> void:
	if mode < 0 or mode > 2: return
	if SudokuGrid.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER:
		mode = SudokuGrid.EntryMode.CORNER
	_entry_mode = mode as SudokuGrid.EntryMode
	_real_entry_mode = mode as SudokuGrid.EntryMode
	sudoku_grid.mode = mode as SudokuGrid.EntryMode
	if not no_button:
		select_entry_button(mode)
func set_entry_mode_no_button(mode: int) -> void:
	set_entry_mode(mode, true)

func set_shift_center(val: bool) -> void:
	SudokuGrid.config.shift_center = val

func set_show_invalid(val: bool) -> void:
	SudokuGrid.config.show_invalid = val

func set_shapes_mode(val: bool) -> void:
	SudokuGrid.config.shapes_mode = val
	if val:
		if _entry_mode == SudokuGrid.EntryMode.CENTER:
			_entry_mode = SudokuGrid.EntryMode.CORNER
			sudoku_grid.mode = _entry_mode
		if _real_entry_mode == SudokuGrid.EntryMode.CENTER:
			_real_entry_mode = SudokuGrid.EntryMode.CORNER
		select_entry_button(_entry_mode)
	else:
		%RadioCenter.disabled = false
		%RadioCenter.queue_redraw()

func set_throttle_gen(val: bool) -> void:
	SudokuGrid.config.throttle_bg_generation = val

func init_theme() -> void:
	if not DirAccess.dir_exists_absolute("user://themes/"):
		DirAccess.make_dir_recursive_absolute("user://themes/")
	assert(%Sudoku.sudoku_theme)
	var path: String = SudokuGrid.config.theme_path
	if FileAccess.file_exists(path):
		%Sudoku.sudoku_theme.update_from_copy(ResourceLoader.load(path, "SudokuTheme", ResourceLoader.CACHE_MODE_REPLACE))
	else:
		ResourceSaver.save(%Sudoku.sudoku_theme, path)


func save_theme(path := "") -> void:
	if path.is_empty(): path = SudokuGrid.config.theme_path
	var err := ResourceSaver.save(%Sudoku.sudoku_theme, path)
	if err:
		AP.log("Error saving theme file '%s': '%s'" % [path,error_string(err)])
func save_theme_as() -> void:
	var dir_path := ProjectSettings.globalize_path(SudokuGrid.config.theme_path).replace("\\","/")
	var pos := dir_path.rfind("/")
	var cur_dir: String = dir_path if pos < 0 else dir_path.substr(0,pos+1)
	DisplayServer.file_dialog_show("Save Theme As", cur_dir, "", false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, ["*.res ; Godot Binary Resource File",
			"*.tres ; Godot Text Resource File"],
		func(ok: bool, paths: PackedStringArray, filt: int):
			if not ok: return
			var ext: String = [".res",".tres"][filt-1]
			var fpath: String = paths[0]
			if not fpath.ends_with(ext): fpath += ext
			save_theme(fpath))
func load_theme(path := "") -> void:
	if path.is_empty():
		var dir_path := ProjectSettings.globalize_path(SudokuGrid.config.theme_path).replace("\\","/")
		var pos := dir_path.rfind("/")
		var cur_dir: String = dir_path if pos < 0 else dir_path.substr(0,pos+1)
		DisplayServer.file_dialog_show("Load Theme", cur_dir, "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, ["*.res ; Godot Binary Resource File",
			"*.tres ; Godot Text Resource File"],
			func(ok: bool, paths: PackedStringArray, filt: int):
				if not ok: return
				var ext: String = [".res",".tres"][filt]
				var fpath: String = paths[0]
				if not fpath.ends_with(ext): fpath += ext
				load_theme(fpath))
		return
	var new_theme = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if new_theme:
		if new_theme is SudokuTheme:
			SudokuGrid.config.theme_path = path
			%Sudoku.sudoku_theme.update_from_copy(new_theme)
		else:
			InfoButton.pop_info("Load Failed!", "File '%s' contains wrong resource type; expected 'SudokuTheme'" % path)
	else:
		InfoButton.pop_info("Load Failed!", "Failed to load file '%s' - invalid resource" % path)

func reset_theme():
	if await PopupManager.popup_dlg("Are you sure you want to reset the current theme to default?", "Reset Theme", true):
		%Sudoku.sudoku_theme.update_from_copy(SudokuTheme.new())

func on_printjson(json: Dictionary, text: String) -> void:
	if "CommandResult" not in json.get("type", ""):
		return
	if text == "Sorry, Remote administration is disabled":
		admin_login_error.text = "ERROR: Remote Administration is Disabled"
	elif text == "Password incorrect.":
		admin_login_error.text = "ERROR: Wrong Password!"
	elif text == "Login successful. You can now issue server side commands.":
		admin_login_error.text = ""
		admin_validated = true

func check_admin() -> void:
	Archipelago.send_command("Say", {"text": "!admin login %s" % admin_pwd_box.text})


var is_enabled: bool = true
var setting_weights: Dictionary[String, Array]
func on_update_settings(settings: Dictionary) -> void:
	is_enabled = settings.get("enabled", true)
	setting_weights.merge(settings.get("weights", {}), true)
	update_setting_label()
	refresh_hint_count()

func update_setting_label() -> void:
	if Archipelago.status != Archipelago.APStatus.PLAYING:
		%SettingsText.text = "Information on room-specific settings appears here after connecting."
		return
	if not is_enabled:
		%SettingsText.text = "The host has disabled APSudoku entirely. No hints may be earned."
		return
	var weights: Array[int] = _cur_weights()
	%SettingsText.text = "Weights:\nProgression: %d\nNon-Prog: %d\nNo Hint: %d" % weights

func _cur_weights() -> Array[int]:
	var weights: Array[int] = []

	match sudoku_grid.difficulty:
		PuzzleGrid.Difficulty.EASY:
			weights = [10, 90, 0]
		PuzzleGrid.Difficulty.MEDIUM:
			weights = [40, 60, 0]
		PuzzleGrid.Difficulty.HARD:
			weights = [80, 20, 0]
		PuzzleGrid.Difficulty.KILLER:
			weights = [60, 40, 0]
	weights.assign(setting_weights.get(PuzzleGrid.diff_to_str(sudoku_grid.difficulty), weights))
	while weights.size() < 3:
		weights.append(0)
	return weights

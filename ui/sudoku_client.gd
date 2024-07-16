@tool extends ConsoleWindowContainer

@onready var settings_subtabs: Control = $Tabs/Settings/Margin/Tabs
@onready var fields: Array[Control] = [%IP, %Port, %Slot, %Password, %Lives, %DeathLink]
@onready var sudoku_grid: SudokuGrid = $Tabs/Sudoku

var _real_entry_mode: SudokuGrid.EntryMode = SudokuGrid.EntryMode.ANSWER
var _entry_mode: SudokuGrid.EntryMode = SudokuGrid.EntryMode.ANSWER

func _ready():
	super()
	get_window().min_size = Vector2(850,500)
	if Engine.is_editor_hint():
		await get_tree().create_timer(1).timeout
		var q := 0
		for cell in %Sudoku.cells:
			cell.name = "Cell %d" % q
			q += 1
		return
	tabs.move_child(tabs.get_node("Sudoku"), 0)
	tabs.current_tab = 0 if OS.is_debug_build() else tabs.get_tab_idx_from_control($Tabs/Settings)
	set_entry_mode(SudokuGrid.EntryMode.ANSWER)
	
	sudoku_grid.modifier_entry_mode.connect(set_fake_entry_mode)
	sudoku_grid.cycle_entry_mode.connect(cycle_entry)
	sudoku_grid.grant_hint.connect(grant_hint)
	
	settings_subtabs.move_child(settings_subtabs.get_node("Connection"), 0)
	settings_subtabs.move_child(settings_subtabs.get_node("Sudoku"), 1)
	settings_subtabs.current_tab = 0
	Archipelago.load_console(self, false)
	
	Archipelago.connected.connect(on_connect)
	Archipelago.disconnected.connect(on_disconnect)
	Archipelago.connectionrefused.connect(on_connect_reject)
	on_disconnect()
	Archipelago.creds.updated.connect(load_credentials)
	load_credentials(Archipelago.creds)
	
	%ShiftCenter.set_pressed_no_signal(%Sudoku.config.shift_center)
	%ShowInvalid.set_pressed_no_signal(%Sudoku.config.show_invalid)
	%ShapesMode.set_pressed_no_signal(%Sudoku.config.shapes_mode)

var _prog_locs: Array[NetworkItem] = []
var _non_prog_locs: Array[NetworkItem] = []
func refresh_hint_count() -> void:
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
	var count := locs.size()
	%CountLabel.text = "%d unhinted" % count if count else "Hinted Out!"

func grant_hint(prog_percent: int) -> void:
	if _prog_locs.is_empty():
		prog_percent = 0
		if _non_prog_locs.is_empty():
			await PopupManager.popup_dlg("No hints left to earn, though!", "Correct!", false)
			return
	elif _non_prog_locs.is_empty(): prog_percent = 100
	var itm: NetworkItem
	if randi_range(0,100) < prog_percent:
		itm = _prog_locs.pick_random()
	else:
		itm = _non_prog_locs.pick_random()
	Archipelago.conn.scout(itm.loc_id, 1, Callable())
	Archipelago.conn.on_hint_update.connect(display_hint.bind(itm.loc_id), CONNECT_ONE_SHOT)
func display_hint(hints: Array[NetworkHint], loc: int) -> void:
	for hint in hints:
		if hint.item.loc_id == loc:
			var s: String = hint.as_plain_string()
			await PopupManager.popup_dlg(s, "Correct!", false)
			return

func on_connect(conn: ConnectionInfo, _json: Dictionary) -> void:
	conn.roomupdate.connect(refresh_hint_count.unbind(1))
	conn.on_hint_update.connect(refresh_hint_count.unbind(1))
	conn.deathlink.connect(%Sudoku.deathlink_recv)
	%ConnectButton.text = "Disconnect"
	%ConnectButton.tooltip_text = "Disconnect from the Archipelago server. This will forfeit any active puzzles."
	%ErrorLabel.text = ""
	for field in fields:
		if field is LineEdit:
			field.editable = false
		elif field is CheckBox:
			field.disabled = true
	%CountLabel.text = ""
	conn.all_scout_cached.connect(refresh_hint_count, CONNECT_ONE_SHOT)
	conn.force_scout_all()
func on_disconnect() -> void:
	%ConnectButton.text = "Connect"
	%ConnectButton.tooltip_text = "Connect to the Archipelago server. This will forfeit any active puzzles."
	%CountLabel.text = ""
	for field in fields:
		if field is LineEdit:
			field.editable = true
		elif field is CheckBox:
			field.disabled = false
func on_connect_reject(_conn: ConnectionInfo, json: Dictionary) -> void:
	var err_str := "Errors: %s" % str(json["errors"])
	%ErrorLabel.text = err_str

func try_connect() -> void:
	if Archipelago.is_ap_connected(): return
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Connecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.set_deathlink(%DeathLink.button_pressed)
	%Sudoku.death_amnesty = %Lives.get_val()
	Archipelago.ap_connect(%IP.get_val(), %Port.get_val(), %Slot.get_val(), %Password.get_val())
func try_disconnect() -> void:
	if Archipelago.is_not_connected(): return
	if sudoku_grid.active_puzzle:
		if not await PopupManager.popup_dlg("Disconnecting while a puzzle is active requires forfeiting the puzzle. Are you sure?", "Forfeit?"):
			return
		sudoku_grid.clear()
	Archipelago.ap_disconnect()
func on_connect_button() -> void:
	if Archipelago.is_not_connected():
		try_connect()
	else:
		try_disconnect()


func load_credentials(creds: APCredentials) -> void:
	Archipelago.config.update_credentials(creds)
	%IP.text = creds.ip
	%Port.text = creds.port
	%Slot.text = creds.slot

func select_entry_button(mode: int, from_mod := false) -> void:
	assert(not (%Sudoku.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER))
	var cboxes = [%RadioAnswer,%RadioCenter,%RadioCorner]
	for q in 3:
		var cbox := cboxes[q] as CheckBox
		if q == SudokuGrid.EntryMode.CENTER and %Sudoku.config.shapes_mode:
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
	if %Sudoku.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER:
		mode = SudokuGrid.EntryMode.CORNER
	_entry_mode = mode as SudokuGrid.EntryMode
	sudoku_grid.mode = mode as SudokuGrid.EntryMode
	select_entry_button(mode, true)
func cycle_entry() -> void:
	if _entry_mode != _real_entry_mode: return
	set_entry_mode((_real_entry_mode + 1) % SudokuGrid.EntryMode.size())
func set_entry_mode(mode: int, no_button := false) -> void:
	if mode < 0 or mode > 2: return
	if %Sudoku.config.shapes_mode and mode == SudokuGrid.EntryMode.CENTER:
		mode = SudokuGrid.EntryMode.CORNER
	_entry_mode = mode as SudokuGrid.EntryMode
	_real_entry_mode = mode as SudokuGrid.EntryMode
	sudoku_grid.mode = mode as SudokuGrid.EntryMode
	if not no_button:
		select_entry_button(mode)
func set_entry_mode_no_button(mode: int) -> void:
	set_entry_mode(mode, true)

func set_shift_center(val: bool) -> void:
	%Sudoku.config.shift_center = val

func set_show_invalid(val: bool) -> void:
	%Sudoku.config.show_invalid = val

func set_shapes_mode(val: bool) -> void:
	%Sudoku.config.shapes_mode = val
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

func init_theme() -> void:
	if not DirAccess.dir_exists_absolute("user://themes/"):
		DirAccess.make_dir_recursive_absolute("user://themes/")
	assert(%Sudoku.sudoku_theme)
	var path: String = %Sudoku.config.theme_path
	if FileAccess.file_exists(path):
		%Sudoku.sudoku_theme.update_from_copy(ResourceLoader.load(path, "SudokuTheme", ResourceLoader.CACHE_MODE_REPLACE))
	else:
		ResourceSaver.save(%Sudoku.sudoku_theme, path)


func save_theme(path := "") -> void:
	if path.is_empty(): path = %Sudoku.config.theme_path
	var err := ResourceSaver.save(%Sudoku.sudoku_theme, path)
	if err:
		AP.log("Error saving theme file '%s': '%s'" % [path,error_string(err)])
func save_theme_as() -> void:
	var dir_path := ProjectSettings.globalize_path(%Sudoku.config.theme_path).replace("\\","/")
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
		var dir_path := ProjectSettings.globalize_path(%Sudoku.config.theme_path).replace("\\","/")
		var pos := dir_path.rfind("/")
		var cur_dir: String = dir_path if pos < 0 else dir_path.substr(0,pos+1)
		DisplayServer.file_dialog_show("Load Theme", cur_dir, "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, ["*.res ; Godot Binary Resource File",
			"*.tres ; Godot Text Resource File"],
			func(ok: bool, paths: PackedStringArray, filt: int):
				if not ok: return
				var ext: String = [".res",".tres"][filt-1]
				var fpath: String = paths[0]
				if not fpath.ends_with(ext): fpath += ext
				load_theme(fpath))
		return
	var new_theme = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if new_theme:
		if new_theme is SudokuTheme:
			%Sudoku.config.theme_path = path
			%Sudoku.sudoku_theme.update_from_copy(new_theme)
		else:
			InfoButton.pop_info("Load Failed!", "File '%s' contains wrong resource type; expected 'SudokuTheme'" % path)
	else:
		InfoButton.pop_info("Load Failed!", "Failed to load file '%s' - invalid resource" % path)

func reset_theme():
	if await PopupManager.popup_dlg("Are you sure you want to reset the current theme to default?", "Reset Theme", true):
		%Sudoku.sudoku_theme.update_from_copy(SudokuTheme.new())

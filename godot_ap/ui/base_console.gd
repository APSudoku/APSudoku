@tool class_name BaseConsole extends Control

const DEBUG_RECTS := false

class FontFlags:
	var bold := false
	var italic := false

@export var font: SystemFont :
	set(val):
		font = val
		font_bold = null
		queue_redraw()
@export var font_size: int = 20 :
	set(val):
		font_size = val
		queue_redraw()
@export var font_color: Color = Color.WHITE :
	set(val):
		font_color = val
		queue_redraw()
@export var SCROLL_MULT: float = 10
@export var SPACING = 0 :
	set(val):
		SPACING = val
		queue_redraw()
@export var COLOR_UI_MSG: Color = Color(.7,.7,.3)
@export var scroll_bar: VScrollBar :
	set(val):
		if scroll_bar == val: return
		if scroll_bar:
			scroll_bar.scrolling.disconnect(update_scroll)
			scroll_bar.value_changed.disconnect(_update_scroll2)
		scroll_bar = val
		scroll_bar.scrolling.connect(update_scroll)
		scroll_bar.value_changed.connect(_update_scroll2)

signal send_text(msg: String)

var font_bold: SystemFont :
	get:
		if font_bold: return font_bold
		font_bold = font.duplicate()
		font_bold.font_weight *= 2
		return font_bold
var font_italic: SystemFont :
	get:
		if font_italic: return font_italic
		font_italic = font.duplicate()
		font_italic.font_italic = true
		return font_italic
var font_bold_italic: SystemFont :
	get:
		if font_bold_italic: return font_bold_italic
		font_bold_italic = font.duplicate()
		font_bold_italic.font_italic = true
		font_bold_italic.font_weight *= 2
		return font_bold_italic

func get_font(flags: FontFlags = null) -> Font:
	if not flags: flags = FontFlags.new()
	if flags.bold:
		if flags.italic:
			return font_bold_italic
		else: return font_bold
	elif flags.italic:
		return font_italic
	else: return font
func get_font_height(flags: FontFlags = null) -> float:
	return get_font(flags).get_height(font_size)
func get_line_height() -> float:
	var h := 0.0
	for f in [font,font_bold,font_italic,font_bold_italic]:
		h = maxf(h,f.get_height(font_size))
	return SPACING+h
func get_font_ascent(flags: FontFlags = null) -> float:
	return get_font(flags).get_ascent(font_size)
func get_string_size(text: String, flags: FontFlags = null) -> Vector2:
	return get_font(flags).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

@onready var tooltip_bg: ColorRect = $TooltipBG
@onready var tooltip_label: Label = $TooltipBG/Tooltip
class ConsoleDrawData:
	var win_l: float
	var win_r: float
	var win_w: float :
		get: return win_r - win_l
	var win_cx: float :
		get: return win_l + win_w/2
	
	var l: float
	var t: float
	var r: float
	var b: float
	
	var x: float :
		set(val):
			x = val
			if not Util.approx_eq(x, l):
				reset_y = null
	var y: float
	
	var w: float:
		get: return r-l
	var h: float:
		get: return b-t
	
	var cx: float:
		get: return l + w/2
	var cy: float:
		get: return t + h/2
	
	var max_shown_y: float = 0.0
	var reset_y: Variant
	
	func show_y(ty: float) -> void:
		ty -= t
		if ty > max_shown_y:
			max_shown_y = ty;
	func max_scroll() -> float:
		var s := max_shown_y - b
		return 0.0 if s <= 0 else s
	func ensure_line(c: BaseConsole):
		if not Util.approx_eq(x, l):
			newline(c)
	func newline(c: BaseConsole, count := 1):
		var at_start := Util.approx_eq(x, l)
		x = l
		if count > 0:
			if at_start:
				reset_y = y
			else: reset_y = y + c.get_line_height()
		y += c.get_line_height() * count
	func ensure_spacing(c: BaseConsole, spacing: Vector2):
		if reset_y == null:
			newline(c)
		var r_y: float = reset_y
		x = l + spacing.x
		if not Util.approx_eq(r_y, t):
			y = max(y, r_y + spacing.y) # max to avoid reducing space
class ConsolePart: ## A base part, for all other parts to inherit from
	var on_click: Callable # Callable[InputEventMouseButton]->bool
	var hidden: bool = false
	signal hitbox_changed
	func draw(_c: BaseConsole, _data: ConsoleDrawData) -> void:
		pass
	func draw_hover(_c: BaseConsole, _data: ConsoleDrawData) -> void:
		pass
	func needs_hover() -> bool:
		return false
	func get_hitboxes() -> Array[Rect2]:
		return []
	func get_hitbox() -> Rect2: ## Combines all the hitboxes from 'get_hitboxes()' rectangularly
		var hbs := get_hitboxes()
		if hbs.is_empty(): return Rect2()
		var ret: Rect2 = hbs.back()
		for hb in hbs:
			var hb2 = ret
			ret.position.x = min(hb.position.x, hb2.position.x)
			ret.size.x = max(hb.position.x+hb.size.x, hb2.position.x+hb2.size.x) - ret.position.x
			ret.position.y = min(hb.position.y, hb2.position.y)
			ret.size.y = max(hb.position.y+hb.size.y, hb2.position.y+hb2.size.y) - ret.position.y
		return ret
	func try_hover(c: BaseConsole, pos: Vector2) -> bool:
		for hb in get_hitboxes():
			if hb.has_point(pos):
				c.update_hover(self, hb)
				return true
		return false
	func try_click(evt: InputEventMouseButton, pos: Vector2) -> bool:
		if on_click:
			for hb in get_hitboxes():
				if hb.has_point(pos):
					return on_click.call(evt)
		return false
	func pop_dropdown(c: BaseConsole) -> VBoxContainer:
		var parent_window := c.get_window()
		var window := Window.new()
		window.min_size = Vector2.ZERO
		window.reset_size()
		window.transient = true
		window.exclusive = true
		window.unresizable = true
		window.borderless = true
		window.popup_window = true
		window.visible = false
		window.focus_exited.connect(window.queue_free)
		window.close_requested.connect(window.queue_free)
		parent_window.close_requested.connect(window.queue_free)
		var vbox := VBoxContainer.new()
		var resize_window: Callable = func():
			var hb := get_hitbox()
			window.size.x = roundi(hb.size.x)
			window.size.y = ceili(vbox.size.y)
			window.position.x = roundi(c.global_position.x + hb.position.x)
			window.position.y = roundi(c.global_position.y + hb.position.y + hb.size.y)
			if not window.visible: window.visible = true
		hitbox_changed.connect(resize_window)
		window.add_child(vbox)
		window.ready.connect(resize_window)
		window.tree_exiting.connect(func(): hitbox_changed.disconnect(resize_window))
		c.add_child.call_deferred(window) # Defer adding it, to allow caller to add things to the vbox
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		return vbox
	func dont_draw() -> bool:
		return hidden
class TextPart extends ConsolePart: ## A part that displays text, with opt color+tooltip
	var text: String = ""
	var tooltip: String = ""
	var color: Color = Color.TRANSPARENT
	var hitboxes: Array[Rect2] = []
	var bold := false
	var underline := false
	var italic := false
	var _font_flags: FontFlags = FontFlags.new() :
		get:
			_font_flags.bold = bold
			_font_flags.italic = italic
			return _font_flags
	
	func _draw_string(c: BaseConsole, subtext: String, data: ConsoleDrawData):
		var str_sz = c.get_string_size(subtext, _font_flags)
		var pos := Vector2(data.x, data.y+c.get_font_ascent(_font_flags))
		c.draw_string(c.get_font(_font_flags), pos, subtext, HORIZONTAL_ALIGNMENT_LEFT, -1, c.font_size, _get_color(c))
		var hb := Rect2(Vector2(data.x,data.y), str_sz)
		if DEBUG_RECTS: c.draw_rect(hb, _get_color(c), false, 4)
		hitboxes.append(hb)
		if underline:
			c.draw_rect(Rect2(hb.position.x, hb.position.y + str_sz.y, hb.size.x, 1), _get_color(c))
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		var text_pos = 0
		var trim_pos: int
		var old_hitbox := get_hitbox()
		hitboxes.clear()
		var space_only := true
		while true:
			if text_pos >= text.length():
				break
			if text[text_pos] == "\n":
				data.newline(c)
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
			trim_pos = text.find("\n", text_pos)
			if trim_pos < 0: trim_pos = text.length()
			var subtext := text.substr(text_pos,trim_pos-text_pos)
			var str_sz := c.get_string_size(subtext, _font_flags)
			while data.x < data.r and data.x + str_sz.x >= data.r and trim_pos > text_pos:
				if text[trim_pos-1].lstrip(" \t"):
					while trim_pos > text_pos and text[trim_pos-1].lstrip(" \t"): # Trim non-WS
						trim_pos -= 1
						if not space_only: break # Allow breaking mid-word
				else:
					while trim_pos > text_pos and not text[trim_pos-1].lstrip(" \t"): # Trim WS
						trim_pos -= 1
				subtext = text.substr(text_pos,trim_pos-text_pos)
				str_sz = c.get_string_size(subtext, _font_flags)
			if trim_pos <= text_pos: # No space at all, window is too thin
				if Util.approx_eq(data.x, data.l):
					if space_only:
						space_only = false
						continue # Try again, allowing breaking mid-word
					break # abort to avoid infinite loop
				data.x = data.r # Force next line
			if data.x >= data.r: # no space! next line!
				data.newline(c)
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
			# The string WILL be drawn if this line is reached
			space_only = true # Reset space check mode
			if subtext.lstrip(" \t"): #not all whitespace
				str_sz = c.get_string_size(subtext, _font_flags)
				_draw_string(c, subtext, data)
				data.show_y(data.y + str_sz.y + c.get_font_ascent(_font_flags))
				data.x += str_sz.x
			elif trim_pos < text.length():
				# Trimmed whitespace, need to force the line down though
				data.x = data.r
			text_pos = trim_pos
		if old_hitbox != get_hitbox():
			hitbox_changed.emit()
	func _ttip_calc_size(c: BaseConsole, data: ConsoleDrawData, clip := false) -> void:
		if clip:
			c.tooltip_label.size = Vector2(data.win_w,c.tooltip_label.size.y)
			var h: int = 0 if c.tooltip_label.get_line_count() else c.tooltip_label.get_line_height()
			for q in c.tooltip_label.get_line_count():
				h += c.tooltip_label.get_line_height(q)
			c.tooltip_label.size = Vector2(c.tooltip_label.size.x,h)
		else:
			c.tooltip_label.reset_size()
		c.tooltip_bg.size = c.tooltip_label.size
		
		var cpos: Vector2 = c.hovered_hitbox.get_center()
		c.tooltip_bg.position.x = cpos.x - c.tooltip_bg.size.x/2
		if cpos.y >= c.size.y/2:
			c.tooltip_bg.position.y = c.hovered_hitbox.position.y - c.tooltip_bg.size.y
		else:
			c.tooltip_bg.position.y = c.hovered_hitbox.position.y + c.hovered_hitbox.size.y
		#region Add border
		const HMARGIN = 2
		const VMARGIN = 2
		c.tooltip_label.position.x = HMARGIN
		c.tooltip_label.position.y = VMARGIN
		c.tooltip_bg.size.x += 2*HMARGIN
		c.tooltip_bg.size.y += 2*VMARGIN
		#endregion Add border
	func draw_hover(c: BaseConsole, data: ConsoleDrawData) -> void:
		if not tooltip: return
		c.tooltip_bg.visible = true
		c.tooltip_label.text = tooltip
		c.tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.tooltip_label.reset_size()
		_ttip_calc_size(c,data)
		
		#region Bound tooltip in-window
		if c.tooltip_bg.size.x >= data.w: #don't let width overrun
			c.tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			c.tooltip_label.get_minimum_size() # Removing this getter breaks everything for some reason. WTF.
			_ttip_calc_size(c,data,true)
		while c.tooltip_bg.position.x < data.win_l:
			c.tooltip_bg.position.x += 1
		while c.tooltip_bg.position.x + c.tooltip_bg.size.x >= data.win_r:
			c.tooltip_bg.position.x -= 1
		while c.tooltip_bg.position.y < 0:
			c.tooltip_bg.position.y += 1
		while c.tooltip_bg.position.y + c.tooltip_bg.size.y >= data.b:
			c.tooltip_bg.position.y -= 1
		#endregion Bound tooltip in-window
	func needs_hover() -> bool:
		return not tooltip.is_empty()
	func get_hitboxes() -> Array[Rect2]:
		return hitboxes
	
	func _get_color(c: BaseConsole) -> Color:
		return color if color.a8 else c.font_color
	
	func copy_to(other: TextPart) -> void:
		other.text = text
		other.tooltip = tooltip
		other.color = color
		other.hitboxes = hitboxes
		other.bold = bold
		other.underline = underline
		other.italic = italic
	func centered() -> CenterTextPart:
		var c := CenterTextPart.new()
		copy_to(c)
		return c
class CenterTextPart extends TextPart:
	func _draw_string(c: BaseConsole, subtext: String, data: ConsoleDrawData):
		var str_sz = c.get_string_size(subtext, _font_flags)
		var pos := Vector2(data.cx - str_sz.x/2, data.y+c.get_font_ascent(_font_flags))
		c.draw_string(c.get_font(_font_flags), pos, subtext, HORIZONTAL_ALIGNMENT_LEFT, -1, c.font_size, _get_color(c))
		var hb := Rect2(data.l, data.y, data.w, str_sz.y)
		if DEBUG_RECTS: c.draw_rect(hb, _get_color(c), false, 4)
		hitboxes.append(hb)
		if underline:
			c.draw_rect(Rect2(pos.x, data.y + str_sz.y, str_sz.x, 1), _get_color(c))
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		data.ensure_line(c)
		super(c, data)

class LineBreakPart extends ConsolePart: ## A part that breaks a line
	var break_count: int = 1
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		data.newline(c, break_count)
class SpacingPart extends ConsolePart: ## A part that adds spacing
	var spacing := Vector2.ZERO
	var reset_line := true
	var from_reset_y := false
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		if reset_line:
			data.ensure_line(c)
		if from_reset_y:
			data.ensure_spacing(c, spacing)
		else:
			data.x += spacing.x
			if not Util.approx_eq(data.y, data.t):
				data.y += spacing.y
class IndentPart extends ConsolePart: ## A part that manages indents
	var indent: float = 0.0
	func draw(_c: BaseConsole, data: ConsoleDrawData) -> void:
		if Util.approx_eq(data.x, data.l):
			data.x += indent
		data.l += indent

class IteratorPart extends ConsolePart: ## A base part, for parts that contain parts
	func iter_parts() -> Array[ConsolePart]:
		return []
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		for p in iter_parts():
			p.draw(c,data)
	func draw_hover(c: BaseConsole, data: ConsoleDrawData) -> void:
		for p in iter_parts():
			p.draw_hover(c,data)
	func needs_hover() -> bool:
		for p in iter_parts():
			if p.needs_hover():
				return true
		return false
	func get_hitboxes() -> Array[Rect2]:
		var ret: Array[Rect2] = []
		for p in iter_parts():
			ret.append_array(p.get_hitboxes())
		return ret
	func try_hover(c: BaseConsole, pos: Vector2) -> bool:
		for p in iter_parts():
			if p.try_hover(c, pos):
				return true
		return false
	func try_click(evt: InputEventMouseButton, pos: Vector2) -> bool:
		for p in iter_parts():
			if p.try_click(evt, pos):
				return true
		return false
class ContainerPart extends IteratorPart:
	var parts: Array[ConsolePart] = []
	func iter_parts() -> Array[ConsolePart]:
		return parts
	func _add(part: ConsolePart) -> ConsolePart:
		parts.append(part)
		return part
	func clear() -> void:
		parts.clear()
class ColumnsPart extends ContainerPart:
	var widths: Array[int] = []
	
	## Adds a part as a 'Column', with an associated width.
	## Max of 1 part can have a width '-1', which will auto-fill the remaining width
	func add(part: ConsolePart, w: int) -> ConsolePart:
		_add(part)
		widths.append(w)
		return part
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		# Ensure we're at line start
		data.ensure_line(c)
		# Cache data vals
		var dl := data.l
		var dr := data.r
		var dy := data.y
		# Calculate widths of columns
		var dw := dr-dl
		var total_w := 0
		var ws := widths.duplicate()
		var count := 0
		for q in parts.size():
			if ws[q] > -1:
				total_w += ws[q]
				count += 1
		if total_w >= dw: # Uh-oh, not enough space!
			var per_diff: int = roundi((total_w - dw) / count)
			for q in parts.size():
				if ws[q] > -1:
					ws[q] -= per_diff
		else: # Room to spare?
			for q in parts.size():
				if ws[q] < 0:
					ws[q] = roundi(dw - total_w)
					total_w += ws[q]
		# Draw
		var by := data.y
		for q in parts.size():
			if ws[q] <= 0: continue
			data.y = dy # Start at top
			data.r = data.l + ws[q] # Set width
			parts[q].draw(c, data)
			# Increment position
			data.l += ws[q]
			data.x = data.l
			if data.y > by:
				by = data.y
		# Revert boundaries, and linebreak from by
		data.l = dl
		data.r = dr
		data.y = by
		data.newline(c)

class HintPart extends ColumnsPart: ## A part representing a hint info
	var hint: NetworkHint
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		if parts.is_empty():
			refresh(c)
		var vspc = c.get_line_height()/4
		data.ensure_spacing(c, Vector2(0, vspc))
		super(c, data)
		for part in parts:
			if part is TextPart and not part.hitboxes.is_empty():
				var top_hb = part.hitboxes.front()
				top_hb.position.y -= vspc/2
				top_hb.size.y += vspc/2
				part.hitboxes[0] = top_hb
				var bot_hb = part.hitboxes.back()
				bot_hb.size.y += vspc/2
				part.hitboxes[-1] = bot_hb
	func refresh(c: BaseConsole) -> void:
		parts.clear()
		var data := Archipelago.conn.get_gamedata_for_player(hint.item.src_player_id)
		
		add(Archipelago.out_player(c, hint.item.dest_player_id, false).centered(), 500)
		add(hint.item.output(c, false).centered(), 500)
		add(Archipelago.out_player(c, hint.item.src_player_id, false).centered(), 500)
		add(Archipelago.out_location(c, hint.item.loc_id, data, false).centered(), 500)
		add(hint.make_status(c).centered(), 500).on_click = func(evt): return change_status(evt,c)
	func change_status(event: InputEventMouseButton, c: BaseConsole) -> bool:
		if not event.pressed: return false
		if hint.item.dest_player_id != Archipelago.conn.player_id:
			return false # Lacking permission
		if hint.status == NetworkHint.Status.FOUND: return false # Can't change found
		if hint.status == NetworkHint.Status.NOT_FOUND: return false # Indicates feature unsupported
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			var vbox := parts[4].pop_dropdown(c)
			vbox.add_theme_constant_override("separation", 0)
			for s in [NetworkHint.Status.AVOID,NetworkHint.Status.NON_PRIORITY,NetworkHint.Status.PRIORITY]:
				var btn := Button.new()
				btn.text = NetworkHint.status_names[s]
				btn.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
				btn.pressed.connect(func():
					Archipelago.conn.update_hint(hint.item.loc_id, hint.item.src_player_id, s)
					vbox.get_window().close_requested.emit())
				vbox.add_child(btn)
			return true
		return false

func add(part: ConsolePart) -> ConsolePart:
	if not part: return
	parts.append(part)
	queue_redraw()
	return part

func make_text(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	var part := TextPart.new()
	part.text = text
	part.tooltip = ttip
	part.color = col
	return part
func add_text(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	return add(make_text(text, ttip, col))

func make_c_text(text: String, ttip := "", col := Color.TRANSPARENT) -> CenterTextPart:
	var part := CenterTextPart.new()
	part.text = text
	part.tooltip = ttip
	part.color = col
	return part
func add_c_text(text: String, ttip := "", col := Color.TRANSPARENT) -> CenterTextPart:
	return add(make_c_text(text, ttip, col))

func make_line(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	return make_text(text+"\n", ttip, col)
func add_line(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	return add(make_line(text, ttip, col))

func make_linebreak(count := 1) -> LineBreakPart:
	var part = LineBreakPart.new()
	part.break_count = count
	return part
func add_linebreak(count := 1) -> LineBreakPart:
	return add(make_linebreak(count))

func make_spacing(spacing: Vector2, reset_line := true, from_reset_y := false) -> SpacingPart:
	var part = SpacingPart.new()
	part.spacing = spacing
	part.reset_line = reset_line
	part.from_reset_y = from_reset_y
	return part
func add_spacing(spacing: Vector2, reset_line := true, from_reset_y := false) -> SpacingPart:
	return add(make_spacing(spacing, reset_line, from_reset_y))

func make_header_spacing(vspace: float = -0.5) -> SpacingPart:
	if vspace < 0: vspace = get_line_height() * abs(vspace)
	return make_spacing(Vector2(0,vspace), false, true)
func add_header_spacing(vspace: float = -0.5) -> SpacingPart:
	return add(make_header_spacing(vspace))

func make_indent(indent: float) -> IndentPart:
	var part = IndentPart.new()
	part.indent = indent
	return part
func add_indent(indent: float) -> IndentPart:
	return add(make_indent(indent))

func make_hint(hint: NetworkHint) -> HintPart:
	var ret := HintPart.new()
	ret.hint = hint
	return ret
func add_hint(hint: NetworkHint) -> HintPart:
	return add(make_hint(hint))

func ensure_newline(parts_arr: Array[ConsolePart]): ## Returns SpacingPart | null
	if not parts_arr.is_empty():
		var last_part = parts_arr.back()
		if last_part is SpacingPart:
			if last_part.reset_line or last_part.from_reset_y:
				return #already ensured
	return make_header_spacing(0)
func add_ensure_newline(): ## Returns SpacingPart | null
	add(ensure_newline(parts))

var parts: Array[ConsolePart] = []
var hovered_part: ConsolePart = null
var hovered_hitbox: Rect2
var scroll: float = 0 :
	get: return scroll_bar.value if scroll_bar else scroll
	set(val):
		if scroll_bar: scroll_bar.value = val
		else: scroll = val
var is_max_scroll := true
var has_mouse := false

func _init():
	if Engine.is_editor_hint():
		add_text("Test Font\n")
		add_text("Bold Font\n").bold = true
		add_text("Italic Font\n").italic = true
		var v = add_text("BoldItalic Font\n")
		v.bold = true
		v.italic = true
		add_text("Underline Font\n").underline = true
		return
	mouse_entered.connect(func():
		has_mouse = true
		refocus_part())
	mouse_exited.connect(func():
		has_mouse = false
		refocus_part())

func _process(_delta):
	if Engine.is_editor_hint(): return
	refocus_part()

func _get_mouse_pos() -> Vector2:
	return get_viewport().get_mouse_position() - global_position + Util.MOUSE_OFFSET

func update_hover(part: ConsolePart, hb: Rect2) -> void:
	var changed := false
	if hovered_part != part:
		hovered_part = part
		changed = true
	if not part or not part.needs_hover():
		hb = Rect2()
	if hovered_hitbox != hb:
		hovered_hitbox = hb
		changed = true
	if changed:
		queue_redraw()
func refocus_part():
	if Engine.is_editor_hint(): return
	var pos := _get_mouse_pos()
	if has_mouse:
		var found := false
		for part in parts:
			if part.try_hover(self, pos):
				found = true
				break
		if not found:
			update_hover(null, Rect2())

var _draw_data := ConsoleDrawData.new()
func _draw():
	if Engine.is_editor_hint() or OS.is_debug_build(): # Reload these fonts each redraw, incase they changed
		font_bold = null
		font_italic = null
		font_bold_italic = null
	_draw_data.win_l = 0
	_draw_data.l = _draw_data.win_l
	_draw_data.t = -scroll
	_draw_data.win_r = size.x
	_draw_data.r = _draw_data.win_r
	_draw_data.b = size.y
	_draw_data.x = _draw_data.l
	_draw_data.y = _draw_data.t
	_draw_data.max_shown_y = 0.0
	_draw_data.reset_y = _draw_data.t
	tooltip_bg.visible = false
	tooltip_label.text = ""
	for part in parts:
		#if part is TextPart:
			#part.color = Color.RED if part == hovered_part else Color.WHITE
		part.draw(self, _draw_data)
	if hovered_part:
		hovered_part.draw_hover(self, _draw_data)
	
	if Engine.is_editor_hint(): return
	
	var max_scroll = _draw_data.max_scroll()
	if scroll > max_scroll:
		scroll = max_scroll
		queue_redraw.call_deferred()
	elif scroll < max_scroll and is_max_scroll:
		scroll = _draw_data.max_scroll()
		queue_redraw.call_deferred()
	if Util.approx_eq(scroll,_draw_data.max_scroll()):
		is_max_scroll = true
	if scroll_bar:
		scroll_bar.max_value = max_scroll
		scroll_bar.value = scroll
		scroll_bar.visible = max_scroll > Util.GAMMA
	#var mpos = _get_mouse_pos()
	#draw_rect(Rect2(mpos.x-1,mpos.y-1,2,2), Color.REBECCA_PURPLE)

func scroll_by(amount: float) -> void:
	scroll_by_abs(amount * SCROLL_MULT)
func scroll_by_abs(amount: float) -> void:
	var old_scroll := scroll
	scroll = clampf(scroll + amount, 0, _draw_data.max_scroll())
	if not Util.approx_eq(scroll,old_scroll):
		update_scroll()
func _update_scroll2(_junk) -> void:
	return update_scroll()
func update_scroll() -> void:
	is_max_scroll = Util.approx_eq(scroll,_draw_data.max_scroll())
	queue_redraw()
func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventMouseButton:
		for part in Util.reversed(parts):
			if part.try_click(event, _get_mouse_pos()):
				return
		var fac: float = 1.0 if event.factor < Util.GAMMA else event.factor
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-fac)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(fac)
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_HOME:
					scroll_by_abs(-scroll)
				KEY_END:
					scroll_by_abs(_draw_data.max_scroll())
				KEY_UP:
					scroll_by_abs(-get_line_height())
				KEY_DOWN:
					scroll_by_abs(get_line_height())
				KEY_PAGEUP:
					scroll_by_abs(-size.y)
				KEY_PAGEDOWN:
					scroll_by_abs(size.y)

func close() -> void:
	if Engine.is_editor_hint(): return
	var p = self
	while p and not p is ConsoleWindowContainer:
		p = p.get_parent()
	if p:
		p.close()

func send_msg(msg: String):
	send_text.emit(msg)
	scroll_by_abs(_draw_data.max_scroll())

func clear() -> void:
	parts.clear()
	queue_redraw()

func printjson_command(json: Dictionary) -> String:
	var s := ""
	var output_data := false
	var pre_space := false
	var post_space := false
	match json.get("type"):
		"Chat":
			var msg = json.get("message","")
			var name_part := Archipelago.conn.get_player(json["slot"]).output(self)
			name_part.text += ": "
			if not msg.is_empty():
				add_text(msg)
				s += name_part.text + msg
		"CommandResult", "AdminCommandResult", "Goal", "Release", "Collect", "Tutorial":
			pre_space = true
			post_space = true
			output_data = true
		"Countdown":
			if int(json["countdown"]) == 0:
				post_space = true
			output_data = true
		"ItemSend", "ItemCheat":
			if not Archipelago.AP_HIDE_NONLOCAL_ITEMSENDS:
				output_data = true
			elif int(json["receiving"]) == Archipelago.conn.player_id:
				output_data = true
			else:
				var ni := NetworkItem.from(json["item"], true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Hint":
			if int(json["receiving"]) == Archipelago.conn.player_id:
				output_data = true
			else:
				var ni := NetworkItem.from(json["item"], true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Join", "Part":
			var data: Array = json["data"]
			var elem: Dictionary = data.pop_front()
			var plyr := Archipelago.conn.get_player(json["slot"])
			var spl := (elem["text"] as String).split(plyr.get_name(), true, 1)
			if spl.size() == 2:
				elem["text"] = spl[0]
				s += printjson_out([elem])
				s += plyr.output(self).text
				elem["text"] = spl[1]
				s += printjson_out([elem])
				s += printjson_out(data)
			else: output_data = true
		_:
			output_data = true
	if pre_space and output_data:
		add_header_spacing()
	if output_data:
		s += printjson_out(json["data"])
	if post_space and output_data:
		add_header_spacing()
	add_ensure_newline()
	return s

func printjson_out(elems: Array) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		s += txt
		match elem.get("type", "text"):
			"player_name":
				add_text(txt, "Arbitrary Player Name", AP.rich_colors[AP.COLORNAME_PLAYER])
			"item_name":
				add_text(txt, "Arbitrary Item Name", AP.rich_colors[AP.COLORNAME_ITEM])
			"location_name":
				add_text(txt, "Arbitrary Location Name", AP.rich_colors[AP.COLORNAME_LOCATION])
			"entrance_name":
				add_text(txt, "Arbitrary Entrance Name", AP.rich_colors[AP.COLORNAME_LOCATION])
			"player_id":
				var plyr_id = int(txt)
				Archipelago.conn.get_player(plyr_id).output(self)
			"item_id":
				var item_id = int(txt)
				var plyr_id = int(elem["player"])
				var data := Archipelago.conn.get_gamedata_for_player(plyr_id)
				var flags := int(elem["flags"])
				Archipelago.out_item(self, item_id, flags, data)
			"location_id":
				var loc_id = int(txt)
				var plyr_id = int(elem["player"])
				var data := Archipelago.conn.get_gamedata_for_player(plyr_id)
				Archipelago.out_location(self, loc_id, data)
			"text":
				add_text(txt)
			"color":
				var part := add_text(txt)
				var col_str: String = elem["color"]
				if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
					col_str = col_str.substr(0,col_str.length()-3)
				match col_str:
					"bold":
						part.bold = true
					"underline":
						part.underline = true
					_:
						part.color = Archipelago.rich_colors.get(col_str, part.color)
	return s

static func printjson_str(elems: Array) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		s += txt
	return s

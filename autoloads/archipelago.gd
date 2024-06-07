class_name AP extends Node

const AP_GAME_NAME := "Super Metroid"
const AP_GAME_TAGS: Array[String] = []
const AP_ITEM_HANDLING := ItemHandling.ALL
const AP_LOG_COMMUNICATION := true
const COLOR_PLAYER: Color = Color8(238,0,238)
const COLOR_ITEM_PROG: Color = Color8(175,153,239)
const COLOR_ITEM: Color = Color8(1,234,234)
const COLOR_ITEM_TRAP: Color = Color.RED
const COLOR_LOCATION: Color = Color8(1,252,126)
const COLOR_SELF: Color = Color.GOLDENROD
const COLOR_UI_MSG: Color = Color(.7,.7,.3)

enum ItemHandling {
	NONE = 0,
	OTHER = 1,
	OWN_OTHER = 3,
	STARTING_OTHER = 5,
	ALL = 7,
}

var ip: String = "archipelago.gg"
var port: String = ""
var slot: String = ""
var pwd: String = ""
var death_alias: String = ""
var uid: int

var socket := WebSocketPeer.new()

#region CONNECTION
class ConnectionInfo:
	var serv_version: Version
	var gen_version: Version
	var seed_name: String
	
	var player_id: int
	var team_id: int
	var slot_data: Dictionary
	
	var players: Array[NetworkPlayer]
	var slots: Array[NetworkSlot]
	
	func _to_string():
		return "AP_CONN(SERV_%s, GEN_%s, SEED:%s, PLYR %d, TEAM %d, SLOT_DATA %s)" % [serv_version,gen_version,seed_name,player_id,team_id,slot_data]
	
	func get_player(id: int) -> NetworkPlayer:
		return players[id-1]
	func get_slot(id: int) -> NetworkSlot:
		return slots[id-1]
	func get_player_name(plyr_id: int, alias := true) -> String:
		var name = get_player(plyr_id).get_name(alias)
		if not name: name = "Player %d" % plyr_id
		return name
	func get_game_for_player(plyr_id: int) -> String:
		return slots[plyr_id-1].game
	func get_gamedata_for_player(plyr_id: int) -> DataCache:
		return AP.get_datacache(get_game_for_player(plyr_id))
	

var conn: ConnectionInfo

enum APStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	PLAYING, # 'Authenticated'
	DISCONNECTING,
}
signal status_updated
var queue_reconnect := false
var status: APStatus = APStatus.DISCONNECTED :
	set(val):
		if status != val:
			status = val
			status_updated.emit()
		if status == APStatus.DISCONNECTED:
			conn = null
			if queue_reconnect:
				queue_reconnect = false
				ap_reconnect()

var connecting_part: CustomConsole.TextPart

func ap_reconnect() -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect()
		queue_reconnect = true
		return
	var attempts := 1
	var wss := true
	var url: String
	while true:
		url = "%s://%s:%s" % ["wss" if wss else "ws",ip,port]
		socket.close()
		var err := socket.connect_to_url(url)
		if err:
			AP.log("Connection to '%s' failed! Retrying (%d)" % [url,attempts])
			wss = not wss
			if wss: attempts += 1
		else: break
	AP.log("Connected to '%s'!" % url)
	if output_console:
		connecting_part = output_console.add_text("Connecting...\n","%s:%s %s" % [ip,port,slot],COLOR_UI_MSG)
	status = APStatus.CONNECTING

func ap_connect(room_ip: String, room_port: String, slot_name: String, room_pwd := "") -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect() # Do it here so the ip/port/slot are correct in the disconnect message
	AP.open_logger()
	ip = room_ip
	port = room_port
	slot = slot_name
	pwd = room_pwd
	death_alias = ""
	ap_reconnect()

func ap_disconnect() -> void:
	if status == APStatus.DISCONNECTED or status == APStatus.DISCONNECTING:
		return
	status = APStatus.DISCONNECTING
	socket.close()
	AP.close_logger()
	if output_console:
		var part := output_console.add_text("Disconnecting...\n","%s:%s %s" % [ip,port,slot],COLOR_UI_MSG)
		while status != APStatus.DISCONNECTED:
			await status_updated
		part.text = "Disconnected from AP.\n"
#endregion CONNECTION

static var logging_file = null
static func open_logger() -> void:
	logging_file = FileAccess.open("user://ap/ap_log.log",FileAccess.WRITE)
static func close_logger() -> void:
	if logging_file:
		logging_file.close()
		logging_file = null
static func log(s: Variant) -> void:
	if logging_file:
		logging_file.store_line(str(s))
		if OS.is_debug_build(): logging_file.flush()
	print("[AP] %s" % str(s))
static func comm_log(pref: String, s: Variant) -> void:
	if not AP_LOG_COMMUNICATION: return
	AP.log("[%s] %s" % [pref,str(s)])
static func dblog(s: Variant) -> void:
	if not OS.is_debug_build(): return
	AP.log(s)

func poll():
	if status == APStatus.DISCONNECTED:
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_CLOSED: # Exited; handle reconnection, or concluding intentional disconnection
			if status == APStatus.DISCONNECTING:
				status = APStatus.DISCONNECTED
			else:
				AP.log("Accidental disconnection; reconnecting!")
				ap_reconnect()
		WebSocketPeer.STATE_OPEN: # Running; handle communication
			while socket.get_available_packet_count():
				var packet: PackedByteArray = socket.get_packet()
				var json = JSON.parse_string(packet.get_string_from_utf8())
				if not json is Array:
					json = [json]
				for dict in json:
					handle_command(dict)

var printout_recieved_items: bool = false
func send_command(cmdname: String, obj: Dictionary) -> void:
	obj["cmd"] = cmdname
	send_packet([obj])
func send_packet(obj: Array) -> void:
	var s := JSON.stringify(obj)
	AP.comm_log("SEND", s)
	socket.send_text(s)
func handle_command(json: Dictionary) -> void:
	var command = json["cmd"]
	match command:
		"RoomInfo":
			status = APStatus.CONNECTED
			if output_console and connecting_part:
				connecting_part.text = "Authenticating...\n"
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args: Dictionary = {"name":slot,"password":pwd,"uuid":uid,
				"version":Version.val(0,4,6)._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			send_command("Connect",args)
		"ConnectionRefused":
			var err_str := str(json["errors"])
			if output_console and connecting_part:
				connecting_part.text = "Connection Refused!\n"
				connecting_part.tooltip += "\nERROR(S): "+err_str
			AP.log("Connection errors: %s" % err_str)
			ap_disconnect()
		"Connected":
			conn.player_id = json["slot"]
			conn.team_id = json["team"]
			#conn.slot_data = json["slot_data"]
			for plyr in json["players"]:
				conn.players.append(NetworkPlayer.from(plyr, conn))
			var slot_info = json["slot_info"]
			for key in slot_info:
				conn.slots.append(NetworkSlot.from(slot_info[key]))
			AP.log(conn)
			
			for loc in json["missing_locations"]:
				if not _removed_locs.has(loc as int):
					_removed_locs[loc as int] = false
					#Force this locations to be accessible?
			
			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true
			
			var to_collect: Array[int] = []
			for loc in _removed_locs.keys():
				if _removed_locs[loc] and not loc in server_checked:
					to_collect.append(loc)
			collect_locations(to_collect)
			
			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?
			
			send_datapack_request()
			
			status = APStatus.PLAYING
			if output_console and connecting_part:
				connecting_part.text = "Connected Successfully!\n"
			
			printout_recieved_items = true
			await get_tree().create_timer(3).timeout
			printout_recieved_items = false
		"PrintJSON":
			var s: String = ""
			for elem in json["data"]:
				var txt: String = elem["text"]
				s += txt
				if output_console:
					match elem.get("type", "text"):
						"player_name":
							output_console.add_text(txt, "Arbitrary Player Name", COLOR_PLAYER)
						"item_name":
							output_console.add_text(txt, "Arbitrary Item Name", COLOR_ITEM)
						"location_name":
							output_console.add_text(txt, "Arbitrary Location Name", COLOR_LOCATION)
						"entrance_name":
							output_console.add_text(txt, "Arbitrary Entrance Name", COLOR_LOCATION)
						"player_id":
							var plyr_id = int(txt)
							conn.get_player(plyr_id).output(output_console)
						"item_id":
							var item_id = int(txt)
							var plyr_id = int(elem["player"])
							var data := conn.get_gamedata_for_player(plyr_id)
							var flags := int(elem["flags"])
							AP.out_item(output_console, item_id, flags, data)
						"location_id":
							var loc_id = int(txt)
							var plyr_id = int(elem["player"])
							var data := conn.get_gamedata_for_player(plyr_id)
							AP.out_location(output_console, loc_id, data)
						"text":
							output_console.add_text(txt)
						"color":
							var part := output_console.add_text(txt)
							var col_str: String = elem["color"]
							if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
								col_str = col_str.substr(0,col_str.length()-3)
							match col_str:
								"red":
									part.color = Color.RED
								"green":
									part.color = Color.GREEN
								"yellow":
									part.color = Color.YELLOW
								"blue":
									part.color = Color.BLUE
								"magenta":
									part.color = Color.MAGENTA
								"cyan":
									part.color = Color.CYAN
								"white":
									part.color = Color.WHITE
								"bold":
									part.bold = true
								"underline":
									part.underline = true
			if output_console:
				output_console.add_linebreak()
			AP.log("[PRINT] %s" % s)
		"DataPackage":
			var packs = json["data"]["games"]
			for game in packs.keys():
				handle_datapack(game, packs[game])
			send_datapack_request()
		"ReceivedItems":
			if datapack_pending:
				await all_datapacks_loaded
			while status != APStatus.PLAYING:
				if status == APStatus.CONNECTED:
					await status_updated
				else: return
			var idx: int = json["index"]
			var items: Array[NetworkItem] = []
			for obj in json["items"]:
				items.append(NetworkItem.from(obj, conn, true))
			for item in items:
				recieve_item(idx, item)
				idx += 1
		_: #TODO "LocationInfo","RoomUpdate","Bounced","Retrieved","SetReply","InvalidPacket"
			AP.log("[UNHANDLED PACKET TYPE] %s" % str(json))

#region DATAPACKS
class DataCache:
	var item_name_to_id: Dictionary = {}
	var location_name_to_id: Dictionary = {}
	var checksum: String = ""
	
	static func from(data: Dictionary) -> DataCache:
		var c = DataCache.new()
		c.item_name_to_id = data.get("item_name_to_id",c.item_name_to_id)
		for k in c.item_name_to_id.keys():
			c.item_name_to_id[k] = c.item_name_to_id[k] as int
		c.location_name_to_id = data.get("location_name_to_id",c.location_name_to_id)
		for k in c.location_name_to_id.keys():
			c.location_name_to_id[k] = c.location_name_to_id[k] as int
		c.checksum = data.get("checksum",c.checksum)
		return c
	static func from_file(file: FileAccess) -> DataCache:
		if not file: return null
		var dict = JSON.parse_string(file.get_as_text())
		if dict is Dictionary:
			return from(dict)
		return null
	func get_item_id(name:String) -> int:
		var id = item_name_to_id.get(name,-1)
		assert(id > -1)
		return id
	func get_loc_id(name:String) -> int:
		var id = location_name_to_id.get(name,-1)
		assert(id > -1)
		return id
	func get_item_name(id:int) -> String:
		var v = item_name_to_id.find_key(id)
		return v if v else str(id)
	func get_loc_name(id:int) -> String:
		var v = location_name_to_id.find_key(id)
		return v if v else str(id)
const READABLE_DATAPACK_FILES = true
const datapack_cached_fields = ["item_name_to_id","location_name_to_id","checksum"]
var datapack_cache: Dictionary
var datapack_pending: Array = []
signal all_datapacks_loaded
func handle_datapackage_checksums(checksums: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://ap/datapacks/") # Ensure the directory exists, for later
	var cachefile: FileAccess = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.READ)
	if cachefile:
		datapack_cache = cachefile.get_var(true)
		cachefile.close()
	datapack_pending = []
	for game in checksums.keys():
		if datapack_cache.has(game):
			var cached = datapack_cache[game]
			if cached["checksum"] == checksums[game] and cached["fields"] == datapack_cached_fields:
				continue #already up-to-date, matching checksum
		match game: # TODO Temporary while Stardew's datapack is broken- stops other games from being broken too
			"Stardew Valley":
				pass
			_:
				datapack_pending.append(game)

func handle_datapack(game: String, data: Dictionary) -> void:
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.WRITE)
	datapack_cache[game] = {"checksum":data["checksum"],"fields":datapack_cached_fields.duplicate()}
	for key in data.keys():
		if not key in datapack_cached_fields:
			data.erase(key)
	data_file.store_string(JSON.stringify(data, "\t" if READABLE_DATAPACK_FILES else ""))
func send_datapack_request() -> void:
	if datapack_pending:
		var game = datapack_pending.pop_front()
		var req = [{"cmd":"GetDataPackage","games":[game]}]
		#var req = [{"cmd":"GetDataPackage","games":datapack_pending}]
		#datapack_pending = []
		send_packet(req)
	else:
		var cachefile = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.WRITE)
		cachefile.store_var(datapack_cache, true)
		cachefile.close()
		all_datapacks_loaded.emit()

static var _data_caches: Dictionary = {}
static func get_datacache(game: String) -> DataCache:
	var ret: DataCache = _data_caches.get(game)
	if ret: return ret
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.READ)
	if not data_file:
		return DataCache.new()
	ret = DataCache.from_file(data_file)
	data_file.close()
	_data_caches[game] = ret
	return ret
#endregion DATAPACKS

#region ITEMS
var _recieved_item_index := -1
func recieve_item(index: int, item: NetworkItem) -> void:
	assert(item.dest_player_id == conn.player_id)
	if index <= _recieved_item_index:
		return # Already recieved, skip
	var data := AP.get_datacache(AP_GAME_NAME)
	var msg := ""
	if item.dest_player_id == item.src_player_id:
		if output_console and printout_recieved_items:
			AP.out_player(output_console, conn.player_id, conn)
			output_console.add_text(" found their ")
			item.output(output_console, data)
			output_console.add_text(" (")
			AP.out_location(output_console, item.loc_id, data)
			output_console.add_text(")\n")
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	else:
		var src_data := conn.get_gamedata_for_player(item.src_player_id)
		if output_console and printout_recieved_items:
			conn.get_player(item.src_player_id).output(output_console)
			output_console.add_text(" sent ")
			item.output(output_console, data)
			output_console.add_text(" to ")
			AP.out_player(output_console, conn.player_id, conn)
			output_console.add_text(" (")
			AP.out_location(output_console, item.loc_id, src_data)
			output_console.add_text(")\n")
		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]
	
	#TODO actually handle recieving?
	AP.log(msg)
	
	_recieved_item_index = index
#endregion ITEMS

#region LOCATIONS
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal _remove_location(loc_id: int)
var _removed_locs: Dictionary = {}
func _remove_loc(loc_id: int) -> void:
	if not _removed_locs.get(loc_id, false):
		_removed_locs[loc_id] = true
		_remove_location.emit(loc_id)
func _on_removed_id(loc_id: int, proc: Callable) -> void:
	if _removed_locs.get(loc_id, false):
		proc.call()
	else:
		_remove_location.connect(func(id:int):
			if id == loc_id:
				proc.call())
func on_removed(loc_name: String, proc: Callable) -> void:
	_on_removed_id(AP.get_datacache(AP_GAME_NAME).get_loc_id(loc_name), proc)

## Call when a location is collected and needs to be sent to the server.
func collect_location(loc_id: int) -> void:
	printout_recieved_items = false
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
func collect_locations(locs: Array[int]) -> void:
	printout_recieved_items = false
	send_command("LocationChecks", {"locations":locs})
	for loc_id in locs:
		_remove_loc(loc_id)
#endregion LOCATIONS
func _process(_delta):
	poll()

func _ready():  #TODO REMOVE TESTING
	ap_connect("archipelago.gg","50874","EmilySM")

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		AP.close_logger()

#region DATACLASSES
class Version:
	var major := 0
	var minor := 0
	var build := 0
	
	static func from(json: Dictionary) -> Version:
		if json["class"] != "Version":
			return null
		var v := Version.new()
		v.major = json["major"]
		v.minor = json["minor"]
		v.build = json["build"]
		return v
	static func val(v1:int, v2:int, v3:int):
		var v = Version.new()
		v.major = v1
		v.minor = v2
		v.build = v3
		return v
	
	func _to_string():
		return "VER(%d.%d.%d)" % [major,minor,build]
	
	func compare(other: Version) -> int:
		if major != other.major:
			return major - other.major
		if minor != other.minor:
			return minor - other.minor
		return build - other.build
	
	func _as_ap_dict() -> Dictionary:
		return {"major":major,"minor":minor,"build":build,"class":"Version"}
class NetworkItem:
	var id: int
	var loc_id: int
	var src_player_id: int
	var dest_player_id: int
	var flags: int
	
	func get_classification() -> String:
		return AP.get_item_classification(flags)
	static func from(json: Dictionary, conn_info: ConnectionInfo, recv: bool) -> NetworkItem:
		if json["class"] != "NetworkItem":
			return null
		var v := NetworkItem.new()
		v.id = json["item"]
		v.loc_id = json["location"]
		v.src_player_id = json["player"] if recv else conn_info.player_id
		v.dest_player_id = conn_info.player_id if recv else json["player"]
		v.flags = json["flags"]
		return v
	
	func _to_string():
		return "ITEM(%d at %d,player %d->%d,flags %d)" % [id,loc_id,src_player_id,dest_player_id,flags]
	func output(console: CustomConsole, data: DataCache) -> void:
		AP.out_item(console, id, flags, data)
class NetworkPlayer:
	var team: int
	var slot: int
	var alias := ""
	var name : String
	
	var conn: ConnectionInfo
	func get_slot() -> NetworkSlot:
		return conn.slots[slot]
	func get_name(use_alias := true) -> String:
		var ret := ""
		if use_alias: ret = alias
		if not ret: ret = name
		return ret
	
	static func from(json: Dictionary, conn_info: ConnectionInfo) -> NetworkPlayer:
		if json["class"] != "NetworkPlayer":
			return null
		var v := NetworkPlayer.new()
		v.team = json["team"]
		v.slot = json["slot"]
		v.name = json["name"]
		if json.has("alias"):
			v.alias = json["alias"]
			if v.alias == v.name:
				v.alias = ""
		v.conn = conn_info
		return v
	
	func _to_string():
		return "PLAYER(%s[%s],team %d,slot %d)" % [name,alias,team,slot]
	func output(console: CustomConsole) -> void:
		AP.out_player(console, slot, conn)
class NetworkSlot:
	var name : String
	var game: String
	var type: int #spectator = 0x00, player = 0x01, group = 0x02
	var group_members: Array[int] = []
	
	static func from(json: Dictionary) -> NetworkSlot:
		if json["class"] != "NetworkSlot":
			return null
		var v := NetworkSlot.new()
		v.name = json["name"]
		v.game = json["game"]
		v.type = json["type"]
		v.group_members.assign(json["group_members"])
		return v
	
	func _to_string():
		return "SLOT(%s[%s],type %d,members %s)" % [name,game,type,group_members]

#endregion DATACLASSES

#region CONSOLE

static func out_item(console: CustomConsole, id: int, flags: int, data: DataCache):
	if not console: return
	var ttip = "Type: %s" % AP.get_item_classification(flags)
	var color := COLOR_ITEM
	if flags&ICLASS_PROG:
		color = COLOR_ITEM_PROG
	elif flags&ICLASS_TRAP:
		color = COLOR_ITEM_TRAP
	console.add_text(data.get_item_name(id), ttip, color)
static func out_player(console: CustomConsole, id: int, conn_info: ConnectionInfo):
	if not console: return
	var player := conn_info.get_player(id)
	var ttip = "Game: %s" % conn_info.get_slot(id).game
	if not player.alias.is_empty():
		ttip += "\nName: %s" % player.name
	console.add_text(conn_info.get_player_name(id), ttip, COLOR_PLAYER)
static func out_location(console: CustomConsole, id: int, data: DataCache):
	var ttip = ""
	console.add_text(data.get_loc_name(id), ttip, COLOR_LOCATION)

var output_console_window: ConsoleWindow = null
var output_console: CustomConsole = null
func _open_console() -> void:
	if output_console: return
	output_console_window = load("res://ui/console.tscn").instantiate()
	output_console_window.title = "Archipelago Console"
	add_child(output_console_window)
	await output_console_window.ready
	output_console = output_console_window.console
	output_console.send_text.connect(console_message)
	output_console.tree_exiting.connect(_close_console)
	output_console_window.typing_bar.autofill = autofill
func _close_console() -> void:
	if output_console:
		output_console.close()
		output_console = null

class ConsoleCommand:
	var text: String = ""
	var help_text: String = ""
	var call_proc: Variant = null # Callable[String->void] | null
	var autofill_proc: Variant = true # Callable[String->Array[String]] | bool
	func _init(txt: String):
		text = txt
	func set_call(caller: Callable) -> ConsoleCommand:
		call_proc = caller
		return self
	func set_autofill(caller: Variant) -> ConsoleCommand:
		assert(caller is bool or caller is Callable)
		autofill_proc = caller
		return self
	func set_help(helptxt: String) -> ConsoleCommand:
		help_text = helptxt
		return self
	
var console_commands: Array[ConsoleCommand] = []
func console_message(msg: String) -> void:
	if msg.is_empty(): return
	if msg[0] != "/": #Plain message
		send_command("Say", {"text":msg})
	else:
		var cmd = msg.split(" ", true, 1)[0].to_lower()
		var cmd_lower = cmd.to_lower()
		var found := false
		for command in console_commands:
			if command.text == cmd_lower:
				command.call_proc.call(msg)
				found = true
				break
		if not found:
			output_console.add_text("Unknown command '%s'\n" % cmd, "", COLOR_UI_MSG)
#endregion CONSOLE

var autofill: AutofillHandler = AutofillHandler.new()
func _init():
	_open_console()
	register_command(ConsoleCommand.new("/help").set_help("Displays this message").set_call(
		func(_msg: String):
			var s := ""
			for cmd in console_commands:
				if cmd.help_text:
					s += "%s\n    %s\n" % [cmd.text,cmd.help_text.replace("\n","\n    ")]
			output_console.add_text(s, "", COLOR_UI_MSG)))
	register_command(ConsoleCommand.new("/cls")
		.set_help("Clears the console")
		.set_call(func(_msg: String): output_console.clear()))
	register_command(ConsoleCommand.new("/clr_hist")
		.set_help("Clears the command history")
		.set_call(func(_msg: String): output_console_window.typing_bar.history_clear()))
	register_command(ConsoleCommand.new("/reconnect")
		.set_help("Refreshes the connection to the Archipelago server")
		.set_call(func(_msg: String): ap_reconnect()))
	register_command(ConsoleCommand.new("!hint_location").set_autofill(_autofill_locs))
	register_command(ConsoleCommand.new("!hint").set_autofill(_autofill_items))
	register_command(ConsoleCommand.new("!help").set_help("Displays server-based command help"))
	register_command(ConsoleCommand.new("!remaining"))
	register_command(ConsoleCommand.new("!missing"))
	register_command(ConsoleCommand.new("!checked"))
	register_command(ConsoleCommand.new("!collect"))
	register_command(ConsoleCommand.new("!release"))
	register_command(ConsoleCommand.new("!players"))
	if OS.is_debug_build():
		register_command(ConsoleCommand.new("/db_send")
			.set_help("Cheat-Collects the given location")
			.set_call(func(msg: String):
				var command_args = msg.split(" ", true, 1)
				if command_args.size() > 1 and command_args[1]:
					var data = AP.get_datacache(AP_GAME_NAME)
					for loc in _removed_locs:
						var loc_name := data.get_loc_name(loc)
						if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
							if _removed_locs[loc]:
								output_console.add_text("Location already sent!\n", "", COLOR_UI_MSG)
							else:
								output_console.add_text("Sending location '%s'!\n" % loc_name, "", COLOR_UI_MSG)
								collect_location(loc)
							return
					output_console.add_text("Location '%s' not found! Check spelling?\n" % command_args[1].strip_edges(), "", COLOR_UI_MSG)
				else: output_console.add_text("Usage: '/db_send Some Location Name'\n", "", COLOR_UI_MSG))
			.set_autofill(_autofill_locs))
		register_command(ConsoleCommand.new("/connect")
			.set_call(func(msg: String):
				var command_args = msg.split(" ", true, 3)
				if command_args.size() == 3:
					command_args.append("")
				if command_args.size() != 4:
					output_console.add_text("Usage: '/connect ip_address:port \"Slot Name\" [\"Password\"]'\n", "", COLOR_UI_MSG)
				else:
					var ipport = command_args[1].split(":",1)
					ap_connect(ipport[0],ipport[1],command_args[2],command_args[3])))
	
func register_command(cmd: ConsoleCommand) -> void:
	console_commands.append(cmd)
	autofill.commands[cmd.text] = cmd.autofill_proc
const ICLASS_PROG := 0b001
const ICLASS_USEFUL := 0b010
const ICLASS_TRAP := 0b100
static func get_item_classification(flags: int) -> String:
	match flags:
		0b001:
			return "Progression"
		0b010:
			return "Useful"
		0b100:
			return "Trap"
		0b000:
			return "Filler"
		_:
			var s := ""
			for q in 3:
				if flags & (1<<q):
					if s:
						s += ","
					s += get_item_classification(1<<q)
			return s

func _cmd_nil(_msg: String): pass
func _autofill_locs(msg: String) -> Array[String]:
	var args = msg.split(" ", true, 1)
	var data: DataCache = AP.get_datacache(AP_GAME_NAME)
	var locs: Array[String] = []
	locs.assign(data.location_name_to_id.keys())
	var ind := 0
	while ind < locs.size():
		var id: int = data.location_name_to_id[locs[ind]]
		if _removed_locs.get(id, true):
			locs.pop_at(ind)
		else: ind += 1
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < locs.size():
			if not locs[q].strip_edges().to_lower().begins_with(arg_str):
				locs.pop_at(q)
			else:
				q += 1
	for q in locs.size():
		locs[q] = "%s %s" % [args[0],locs[q]]
	return locs
func _autofill_items(msg: String) -> Array[String]:
	var args = msg.split(" ", true, 1)
	var data: DataCache = AP.get_datacache(AP_GAME_NAME)
	var itms: Array[String] = []
	itms.assign(data.item_name_to_id.keys())
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < itms.size():
			if not itms[q].strip_edges().to_lower().begins_with(arg_str):
				itms.pop_at(q)
			else:
				q += 1
	for q in itms.size():
		itms[q] = "%s %s" % [args[0],itms[q]]
	return itms

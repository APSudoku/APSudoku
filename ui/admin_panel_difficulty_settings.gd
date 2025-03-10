@tool class_name AdminPanelDifficultySettings extends VBoxContainer

signal update_values(values: Array[int], name: String)

@export var diffname: String :
	set(val):
		diffname = val
		if label:
			label.text = "%s Reward Weights" % val
@export_group("Nodes")
@export var label: Label
@export var spinboxes: Array[SpinBox]

var values: Array[int] = [0, 0, 0]

func _ready() -> void:
	label.text = "%s Reward Weights" % diffname

func set_value(value: int, indx: int) -> void:
	values[indx] = value
	update_values.emit(values, diffname)

func update_weights(weights: Dictionary) -> void:
	var vals: Array = weights.get(diffname, [])
	while vals.size() < spinboxes.size():
		vals.append(0)
	for q in spinboxes.size():
		spinboxes[q].set_value(vals[q])

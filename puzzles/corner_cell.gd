class_name CornerCell extends Cell

@export var party_particles: GPUParticles2D

func _ready() -> void:
	super()
	answer_filled.connect(answer_changed)

func answer_changed(val: int) -> void:
	if val == 3:
		var grect := get_global_rect()
		match index:
			0:
				party_particles.global_position = grect.position
				party_particles.rotation_degrees = 0
			8:
				party_particles.global_position.x = grect.end.x
				party_particles.global_position.y = grect.position.y
				party_particles.rotation_degrees = 90
			72:
				party_particles.global_position.x = grect.position.x
				party_particles.global_position.y = grect.end.y
				party_particles.rotation_degrees = -90
			80:
				party_particles.global_position = grect.end
				party_particles.rotation_degrees = 180
		party_particles.restart()
	else:
		party_particles.restart()
		party_particles.emitting = false

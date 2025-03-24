extends Node3D

const PLATFORM_SPEED = 2

@onready var player = $Wizard
@onready var platforms = $Platforms
@export var enemy: CharacterBody3D

func handle_platforms(delta):
	for platform in platforms.get_children():
		var player_height = player.global_transform.origin.y
		var collision_shape = platform.get_node("StaticBody3D/CollisionShape3D")
		if player_height > platform.global_transform.origin.y:
			collision_shape.disabled = false
		else:
			collision_shape.disabled = true
		if platform.has_meta("MoveDirection"):
			var current_move_direction = platform.get_meta("MoveDirection")
			platform.position.x += current_move_direction * PLATFORM_SPEED * delta
			if abs(platform.position.x) > 4:
				platform.set_meta("MoveDirection", current_move_direction * -1)
			
func _ready():
	if !Music.playing:
		Music.play()
	enemy.defeated.connect(func():
		player.victory()
		await get_tree().create_timer(4).timeout
		WorldManager.next_level())
	if enemy.has_signal("ultimate"):
		enemy.ultimate.connect(func(phase):
			if phase == 0:
				var tween = create_tween().set_parallel()
				for mesh in get_node("Room").get_children():
					tween.tween_property(mesh, "surface_material_override/0:albedo_color", Color(0, 0, 0), 1)
			elif phase == 1:
				player.rapidfire = true
				player.get_node("AttackCooldown").wait_time = 0.1
			elif phase == 2:
				var tween = create_tween().set_parallel()
				for mesh in get_node("Room").get_children():
					if mesh.name == "Back":
						tween.tween_property(mesh, "surface_material_override/0:albedo_color", Color(1, 0.5, 1), 1)
					else:
						tween.tween_property(mesh, "surface_material_override/0:albedo_color", Color(0.5, 0, 0.5), 1)
		)

func _process(delta):
	handle_platforms(delta)

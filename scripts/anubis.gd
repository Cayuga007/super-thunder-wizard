extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, SWING, RISE, BEAM, ULTIMATE, PILLARS}

const MAX_HEALTH = 500

var float_tween
var can_beam_damage = false
var current_action = IDLE
var health: int = MAX_HEALTH
var projectile_damage = 10
var pillar_damage = 15
var beam_damage = 20

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var attack_cooldown = $AttackCooldown
@export var target: CharacterBody3D
@export var tools: Node3D
@export var platform: MeshInstance3D

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Movement/transition_request", "Defeated")
		BEAM:
			animation_tree.set("parameters/Movement/transition_request", "Beam")
		PILLARS:
			animation_tree.set("parameters/Movement/transition_request", "Pillars")
		SWING:
			animation_tree.set("parameters/Swing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		RISE:
			animation_tree.set("parameters/Rise/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		ULTIMATE:
			animation_tree.set("parameters/Ultimate/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
func deal_damage(damage):
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
func take_damage(damage):
	health -= damage
	if health <= 0:
		animate(DEFEATED)
		current_action = DEFEATED
		defeated.emit()
		health = 0
		float_tween.stop()
	health_label.text = str(health)
	
func _ready():
	health_label.text = str(health)
	var armature = get_node("Armature")
	float_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(armature, "position:y", 0.5, 1)
	float_tween.tween_property(armature, "position:y", -0.5, 1)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 5)
		match random_attack:
			1:
				var move_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				move_tween.tween_property(self, "position:x", position.x * -1, 1)
				move_tween.tween_property(self, "rotation:y", rotation.y * -1, 1)
				move_tween.tween_property(platform, "position:x", platform.position.x * -1, 1)
			2:
				animate(SWING)
				var new_projectile = tools.get_node("Projectile").duplicate()
				get_tree().get_current_scene().add_child(new_projectile)
				new_projectile.position = position
				var projectile_tween = create_tween()
				projectile_tween.tween_property(new_projectile, "position", target.position, 1)
				projectile_tween.tween_property(new_projectile, "scale", new_projectile.scale * 3, 0.15)
				projectile_tween.step_finished.connect(func(step):
					if new_projectile.get_overlapping_bodies().has(target):
						deal_damage(projectile_damage))
				await projectile_tween.finished
				new_projectile.queue_free()
			3:
				animate(RISE)
				await get_tree().create_timer(1).timeout
				var new_pillar = tools.get_node("Pillar").duplicate()
				get_tree().get_current_scene().add_child(new_pillar)
				var can_damage = true
				new_pillar.body_entered.connect(func(body):
					if body == target and can_damage:
						can_damage = false
						deal_damage(pillar_damage))
				var tween = create_tween()
				tween.tween_property(new_pillar, "position:y", 3, 0.5)
				tween.tween_interval(1)
				tween.finished.connect(func():
					new_pillar.get_node("MeshInstance3D").visible = false
					new_pillar.get_node("CollisionShape3D").disabled = true
					var projectile_tween = create_tween().set_parallel()
					for path in new_pillar.get_node("Paths").get_children():
						var path_follow = path.get_node("PathFollow3D")
						var projectile = path_follow.get_node("Projectile")
						projectile_tween.tween_property(path_follow, "progress_ratio", 1, 1.5)
						var projectile_can_damage = true
						projectile.body_entered.connect(func(body):
							if body == target and projectile_can_damage:
								projectile_can_damage = false
								deal_damage(projectile_damage)))
				await get_tree().create_timer(3).timeout
				new_pillar.queue_free()
			4:
				animate(BEAM)
				current_action = BEAM
				var beam = get_node("Beam")
				var collision_shape = beam.get_node("CollisionShape3D")
				var mesh = beam.get_node("MeshInstance3D")
				can_beam_damage = true
				collision_shape.shape.height = 0.5
				mesh.mesh.height = 0.5
				var tween = create_tween()
				tween.tween_interval(1.5)
				tween.tween_property(collision_shape, "shape:height", 12, 1.5)
				tween.parallel().tween_property(mesh, "mesh:height", 12, 1.5)
				tween.tween_property(mesh, "transparency", 1, 0.25)
				tween.step_finished.connect(func(step):
					if step == 0:
						mesh.transparency = 0
					if step == 1:
						can_beam_damage = false)
				await tween.finished
			5:
				current_action = ULTIMATE
				var original_transform = transform
				var center_transform = tools.get_node("Center").transform
				var tween = create_tween().set_trans(Tween.TRANS_SINE)
				tween.tween_property(self, "position", position + Vector3(0, 10, 0), 1).set_ease(Tween.EASE_IN)
				tween.tween_property(self, "transform", center_transform, 1).set_ease(Tween.EASE_OUT)
				tween.tween_interval(6)
				tween.tween_property(self, "position", center_transform.origin + Vector3(0, 10, 0), 1).set_ease(Tween.EASE_IN)
				tween.tween_property(self, "transform", original_transform, 1).set_ease(Tween.EASE_OUT)
				tween.step_finished.connect(func(step):
					if step == 0:
						transform = center_transform
						position += Vector3(0, 5, 0)
						animate(ULTIMATE)
						animate(PILLARS)
						var pillars = tools.get_node("Pillars")
						var pillars_tween = create_tween()
						pillars_tween.tween_property(pillars, "position", Vector3(0, 0, 0), 1)
						pillars_tween.tween_property(pillars, "position", Vector3(0, 4, 0), 0.2).set_delay(1)
						pillars_tween.tween_property(pillars, "position", Vector3(0, -1, 0), 0.5).set_delay(1)
						pillars_tween.tween_property(pillars, "position", Vector3(1, 0, 0), 1)
						pillars_tween.tween_property(pillars, "position", Vector3(1, 4, 0), 0.2).set_delay(1)
						pillars_tween.tween_property(pillars, "position", Vector3(1, -1, 0), 0.5).set_delay(1)
						pillars_tween.step_finished.connect(func(step):
							if step == 1 or step == 4:
								for pillar in pillars.get_children():
									if pillar.get_overlapping_bodies().has(target):
										deal_damage(pillar_damage)
							if step == 2:
								pillars.position.x += 1)
						pillars_tween.finished.connect(func():
							pillars.position = Vector3(0, -1, 0))
					if step == 2:
						animate(IDLE)
					if step == 3:
						transform = original_transform
						position += Vector3(0, 5, 0)
					)
				await tween.finished
		animate(IDLE)
		current_action = IDLE
		float_tween.play()
		attack_cooldown.start())

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
			if position.y > 0:
				position.y -= 2 * delta
			elif position.y < 0:
				position.y = 0
		BEAM:
			if can_beam_damage and get_node("Beam").get_overlapping_bodies().has(target):
				can_beam_damage = false
				deal_damage(beam_damage)

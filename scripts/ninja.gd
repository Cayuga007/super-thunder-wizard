extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, SHURIKEN, JUMP, FALL}

const MAX_HEALTH = 300

var can_fall_damage = false
var current_action = IDLE
var health: int = MAX_HEALTH
var shuriken_damage = 15
var fall_damage = 20
var shuriken = preload("res://scenes/shuriken.tscn")

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var attack_cooldown = $AttackCooldown
@export var target: CharacterBody3D
@export var leap_path: Path3D

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Movement/transition_request", "Defeated")
		JUMP:
			animation_tree.set("parameters/Movement/transition_request", "Jump")
		FALL:
			animation_tree.set("parameters/Movement/transition_request", "Fall")
		SHURIKEN:
			animation_tree.set("parameters/Shuriken/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
	health_label.text = str(health)
	
func _ready():
	health_label.text = str(health)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 3)
		match random_attack:
			1:
				animate(JUMP)
				current_action = JUMP
				var leap_follow = leap_path.get_node("PathFollow3D")
				var tween = create_tween()
				tween.tween_property(leap_follow, "progress_ratio", abs(leap_follow.progress_ratio - 1), 1)
				tween.parallel().tween_property(self, "rotation:y", rotation.y + PI, 1)
				var shuriken_follow = get_node("ShurikenPath/PathFollow3D")
				tween.tween_property(shuriken_follow, "progress_ratio", 1, 0.75)
				var new_shuriken = shuriken.instantiate()
				tween.step_finished.connect(func(step):
					if step == 1: return
					animate(SHURIKEN)
					shuriken_follow.add_child(new_shuriken)
					new_shuriken.position = Vector3.ZERO
					new_shuriken.rotation.y = 0
					new_shuriken.body_entered.connect(func(body):
						if body == target:
							deal_damage(shuriken_damage)))
				await tween.finished
				shuriken_follow.progress_ratio = 0
				new_shuriken.queue_free()
			2:
				animate(SHURIKEN)
				var new_shuriken = shuriken.instantiate()
				get_tree().get_current_scene().add_child(new_shuriken)
				new_shuriken.body_entered.connect(func(body):
					if body == target:
						deal_damage(shuriken_damage))
				new_shuriken.position = position + Vector3(0, 1, 0)
				var goal = (target.position - position).normalized() * 10 + Vector3(0, 1, 0) + position
				var tween = create_tween().set_parallel()
				tween.tween_property(new_shuriken, "position", goal, 1)
				tween.tween_property(new_shuriken, "rotation:x", 2 * PI, 1)
				tween.finished.connect(func():
					new_shuriken.queue_free())
			3:
				current_action = FALL
				animate(JUMP)
				var opposite_position = position * -1
				var tween = create_tween()
				tween.tween_property(self, "position:y", 8, 1)
				tween.tween_property(self, "position", opposite_position, 2)
				tween.step_finished.connect(func(step):
					animate(FALL)
					if step == 0:
						position.x += position.x / abs(position.x) * 4
						can_fall_damage = true
					elif step == 1:
						position = opposite_position
						rotation.y += PI
						var leap_follow = leap_path.get_node("PathFollow3D")
						leap_follow.progress_ratio = abs(leap_follow.progress_ratio - 1))
				await tween.finished
		current_action = IDLE
		attack_cooldown.start()
	)

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
		JUMP:
			position = leap_path.get_node("PathFollow3D").position
		FALL:
			if get_node("Hitbox").get_overlapping_bodies().has(target) and can_fall_damage:
				can_fall_damage = false
				deal_damage(fall_damage)

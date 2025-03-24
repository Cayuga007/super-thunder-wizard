extends CharacterBody3D

signal defeated
signal ultimate(phase)
signal big_defeated

enum {IDLE, DEFEATED, DOWN, FIREWHEEL, EXPLODE, GIANT, BLAST, ULTIMATE, ULTIMATE_BIG}

const MAX_HEALTH = 500

var ultimate_phase = false
var can_blast_damage = false
var current_action = IDLE
var health: int = MAX_HEALTH
var fireball_damage = 15
var explode_damage = 30
var giant_damage = 25
var blast_damage = 25
var fireball = preload("res://scenes/fireball.tscn")

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var attack_cooldown = $AttackCooldown
@export var target: CharacterBody3D
@export var tools: Node3D

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Movement/transition_request", "Defeated")
		DOWN:
			animation_tree.set("parameters/Movement/transition_request", "Down")
		BLAST:
			animation_tree.set("parameters/Movement/transition_request", "Blast")
		FIREWHEEL:
			animation_tree.set("parameters/Firewheel/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		EXPLODE:
			animation_tree.set("parameters/Explode/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		GIANT:
			animation_tree.set("parameters/Giant/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
func do_ultimate():
	ultimate.emit(0)
	visible = false
	animate(DOWN)
	var hat = tools.get_node("Hat")
	hat.visible = true
	await hat.body_entered
	hat.visible = false
	current_action = ULTIMATE_BIG
	ultimate.emit(1)
	await big_defeated
	visible = true
	position = Vector3.ZERO
	ultimate_phase = false
	ultimate.emit(2)

func deal_damage(damage):
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
func take_damage(damage):
	if ultimate_phase: return
	if health == 1:
		animate(DEFEATED)
		health = 0
		current_action = DEFEATED
		defeated.emit()
	else:
		health -= damage
		if health <= 1:
			health = 1
			ultimate_phase = true
			attack_cooldown.stop()
			animate(EXPLODE)
			current_action = ULTIMATE
			do_ultimate()
	health_label.text = str(health)
	
func _ready():
	health_label.text = str(health)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 4)
		match random_attack:
			1:
				animate(FIREWHEEL)
				var tween = create_tween().set_parallel()
				for i in 12:
					var new_fireball = fireball.instantiate()
					get_tree().current_scene.add_child(new_fireball)
					new_fireball.transform = transform
					new_fireball.rotate_z(PI / 6 * i)
					new_fireball.body_entered.connect(func(body):
						if body == target:
							deal_damage(fireball_damage)
						new_fireball.queue_free())
					tween.tween_property(new_fireball, "position", new_fireball.global_transform.basis.y * 25 + position, 2)
			2:
				animate(EXPLODE)
				current_action = EXPLODE
				var goal = target.position
				goal.y = 2.5
				var tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(self, "position", goal, 1.25)
				tween.tween_property(self, "rotation:y", 0, 1.25)
				await tween.finished
				var hitbox = get_node("Hitbox")
				hitbox.visible = true
				if hitbox.get_overlapping_bodies().has(target):
					deal_damage(explode_damage)
				await get_tree().create_timer(1).timeout
				hitbox.visible = false
				var return_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				if target.position.x > position.x:
					return_tween.tween_property(self, "rotation:y", PI/2, 0.5)
				elif target.position.x < position.x:
					return_tween.tween_property(self, "rotation:y", -PI/2, 0.5)
			3:
				current_action = BLAST
				var pos_x = 11
				var rot_y = -PI/2
				if randi_range(0, 1):
					pos_x = -11
					rot_y = PI/2
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_parallel()
				tween.tween_property(self, "position:x", pos_x, 1)
				tween.chain().tween_property(self, "rotation:y", rot_y, 1)
				tween.chain().tween_interval(1)
				var blast = get_node("Blast")
				var collision_shape = blast.get_node("CollisionShape3D")
				var mesh = blast.get_node("MeshInstance3D")
				tween.tween_property(collision_shape, "shape:height", 20, 2)
				tween.tween_property(collision_shape, "position:z", 10, 2)
				tween.tween_property(mesh, "mesh:height", 20, 2)
				tween.tween_property(mesh, "position:z", 10, 2)
				tween.step_finished.connect(func(step):
					if step == 0:
						animate(BLAST)
					elif step == 1:
						blast.visible = true
						can_blast_damage = true)
				await tween.finished
				collision_shape.shape.height = 0
				collision_shape.position.z = 0
				mesh.mesh.height = 0
				mesh.position.z = 0
				blast.visible = false
			4:
				current_action = GIANT
				animate(GIANT)
				var pos_goal = target.position
				pos_goal.y = 0
				var rot_goal = -PI/2
				if target.position.x > position.x:
					rot_goal = PI/2
				var tween = create_tween()
				tween.tween_property(self, "position", pos_goal, 1)
				tween.parallel().tween_property(self, "rotation:y", rot_goal, 1)
				tween.parallel().tween_property(self, "scale", scale * 2, 1)
				tween.tween_interval(1.5)
				tween.tween_interval(1)
				tween.tween_property(self, "scale", Vector3.ONE, 1)
				tween.parallel().tween_property(self, "position:y", 2.5, 1)
				tween.step_finished.connect(func(step):
					if step == 1 and get_node("Hitbox").get_overlapping_bodies().has(target):
						deal_damage(giant_damage))
				await tween.finished
		if ultimate_phase: return
		current_action = IDLE
		attack_cooldown.start())

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
		BLAST:
			if can_blast_damage and get_node("Blast").get_overlapping_bodies().has(target):
				can_blast_damage = false
				deal_damage(blast_damage)
		ULTIMATE_BIG:
			var demon_big = tools.get_node("DemonBig")
			demon_big.position.x -= delta
			if demon_big.position.x <= -10:
				deal_damage(100)
			if demon_big.get_meta("Health") <= 0:
				demon_big.queue_free()
				current_action = ULTIMATE
				big_defeated.emit()
			if (target.position - demon_big.position - Vector3(0, 20, 0)).length() <= 1:
				deal_damage(5)
				

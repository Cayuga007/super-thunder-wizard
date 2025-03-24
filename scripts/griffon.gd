extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, READY, LUNGE, RISE, SLASH}

const MAX_HEALTH = 400

var can_damage = false
var can_lunge_damage = false
var current_action = IDLE
var health: int = MAX_HEALTH
var lunge_damage = 15

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var attack_cooldown = $AttackCooldown
@export var target: CharacterBody3D

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Movement/transition_request", "Defeated")
		READY:
			animation_tree.set("parameters/Movement/transition_request", "Ready")
		LUNGE:
			animation_tree.set("parameters/Movement/transition_request", "Lunge")
		RISE:
			animation_tree.set("parameters/Movement/transition_request", "Rise")
		SLASH:
			animation_tree.set("parameters/Slash/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
	
func hitbox():
	var hit = get_node("Hitbox").get_overlapping_bodies()
	if hit.has(target):
		deal_damage(lunge_damage)
		can_lunge_damage = false
	
func _ready():
	health_label.text = str(health)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 3)
		match random_attack:
			1:
				animate(READY)
				current_action = READY
				await get_tree().create_timer(1).timeout
				current_action = LUNGE
				can_lunge_damage = true
				var original_position = position
				var lunge_tween = create_tween().set_loops(2)
				lunge_tween.tween_interval(1)
				lunge_tween.tween_property(self, "position", target.position, 0.5)
				lunge_tween.tween_property(self, "position", original_position, 0.5)
				lunge_tween.step_finished.connect(func(step):
					if step == 0:
						animate(LUNGE)
						can_lunge_damage = true
					elif step == 1:
						animate(READY))
				lunge_tween.finished.connect(func():
					animate(IDLE)
					current_action = IDLE
					attack_cooldown.start())
			2:
				animate(SLASH)
				await get_tree().create_timer(1.5).timeout
				can_damage = true
				var path_follow = get_node("StraightPath/PathFollow3D")
				var gale = path_follow.get_node("Gale")
				gale.visible = true
				var path_tween = create_tween()
				path_tween.tween_property(path_follow, "progress_ratio", 1, 1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				path_tween.tween_interval(1)
				path_tween.tween_property(path_follow, "progress_ratio", 0, 1).set_trans(Tween.TRANS_SINE)
				var spin_tween = create_tween()
				spin_tween.tween_property(gale, "rotation:x", 16 * PI, 3)
				path_tween.finished.connect(func():
					gale.visible = false
					can_damage = false
					current_action = IDLE
					attack_cooldown.start())
				path_tween.step_finished.connect(func(step):
					if step == 1:
						can_damage = true)
				spin_tween.finished.connect(func():
					gale.rotation.x = 0)
				gale.body_entered.connect(func(body):
					if body == target and can_damage:
						deal_damage(10)
						can_damage = false)
			3:
				animate(READY)
				current_action = RISE
				var new_position = position * -1
				var fly_tween = create_tween()
				fly_tween.tween_interval(0.5)
				fly_tween.tween_property(self, "position", position + Vector3(0, 5, 0), 1)
				fly_tween.tween_interval(0.5)
				fly_tween.tween_property(self, "position", new_position, 1)
				fly_tween.tween_property(self, "rotation:y", rotation.y + PI, 0.5)
				fly_tween.step_finished.connect(func(step):
					if step == 0:
						animate(RISE)
					elif step == 1:
						animate(READY)
					elif step == 2:
						animate(LUNGE)
						current_action = LUNGE
						can_lunge_damage = true
						var gale = get_node("Gale")
						gale.reparent(get_tree().get_current_scene())
						gale.global_position = position
						gale.visible = true
						var target_position = target.global_position
						target_position.y = -1
						var gale_tween = create_tween().set_parallel()
						gale_tween.tween_property(gale, "position", target_position, 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
						gale_tween.tween_property(gale, "rotation:x", 8 * PI, 2)
						gale_tween.finished.connect(func():
							gale.visible = false
							can_damage = false
							gale.reparent(self)
							gale.position = Vector3.ZERO
							gale.rotation = Vector3(0, 0, PI/2))
						gale.body_entered.connect(func(body):
							if body == target and can_damage:
								deal_damage(10)
								can_damage = false)
					elif step == 3:
						current_action = IDLE
						attack_cooldown.start())
		)

func _physics_process(_delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
		LUNGE:
			if can_lunge_damage:
				hitbox()

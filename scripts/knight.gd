extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, JUMP, DASH_READY, DASH_ATTACK, GROUND, SLASH, COUNTER}

const MAX_HEALTH = 400

var lava
var hitbox
var current_action = IDLE
var health: int = MAX_HEALTH
var ground_damage = 10
var counter_damage = 10
var slash_damage = 20
var dash_damage = 15
var lava_t = 0.0

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
		COUNTER:
			animation_tree.set("parameters/Movement/transition_request", "Counter")
		JUMP:
			animation_tree.set("parameters/Movement/transition_request", "Jump")
		DASH_READY:
			animation_tree.set("parameters/Movement/transition_request", "DashReady")
		DASH_ATTACK:
			animation_tree.set("parameters/Movement/transition_request", "DashAttack")
		GROUND:
			animation_tree.set("parameters/Ground/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
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
	
func counter():
	deal_damage(counter_damage)
	if !hitbox.get_overlapping_bodies().has(target):
		current_action = IDLE
		attack_cooldown.start()
	
func _ready():
	health_label.text = str(health)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 2)
		match random_attack:
			1:
				animate(JUMP)
				current_action = JUMP
				var follow = tools.get_node("AttackJump/PathFollow3D")
				var end_ratio = abs(follow.progress_ratio - 1)
				var tween = create_tween()
				tween.tween_property(follow, "progress_ratio", 0.5, 1)
				tween.tween_property(follow, "progress_ratio", end_ratio, 1).set_delay(0.5)
				tween.tween_property(self, "rotation:y", rotation.y + PI, 0.5)
				tween.step_finished.connect(func(step):
					if step == 0 or step == 1:
						animate(SLASH)
						if hitbox.get_overlapping_bodies().has(target):
							deal_damage(slash_damage))
				await tween.finished
			2:
				animate(DASH_READY)
				current_action = DASH_READY
				await get_tree().create_timer(1.5).timeout
				var tween = create_tween()
				tween.tween_property(self, "position:x", position.x * -1, 0.1)
				tween.tween_interval(0.5)
				tween.tween_property(self, "rotation:y", rotation.y + PI, 0.5)
				tween.step_finished.connect(func(step):
					if step == 0:
						animate(DASH_ATTACK)
						if tools.get_node("DashHitbox").get_overlapping_bodies().has(target):
							deal_damage(dash_damage)
					elif step == 1:
						animate(IDLE))
				await tween.finished
		current_action = IDLE
		attack_cooldown.start()
	)
	lava = tools.get_node("Lava")
	hitbox = get_node("Hitbox")
	animate(GROUND)
	await get_tree().create_timer(2).timeout
	current_action = GROUND
	var tween = create_tween().set_parallel()
	tween.tween_property(tools.get_node("InitialJump/PathFollow3D"), "progress_ratio", 1, 1.25)
	tween.tween_property(lava, "position:y", 0, 0.5)
	await tween.finished
	current_action = IDLE
	attack_cooldown.start()

func _physics_process(delta):
	lava_t += delta
	if lava_t >= 1.0 and lava.get_overlapping_bodies().has(target):
		lava_t = 0.0
		deal_damage(ground_damage)
	match current_action:
		IDLE:
			animate(IDLE)
			if hitbox.get_overlapping_bodies().has(target):
				current_action = COUNTER
				attack_cooldown.stop()
		DEFEATED:
			animate(DEFEATED)
		GROUND:
			position = tools.get_node("InitialJump/PathFollow3D").position
		COUNTER:
			animate(COUNTER)
		JUMP:
			position = tools.get_node("AttackJump/PathFollow3D").position
				

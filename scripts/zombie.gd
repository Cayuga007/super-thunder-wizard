extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, JUMP, FALL, PUNCH, PUNCH_JUMP}

const MAX_HEALTH = 400
const JUMP_DAMAGE = 5
const FALL_DAMAGE = 10
const PUNCH_DAMAGE = 5
const ATTACK_DISTANCE = 2
const PUNCH_JUMP_DURATION = 1

var p0
var p1
var p2
var t = 0
var current_action = IDLE
var health: int = MAX_HEALTH
var damage_accumulated: float = 0.0

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var attack_cooldown = $AttackCooldown
@export var target: CharacterBody3D
@export var jump_spots: Node3D
@export var run_spots: Node3D
@export var punch_hitbox: Area3D

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
		PUNCH:
			animation_tree.set("parameters/Punch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
		var random_attack = randi_range(1, 2)
		match random_attack:
			1:
				animate(JUMP)
				current_action = JUMP
				var jump_spot = jump_spots.get_children()[randi_range(0, 2)]
				var jump_tween = create_tween()
				jump_tween.tween_property(self, "position", jump_spot.position, 1)
				if jump_spot.position.x < position.x:
					rotation.y = -PI/2
				elif jump_spot.position.x > position.x:
					rotation.y = PI/2
				else:
					rotation.y = 0
				await jump_tween.finished
				await get_tree().create_timer(0.5).timeout
				animate(FALL)
				current_action = FALL
				var fall_tween = create_tween()
				fall_tween.tween_property(self, "position", jump_spot.get_node("Land").global_position, 0.25)
				await fall_tween.finished
				var distance_to_player = (target.global_transform.origin - global_transform.origin).length()
				if distance_to_player <= ATTACK_DISTANCE:
					deal_damage(FALL_DAMAGE + randi_range(-5, 5))
				current_action = IDLE
				attack_cooldown.start()
			2:
				animate(JUMP)
				current_action = PUNCH_JUMP
				var run_spot = run_spots.get_children()[randi_range(0, 1)]
				p0 = position
				p1 = run_spot.position + Vector3(0, 5, 0)
				p2 = run_spot.position
				if run_spot.position.x < position.x:
					rotation.y = PI/2
				elif run_spot.position.x > position.x:
					rotation.y = -PI/2
		)

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
		JUMP:
			var distance_to_player = (target.global_transform.origin - global_transform.origin).length()
			if distance_to_player <= ATTACK_DISTANCE:
				damage_accumulated += delta
				if damage_accumulated >= 0.1:
					deal_damage(JUMP_DAMAGE)
					damage_accumulated = 0.0
		PUNCH_JUMP:
			t += delta / PUNCH_JUMP_DURATION
			position = p1 + pow(1-t, 2) * (p0 - p1) + pow(t, 2) * (p2 - p1)
			if t >= 1.0:
				animate(PUNCH)
				t = 0.0
				current_action = PUNCH
		PUNCH:
			animate(IDLE)
			current_action = IDLE
			await get_tree().create_timer(0.5).timeout
			if target.position.y < 1:
				deal_damage(PUNCH_DAMAGE)
			await get_tree().create_timer(1).timeout
			if target.position.y < 1:
				deal_damage(PUNCH_DAMAGE)
			attack_cooldown.start()

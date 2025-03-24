extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, JUMP, TAILWHIP, DIG}

const MAX_HEALTH = 300
const ATTACK_DISTANCE = 2
const JUMP_TIME = 1.5

var p0
var p1
var p2
var t = 0
var second_jump = false
var current_action = IDLE
var health: int = MAX_HEALTH
var tailwhip_damage = 15

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
		JUMP:
			animation_tree.set("parameters/Movement/transition_request", "Jump")
		TAILWHIP:
			animation_tree.set("parameters/Tailwhip/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
		deal_damage(tailwhip_damage)
	
func _ready():
	health_label.text = str(health)
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		animate(JUMP)
		if position.x > target.position.x:
			rotation.y = -PI/2
		elif position.x < target.position.x:
			rotation.y = PI/2
		p0 = position
		var random_attack = randi_range(1, 2)
		match random_attack:
			1:
				current_action = JUMP
				p1 = lerp(position, target.position, 0.5) + Vector3(0, 2.5, 0)
				p2 = target.position
			2:
				current_action = DIG
				p1 = position + Vector3(0, 2.5, 0)
				p2 = position + Vector3(0, -5, 0)
		)

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
			if position.y > 0:
				position.y -= 2 * delta
			elif position.y < 0:
				position.y = 0
		DEFEATED:
			animate(DEFEATED)
		JUMP:
			t += delta / JUMP_TIME
			position = p1 + pow(1-t, 2) * (p0 - p1) + pow(t, 2) * (p2 - p1)
			if t >= 1.0:
				animate(TAILWHIP)
				hitbox()
				t = 0.0
				current_action = IDLE
				attack_cooldown.start()
		DIG:
			t += delta / JUMP_TIME
			position = p1 + pow(1-t, 2) * (p0 - p1) + pow(t, 2) * (p2 - p1)
			if t >= 1.0:
				t = 0.0
				if not second_jump:
					position = target.position
					position.y = -5
					p0 = position
					p1 = position + Vector3(0, 7.5, 0)
					p2 = position + Vector3(0, 5, 0)
					second_jump = true
				else:
					animate(TAILWHIP)
					hitbox()
					current_action = IDLE
					second_jump = false
					attack_cooldown.start()

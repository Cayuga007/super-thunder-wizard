extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, FLY, BITE}

const MAX_HEALTH = 300
const DAMAGE = 10
const ATTACK_DISTANCE = 2
const SPEED = 5

var current_action = IDLE
var health: int = MAX_HEALTH
var direction: Vector3
var player_origin: Vector3

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
		FLY:
			animation_tree.set("parameters/Movement/transition_request", "Fly")
		BITE:
			animation_tree.set("parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
	get_node("AttackCooldown").timeout.connect(func():
		if current_action == DEFEATED: return
		current_action = FLY
		player_origin = target.global_transform.origin + Vector3(0, 1, 0)
		direction = (player_origin - global_transform.origin).normalized())

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
			look_at(target.position, Vector3.UP)
		DEFEATED:
			animate(DEFEATED)
		FLY:
			animate(FLY)
			position += direction * SPEED * delta
			var distance_to_origin = (player_origin - global_transform.origin).length()
			if distance_to_origin <= 0.5:
				var distance_to_player = (target.global_transform.origin - global_transform.origin).length()
				if distance_to_player <= ATTACK_DISTANCE:
					deal_damage(DAMAGE)
				animate(BITE)
				current_action = IDLE
				attack_cooldown.start()

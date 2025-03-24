extends CharacterBody3D

signal defeated

enum {IDLE, DEFEATED, FLY, FIRE, FIREBALLS, RISE, SOAR, FLAMETHROWER}

const MAX_HEALTH = 500
const FLAMETHROWER_DAMAGE = 10
const FIREBALL_DAMAGE = 5
const SOAR_DAMAGE = 20
const ATTACK_DISTANCE = 2

var space_state
var can_damage = false
var right_side = true
var current_action = IDLE
var fireball_t = 0.0
var damage_accumulated = 0.0
var health: int = MAX_HEALTH
var fireball = preload("res://scenes/fireball.tscn")

@onready var animation_tree = $AnimationTree
@onready var health_label = $HealthLabel
@onready var ray_cast_start = $RayCastStart
@onready var attack_cooldown = $AttackCooldown
@export var idle_spots: Node3D
@export var outside_spots: Node3D
@export var flamethrower_spots: Node3D
@export var fireballs: Node3D
@export var ray_cast_target: Node3D
@export var target: CharacterBody3D
@export var laser: MeshInstance3D

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Movement/transition_request", "Defeated")
		FLY:
			animation_tree.set("parameters/Movement/transition_request", "Fly")
		SOAR:
			animation_tree.set("parameters/Movement/transition_request", "Soar")
		FIRE:
			animation_tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		RISE:
			animation_tree.set("parameters/Rise/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
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
	space_state = get_world_3d().direct_space_state
	attack_cooldown.timeout.connect(func():
		if current_action == DEFEATED: return
		var random_attack = randi_range(1, 3)
		match random_attack:
			1:
				animate(FIRE)
				current_action = FIRE
				await get_tree().create_timer(2).timeout
				for n in 3:
					var new_fireball = fireball.instantiate()
					fireballs.add_child(new_fireball)
					new_fireball.position = position + Vector3(0, 3, 0)
					if right_side:
						new_fireball.position.x -= 1
					else:
						new_fireball.position.x += 1
					var launch_tween = create_tween()
					launch_tween.tween_property(new_fireball, "position", Vector3(0, 15, 0), 1)
					await get_tree().create_timer(0.4).timeout
				current_action = FIREBALLS
				await get_tree().create_timer(5).timeout
				current_action = IDLE
				attack_cooldown.start()
				await get_tree().create_timer(2).timeout
				for finished_fireball in fireballs.get_children():
					finished_fireball.queue_free()
			2:
				animate(RISE)
				current_action = RISE
				await get_tree().create_timer(2).timeout
				var rise_tween = create_tween()
				rise_tween.tween_property(self, "position", position + Vector3(0, 50, 0), 1.5)
				await rise_tween.finished
				animate(SOAR)
				current_action = SOAR
				can_damage = true
				var outside_start
				var outside_end
				var idle_end
				if right_side:
					outside_start = outside_spots.get_node("Right")
					outside_end = outside_spots.get_node("Left")
					idle_end = idle_spots.get_node("Left")
				else:
					outside_start = outside_spots.get_node("Left")
					outside_end = outside_spots.get_node("Right")
					idle_end = idle_spots.get_node("Right")
				position = outside_start.position
				var soar_tween = create_tween()
				soar_tween.tween_property(self, "position", outside_end.position, 2)
				await soar_tween.finished
				animate(FLY)
				right_side = not right_side
				rotation.y -= PI
				position = idle_end.position + Vector3(0, 15, 0)
				var fly_down_tween = create_tween()
				fly_down_tween.tween_property(self, "position", idle_end.position, 3)
				await fly_down_tween.finished
				current_action = IDLE
				can_damage = false
				attack_cooldown.start()
			3:
				animate(FLY)
				current_action = FLY
				var fly_tween = create_tween()
				fly_tween.tween_property(self, "position", position + Vector3(0, 4, 0), 1)
				await fly_tween.finished
				current_action = FLAMETHROWER
				laser.visible = true
				var first
				var second
				if right_side:
					first = idle_spots.get_node("Left")
					second = idle_spots.get_node("Right")
				else:
					first = idle_spots.get_node("Right")
					second = idle_spots.get_node("Left")
				ray_cast_target.position = first.get_node("Start").global_position
				var first_flamethrower_tween = create_tween()
				first_flamethrower_tween.tween_property(ray_cast_target, "position", second.global_position, 1)
				await first_flamethrower_tween.finished
				current_action = FLY
				laser.visible = false
				await get_tree().create_timer(1).timeout
				current_action = FLAMETHROWER
				laser.visible = true
				ray_cast_target.position = second.get_node("Start").global_position
				var second_flamethrower_tween = create_tween()
				second_flamethrower_tween.tween_property(ray_cast_target, "position", first.global_position, 1)
				await second_flamethrower_tween.finished
				current_action = FLY
				laser.visible = false
				var land_tween = create_tween()
				land_tween.tween_property(self, "position", position - Vector3(0, 4, 0), 1)
				await land_tween.finished
				current_action = IDLE
				attack_cooldown.start()
		)

func _physics_process(delta):
	match current_action:
		IDLE:
			animate(IDLE)
		DEFEATED:
			animate(DEFEATED)
		FIREBALLS:
			fireball_t += delta
			if fireball_t >= 0.25:
				fireball_t = 0.0
				var new_fireball = fireball.instantiate()
				fireballs.add_child(new_fireball)
				new_fireball.position = Vector3(randi_range(-6, 6), 15, 0)
				var launch_tween = create_tween()
				launch_tween.tween_property(new_fireball, "position", new_fireball.position - Vector3(0, 20, 0), 2)
				new_fireball.body_entered.connect(func(body):
					if body == target:
						deal_damage(FIREBALL_DAMAGE)
						new_fireball.queue_free())
		SOAR:
			var distance_to_player = (target.global_transform.origin - global_transform.origin).length()
			if distance_to_player <= ATTACK_DISTANCE and can_damage:
				can_damage = false
				deal_damage(SOAR_DAMAGE)
		FLAMETHROWER:
			var query = PhysicsRayQueryParameters3D.create(ray_cast_start.global_position, ray_cast_target.global_position)
			var between = lerp(ray_cast_start.global_position, ray_cast_target.position, 0.5)
			laser.position = between
			laser.look_at(ray_cast_start.global_position + Vector3(0, 0, 0.1), Vector3.UP)
			laser.rotation.x += PI/2
			laser.scale.y = (ray_cast_start.global_position - ray_cast_target.global_position).length() / 2
			var result = space_state.intersect_ray(query)
			if result and result.collider == target:
				damage_accumulated += delta
				if damage_accumulated >= 0.1:
					deal_damage(FLAMETHROWER_DAMAGE)
					damage_accumulated = 0.0

func _on_attack_cooldown_timeout():
	if current_action == DEFEATED: return
	var random_attack = randi_range(1, 3)
	match random_attack:
		1:
			animate(FIRE)
			current_action = FIRE
			await get_tree().create_timer(2).timeout
			for n in 3:
				var new_fireball = fireball.instantiate()
				fireballs.add_child(new_fireball)
				new_fireball.position = position + Vector3(0, 3, 0)
				if right_side:
					new_fireball.position.x -= 1
				else:
					new_fireball.position.x += 1
				var launch_tween = create_tween()
				launch_tween.tween_property(new_fireball, "position", Vector3(0, 15, 0), 1)
				await get_tree().create_timer(0.4).timeout
			current_action = FIREBALLS
			await get_tree().create_timer(5).timeout
			current_action = IDLE
			attack_cooldown.start()
			await get_tree().create_timer(2).timeout
			for finished_fireball in fireballs.get_children():
				finished_fireball.queue_free()
		2:
			animate(RISE)
			current_action = RISE
			await get_tree().create_timer(2).timeout
			var rise_tween = create_tween()
			rise_tween.tween_property(self, "position", position + Vector3(0, 50, 0), 1.5)
			await rise_tween.finished
			animate(SOAR)
			current_action = SOAR
			can_damage = true
			var outside_start
			var outside_end
			var idle_end
			if right_side:
				outside_start = outside_spots.get_node("Right")
				outside_end = outside_spots.get_node("Left")
				idle_end = idle_spots.get_node("Left")
			else:
				outside_start = outside_spots.get_node("Left")
				outside_end = outside_spots.get_node("Right")
				idle_end = idle_spots.get_node("Right")
			position = outside_start.position
			var soar_tween = create_tween()
			soar_tween.tween_property(self, "position", outside_end.position, 2)
			await soar_tween.finished
			animate(FLY)
			right_side = not right_side
			rotation.y -= PI
			position = idle_end.position + Vector3(0, 15, 0)
			var fly_down_tween = create_tween()
			fly_down_tween.tween_property(self, "position", idle_end.position, 3)
			await fly_down_tween.finished
			current_action = IDLE
			can_damage = false
			attack_cooldown.start()
		3:
			animate(FLY)
			current_action = FLY
			var fly_tween = create_tween()
			fly_tween.tween_property(self, "position", position + Vector3(0, 4, 0), 1)
			await fly_tween.finished
			current_action = FLAMETHROWER
			laser.visible = true
			var first
			var second
			if right_side:
				first = idle_spots.get_node("Left")
				second = idle_spots.get_node("Right")
			else:
				first = idle_spots.get_node("Right")
				second = idle_spots.get_node("Left")
			ray_cast_target.position = first.get_node("Start").global_position
			var first_flamethrower_tween = create_tween()
			first_flamethrower_tween.tween_property(ray_cast_target, "position", second.global_position, 1)
			await first_flamethrower_tween.finished
			current_action = FLY
			laser.visible = false
			await get_tree().create_timer(1).timeout
			current_action = FLAMETHROWER
			laser.visible = true
			ray_cast_target.position = second.get_node("Start").global_position
			var second_flamethrower_tween = create_tween()
			second_flamethrower_tween.tween_property(ray_cast_target, "position", first.global_position, 1)
			await second_flamethrower_tween.finished
			current_action = FLY
			laser.visible = false
			var land_tween = create_tween()
			land_tween.tween_property(self, "position", position - Vector3(0, 4, 0), 1)
			await land_tween.finished
			current_action = IDLE
			attack_cooldown.start()

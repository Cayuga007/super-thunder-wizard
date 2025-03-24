extends CharacterBody3D

enum {IDLE, DEFEATED, VICTORY, RUN, JUMP, SHOOT, SLASH}

const SPEED = 7.0
const JUMP_VELOCITY = 13
const LERP_VAL = 0.25

var rapidfire = false
var has_slash = false
var has_charge = false
var can_attack = true
var active = true
var current_action = IDLE
var charge = 0
var health: int = 100
var slash_damage = 20
var direction_facing = 1
var thunderbolt = preload("res://scenes/thunderbolt.tscn")
var thunderbolt2 = preload("res://scenes/thunderbolt2.tscn")
var thunderbolt4 = preload("res://scenes/thunderbolt4.tscn")
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var armature = $Armature
@onready var animation_tree = $AnimationTree
@onready var charge_indicator = $ChargeIndicator
@onready var attack_cooldown = $AttackCooldown
@onready var health_label = $HealthLabel

func animate(animation):
	match animation:
		IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		DEFEATED:
			animation_tree.set("parameters/Defeated/transition_request", "Dead")
		VICTORY:
			animation_tree.set("parameters/Victory/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		RUN:
			animation_tree.set("parameters/Movement/transition_request", "Run")
		JUMP:
			animation_tree.set("parameters/Movement/transition_request", "Jump")
		SHOOT:
			animation_tree.set("parameters/Shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		SLASH:
			animation_tree.set("parameters/Slash/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func take_damage(damage):
	health -= damage
	if health <= 0:
		animate(DEFEATED)
		active = false
		health = 0
		get_tree().create_timer(2).timeout.connect(func():
			get_tree().change_scene_to_file("res://scenes/overworld.tscn")
			Music.stop())
	health_label.text = str(health)

func victory():
	animate(VICTORY)
	active = false
	armature.rotation.y = deg_to_rad(-90)
	velocity = Vector3.ZERO
	
func hide_sword():
			get_node("Armature/Skeleton3D/BoneAttachment3D").visible = false

func _unhandled_input(_event):
	if not active: return
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_pressed("shoot") and can_attack:
		animate(SHOOT)
		var new_thunderbolt
		if rapidfire:
			new_thunderbolt = thunderbolt2.instantiate()
		else:
			new_thunderbolt = thunderbolt.instantiate()
		get_tree().root.add_child(new_thunderbolt)
		new_thunderbolt.position = position + Vector3(0, 1.25, 0)
		new_thunderbolt.direction_facing = direction_facing
		can_attack = false
		attack_cooldown.start()
	if Input.is_action_just_pressed("slash") and can_attack and has_slash:
		animate(SLASH)
		get_node("SlashSound").play()
		get_node("Armature/Skeleton3D/BoneAttachment3D").visible = true
		for body in armature.get_node("SlashHitbox").get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(slash_damage)
		can_attack = false
		attack_cooldown.start()

func _ready():
	health_label.text = str(health)
	if WorldManager.completed_worlds >= 1:
		has_slash = true
	if WorldManager.completed_worlds >= 2:
		has_charge = true
	var tween = create_tween().set_loops()
	tween.tween_property(charge_indicator, "rotation:y", PI / 2, 0.25)
	tween.tween_property(charge_indicator, "rotation:y", PI, 0.25)
	tween.tween_property(charge_indicator, "rotation:y", PI * 3 / 2, 0.25)
	tween.tween_property(charge_indicator, "rotation:y", PI * 2, 0.25)
	tween.loop_finished.connect(func(loop):
		charge_indicator.rotation.y = 0)
	get_node("AttackCooldown").timeout.connect(func():
		can_attack = true)

func _physics_process(delta):
	if not active: return
	var direction = Input.get_axis("left", "right")
	if direction != 0:
		animate(RUN)
		velocity.x = direction * SPEED
		if direction != direction_facing:
			create_tween().tween_property(armature, "rotation", Vector3(0, deg_to_rad(direction * 90 - 90), 0), 0.1)
		direction_facing = direction
	else:
		animate(IDLE)
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
	if not is_on_floor():
		animate(JUMP)
		velocity.y -= gravity * 4 * delta
	move_and_slide()
	
	if Input.is_action_pressed("shoot") and has_charge:
		charge += delta
		if charge >= 1:
			charge_indicator.visible = true
	if Input.is_action_just_released("shoot"):
		if charge >= 1:
			animate(SHOOT)
			var new_thunderbolt = thunderbolt4.instantiate()
			get_tree().root.add_child(new_thunderbolt)
			new_thunderbolt.position = position + Vector3(0, 1.25, 0)
			new_thunderbolt.direction_facing = direction_facing
			can_attack = false
			attack_cooldown.start()
		charge = 0
		charge_indicator.visible = false

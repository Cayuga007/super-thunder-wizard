extends Area3D

const SPEED = 20
var direction_facing = 1

@export var damage: int

func _ready():
	get_tree().create_timer(1).timeout.connect(func():
		queue_free())

func _physics_process(delta):
	var velocity = direction_facing * SPEED
	position.x += velocity * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
		get_node("AnimationPlayer").play("hit")
	elif body.name == "DemonBig":
		var demon_health = body.get_meta("Health")
		body.set_meta("Health", demon_health - damage)
		get_node("AnimationPlayer").play("hit")
		

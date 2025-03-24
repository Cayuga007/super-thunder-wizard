extends Area3D

@export var world: int

func _ready():
	if WorldManager.completed_worlds >= world - 1:
		visible = true
		get_node("CollisionShape3D").disabled = false
	body_entered.connect(func(body: CharacterBody3D):
		if body.name == "Wizard":
			WorldManager.start_world(world))
			

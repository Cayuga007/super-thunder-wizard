extends Node3D

func _ready():
	get_node("Play").pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/overworld.tscn"))
	get_node("Quit").pressed.connect(func():
		get_tree().quit())

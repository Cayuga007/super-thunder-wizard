extends Node

var current_world = 0
var current_level = 0
var levels = [
	[
	"res://scenes/worldonelevelone.tscn",
	"res://scenes/worldoneleveltwo.tscn",
	"res://scenes/worldonelevelthree.tscn",
	],
	[
	"res://scenes/worldtwolevelone.tscn",
	"res://scenes/worldtwoleveltwo.tscn",
	"res://scenes/worldtwolevelthree.tscn",
	],
	[
	"res://scenes/worldthreelevelone.tscn",
	"res://scenes/worldthreeleveltwo.tscn",
	"res://scenes/worldthreelevelthree.tscn",
	]
]

var completed_worlds = 0

func start_level():
	get_tree().change_scene_to_file(levels[current_world][current_level])
	
func start_world(world):
	current_world = world - 1
	current_level = 0
	start_level()

func next_level():
	current_level += 1
	if current_level <= 2:
		start_level()
	else:
		if current_world == 0 and completed_worlds == 0:
			completed_worlds = 1
		elif current_world == 1 and completed_worlds == 1:
			completed_worlds = 2
		elif current_world == 2 and completed_worlds == 2:
			completed_worlds = 3
		get_tree().change_scene_to_file("res://scenes/overworld.tscn")
		Music.stop()

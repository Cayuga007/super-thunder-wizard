extends Label

func _ready():
	if WorldManager.completed_worlds == 1:
		text = "Press X to slash"
	elif WorldManager.completed_worlds == 2:
		text = "Hold Z to charge fire"
	elif WorldManager.completed_worlds == 3:
		text = "Congratulations\nyou beat the game!"

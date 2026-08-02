extends Area2D

@export var item_id: String = "berry"
@export var item_name: String = "野果"

var player_in_range: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "CharacterBody2D":
		player_in_range = true
		print("进入拾取范围")

func _on_body_exited(body):
	if body.name == "CharacterBody2D":
		player_in_range = false
		print("离开拾取范围")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if player_in_range:
			GameData.inventory.append(item_id)
			print("捡起了：", item_name)
			queue_free()

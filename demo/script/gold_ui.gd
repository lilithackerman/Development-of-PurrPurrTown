extends CanvasLayer

@onready var gold_label = $GoldPanel/GoldLabel

func _ready():
	GameData.gold_changed.connect(_on_gold_changed)
	update_gold_display()
	while  true:
		await get_tree().create_timer(1.0).timeout
		GameData.gold += 1
func _on_gold_changed(new_value):
	gold_label.text = str(new_value)

func update_gold_display():
	gold_label.text = str(GameData.gold)

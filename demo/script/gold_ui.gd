extends CanvasLayer
# 金币显示层：只负责把 GameData.gold 画到右上角，不修改金币（表现层职责，见《游戏开发SOP》）。

# 节点引用：GoldUI 场景里 Panel 下的数字标签。
@onready var gold_label: Label = $GoldPanel/GoldLabel


func _ready():
	# 连上数据层的金币变化信号，金币一变就刷新数字。
	GameData.gold_changed.connect(_on_gold_changed)
	# 进游戏时先刷新一次，避免开局显示空标签。
	update_gold_display()


func _on_gold_changed(new_value: int):
	# 收到信号只更新显示；这里绝不写 GameData.gold，否则会形成“改值→发信号→改值”的死循环。
	gold_label.text = str(new_value)


func update_gold_display():
	# 手动刷新一次，供初始化或重开界面时调用。
	gold_label.text = str(GameData.gold)

extends Node

signal gold_changed(new_value)

var _gold: int = 0
var gold: int:
	get:
		return _gold
	set(value):
		if _gold == value:
			return                 # 值没变就不发信号，避免 UI 无谓刷新
		_gold = value
		gold_changed.emit(_gold)

# 背包：用字典存储，键为物品ID，值为数量
# 例如：{ "PlasticBottle": 3, "Berry": 5 }
var inventory: Dictionary = {}

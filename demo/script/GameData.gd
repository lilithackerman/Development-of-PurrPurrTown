extends Node

# 金币
var gold: int = 0

# 背包：用字典存储，键为物品ID，值为数量
# 例如：{ "PlasticBottle": 3, "Berry": 5 }
var inventory: Dictionary = {}

extends Node
# 全局数据中心（AutoLoad）。
# 只存数据、发信号，不碰任何节点、不写 UI 逻辑——这是《游戏开发SOP》里给 GameData 定死的职责。

# ========== 信号 ==========
# 金币变化时发出，GoldUI 监听后刷新右上角数字。
signal gold_changed(new_value)
# 背包变化时发出，BagUI 与 TradeUI 监听后刷新格子。
signal inventory_changed

# ========== 常量：背包容量 ==========
# 背包固定格子数，和 BagUI 里的 60 个格子保持一致；装满后再捡东西会提示“背包已满”。
const MAX_BAG_SLOTS: int = 60

# ========== 常量：物品与交易数据表 ==========
# 物品中文名表：键是物品 ID，值是显示用的名字。
const ITEM_NAME := {
	"PlasticBottle": "塑料瓶",
	"Newspaper": "废旧报纸",
	"Berry": "野果",
	"Cabbage": "白菜",
}
# 物品分类表：决定这个物品在哪个 NPC 那里能卖（废品、农产品……）。
const ITEM_CATEGORY := {
	"PlasticBottle": "废品",
	"Newspaper": "废品",
	"Berry": "农产品",
	"Cabbage": "农产品",
}
# 价格表：每件物品的收购单价（单位：金币）。
const PRICE_TABLE := {
	"PlasticBottle": 1,
	"Newspaper": 2,
	"Berry": 3,
	"Cabbage": 5,
}
# NPC 收货分类表：键是 NPC 的 id，值是它能收的分类数组；不在表里的 NPC 只闲聊、不交易。
const NPC_TRADE_CATEGORY := {
	"crow_merchant": ["废品"],
	"vegetable_market": ["农产品"],
}

# ========== 状态 ==========
# 游戏界面状态：PLAY 可自由走动、DIALOG 对话中、TRADE 交易中。
# 对话和交易时锁住角色移动，避免一边走一边点 UI。
enum UiState { PLAY, DIALOG, TRADE }
# 当前状态，默认可以自由走动。
var ui_state: UiState = UiState.PLAY

# ========== 金币 ==========
# 内部变量：真正的金币数值，只有下面的 gold 属性会读写它。
var _gold: int = 0
# 对外属性：读写金币时自动发信号，金币不会变成负数。
var gold: int:
	get:
		return _gold
	set(value):
		# 强制转成整数并夹到 0 以上，防止出现负金币导致 UI 显示怪数字。
		var clamped: int = max(0, int(value))
		# 值没变就直接返回，避免发出无意义的信号让 UI 白白刷新。
		if _gold == clamped:
			return
		_gold = clamped
		# 通知所有监听者（GoldUI）刷新显示。
		gold_changed.emit(_gold)

# ========== 背包 ==========
# 背包字典：键是物品 ID，值是数量，同一件物品天然堆叠成一格。
var inventory: Dictionary = {}


# ========== 查询类函数 ==========

func get_item_name(item_id: String) -> String:
	# 查物品中文名；表里没有就退回物品 ID，保证 UI 永远有字可显示。
	return ITEM_NAME.get(item_id, item_id)


func get_item_category(item_id: String) -> String:
	# 查物品分类；查不到返回空字符串，表示这件物品默认不可交易。
	return ITEM_CATEGORY.get(item_id, "")


func get_price(item_id: String) -> int:
	# 查收购单价；没定价的物品按 0 算。
	return int(PRICE_TABLE.get(item_id, 0))


func get_npc_categories(npc_id: String) -> Array:
	# 查这个 NPC 收哪些分类；不收货的 NPC 返回空数组。
	return NPC_TRADE_CATEGORY.get(npc_id, [])


func can_npc_trade(npc_id: String) -> bool:
	# 只要这个 NPC 在收货表里，就认为它能交易（供对话界面决定是否显示“交易”按钮）。
	return NPC_TRADE_CATEGORY.has(npc_id)


func can_trade_item(npc_id: String, item_id: String) -> bool:
	# 判断某件物品能不能卖给这个 NPC：先看物品分类，再看 NPC 收不收这个分类。
	var category: String = get_item_category(item_id)
	# 没有分类的物品一律不许交易。
	if category.is_empty():
		return false
	# 分类命中该 NPC 的收货列表才算可交易。
	return category in get_npc_categories(npc_id)


func count_item(item_id: String) -> int:
	# 查背包里某件物品有多少个；没有就是 0。
	return int(inventory.get(item_id, 0))


func bag_used_slots() -> int:
	# 已用格子数 = 背包字典里不同物品的种数（同种物品堆叠，只占一格）。
	return inventory.size()


func is_bag_full() -> bool:
	# 格子用满就算背包满。
	return bag_used_slots() >= MAX_BAG_SLOTS


# ========== 写入类函数 ==========

func add_item(item_id: String, amount: int = 1) -> bool:
	# 往背包加物品：成功返回 true，背包已满返回 false（调用方据此提示玩家）。
	if amount <= 0:
		return false
	if inventory.has(item_id):
		# 已经有这种物品，直接累加数量，不占新格子。
		inventory[item_id] = int(inventory[item_id]) + amount
	elif is_bag_full():
		# 新物品需要新格子，但格子已满，拒绝放入。
		return false
	else:
		# 新物品首次进包。
		inventory[item_id] = amount
	# 通知 UI 刷新背包。
	inventory_changed.emit()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	# 从背包扣除物品：成功返回 true，数量不够返回 false。
	if amount <= 0:
		return false
	var owned: int = count_item(item_id)
	if owned < amount:
		return false
	var left: int = owned - amount
	if left <= 0:
		# 扣完就整格移除，避免留下 0 个的空格子。
		inventory.erase(item_id)
	else:
		inventory[item_id] = left
	# 通知 UI 刷新背包。
	inventory_changed.emit()
	return true


func add_gold(amount: int) -> void:
	# 加金币：走 gold 属性，自动发信号。
	gold += amount


func spend_gold(amount: int) -> bool:
	# 花金币：不够就返回 false，够才扣。
	if amount <= 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	return true


# ========== 状态函数 ==========

func set_ui_state(new_state: UiState) -> void:
	# 切换界面状态；角色移动脚本每帧读这个值来决定能不能动。
	ui_state = new_state


func is_ui_blocking() -> bool:
	# 对话或交易时返回 true，表示现在应该锁住角色移动。
	return ui_state != UiState.PLAY

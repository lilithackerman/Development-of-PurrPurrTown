extends Area2D
# 拾取交互层：鼠标左键点中、且玩家在范围内，就把物品写进 GameData.inventory。
# 按 SOP：这里只管“检测点击 + 写数据”，不负责任何 UI 显示。

# ========== 导出变量 ==========
# 物品 ID：要和 GameData 的物品表对上（如 PlasticBottle）。
@export var item_id: String = "PlasticBottle"
# 一次拾取的数量，默认 1 个。
@export var amount: int = 1

# ========== 私有变量 ==========
# 玩家是否站在拾取范围内（用 body_entered / body_exited 维护）。
var player_in_range: bool = false

# ========== 节点引用 ==========
# 自己的贴图节点，用来判断鼠标是不是真的点在这件物品上。
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


# ========== 生命周期 ==========
func _ready():
	# 进出范围的两个信号在这里接上，_ready 时接比在检查器里连更好维护。
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	# 只认 player 组里的节点，不再硬写节点名（改一次名就会全崩）。
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body):
	# 玩家走出范围就关掉拾取权限。
	if body.is_in_group("player"):
		player_in_range = false


# ========== 输入：点击拾取 ==========
func _unhandled_input(event):
	# 只处理鼠标左键按下的那一下。
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# 玩家不在范围内就不理会这一下点击。
	if not player_in_range:
		return
	# 关键修复：必须点在“我自己”身上才算捡，否则一个都捡不起来；
	# 反过来，只要点中了，就把事件标记为已处理，别的瓶子不会再抢这一次点击。
	if not _is_point_on_me(get_global_mouse_position()):
		return
	get_viewport().set_input_as_handled()
	_pick_up()


func _is_point_on_me(world_pos: Vector2) -> bool:
	# 判断一个世界坐标点是不是落在这件物品的贴图范围内。
	# 单独抽成一个带参数的函数，是为了让测试能直接传坐标进来验证（鼠标位置在无头模式里没法伪造）。
	# 没有贴图节点时退化成“离中心 48 像素内算点中”，保证不会失灵。
	if sprite == null or sprite.texture == null:
		return world_pos.distance_to(global_position) <= 48.0
	# 贴图尺寸 × 世界缩放 = 屏幕上的实际大小。
	var size: Vector2 = sprite.texture.get_size() * sprite.global_scale.abs()
	# Sprite2D 默认以中心为原点，offset 会让中心整体偏移，这里一并算进去。
	var center: Vector2 = sprite.global_position + sprite.offset * sprite.global_scale
	# 求包围盒后判断点是否落在里面。
	var rect := Rect2(center - size * 0.5, size)
	return rect.has_point(world_pos)


func _pick_up():
	# 真正写数据的地方：交给 GameData 判断能不能放（背包满会返回 false）。
	var ok: bool = GameData.add_item(item_id, amount)
	if not ok:
		# 背包满就把这次点击作废，物品留在原地。
		print("背包已满，捡不起：", GameData.get_item_name(item_id))
		return
	# 打印一行便于调试，正式版可以删。
	print("捡起了：", GameData.get_item_name(item_id), " 当前数量：", GameData.count_item(item_id))
	# 数据已进包，这个拾取物从场景里消失。
	queue_free()

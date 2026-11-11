extends CanvasLayer
# 背包表现层：读 GameData.inventory，把物品图标和数量画到格子里。
# 按 SOP：这里不写入数据，只负责显示。

# ========== 常量 ==========
# 单个格子的尺寸（像素），沿用原来手工布局的 70×70。
const SLOT_SIZE: Vector2 = Vector2(70, 70)
# 格子里的图标尺寸，留 5 像素边距让图标居中。
const ICON_SIZE: Vector2 = Vector2(60, 60)
# 图标所在文件夹。
const ICON_DIR: String = "res://img/"

# ========== 导出变量 ==========
# 图标路径，保留原脚本的导出项，方便以后换素材目录。
@export var item_icon_path: String = ICON_DIR

# ========== 节点引用 ==========
# 背包底板。
@onready var panel: Panel = $Panel
# 标题标签，用来显示“背包 3/60”。
@onready var title_label: Label = $Panel/Label
# 格子容器。
@onready var grid: GridContainer = $Panel/GridContainer

# ========== 运行时数据 ==========
# 运行时生成的格子列表，索引和背包物品顺序一一对应。
var _slots: Array[Panel] = []


# ========== 生命周期 ==========
func _ready():
	# 开局先隐藏，按 B 才打开。
	visible = false
	# 登记到 bag_ui 组，角色脚本按键时靠这个组名找到背包。
	add_to_group("bag_ui")
	# 背包数据一变就自动刷新（捡东西、卖东西都会触发）。
	GameData.inventory_changed.connect(_on_inventory_changed)
	# 把格子按统一规格重建一遍。
	_build_slots()


func _on_inventory_changed():
	# 只在背包打开时刷新，关着的时候刷新纯属浪费。
	if visible:
		update_bag()


# ========== 构建格子 ==========
func _build_slots():
	# 先清空场景里原有的格子：原场景有 60 个手搓格子，
	# 其中还误在 slot48 里面塞了 12 个（改着改着放错了上级节点）。
	# 这些格子规格不一致，统一按代码重建，场景文件保持干净。
	for child in grid.get_children():
		# 先断开上级关系再销毁，保证后面算格子数量时不会数到“待销毁”的节点。
		grid.remove_child(child)
		child.queue_free()
	# 清空自己的格子列表。
	_slots.clear()
	# 60 个格子共用一套底样式，只建一次，省资源。
	var slot_style := StyleBoxFlat.new()
	# 格子底色：比面板略亮一点，才看得出“格子”。
	slot_style.bg_color = Color(0.18, 0.19, 0.23, 1.0)
	# 细边框，网格才立得起来。
	slot_style.border_color = Color(0.42, 0.40, 0.30, 1.0)
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(6)
	# 按 GameData 的容量上限生成同样多的空格子。
	for i in GameData.MAX_BAG_SLOTS:
		# 每个格子都是一个 Panel，纯用来装图标和数字。
		var slot := Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.size = SLOT_SIZE
		# 套上底样式。
		slot.add_theme_stylebox_override("panel", slot_style)
		grid.add_child(slot)
		_slots.append(slot)


# ========== 刷新显示 ==========
func update_bag():
	# 背包没建好（比如场景还没进树）就不刷新，防止空指针。
	if _slots.is_empty():
		return
	# 取出所有物品 ID，顺序即字典插入顺序。
	var item_ids: Array = GameData.inventory.keys()
	# 逐个格子刷新：有物品就画，没有就留空。
	for i in _slots.size():
		var slot: Panel = _slots[i]
		# 先清掉这个格子上一轮的图标/数字。
		_clear_slot(slot)
		# 超出物品数量的格子保持空白。
		if i >= item_ids.size():
			continue
		# 当前格子对应的物品 ID 和数量。
		var item_id: String = item_ids[i]
		var count: int = GameData.count_item(item_id)
		# 往格子里画图标和数量。
		_fill_slot(slot, item_id, count)
	# 标题顺便显示容量占用，方便调试“背包已满”。
	if title_label:
		title_label.text = "背包  %d / %d" % [GameData.bag_used_slots(), GameData.MAX_BAG_SLOTS]


func _clear_slot(slot: Panel):
	# 只删运行时生成的子节点；格子本身要留着。
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()


func _fill_slot(slot: Panel, item_id: String, count: int):
	# 图标：按 res://img/物品ID.png 找图。
	var icon := TextureRect.new()
	icon.size = ICON_SIZE
	icon.position = (SLOT_SIZE - ICON_SIZE) * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = item_icon_path + item_id + ".png"
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	else:
		# 没有图就画个灰块占位，同时把名字写上去，至少能认出是什么。
		icon.self_modulate = Color(0.55, 0.55, 0.55, 1.0)
		var name_label := Label.new()
		name_label.text = GameData.get_item_name(item_id)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size = ICON_SIZE
		icon.add_child(name_label)
	slot.add_child(icon)
	# 数量标签放在格子右下角。
	var count_label := Label.new()
	count_label.text = str(count)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_label.position = Vector2(50, 44)
	count_label.size = Vector2(20, 24)
	slot.add_child(count_label)


func toggle():
	# 开/关背包，角色脚本也可以直接调这个函数。
	visible = not visible
	# 打开时立刻刷新一次数据。
	if visible:
		update_bag()

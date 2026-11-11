extends CanvasLayer
# 交易界面（表现层 + 交易逻辑）：读背包、按 NPC 分类过滤、把物品移进交易栏、结算成金币。
# 按 SOP：这里不直接操作 NPC 节点，只跟 GameData 打交道。

# ========== 信号 ==========
# 界面关闭时发出，交互层据此清空引用。
signal closed

# ========== 常量 ==========
# 长按判定时间（秒）：按住超过这个时间算长按。
const LONG_PRESS_TIME: float = 0.5
# 长按一次移动的数量；数量不足就全移。
const LONG_PRESS_AMOUNT: int = 10
# 背包格子的列数，和场景里 GridContainer 的 columns 保持一致。
const BAG_COLUMNS: int = 3
# 单个格子的最小尺寸（像素）。
const SLOT_SIZE: Vector2 = Vector2(104, 104)
# 图标文件夹路径，和 bag_ui.gd 用同一套约定。
const ICON_DIR: String = "res://img/"

# ========== 运行时数据 ==========
# 当前交易的 NPC id，决定收哪些分类。
var npc_id: String = ""
# 当前交易的 NPC 显示名，用于标题。
var npc_display_name: String = ""
# 交易栏数据：键是物品 ID，值是“准备卖出的数量”。
# 注意这里只记账，不立刻扣背包；等“确定售出”时再一次性结算。
var trade_items: Dictionary = {}

# ========== 长按状态 ==========
# 按下的是哪件物品。
var _press_item_id: String = ""
# 已经按住了多久（秒）。
var _press_elapsed: float = 0.0
# 这一次长按是否已经触发过移动（防止长按一次反复触发）。
var _press_consumed: bool = false
# 当前是否处于按住状态。
var _pressing: bool = false

# ========== 节点引用 ==========
# 标题，显示“XX 的回收站”之类。
@onready var title_label: Label = $Root/Title
# 左侧交易栏的滚动容器。
@onready var trade_scroll: ScrollContainer = $Root/TradeScroll
# 左侧交易栏的行容器，运行时动态生成行。
@onready var trade_list: VBoxContainer = $Root/TradeScroll/TradeList
# 右侧背包格子容器，运行时动态生成格子。
@onready var bag_grid: GridContainer = $Root/BagGrid
# 预计收入标签。
@onready var income_label: Label = $Root/IncomeLabel
# 一键售出按钮。
@onready var sell_all_button: Button = $Root/SellAllButton
# 确定售出按钮。
@onready var confirm_button: Button = $Root/ConfirmButton
# 关闭按钮。
@onready var close_button: Button = $Root/CloseButton
# 交易栏为空时的提示标签。
@onready var empty_hint: Label = $Root/EmptyHint


# ========== 生命周期 ==========
func _ready():
	# 三个按钮的信号统一在这里接，不让场景文件里散落 connection。
	close_button.pressed.connect(close)
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	# 打开交易界面就把全局状态切成 TRADE，角色会被锁住。
	GameData.set_ui_state(GameData.UiState.TRADE)
	# 背包数据一变就刷新显示，保证结算后界面立刻同步。
	GameData.inventory_changed.connect(_on_inventory_changed)


func _process(delta):
	# 没在按住就直接返回，几乎不耗性能。
	if not _pressing:
		return
	# 累计按住时长。
	_press_elapsed += delta
	# 超过 0.5 秒且本次尚未触发，就按“长按”处理。
	if not _press_consumed and _press_elapsed >= LONG_PRESS_TIME:
		_press_consumed = true
		# 长按移 10 个（不足就全移）。
		move_item_to_trade(_press_item_id, LONG_PRESS_AMOUNT)


# ========== 对外接口 ==========
func open(p_npc_id: String, p_npc_display_name: String) -> void:
	# 记下交易对象：分类过滤和标题都要用。
	npc_id = p_npc_id
	npc_display_name = p_npc_display_name
	# 标题写在 NPC 名字后面，一眼看出在跟谁交易。
	title_label.text = npc_display_name + " · 回收站"
	# 交易栏一开始是空的。
	trade_items.clear()
	# 生成两侧的格子/行。
	refresh()


func close() -> void:
	# 关掉前还原状态，否则角色会一直被锁住。
	GameData.set_ui_state(GameData.UiState.PLAY)
	# 先通知上层，再销毁自己。
	closed.emit()
	queue_free()


# ========== 核心：物品移动 ==========
func move_item_to_trade(item_id: String, amount: int) -> void:
	# 统一入口：点击、长按、一键售出都走这里，避免三套逻辑各写一遍。
	if amount <= 0:
		return
	# 这个 NPC 不收这件东西就什么都不做。
	if not GameData.can_trade_item(npc_id, item_id):
		return
	# 背包里实际有多少个。
	var owned: int = GameData.count_item(item_id)
	# 已经放进交易栏多少个。
	var staged: int = int(trade_items.get(item_id, 0))
	# 还能再移多少个（背包数量减去已记账的）。
	var available: int = owned - staged
	if available <= 0:
		return
	# 真正移动数量：不超过想要的数量，也不超过可用的数量。
	var moved: int = min(amount, available)
	trade_items[item_id] = staged + moved
	# 刷新界面。
	refresh()


func return_item_to_bag(item_id: String, amount: int) -> void:
	# 反向操作：从交易栏拿回背包（点击交易栏某一行时用）。
	var staged: int = int(trade_items.get(item_id, 0))
	if staged <= 0:
		return
	var back: int = min(amount, staged)
	var left: int = staged - back
	if left <= 0:
		# 拿空了就把这一行删掉，避免留下 0 个的空行。
		trade_items.erase(item_id)
	else:
		trade_items[item_id] = left
	refresh()


# ========== 刷新界面 ==========
func refresh() -> void:
	_refresh_bag()
	_refresh_trade_list()
	_refresh_income()


func _refresh_bag() -> void:
	# 先清空旧格子（这些格子都是运行时生成的，可以直接删）。
	for child in bag_grid.get_children():
		child.queue_free()
	# 再按背包内容生成新格子：只显示这个 NPC 收得下的分类。
	for item_id in GameData.inventory.keys():
		# 背包里已经全部放进交易栏的，格子上显示为 0，直接跳过。
		var remain: int = GameData.count_item(item_id) - int(trade_items.get(item_id, 0))
		if remain <= 0:
			continue
		# 这个 NPC 不收的分类不显示。
		if not GameData.can_trade_item(npc_id, item_id):
			continue
		# 生成一个可点击的格子。
		bag_grid.add_child(_make_bag_slot(item_id, remain))
	# 空位补齐，让 3 列网格看起来规整（最多补到 12 格）。
	var filler: int = BAG_COLUMNS - (bag_grid.get_child_count() % BAG_COLUMNS)
	if bag_grid.get_child_count() > 0 and filler < BAG_COLUMNS:
		for i in filler:
			bag_grid.add_child(_make_empty_slot())


func _make_bag_slot(item_id: String, count: int) -> Panel:
	# 一个格子就是一个 Panel，靠 gui_input 接点击/长按。
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	# 给格子加个边框底色，不然在深色面板上看不出“这里有个格子”。
	slot.add_theme_stylebox_override("panel", _make_slot_style())
	# 记下这个格子装的是哪件物品，回调里要用。
	slot.set_meta("item_id", item_id)
	# 图标：有图就用图，没图就留空（名字标签始终显示，保证能认出来）。
	var icon := TextureRect.new()
	icon.texture = _load_icon(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 上边留 8、下边留出 30 给文字，图标就在这块区域里居中缩放。
	icon.offset_left = 8.0
	icon.offset_top = 8.0
	icon.offset_right = -8.0
	icon.offset_bottom = -30.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	# 名字 + 数量写在格子底部，一行看完。
	var name_label := Label.new()
	name_label.text = "%s ×%d" % [GameData.get_item_name(item_id), count]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	# 贴住格子底边，左右拉满。
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 2.0
	name_label.offset_top = -26.0
	name_label.offset_right = -2.0
	name_label.offset_bottom = -4.0
	slot.add_child(name_label)
	# 接上点击 / 长按。
	slot.gui_input.connect(_on_slot_gui_input.bind(item_id))
	return slot


func _make_slot_style() -> StyleBoxFlat:
	# 格子/行通用的底样式：深灰底 + 细边 + 圆角。
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.21, 1.0)
	style.border_color = Color(0.42, 0.40, 0.30, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _make_empty_slot() -> Panel:
	# 空格子只用来占位，不接受输入。
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 和真格子用同一套底色，网格看起来才连贯。
	slot.add_theme_stylebox_override("panel", _make_slot_style())
	return slot


func _refresh_trade_list() -> void:
	# 先清空旧行。
	for child in trade_list.get_children():
		child.queue_free()
	# 交易栏是否为空，决定要不要显示提示。
	var has_item: bool = not trade_items.is_empty()
	empty_hint.visible = not has_item
	trade_scroll.visible = has_item
	if not has_item:
		return
	# 每件物品生成一行。
	for item_id in trade_items.keys():
		trade_list.add_child(_make_trade_row(item_id, int(trade_items[item_id])))


func _make_trade_row(item_id: String, count: int) -> Panel:
	# 一行 = 一个 Panel，里面横着摆名字、数量、单价、小计。
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.set_meta("item_id", item_id)
	# 行也用同一套底色，和右边格子呼应。
	row.add_theme_stylebox_override("panel", _make_slot_style())
	# 物品名。
	var name_label := Label.new()
	name_label.text = GameData.get_item_name(item_id)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(16, 14)
	name_label.size = Vector2(260, 30)
	row.add_child(name_label)
	# 数量。
	var count_label := Label.new()
	count_label.text = "× " + str(count)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.position = Vector2(300, 14)
	count_label.size = Vector2(100, 30)
	row.add_child(count_label)
	# 单价。
	var price_label := Label.new()
	price_label.text = "单价 " + str(GameData.get_price(item_id))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.position = Vector2(420, 14)
	price_label.size = Vector2(160, 30)
	row.add_child(price_label)
	# 小计，靠右显示。
	var subtotal_label := Label.new()
	subtotal_label.text = "小计 " + str(GameData.get_price(item_id) * count)
	subtotal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtotal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtotal_label.position = Vector2(700, 14)
	subtotal_label.size = Vector2(200, 30)
	row.add_child(subtotal_label)
	# 点这一行可以把物品拿回背包。
	row.gui_input.connect(_on_trade_row_gui_input.bind(item_id))
	return row


func _refresh_income() -> void:
	# 预计总收入 = 每件物品的单价 × 数量，全部加起来。
	var total: int = 0
	for item_id in trade_items.keys():
		total += GameData.get_price(item_id) * int(trade_items[item_id])
	income_label.text = "预计收入：" + str(total) + " 金币"
	# 没有东西可卖时，确定按钮灰掉，防止空点。
	confirm_button.disabled = total <= 0
	sell_all_button.disabled = _count_sellable_items() <= 0


func _count_sellable_items() -> int:
	# 统计背包里还有多少件“没进交易栏”的可卖物品。
	var total: int = 0
	for item_id in GameData.inventory.keys():
		if not GameData.can_trade_item(npc_id, item_id):
			continue
		var remain: int = GameData.count_item(item_id) - int(trade_items.get(item_id, 0))
		if remain > 0:
			total += remain
	return total


func _load_icon(item_id: String) -> Texture2D:
	# 按约定路径找图标；找不到返回 null，格子照样能显示名字。
	var path: String = ICON_DIR + item_id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ========== 输入回调 ==========
func _on_slot_gui_input(event: InputEvent, item_id: String) -> void:
	# 只处理鼠标左键。
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		# 按下：开始计时，等着看是“点击”还是“长按”。
		_pressing = true
		_press_item_id = item_id
		_press_elapsed = 0.0
		_press_consumed = false
	else:
		# 松开：如果长按没触发过，就按普通点击处理——移 1 个。
		if _pressing and not _press_consumed:
			move_item_to_trade(item_id, 1)
		# 复位长按状态。
		_pressing = false
		_press_item_id = ""
		_press_elapsed = 0.0
		_press_consumed = false


func _on_trade_row_gui_input(event: InputEvent, item_id: String) -> void:
	# 交易栏里点一下 = 拿回 1 个，方便点错了反悔。
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return_item_to_bag(item_id, 1)


func _on_sell_all_pressed() -> void:
	# 一键售出：把背包里所有可卖的东西全部移进交易栏。
	for item_id in GameData.inventory.keys():
		if not GameData.can_trade_item(npc_id, item_id):
			continue
		var remain: int = GameData.count_item(item_id) - int(trade_items.get(item_id, 0))
		if remain > 0:
			move_item_to_trade(item_id, remain)


func _on_confirm_pressed() -> void:
	# 确定售出：先把总价算出来，再扣背包、加金币，最后清空交易栏。
	var total: int = 0
	for item_id in trade_items.keys():
		total += GameData.get_price(item_id) * int(trade_items[item_id])
	if total <= 0:
		return
	# 逐件从背包扣除；扣不动的（数据被别处改了）就跳过，但总价已在上面算好。
	for item_id in trade_items.keys():
		GameData.remove_item(item_id, int(trade_items[item_id]))
	# 金币一次性加到玩家账上，GoldUI 会自动刷新。
	GameData.add_gold(total)
	# 打印一行结算日志，方便测试时核对。
	print("售出完成，收入 ", total, " 金币，当前金币 ", GameData.gold)
	# 交易栏清空，界面回到初始状态。
	trade_items.clear()
	refresh()


func _on_inventory_changed() -> void:
	# 背包数据变了（比如别处又捡到东西）就刷新一次。
	refresh()


# ========== 输入：Esc 关闭 ==========
func _unhandled_input(event):
	# 只关心按下、且不是输入法重复触发的事件。
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Esc 关掉交易界面。
	if event.keycode == KEY_ESCAPE:
		# 标记已处理，防止同一个按键继续传给别的节点。
		get_viewport().set_input_as_handled()
		close()

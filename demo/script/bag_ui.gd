extends CanvasLayer
# 继承 CanvasLayer，确保背包 UI 始终显示在游戏画面的最上层，不受地图、角色等遮挡。

@export var item_icon_path: String = "res://img/"
# 导出变量，可在检查器中修改。这是物品图标存放的文件夹路径，默认是 "res://img/"。

@export var grid_container: GridContainer = null
# 导出变量，可在检查器中拖入 GridContainer 节点。如果为空，则在 _ready() 中自动查找。

func _ready():
	# 当背包 UI 场景被加载时自动执行。
	visible = false
	# 初始状态隐藏背包界面，玩家按 Tab 键时才显示。
	
	if grid_container == null:
		# 如果 grid_container 变量为空（没有在检查器中手动指定），则自动查找场景中的 GridContainer。
		grid_container = $Panel/GridContainer
		# $ 符号表示从当前节点（CanvasLayer）开始查找子节点。这里查找 Panel 节点下的 GridContainer。

func update_bag():
	# 刷新背包显示的函数，由外部（如玩家按 Tab 键时）调用。
	
	# 1. 清空所有格子里的旧内容（保留格子本身）
	for slot in grid_container.get_children():
		# 遍历 GridContainer 的所有直接子节点，即每个格子（slot）。
		for child in slot.get_children():
			# 遍历每个格子下的所有子节点（之前的图标、标签等）。
			child.queue_free()
			# 安全地删除这些旧内容，下一帧生效。
	
	# 2. 填充物品
	var index = 0
	# index 用于记录当前填充到第几个格子（从0开始）。
	
	for item_id in GameData.inventory:
		# 遍历 GameData.inventory 字典，item_id 是物品的 ID（如 "PlasticBottle"）。
		var count = GameData.inventory[item_id]
		# 获取该物品的堆叠数量。
		
		if index >= grid_container.get_child_count():
			# 如果物品数量超过了格子总数（防止数组越界），则停止填充。
			break
		
		var slot = grid_container.get_child(index)
		# 获取当前索引对应的格子节点（slot）。
		
		# 3. 添加物品图标（TextureRect）
		var icon = TextureRect.new()
		# 创建一个新的 TextureRect 节点，用于显示物品图片。
		icon.size = Vector2(60, 60)
		# 设置图标大小为 60x60 像素。
		icon.position = Vector2(5, 5)
		# 设置图标在格子内的偏移位置。因为格子大小是 70x70，偏移 (5,5) 可以让图标居中（(70-60)/2=5）。
		
		var texture = load(item_icon_path + item_id + ".png")
		# 根据物品 ID 构建图片路径，并尝试加载图片文件。
		
		if texture:
			icon.texture = texture
			# 如果加载成功，将纹理赋给图标。
		else:
			# 如果加载失败（图片不存在），则使用灰色填充占位。
			icon.self_modulate = Color(0.5, 0.5, 0.5, 1)
			# TextureRect 没有 color 属性，用 self_modulate 设置颜色（这里为灰色，半透明）。
		
		icon.expand = true
		# 允许图标根据设置的尺寸缩放。
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# 设置图标的拉伸模式：保持宽高比并居中显示，不变形。
		
		slot.add_child(icon)
		# 将图标添加为格子（slot）的子节点，显示在格子内部。
		
		# 4. 数量标签（如果 count >= 1）
		if count >= 1:
			# 只要数量 >=1 就显示数字（原来只显示 >1，现在改为 >=1 便于调试）。
			var label = Label.new()
			# 创建一个新的 Label 节点用于显示数量。
			label.text = str(count)
			# 将数量数字转为字符串并赋值给标签。
			label.position = Vector2(55, 45)
			# 设置标签在格子内的位置（相对于格子的左上角），这里放在右下角附近。
			label.add_theme_font_size_override("font_size", 14)
			# 设置字体大小为 14。
			label.add_theme_color_override("font_color", Color.WHITE)
			# 设置字体颜色为白色。
			icon.add_child(label)
			# 将标签添加为图标（icon）的子节点，这样标签会跟随图标的位置移动。
		
		index += 1
		# 索引加1，准备处理下一个物品。

extends Area2D
@export var dialog_ui_scene: PackedScene = preload("res://DialogUI.tscn")
# 引用对话框 UI（你刚才新建的场景）
@export var npc_name: String = "NPC名字"
@export var dialog_text: String = "对话内容"
@export var npc_portrait: Texture = null   # 立绘图片，在检查器里拖入

# 当前对话框的实例（运行时创建）
var dialog_instance = null

# 玩家是否在范围内
var player_in_range = false

func _ready():
	# 连接信号：当有物体进入/离开这个区域时，触发函数
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# 当玩家进入触发范围
func _on_body_entered(body):
	if body.name == "CharacterBody2D":  # 检查是不是玩家
		player_in_range = true
		print("玩家进入了对话范围")  # 测试输出

# 当玩家离开触发范围
func _on_body_exited(body):
	if body.name == "CharacterBody2D":
		player_in_range = false
		# 如果对话框还开着，就关闭它
		if dialog_instance:
			dialog_instance.queue_free()
			dialog_instance = null
		print("玩家离开了对话范围")  # 测试输出

# 检测键盘输入（按 E 键）
func _input(event):
	# 只处理按下的 E 键
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		return
	if not player_in_range:
		return
	
	# 如果对话框已经打开，关闭它
	if dialog_instance != null:
		dialog_instance.queue_free()
		dialog_instance = null
		return
	
	# 如果对话框没打开，创建它
	dialog_instance = dialog_ui_scene.instantiate()# --- 创建并显示对话框 ---
	add_child(dialog_instance)
	
	var name_label = dialog_instance.get_node("Panel/NameLabel")
	if name_label:
		name_label.text = "乌乌"
	else:
		print("错误：DialogUI 里找不到 NameLabel 节点")

	# 2. 设置对话内容
	var text_label = dialog_instance.get_node("Panel/TextLabel")
	if text_label:
		text_label.text = "还钱"
	else:
		print("错误：DialogUI 里找不到 TextLabel 节点")

	# 3. 设置立绘（如果没有图片，就跳过）
	var portrait = dialog_instance.get_node("Panel/TextureRect3")
	if portrait and npc_portrait:
		portrait.texture = npc_portrait
	elif portrait:
		# 如果没有给这个 NPC 设置立绘，就留空（不报错）
		pass
	else:
		print("错误：DialogUI 里找不到 Portrait 节点")

func _show_dialog(name_text, content_text):
	if dialog_instance:
		# 假设你的 DialogUI 里名字 Label 叫 "NameLabel"，内容 Label 叫 "TextLabel"
		dialog_instance.get_node("NameLabel").text = name_text
		dialog_instance.get_node("TextLabel").text = content_text
		

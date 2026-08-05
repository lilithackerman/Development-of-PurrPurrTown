# 继承 CharacterBody2D，这是 Godot 中用于物理运动（移动、碰撞）的标准节点类型。
extends CharacterBody2D

# 行走速度（单位：像素/秒），可在检查器中调整。
@export var walk_speed: float = 100.0
# 奔跑速度（单位：像素/秒），可在检查器中调整。
@export var run_speed: float = 200.0

# 当前实际移动速度，初始为行走速度。
var current_speed: float = walk_speed
# 记录角色最后一次面朝的方向，用于松开按键后播放对应的待机动画。
var last_direction: String = "down"

# 获取角色身上的 AnimatedSprite2D 节点，用于播放动画。
# @onready 表示在节点树完全加载后才赋值，确保节点存在。
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# physics_process 每帧调用，用于处理物理相关的逻辑（移动、碰撞检测）。
func _physics_process(delta: float) -> void:
	# 1. 获取方向键输入（WASD），返回一个 Vector2，范围 -1 到 1。
	# 注意这里使用的是 Godot 默认的 ui_ 开头的动作，无需额外绑定按键。
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. 检测是否按住了 Shift 键（通过名为 "run" 的输入动作，需要在项目设置中绑定）。
	var is_running := Input.is_action_pressed("run")
	
	# 判断是否按下了方向键（即输入不为零向量）。
	if input_dir != Vector2.ZERO:
		# ---- 确定面朝方向（上下左右） ----
		var dir_str: String
		# 比较水平方向和垂直方向输入绝对值的大小，决定优先水平还是垂直。
		if abs(input_dir.x) > abs(input_dir.y):
			# 水平方向移动更大，优先处理左右。
			dir_str = "left" if input_dir.x < 0 else "right"
		else:
			# 垂直方向移动更大，优先处理上下。
			dir_str = "up" if input_dir.y < 0 else "down"
		
		# 记下最后的方向，用于松开按键时播放正确的待机动画。
		last_direction = dir_str
		
		# ---- 计算速度并移动角色 ----
		# 如果正在奔跑则使用奔跑速度，否则使用行走速度。
		current_speed = run_speed if is_running else walk_speed
		# 速度向量 = 输入方向 * 当前速度大小。
		velocity = input_dir * current_speed
		# 应用速度并处理碰撞（自动移动并滑动）。
		move_and_slide()
		
		# ---- 播放对应的走路或跑步动画 ----
		# 根据是否奔跑决定动画前缀（"run" 或 "walk"）。
		var anim_prefix = "run" if is_running else "walk"
		# 播放动画：前缀 + "-" + 方向，例如 "walk-down"、"run-left"。
		# 注意动画名称中用的是短横线 "-" 连接。
		animated_sprite.play(anim_prefix + "-" + dir_str)
		
	else:
		# ---- 没有按任何方向键：原地待机 ----
		# 速度归零，角色停止移动。
		velocity = Vector2.ZERO
		# 播放待机动画：面朝最后一次移动的方向，例如 "idle-down"。
		animated_sprite.play("idle-" + last_direction)


# ----- 鼠标滚轮控制镜头缩放 和 Tab 键开关背包 -----
# _input 函数用于处理各种输入事件（键盘、鼠标等）。
func _input(event):
	# ---- Tab 键开关背包 ----
	# 判断事件是否为键盘按键，且按下，且键码为 Tab。
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		# 从场景根节点开始，递归查找名为 "BagUI" 的子节点（包括隐藏的）。
		var bag = get_tree().root.find_child("BagUI", true, false)
		# 打印找到的节点（用于调试，会输出节点路径或 null）。
		print("找到的背包节点：", bag)
		if bag:
			# 切换背包可见性（取反）。
			bag.visible = !bag.visible
			# 如果背包现在可见，则刷新背包数据显示最新物品。
			if bag.visible:
				bag.update_bag()  # 打开时刷新数据
				
	# ---- 鼠标滚轮控制镜头缩放 ----
	# 判断事件是否为鼠标按钮事件，且为按下状态。
	if event is InputEventMouseButton and event.pressed:
		# 获取角色身上的 Camera2D 节点（假设直接挂在角色下面）。
		var camera = $Camera2D
		
		# 如果没找到摄像机，就不执行，防止报错。
		if camera == null:
			return
		
		# 滚轮向上：拉近（放大），增加 zoom 值。
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom += Vector2(0.1, 0.1)
		# 滚轮向下：拉远（缩小），减小 zoom 值。
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom -= Vector2(0.1, 0.1)
		
		# 限制缩放范围，防止拉到太远看不见，或太近只看得到眼睛。
		# clamp 将 zoom 限制在 (0.5,0.5) 和 (3.0,3.0) 之间。
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

# _ready 函数在节点进入场景树时调用一次，用于初始化。
func _ready():
	# 打印 GameData 中的金币数量，用于测试数据是否加载成功。
	print(GameData.gold)
	# 打印 GameData 中的背包字典，用于测试数据是否加载成功。
	print(GameData.inventory)

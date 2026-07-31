extends CharacterBody2D

# 行走和奔跑速度（可在检查器里调）
@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0

# 当前速度（由是否按 Shift 决定）
var current_speed: float = walk_speed
# 记住最后一次面朝方向（用于待机）
var last_direction: String = "down"

# 获取角色身上的动画播放器（请确保节点名叫 AnimatedSprite2D）
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# 1. 获取方向键输入（WASD），注意这里用的是 ui_ 开头
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. 检测是否按住了 Shift 键（直接检测键盘，不用去项目设置绑定了）
	var is_running := Input.is_action_pressed("run")
	
	if input_dir != Vector2.ZERO:
		# ---- 确定面朝方向（上下左右） ----
		var dir_str: String
		if abs(input_dir.x) > abs(input_dir.y):
			# 水平方向移动优先
			dir_str = "left" if input_dir.x < 0 else "right"
		else:
			# 垂直方向移动优先
			dir_str = "up" if input_dir.y < 0 else "down"
		
		# 记下最后的方向，松开按键时待机动画要用
		last_direction = dir_str
		
		# ---- 计算速度并移动角色 ----
		current_speed = run_speed if is_running else walk_speed
		velocity = input_dir * current_speed
		move_and_slide()
		
		# ---- 播放对应的走路或跑步动画（注意这里是短横线 - ） ----
		var anim_prefix = "run" if is_running else "walk"
		animated_sprite.play(anim_prefix + "-" + dir_str)
		
	else:
		# ---- 没有按任何方向键：原地待机 ----
		velocity = Vector2.ZERO
		# 播放待机动画（面朝最后一次移动的方向，注意短横线）
		animated_sprite.play("idle-" + last_direction)


# ----- 鼠标滚轮控制镜头缩放（新加的，完全独立） -----
func _input(event: InputEvent) -> void:
	# 只处理鼠标按键事件
	if event is InputEventMouseButton and event.pressed:
		# 获取摄像机（确保你的 Camera2D 节点在角色下面，且名字叫 Camera2D）
		var camera = $Camera2D
		
		# 如果没找到摄像机，就不执行，防止报错
		if camera == null:
			return
		
		# 滚轮向上：拉近（放大）
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom += Vector2(0.1, 0.1)
		# 滚轮向下：拉远（缩小）
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom -= Vector2(0.1, 0.1)
		
		# 限制缩放范围，防止拉到太远看不见，或太近只看得到眼睛
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

extends CharacterBody2D
# 角色控制层：负责移动、动画、镜头缩放、按 B 开关背包。
# 按《游戏开发SOP》的分层要求，这里不直接改背包数据，只调用 GameData。

# ========== 导出变量 ==========
# 行走速度（像素/秒），可在检查器里调。
@export var walk_speed: float = 100.0
# 奔跑速度（像素/秒），可在检查器里调。
@export var run_speed: float = 200.0

# ========== 私有变量 ==========
# 当前实际速度，初始等于行走速度。
var current_speed: float = walk_speed
# 最后一次面朝方向，松键后用它播放对应的待机动画。
var last_direction: String = "down"

# ========== 节点引用 ==========
# 角色身上的动画节点，负责播放走/跑/待机动画。
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# 跟随角色的相机，用于滚轮缩放。
@onready var camera: Camera2D = $Camera2D


# ========== 生命周期 ==========
func _ready():
	# 把自己登记进 player 组：拾取物和 NPC 靠这个组名认出玩家，
	# 不用再硬写 body.name == "CharacterBody2D"（节点一改名就全崩）。
	add_to_group("player")


# ========== 物理帧：移动与动画 ==========
func _physics_process(delta):
	# 对话或交易进行中，直接停下，避免一边看 UI 一边把角色走丢。
	if GameData.is_ui_blocking():
		velocity = Vector2.ZERO
		# 停下时播放待机动画，方向沿用最后一次朝向。
		animated_sprite.play("idle-" + last_direction)
		return

	# 读方向输入，返回 -1~1 之间的二维向量。
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# 是否按住跑步键（Shift）。
	var is_running: bool = Input.is_action_pressed("run")

	if input_dir != Vector2.ZERO:
		# 水平输入比垂直大就优先走左右，否则走上下，避免斜向时动画打架。
		if abs(input_dir.x) > abs(input_dir.y):
			last_direction = "left" if input_dir.x < 0 else "right"
		else:
			last_direction = "up" if input_dir.y < 0 else "down"

		# 按住 Shift 用跑速，否则用走速。
		current_speed = run_speed if is_running else walk_speed
		# 速度向量 = 方向 × 速度大小。
		velocity = input_dir * current_speed
		# 真正移动并按碰撞做滑动。
		move_and_slide()

		# 动画名前缀跟着走/跑切换，拼出来就是 walk-left、run-up 这种。
		var anim_prefix: String = "run" if is_running else "walk"
		animated_sprite.play(anim_prefix + "-" + last_direction)
	else:
		# 没按方向键：停下并播待机动画。
		velocity = Vector2.ZERO
		animated_sprite.play("idle-" + last_direction)


# ========== 输入：背包开关 与 相机缩放 ==========
func _input(event):
	# ---- Tab 键开关背包（实际绑在 B 上）----
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		# 交易或对话时不允许开背包，避免两套 UI 叠在一起。
		if GameData.is_ui_blocking():
			return
		# 用组名找背包，比按节点名递归搜索更稳。
		var bag: CanvasLayer = get_tree().get_first_node_in_group("bag_ui")
		if bag == null:
			return
		# 可见性取反，实现“按一下开、再按一下关”。
		bag.visible = not bag.visible
		# 打开时刷新一次数据，保证刚捡的东西立刻出现在格子里。
		if bag.visible:
			bag.update_bag()
		# 键盘事件已经用完，标记为已处理，避免再传给别的节点。
		get_viewport().set_input_as_handled()
		return

	# ---- 鼠标滚轮缩放镜头 ----
	if event is InputEventMouseButton and event.pressed:
		# 界面开着的时候不准缩放，不然点 UI 会顺手把镜头拉飞。
		if GameData.is_ui_blocking():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 向上滚：拉近。
			camera.zoom += Vector2(0.1, 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 向下滚：拉远。
			camera.zoom -= Vector2(0.1, 0.1)
		# 把缩放限制在 0.5~3.0，防止拉到看不见人或近到只剩像素。
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

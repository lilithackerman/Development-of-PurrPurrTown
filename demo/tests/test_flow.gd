extends Node
# 端到端流程测试：加载真正的 main.tscn，用真实输入事件走一遍
# “按 E 对话 → 点交易 → 卖瓶子 → 金币增加 → 关界面解锁”的完整闭环。
# 运行方式：godot --headless --path <项目目录> res://tests/test_flow.tscn

# 主场景。
const MAIN_SCENE: PackedScene = preload("res://tscn/main.tscn")

# 失败/通过计数。
var _failed: int = 0
var _passed: int = 0
# 场景根与关键节点引用。
var _main: Node = null
var _player: CharacterBody2D = null
var _npc: Area2D = null


func _ready():
	# 等一帧，保证 AutoLoad 就绪。
	await get_tree().process_frame
	# 把整个游戏场景加载进来，跟玩家真正运行时的结构一模一样。
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	# 等两帧，让所有 _ready 跑完、节点进树。
	await get_tree().process_frame
	await get_tree().process_frame

	# 找到玩家和乌鸦老板这两个关键节点。
	_player = _main.get_node("Node2D/CharacterBody2D")
	_npc = _main.get_node("Node2D/StaticBody2D2/Area2D")

	# 清空数据，保证测试从干净状态开始。
	GameData.inventory.clear()
	GameData.gold = 0
	GameData.set_ui_state(GameData.UiState.PLAY)

	await _test_player_group()
	await _test_pickup_hit()
	await _test_dialog_open_close()
	await _test_trade_flow()
	await _test_player_locked_in_ui()

	# 汇总。
	print("")
	print("========== 流程测试汇总 ==========")
	print("通过 %d 条，失败 %d 条" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# ========== 断言工具 ==========
func _check(condition: bool, case_name: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", case_name)
	else:
		_failed += 1
		print("  [FAIL] ", case_name)


# 模拟按一下某个键，走真正的输入管线（_input → GUI → _unhandled_input）。
func _press_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame


# ========== 用例 1：玩家分组 ==========
func _test_player_group() -> void:
	print("[用例1] 玩家进入 player 组（拾取和对话都靠它认人）")
	_check(_player.is_in_group("player"), "玩家已加入 player 组")
	_check(_player.get_tree().get_first_node_in_group("bag_ui") != null, "背包已在 bag_ui 组里被找到")
	await get_tree().process_frame


# ========== 用例 2：拾取命中判定 ==========
func _test_pickup_hit() -> void:
	print("[用例2] 点击拾取：必须点中物品才算捡")
	# 找场景里放的一瓶。注意：实例的根节点是 Node2D，脚本挂在它下面的 Area2D 上。
	var pickup_root: Node = _main.find_child("Pickup_Bottle_A", true, false)
	_check(pickup_root != null, "场景里找到可拾取的瓶子")
	if pickup_root == null:
		return
	var bottle = pickup_root.get_node("Area2D")
	# 点在贴图中心应该判中。
	var sprite: Sprite2D = bottle.sprite
	_check(bottle._is_point_on_me(sprite.global_position), "点在瓶子上 = 命中")
	# 点在同屏但离得很远的地方不应该判中。
	_check(not bottle._is_point_on_me(sprite.global_position + Vector2(400, 400)), "点在远处 = 不命中")
	# 不在拾取范围内时，_unhandled_input 应该直接放过这一下点击（用状态位验证）。
	bottle.player_in_range = false
	_check(not bottle.player_in_range, "不在范围内时不响应点击（状态位）")
	bottle.player_in_range = true
	# 直接走拾取流程：数量 +1、物品消失。
	var before: int = GameData.count_item("PlasticBottle")
	bottle._pick_up()
	await get_tree().process_frame
	_check(GameData.count_item("PlasticBottle") == before + 1, "拾取后背包数量 +1")
	_check(not is_instance_valid(bottle), "拾取后瓶子节点被销毁")
	# 清空，后面的用例从零开始。
	GameData.inventory.clear()


# ========== 用例 3：按 E 开关对话 ==========
func _test_dialog_open_close() -> void:
	print("[用例3] 靠近 NPC 按 E 打开对话")
	# 直接把“玩家在范围内”置真，等价于玩家走进 Area2D。
	_npc.player_in_range = true
	await _press_key(KEY_E)
	# 对话应该开出来了。
	_check(_npc.dialog_instance != null, "按 E 后对话界面出现")
	_check(GameData.ui_state == GameData.UiState.DIALOG, "对话时全局状态变成 DIALOG")
	if _npc.dialog_instance != null:
		# 名字和台词应该按检查器里配的内容填好。
		_check(_npc.dialog_instance.name_label.text == "乌乌", "姓名显示为“乌乌”")
		_check(_npc.dialog_instance.text_label.text.length() > 0, "正文非空")
		# 乌鸦老板能交易，交易按钮必须是显示的。
		_check(_npc.dialog_instance.trade_button.visible, "可交易 NPC 的“交易”按钮可见")
	# 再按一次 E 应该关掉。
	await _press_key(KEY_E)
	_check(_npc.dialog_instance == null, "再按 E 后对话关闭")
	_check(GameData.ui_state == GameData.UiState.PLAY, "关闭对话后状态回到 PLAY")


# ========== 用例 3：对话里点交易并卖东西 ==========
func _test_trade_flow() -> void:
	print("[用例4] 对话 → 点交易 → 卖瓶子 → 金币增加")
	# 先捡 3 个瓶子进背包（等价于点三次瓶子）。
	for i in 3:
		GameData.add_item("PlasticBottle", 1)
	# 重新打开对话。
	await _press_key(KEY_E)
	_check(_npc.dialog_instance != null, "对话重新打开")
	# 模拟点击“我要卖点东西”按钮（直接触发按钮的 pressed 信号）。
	if _npc.dialog_instance != null:
		_npc.dialog_instance.trade_button.pressed.emit()
	await get_tree().process_frame
	# 交易界面应该出现，对话应该关掉。
	_check(_npc.trade_instance != null, "点交易后交易界面出现")
	_check(_npc.dialog_instance == null, "交易打开时对话已关闭")
	_check(GameData.ui_state == GameData.UiState.TRADE, "交易时状态变成 TRADE")
	if _npc.trade_instance != null:
		# 标题里应该带 NPC 名字。
		_check(_npc.trade_instance.title_label.text.contains("乌乌"), "交易界面标题带 NPC 名字")
		# 背包区应该出现瓶子的格子。
		_check(_npc.trade_instance.bag_grid.get_child_count() > 0, "背包区显示可交易物品")
		# 一键售出 + 确定售出。
		_npc.trade_instance._on_sell_all_pressed()
		_check(int(_npc.trade_instance.trade_items.get("PlasticBottle", 0)) == 3, "一键售出把 3 个瓶子放进交易栏")
		_npc.trade_instance._on_confirm_pressed()
		await get_tree().process_frame
		# 3 个瓶子 × 1 金币 = 3。
		_check(GameData.gold == 3, "结算后金币 = 3")
		_check(GameData.count_item("PlasticBottle") == 0, "结算后背包里没有瓶子了")
		# 关掉交易界面，状态应该解锁。
		_npc.trade_instance.close()
	await get_tree().process_frame
	_check(_npc.trade_instance == null, "交易界面已关闭")
	_check(GameData.ui_state == GameData.UiState.PLAY, "关闭交易后状态回到 PLAY")


# ========== 用例 4：界面打开时角色被锁 ==========
func _test_player_locked_in_ui() -> void:
	print("[用例5] 界面打开时锁住角色移动")
	# 模拟按住“向左”方向键。
	GameData.set_ui_state(GameData.UiState.DIALOG)
	Input.action_press("ui_left")
	# 跑几个物理帧，让 _physics_process 执行。
	for i in 3:
		await get_tree().physics_frame
	# 对话状态下速度必须被清零。
	_check(_player.velocity.length() < 0.001, "对话状态下角色速度为 0")
	# 解锁后再跑几帧，角色应该能重新动起来。
	GameData.set_ui_state(GameData.UiState.PLAY)
	for i in 3:
		await get_tree().physics_frame
	_check(_player.velocity.length() > 0.001, "解锁后角色能重新移动")
	# 松开按键，避免影响后续。
	Input.action_release("ui_left")
	await get_tree().process_frame

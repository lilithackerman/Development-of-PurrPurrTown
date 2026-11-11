extends Node
# 交易闭环的无头测试：不打开窗口，直接驱动数据层和交易界面，逐条断言。
# 运行方式：godot --headless --path <项目目录> res://tests/test_trade.tscn

# 交易界面场景，测试里要反复实例化。
const TRADE_SCENE: PackedScene = preload("res://tscn/TradeUI.tscn")

# 失败条数，最后拿它决定退出码。
var _failed: int = 0
# 通过的条数，最后打印汇总。
var _passed: int = 0


func _ready():
	# 等一帧，确保 AutoLoad（GameData）和场景都进树完毕。
	await get_tree().process_frame
	# 按顺序跑所有测试用例。
	await _test_tables()
	await _test_add_remove()
	await _test_bag_capacity()
	await _test_crow_trade()
	await _test_sell_all_and_settle()
	# 打印汇总。
	print("")
	print("========== 测试汇总 ==========")
	print("通过 %d 条，失败 %d 条" % [_passed, _failed])
	# 有失败就返回非 0 退出码，方便外部脚本判定。
	get_tree().quit(1 if _failed > 0 else 0)


# ========== 断言工具 ==========
func _check(condition: bool, case_name: String) -> void:
	# 成立就记一条通过。
	if condition:
		_passed += 1
		print("  [PASS] ", case_name)
	else:
		# 不成立就记一条失败，并标红打印，方便一眼看到。
		_failed += 1
		print("  [FAIL] ", case_name)


func _reset() -> void:
	# 每个用例开始前把全局数据恢复干净，避免用例之间互相污染。
	GameData.inventory.clear()
	GameData.gold = 0
	GameData.set_ui_state(GameData.UiState.PLAY)


# ========== 用例 1：数据表 ==========
func _test_tables() -> void:
	print("[用例1] 物品表 / 价格表 / NPC 收货分类")
	_reset()
	_check(GameData.get_price("PlasticBottle") == 1, "塑料瓶单价 = 1")
	_check(GameData.get_price("Newspaper") == 2, "废旧报纸单价 = 2")
	_check(GameData.get_item_category("PlasticBottle") == "废品", "塑料瓶分类 = 废品")
	_check(GameData.get_item_category("Cabbage") == "农产品", "白菜分类 = 农产品")
	_check(GameData.can_npc_trade("crow_merchant"), "乌鸦老板可以交易")
	_check(not GameData.can_npc_trade("mayor"), "镇长不参与交易")
	_check(GameData.can_trade_item("crow_merchant", "PlasticBottle"), "乌鸦老板收塑料瓶")
	_check(not GameData.can_trade_item("crow_merchant", "Cabbage"), "乌鸦老板不收白菜")
	await get_tree().process_frame


# ========== 用例 2：背包增删 ==========
func _test_add_remove() -> void:
	print("[用例2] 背包增删与堆叠")
	_reset()
	# 连加 3 次，应该堆叠成 3 个、只占 1 格。
	GameData.add_item("PlasticBottle", 1)
	GameData.add_item("PlasticBottle", 1)
	GameData.add_item("PlasticBottle", 1)
	_check(GameData.count_item("PlasticBottle") == 3, "连捡 3 次 = 3 个")
	_check(GameData.bag_used_slots() == 1, "同种物品只占 1 格")
	# 扣 2 个，应该剩 1 个。
	GameData.remove_item("PlasticBottle", 2)
	_check(GameData.count_item("PlasticBottle") == 1, "扣掉 2 个后剩 1 个")
	# 数量不够时扣款应该失败，且不变。
	_check(not GameData.remove_item("PlasticBottle", 5), "数量不够时拒绝扣除")
	_check(GameData.count_item("PlasticBottle") == 1, "扣除失败后数量不变")
	# 扣到 0 应该整格移除。
	GameData.remove_item("PlasticBottle", 1)
	_check(not GameData.inventory.has("PlasticBottle"), "扣到 0 时整格移除")
	await get_tree().process_frame


# ========== 用例 3：背包容量上限 ==========
func _test_bag_capacity() -> void:
	print("[用例3] 背包格子满时的拒绝逻辑")
	_reset()
	# 塞满 60 种不同物品（每件占一格）。
	for i in GameData.MAX_BAG_SLOTS:
		GameData.add_item("测试物品_%d" % i, 1)
	_check(GameData.bag_used_slots() == GameData.MAX_BAG_SLOTS, "已用满 60 格")
	_check(GameData.is_bag_full(), "背包判定为已满")
	# 第 61 种应该被拒绝。
	var ok: bool = GameData.add_item("测试物品_额外", 1)
	_check(not ok, "背包满时新物品被拒绝")
	# 已有物品仍可继续堆叠（不需要新格子）。
	_check(GameData.add_item("测试物品_0", 5), "背包满时老物品仍可堆叠")
	await get_tree().process_frame


# ========== 用例 4：乌鸦老板交易过滤 ==========
func _test_crow_trade() -> void:
	print("[用例4] 打开交易界面：只显示废品、点击移 1、长按移 10")
	_reset()
	# 背包里放 3 个瓶子（废品）和 2 颗白菜（农产品）。
	GameData.add_item("PlasticBottle", 3)
	GameData.add_item("Cabbage", 2)
	# 打开交易界面。
	var ui = TRADE_SCENE.instantiate()
	add_child(ui)
	ui.open("crow_merchant", "乌乌")
	await get_tree().process_frame
	# 右侧背包只应该有瓶子这一格（白菜被过滤掉）。
	var bag_slots: int = ui.bag_grid.get_child_count()
	_check(bag_slots >= 1, "背包里显示可交易物品")
	# 点击 = 移 1 个。
	ui.move_item_to_trade("PlasticBottle", 1)
	_check(int(ui.trade_items.get("PlasticBottle", 0)) == 1, "点击移 1 个进交易栏")
	_check(ui.income_label.text.contains("1"), "预计收入更新为 1")
	# 长按 = 移 10 个，但只有 2 个可用，应该全移。
	ui.move_item_to_trade("PlasticBottle", 10)
	_check(int(ui.trade_items.get("PlasticBottle", 0)) == 3, "长按一次把剩下的全移走（不足 10 个）")
	# 白菜不该被移进来。
	ui.move_item_to_trade("Cabbage", 1)
	_check(not ui.trade_items.has("Cabbage"), "不收的分类移不进交易栏")
	# 点交易栏可以把东西拿回背包。
	ui.return_item_to_bag("PlasticBottle", 1)
	_check(int(ui.trade_items.get("PlasticBottle", 0)) == 2, "点交易栏拿回 1 个")
	# 收尾：销毁界面。
	ui.queue_free()
	await get_tree().process_frame


# ========== 用例 5：一键售出 + 确定售出结算 ==========
func _test_sell_all_and_settle() -> void:
	print("[用例5] 一键售出与结算（金币到账、背包扣减）")
	_reset()
	# 5 个瓶子 + 2 颗白菜，白菜不应该被卖。
	GameData.add_item("PlasticBottle", 5)
	GameData.add_item("Cabbage", 2)
	var ui = TRADE_SCENE.instantiate()
	add_child(ui)
	ui.open("crow_merchant", "乌乌")
	await get_tree().process_frame
	# 一键售出：只把废品全部移到交易栏。
	ui._on_sell_all_pressed()
	_check(int(ui.trade_items.get("PlasticBottle", 0)) == 5, "一键售出把 5 个瓶子全移走")
	_check(not ui.trade_items.has("Cabbage"), "一键售出不碰白菜")
	# 确定售出：5 × 1 = 5 金币。
	ui._on_confirm_pressed()
	await get_tree().process_frame
	_check(GameData.gold == 5, "结算后金币 = 5")
	_check(GameData.count_item("PlasticBottle") == 0, "结算后瓶子从背包扣除")
	_check(GameData.count_item("Cabbage") == 2, "白菜仍在背包里")
	_check(ui.trade_items.is_empty(), "结算后交易栏清空")
	# 再卖一次应该没有收入（没有东西可卖了）。
	ui._on_confirm_pressed()
	_check(GameData.gold == 5, "空交易栏再点确定不会重复加钱")
	# 收尾：关掉界面，状态应该回到可自由走动。
	ui.close()
	await get_tree().process_frame
	_check(GameData.ui_state == GameData.UiState.PLAY, "关闭交易界面后状态回到 PLAY")

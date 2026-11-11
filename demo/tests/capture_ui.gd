extends Node
# 界面截图工具（开发用）：加载主场景，依次打开对话框和交易界面，各截一张图存到 res://_shots/。
# 运行方式（要带窗口，不能用 --headless，否则渲染器是空实现截不到图）：
#   godot --path <项目目录> res://tests/capture_ui.tscn

# 主场景。
const MAIN_SCENE: PackedScene = preload("res://tscn/main.tscn")
# 截图输出目录。
const SHOT_DIR: String = "res://_shots/"

# 场景节点引用。
var _main: Node = null
var _npc: Area2D = null


func _ready():
	# 等一帧让 AutoLoad 就绪。
	await get_tree().process_frame
	# 确保输出目录存在。
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	# 加载主场景。
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	# 取到乌鸦老板。
	_npc = _main.get_node("Node2D/StaticBody2D2/Area2D")
	# 造一点测试数据：3 个瓶子（有图标）+ 2 份报纸（没有图标，用来看占位效果）。
	GameData.inventory.clear()
	GameData.gold = 128
	GameData.add_item("PlasticBottle", 3)
	GameData.add_item("Newspaper", 2)
	# 让玩家“在范围内”。
	_npc.player_in_range = true

	# 第一张：对话框。
	_npc._open_dialog()
	await _wait(0.5)
	await _save_shot("dialog.png")
	# 第二张：交易界面（从对话点交易过去）。
	_npc._on_trade_pressed()
	await _wait(0.5)
	await _save_shot("trade.png")
	# 第三张：背包界面（关掉交易，直接打开背包）。
	_npc._close_trade()
	await get_tree().process_frame
	var bag: CanvasLayer = _main.get_node("BagUI")
	bag.visible = true
	bag.update_bag()
	await _wait(0.4)
	await _save_shot("bag.png")

	print("截图完成，输出目录：", ProjectSettings.globalize_path(SHOT_DIR))
	get_tree().quit()


func _wait(seconds: float) -> void:
	# 等一段时间，让 UI 布局和动画稳定下来再截。
	await get_tree().create_timer(seconds).timeout


func _save_shot(file_name: String) -> void:
	# 等一帧真正画完，否则拿到的是上一帧画面。
	await RenderingServer.frame_post_draw
	# 取整个窗口的画面。
	var image: Image = get_viewport().get_texture().get_image()
	# 存成 PNG。
	var path: String = SHOT_DIR + file_name
	var err: int = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		print("截图失败：", path, " 错误码 ", err)
	else:
		print("已保存：", ProjectSettings.globalize_path(path))

extends Area2D
# NPC 交互层：玩家进范围按 E 打开对话；对话里点“交易”再打开交易界面。
# 按 SOP：这里只负责“什么时候开哪个界面”，绝不写交易结算逻辑。

# ========== 常量 ==========
# 对话界面场景；路径必须写全（原来写成 res://DialogUI.tscn 是错的，文件其实在 tscn/ 下）。
const DIALOG_SCENE: PackedScene = preload("res://tscn/DialogUI.tscn")
# 交易界面场景。
const TRADE_SCENE: PackedScene = preload("res://tscn/TradeUI.tscn")

# ========== 导出变量 ==========
# NPC 的 id：要和 GameData.NPC_TRADE_CATEGORY 里的键对上，对不上就只聊天不交易。
@export var npc_id: String = "crow_merchant"
# NPC 显示名，显示在对话框的姓名框里。
@export var npc_name: String = "NPC名字"
# 第一次对话的正文。
@export var dialog_text: String = "对话内容"
# 立绘图片，在检查器里拖进来；不给就不显示立绘。
@export var npc_portrait: Texture = null
# 闲聊台词库：每点一次“闲聊”随机抽一句。
@export var chat_lines: PackedStringArray = [
	"今天也是捡瓶子的好天气。",
	"废品价最近有点低，过两天再来吧。",
	"你那只猫又跑哪儿去了？",
]

# ========== 运行时引用 ==========
# 当前打开的对话框实例（没有就是 null）。
var dialog_instance: CanvasLayer = null
# 当前打开的交易界面实例（没有就是 null）。
var trade_instance: CanvasLayer = null

# ========== 状态 ==========
# 玩家是否在交互范围内。
var player_in_range: bool = false


# ========== 生命周期 ==========
func _ready():
	# 进出范围用信号维护，不在 _process 里每帧检测，省性能。
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	# 只认 player 组（不再依赖节点名，改名不会崩）。
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body):
	# 玩家走远：关掉对话和交易，避免界面挂在半空中。
	if body.is_in_group("player"):
		player_in_range = false
		_close_dialog()
		_close_trade()


# ========== 输入：按 E 对话 ==========
func _unhandled_input(event):
	# 只处理按下、非重复的 E 键。
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		return
	# 交易界面开着的时候，E 不做事（避免误触把交易关掉）。
	if trade_instance != null:
		return
	# 玩家不在范围内就不响应。
	if not player_in_range:
		return
	# 事件被我们消费掉了，别让别的 NPC 也弹一次。
	get_viewport().set_input_as_handled()
	# 已经开着对话：再按 E 就关掉（开/关都由这里管，逻辑简单不会打架）。
	if dialog_instance != null:
		_close_dialog()
		return
	# 没开着就打开。
	_open_dialog()


# ========== 对话 ==========
func _open_dialog() -> void:
	# 实例化对话界面。
	dialog_instance = DIALOG_SCENE.instantiate()
	# 挂到自己下面，跟着 NPC 一起存在/销毁。
	add_child(dialog_instance)
	# 填充内容；这个 NPC 能不能交易由数据表决定，不是写死的。
	dialog_instance.setup(npc_name, dialog_text, npc_portrait, GameData.can_npc_trade(npc_id))
	# 接上两个按钮的信号。
	dialog_instance.chat_pressed.connect(_on_chat_pressed)
	dialog_instance.trade_pressed.connect(_on_trade_pressed)
	# 界面自己关掉时（点 × 或按 Esc），这里要清空引用。
	dialog_instance.closed.connect(_on_dialog_closed)


func _close_dialog() -> void:
	# 没有对话框就什么都不做。
	if dialog_instance == null:
		return
	# 直接销毁；引用在 closed 信号里清空。
	dialog_instance.close()
	dialog_instance = null


func _on_dialog_closed() -> void:
	# 对话框自己关掉了，把引用清空，避免下次判断拿到已释放的对象。
	dialog_instance = null


func _on_chat_pressed() -> void:
	# 闲聊：从台词库里随机抽一句，替换正文，界面不关。
	if chat_lines.is_empty():
		return
	var index: int = randi() % chat_lines.size()
	dialog_instance.set_text(chat_lines[index])


# ========== 交易 ==========
func _on_trade_pressed() -> void:
	# 先关对话（同时把状态还原成 PLAY），再开交易（交易界面会自己切成 TRADE）。
	_close_dialog()
	# 防止重复开两个交易界面。
	if trade_instance != null:
		return
	# 实例化并挂到场景里。
	trade_instance = TRADE_SCENE.instantiate()
	add_child(trade_instance)
	# 界面关闭时清空引用。
	trade_instance.closed.connect(_on_trade_closed)
	# 告诉交易界面：跟谁交易（分类过滤靠这个 id）。
	trade_instance.open(npc_id, npc_name)


func _close_trade() -> void:
	# 没有交易界面就直接返回。
	if trade_instance == null:
		return
	trade_instance.close()
	trade_instance = null


func _on_trade_closed() -> void:
	# 交易界面自己关掉了，清空引用。
	trade_instance = null

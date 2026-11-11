extends CanvasLayer
# 对话表现层：只负责显示名字/文本/立绘，并把“闲聊”“交易”两个按钮点击转成信号发给交互层。
# 按 SOP：这里不修改 GameData，只发信号。

# ========== 信号 ==========
# 玩家点了“闲聊”。
signal chat_pressed
# 玩家点了“我要卖点东西”。
signal trade_pressed
# 对话框关掉了（无论是点关闭还是按 E），上层据此清空自己的引用。
signal closed

# ========== 节点引用 ==========
# 名字标签，显示 NPC 名字。
@onready var name_label: Label = $Panel/NameLabel
# 正文标签，显示对话内容。
@onready var text_label: Label = $Panel/TextLabel
# 立绘框，显示 NPC 形象。
@onready var portrait: TextureRect = $Panel/Portrait
# 闲聊按钮。
@onready var chat_button: Button = $Panel/ChatButton
# 交易按钮。
@onready var trade_button: Button = $Panel/TradeButton
# 关闭按钮。
@onready var close_button: Button = $Panel/CloseButton


# ========== 生命周期 ==========
func _ready():
	# 按钮信号在这里统一接上，避免场景文件里散落一堆 connection 行。
	chat_button.pressed.connect(_on_chat_pressed)
	trade_button.pressed.connect(_on_trade_pressed)
	close_button.pressed.connect(close)
	# 对话一打开就把全局状态切成 DIALOG，角色会被锁住不能走。
	GameData.set_ui_state(GameData.UiState.DIALOG)


# ========== 对外接口 ==========
func setup(npc_display_name: String, content: String, portrait_texture: Texture, can_trade: bool) -> void:
	# 填名字。
	name_label.text = npc_display_name
	# 填对话正文。
	text_label.text = content
	# 有立绘就贴上；没有就保持空白，不报错。
	if portrait_texture != null:
		portrait.texture = portrait_texture
		portrait.visible = true
	else:
		portrait.visible = false
	# 这个 NPC 不收东西时，直接把交易按钮藏掉——数据决定功能，而不是写死在场景里。
	trade_button.visible = can_trade


func set_text(content: String) -> void:
	# 只换正文，用于“闲聊”换一句新台词。
	text_label.text = content


func close() -> void:
	# 关掉前把状态还原成可自由走动，否则角色会一直定在原地。
	GameData.set_ui_state(GameData.UiState.PLAY)
	# 先通知上层，再销毁自己，避免上层拿到已释放的对象。
	closed.emit()
	queue_free()


# ========== 输入：Esc 关闭 ==========
func _unhandled_input(event):
	# 只关心按键按下那一下。
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 这里只处理 Esc；E 键的开关交给 NPC 交互层统一管，避免两边抢同一个按键。
	if event.keycode == KEY_ESCAPE:
		# 标记已处理，防止同一个按键继续传给别的节点。
		get_viewport().set_input_as_handled()
		close()


# ========== 按钮回调 ==========
func _on_chat_pressed():
	# 只发信号，说什么由交互层决定（对话内容属于 NPC 数据）。
	chat_pressed.emit()


func _on_trade_pressed():
	# 只发信号，具体打开哪个交易界面由交互层负责。
	trade_pressed.emit()

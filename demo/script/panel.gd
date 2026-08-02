extends Panel

func _on_close_button_pressed():
	# 点击关闭按钮时，告诉父节点销毁自己
	self.queue_free()

# 在 Panel 的检查器里，找到 Button 的 "pressed" 信号，把它连接到这个函数
